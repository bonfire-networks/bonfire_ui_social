defmodule Bonfire.UI.Social.FeedFiltersHelpersTest do
  @moduledoc """
  Pure-function coverage for the tri-state toggle logic and the small display
  helpers used to label collapsed sections of the feed filters modal.
  No DB, no LiveView — fast and deterministic.
  """
  use ExUnit.Case, async: true

  alias Bonfire.UI.Social.ToggleTypeLive
  alias Bonfire.UI.Social.FeedFiltersModalContentLive

  describe "ToggleTypeLive.check_throuple/3" do
    test "returns true when value is in include only" do
      assert ToggleTypeLive.check_throuple(:post, [:post], []) == true
    end

    test "returns false when value is in exclude only" do
      assert ToggleTypeLive.check_throuple(:post, [], [:post]) == false
    end

    test "returns nil when value is in neither" do
      assert ToggleTypeLive.check_throuple(:post, [], []) == nil
      assert ToggleTypeLive.check_throuple(:post, [:article], [:event]) == nil
    end

    test "returns nil when value is in both include and exclude (ambiguous)" do
      assert ToggleTypeLive.check_throuple(:post, [:post], [:post]) == nil
    end

    test "matches string values against atom inputs via to_string/1 coercion" do
      # The function calls `to_string(value)` and checks both the raw and
      # stringified forms against the sets, so an atom value matches a string
      # entry in the list.
      assert ToggleTypeLive.check_throuple(:post, ["post"], []) == true
      assert ToggleTypeLive.check_throuple(:post, [], ["post"]) == false
    end

    test "accepts MapSets as well as lists" do
      assert ToggleTypeLive.check_throuple(:post, MapSet.new([:post]), MapSet.new([])) == true
      assert ToggleTypeLive.check_throuple(:post, MapSet.new([]), MapSet.new([:post])) == false
    end

    test "treats nil include or exclude as an empty set" do
      assert ToggleTypeLive.check_throuple(:post, nil, [:post]) == false
      assert ToggleTypeLive.check_throuple(:post, [:post], nil) == true
    end
  end

  describe "ToggleTypeLive.tri_state/3" do
    test ":only when value is isolated" do
      assert ToggleTypeLive.tri_state(:post, [:post], []) == :only
    end

    test ":hide when value is suppressed" do
      assert ToggleTypeLive.tri_state(:post, [], [:post]) == :hide
    end

    test ":default when value flows with the rest" do
      assert ToggleTypeLive.tri_state(:post, [], []) == :default
      assert ToggleTypeLive.tri_state(:post, [:article], []) == :default
      assert ToggleTypeLive.tri_state(:post, [], [:event]) == :default
    end

    test ":default when value is ambiguously in both lists" do
      assert ToggleTypeLive.tri_state(:post, [:post], [:post]) == :default
    end
  end

  describe "FeedFiltersModalContentLive.time_range_summary/1" do
    test "returns 'All time' when no time_limit is set" do
      assert FeedFiltersModalContentLive.time_range_summary(%{}) == "All time"
      assert FeedFiltersModalContentLive.time_range_summary(%{time_limit: nil}) == "All time"
    end

    test "returns 'All time' for 0 days" do
      assert FeedFiltersModalContentLive.time_range_summary(%{time_limit: 0}) == "All time"
    end

    test "returns the matching preset label when days match a default option" do
      # relies on the canonical set of options in TimeControlLive.default_options/0
      [{days, label} | _] =
        Bonfire.UI.Social.TimeControlLive.default_options()
        |> Enum.reject(fn {d, _} -> d == 0 end)

      assert FeedFiltersModalContentLive.time_range_summary(%{time_limit: days}) == label
    end

    test "falls back to a Nd label when days don't match any preset" do
      assert FeedFiltersModalContentLive.time_range_summary(%{time_limit: 9999}) == "9999d"
    end
  end

  describe "FeedFiltersModalContentLive.sort_order_summary/1" do
    test "returns 'Oldest first' for :asc" do
      assert FeedFiltersModalContentLive.sort_order_summary(%{sort_order: :asc}) == "Oldest first"
    end

    test "returns 'Newest first' for :desc (the default direction)" do
      assert FeedFiltersModalContentLive.sort_order_summary(%{sort_order: :desc}) ==
               "Newest first"
    end

    test "returns 'Newest first' when unset" do
      assert FeedFiltersModalContentLive.sort_order_summary(%{}) == "Newest first"
    end
  end

  describe "FeedFiltersModalContentLive.types_summary/2" do
    test "returns 'All' when neither include nor exclude has entries for the field" do
      assert FeedFiltersModalContentLive.types_summary(%{}, :object_types) == "All"

      assert FeedFiltersModalContentLive.types_summary(
               %{object_types: [], exclude_object_types: []},
               :object_types
             ) == "All"
    end

    test "returns 'N only' when only include is populated" do
      assert FeedFiltersModalContentLive.types_summary(
               %{object_types: [:post, :article]},
               :object_types
             ) == "2 only"
    end

    test "returns 'N hidden' when only exclude is populated" do
      assert FeedFiltersModalContentLive.types_summary(
               %{exclude_object_types: [:post]},
               :object_types
             ) == "1 hidden"
    end

    test "returns a compound label when both lists have entries" do
      summary =
        FeedFiltersModalContentLive.types_summary(
          %{object_types: [:post, :article], exclude_object_types: [:event]},
          :object_types
        )

      # interpolation order depends on locale; both counts must appear
      assert summary =~ "2"
      assert summary =~ "1"
      assert summary =~ "only"
      assert summary =~ "hidden"
    end
  end

  describe "FeedFiltersModalContentLive.circles_summary/1" do
    test "returns 'None' when no circles are selected" do
      assert FeedFiltersModalContentLive.circles_summary(%{}) == "None"
      assert FeedFiltersModalContentLive.circles_summary(%{subject_circles: []}) == "None"
    end

    test "returns 'N selected' when circles are selected" do
      assert FeedFiltersModalContentLive.circles_summary(%{subject_circles: ["id1"]}) ==
               "1 selected"

      assert FeedFiltersModalContentLive.circles_summary(%{
               subject_circles: ["id1", "id2", "id3"]
             }) ==
               "3 selected"
    end
  end
end
