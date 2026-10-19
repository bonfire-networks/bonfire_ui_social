defmodule Bonfire.UI.Social.FeedBlockKeywordsBenchmarkTest do
  @moduledoc """
  Cost of a user's filtered keywords on a RENDERED feed page: the connected LiveView mount, with the page's activities postloaded and rendered, for a signed-in viewer.

  The backend-only `FeedLoader.feed_postloaded` benchmark (`bonfire_social/test/feeds/feeds_block_keywords_benchmark_test.exs`) makes 5 `Settings.get` calls per load. This one counts them across the whole render, in every process.

  The keywords are stored in each viewer's settings row, as in production. Do not `Process.put` the keyword key: in test env that short-circuits `Settings.get` before the DB path.

  Run: `just test extensions/bonfire_ui_social/test/views/feed_block_keywords_benchmark_test.exs --only benchmark`
  """
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Boundaries.BlockKeywords

  @moduletag :ui
  @moduletag :benchmark
  @moduletag timeout: :infinity

  @timed_runs 8

  @settings_get {Bonfire.Common.Settings, :__get__, 3}
  @block_keywords {BlockKeywords, :block_keywords_settings, 1}
  @activity_preloads {Bonfire.Social.Activities, :activity_preloads, 3}

  setup do
    # the test default is 2, which would cut the page down to 2 activities
    Process.put([:bonfire, :default_pagination_limit], 20)

    authors = for i <- 1..4, do: fake_user!("kw_ui_author_#{i}")
    [booster, replier] = for i <- 1..2, do: fake_user!("kw_ui_other_#{i}")

    # 16 root posts across 4 authors, two of them with the spammy keyword
    posts =
      for {author, a} <- Enum.with_index(authors, 1), n <- 1..4 do
        body =
          if a == 1 and n <= 2,
            do: "Amazing deal on viagra #{n}",
            else: "Post #{n} from author #{a}, with a few more words so it looks like a real post"

        {:ok, post} =
          Posts.publish(
            current_user: author,
            post_attrs: %{post_content: %{name: "Post #{a}.#{n}", html_body: body}},
            boundary: "public"
          )

        post
      end

    # replies, boosts and likes so the page has the same mix of edges as a real one
    # none of these touch the two spammy posts (indexes 0 and 1): a reply's inline reply-to preview shows the original's body
    for post <- Enum.slice(posts, 4, 3) do
      {:ok, _} =
        Posts.publish(
          current_user: replier,
          post_attrs: %{post_content: %{html_body: "A reply"}, reply_to: post.id},
          boundary: "public"
        )
    end

    for post <- Enum.slice(posts, 8, 3), do: {:ok, _} = Boosts.boost(booster, post)
    for post <- Enum.slice(posts, 12, 3), do: {:ok, _} = Likes.like(booster, post)

    %{
      viewers: %{
        "0 keywords" => viewer_with_keywords("kw_ui_viewer_0", 0),
        "20 keywords" => viewer_with_keywords("kw_ui_viewer_20", 20),
        "200 keywords" => viewer_with_keywords("kw_ui_viewer_200", 200)
      }
    }
  end

  @tag :benchmark
  test "rendered feed page: filtered keyword count vs Settings.get calls and time", %{
    viewers: viewers
  } do
    load_page = fn {user, _keywords} ->
      conn(user: user, account: user.account)
      |> visit("/feed/local")
      |> wait_async()
    end

    # correctness: the page renders the posts, and the keywords reach the UI path only for the user who set them
    load_page.(viewers["0 keywords"])
    |> assert_has("[data-id=feed]", text: "Amazing deal on viagra")

    load_page.(viewers["200 keywords"])
    |> assert_has("[data-id=feed]", text: "from author 2")
    |> refute_has("[data-id=feed]", text: "Amazing deal on viagra")

    IO.puts("\n=== rendered /feed/local, #{@timed_runs} timed runs per viewer ===")

    for {label, viewer} <- Enum.sort(viewers) do
      load_page.(viewer)

      counts =
        call_counts([@settings_get, @block_keywords, @activity_preloads], fn ->
          load_page.(viewer)
        end)

      times_ms =
        for _ <- 1..@timed_runs do
          {us, _} = :timer.tc(fn -> load_page.(viewer) end)
          us / 1000
        end
        |> Enum.sort()

      IO.puts(
        "#{label}: #{inspect(counts[@settings_get])} Settings.get, " <>
          "#{inspect(counts[@block_keywords])} block_keywords_settings, " <>
          "#{inspect(counts[@activity_preloads])} activity_preloads | " <>
          "min #{fmt(hd(times_ms))} ms, median #{fmt(Enum.at(times_ms, div(@timed_runs, 2)))} ms, max #{fmt(List.last(times_ms))} ms"
      )
    end
  end

  defp fmt(ms), do: :erlang.float_to_binary(ms, decimals: 1)

  defp viewer_with_keywords(name, count) do
    user = fake_user!(name)

    if count > 0 do
      keywords = ["viagra" | for(i <- 1..(count - 1)//1, do: "blockedword#{i}")]
      {:ok, _} = BlockKeywords.put_block_keywords_settings(keywords, current_user: user)
    end

    {Bonfire.Common.Repo.preload(user, :settings, force: true), count}
  end

  # Counts calls to each {module, fun, arity} made by any process while `fun` runs.
  defp call_counts(mfas, fun) do
    Enum.each(mfas, fn {mod, _, _} = mfa ->
      Code.ensure_loaded(mod)
      :erlang.trace_pattern(mfa, true, [:call_count])
    end)

    try do
      fun.()

      Map.new(mfas, fn mfa ->
        case :erlang.trace_info(mfa, :call_count) do
          {:call_count, n} when is_integer(n) -> {mfa, n}
          _ -> {mfa, :not_defined}
        end
      end)
    after
      Enum.each(mfas, &:erlang.trace_pattern(&1, false, [:call_count]))
    end
  end
end
