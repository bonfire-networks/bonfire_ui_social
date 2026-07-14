defmodule Bonfire.UI.Social.Benchmark do
  @endpoint Bonfire.Web.Endpoint
  import Phoenix.ConnTest
  alias Bonfire.Common.Utils
  import Bonfire.UI.Common.Testing.Helpers
  # import Phoenix.LiveViewTest
  use Bonfire.Common.Config
  import Untangle

  # NOTE: make sure you populate your local with seeds first, and then call these functions in iex

  @log_level :info
  # @log_level String.to_existing_atom(System.get_env("DEV_LOG_LEVEL", "debug"))

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

  @boundarise_strategies %{
    "summary_subquery" => [boundarise_strategy: :summary_subquery],
    "summary_view" => [boundarise_strategy: :view],
    "direct_exists" => [boundarise_strategy: :direct_exists],
    "no_boundaries_floor" => [skip_boundary_check: true]
  }

  @doc """
  Benchmarks the boundarised :see/:read check under each `boundarise_strategy`, against EXISTING data — read-only, safe on production (run in `bin/bonfire remote`, where the no-Benchee fallback kicks in).

  Options (env vars so they work the same in iex and mix):
  - `BENCH_SUBJECTS=3` how many recent local users to benchmark as viewers (+ anon)
  - `BENCH_LIMIT=20` feed page size
  - `BENCH_THREAD_ID=...` thread for the replies scenario (uuid or ulid); defaults to the thread with the most replies
  - `BENCH_TIME=5` seconds per Benchee scenario
  - `BENCH_ITERATIONS=10` iterations per scenario in the no-Benchee fallback
  """
  def boundarise_strategies do
    Logger.configure(level: :critical)
    # without this, feeds on instances with older data return 0 edges and the benchmark
    # measures empty queries
    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)

    run_scenarios(boundarise_strategy_queries(), "boundarise_strategies")

    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
    Logger.configure(level: @log_level)
  end

  # shared Benchee-or-fallback runner (the fallback kicks in on releases, where Benchee
  # isn't shipped — read the medians across iterations there)
  defp run_scenarios(scenarios, output_name) do
    if Code.ensure_loaded?(Benchee) do
      Utils.maybe_apply(Benchee, :run, [
        scenarios,
        [
          parallel: 1,
          warmup: 2,
          time: String.to_integer(System.get_env("BENCH_TIME", "5")),
          formatters: formatters("benchmarks/output/#{output_name}.html")
        ]
      ])
    else
      info("Benchee not available — falling back to Bonfire.Common.Benchmark.apply_timed")

      Enum.each(scenarios, fn {name, fun} ->
        IO.puts("\n#{name}")

        for _ <- 1..String.to_integer(System.get_env("BENCH_ITERATIONS", "10")) do
          Bonfire.Common.Benchmark.apply_timed(fun)
        end
      end)
    end
  end

  defp boundarise_strategy_queries do
    limit = String.to_integer(System.get_env("BENCH_LIMIT", "20"))
    thread_id = biggest_thread_id()

    for {subject_label, subject} <- bench_subjects(),
        {strategy_label, strategy_opts} <- @boundarise_strategies,
        {scenario_label, fun} <- [
          # :my (follows-based) for logged-in — no :local origin OR-filter masking boundary cost
          {"feed",
           fn ->
             Bonfire.Social.FeedActivities.feed(
               if(subject, do: :my, else: :local),
               [limit: limit, current_user: subject, query_with_deferred_join: true] ++
                 strategy_opts
             )
           end},
          # threads boundarise the full candidate set (no deferred join) = biggest strategy delta
          {"thread",
           fn ->
             Bonfire.Social.Threads.list_replies(
               thread_id,
               [current_user: subject, limit: 500] ++ strategy_opts
             )
           end}
        ],
        into: %{} do
      {"#{scenario_label} | #{strategy_label} | #{subject_label}", catching(fun)}
    end
  end

  # ── custom feeds (plan: custom-feeds-perf.md › T0) ─────────────────────────

  # DISABLED presets' filters, copied verbatim from their commented-out definitions in
  # bonfire_social/runtime_config.ex — `FeedLoader.feed/2` takes filters directly, so we can
  # measure exactly what re-enabling would ship without touching config
  defp disabled_preset_filters do
    %{
      "trending(disabled)" => %Bonfire.Social.FeedFilters{
        exclude_activity_types: [:reply],
        sort_by: :popularity_score,
        sort_order: :desc,
        time_limit: 7
      },
      "trending_links(disabled)" => %Bonfire.Social.FeedFilters{
        exclude_activity_types: [:reply, :boost],
        media_types: [:link],
        sort_by: :popularity_score,
        sort_order: :desc,
        time_limit: 2,
        show_objects_only_once: false
      }
    }
  end

  @doc """
  Benchmarks the custom-feed presets (discussions/media/trending) against EXISTING data —
  read-only, safe on production (`bin/bonfire remote`, no-Benchee fallback).

  Env options (in addition to `BENCH_SUBJECTS/BENCH_LIMIT/BENCH_TIME/BENCH_ITERATIONS`):
  - `BENCH_PRESETS=local,trending_discussions` subset by (label) name
  - `BENCH_TIME_LIMIT=0` override every scenario's time window (0 = unbounded — the variant
    that decides whether count-sort indexes pay off, see plan T1)
  """
  def feed_presets do
    Logger.configure(level: :critical)
    run_scenarios(feed_preset_queries(), "feed_presets")
    Logger.configure(level: @log_level)
  end

  defp feed_preset_queries do
    limit = String.to_integer(System.get_env("BENCH_LIMIT", "20"))

    scenarios =
      %{
        # baseline for comparison (:explore, NOT :local — the :local origin OR-filter has its
        # own known slowness that would pollute every preset comparison)
        "explore(baseline)" => :explore,
        "trending_discussions" => :trending_discussions,
        "recent_discussions" => :recent_discussions,
        # the real preset (carries the origin OR-filter tax for logged-in viewers — see
        # activities.ex maybe_filter {:origin, :local}) …
        "local_media" => :local_media,
        # … and the origin-free variant that isolates the media machinery itself
        "media_all(no_origin)" => %Bonfire.Social.FeedFilters{media_types: ["*"]}
      }
      |> Map.merge(disabled_preset_filters())
      |> subset_by_env("BENCH_PRESETS")

    for {preset_label, preset_or_filters} <- scenarios,
        {subject_label, subject} <- bench_subjects(),
        into: %{} do
      {"#{preset_label} | #{subject_label}",
       catching(fn -> call_feed(preset_or_filters, limit: limit, current_user: subject) end)}
    end
  end

  @doc """
  Benchmarks each `sort_by` over the same base feed — isolates sort cost from preset filters.

  Env options: `BENCH_SORTS=reply_count,popularity_score` to subset;
  `BENCH_BASE_PRESET=local`; plus the usual `BENCH_*`.
  """
  def feed_sorts do
    Logger.configure(level: :critical)
    run_scenarios(feed_sort_queries(), "feed_sorts")
    Logger.configure(level: @log_level)
  end

  defp feed_sort_queries do
    limit = String.to_integer(System.get_env("BENCH_LIMIT", "20"))
    # :explore not :local — see note in feed_preset_queries
    base = System.get_env("BENCH_BASE_PRESET", "explore") |> String.to_existing_atom()

    sorts =
      %{
        "chronological(baseline)" => nil,
        "like_count" => :like_count,
        "boost_count" => :boost_count,
        "reply_count" => :reply_count,
        "popularity_score" => :popularity_score
      }
      |> subset_by_env("BENCH_SORTS")

    for {sort_label, sort_by} <- sorts,
        {subject_label, subject} <- bench_subjects(),
        into: %{} do
      filters = if sort_by, do: %{sort_by: sort_by, sort_order: :desc}, else: %{}

      {"sort=#{sort_label} | #{subject_label}",
       catching(fn ->
         Bonfire.Social.FeedLoader.feed(base, maybe_override_time_limit(filters),
           limit: limit,
           current_user: subject
         )
       end)}
    end
  end

  @doc """
  Prints `EXPLAIN (ANALYZE, BUFFERS)` for a preset (atom) or `%FeedFilters{}`/map of filters —
  the before/after artifact for index work. Uses the `return: :query` seam, so it explains the
  CORE feed query (pre-preloads). Same env options as the benchmarks apply.

      Benchmark.feed_explain(:trending_discussions)
      Benchmark.feed_explain(%{sort_by: :reply_count}, current_user: me)
  """
  def feed_explain(preset_or_filters \\ :local, opts \\ []) do
    limit = String.to_integer(System.get_env("BENCH_LIMIT", "20"))

    query = call_feed(preset_or_filters, Keyword.merge([limit: limit, return: :query], opts))

    Bonfire.Common.Repo.checkout(
      fn ->
        try do
          Bonfire.Common.Repo.query!("RESET ALL")
          Bonfire.Common.Repo.query!("SET statement_timeout = 0")

          IO.puts(
            Bonfire.Common.Repo.explain(:all, query,
              analyze: true,
              buffers: true,
              timeout: :infinity
            )
          )
        after
          Bonfire.Common.Repo.query!("RESET ALL")
        end
      end,
      timeout: :infinity
    )
  end

  # named presets + BENCH_TIME_LIMIT need the 3-arity feed (preset, extra_filters, opts)
  defp call_feed(preset_or_filters, opts) do
    case maybe_override_time_limit(preset_or_filters) do
      {preset, extra_filters} -> Bonfire.Social.FeedLoader.feed(preset, extra_filters, opts)
      other -> Bonfire.Social.FeedLoader.feed(other, opts)
    end
  end

  defp maybe_override_time_limit(preset_or_filters) do
    case System.get_env("BENCH_TIME_LIMIT") do
      nil ->
        preset_or_filters

      t ->
        t = String.to_integer(t)

        case preset_or_filters do
          %Bonfire.Social.FeedFilters{} = f -> %{f | time_limit: t}
          %{} = f -> Map.put(f, :time_limit, t)
          # named preset: the override rides opts-level filters instead
          preset when is_atom(preset) -> {preset, %{time_limit: t}}
        end
    end
  end

  defp subset_by_env(map, env_var) do
    case System.get_env(env_var) do
      nil ->
        map

      list ->
        wanted = String.split(list, ",") |> Enum.map(&String.trim/1)
        Map.filter(map, fn {label, _} -> Enum.any?(wanted, &String.starts_with?(label, &1)) end)
    end
  end

  defp bench_subjects do
    # Real users from the DB (no seeding/faking — prod-safe). Preload character.peered so
    # subject resolution classifies locality without a DB round-trip (see user_and_circle_ids
    # in Bonfire.Boundaries.Queries).
    n = String.to_integer(System.get_env("BENCH_SUBJECTS", "3"))

    local_users =
      Bonfire.Me.Users.list(skip_boundary_check: true, show: :local, limit: n)
      |> Bonfire.Common.Repo.preload(character: [:peered])
      |> Enum.take(n)
      |> Enum.with_index()
      |> Enum.map(fn {u, i} -> {"local_user_#{i}", u} end)

    [{"anon", nil}] ++ local_users
  end

  defp biggest_thread_id do
    case System.get_env("BENCH_THREAD_ID") do
      nil ->
        %{rows: [[id] | _]} =
          Bonfire.Common.Repo.query!("""
          SELECT r.thread_id FROM bonfire_data_social_replied r
          WHERE r.thread_id IS NOT NULL GROUP BY 1 ORDER BY count(*) DESC LIMIT 1
          """)

        Needle.ULID.load(id) |> elem(1)

      id_str ->
        # accept uuid form (as SQL returns it) or ulid form
        case Ecto.UUID.cast(id_str) do
          {:ok, uuid} -> Ecto.UUID.dump!(uuid) |> Needle.ULID.load() |> elem(1)
          :error -> id_str
        end
    end
  end

  defp catching(fun) do
    fn ->
      try do
        fun.()
      rescue
        e -> error(e, "Benchmark query failed")
      end
    end
  end

  defp some_feed_queries do
    user = fake_user!()

    Map.new(
      %{
        "query 1 activity" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, limit: 1, query_with_deferred_join: true)
        end,
        "query 10 activities" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, limit: 10, query_with_deferred_join: true)
        end,
        "query 20 activities" => fn ->
          Bonfire.Social.FeedActivities.feed(:local, limit: 20, query_with_deferred_join: true)
        end,
        "query 1 activity, signed in" => fn ->
          Bonfire.Social.FeedActivities.feed(:local,
            limit: 1,
            current_user: user,
            query_with_deferred_join: true
          )
        end,
        "query 10 activities, signed in" => fn ->
          Bonfire.Social.FeedActivities.feed(:local,
            limit: 10,
            current_user: user,
            query_with_deferred_join: true
          )
        end,
        "query 20 activities, signed in" => fn ->
          Bonfire.Social.FeedActivities.feed(:local,
            limit: 20,
            current_user: user,
            query_with_deferred_join: true
          )
        end,
        "query 1 activity, signed in, with no time limit" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 1,
            current_user: user,
            query_with_deferred_join: true
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 10 activities, signed in, with no time limit" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 10,
            current_user: user,
            query_with_deferred_join: true
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 20 activities, signed in, with no time limit" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 20,
            current_user: user,
            query_with_deferred_join: true
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 1, ignoring boundaries" => fn ->
          Bonfire.Social.FeedActivities.feed(:local,
            limit: 1,
            skip_boundary_check: true,
            query_with_deferred_join: true
          )
        end,
        "query 10, ignoring boundaries" => fn ->
          Bonfire.Social.FeedActivities.feed(:local,
            limit: 10,
            skip_boundary_check: true,
            query_with_deferred_join: true
          )
        end,
        "query 20, ignoring boundaries" => fn ->
          Bonfire.Social.FeedActivities.feed(:local,
            limit: 20,
            skip_boundary_check: true,
            query_with_deferred_join: true
          )
        end,
        "query 1 with 1 year time limit" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
          Bonfire.Social.FeedActivities.feed(:local, limit: 1, query_with_deferred_join: true)
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 10 with 1 year time limit" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
          Bonfire.Social.FeedActivities.feed(:local, limit: 10, query_with_deferred_join: true)
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 20 with 1 year time limit" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
          Bonfire.Social.FeedActivities.feed(:local, limit: 20, query_with_deferred_join: true)
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 1 with 1 year time limit, without boundaries" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 1,
            skip_boundary_check: true,
            query_with_deferred_join: true
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 10 with 1 year time limit, without boundaries" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 10,
            skip_boundary_check: true,
            query_with_deferred_join: true
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 20 with 1 year time limit, without boundaries" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 20,
            skip_boundary_check: true,
            query_with_deferred_join: true
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 1 with no time limit, without deferred join" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
          Bonfire.Social.FeedActivities.feed(:local, limit: 1, query_with_deferred_join: false)
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 10 with no time limit, without deferred join" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
          Bonfire.Social.FeedActivities.feed(:local, limit: 10, query_with_deferred_join: false)
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 20 with no time limit, without deferred join" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
          Bonfire.Social.FeedActivities.feed(:local, limit: 20, query_with_deferred_join: false)
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 1 with no time limit, with boundaries view, without deferred join" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 1,
            query_with_deferred_join: false,
            boundarise_strategy: :view
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 10 with no time limit, with boundaries view, without deferred join" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 10,
            query_with_deferred_join: false,
            boundarise_strategy: :view
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 20 with no time limit, with boundaries view, without deferred join" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 20,
            query_with_deferred_join: false,
            boundarise_strategy: :view
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 1 with no time limit, with deferred join" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
          Bonfire.Social.FeedActivities.feed(:local, limit: 1, query_with_deferred_join: true)
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 10 with no time limit, with deferred join" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
          Bonfire.Social.FeedActivities.feed(:local, limit: 10, query_with_deferred_join: true)
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 20 with no time limit, with deferred join" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
          Bonfire.Social.FeedActivities.feed(:local, limit: 20, query_with_deferred_join: true)
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 1 with no time limit, ignoring boundaries" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 1,
            skip_boundary_check: true,
            query_with_deferred_join: true
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 10 with no time limit, ignoring boundaries" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 10,
            skip_boundary_check: true,
            query_with_deferred_join: true
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end,
        "query 20 with no time limit, ignoring boundaries" => fn ->
          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)

          Bonfire.Social.FeedActivities.feed(:local,
            limit: 20,
            skip_boundary_check: true,
            query_with_deferred_join: true
          )

          Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
        end
      },
      fn {name, fun} -> {name, catching(fun)} end
    )
  end

  def feed_full_backend do
    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
    Bonfire.Social.FeedActivities.feed(:local, limit: 20)
    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)
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
    Logger.configure(level: :critical)

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

    conn = conn()

    user = fake_user!()
    user_conn = conn(conn, user: user)

    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
    _feed = Bonfire.Social.FeedActivities.feed(:local)
    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)

    Utils.maybe_apply(
      Benchee,
      :run,
      # md_lib_feed(),
      [
        %{
          # "query & render entire feed page with activities" => fn -> live(conn, "/feed/local") end, # NOPE: error  LiveView helpers can only be invoked from the test process

          # "fetch home page with activities" => fn -> get(conn, "/") end, # should be quick because cached

          "fetch feed page" => fn -> get(conn, "/feed/local?cache=skip") end,
          "fetch feed page, signed in" => fn -> get(user_conn, "/feed/local?cache=skip") end,

          # "fetch feed page with activities not rendered " => fn ->
          #   get(conn, "/feed/local?cache=skip&hide_activities=component")
          # end,
          "fetch feed page with 1 year limit" => fn ->
            get(conn, "/feed/local?cache=skip&time_limit=365")
          end,
          "fetch feed page with 1 year limit, signed in" => fn ->
            get(user_conn, "/feed/local?cache=skip&time_limit=365")
          end
          # "fetch feed page with 1 year limit & activities not rendered " => fn ->
          #   get(conn, "/feed/local?cache=skip&hide_activities=component&time_limit=365")
          # end,
          # "fetch feed page with 1 year limit & activity sub-components not rendered " => fn ->
          #   get(conn, "/feed/local?cache=skip&hide_activities=all&time_limit=365")
          # end,
          # "fetch feed page with no time limit" => fn ->
          #   get(conn, "/feed/local?cache=skip&time_limit=0")
          # end,
          # "fetch feed page with no time limit & activities not rendered " => fn ->
          #   get(conn, "/feed/local?cache=skip&hide_activities=component&time_limit=0")
          # end,
          # "fetch feed page with no time limit & activity sub-components not rendered " => fn ->
          #   get(conn, "/feed/local?cache=skip&hide_activities=all&time_limit=0")
          # end

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

  def feed_component do
    Logger.configure(level: @log_level)

    user = fake_user!()

    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 365)
    feed = Bonfire.Social.FeedActivities.feed(:local)
    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 7)

    Utils.maybe_apply(
      Benchee,
      :run,
      # md_lib_feed(),
      [
        %{
          "query & render feed component with activities (default preloads)" => fn ->
            live_feed()
          end,
          "query & render feed component with activities (default preloads), signed in" => fn ->
            live_feed(current_user: user)
            # |> dump()
          end,
          # "query & render feed component with activities (using all async preloads)" => fn ->
          #   live_feed(live_update_many_preload_mode: :async)
          # end,
          # "query & render feed component with activities (inline all preloads)" => fn ->
          #   live_feed(live_update_many_preload_mode: :inline)
          # end,
          # "query & render feed component with activities (skipping all preloads)" => fn ->
          #   live_feed(live_update_many_preload_mode: :skip)
          # end,
          # "query & render feed component with activities (using feed async preloads)" => fn ->
          #   live_feed(feed_live_update_many_preload_mode: :async_total) # FIXME
          # end,
          # "query & render feed component with activities (inline feed preloads)" => fn ->
          #   live_feed(feed_live_update_many_preload_mode: :inline)
          # end,
          # "query & render feed component with activities (inline + async actions)" => fn ->
          #   live_feed(feed_live_update_many_preload_mode: :async_actions)
          # end,
          # "query & render feed component with activities (skipping feed preloads)" => fn ->
          #   live_feed(feed_live_update_many_preload_mode: :skip)
          # end,
          "render feed component with pre-queried activities" => fn ->
            render_feed(feed)
          end,
          "render feed component with pre-queried activities, signed in" => fn ->
            render_feed(feed, current_user: user)
          end
          # "render feed component with already queried activities (skipping preloads)" => fn ->
          #   render_feed(feed, feed_live_update_many_preload_mode: :skip)
          # end,
          # "render feed component with already queried activities (inline preloads)" => fn ->
          #   render_feed(feed, feed_live_update_many_preload_mode: :inline)
          # end,
          # "render feed component with already queried activities (async actions preloads)" =>
          #   fn ->
          #     render_feed(feed, feed_live_update_many_preload_mode: :async_actions)
          #   end,
          # "render feed component with already queried activities (async preloads)" => fn ->
          #   render_feed(feed, feed_live_update_many_preload_mode: :async)
          # end,
          # "render feed component with already queried activities (skip activity component)" => fn ->
          #   render_feed(feed, hide_activities: "component")
          # end,
          # "render feed component with already queried activities (hide activity component)" => fn ->
          #   render_feed(feed, hide_activities: "all")
          # end,
          # "render feed component with already queried activities (skip subject)" => fn ->
          #   render_feed(feed, hide_activities: "subject")
          # end,
          # "render feed component with already queried activities (skip note)" => fn ->
          #   render_feed(feed, hide_activities: "note")
          # end,
          # "render feed component with already queried activities (skip media)" => fn ->
          #   render_feed(feed, hide_activities: "media")
          # end,
          # "render feed component with already queried activities (skip actions)" => fn ->
          #   render_feed(feed, hide_activities: "actions")
          # end,
          # "render feed component with already queried activities (skip dynamic)" => fn ->
          #   render_feed(feed, hide_activities: "dynamic")
          # end,
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

  def feed_full_get(conn \\ build_conn()), do: get(conn, "/feed/local?cache=skip&time_limit=0")

  # defp md_lib_feed do
  #   feed = Bonfire.Social.FeedActivities.feed(:remote, limit: 20)

  #   %{
  #     "render activities with earmark" => fn ->
  #       Config.put(:markdown_library, Earmark)
  #       render_feed(feed)
  #     end,
  #     "render activities with mdex" => fn ->
  #       Config.put(:markdown_library, MDEx)
  #       render_feed(feed)
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
          #   render_feed(feed, live_update_many_preload_mode: :skip)
          # end,
          # "render feed component with already queried activities (using async preloads)" => fn ->
          #   render_feed(feed, live_update_many_preload_mode: :async)
          # end,
          "render feed component with already queried activities (inline preloads)" => fn ->
            render_feed(feed, live_update_many_preload_mode: :inline)
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

  def misc do
    # app_names = Bonfire.Common.Extend.loaded_application_names()
    app_names = [1, 2]

    app_map =
      Map.new(app_names, fn x -> {x, true} end)
      |> IO.inspect()

    Utils.maybe_apply(
      Benchee,
      :run,
      [
        %{
          "Map.get" => fn ->
            app_map
            |> Map.get(:bonfire_common)
          end,
          "Enum.member" => fn ->
            app_names
            |> Enum.member?(:bonfire_common)
          end
        },
        [
          parallel: 1,
          warmup: 0,
          time: 1,
          memory_time: 1,
          reduction_time: 1,
          profile_after: true,
          formatters: formatters("benchmarks/output/misc.html")
        ]
      ]
    )
  end

  def live_feed(opts \\ []) do
    Bonfire.Social.FeedActivities.feed(:local, opts)
    |> render_feed(opts)
  end

  def render_feed(%{edges: feed, page_info: page_info}, opts \\ []) do
    Process.put([:bonfire, :live_update_many_preload_mode], opts[:live_update_many_preload_mode])

    Process.put(
      [:bonfire, :feed_live_update_many_preload_mode],
      opts[:feed_live_update_many_preload_mode]
    )

    html =
      Bonfire.UI.Common.Testing.Helpers.render_stateful(
        Bonfire.UI.Social.FeedLive,
        Enum.into(opts, %{
          feed: feed,
          page_info: page_info
        }),
        Map.new(opts)
      )

    html =~ "data-id=\"activity\"" || (dump(html) && raise "Feed not found in HTML")

    html
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
