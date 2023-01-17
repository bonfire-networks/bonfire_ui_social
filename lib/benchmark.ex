defmodule Bonfire.UI.Social.Benchmark do
  @endpoint Bonfire.Web.Endpoint
  import Phoenix.ConnTest

  def feed_query_methods do
    # NOTE: make sure you populate your local with seeds first, and then copy paste this in iex
    Logger.configure(level: :info)

    Benchee.run(
      %{
        "minimal join/preloads, with boundaries applied" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, preloads: :with_object)
        end,
        "minimal join/preloads, without boundaries applied" => fn ->
          Bonfire.Social.FeedActivities.feed(:local,
            skip_boundary_check: true,
            preloads: :with_object
          )
        end,
        "caching preloads, with boundaries applied" => fn ->
          Bonfire.Social.FeedActivities.feed(:local)
          |> Bonfire.Social.Feeds.LiveHandler.preloads(with_cache: true)
        end,
        "caching preloads, without boundaries applied " => fn ->
          Bonfire.Social.FeedActivities.feed(:local, skip_boundary_check: true)
          |> Bonfire.Social.Feeds.LiveHandler.preloads(with_cache: true)
        end,
        "full join/preloads, with boundaries applied" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, preloads: :feed)
        end,
        "full join/preloads, without boundaries applied" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, skip_boundary_check: true, preloads: :feed)
        end
        # "AP:shared_outbox" => fn -> ActivityPubWeb.ObjectView.render("outbox.json", %{outbox: :shared_outbox}) end
      },
      parallel: 10,
      warmup: 2,
      time: 5,
      memory_time: 2,
      reduction_time: 2,
      profile_after: true,
      formatters: [
        {Benchee.Formatters.HTML, file: "benchmarks/output/feed_query_methods.html"},
        Benchee.Formatters.Console
      ]
    )
  end

  def feed_queries do
    # NOTE: make sure you populate your local with seeds first, and then copy paste this in iex
    Logger.configure(level: :info)

    Benchee.run(
      %{
        "query 1 activity" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, preloads: :feed, limit: 1)
        end,
        "query 10 activities" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, preloads: :feed, limit: 10)
        end,
        "query 20 activities" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, preloads: :feed, limit: 20)
        end
      },
      parallel: 10,
      warmup: 2,
      time: 5,
      memory_time: 2,
      reduction_time: 2,
      profile_after: true,
      formatters: [
        {Benchee.Formatters.HTML, file: "benchmarks/output/feed_queries.html"},
        Benchee.Formatters.Console
      ]
    )
  end

  def feed_page do
    Logger.configure(level: :info)
    conn = build_conn()

    Benchee.run(
      %{
        "fetch feed page with 1 activity" => fn -> get(conn, "/feed/local?limit=1") end,
        "fetch feed page with 10 activities" => fn -> get(conn, "/feed/local?limit=10") end,
        "fetch feed page with 20 activities" => fn -> get(conn, "/feed/local?limit=20") end,
        "fetch feed page with 1 (hidden) activity" => fn ->
          get(conn, "/feed/local?limit=1&hide_activities=1")
        end,
        "fetch feed page with 10 (hidden) activities" => fn ->
          get(conn, "/feed/local?limit=10&hide_activities=1")
        end,
        "fetch feed page with 20 (hidden) activities" => fn ->
          get(conn, "/feed/local?limit=20&hide_activities=1")
        end
      },
      parallel: 1,
      warmup: 2,
      time: 10,
      memory_time: 2,
      reduction_time: 2,
      profile_after: true,
      formatters: [
        {Benchee.Formatters.HTML, file: "benchmarks/output/feed_page.html"},
        Benchee.Formatters.Console
      ]
    )

    Logger.configure(level: :debug)
  end
end
