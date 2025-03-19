defmodule Bonfire.UI.Social.Feeds.ComponentID.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.UI.Common.ComponentID

  describe "component_id" do
    test "creates deterministic IDs" do
      component_module = Bonfire.UI.Social.FeedLive
      object_id = "test_object"
      parent_id = "parent_context"

      # Generate ID twice with same inputs
      id1 = ComponentID.new(component_module, object_id, parent_id)
      id2 = ComponentID.new(component_module, object_id, parent_id)

      # IDs should be identical
      assert id1 == id2

      # Should not contain random elements
      refute String.contains?(id1, ~r/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
    end

    test "preserves uniqueness based on inputs" do
      component_module = Bonfire.UI.Social.FeedLive

      # Different object IDs should produce different component IDs
      id1 = ComponentID.new(component_module, "object1", "parent")
      id2 = ComponentID.new(component_module, "object2", "parent")
      assert id1 != id2

      # Different parent IDs should produce different component IDs
      id3 = ComponentID.new(component_module, "object", "parent1")
      id4 = ComponentID.new(component_module, "object", "parent2")
      assert id3 != id4

      # Different component modules should produce different component IDs
      id5 = ComponentID.new(Bonfire.UI.Social.FeedLive, "object", "parent")
      id6 = ComponentID.new(Bonfire.UI.Social.ActivityLive, "object", "parent")
      assert id5 != id6
    end
  end
end
