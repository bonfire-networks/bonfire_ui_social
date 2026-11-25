defmodule Bonfire.UI.Social.MediaGridTest do
  @moduledoc """
  The `/media` page lists the local instance's media as tiles in a grid, one per file however many posts share it, with how many posts use it. Link previews aren't media of their own, so they aren't listed.
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
    Fake.post_with_media(me, shared, "second")

    once = Fake.upload_media(:images, me, "once")
    Fake.post_with_media(me, once, "third")

    conn
    |> visit("/media")
    |> wait_async()
    |> assert_has("[data-id=media_grid] [data-id=media_tile]", count: 2)
    # an icon and the number, as the trending media feed shows it, with the words in its title
    |> assert_has("#{tile(shared)} [data-role=used_count][title='Used in 2 posts']", text: "2")
    |> assert_has("#{tile(once)} [data-role=used_count][title='Used in 1 post']", text: "1")
  end

  test "a tile shows its media as a post does, so it can be viewed bigger, with its alt button marked when it has no alt text, and a player or document takes the full width",
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
    # a player is marked wide, so the grid (`data-id=media_grid`'s list) gives its row the whole width; the grid item is the feed's own wrapper, so the class doing it sits on the list
    |> assert_has("#{tile(audio)}[data-wide]")
    |> refute_has("#{tile(with_alt)}[data-wide]")
    |> assert_has("[data-id=media_grid] [class*='has([data-wide])]:col-span-full']")
    # a tile is a size container: narrow, its player hides the secondary controls (vidstack's one row of fixed buttons overflows otherwise), keeping play and the time; in a post the player keeps them all
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
