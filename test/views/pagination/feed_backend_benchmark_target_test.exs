defmodule Bonfire.UI.Social.Feeds.FeedBackendBenchmarkTargetTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  use Bonfire.Common.Config

  alias Bonfire.Posts
  alias Bonfire.Social.FeedActivities

  setup do
    original_deferred = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
    original_time_limit = Config.get([Bonfire.UI.Social.FeedLive, :time_limit], 7)

    Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], true)
    repo().delete_all(Bonfire.Data.Social.FeedPublish)

    on_exit(fn ->
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_deferred)
      Config.put([Bonfire.UI.Social.FeedLive, :time_limit], original_time_limit)
    end)

    %{viewer: fake_user!()}
  end

  test "feed_backend target uses the normal no-time-limit local feed path", %{viewer: viewer} do
    with_pagination_hard_max_limit(500)

    for n <- 1..3 do
      assert {:ok, _post} =
               Posts.publish(
                 current_user: viewer,
                 boundary: "public",
                 post_attrs: %{post_content: %{html_body: "<p>benchmark target #{n}</p>"}}
               )
    end

    assert %{edges: edges, page_info: page_info} = Bonfire.UI.Social.Benchmark.feed_full_backend()
    assert length(edges) > 0
    assert is_map(page_info)

    query_string =
      with_feed_time_limit(0, fn ->
        FeedActivities.feed(:local, limit: 20, return: :query)
      end)
      |> Inspect.Ecto.Query.to_string()

    assert query_string =~ " in subquery(from"
    assert query_string =~ "f0.feed_id == ^\"3SERSFR0MY0VR10CA11NSTANCE\""
    refute query_string =~ "is_nil(c5.id) or is_nil(p6.peer_id)"

    assert %{rows: [[indexdef]]} =
             repo().query!(
               """
               select indexdef
               from pg_indexes
               where tablename = $1 and indexname = $2
               """,
               [
                 "bonfire_data_social_feed_publish",
                 "bonfire_data_social_feed_publish_feed_id_id_idx"
               ]
             )

    assert indexdef =~ "(feed_id, id)"

    without_boundaries_string =
      with_feed_time_limit(0, fn ->
        FeedActivities.feed(:local, limit: 20, return: :query, skip_boundary_check: true)
      end)
      |> Inspect.Ecto.Query.to_string()

    assert query_string != without_boundaries_string
  end

  defp with_feed_time_limit(days, fun) do
    previous = Config.get([Bonfire.UI.Social.FeedLive, :time_limit], 7)
    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], days)

    try do
      fun.()
    after
      Config.put([Bonfire.UI.Social.FeedLive, :time_limit], previous)
    end
  end

  defp with_pagination_hard_max_limit(limit) do
    key = [:bonfire, :pagination_hard_max_limit]
    previous = Process.get(key)

    Process.put(key, limit)

    on_exit(fn ->
      if is_nil(previous),
        do: Process.delete(key),
        else: Process.put(key, previous)
    end)
  end
end
