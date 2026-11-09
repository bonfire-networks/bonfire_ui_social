defmodule Bonfire.UI.Social.FeedLocaleBenchmarkTest do
  @moduledoc """
  Time of a RENDERED local feed page in `en`, `fr` and `fr_FR`: the connected LiveView mount, with the page's activities postloaded and rendered, for a signed-in viewer whose language is set in their settings, as the language form does.

  Only prints. The database time dwarfs the string lookups and varies between runs, so it shows what share of a real render the lookups are and cannot carry an assertion. The asserted page replay is in `bonfire_common/test/localise/locale_fallback_benchmark_test.exs`.

  Set up like `feed_block_keywords_benchmark_test.exs`.

  Run: `just test extensions/bonfire_ui_social/test/views/feed_locale_benchmark_test.exs --only benchmark`
  """
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes

  @moduletag :ui
  @moduletag :benchmark
  @moduletag timeout: :infinity

  @timed_runs 8
  @locales ["en", "fr", "fr_FR"]

  setup do
    # the test default is 2, which would cut the page down to 2 activities
    Process.put([:bonfire, :default_pagination_limit], 20)

    authors = for i <- 1..4, do: fake_user!("loc_ui_author_#{i}")
    [booster, replier] = for i <- 1..2, do: fake_user!("loc_ui_other_#{i}")

    posts =
      for {author, a} <- Enum.with_index(authors, 1), n <- 1..4 do
        {:ok, post} =
          Posts.publish(
            current_user: author,
            post_attrs: %{
              post_content: %{
                name: "Post #{a}.#{n}",
                html_body:
                  "Post #{n} from author #{a}, with a few more words so it looks like a real post"
              }
            },
            boundary: "public"
          )

        post
      end

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

    %{viewers: Map.new(@locales, &{&1, viewer_in(&1)})}
  end

  @tag :benchmark
  test "rendered /feed/local: time per locale", %{viewers: viewers} do
    # which Gettext locale each setting resolves to, through the function the page's LiveView plug uses; `fr_FR` is not asserted because that resolution is part of what is being reported
    resolved =
      for locale <- @locales do
        {:ok, _} = Bonfire.Common.Localise.put_best_locale_match([locale])
        {locale, Gettext.get_locale()}
      end

    IO.puts("\nGettext locale each viewer setting resolves to: #{inspect(resolved)}")
    assert {"en", "en"} in resolved
    assert {"fr", "fr"} in resolved

    load_page = fn viewer ->
      conn(user: viewer, account: viewer.account)
      |> visit("/feed/local")
      |> wait_async()
    end

    # correctness: the page shows the posts in every locale, and the language changes what is rendered
    html =
      Map.new(viewers, fn {locale, viewer} ->
        session = load_page.(viewer) |> assert_has("[data-id=feed]", text: "from author 2")

        session
        |> PhoenixTest.unwrap(fn view ->
          rendered = Phoenix.LiveViewTest.render(view)
          Process.put(:rendered_html, rendered)
          rendered
        end)

        {locale, Process.get(:rendered_html)}
      end)

    refute html["en"] == html["fr"], "the en and fr pages are the same"

    IO.puts("\n=== rendered /feed/local, #{@timed_runs} timed runs per locale ===")

    for locale <- @locales do
      viewer = viewers[locale]
      load_page.(viewer)

      times_ms =
        for _ <- 1..@timed_runs do
          {us, _} = :timer.tc(fn -> load_page.(viewer) end)
          us / 1000
        end
        |> Enum.sort()

      IO.puts(
        "#{locale}: min #{fmt(hd(times_ms))} ms, median #{fmt(Enum.at(times_ms, div(@timed_runs, 2)))} ms, max #{fmt(List.last(times_ms))} ms"
      )
    end
  end

  defp fmt(ms), do: :erlang.float_to_binary(ms, decimals: 1)

  defp viewer_in(locale) do
    user = fake_user!("loc_ui_viewer_#{locale}")

    {:ok, _} =
      Bonfire.Common.Settings.put([Bonfire.Common.Localise.Cldr, :default_locale], locale,
        current_user: user
      )

    Bonfire.Common.Repo.preload(user, :settings, force: true)
  end
end
