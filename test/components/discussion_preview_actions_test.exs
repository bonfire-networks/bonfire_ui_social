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
end
