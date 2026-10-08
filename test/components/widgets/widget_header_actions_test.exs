defmodule Bonfire.UI.Social.WidgetHeaderActionsTest do
  @moduledoc """
  Surface ignores `:if` on slot entries (only `:let` is supported there), so a `<:action :if={...}>` always rendered. These guard the widgets whose header actions are conditional.
  """
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Boundaries.Circles
  alias Bonfire.Boundaries.Scaffold.Instance

  # `render_stateless/3` (Bonfire.UI.Common.Testing.Helpers) doesn't hand `__context__` to a Surface component, so the widgets can't see the user
  defp render_widget(module, user) do
    assigns =
      module
      |> Surface.default_props()
      |> Map.new()
      |> Map.put(:__context__, %{current_user: user})

    Phoenix.LiveViewTest.render_component(&module.render/1, assigns)
  end

  describe "feeds widget" do
    setup do
      key = [
        Bonfire.Common.Config.top_level_otp_app(),
        :ui,
        :sidebar,
        :disable_feeds_customization
      ]

      on_exit(fn -> Process.delete(key) end)
      {:ok, key: key, user: fake_user!()}
    end

    test "links to feed settings by default", %{user: user} do
      html = render_widget(Bonfire.UI.Social.WidgetFeedsLive, user)

      assert html =~ "Feeds"
      assert html =~ ~s(href="/settings/user/feeds")
    end

    test "hides the settings link when sidebar customization is disabled", %{
      key: key,
      user: user
    } do
      Process.put(key, true)

      html = render_widget(Bonfire.UI.Social.WidgetFeedsLive, user)

      assert html =~ "Feeds"
      refute html =~ ~s(href="/settings/user/feeds")
    end
  end

  describe "suggested profiles widget" do
    setup do
      Circles.list_suggested_profiles(cache: :reset)
      on_exit(fn -> Circles.list_suggested_profiles(cache: :reset) end)
      {:ok, me: fake_user!()}
    end

    defp suggest!(user) do
      {:ok, _} = Circles.add_to_circles(user, Instance.suggested_profiles_circle())
      Circles.list_suggested_profiles(cache: :reset)
      user
    end

    test "has no carousel arrows for a single suggestion", %{me: me} do
      suggest!(fake_user!())

      html = render_widget(Bonfire.UI.Social.WidgetSuggestedProfilesLive, me)

      assert html =~ "suggested-profiles-carousel"
      refute html =~ "data-carousel-scroll"
    end

    test "has carousel arrows for several suggestions", %{me: me} do
      suggest!(fake_user!())
      suggest!(fake_user!())

      html = render_widget(Bonfire.UI.Social.WidgetSuggestedProfilesLive, me)

      assert html =~ ~s(data-carousel-scroll="previous")
      assert html =~ ~s(data-carousel-scroll="next")
    end
  end
end
