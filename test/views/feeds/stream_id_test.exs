defmodule Bonfire.UI.Social.Feeds.StreamID.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  import Phoenix.LiveViewTest

  # Expose private stream_id function for testing
  defmodule TestHelper do
    def stream_id(feed_id, entry) do
      entry_id =
        Bonfire.Common.Enums.id(entry) ||
          Bonfire.Common.Utils.e(entry, :activity, :id, nil) ||
          Bonfire.Common.Utils.e(entry, :object, :id, nil) ||
          Bonfire.Common.Utils.e(entry, :edge, :id, nil)

      final_id =
        if entry_id,
          do: entry_id,
          else: :erlang.phash2(entry, 1_000_000)

      "#{feed_id}_#{final_id}"
    end
  end

  describe "stream_id" do
    test "creates deterministic IDs with explicit ID" do
      feed_id = "my_feed"
      entry = %{id: "entry123"}

      # Generate ID twice with same inputs
      id1 = TestHelper.stream_id(feed_id, entry)
      id2 = TestHelper.stream_id(feed_id, entry)

      # IDs should be identical
      assert id1 == id2
      assert id1 == "my_feed_entry123"
    end

    test "creates deterministic IDs with nested ID" do
      feed_id = "my_feed"
      entry = %{activity: %{id: "activity456"}}

      # Generate ID twice with same inputs
      id1 = TestHelper.stream_id(feed_id, entry)
      id2 = TestHelper.stream_id(feed_id, entry)

      # IDs should be identical
      assert id1 == id2
      assert id1 == "my_feed_activity456"
    end

    test "creates deterministic IDs without explicit ID" do
      feed_id = "my_feed"
      entry = %{content: "Some content without ID"}

      # Generate ID twice with same inputs
      id1 = TestHelper.stream_id(feed_id, entry)
      id2 = TestHelper.stream_id(feed_id, entry)

      # IDs should be identical despite lack of explicit ID
      assert id1 == id2
    end
  end
end
