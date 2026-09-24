defmodule Bonfire.UI.Social.NotificationPreferencesTest do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  test "notification page has a preferences trigger alongside the existing feed" do
    user = fake_user!()

    conn(user: user, account: user.account)
    |> visit("/notifications")
    |> assert_has("#notification-preferences-toggle[aria-expanded=false]", text: "Preferences")
    |> assert_has("#notification-filters")
    |> assert_has(
      "#notification-preferences-panel[aria-labelledby=notification-preferences-title]"
    )
    |> assert_has("[data-id=feed]")
  end

  test "each row's two switches are their own form, and both save" do
    html =
      render_component(&Bonfire.UI.Social.NotificationPreferencesLive.render/1, %{
        __context__: %{}
      })

    doc = Floki.parse_document!(html)

    # one row, two switches, each in a form of its own: what appears in the feed, and what is pushed. Sharing a form's attributes would make them indistinguishable to a selector
    for column <- ["centre", "push"] do
      assert [_] =
               Floki.find(
                 doc,
                 "form#notification-pref-react-#{column}-form[phx-change] #notification-pref-react-#{column}[checked]"
               ),
             "the #{column} switch has to save, and to be on unless the person said otherwise"
    end

    refute Floki.attribute(doc, "#notification-pref-react-centre-form", "id") ==
             Floki.attribute(doc, "#notification-pref-react-push-form", "id")
  end

  test "with delivery switched off, the feed switches stay and the push column goes" do
    user = fake_user!()

    # this panel belongs to the feed it configures, and delivery is another extension an instance can do without: a push switch nothing would read must not be offered
    # `Settings.put/3` hands back a context rather than a user, and what the panel reads its switches from is the recipient it was given
    disabled_for =
      current_user(
        Bonfire.Common.Settings.put([:bonfire_notify, :modularity], :disabled, current_user: user)
      )

    doc =
      render_component(&Bonfire.UI.Social.NotificationPreferencesLive.render/1, %{
        __context__: %{current_user: disabled_for}
      })
      |> Floki.parse_document!()

    assert [_] = Floki.find(doc, "#notification-pref-react-centre")
    assert [] = Floki.find(doc, "#notification-pref-react-push")
    refute Floki.text(doc) =~ "Push"
  end

  test "the sections that are still previews write no settings" do
    html =
      render_component(&Bonfire.UI.Social.NotificationPreferencesLive.render/1, %{
        __context__: %{}
      })

    doc = Floki.parse_document!(html)

    assert Floki.attribute(doc, "#notification-audience-not_followed option", "value") ==
             ["accept", "filter", "ignore"]

    preview = "#notification-audience-preview"
    assert [_] = Floki.find(doc, preview)
    assert [] = Floki.find(doc, "#{preview} form, #{preview} [phx-change]")

    assert html =~ "Their changes are not saved"
  end

  test "the push section is the real device panel, not a copy of it" do
    user = fake_user!()

    # the one implementation, which also appears on the settings page: it owns the browser permission flow, so a second copy of these controls could only be a fake
    conn(user: user, account: user.account)
    |> visit("/notifications")
    |> assert_has("#notification-push")
    |> assert_has("#notification-push [phx-hook=PushSettingsHook]")
    |> refute_has("#notification-push-sample-device")
  end

  test "notification controls do not leak or duplicate when navigating between feeds" do
    user = fake_user!()
    {:ok, view, _html} = live(conn(user: user, account: user.account), "/notifications")

    render_patch(view, "/feed/local")
    refute has_element?(view, "#notification-preferences-toggle")
    refute has_element?(view, "#notification-preferences-panel")
    refute has_element?(view, "#notification-filters")

    render_patch(view, "/notifications")
    doc = view |> render() |> Floki.parse_document!()
    assert [_] = Floki.find(doc, "#notification-preferences-toggle")
    assert [_] = Floki.find(doc, "#notification-filters")
  end

  describe "the Email column" do
    # each row chooses when that kind is emailed; how often the digest goes out is a separate setting
    test "offers Off, In the digest and Immediately, in that order, with the digest lit until chosen" do
      user = fake_user!()

      doc =
        render_component(&Bonfire.UI.Social.NotificationPreferencesLive.render/1, %{
          __context__: %{current_user: user}
        })
        |> Floki.parse_document!()

      assert doc
             |> Floki.find("#notification-pref-react-email button")
             |> Enum.map(&String.trim(Floki.text(&1))) == ["Off", "Digest", "Instant"]

      assert [_] =
               Floki.find(doc, "#notification-pref-react-email button.active[data-id=default]")
    end

    test "choosing Instant saves it for that kind alone" do
      user = fake_user!()

      conn(user: user, account: user.account)
      |> visit("/notifications")
      |> wait_async()
      |> click_button("#notification-pref-react-email [data-id=enabled]", "Instant")

      user = Bonfire.Me.Users.get_current(user.id)

      assert Bonfire.Common.Settings.get([:notifications, :email, :react], nil,
               current_user: user
             ) in [true, "true"]

      assert Bonfire.Common.Settings.get([:notifications, :email, :boost], nil,
               current_user: user
             ) == nil
    end

    test "how often the digest comes is one choice below the table, never until changed" do
      user = fake_user!()

      doc =
        render_component(&Bonfire.UI.Social.NotificationPreferencesLive.render/1, %{
          __context__: %{current_user: user}
        })
        |> Floki.parse_document!()

      assert Floki.attribute(doc, "#notification-email-digest option", "value") ==
               ["daily", "weekly", "monthly", "never"]

      assert Floki.attribute(doc, "#notification-email-digest option[selected]", "value") ==
               ["never"]
    end

    test "choosing how often the digest comes saves it" do
      user = fake_user!()

      conn(user: user, account: user.account)
      |> visit("/notifications")
      |> wait_async()
      |> within("#notification-email-digest-form", fn session ->
        select(session, "#notification-email-digest", "Weekly", from: "Email digest")
      end)

      assert Bonfire.Common.Settings.get([:notifications, :email_digest], nil,
               current_user: Bonfire.Me.Users.get_current(user.id)
             ) in [:weekly, "weekly"]
    end

    test "how often the digest comes is one choice for the whole account, whichever persona makes it" do
      account = fake_account!()
      chooser = fake_user!(account)
      other_persona = fake_user!(account)

      conn(user: chooser, account: account)
      |> visit("/notifications")
      |> wait_async()
      |> within("#notification-email-digest-form", fn session ->
        select(session, "#notification-email-digest", "Weekly", from: "Email digest")
      end)

      # one email per account, so the other persona's digest comes as often
      assert Bonfire.Common.Settings.get([:notifications, :email_digest], nil,
               current_user: Bonfire.Me.Users.get_current(other_persona.id)
             ) in [:weekly, "weekly"]
    end

    test "choosing Never cancels the digest waiting to go out" do
      # an account that asked for a daily digest, since Never is the default
      user = fake_user!()

      Bonfire.Common.Settings.put([:notifications, :email_digest], :daily,
        current_account: user.account,
        scope: :account
      )

      account_id = user.account.id

      # as the fan-out queues one when a notification left to the digest arrives
      {:ok, _} =
        Bonfire.Notify.Worker.enqueue_digest(
          account_id,
          DateTime.add(DateTime.utc_now(), 1, :day),
          DateTime.utc_now()
        )

      # the positive first: one is waiting
      assert [_] = waiting_digests(account_id)

      conn(user: user, account: user.account)
      |> visit("/notifications")
      |> wait_async()
      |> within("#notification-email-digest-form", fn session ->
        select(session, "#notification-email-digest", "Never", from: "Email digest")
      end)

      assert [] = waiting_digests(account_id)
    end

    test "choosing Digest after another choice goes back to no choice at all" do
      user = fake_user!()

      session =
        conn(user: user, account: user.account)
        |> visit("/notifications")
        |> wait_async()
        |> click_button("#notification-pref-react-email [data-id=enabled]", "Instant")

      # the positive first: the other choice did take
      assert Bonfire.Common.Settings.get([:notifications, :email, :react], nil,
               current_user: Bonfire.Me.Users.get_current(user.id)
             ) in [true, "true"]

      session
      |> click_button("#notification-pref-react-email [data-id=default]", "Digest")
      |> assert_has("#notification-pref-react-email button.active[data-id=default]")

      # unset rather than a stored blank, since unset is what the digest means
      assert Bonfire.Common.Settings.get([:notifications, :email, :react], nil,
               current_user: Bonfire.Me.Users.get_current(user.id)
             ) == nil
    end
  end

  defp waiting_digests(account_id) do
    Oban.Testing.all_enqueued(Bonfire.Common.Repo, worker: Bonfire.Notify.Worker)
    |> Enum.filter(&(&1.args["op"] == "digest" and &1.args["account_id"] == account_id))
  end

  test "preferences are absent from the public feed" do
    user = fake_user!()

    conn(user: user, account: user.account)
    |> visit("/feed/local")
    |> refute_has("#notification-preferences-toggle")
    |> refute_has("#notification-preferences-panel")
    |> refute_has("#notification-filters")
  end
end
