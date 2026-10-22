defmodule Bonfire.UI.Social.DiscussionPreviewActionsTest do
  use ExUnit.Case, async: true

  # bucket this into the ui CI leg: bare `ExUnit.Case` skips the tag the extension case templates apply, so without it this also runs in the federation job catch-all
  @moduletag :ui

  alias Bonfire.UI.Social.Activity.DiscussionPreviewActionsLive

  test "display_reply_count sums the thread root's counts when its content is preloaded" do
    activity = %{
      replied: %{
        thread: %{
          post_content: %{html_body: "root post"},
          replied: %{nested_replies_count: 3, direct_replies_count: 2}
        }
      }
    }

    assert DiscussionPreviewActionsLive.display_reply_count(activity, 7) == 5
  end

  test "display_reply_count falls back to the prepared count without a thread root" do
    assert DiscussionPreviewActionsLive.display_reply_count(%{}, 7) == 7
    assert DiscussionPreviewActionsLive.display_reply_count(nil, nil) == 0
  end

  describe "update_many/1" do
    setup do
      test_pid = self()

      Repatch.patch(Bonfire.Social.Threads, :attach_participants, fn cards, _user ->
        send(test_pid, {:participants_loaded, length(cards)})

        Enum.map(
          cards,
          &Map.merge(&1, %{participants: [%{id: "someone"}], participants_more_count: 0})
        )
      end)

      :ok
    end

    defp card(id, socket_assigns \\ %{}),
      do:
        {%{id: id, activity: %{id: "activity_#{id}"}},
         %Phoenix.LiveView.Socket{assigns: Map.merge(%{__changed__: %{}}, socket_assigns)}}

    test "the page's cards get their participants in one batch" do
      assert [
               %{assigns: %{participants: [%{id: "someone"}]}},
               %{assigns: %{participants: [%{id: "someone"}]}}
             ] =
               DiscussionPreviewActionsLive.update_many([card("a"), card("b")])

      assert_received {:participants_loaded, 2}
    end

    test "a card that already loaded them keeps them, without querying again" do
      loaded = %{participants: [%{id: "earlier"}], participants_more_count: 2}

      assert [%{assigns: %{participants: [%{id: "earlier"}], participants_more_count: 2}}] =
               DiscussionPreviewActionsLive.update_many([card("a", loaded)])

      refute_received {:participants_loaded, _}
    end
  end
end
