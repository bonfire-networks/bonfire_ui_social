defmodule Bonfire.UI.Social.Threads.FediverseReactionsTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.Boosts

  setup do
    account = fake_account!()
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    {:ok, post} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "<p>An original post</p>"}},
        boundary: "public"
      )

    {:ok, conn: conn(user: alice, account: account), alice: alice, bob: bob, post: post}
  end

  test "shows a reposts facepile + count once the post has been boosted", %{
    conn: conn,
    bob: bob,
    post: post
  } do
    assert {:ok, _} = Boosts.boost(bob, post)

    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("[data-role=fediverse_reactions]")
    |> assert_has("[data-role=boosts_summary]", text: "1 Boosts")
  end

  test "also shows boosts on the /post/:id thread view", %{conn: conn, bob: bob, post: post} do
    assert {:ok, _} = Boosts.boost(bob, post)

    conn
    |> visit("/post/#{post.id}")
    |> assert_has("[data-role=fediverse_reactions]")
    |> assert_has("[data-role=boosts_summary]", text: "1 Boosts")
  end

  test "hides the reactions section when there are no boosts", %{conn: conn, post: post} do
    conn
    |> visit("/discussion/#{post.id}")
    |> refute_has("[data-role=fediverse_reactions]")
  end
end
