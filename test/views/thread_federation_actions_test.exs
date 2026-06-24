defmodule Bonfire.UI.Social.Threads.FederationActionsTest do
  @moduledoc """
  UI tests for bonfire-app#647: like/reply buttons on a REMOTE post are disabled when this
  instance can't federate the interaction (disabled / manual / allowlist-only), and enabled when
  federation is open. Mirrors the follow-button gating tested in `bonfire_ui_me` profile_test.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  import Bonfire.Posts.Fake, only: [fake_post!: 3]

  setup do
    Tesla.Mock.mock_global(fn env -> ActivityPub.Test.HttpRequestMock.request(env) end)

    # create the remote actor + post under OPEN federation (avoids leaked-mode failures), then
    # each test sets the mode it needs
    Bonfire.Federate.ActivityPub.set_federating(:instance, true)

    on_exit(fn ->
      parent = self()

      Task.start(fn ->
        Ecto.Adapters.SQL.Sandbox.allow(Bonfire.Common.Repo, parent, self())
        Bonfire.Federate.ActivityPub.set_federating(:instance, true)
      end)
    end)

    account = fake_account!()
    alice = fake_user!(account)
    {:ok, karen} = Bonfire.Federate.ActivityPub.Simulate.fake_remote_user()

    # a post authored by the remote user (so the like/reply target is remote)
    post = fake_post!(karen, "public", %{post_content: %{html_body: "<p>a remote post</p>"}})

    {:ok, conn: conn(user: alice, account: account), post: post}
  end

  test "like, reply & quote are ENABLED on a remote post when federation is open", %{
    conn: conn,
    post: post
  } do
    conn
    |> visit("/discussion/#{post.id}")
    |> wait_async()
    |> assert_has("[data-role=like_enabled]")
    |> assert_has("[data-role=reply_enabled]")
    |> assert_has("[data-role=quote_enabled]")
  end

  test "like, reply & quote are DISABLED on a remote post when federation is disabled", %{
    conn: conn,
    post: post
  } do
    Bonfire.Federate.ActivityPub.set_federating(:instance, false)

    conn
    |> visit("/discussion/#{post.id}")
    |> wait_async()
    |> assert_has("[data-role=like_disabled]")
    |> assert_has("[data-role=reply_disabled]")
    |> assert_has("[data-role=quote_disabled]")
  end

  test "like, reply & quote are DISABLED on a remote post in archipelago (allowlist-only) mode",
       %{conn: conn, post: post} do
    Bonfire.Federate.ActivityPub.set_allowlist_only(:instance, true)

    conn
    |> visit("/discussion/#{post.id}")
    |> wait_async()
    |> assert_has("[data-role=like_disabled]")
    |> assert_has("[data-role=reply_disabled]")
    |> assert_has("[data-role=quote_disabled]")
  end
end
