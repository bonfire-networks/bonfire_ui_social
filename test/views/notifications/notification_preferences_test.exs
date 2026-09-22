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

  test "preferences are absent from the public feed" do
    user = fake_user!()

    conn(user: user, account: user.account)
    |> visit("/feed/local")
    |> refute_has("#notification-preferences-toggle")
    |> refute_has("#notification-preferences-panel")
    |> refute_has("#notification-filters")
  end
end
