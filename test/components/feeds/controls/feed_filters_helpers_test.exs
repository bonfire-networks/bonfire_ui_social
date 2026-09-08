defmodule Bonfire.UI.Social.FeedFiltersHelpersTest do
  @moduledoc "Coverage for filter transitions, scope-preserving Reset and row summaries."
  use ExUnit.Case, async: true

  # bucket this into the ui CI leg: bare `ExUnit.Case` skips the tag the extension case templates apply, so without it this also runs in the federation job catch-all
  @moduletag :ui

  alias Bonfire.UI.Social.ToggleTypeLive
  alias Bonfire.UI.Social.FeedFiltersModalContentLive
  doctest FeedFiltersModalContentLive

  test "Any media uses the host's options and preserves other filters" do
    attrs = %{
      __context__: %{},
      sections: [:media_types],
      media_types: [:image, :research],
      feed_filters: %{exclude_media_types: [:image], time_limit: 30}
    }

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = FeedFiltersModalContentLive.update(attrs, socket)

    {:noreply, selected} = FeedFiltersModalContentLive.handle_event("any_media", %{}, socket)

    assert selected.assigns.pending_filters == %{
             media_types: [:image, :research],
             exclude_media_types: [],
             time_limit: 30
           }

    assert FeedFiltersModalContentLive.any_media?(
             selected.assigns.pending_filters,
             attrs.media_types
           )

    assert FeedFiltersModalContentLive.media_summary(
             selected.assigns.pending_filters,
             attrs.media_types
           ) == "Any media"

    {:noreply, cleared} = FeedFiltersModalContentLive.handle_event("clear_media", %{}, selected)
    assert cleared.assigns.pending_filters.time_limit == 30

    refute FeedFiltersModalContentLive.any_media?(
             cleared.assigns.pending_filters,
             attrs.media_types
           )

    assert FeedFiltersModalContentLive.media_summary(
             cleared.assigns.pending_filters,
             attrs.media_types
           ) == "Any"
  end

  test "Any media is not selected for exclusions, extra types or an empty option list" do
    refute FeedFiltersModalContentLive.any_media?(
             %{media_types: [:image], exclude_media_types: [:video]},
             [:image]
           )

    refute FeedFiltersModalContentLive.any_media?(%{media_types: [:image, :research]}, [:image])
    refute FeedFiltersModalContentLive.any_media?(%{}, [])
  end

  test "specific instance input stays hidden for local origins" do
    for origin <- [nil, :all, :local, [:local], "local", ["local"], []] do
      refute FeedFiltersModalContentLive.show_instances?(%{origin: origin})
    end

    for origin <- [:remote, [:remote], ["mastodon.social"]] do
      assert FeedFiltersModalContentLive.show_instances?(%{origin: origin})
    end
  end

  test "circle toggles use the generic handler and section Reset clears both directions" do
    attrs = %{__context__: %{}, sections: [], feed_filters: %{time_limit: 30}}
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = FeedFiltersModalContentLive.update(attrs, socket)

    toggle = %{
      "toggle" => "subject_circles",
      "toggle_type" => "circle-one",
      "toggle_value" => "true"
    }

    {:noreply, included} = FeedFiltersModalContentLive.handle_event("set_filter", toggle, socket)
    assert included.assigns.pending_filters.subject_circles == ["circle-one"]

    {:noreply, hidden} =
      FeedFiltersModalContentLive.handle_event(
        "set_filter",
        %{toggle | "toggle_value" => "false"},
        included
      )

    assert hidden.assigns.pending_filters.subject_circles == []
    assert hidden.assigns.pending_filters.exclude_subject_circles == ["circle-one"]

    hidden = Phoenix.Component.assign(hidden, :sections, [:circles])
    {:noreply, reset} = FeedFiltersModalContentLive.handle_event("reset_pending", %{}, hidden)
    assert reset.assigns.pending_filters == %{time_limit: 30}

    assert FeedFiltersModalContentLive.filters_to_apply(
             reset.assigns.pending_filters,
             hidden.assigns.pending_filters
           ) ==
             %{time_limit: 30, subject_circles: [], exclude_subject_circles: []}
  end

  test "drafts survive updates from the same host and reset when the host changes" do
    attrs = %{
      __context__: %{},
      feed_filters: %{},
      sections: [:hashtags],
      context_key: {:profile, "alice"},
      apply_to: :parent
    }

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = FeedFiltersModalContentLive.update(attrs, socket)

    {:noreply, edited} =
      FeedFiltersModalContentLive.handle_event("set_tags", %{"tags_text" => "#bonfire"}, socket)

    refute_received {FeedFiltersModalContentLive, :apply, _}
    {:ok, same_host} = FeedFiltersModalContentLive.update(attrs, edited)
    {:noreply, _} = FeedFiltersModalContentLive.handle_event("apply", %{}, same_host)
    assert_received {FeedFiltersModalContentLive, :apply, %{tags: ["bonfire"]}}

    {:ok, other_host} =
      FeedFiltersModalContentLive.update(%{attrs | context_key: {:profile, "bob"}}, edited)

    {:noreply, _} = FeedFiltersModalContentLive.handle_event("apply", %{}, other_host)
    assert_received {FeedFiltersModalContentLive, :apply, filters}
    assert filters == %{}
    assert other_host.assigns.pending_tags_text == ""
  end

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
