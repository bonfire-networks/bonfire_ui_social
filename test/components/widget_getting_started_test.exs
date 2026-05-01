defmodule Bonfire.UI.Social.WidgetGettingStartedTest do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.UI.Social.WidgetGettingStartedLive
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows

  describe "render_state/1" do
    test "stays hidden when the user has dismissed the widget" do
      assigns = %{dismissed?: true, total_count: 3, current: nil, celebrating?: false}
      assert WidgetGettingStartedLive.render_state(assigns) == :hidden
    end

    test "stays hidden when the instance has no actions configured" do
      assigns = %{dismissed?: false, total_count: 0, current: nil, celebrating?: false}
      assert WidgetGettingStartedLive.render_state(assigns) == :hidden
    end

    test "stays hidden when the user already had everything done before the widget existed" do
      assigns = %{dismissed?: false, total_count: 3, current: nil, celebrating?: false}
      assert WidgetGettingStartedLive.render_state(assigns) == :hidden
    end

    test "celebrates when the user just finished the last step in this session" do
      assigns = %{dismissed?: false, total_count: 3, current: nil, celebrating?: true}
      assert WidgetGettingStartedLive.render_state(assigns) == :celebrate
    end

    test "shows the focused step when work remains" do
      assigns = %{
        dismissed?: false,
        total_count: 3,
        current: %{key: :profile},
        celebrating?: false
      }

      assert WidgetGettingStartedLive.render_state(assigns) == :step
    end
  end

  describe "configured_action_keys/0" do
    test "falls back to the default seed when no flavour overrides" do
      Application.delete_env(:bonfire_ui_social, WidgetGettingStartedLive)

      assert WidgetGettingStartedLive.configured_action_keys() ==
               [:profile, :first_post, :first_follow]
    end

    test "honours a flavour override and silently drops unknown keys" do
      Application.put_env(:bonfire_ui_social, WidgetGettingStartedLive,
        actions: [:first_post, :unsupported_action_xyz, :profile]
      )

      on_exit(fn -> Application.delete_env(:bonfire_ui_social, WidgetGettingStartedLive) end)

      assert WidgetGettingStartedLive.configured_action_keys() == [:first_post, :profile]
    end
  end

  describe "detection signals" do
    setup do
      account = fake_account!()
      me = fake_user!(account)
      {:ok, account: account, me: me}
    end

    test "profile_complete?/1 is false for a brand-new user without an avatar or bio", %{me: me} do
      refute WidgetGettingStartedLive.profile_complete?(me)
    end

    test "profile_complete?/1 is false for nil" do
      refute WidgetGettingStartedLive.profile_complete?(nil)
    end

    test "has_posted?/1 flips to true after the user publishes their first post", %{me: me} do
      refute WidgetGettingStartedLive.has_posted?(me)

      attrs = %{post_content: %{html_body: "hello world"}}
      assert {:ok, _post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")

      assert WidgetGettingStartedLive.has_posted?(me)
    end

    test "has_followed?/1 flips to true after the user follows someone", %{account: account, me: me} do
      refute WidgetGettingStartedLive.has_followed?(me)

      other_account = fake_account!()
      other = fake_user!(other_account)

      assert {:ok, _follow} = Follows.follow(me, other)
      _ = account
      assert WidgetGettingStartedLive.has_followed?(me)
    end
  end

end
