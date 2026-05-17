defmodule Bonfire.UI.Social.Feeds.FeedFullPreloadRenderStressTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  use Bonfire.Common.Config

  import Bonfire.Posts.Fake

  alias Bonfire.Data.Social.FeedPublish
  alias Bonfire.UI.Social.Benchmark
  alias Bonfire.Social.FeedActivities

  @default_page_limit 20
  @default_hidden_multiplier 32
  @default_hidden_extra_rows 5
  @default_preload_max_ms 1_000
  @default_component_render_max_ms 3_000
  @default_initial_render_max_ms 5_000
  @default_load_more_render_max_ms 3_000

  setup do
    page_limit = env_integer("BONFIRE_FULL_RENDER_PAGE_LIMIT", @default_page_limit)

    hidden_multiplier =
      env_integer("BONFIRE_FULL_RENDER_HIDDEN_MULTIPLIER", @default_hidden_multiplier)

    hidden_extra_rows =
      env_integer("BONFIRE_FULL_RENDER_HIDDEN_EXTRA_ROWS", @default_hidden_extra_rows)

    account = fake_account!()
    viewer = fake_user!(account)
    hidden_author = fake_user!()

    original_deferred = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
    original_time_limit = Config.get([Bonfire.UI.Social.FeedLive, :time_limit], 7)
    original_default_limit = Config.get(:default_pagination_limit)
    original_hard_max = Config.get(:pagination_hard_max_limit)

    Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], true)
    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
    Config.put(:default_pagination_limit, page_limit)
    Config.put(:pagination_hard_max_limit, max(original_hard_max || 0, page_limit))

    repo().delete_all(Bonfire.Data.Social.FeedPublish)

    fallback_handler_id = {__MODULE__, self(), make_ref()}

    :telemetry.attach(
      fallback_handler_id,
      [:bonfire, :social, :feed_loader, :deferred_join, :fallback],
      fn _event, _measurements, metadata, test_pid ->
        send(test_pid, {:deferred_join_fallback, metadata})
      end,
      self()
    )

    on_exit(fn ->
      :telemetry.detach(fallback_handler_id)
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_deferred)
      Config.put([Bonfire.UI.Social.FeedLive, :time_limit], original_time_limit)
      Config.put(:default_pagination_limit, original_default_limit)
      Config.put(:pagination_hard_max_limit, original_hard_max)
    end)

    %{
      account: account,
      viewer: viewer,
      hidden_author: hidden_author,
      page_limit: page_limit,
      hidden_count: page_limit * hidden_multiplier + hidden_extra_rows
    }
  end

  @tag timeout: 600_000
  test "full preload backend and rendered load_more recover a 20-item local page after hidden local rows without fallback",
       %{
         account: account,
         viewer: viewer,
         hidden_author: hidden_author,
         page_limit: page_limit,
         hidden_count: hidden_count
       } do
    tag = System.unique_integer([:positive])
    older_prefix = "FULL_RENDER_OLDER_#{tag}"
    hidden_prefix = "FULL_RENDER_HIDDEN_#{tag}"
    newer_prefix = "FULL_RENDER_NEWER_#{tag}"

    {older_posts, older_markers} = create_posts(viewer, "public", older_prefix, page_limit)

    {hidden_posts, _hidden_markers} =
      create_posts(hidden_author, "mentions", hidden_prefix, hidden_count)

    Enum.each(hidden_posts, &publish_to_local_feed/1)

    {newer_posts, newer_markers} = create_posts(viewer, "public", newer_prefix, page_limit)

    {first_preload_us, first_page} =
      :timer.tc(fn ->
        full_preload_feed(viewer, page_limit)
      end)

    assert %{edges: first_edges, page_info: %{end_cursor: cursor}} = first_page
    assert length(first_edges) == page_limit
    assert is_binary(cursor)

    assert_page_contains_all(first_edges, newer_posts)
    refute_page_contains_any(first_edges, hidden_posts)

    hidden_window =
      FeedActivities.feed(:local,
        current_user: viewer,
        after: cursor,
        limit: page_limit,
        skip_boundary_check: true,
        show_objects_only_once: false,
        preload: false
      )

    assert_page_contains_any(hidden_window.edges, hidden_posts)

    {second_preload_us, second_page} =
      :timer.tc(fn ->
        full_preload_feed(viewer, page_limit, after: cursor)
      end)

    assert %{edges: second_edges} = second_page
    assert length(second_edges) == page_limit
    assert_page_contains_all(second_edges, older_posts)
    refute_page_contains_any(second_edges, hidden_posts)
    assert_disjoint_pages(first_edges, second_edges)

    {component_render_us, component_html} =
      :timer.tc(fn ->
        Benchmark.render_feed(first_page,
          current_user: viewer,
          feed_name: :local,
          feed_id: :local,
          feed_filters: %{feed_name: :local},
          live_update_many_preload_mode: :inline,
          feed_live_update_many_preload_mode: :inline,
          hide_filters: true
        )
      end)

    assert_all_activity_ids_present(component_html, newer_posts)
    refute_activity_ids_present(component_html, hidden_posts)

    first_preload_ms = us_to_ms(first_preload_us)
    second_preload_ms = us_to_ms(second_preload_us)
    component_render_ms = us_to_ms(component_render_us)

    assert_under_ms(
      "full preload backend",
      max(first_preload_ms, second_preload_ms),
      "BONFIRE_FULL_PRELOAD_MAX_MS",
      @default_preload_max_ms
    )

    assert_under_ms(
      "full preload component render",
      component_render_ms,
      "BONFIRE_FULL_COMPONENT_RENDER_MAX_MS",
      @default_component_render_max_ms
    )

    {initial_render_us, session} =
      :timer.tc(fn ->
        conn(user: viewer, account: account)
        |> visit("/feed/local?cache=skip&time_limit=0")
        |> wait_async()
      end)

    initial_render_ms = us_to_ms(initial_render_us)

    session =
      session
      |> assert_has("[data-id=feed] article", count: page_limit)
      |> assert_all_articles_present(newer_markers)
      |> refute_has("article", text: hidden_prefix)
      |> assert_has("[data-id=load_more]")

    assert_under_ms(
      "initial full render",
      initial_render_ms,
      "BONFIRE_FULL_INITIAL_RENDER_MAX_MS",
      @default_initial_render_max_ms
    )

    {load_more_render_us, session} =
      :timer.tc(fn ->
        session
        |> click_button("[data-id=load_more]", "Load more")
        |> wait_async()
      end)

    load_more_render_ms = us_to_ms(load_more_render_us)

    session
    |> assert_has("[data-id=feed] article", count: page_limit * 2)
    |> assert_all_articles_present(older_markers)
    |> assert_all_articles_present(newer_markers)
    |> refute_has("article", text: hidden_prefix)

    assert_under_ms(
      "load_more full render",
      load_more_render_ms,
      "BONFIRE_FULL_LOAD_MORE_RENDER_MAX_MS",
      @default_load_more_render_max_ms
    )

    refute_received {:deferred_join_fallback, metadata},
                    "Expected full preload/render stress not to use non-deferred fallback, got #{inspect(metadata)}"

    IO.puts(
      "full_preload_render_stress page_limit=#{page_limit} hidden_rows=#{hidden_count} first_preload_ms=#{first_preload_ms} second_preload_ms=#{second_preload_ms} component_render_ms=#{component_render_ms} initial_render_ms=#{initial_render_ms} load_more_render_ms=#{load_more_render_ms}"
    )
  end

  defp full_preload_feed(viewer, page_limit, opts \\ []) do
    FeedActivities.feed(
      :local,
      Keyword.merge(
        [
          current_user: viewer,
          limit: page_limit,
          preload: :feed,
          show_objects_only_once: false
        ],
        opts
      )
    )
  end

  defp create_posts(user, boundary, marker_prefix, count) do
    posts_and_markers =
      for n <- 1..count do
        marker = "#{marker_prefix}_#{n}_END"

        post =
          fake_post!(user, boundary, %{
            post_content: %{
              name: marker,
              html_body: marker
            }
          })

        {post, marker}
      end

    Enum.unzip(posts_and_markers)
  end

  defp publish_to_local_feed(post) do
    assert {:ok, _published} =
             repo().upsert(
               Ecto.Changeset.cast(
                 %FeedPublish{},
                 %{feed_id: local_feed_id(), id: post.id},
                 [:feed_id, :id]
               )
             )
  end

  defp local_feed_id,
    do: Bonfire.Boundaries.Circles.get_id(:local) || "3SERSFR0MY0VR10CA11NSTANCE"

  defp assert_all_articles_present(session, markers) do
    Enum.each(markers, fn marker ->
      assert_has(session, "article", text: marker)
    end)

    session
  end

  defp assert_all_activity_ids_present(html, posts) do
    Enum.each(posts, fn post ->
      assert html =~ post.id
    end)
  end

  defp refute_activity_ids_present(html, posts) do
    Enum.each(posts, fn post ->
      refute html =~ post.id
    end)
  end

  defp assert_disjoint_pages(first_edges, second_edges) do
    overlap = MapSet.intersection(activity_ids(first_edges), activity_ids(second_edges))

    assert MapSet.size(overlap) == 0,
           "Expected full preload pages not to overlap, got #{inspect(MapSet.to_list(overlap))}"
  end

  defp activity_ids(edges), do: MapSet.new(Enum.map(edges, & &1.activity.id))

  defp post_ids(posts), do: MapSet.new(Enum.map(posts, & &1.id))

  defp assert_page_contains_all(edges, posts) do
    missing = MapSet.difference(post_ids(posts), activity_ids(edges))

    assert MapSet.size(missing) == 0,
           "Expected page to contain posts #{inspect(MapSet.to_list(missing))}"
  end

  defp assert_page_contains_any(edges, posts) do
    overlap = MapSet.intersection(post_ids(posts), activity_ids(edges))

    assert MapSet.size(overlap) > 0,
           "Expected page to contain at least one of #{MapSet.size(post_ids(posts))} posts"
  end

  defp refute_page_contains_any(edges, posts) do
    overlap = MapSet.intersection(post_ids(posts), activity_ids(edges))

    assert MapSet.size(overlap) == 0,
           "Expected page not to contain hidden posts #{inspect(MapSet.to_list(overlap))}"
  end

  defp assert_under_ms(label, actual_ms, env_name, default_ms) do
    max_ms = env_integer(env_name, default_ms)

    assert actual_ms <= max_ms,
           "#{label} took #{actual_ms}ms, above #{env_name}=#{max_ms}ms"
  end

  defp us_to_ms(us), do: Float.round(us / 1_000, 2)

  defp env_integer(name, default) do
    case System.get_env(name) do
      nil -> default
      "" -> default
      value -> String.to_integer(value)
    end
  end
end
