defmodule Bonfire.UI.Social.Notifications.FollowChipPaginationTest do
  @moduledoc """
  A notifications tab pages through its own kind of notification, however many of the other kinds arrived since: the "New followers" tab once showed 2 followers, then an endless "Load more" that brought older ones one at a time.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Common.Config
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Social.Likes

  @next_page_button "[data-id=load_more]:not(#load_more_show_older)"

  setup do
    # as in production, where the deferred join picks a window of the newest notifications before the tab's own filter applies
    original = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
    Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], true)
    on_exit(fn -> Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original) end)

    limit = Config.get(:default_pagination_limit, 2)
    account = fake_account!()
    me = fake_user!(account)

    {:ok, me: me, account: account, limit: limit}
  end

  test "the New followers tab shows a full page, and Load more brings the next one", %{
    me: me,
    account: account,
    limit: limit
  } do
    followers = limit * 3

    for _ <- 1..followers do
      {:ok, _} = Follows.follow(fake_user!(), me)
    end

    # newer than every follow, and more of them than the deferred join's window holds
    liker = fake_user!()

    for _ <- 1..(limit * 12) do
      {:ok, _} = Likes.like(liker, Bonfire.Posts.Fake.fake_post!(me, "public"))
    end

    pages_through_follows(me, account, limit, followers)
  end

  # follows not made the way a local follow is, since local follows page fine
  describe "pages through follows that arrived other ways:" do
    test "from people on other instances", %{me: me, account: account, limit: limit} do
      # each actor is fetched as it would be from its instance
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://mocked.local/users/follower" <> _ = url} = env ->
          if String.ends_with?(url, "/outbox") or String.ends_with?(url, "/followers") or
               String.ends_with?(url, "/following"),
             do: ActivityPub.Test.HttpRequestMock.request(env),
             else:
               Tesla.Mock.json(
                 Bonfire.Federate.ActivityPub.Simulate.actor_json(
                   url,
                   List.last(String.split(url, "/"))
                 )
               )

        env ->
          ActivityPub.Test.HttpRequestMock.request(env)
      end)

      followers = limit * 3

      remotes =
        for n <- 1..followers do
          # each a different person: `fake_remote_user/0` gives the same mocked actor every time
          username = "follower#{n}_#{System.unique_integer([:positive])}"

          {:ok, remote} =
            Bonfire.Federate.ActivityPub.AdapterUtils.get_or_fetch_and_create_by_uri(
              "https://mocked.local/users/#{username}"
            )

          {:ok, _} = Follows.follow(remote, me)
          remote
        end

      # the positive first: that many different people, each following me
      assert remotes |> Enum.map(&id/1) |> Enum.uniq() |> length() == followers
      assert Enum.all?(remotes, &Follows.following?(&1, me))

      pages_through_follows(me, account, limit, followers)
    end

    test "requests I accepted", %{account: account, limit: limit} do
      me = fake_user!(account, %{}, request_before_follow: true)
      followers = limit * 3

      for _ <- 1..followers do
        {:ok, request} = Follows.follow(fake_user!(), me)
        {:ok, _} = Follows.accept(request, current_user: me)
      end

      pages_through_follows(me, account, limit, followers)
    end

    test "people who unfollowed and followed again", %{me: me, account: account, limit: limit} do
      followers = limit * 3

      for _ <- 1..followers do
        follower = fake_user!()
        {:ok, _} = Follows.follow(follower, me)
        Follows.unfollow(follower, me)
        {:ok, _} = Follows.follow(follower, me)
      end

      pages_through_follows(me, account, limit, followers)
    end
  end

  # the default for people (`:preload`, `config/test.exs` turns it off): scrolling near the button sends `preload_more`, which loads the next page hidden, and the browser's `LoadMore` hook waits for the button's `data-page` to change before it stops its spinner and can send again
  test "with infinite scroll preloading, each page loaded on scroll moves the cursor and brings more followers",
       %{me: me, account: account, limit: limit} do
    Bonfire.Common.Settings.put([:ui, :infinite_scroll], :preload, current_user: me, scope: :user)
    followers = limit * 3

    for _ <- 1..followers do
      {:ok, _} = Follows.follow(fake_user!(), me)
    end

    conn(user: me, account: account)
    |> visit("/notifications/follow")
    |> wait_async()
    |> assert_has("[data-id=feed] article[data-verb=follow]", count: limit)
    |> unwrap(fn view ->
      # what the hook does on scroll, until the page has no more to load
      seen =
        Enum.reduce_while(1..(followers + 2), {nil, limit}, fn _, {previous_cursor, _} ->
          html = Phoenix.LiveViewTest.render(view)
          doc = Floki.parse_document!(html)
          count = doc |> Floki.find("[data-id=feed] article[data-verb=follow]") |> length()

          # the feed's own button: "Show older activities" (`#load_more_show_older`) only appears once the time window is done, and doesn't load on scroll in this mode
          case Floki.find(doc, @next_page_button) do
            [] ->
              {:halt, {:done, count}}

            [button | _] ->
              cursor = button |> Floki.attribute("data-page") |> List.first()
              event = button |> Floki.attribute("phx-scroll") |> List.first()

              assert cursor != previous_cursor,
                     "the cursor didn't move after a page loaded on scroll (#{count} followers shown), so the hook's spinner never stops"

              assert is_binary(event), "the load-more button sends nothing on scroll"

              values =
                for {"phx-value-" <> key, value} <- elem(button, 1), into: %{}, do: {key, value}

              view
              |> Phoenix.LiveViewTest.element(@next_page_button)
              |> Phoenix.LiveViewTest.render_hook(event, values)

              {:cont, {cursor, count}}
          end
        end)

      assert {_, ^followers} = seen
      Phoenix.LiveViewTest.render(view)
    end)
  end

  # once the follows inside the time window are all shown, "Show older activities" goes on from the last one shown, not from the page before it
  test "after paging through the recent followers, Show older activities brings someone who followed before the time window",
       %{me: me, account: account, limit: limit} do
    recent = limit * 2

    for _ <- 1..recent do
      {:ok, _} = Follows.follow(fake_user!(), me)
    end

    # older than the default 30 days the feed shows (`FeedLoader.default_time_limit/0`)
    long_ago = fake_user!()
    long_ago_link = "[data-id=feed] article a[href='/@#{long_ago.character.username}']"

    {:ok, _} =
      Follows.follow(long_ago, me,
        pointer_id:
          Bonfire.Common.DatesTimes.past(60, :day) |> Bonfire.Common.DatesTimes.generate_ulid()
      )

    # the positive first: the old follow is there, and is a notification
    assert Follows.following?(long_ago, me)

    conn(user: me, account: account)
    |> visit("/notifications/follow")
    |> wait_async()
    |> assert_has("[data-id=feed] article[data-verb=follow]", count: limit)
    |> click_button("[data-id=load_more]", "Load more")
    |> wait_async()
    |> assert_has("[data-id=feed] article[data-verb=follow]", count: recent)
    |> refute_has(long_ago_link)
    |> click_button("#load_more_show_older", "Show older activities")
    |> wait_async()
    |> assert_has(long_ago_link)
    |> assert_has("[data-id=feed] article[data-verb=follow]", count: recent + 1)
  end

  defp pages_through_follows(me, account, limit, followers) do
    conn(user: me, account: account)
    |> visit("/notifications/follow")
    |> wait_async()
    |> assert_has("[data-id=feed] article[data-verb=follow]", count: limit)
    |> click_button("[data-id=load_more]", "Load more")
    |> wait_async()
    |> assert_has("[data-id=feed] article[data-verb=follow]", count: limit * 2)
    |> click_button("[data-id=load_more]", "Load more")
    |> wait_async()
    |> assert_has("[data-id=feed] article[data-verb=follow]", count: followers)
  end
end
