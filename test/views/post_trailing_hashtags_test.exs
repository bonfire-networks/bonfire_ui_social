defmodule Bonfire.UI.Social.PostTrailingHashtagsTest do
  @moduledoc """
  A post ending in a line of hashtags shows its text, while that line is kept for tagging but hidden, as Mastodon does.
  """
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  test "a post's trailing hashtags are hidden on its page, and its text is shown" do
    alice = fake_user!()

    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: alice,
        post_attrs: %{
          post_content: %{html_body: "This is a post about data protection.\n#privacy #gdpr"}
        },
        boundary: "public"
      )

    conn(user: alice, account: alice.account)
    |> visit("/post/#{post.id}")
    |> wait_async()
    |> assert_has("[data-id=object_body]", text: "data protection")
    |> assert_has("[data-id=object_body] .invisible a", text: "#privacy")
    |> assert_has("[data-id=object_body] .invisible a", text: "#gdpr")
    |> refute_has("[data-id=object_body] .invisible", text: "data protection")
  end
end
