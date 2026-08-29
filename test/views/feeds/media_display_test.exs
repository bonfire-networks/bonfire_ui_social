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

  # Alt text is what a screen reader reads out and what the `alt` badge reveals, and it is the half of a media's metadata that federates as an attachment's AS2 `name`. It had no rendering coverage at all, so a media that carries alt but no caption (exactly what arrives from another instance) could stop rendering it without anything failing.
  describe "alt text" do
    defp post_with_alt(me, metadata, body) do
      {:ok, media} =
        Bonfire.Files.upload(
          Bonfire.Files.ImageUploader,
          me,
          Bonfire.Files.Simulation.image_file(),
          %{metadata: metadata}
        )

      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{
            post_content: %{html_body: body},
            uploaded_media: [media]
          },
          boundary: "public"
        )

      post
    end

    test "an image's alt text is on the img element", %{conn: conn, me: me} do
      alt = "A sunset over the sea"
      post = post_with_alt(me, %{"alt" => alt}, "post with described image")

      conn
      |> visit("/discussion/#{post.id}")
      |> assert_has("img[alt='#{alt}']")
    end

    test "an image's alt text is revealed by the alt badge", %{conn: conn, me: me} do
      alt = "A chart of rising costs"
      post = post_with_alt(me, %{"alt" => alt}, "post with described chart")

      conn
      |> visit("/discussion/#{post.id}")
      |> assert_has("[data-id=media_alt]", text: alt)
    end

    test "alt text shows even when the media has no caption of its own", %{conn: conn, me: me} do
      # the federated case: an AS2 attachment carries one `name`, which is the alt text, so a
      # received media has alt and no label
      alt = "A cat asleep on a keyboard"
      post = post_with_alt(me, %{"alt" => alt}, "post with described cat")

      conn
      |> visit("/discussion/#{post.id}")
      |> assert_has("[data-id=media_alt]", text: alt)
    end

    # the badge still appears for an undescribed media, saying so — a missing description is worth
    # surfacing rather than hiding, and it's what tells an author their upload needs alt text
    test "an undescribed media says so rather than hiding the badge", %{conn: conn, me: me} do
      post = post_with_alt(me, %{}, "post with undescribed image")

      conn
      |> visit("/discussion/#{post.id}")
      |> assert_has("[data-id=article_media]")
      |> assert_has("[data-id=media_alt]", text: "no caption provided")
    end
  end
end
