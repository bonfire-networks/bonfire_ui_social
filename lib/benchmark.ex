defmodule Bonfire.UI.Social.Benchmark do
  @endpoint Bonfire.Web.Endpoint
  import Phoenix.ConnTest
  alias Bonfire.Common.Config
  # import Untangle

  # NOTE: make sure you populate your local with seeds first, and then call these functions in iex

  def feed_queries do
    Logger.configure(level: :info)

    Benchee.run(
      md_lib_feed_queries(),
      # some_feed_queries(),
      parallel: 1,
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

  defp md_lib_feed_queries do
    %{
      "render activities with earmark" => fn ->
        Config.put(:markdown_library, :earmark)
        live_feed(limit: 10)
      end,
      "render activities with mdex" => fn ->
        Config.put(:markdown_library, nil)
        live_feed(limit: 10)
      end
    }
  end

  defp some_feed_queries do
    %{
      "query 1 activity" => fn ->
        Bonfire.Social.FeedActivities.feed(:local, limit: 1)
      end,
      "query 10 activities" => fn ->
        Bonfire.Social.FeedActivities.feed(:local, limit: 10)
      end,
      "query 20 activities" => fn ->
        Bonfire.Social.FeedActivities.feed(:local, limit: 20)
      end
    }
  end

  def feed_query_methods do
    Logger.configure(level: :info)

    Benchee.run(
      %{
        "minimal join/preloads, with boundaries applied" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, preload: :with_object)
        end,
        "minimal join/preloads, without boundaries applied" => fn ->
          Bonfire.Social.FeedActivities.feed(:local,
            skip_boundary_check: true,
            preload: :with_object
          )
        end,
        # "caching preloads, with boundaries applied" => fn ->
        #   Bonfire.Social.FeedActivities.feed(:local)
        #   |> Bonfire.Social.Feeds.LiveHandler.preloads(with_cache: true)
        # end,
        # "caching preloads, without boundaries applied " => fn ->
        #   Bonfire.Social.FeedActivities.feed(:local, skip_boundary_check: true)
        #   |> Bonfire.Social.Feeds.LiveHandler.preloads(with_cache: true)
        # end,
        "full join/preloads, with boundaries applied" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, preload: :feed)
        end,
        "full join/preloads, without boundaries applied" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, skip_boundary_check: true, preload: :feed)
        end
        # "AP:shared_outbox" => fn -> ActivityPub.Web.ObjectView.render("outbox.json", %{outbox: :shared_outbox}) end
      },
      parallel: 1,
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

  def feed_queries_without_benchee do
    Logger.configure(level: :error)

    Enum.each(
      some_feed_queries(),
      fn {name, fun} ->
        IO.inspect(name)

        for _ <- 0..10 do
          Bonfire.Common.Benchmark.apply_timed(fun)
        end
      end
    )

    Logger.configure(level: :info)
  end

  def feed_page do
    Logger.configure(level: :info)
    conn = build_conn()

    feed = Bonfire.Social.FeedActivities.feed(:local, limit: 20)

    Benchee.run(
      %{
        # "fetch feed page with 1 activity" => fn -> get(conn, "/feed/local?limit=1") end,
        # "fetch feed page with 10 activities" => fn -> get(conn, "/feed/local?limit=10") end,
        "fetch feed page with 20 activities" => fn -> get(conn, "/feed/local?limit=20") end,

        # "render feed component with 10 activities (not incl. async preloads)" => fn -> live_feed(limit: 10, enable_async_preloads: true) end,
        "query & render feed component with 20 activities (not incl. async preloads)" => fn ->
          live_feed(limit: 20, enable_async_preloads: true)
        end,

        # "render feed component with 10 activities  (incl. preloads)" => fn -> live_feed(limit: 10, enable_async_preloads: false) end,
        "query & render feed component with 20 activities (incl. preloads)" => fn ->
          live_feed(limit: 20, enable_async_preloads: false)
        end,
        "render feed component with 20 already queried activities (incl. preloads)" => fn ->
          render_feed(feed.edges, enable_async_preloads: false)
        end,
        "render feed component with 20 already queried activities (not incl. async preloads)" =>
          fn ->
            render_feed(feed.edges, enable_async_preloads: true)
          end,

        # "fetch feed page with 1 (skipped) activity" => fn ->
        #   get(conn, "/feed/local?limit=1&hide_activities=component")
        # end,
        # "fetch feed page with 10 (skipped) activities" => fn ->
        #   get(conn, "/feed/local?limit=10&hide_activities=component")
        # end,
        "fetch feed page with 20 (skipped) activities" => fn ->
          get(conn, "/feed/local?limit=20&hide_activities=component")
        end,
        # "fetch feed page with 1 (not rendered) activity" => fn ->
        #   get(conn, "/feed/local?limit=1&hide_activities=all")
        # end,
        # "fetch feed page with 10 (not rendered) activities" => fn ->
        #   get(conn, "/feed/local?limit=10&hide_activities=all")
        # end,
        "fetch feed page with 20 (not rendered) activities" => fn ->
          get(conn, "/feed/local?limit=20&hide_activities=all")
        end
      },
      parallel: 1,
      warmup: 2,
      time: 25,
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

  def live_feed(opts \\ []) do
    feed = Bonfire.Social.FeedActivities.feed(:local, opts)

    render_feed(feed.edges, opts)
  end

  def render_feed(feed, opts \\ []) do
    Process.put(:enable_async_preloads, opts[:enable_async_preloads] || true)

    Bonfire.UI.Common.Testing.Helpers.render_stateful(Bonfire.UI.Social.FeedLive, %{
      feed: feed
    })
  end
end
