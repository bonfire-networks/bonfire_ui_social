defmodule Bonfire.UI.Social.ProfileFeedFilterReloadTest do
  @moduledoc """
  Simulates the exact filter evolution of a profile feed when the user clicks
  "Show older activities" (the `set_filter` time_limit=0 path) AFTER an async
  initial load has replaced the component's `feed_filters` with the
  validated/parameterized filters returned by `feed_assigns`.

  On prod this reload comes back EMPTY and (combined with reset_stream: true)
  wipes the already-visible activity — this test checks the requery still
  returns the user's activities.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  use Bonfire.Common.Utils
  use Bonfire.Common.Config

  alias Bonfire.Social.{FeedFilters, FeedLoader}
  alias Bonfire.Social.Feeds.LiveHandler
  alias Bonfire.Common.DatesTimes

  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]

  setup do
    original_config = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
    # production default
    Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], true)

    on_exit(fn ->
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_config)
    end)

    repo().delete_all(Bonfire.Data.Social.FeedPublish)

    account = fake_account!()
    alice = fake_user!(account)
    bob = fake_user!(account)

    fake_post!(alice, "public", %{
      post_content: %{
        summary: "recent post",
        html_body: "<p>Only recent activity</p>"
      },
      id: DatesTimes.past(2, :day) |> DatesTimes.generate_ulid()
    })

    %{alice: alice, bob: bob}
  end

  test "requery after merging time_limit: 0 into async-validated filters still finds activities",
       %{alice: alice, bob: bob} do
    opts = [current_user: bob]

    # 1. what ProfileLive passes on mount: params + by
    initial_filters = %{by: id(alice), feed_name: :user_activities}

    # 2. what the async initial load computes (and sends back to the component
    # as its new `feed_filters` assign)
    {validated_filters, _assigns, preloads, _postloads} =
      LiveHandler.prepare_filters_assigns_preloads_posloads(initial_filters, opts)

    feed1 =
      FeedLoader.feed(:user_activities, validated_filters, opts ++ [preload: preloads])

    assert length(feed1.edges) == 1,
           "initial profile feed should contain the recent activity"

    # 3. what FeedLive.set_filters does on "Show older activities":
    # validate ONLY the incoming attrs, then merge onto the component's filters
    {:ok, new_filters} = FeedFilters.validate(%{time_limit: "0"})

    merged =
      Bonfire.Common.Enums.merge_as_map(validated_filters, new_filters)

    # 4. what reload → feed_assigns does with the merged filters
    case LiveHandler.prepare_filters_assigns_preloads_posloads(
           Map.put(merged, :feed_name, :user_activities),
           opts
         ) do
      {refiltered, _assigns, preloads2, _} ->
        feed2 =
          FeedLoader.feed(:user_activities, refiltered, opts ++ [preload: preloads2])

        assert length(feed2.edges) == 1,
               "reload with time_limit=0 must still return the activity (got: #{inspect(refiltered, pretty: true)})"

      other ->
        flunk(
          "prepare_filters_assigns_preloads_posloads errored on merged filters: #{inspect(other, pretty: true)}\nmerged: #{inspect(merged, pretty: true)}"
        )
    end
  end
end
