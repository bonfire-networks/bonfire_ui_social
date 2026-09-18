defmodule Bonfire.UI.Social.NotificationPreferencesTest do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  test "notification page has a preferences trigger alongside the existing feed" do
    user = fake_user!()

    conn(user: user, account: user.account)
    |> visit("/notifications")
    |> assert_has("#notification-preferences-toggle[aria-expanded=false]", text: "Preferences")
    |> assert_has("#notification-filter-all[checked]")
    |> assert_has("#notification-preferences-panel[aria-labelledby=notification-preferences-title]")
    |> assert_has("[data-id=feed]")
  end

  test "preview controls are independent native inputs with no settings write bindings" do
    html = render_component(&Bonfire.UI.Social.NotificationPreferencesLive.render/1, %{})
    doc = Floki.parse_document!(html)

    assert [_] = Floki.find(doc, "#notification-pref-like-centre[checked]")
    assert [_] = Floki.find(doc, "#notification-pref-like-push")
    assert [] = Floki.find(doc, "#notification-pref-like-push[checked]")
    assert Floki.attribute(doc, "#notification-audience-not_followed option", "value") ==
             ["accept", "filter", "ignore"]
    assert [] = Floki.find(doc, "form, [phx-change], input[phx-click], select[phx-change]")
    assert html =~ "Changes are not saved"
  end

  test "category filters have tooltip and accessible labels without backend events" do
    html = render_component(&Bonfire.UI.Social.NotificationFiltersLive.render/1, %{__context__: %{}})
    doc = Floki.parse_document!(html)

    assert Floki.attribute(doc, "input[checked]", "value") == ["all"]
    assert Floki.find(doc, "label[data-tip='All notifications']") |> Floki.text() =~ "All"

    for {key, label} <- [
          {"all", "All notifications"}, {"mention", "Mentions"}, {"reply", "Replies"},
          {"like", "Likes"}, {"boost", "Boosts"}, {"follow", "New followers"},
          {"request", "Follow requests"}, {"quote", "Quotes"}
        ] do
      assert Floki.attribute(doc, "#notification-filter-#{key}", "aria-label") == [label]
      assert Floki.attribute(doc, "#notification-filter-#{key}", "name") == ["notification-category"]
      assert Floki.find(doc, "label[data-tip='#{label}'] input[value='#{key}']") != []
    end

    assert [] = Floki.find(doc, "[phx-click], [phx-change]")
  end

  test "push devices preview has local controls and no push subscription hook" do
    html = render_component(&Bonfire.UI.Social.NotificationPreferencesLive.render/1, %{})
    doc = Floki.parse_document!(html)

    assert [_] = Floki.find(doc, "#notification-push-this-browser[type=checkbox]")
    assert [] = Floki.find(doc, "#notification-push-this-browser[checked]")
    assert [_] = Floki.find(doc, "#notification-push-remove-sample")
    assert [_] = Floki.find(doc, "#notification-push-undo-remove")
    assert [] = Floki.find(doc, "[phx-hook], [data-vapid-key]")

    for {button, hidden, shown, focus} <- [
          {"#notification-push-remove-sample", "#notification-push-sample-device", "#notification-push-sample-removed", "#notification-push-undo-remove"},
          {"#notification-push-undo-remove", "#notification-push-sample-removed", "#notification-push-sample-device", "#notification-push-remove-sample"}
        ] do
      commands = doc |> Floki.attribute(button, "phx-click") |> hd() |> Jason.decode!()
      assert length(commands) == 3
      assert Enum.any?(commands, fn [command, opts] -> command == "hide" and opts["to"] == hidden end)
      assert Enum.any?(commands, fn [command, opts] -> command == "show" and opts["to"] == shown end)
      assert List.last(commands) == ["focus", %{"to" => focus}]
      for target <- [hidden, shown, focus], do: assert([_] = Floki.find(doc, target))
    end

    assert html =~ "No browser permission is requested"
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
