defmodule Bonfire.UI.Social.MediaGridTest do
  @moduledoc """
  The `/media` page lists the local instance's media one per row at the feed's full width, one per file however many posts share it, with how many posts use it. Link previews aren't media of their own, so they aren't listed. The media feed presets (`/feed/local_media`, images, videos, audio, documents) show each file the same way; only the composer's media picker lays them out in a grid.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Social.Fake

  setup do
    # some tests list more than the test env's page of 2
    Process.put([:bonfire, :default_pagination_limit], 10)

    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account), me: me}
  end

  defp tile(media), do: "[data-id=media_tile][data-media-id='#{media.id}']"

  defp image(me, metadata) do
    {:ok, media} =
      Bonfire.Files.upload(
        Bonfire.Files.ImageUploader,
        me,
        Bonfire.Files.Simulation.icon_file(),
        %{metadata: metadata}
      )

    Fake.post_with_media(me, media, "a post")
    media
  end

  test "shows each file once, as a tile with how many posts use it", %{conn: conn, me: me} do
    shared = Fake.upload_media(:images, me, "shared")
    Fake.post_with_media(me, shared, "first")
    newest = Fake.post_with_media(me, shared, "second")

    once = Fake.upload_media(:images, me, "once")
    only = Fake.post_with_media(me, once, "third")

    conn
    |> visit("/media")
    |> wait_async()
    |> assert_has("[data-id=media_feed] [data-id=media_tile]", count: 2)
    # an icon and the number, as the trending media feed shows it, with the words in its title
    |> assert_has("#{tile(shared)} [data-role=used_count][title='Used in 2 posts']", text: "2")
    |> assert_has("#{tile(once)} [data-role=used_count][title='Used in 1 post']", text: "1")
    # the count is a link to the newest post using the file, as the trending media feed's is
    |> assert_has("#{tile(shared)} a[data-role=used_count][href*='#{newest.id}']")
    |> assert_has("#{tile(once)} a[data-role=used_count][href*='#{only.id}']")
  end

  test "a tile shows its media as a post does, so it can be viewed bigger, with its alt button marked when it has no alt text, one per row rather than in a grid",
       %{conn: conn, me: me} do
    no_alt = image(me, %{label: "no alt"})
    with_alt = image(me, %{label: "with alt", alt: "a red square"})
    audio = Fake.upload_media(:audio, me, "a recording")
    Fake.post_with_media(me, audio, "a recording")

    conn
    |> visit("/media")
    |> wait_async()
    # an image as a post shows it (`MediaLive`'s carousel, whose click opens its viewer)
    |> assert_has("#{tile(no_alt)} [data-id=article_media]")
    |> assert_has("#{tile(no_alt)} [data-id=media_alt][data-missing-alt]")
    |> assert_has("#{tile(with_alt)} [data-id=media_alt]")
    |> refute_has("#{tile(with_alt)} [data-id=media_alt][data-missing-alt]")
    # a player is marked wide, which only the picker's grid uses (it gives the row the whole width)
    |> assert_has("#{tile(audio)}[data-wide]")
    |> refute_has("#{tile(with_alt)}[data-wide]")
    # one per row: the feed's own list, without a grid
    |> assert_has("[data-id=media_feed] [data-id=feed_activity_list]")
    |> refute_has("[data-id=media_feed] [data-id=feed_activity_list][class*='grid']")
    # a tile is a size container: narrow (in the picker's grid), its player hides the secondary controls (vidstack's one row of fixed buttons overflows otherwise), keeping play and the time; at a feed's width it keeps them all
    |> assert_has(
      "#{tile(audio)}[class*='@container'][class*='@max-lg:[&_.vds-volume]:hidden!'][class*='@max-lg:[&_.vds-mute-button]:hidden!']"
    )
    |> refute_has("#{tile(audio)}[class*='vds-play-button']")
  end

  test "a tile's caption is its label and alt text, else its description, else nothing", %{
    conn: conn,
    me: me
  } do
    labelled = image(me, %{label: "A label"})
    described = image(me, %{description: "Only a description"})
    alt_only = image(me, %{alt: "Only an alt"})
    bare = image(me, %{})

    conn
    |> visit("/media")
    |> wait_async()
    |> assert_has("#{tile(labelled)} [data-role=media_caption][title='A label']", text: "A label")
    |> assert_has("#{tile(described)} [data-role=media_caption]", text: "Only a description")
    |> assert_has("#{tile(alt_only)} [data-role=media_caption]", text: "Only an alt")
    # the control: the bare image is listed, without a caption
    |> assert_has(tile(bare))
    |> refute_has("#{tile(bare)} [data-role=media_caption]")
  end

  test "the media feed presets show each file as `/media` does, one per row, rather than as a link card",
       %{conn: conn, me: me} do
    image = image(me, %{label: "An image"})
    video = Fake.upload_media(:videos, me, "A video")
    Fake.post_with_media(me, video, "a video")
    audio = Fake.upload_media(:audio, me, "A recording")
    Fake.post_with_media(me, audio, "a recording")

    {:ok, document} =
      Bonfire.Files.upload(
        Bonfire.Files.DocumentUploader,
        me,
        Bonfire.Files.Simulation.pdf_file(),
        %{metadata: %{label: "A document"}}
      )

    Fake.post_with_media(me, document, "a document")

    url = "https://example.com/a-paper"

    {:ok, paper} =
      Bonfire.Files.Media.insert(me, url, %{media_type: "research", size: 0}, %{
        url: url,
        media_type: "research",
        metadata: %{"label" => "A paper"}
      })

    Fake.post_with_media(me, paper, "a paper")

    for {preset, media} <- [
          local_media: image,
          images: image,
          videos: video,
          audio: audio,
          documents: document,
          research: paper
        ] do
      conn
      |> visit("/feed/#{preset}")
      |> wait_async()
      |> assert_has(tile(media))
      |> refute_has("[data-id=top_level_media]")
      |> refute_has("[data-id=feed_activity_list][class*='grid']")
    end
  end

  test "the trending links feed shows each link as a tile, with its post count linking to the newest post and its boosts, likes and replies, which other media feeds leave out",
       %{conn: conn, me: me} do
    other = fake_user!(fake_account!())
    url = "https://example.com/a-trending-article"

    {:ok, link} =
      Bonfire.Files.Media.insert(me, url, %{media_type: "link", size: 0}, %{
        url: url,
        media_type: "link",
        metadata: %{"label" => "A trending article"}
      })

    Fake.post_with_media(me, link, "first")
    newest = Fake.post_with_media(me, link, "second")

    image = Fake.upload_media(:images, me, "an image")
    image_post = Fake.post_with_media(me, image, "an image")

    # both posts have a boost, a like and a reply, so a feed that leaves the counts out does so by not loading them
    for post <- [newest, image_post] do
      {:ok, _} = Bonfire.Social.Boosts.boost(other, post)
      {:ok, _} = Bonfire.Social.Likes.like(other, post)

      Bonfire.Posts.Fake.fake_post!(other, "public", %{
        post_content: %{html_body: "a reply"},
        reply_to_id: post.id
      })
    end

    conn
    |> visit("/feed/trending_links")
    |> wait_async()
    |> assert_has(tile(link))
    |> refute_has("[data-id=top_level_media]")
    |> assert_has("#{tile(link)} a[data-role=used_count][title='Used in 2 posts'][href*='#{newest.id}']",
      text: "2"
    )
    |> assert_has("#{tile(link)} [title=Boosts]", text: "1")
    |> assert_has("#{tile(link)} [title=Likes]", text: "1")
    |> assert_has("#{tile(link)} [title=Replies]", text: "1")

    conn
    |> visit("/feed/local_media")
    |> wait_async()
    |> assert_has("#{tile(image)} a[data-role=used_count][href*='#{image_post.id}']")
    |> refute_has("#{tile(image)} [title=Boosts]")
    |> refute_has("#{tile(image)} [title=Likes]")
    |> refute_has("#{tile(image)} [title=Replies]")
  end

  test "leaves out link previews", %{conn: conn, me: me} do
    url = "https://example.com/an-article"

    {:ok, link} =
      Bonfire.Files.Media.insert(me, url, %{media_type: "link", size: 0}, %{
        url: url,
        media_type: "link",
        metadata: %{"label" => "An article"}
      })

    Fake.post_with_media(me, link, "a link")

    # the control: a file in another post is listed
    image = Fake.upload_media(:images, me, "an image")
    Fake.post_with_media(me, image, "an image")

    conn
    |> visit("/media")
    |> wait_async()
    |> assert_has(tile(image))
    |> refute_has(tile(link))
  end
end
