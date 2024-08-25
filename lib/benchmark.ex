defmodule Bonfire.UI.Social.Benchmark do
  @endpoint Bonfire.Web.Endpoint
  import Phoenix.ConnTest
  alias Bonfire.Common.Utils
  # import Bonfire.UI.Common.Testing.Helpers
  # import Phoenix.LiveViewTest
  alias Bonfire.Common.Config
  # import Untangle

  # NOTE: make sure you populate your local with seeds first, and then call these functions in iex

  # @log_level :error
  @log_level String.to_existing_atom(System.get_env("DEV_LOG_LEVEL", "debug"))

  def feed_backend do
    Logger.configure(level: @log_level)

    Utils.maybe_apply(
      Benchee,
      :run,
      [
        some_feed_queries(),
        # current_user_approaches_feed(),
        [
          parallel: 1,
          warmup: 2,
          time: 15,
          memory_time: 2,
          reduction_time: 2,
          profile_after: true,
          formatters: formatters("benchmarks/output/feed_queries.html")
        ]
      ]
    )
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
      end,
      "query 1 without boundaries" => fn ->
        Bonfire.Social.FeedActivities.feed(:local, limit: 1, skip_boundary_check: true)
      end,
      "query 10 without boundaries" => fn ->
        Bonfire.Social.FeedActivities.feed(:local, limit: 10, skip_boundary_check: true)
      end,
      "query 20 without boundaries" => fn ->
        Bonfire.Social.FeedActivities.feed(:local, limit: 20, skip_boundary_check: true)
      end,
      "query 1 with 1 year time limit" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
        Bonfire.Social.FeedActivities.feed(:local, limit: 1)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 10 with 1 year time limit" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
        Bonfire.Social.FeedActivities.feed(:local, limit: 10)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 20 with 1 year time limit" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
        Bonfire.Social.FeedActivities.feed(:local, limit: 20)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 1 with 1 year time limit, without boundaries" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
        Bonfire.Social.FeedActivities.feed(:local, limit: 1, skip_boundary_check: true)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 10 with 1 year time limit, without boundaries" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
        Bonfire.Social.FeedActivities.feed(:local, limit: 10, skip_boundary_check: true)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 20 with 1 year time limit, without boundaries" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
        Bonfire.Social.FeedActivities.feed(:local, limit: 20, skip_boundary_check: true)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 1 with no time limit" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
        Bonfire.Social.FeedActivities.feed(:local, limit: 1)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 10 with no time limit" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
        Bonfire.Social.FeedActivities.feed(:local, limit: 10)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 20 with no time limit" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
        Bonfire.Social.FeedActivities.feed(:local, limit: 20)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 1 with no time limit, without boundaries" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
        Bonfire.Social.FeedActivities.feed(:local, limit: 1, skip_boundary_check: true)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 10 with no time limit, without boundaries" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
        Bonfire.Social.FeedActivities.feed(:local, limit: 10, skip_boundary_check: true)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end,
      "query 20 with no time limit, without boundaries" => fn ->
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
        Bonfire.Social.FeedActivities.feed(:local, limit: 20, skip_boundary_check: true)
        Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
      end
    }
  end

  # defp current_user_approaches_feed do
  #   conn = conn(user: fake_user!())

  #   %{
  #     "render activities with current_user in @__context__ assign" => fn ->
  #       Process.put(:approach_to_current_user, :user)
  #       get(conn, "/feed/local")
  #     end,
  #     "render activities with only ID in @__context__ assign" => fn ->
  #       Process.put(:approach_to_current_user, :id)
  #       get(conn, "/feed/local")
  #     end,
  #     "render activities with cached current_user" => fn ->
  #       Process.put(:approach_to_current_user, :cache)
  #       get(conn, "/feed/local")
  #     end
  #   }
  # end

  def feed_query_methods do
    Logger.configure(level: @log_level)

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
        [
          parallel: 1,
          warmup: 2,
          time: 10,
          memory_time: 2,
          reduction_time: 2,
          profile_after: true,
          formatters: formatters("benchmarks/output/feed_query_methods.html")
        ]
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

    Logger.configure(level: @log_level)
  end

  def feed_page do
    Logger.configure(level: @log_level)

    conn = build_conn()

    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
    feed = Bonfire.Social.FeedActivities.feed(:local)
    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)

    Utils.maybe_apply(
      Benchee,
      :run,
      # md_lib_feed(),
      [
        %{
          # "query & render entire feed page with activities" => fn -> live(conn, "/feed/local") end, # NOPE: LiveView helpers can only be invoked from the test process
          # "query & render feed component with activities (default preloads)" => fn ->
          #   live_feed()
          # end,
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
          "render feed component with pre-queried activities" => fn ->
            render_feed(feed.edges)
          end,
          # "render feed component with already queried activities (skipping preloads)" => fn ->
          #   render_feed(feed.edges, feed_live_update_many_preloads: :skip)
          # end,
          # "render feed component with already queried activities (inline preloads)" => fn ->
          #   render_feed(feed.edges, feed_live_update_many_preloads: :inline)
          # end,
          # "render feed component with already queried activities (async actions preloads)" =>
          #   fn ->
          #     render_feed(feed.edges, feed_live_update_many_preloads: :async_actions)
          #   end,
          # "render feed component with already queried activities (async preloads)" => fn ->
          #   render_feed(feed.edges, feed_live_update_many_preloads: :async)
          # end,
          # "render feed component with already queried activities (skip activity component)" => fn ->
          #   render_feed(feed.edges, hide_activities: "component")
          # end,
          # "render feed component with already queried activities (hide activity component)" => fn ->
          #   render_feed(feed.edges, hide_activities: "all")
          # end,
          # "render feed component with already queried activities (skip subject)" => fn ->
          #   render_feed(feed.edges, hide_activities: "subject")
          # end,
          # "render feed component with already queried activities (skip note)" => fn ->
          #   render_feed(feed.edges, hide_activities: "note")
          # end,
          # "render feed component with already queried activities (skip media)" => fn ->
          #   render_feed(feed.edges, hide_activities: "media")
          # end,
          # "render feed component with already queried activities (skip actions)" => fn ->
          #   render_feed(feed.edges, hide_activities: "actions")
          # end,
          # "render feed component with already queried activities (skip dynamic)" => fn ->
          #   render_feed(feed.edges, hide_activities: "dynamic")
          # end,
          # "fetch home page with activities" => fn -> get(conn, "/") end, # should be quick because cached

          "fetch feed page" => fn -> get(conn, "/feed/local?cache=skip") end,
          "fetch feed page with activities not rendered " => fn ->
            get(conn, "/feed/local?cache=skip&hide_activities=component")
          end,
          "fetch feed page with 1 year limit" => fn ->
            get(conn, "/feed/local?cache=skip&time_limit=365")
          end,
          "fetch feed page with 1 year limit & activities not rendered " => fn ->
            get(conn, "/feed/local?cache=skip&hide_activities=component&time_limit=365")
          end,
          "fetch feed page with 1 year limit & activity sub-components not rendered " => fn ->
            get(conn, "/feed/local?cache=skip&hide_activities=all&time_limit=365")
          end,
          "fetch feed page with no time limit" => fn ->
            get(conn, "/feed/local?cache=skip&time_limit=0")
          end,
          "fetch feed page with no time limit & activities not rendered " => fn ->
            get(conn, "/feed/local?cache=skip&hide_activities=component&time_limit=0")
          end,
          "fetch feed page with no time limit & activity sub-components not rendered " => fn ->
            get(conn, "/feed/local?cache=skip&hide_activities=all&time_limit=0")
          end

          # "fetch feed page with (not rendered) activities" => fn ->
          #   get(conn, "/feed/local?&hide_activities=all")
          # end,
          # "fetch feed page with not rendered subject" => fn ->
          #   get(conn, "/feed/local?&hide_activities=subject")
          # end,
          # "fetch feed page with not rendered note" => fn ->
          #   get(conn, "/feed/local?&hide_activities=note")
          # end,
          # "fetch feed page with not rendered media" => fn ->
          #   get(conn, "/feed/local?&hide_activities=media")
          # end,
          # "fetch feed page with not rendered actions" => fn ->
          #   get(conn, "/feed/local?&hide_activities=actions")
          # end,
          # "fetch feed page with not rendered dynamic component" => fn ->
          #   get(conn, "/feed/local?&hide_activities=dynamic")
          # end
        },
        [
          parallel: 1,
          warmup: 2,
          time: 15,
          memory_time: 2,
          reduction_time: 2,
          profile_after: true,
          formatters: formatters("benchmarks/output/feed_page.html")
        ]
      ]
    )

    # Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)

    Logger.configure(level: :debug)
  end

  # defp md_lib_feed do
  #   feed = Bonfire.Social.FeedActivities.feed(:fediverse, limit: 20)

  #   %{
  #     "render activities with earmark" => fn ->
  #       Config.put(:markdown_library, Earmark)
  #       render_feed(feed.edges)
  #     end,
  #     "render activities with mdex" => fn ->
  #       Config.put(:markdown_library, MDEx)
  #       render_feed(feed.edges)
  #     end
  #   }
  # end

  def feed_render_page do
    Logger.configure(level: @log_level)
    _conn = build_conn()

    feed = Bonfire.Social.FeedActivities.feed(:local)

    Utils.maybe_apply(
      Benchee,
      :run,
      [
        %{
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
        [
          parallel: 1,
          warmup: 2,
          time: 25,
          memory_time: 2,
          reduction_time: 2,
          profile_after: true,
          formatters: formatters("benchmarks/output/feed_page.html")
        ]
      ]
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

    Bonfire.UI.Common.Testing.Helpers.render_stateful(
      Bonfire.UI.Social.FeedLive,
      Enum.into(opts, %{
        feed: feed
      })
    )
  end

  if Config.get(:env) == :prod do
    defp formatters(_file) do
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
