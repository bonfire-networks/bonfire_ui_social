defmodule Bonfire.UI.Social.Feeds.HovercardTaggingTest do
  @moduledoc """
  In a real feed, another user's post tags its author links for the profile hover card, and my own post doesn't. Proves `ActivityLive` passes the subject's type from a feed-loaded activity to `SubjectLive`.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts

  test "another user's post tags its avatar, name and username links; mine doesn't" do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!()

    {:ok, _} =
      Posts.publish(
        current_user: alice,
        boundary: "public",
        post_attrs: %{post_content: %{html_body: "alice says hi"}}
      )

    {:ok, _} =
      Posts.publish(
        current_user: me,
        boundary: "public",
        post_attrs: %{post_content: %{html_body: "I say hi"}}
      )

    conn(user: me, account: account)
    |> visit("/feed/local")
    # so a missing post fails here, not as a missing attribute
    |> assert_has("[data-id=feed] article", text: "alice says hi")
    |> assert_has("[data-hovercard-id='#{alice.id}']", count: 3)
    |> refute_has("[data-hovercard-id='#{me.id}']")
  end

  test "in my boosts feed, the author of a post I boosted is tagged, though the actor is me" do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!()

    {:ok, post} =
      Posts.publish(
        current_user: alice,
        boundary: "public",
        post_attrs: %{post_content: %{html_body: "alice wrote this"}}
      )

    {:ok, _} = Bonfire.Social.Boosts.boost(me, post)

    conn(user: me, account: account)
    |> visit("/feed/my_boosts")
    |> assert_has("[data-id=feed] article", text: "alice wrote this")
    |> assert_has("[data-hovercard-id='#{alice.id}']")
  end
end
