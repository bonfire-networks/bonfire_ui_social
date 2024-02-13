defmodule Bonfire.UI.Social.Benchmark do
  @endpoint Bonfire.Web.Endpoint
  import Phoenix.ConnTest
  alias Bonfire.Common.Utils
  # import Phoenix.LiveViewTest
  alias Bonfire.Common.Config
  # import Untangle

  # NOTE: make sure you populate your local with seeds first, and then call these functions in iex

  def feed do
    Logger.configure(level: :info)
    Utils.maybe_apply(
    Benchee,
    :run,
    [
      md_lib_feed(),
      # some_feed_queries(),
      [parallel: 2,
      warmup: 2,
      time: 10,
      memory_time: 2,
      reduction_time: 2,
      profile_after: true,
      formatters: formatters("benchmarks/output/feed_queries.html")]]
    )
  end

  defp md_lib_feed do
    feed = Bonfire.Social.FeedActivities.feed(:fediverse, limit: 20)

    %{
      "render activities with earmark" => fn ->
        Config.put(:markdown_library, Earmark)
        render_feed(feed.edges)
      end,
      "render activities with mdex" => fn ->
        Config.put(:markdown_library, MDEx)
        render_feed(feed.edges)
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
    Utils.maybe_apply(
    Benchee,
    :run,
    [
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
     [ parallel: 1,
      warmup: 2,
      time: 10,
      memory_time: 2,
      reduction_time: 2,
      profile_after: true,
      formatters: formatters("benchmarks/output/feed_query_methods.html")]
    ])
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

    feed = Bonfire.Social.FeedActivities.feed(:local)
    Utils.maybe_apply(
    Benchee,
    :run,
    [
      %{
        "fetch feed page with activities" => fn -> get(conn, "/feed/local") end,
        # "query & render entire feed page with activities" => fn -> live(conn, "/feed/local") end, # NOPE: LiveView helpers can only be invoked from the test process
        # "query & render feed component with activities (using all async preloads)" => fn ->
        #   live_feed(live_update_many_preloads: :async)
        # end,
        # "query & render feed component with activities (inline all preloads)" => fn ->
        #   live_feed(live_update_many_preloads: :inline)
        # end,
        # "query & render feed component with activities (skipping all preloads)" => fn ->
        #   live_feed(live_update_many_preloads: :skip)
        # end,
        # "query & render feed component with activities (using feed async preloads)" => fn ->
        #   live_feed(feed_live_update_many_preloads: :async_total) # FIXME
        # end,
        # "query & render feed component with activities (inline feed preloads)" => fn ->
        #   live_feed(feed_live_update_many_preloads: :inline)
        # end,
        # "query & render feed component with activities (inline + async actions)" => fn ->
        #   live_feed(feed_live_update_many_preloads: :async_actions)
        # end,
        # "query & render feed component with activities (skipping feed preloads)" => fn ->
        #   live_feed(feed_live_update_many_preloads: :skip)
        # end,
        "render feed component with already queried activities (skipping preloads)" => fn ->
          render_feed(feed.edges, feed_live_update_many_preloads: :skip)
        end,
        "render feed component with already queried activities (inline preloads)" => fn ->
          render_feed(feed.edges, feed_live_update_many_preloads: :inline)
        end,
        "render feed component with already queried activities (async actions preloads)" => fn ->
          render_feed(feed.edges, feed_live_update_many_preloads: :async_actions)
        end,
        "render feed component with already queried activities (async preloads)" => fn ->
          render_feed(feed.edges, feed_live_update_many_preloads: :async)
        end
        # "fetch feed page with (skipped) activities" => fn ->
        #   get(conn, "/feed/local?&hide_activities=component")
        # end,
        # "fetch feed page with (not rendered) activities" => fn ->
        #   get(conn, "/feed/local?&hide_activities=all")
        # end
      },
      [parallel: 1,
      warmup: 2,
      time: 25,
      memory_time: 2,
      reduction_time: 2,
      profile_after: true,
      formatters: formatters("benchmarks/output/feed_page.html")]]
    )

    Logger.configure(level: :debug)
  end

  def feed_render_page do
    Logger.configure(level: :info)
    _conn = build_conn()

    feed = Bonfire.Social.FeedActivities.feed(:local)
    Utils.maybe_apply(
    Benchee,
    :run,
      [%{
        # "render feed component with already queried activities (skipping preloads)" => fn ->
        #   render_feed(feed.edges, live_update_many_preloads: :skip)
        # end,
        # "render feed component with already queried activities (using async preloads)" => fn ->
        #   render_feed(feed.edges, live_update_many_preloads: :async)
        # end,
        "render feed component with already queried activities (inline preloads)" => fn ->
          render_feed(feed.edges, live_update_many_preloads: :inline)
        end
      },
      [parallel: 1,
      warmup: 2,
      time: 25,
      memory_time: 2,
      reduction_time: 2,
      profile_after: true,
      formatters: formatters("benchmarks/output/feed_page.html")]]
    )

    Logger.configure(level: :debug)
  end

  def live_feed(opts \\ []) do
    feed = Bonfire.Social.FeedActivities.feed(:local, opts)

    render_feed(feed.edges, opts)
  end

  def render_feed(feed, opts \\ []) do
    Process.put(:live_update_many_preloads, opts[:live_update_many_preloads])
    Process.put(:feed_live_update_many_preloads, opts[:feed_live_update_many_preloads])

    Bonfire.UI.Common.Testing.Helpers.render_stateful(Bonfire.UI.Social.FeedLive, %{
      feed: feed
    })
  end

  if Config.get(:env) == :prod do
    defp formatters(file) do
      [
        Benchee.Formatters.Console
      ]
    end
  else
    defp formatters(file) do
      [
        {Benchee.Formatters.HTML, file: file},
        Benchee.Formatters.Console
      ]
    end
  end
end
