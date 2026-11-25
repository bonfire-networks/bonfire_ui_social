defmodule Bonfire.UI.Social.Activity.MediaPlayerRenderTest do
  @moduledoc """
  Verifies that direct video files, HLS (.m3u8) streams and audio are rendered
  via the Vidstack player container (`[data-vidstack]`, initialised by
  remote_media_live.hooks.js) rather than a bare native element — which is what
  unlocks HLS playback (#1715/#1721) and the playback-speed control (#1035).
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.UI.Social.Activity.RemoteMediaLive

  defp media(attrs) do
    struct(
      Bonfire.Files.Media,
      Keyword.merge([id: "01HZZ0RemoteMediaPlayerTEST", metadata: %{}], attrs)
    )
  end

  defp render_media(media) do
    render_stateful(RemoteMediaLive, %{id: "player-test", media: media})
  end

  test "a direct mp4 video renders a vidstack player container with its source" do
    url = "https://peertube.example/static/web-videos/clip-1080.mp4"
    html = render_media(media(path: url, media_type: "video/mp4"))

    assert html =~ "<video"
    assert html =~ "data-vidstack"
    assert html =~ ~s(<source src="#{url}")
    # the hook MUST be attached or vidstack never mounts (empty rectangle bug)
    assert html =~ "phx-hook=\"Bonfire.UI.Social.Activity.RemoteMediaLive#default\""
    # the lazy player bundle URL is rendered server-side (digest-aware via static_path), and
    # carries a version outside prod, where there is no digest to bust a cached ES module
    assert html =~ "data-player-bundle="
    assert html =~ ~r"/assets/vidstack_player\.js\?v=\d+"
    # autoplay must be OFF unless explicitly enabled — Surface omits the boolean
    # attribute entirely when false, so it must not appear at all
    refute html =~ "autoplay"
  end

  test "an HLS (.m3u8) stream renders a vidstack <video> (so it can play inline)" do
    url = "https://peertube.example/static/streaming-playlists/hls/abc/master.m3u8"
    html = render_media(media(path: url, media_type: "application/x-mpegURL"))

    assert html =~ "<video"
    assert html =~ "data-vidstack"
    assert html =~ ~s(<source src="#{url}")
    assert html =~ ~s(type="application/x-mpegURL")
  end

  test "an audio file renders a native <audio> element (so vidstack uses the audio layout)" do
    url = "https://example.com/podcast-episode.mp3"
    html = render_media(media(path: url, media_type: "audio/mpeg"))

    assert html =~ "<audio"
    assert html =~ "data-vidstack"
    assert html =~ ~s(<source src="#{url}")
  end

  # in a post the player keeps all its controls: hiding the secondary ones when narrow is the media grid's (see `Bonfire.UI.Social.MediaGridTest`), not the player's own
  test "an audio player in a post keeps all its controls" do
    html =
      render_media(media(path: "https://example.com/an-episode.mp3", media_type: "audio/mpeg"))

    assert html =~ ~s(data-role="audio_player")
    refute html =~ "[&_.vds-volume]:hidden"
  end

  test "a YouTube/oEmbed video page renders an inline iframe, NOT the vidstack player" do
    # media_type "video" is the oEmbed *type*, not a playable file — it must go to
    # the iframe/embed path, not vidstack (which would fail canPlayType).
    html =
      render_media(
        media(
          path: "https://www.youtube.com/watch?v=abc123",
          media_type: "video",
          metadata: %{
            "oembed" => %{
              "type" => "video",
              "html" => ~s(<iframe src="https://www.youtube.com/embed/abc123"></iframe>)
            }
          }
        )
      )

    assert html =~ "<iframe"
    refute html =~ "data-vidstack"
  end

  # a `rich` oEmbed (SoundCloud, Spotify, Bandcamp…: oEmbed has no `audio` type) plays in place as a `video` one does: our own iframe of the provider's iframe `src`, never the provider's HTML
  describe "rich oEmbed players" do
    @soundcloud_html ~s|<iframe width="100%" height="166" scrolling="no" frameborder="no" src="https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F1"></iframe><script>alert(1)</script>|

    defp rich(html, extra \\ %{}) do
      media(
        path: "https://soundcloud.com/someone/a-track",
        media_type: "rich",
        metadata: %{"oembed" => Map.merge(%{"type" => "rich", "html" => html}, extra)}
      )
    end

    test "a rich oEmbed with an iframe is a player, at the height it gives" do
      media = rich(@soundcloud_html, %{"height" => 166})
      assert Bonfire.UI.Social.Activity.MediaLive.has_embed_player?(media)

      html = render_media(media)
      assert html =~ ~r/<iframe[^>]*src="https:\/\/w\.soundcloud\.com\/player\//
      assert html =~ "height: 166px"
      refute html =~ "alert(1)", "the provider's own HTML isn't rendered"
    end

    test "control: a rich oEmbed without an iframe (eg. a quoted post with a script) stays a link card" do
      media =
        rich(
          ~s(<blockquote>a post</blockquote><script src="https://platform.example.com/widgets.js"></script>)
        )

      refute Bonfire.UI.Social.Activity.MediaLive.has_embed_player?(media)
    end

    test "an article embed (a quote of the post with an iframe of it, as WordPress gives) stays a link card" do
      media =
        rich(
          ~s|<blockquote class="wp-embedded-content" data-secret="x"><a href="https://blog.example.com/a-post/">A post</a></blockquote><iframe class="wp-embedded-content" sandbox="allow-scripts" security="restricted" src="https://blog.example.com/a-post/embed/#?secret=x" width="500" height="282"></iframe>|
        )

      refute Bonfire.Files.Media.player_type(media)
      refute Bonfire.UI.Social.Activity.MediaLive.has_embed_player?(media)
      refute render_media(media) =~ "<iframe"
    end

    test "a video oEmbed with no iframe to play (eg. a quote and a script, as TikTok gives) stays a link card" do
      media =
        media(
          path: "https://www.tiktok.com/t/x/",
          media_type: "video",
          metadata: %{
            "oembed" => %{
              "type" => "video",
              "html" =>
                ~s(<blockquote class="tiktok-embed" cite="https://www.tiktok.com/@a/video/1"><a href="https://www.tiktok.com/@a">@a</a></blockquote><script async src="https://www.tiktok.com/embed.js"></script>)
            }
          }
        )

      refute Bonfire.Files.Media.player_type(media)
      refute Bonfire.UI.Social.Activity.MediaLive.has_embed_player?(media)
    end

    test "control: the rich player is a player for both, so the two checks agree" do
      media = rich(@soundcloud_html)
      assert Bonfire.Files.Media.player_type(media)
      assert Bonfire.UI.Social.Activity.MediaLive.has_embed_player?(media)
    end

    test "an embed URL that isn't https is never put in an iframe" do
      assert nil ==
               Bonfire.UI.Social.Activity.MediaLive.extract_oembed_url(
                 ~s|<iframe src="javascript:alert(1)"></iframe>|
               )

      assert nil ==
               Bonfire.UI.Social.Activity.RemoteMediaLive.rewrite_embed_url("javascript:alert(1)")

      html =
        render_media(
          media(
            path: "https://video.example.com/watch/1",
            media_type: "video",
            metadata: %{
              "oembed" => %{
                "type" => "video",
                "html" => ~s|<iframe src="javascript:alert(1)"></iframe>|
              }
            }
          )
        )

      refute html =~ "javascript:"
    end

    test "control: an https embed URL is kept" do
      assert "https://w.soundcloud.com/player/?url=x" ==
               Bonfire.UI.Social.Activity.MediaLive.extract_oembed_url(
                 ~s(<script src="https://a.example/x.js"></script><iframe src="https://w.soundcloud.com/player/?url=x"></iframe>)
               )
    end
  end

  describe "PeerTube embeds" do
    # A federated PeerTube video (AP object in metadata.json_ld) must render the
    # origin instance's own player iframe (/videos/embed/<id>) — like Mastodon —
    # instead of playing the HLS stream in vidstack.
    @peertube_json_ld %{
      "type" => "Video",
      "id" => "https://peertube.example/videos/watch/abece3c3-b9c6-47f4-8040-f3eed8c602e6",
      "uuid" => "abece3c3-b9c6-47f4-8040-f3eed8c602e6"
    }

    test "peertube_embed_url/1 derives the embed URL from the watch-page id" do
      assert Bonfire.UI.Social.Activity.MediaLive.peertube_embed_url(%{
               metadata: %{"json_ld" => @peertube_json_ld}
             }) ==
               "https://peertube.example/videos/embed/abece3c3-b9c6-47f4-8040-f3eed8c602e6"
    end

    test "peertube_embed_url/1 handles /w/ short URLs" do
      assert Bonfire.UI.Social.Activity.MediaLive.peertube_embed_url(%{
               metadata: %{
                 "json_ld" => %{
                   "type" => "Video",
                   "id" => "https://peertube.example/w/sXDmBvDpgwKFWXLKEihJBT"
                 }
               }
             }) == "https://peertube.example/videos/embed/sXDmBvDpgwKFWXLKEihJBT"
    end

    test "peertube_embed_url/1 is nil for non-PeerTube media" do
      refute Bonfire.UI.Social.Activity.MediaLive.peertube_embed_url(%{metadata: %{}})

      refute Bonfire.UI.Social.Activity.MediaLive.peertube_embed_url(%{
               metadata: %{
                 "json_ld" => %{"type" => "Video", "id" => "https://example.com/some/other/page"}
               }
             })
    end

    test "a PeerTube HLS video renders the PeerTube player iframe, NOT vidstack" do
      html =
        render_media(
          media(
            path: "https://peertube.example/static/streaming-playlists/hls/abc/master.m3u8",
            media_type: "application/x-mpegURL",
            metadata: %{"json_ld" => @peertube_json_ld}
          )
        )

      assert html =~ "<iframe"
      assert html =~ "https://peertube.example/videos/embed/abece3c3-b9c6-47f4-8040-f3eed8c602e6"
      refute html =~ "data-vidstack"
    end
  end

  test "a GIF-marked mp4 stays a native looping <video> (no player chrome)" do
    url = "https://mastodon.example/media/reaction.mp4"

    html =
      render_media(
        media(path: url, media_type: "video/mp4", metadata: %{"original_type" => "image/gif"})
      )

    refute html =~ "data-vidstack"
    assert html =~ "gif-as-mp4"
  end

  # a link preview with a player has media_type `video/embed` or `audio/embed`: a link, never a file, so no `<source type>` of it and no vidstack
  describe "embed link previews" do
    alias Bonfire.UI.Social.Activity.MediaLive

    defp video_embed do
      media(
        path: "https://www.youtube.com/watch?v=abc",
        media_type: "video/embed",
        metadata: %{
          "oembed" => %{
            "type" => "video",
            "html" => ~s(<iframe src="https://www.youtube.com/embed/abc"></iframe>)
          }
        }
      )
    end

    defp audio_embed do
      media(
        path: "https://open.spotify.com/track/1",
        media_type: "audio/embed",
        metadata: %{
          "oembed" => %{
            "type" => "rich",
            "html" => ~s(<iframe src="https://open.spotify.com/embed/track/1"></iframe>)
          }
        }
      )
    end

    test "a video/embed renders its iframe, not a file player" do
      html = render_media(video_embed())

      assert html =~ "youtube-nocookie.com/embed/abc"
      refute html =~ ~s(type="video/embed")
      refute html =~ "data-vidstack"
    end

    test "an audio/embed renders its iframe, not an audio element" do
      html = render_media(audio_embed())

      assert html =~ "https://open.spotify.com/embed/track/1"
      refute html =~ ~s(type="audio/embed")
      refute html =~ "<audio"
    end

    test "the media list gives a video/embed and an audio/embed the link player, not the file players" do
      # control: a video file gets the file player, so its marker is what tells the two apart
      file_html =
        render_media_list(media(path: "https://example.com/v.mp4", media_type: "video/mp4"))

      assert file_html =~ ~s(<figcaption class="sr-only")

      for m <- [video_embed(), audio_embed()] do
        html = render_media_list(m)

        assert html =~ "<iframe"
        refute html =~ ~s(<figcaption class="sr-only")
        refute html =~ "data-vidstack"
      end
    end

    defp render_media_list(m) do
      Phoenix.LiveViewTest.render_component(&MediaLive.render/1,
        media: [m],
        parent_id: "list-test",
        showing_within: nil,
        cw: nil,
        muted: false,
        autoplay: nil,
        label: nil,
        viewing_main_object: false,
        activity_inception: false,
        media_text_up_font?: false,
        css_borders: "",
        small_icon: false,
        disable_lazy: false,
        mark_missing_alt: false,
        multimedia_exts: [],
        multimedia_types: [],
        __context__: %{}
      )
    end

    test "embed types are not files" do
      url = "https://example.com/a-page"

      refute MediaLive.is_video?(url, "video/embed")
      refute MediaLive.is_audio?(url, "audio/embed")
      assert MediaLive.is_embeddable?("video/embed")
      assert MediaLive.is_embeddable?("audio/embed")
      refute MediaLive.is_embeddable?("video/mp4")
      assert Bonfire.Files.Media.embed_type?("audio/embed")
      assert Bonfire.Files.Media.embed_type?("video/embed")
      assert Bonfire.Files.Media.embed_type?(%{media_type: "video/embed"})
      refute Bonfire.Files.Media.embed_type?("video/mp4")
      refute Bonfire.Files.Media.embed_type?(nil)
    end

    test "control: real files keep being files" do
      assert MediaLive.is_video?("https://example.com/a.mp4", "video/mp4")
      assert MediaLive.is_audio?("https://example.com/a.mp3", "audio/mpeg")
    end
  end
end
