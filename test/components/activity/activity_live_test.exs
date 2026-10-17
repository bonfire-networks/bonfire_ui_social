defmodule Bonfire.UI.Social.ActivityLiveTest do
  use ExUnit.Case, async: true

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  alias Bonfire.UI.Social.ActivityLive

  @group %{id: "group", profile: %{name: "Fermo"}}

  describe "published_in_placement/2" do
    test "gives a plain group post its own top-line row" do
      assert :standalone =
               ActivityLive.published_in_placement(
                 %{published_in: @group, verb: :create, showing_within: :feed},
                 nil
               )
    end

    test "is hidden inside the group or topic itself" do
      assert :hidden =
               ActivityLive.published_in_placement(
                 %{published_in: @group, verb: :create, showing_within: :group},
                 nil
               )
    end

    test "on a group's page, hides the group's own posts but labels those from its topics" do
      group = Map.put(@group, :character, %{outbox_id: "group_outbox"})
      topic = %{id: "topic", profile: %{name: "Gardens"}, character: %{outbox_id: "topic_outbox"}}
      page = %{verb: :create, showing_within: :group, feed_id: ["group_outbox", "topic_outbox"]}

      assert :hidden =
               ActivityLive.published_in_placement(Map.put(page, :published_in, group), nil)

      assert :standalone =
               ActivityLive.published_in_placement(Map.put(page, :published_in, topic), nil)

      # a topic's auto-boost into the group page: its attribution line is hidden, so the row stands alone
      assert :standalone =
               ActivityLive.published_in_placement(
                 page |> Map.put(:published_in, topic) |> Map.put(:verb, :boost),
                 "topic"
               )

      # a person's boost: the attribution line is hidden inside the group, so the chip can't chain onto it
      assert :standalone =
               ActivityLive.published_in_placement(
                 page |> Map.put(:published_in, topic) |> Map.put(:verb, :boost),
                 "alice"
               )
    end

    test "on a group's other tabs, still hides the group itself" do
      group =
        Map.put(@group, :character, %{outbox_id: "group_outbox", notifications_id: "group_notifs"})

      assert :hidden =
               ActivityLive.published_in_placement(
                 %{
                   published_in: group,
                   verb: :create,
                   showing_within: :group,
                   feed_id: "group_notifs"
                 },
                 nil
               )
    end

    test "chains onto a person's boost, but not a group's own auto-boost" do
      boost = %{published_in: @group, verb: :boost, showing_within: :feed}

      assert :chained = ActivityLive.published_in_placement(boost, "alice")
      assert :standalone = ActivityLive.published_in_placement(boost, "group")
    end

    test "falls back to the standalone row when the subject line is hidden" do
      assert :standalone =
               ActivityLive.published_in_placement(
                 %{
                   published_in: @group,
                   verb: :boost,
                   showing_within: :feed,
                   hide_activity: "subject"
                 },
                 "alice"
               )
    end

    test "is hidden when there is no context, or none nameable without a DB round-trip" do
      assert :hidden = ActivityLive.published_in_placement(%{published_in: nil}, nil)

      assert :hidden =
               ActivityLive.published_in_placement(
                 %{
                   published_in: "01K36J7G8R4PN6X4FJ9WQ2ZTCE",
                   verb: :create,
                   showing_within: :feed
                 },
                 nil
               )
    end

    test "is hidden on the group's own feed" do
      assert :hidden =
               ActivityLive.published_in_placement(
                 %{published_in: @group, verb: :create, showing_within: :feed, feed_id: "group"},
                 nil
               )
    end

    test "is hidden while the activity is the page's main object, or an inception preview" do
      base = %{published_in: @group, verb: :create, showing_within: :feed}

      assert :hidden =
               ActivityLive.published_in_placement(Map.put(base, :viewing_main_object, true), nil)

      assert :hidden =
               ActivityLive.published_in_placement(
                 Map.put(base, :activity_inception, "preview"),
                 nil
               )
    end

    test "is hidden when the card renders no body to attach the context to" do
      base = %{published_in: @group, verb: :create, showing_within: :feed}

      assert :hidden =
               ActivityLive.published_in_placement(
                 Map.put(base, :custom_preview, SomeWidgetLive),
                 nil
               )

      assert :hidden =
               ActivityLive.published_in_placement(Map.put(base, :hide_activity, "all"), nil)
    end

    test "never chains in contexts whose subject line has nothing to attach to" do
      for showing_within <- [:widget, :notifications, :smart_input, :pinned, :search] do
        assert :standalone =
                 ActivityLive.published_in_placement(
                   %{published_in: @group, verb: :boost, showing_within: showing_within},
                   "alice"
                 ),
               "expected #{showing_within} to keep the standalone row"
      end
    end
  end
end
