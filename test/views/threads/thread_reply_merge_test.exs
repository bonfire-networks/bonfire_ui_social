defmodule Bonfire.UI.Social.ThreadReplyMergeTest do
  use ExUnit.Case, async: true

  alias Bonfire.UI.Social.ThreadBranchLive
  doctest ThreadBranchLive, only: [merge_replies: 3], import: true

  test "a later page preserves real parents and all previously loaded descendants" do
    existing = [{%{id: "a"}, [{%{id: "b"}, [{%{id: "c"}, []}]}]}]
    incoming = [{%{id: "a", stub: true}, [{%{id: "b", stub: true}, [{%{id: "d"}, []}]}]}]

    assert [{%{id: "a"}, [{%{id: "b"}, [{%{id: "c"}, []}, {%{id: "d"}, []}]}]}] =
      ThreadBranchLive.merge_replies(existing, incoming)
  end

  test "a resolved parent replaces its placeholder without losing children" do
    existing = [{%{id: "a", stub: true}, [{%{id: "b"}, []}]}]
    incoming = [{%{id: "a", activity: :loaded}, []}]

    assert [{%{id: "a", activity: :loaded}, [{%{id: "b"}, []}]}] =
      ThreadBranchLive.merge_replies(existing, incoming)
  end

  test "live additions prepend and repeated deliveries do not duplicate replies" do
    existing = [{%{id: "a"}, []}]
    incoming = [{%{id: "b"}, []}]
    merged = ThreadBranchLive.merge_replies(existing, incoming, 0)

    assert [{%{id: "b"}, []}, {%{id: "a"}, []}] = merged
    assert ThreadBranchLive.merge_replies(merged, incoming, 0) == merged
  end

  test "component updates merge pages but a fresh generation replaces old content" do
    socket = %Phoenix.LiveView.Socket{assigns: %{
      __changed__: %{},
      comment: %{id: "a"},
      threaded_replies: [{%{id: "b"}, []}],
      reply_generation: 0
    }}
    incoming = %{comment: %{id: "a", stub: true}, threaded_replies: [{%{id: "c"}, []}], reply_generation: 0}

    assert {:ok, merged} = ThreadBranchLive.update(incoming, socket)
    refute Map.get(merged.assigns.comment, :stub)
    assert [{%{id: "b"}, []}, {%{id: "c"}, []}] = merged.assigns.threaded_replies

    assert {:ok, reset} = ThreadBranchLive.update(%{incoming | reply_generation: 1}, merged)
    assert reset.assigns.comment.stub
    assert [{%{id: "c"}, []}] = reset.assigns.threaded_replies
  end
end
