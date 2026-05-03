defmodule Bonfire.UI.Social.WidgetGettingStartedTest do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.UI.Social.WidgetGettingStartedLive
  alias Bonfire.Common.Settings
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

  describe "viewing_step/1" do
    test "returns nil when there are no steps" do
      assert WidgetGettingStartedLive.viewing_step(%{steps: [], viewing_index: 0}) == nil
      assert WidgetGettingStartedLive.viewing_step(%{}) == nil
    end

    test "returns the step at viewing_index" do
      a = %{key: :a}
      b = %{key: :b}
      assert WidgetGettingStartedLive.viewing_step(%{steps: [a, b], viewing_index: 1}) == b
    end

    test "falls back to the first step when the index is out of bounds" do
      a = %{key: :a}
      b = %{key: :b}
      assert WidgetGettingStartedLive.viewing_step(%{steps: [a, b], viewing_index: 99}) == a
    end
  end

  describe "load_state/1" do
    test "treats anonymous users as already dismissed" do
      assert WidgetGettingStartedLive.load_state(nil) == {true, []}
    end

    test "returns defaults for a user with no settings yet" do
      account = fake_account!()
      me = fake_user!(account)

      assert {false, []} = WidgetGettingStartedLive.load_state(me)
    end

    test "round-trips dismissed and manual_done from user settings" do
      account = fake_account!()
      me = fake_user!(account)

      _ =
        Settings.put([:ui, :getting_started, :dismissed], true,
          current_user: me,
          scope: :user
        )

      _ =
        Settings.put([:ui, :getting_started, :manual_done], ["profile", "first_post"],
          current_user: me,
          scope: :user
        )

      assert {true, manual} = WidgetGettingStartedLive.load_state(me)
      assert Enum.sort(manual) == ["first_post", "profile"]
    end
  end

  describe "handle_event navigation" do
    test "next wraps from last index to 0" do
      socket = build_socket(nil, %{viewing_index: 2, total_count: 3})

      assert {:noreply, socket} =
               WidgetGettingStartedLive.handle_event("next", %{}, socket)

      assert socket.assigns.viewing_index == 0
    end

    test "prev wraps from 0 to last index" do
      socket = build_socket(nil, %{viewing_index: 0, total_count: 3})

      assert {:noreply, socket} =
               WidgetGettingStartedLive.handle_event("prev", %{}, socket)

      assert socket.assigns.viewing_index == 2
    end

    test "next is a no-op when total_count is 0" do
      socket = build_socket(nil, %{viewing_index: 0, total_count: 0})

      assert {:noreply, socket} =
               WidgetGettingStartedLive.handle_event("next", %{}, socket)

      assert socket.assigns.viewing_index == 0
    end
  end

  describe "handle_event \"dismiss\"" do
    setup do
      account = fake_account!()
      me = fake_user!(account)
      {:ok, account: account, me: me}
    end

    test "flips dismissed? on and clears celebrating?", %{me: me} do
      socket = build_socket(me, %{celebrating?: true})

      assert {:noreply, socket} =
               WidgetGettingStartedLive.handle_event("dismiss", %{}, socket)

      assert socket.assigns.dismissed? == true
      assert socket.assigns.celebrating? == false
    end

    test "persists dismissed: true to the user's settings", %{me: me} do
      socket = build_socket(me)

      {:noreply, _} = WidgetGettingStartedLive.handle_event("dismiss", %{}, socket)

      assert {true, _} = WidgetGettingStartedLive.load_state(me)
    end
  end

  describe "handle_event \"mark_done\"" do
    setup do
      account = fake_account!()
      me = fake_user!(account)
      {:ok, account: account, me: me}
    end

    test "persists the manual entry to the user's settings", %{me: me} do
      socket = build_socket(me)

      {:noreply, _} =
        WidgetGettingStartedLive.handle_event("mark_done", %{"key" => "profile"}, socket)

      assert {_, manual} = WidgetGettingStartedLive.load_state(me)
      assert "profile" in manual
    end

    test "merges with existing manual_done without duplicates", %{me: me} do
      _ =
        Settings.put([:ui, :getting_started, :manual_done], ["profile"],
          current_user: me,
          scope: :user
        )

      socket = build_socket(me, %{manual_done: ["profile"]})

      {:noreply, _} =
        WidgetGettingStartedLive.handle_event("mark_done", %{"key" => "profile"}, socket)

      {:noreply, _} =
        WidgetGettingStartedLive.handle_event(
          "mark_done",
          %{"key" => "first_post"},
          build_socket(me, %{manual_done: ["profile"]})
        )

      assert {_, manual} = WidgetGettingStartedLive.load_state(me)
      assert Enum.sort(manual) == ["first_post", "profile"]
    end
  end

  describe "update/2" do
    setup do
      Application.put_env(:bonfire_ui_social, WidgetGettingStartedLive, actions: [:profile])
      on_exit(fn -> Application.delete_env(:bonfire_ui_social, WidgetGettingStartedLive) end)
      :ok
    end

    test "anonymous users see the widget hidden" do
      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(nil))

      assert socket.assigns.dismissed? == true
      assert WidgetGettingStartedLive.render_state(socket.assigns) == :hidden
    end

    test "a fresh user sees the configured step as current and is not celebrating" do
      account = fake_account!()
      me = fake_user!(account)

      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(me))

      assert %{key: :profile} = socket.assigns.current
      refute socket.assigns.celebrating?
      assert WidgetGettingStartedLive.render_state(socket.assigns) == :step
    end

    test "a manual mark counts as done even when the auto-detector says false" do
      account = fake_account!()
      me = fake_user!(account)
      refute WidgetGettingStartedLive.profile_complete?(me)

      _ =
        Settings.put([:ui, :getting_started, :manual_done], ["profile"],
          current_user: me,
          scope: :user
        )

      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(me))

      assert socket.assigns.current == nil
      assert socket.assigns.done_count == 1
    end
  end

  describe "fresh-completion celebration" do
    setup do
      Application.put_env(:bonfire_ui_social, WidgetGettingStartedLive, actions: [:profile])
      on_exit(fn -> Application.delete_env(:bonfire_ui_social, WidgetGettingStartedLive) end)
      :ok
    end

    test "fires when mark_done flips current from non-nil to nil" do
      account = fake_account!()
      me = fake_user!(account)

      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(me))

      assert %{key: :profile} = socket.assigns.current
      refute socket.assigns.celebrating?

      assert {:noreply, socket} =
               WidgetGettingStartedLive.handle_event(
                 "mark_done",
                 %{"key" => "profile"},
                 socket
               )

      assert socket.assigns.current == nil
      assert socket.assigns.celebrating? == true
      assert WidgetGettingStartedLive.render_state(socket.assigns) == :celebrate
    end

    test "does not fire on first mount for a user who is already complete" do
      account = fake_account!()
      me = fake_user!(account)

      _ =
        Settings.put([:ui, :getting_started, :manual_done], ["profile"],
          current_user: me,
          scope: :user
        )

      assert {:ok, socket} =
               WidgetGettingStartedLive.update(%{}, build_socket(me))

      assert socket.assigns.current == nil
      refute socket.assigns.celebrating?
      assert WidgetGettingStartedLive.render_state(socket.assigns) == :hidden
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

    test "has_followed?/1 flips to true after the user follows someone", %{
      account: account,
      me: me
    } do
      refute WidgetGettingStartedLive.has_followed?(me)

      other_account = fake_account!()
      other = fake_user!(other_account)

      assert {:ok, _follow} = Follows.follow(me, other)
      _ = account
      assert WidgetGettingStartedLive.has_followed?(me)
    end
  end

  defp build_socket(user, extra_assigns \\ %{}) do
    base = %{
      __changed__: %{},
      current_user: user,
      dismissed?: false,
      celebrating?: false,
      steps: [],
      current: nil,
      viewing_index: 0,
      done_count: 0,
      total_count: 0,
      manual_done: []
    }

    %Phoenix.LiveView.Socket{assigns: Map.merge(base, extra_assigns)}
  end
end
