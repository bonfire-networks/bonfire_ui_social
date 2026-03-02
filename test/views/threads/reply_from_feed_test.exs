defmodule Bonfire.UI.Social.ReplyFromFeed.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)
    other_account = fake_account!()
    other_user = fake_user!(other_account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me, other_user: other_user}
  end

  test "reply button is shown on posts in the feed", %{conn: conn, me: me} do
    {:ok, _post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "post with reply button"}},
        boundary: "public"
      )

    conn
    |> visit("/feed/local")
    |> assert_has("[data-id=action_reply]")
  end

  test "reply created via API appears in the thread", %{conn: conn, me: me, other_user: other_user} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "Original post for reply"}},
        boundary: "public"
      )

    {:ok, _reply} =
      Posts.publish(
        current_user: other_user,
        post_attrs: %{
          post_content: %{html_body: "This is a reply"},
          reply_to_id: post.id
        },
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("article", text: "Original post for reply")
    |> assert_has("article", text: "This is a reply")
  end

  test "reply shows original post context in thread", %{conn: conn, me: me, other_user: other_user} do
    original_body = "Original context post #{System.unique_integer()}"
    reply_body = "Reply to context #{System.unique_integer()}"

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: original_body}},
        boundary: "public"
      )

    {:ok, reply} =
      Posts.publish(
        current_user: other_user,
        post_attrs: %{
          post_content: %{html_body: reply_body},
          reply_to_id: post.id
        },
        boundary: "public"
      )

    # Visiting the reply's thread page should show both original and reply
    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("article", text: original_body)
    |> assert_has("article", text: reply_body)
  end
end
