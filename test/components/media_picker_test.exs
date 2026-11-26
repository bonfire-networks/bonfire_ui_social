defmodule Bonfire.UI.Social.MediaPickerTest do
  @moduledoc """
  The composer's media picker: "Your media" opens a panel listing the author's own media as tiles, each with Insert and Attach. A picked file shows among the composer's uploads, with its alt text editable there (and a note when other posts use it), and publishing attaches that same `Media` again rather than uploading it again.

  The composer lives in its own LiveView (`PersistentLive`), whose updates are delivered to itself, so these tests drive that view (`composer_view/1`), as `smart_input_test.exs` does.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  import Phoenix.LiveViewTest
  alias Bonfire.Social.Fake

  setup do
    # some tests list more than the test env's page of 2
    Process.put([:bonfire, :default_pagination_limit], 10)

    account = fake_account!()
    me = fake_user!(account)

    mine = Fake.upload_media(:images, me, "mine")
    Fake.post_with_media(me, mine, "an earlier post")

    {:ok, conn: conn(user: me, account: account), me: me, mine: mine}
  end

  # visits a page with the composer, opens the picker, and runs `fun` with the composer's view
  defp with_picker(conn, fun) do
    conn
    |> visit("/feed/local")
    |> PhoenixTest.unwrap(fn view ->
      composer = Bonfire.UI.Common.Testing.Helpers.composer_view(view)

      composer |> element("[data-role=open_media_picker]") |> render_click()
      assert has_element?(composer, "[data-id=media_picker]")
      render_async(composer)

      fun.(composer)
      render(view)
    end)
  end

  defp entry(media), do: "[data-role=upload_entry][data-media-id='#{media.id}']"

  test "lists my media as tiles, each with Insert and Attach, without the use count", %{conn: conn, mine: mine} do
    other = fake_user!()
    theirs = Fake.upload_media(:images, other, "theirs")
    Fake.post_with_media(other, theirs, "their post")

    with_picker(conn, fn composer ->
      tile = "[data-id=media_picker] [data-id=media_tile][data-media-id='#{mine.id}']"
      assert has_element?(composer, tile)
      # the picker alone lays the tiles out in a grid (feeds and `/media` show one per row)
      assert has_element?(
               composer,
               "[data-id=media_picker] [data-id=feed_activity_list][class*='grid-cols']"
             )

      assert has_element?(composer, "#{tile} [data-role=pick_insert]")
      assert has_element?(composer, "#{tile} [data-role=pick_attach]")
      # the picker's tiles are only the media: no "Used in N" (it stays on `/media`, `media_grid_test.exs`)
      refute has_element?(composer, "#{tile} [data-role=used_count]")
      refute has_element?(composer, "[data-id=media_picker] [data-media-id='#{theirs.id}']")
    end)
  end

  # a row of media type pills, one type at a time, sent as the feed's tab filter buttons send it
  test "the media type pills narrow the tiles, and All lists them again", %{conn: conn, me: me, mine: mine} do
    audio = Fake.upload_media(:audio, me, "a recording")
    Fake.post_with_media(me, audio, "a recording")

    with_picker(conn, fn composer ->
      tile = &"[data-id=media_picker] [data-id=media_tile][data-media-id='#{&1.id}']"
      # the control: both kinds listed before filtering
      assert has_element?(composer, tile.(mine))
      assert has_element?(composer, tile.(audio))

      pill = &"[data-id=media_picker] [data-role=media_type_pill][data-type=#{&1}]"
      composer |> element(pill.("audio")) |> render_click()
      render_async(composer)

      assert has_element?(composer, tile.(audio))
      refute has_element?(composer, tile.(mine))

      composer |> element(pill.("attachment")) |> render_click()
      render_async(composer)

      assert has_element?(composer, tile.(audio))
      assert has_element?(composer, tile.(mine))
    end)
  end

  test "an audio file is a compact row with its own play button, not the post's player", %{
    conn: conn,
    me: me
  } do
    audio = Fake.upload_media(:audio, me, "a recording")
    Fake.post_with_media(me, audio, "a recording")

    with_picker(conn, fn composer ->
      row = "[data-id=media_picker] [data-media-id='#{audio.id}'] [data-role=media_row][data-preview=audio]"

      assert has_element?(composer, "#{row} [data-role=media_play]")
      assert has_element?(composer, row, "Audio")
      refute has_element?(composer, "[data-id=media_picker] [data-media-id='#{audio.id}'] [data-role=audio_player]")
    end)
  end

  test "minimising the composer closes the picker", %{conn: conn} do
    with_picker(conn, fn composer ->
      composer |> element("#minimize_composer_button") |> render_click()

      refute has_element?(composer, "[data-id=media_picker]")
    end)
  end

  # an embed (a video page, stored as a link `Media` with no file of ours) isn't one of my files: no type filter lists it, while my uploaded video is listed
  test "the Video filter lists my uploaded video and not an embed I posted", %{conn: conn, me: me} do
    video = Fake.upload_media(:videos, me, "a clip")
    Fake.post_with_media(me, video, "a clip")

    embed_url = "https://video.example.com/w/#{Needle.UID.generate()}"

    {:ok, embed} =
      Bonfire.Files.Media.insert(me, embed_url, %{media_type: "video.other", size: 0}, %{
        url: embed_url,
        metadata: %{"content_type" => "text/html"}
      })

    Fake.post_with_media(me, embed, "a video page")

    with_picker(conn, fn composer ->
      tile = &"[data-id=media_picker] [data-id=media_tile][data-media-id='#{&1.id}']"
      composer
      |> element("[data-id=media_picker] [data-role=media_type_pill][data-type=video]")
      |> render_click()
      render_async(composer)

      assert has_element?(composer, tile.(video))
      refute has_element?(composer, tile.(embed))
    end)
  end

  test "Insert places the file's URL in the text and adds it to the uploads", %{
    conn: conn,
    mine: mine
  } do
    path = Bonfire.Files.inline_url(mine) |> URI.parse() |> Map.get(:path)

    with_picker(conn, fn composer ->
      insert = "[data-media-id='#{mine.id}'] [data-role=pick_insert]"
      # the text it places at the cursor
      assert has_element?(composer, "#{insert}[phx-click*='#{path}']")

      composer |> element(insert) |> render_click()

      assert has_element?(
               composer,
               "#{entry(mine)} input[name='upload_metadata[#{mine.id}][media_id]'][value='#{mine.id}']"
             )

      # shown as an upload of an image is: its thumbnail
      assert has_element?(composer, "#{entry(mine)} [data-preview=image] img[src]")
    end)
  end

  test "an inserted audio or document file shows the same type icon as an upload of that type",
       %{conn: conn, me: me} do
    audio = Fake.upload_media(:audio, me, "a recording")
    Fake.post_with_media(me, audio, "a recording")

    {:ok, pdf} =
      Bonfire.Files.upload(
        Bonfire.Files.DocumentUploader,
        me,
        Bonfire.Files.Simulation.pdf_file(),
        %{metadata: %{label: "a paper"}}
      )

    Fake.post_with_media(me, pdf, "a paper")

    with_picker(conn, fn composer ->
      # an audio file is placed as an upload is, `![](url)`, so it shows as its player in the editor and once published; a document as its bare URL
      audio_path = Bonfire.Files.inline_url(audio) |> URI.parse() |> Map.get(:path)
      pdf_path = Bonfire.Files.inline_url(pdf) |> URI.parse() |> Map.get(:path)

      assert has_element?(
               composer,
               "[data-media-id='#{audio.id}'] [data-role=pick_insert][phx-click*='![](']"
             )

      assert has_element?(
               composer,
               "[data-media-id='#{audio.id}'] [data-role=pick_insert][phx-click*='#{audio_path}']"
             )

      refute has_element?(
               composer,
               "[data-media-id='#{pdf.id}'] [data-role=pick_insert][phx-click*='![](']"
             )

      assert has_element?(
               composer,
               "[data-media-id='#{pdf.id}'] [data-role=pick_insert][phx-click*='#{pdf_path}']"
             )

      for media <- [audio, pdf] do
        composer
        |> element("[data-media-id='#{media.id}'] [data-role=pick_insert]")
        |> render_click()
      end

      assert has_element?(composer, "#{entry(audio)} [data-preview=audio]")
      assert has_element?(composer, "#{entry(pdf)} [data-preview=pdf]")
      refute has_element?(composer, "#{entry(pdf)} img")
    end)
  end

  test "Attach adds it to the uploads, with its alt text and a note that other posts use it, and publishing attaches the same Media",
       %{conn: conn, me: me, mine: mine} do
    with_picker(conn, fn composer ->
      composer
      |> element("[data-media-id='#{mine.id}'] [data-role=pick_attach]")
      |> render_click()

      assert has_element?(
               composer,
               "#{entry(mine)} textarea[name='upload_metadata[#{mine.id}][alt]']"
             )

      assert has_element?(composer, "#{entry(mine)} [data-role=alt_shared_note]", "1")

      composer
      |> form("#smart_input_form", %{
        "post" => %{"post_content" => %{"html_body" => "reusing a file"}}
      })
      |> render_submit()
    end)

    # attached to the earlier post and to the new one: the same Media, not a new upload
    assert repo().aggregate(
             from(f in Bonfire.Files, where: f.media_id == ^mine.id),
             :count
           ) == 2

    assert repo().aggregate(
             from(m in Bonfire.Files.Media, where: m.creator_id == ^id(me)),
             :count
           ) == 1
  end

  # alt text belongs to the Media, so editing it for a picked file changes it for every post that uses it
  test "editing a picked file's alt text saves it on the Media when publishing", %{
    conn: conn,
    mine: mine
  } do
    with_picker(conn, fn composer ->
      composer
      |> element("[data-media-id='#{mine.id}'] [data-role=pick_attach]")
      |> render_click()

      composer
      |> form("#smart_input_form", %{
        "post" => %{"post_content" => %{"html_body" => "with a better description"}},
        "upload_metadata" => %{mine.id => %{"alt" => "A better description"}}
      })
      |> render_submit()
    end)

    assert {:ok, media} = Bonfire.Files.Media.one(id: mine.id)
    assert Bonfire.Files.Media.media_alt(media, false) == "A better description"
  end

  test "a picked file can be removed from the uploads", %{conn: conn, mine: mine} do
    with_picker(conn, fn composer ->
      composer
      |> element("[data-media-id='#{mine.id}'] [data-role=pick_attach]")
      |> render_click()

      assert has_element?(composer, entry(mine))

      composer |> element("#{entry(mine)} [data-role=unpick_media]") |> render_click()
      refute has_element?(composer, entry(mine))
    end)
  end
end
