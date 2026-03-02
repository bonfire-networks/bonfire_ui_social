defmodule Bonfire.UI.Social.MediaDisplay.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Social.Fake
  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me}
  end

  test "post with image shows media on post page", %{conn: conn, me: me} do
    media = Fake.upload_media(:images, me)

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{
          post_content: %{html_body: "post with image"},
          uploaded_media: [media]
        },
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("[data-id=article_media]")
  end

  test "post with image shows media in feed", %{conn: conn, me: me} do
    media = Fake.upload_media(:images, me)

    {:ok, _post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{
          post_content: %{html_body: "image in feed"},
          uploaded_media: [media]
        },
        boundary: "public"
      )

    conn
    |> visit("/feed/local")
    |> assert_has("[data-id=article_media]")
  end

  test "post without media does not show media container", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "text only post"}},
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> refute_has("[data-id=article_media]")
  end
end
