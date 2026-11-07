defmodule Bonfire.UI.Social.Notifications.FollowChipPaginationTest do
  @moduledoc """
  A notifications tab pages through its own kind of notification, however many of the other kinds arrived since: the "New followers" tab once showed 2 followers, then an endless "Load more" that brought older ones one at a time.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Common.Config
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Social.Likes

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
