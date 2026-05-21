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
    # the lazy player bundle URL is rendered server-side (digest-aware via static_path)
    assert html =~ "data-player-bundle="
    assert html =~ "/assets/vidstack_player.js"
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

  test "a GIF-marked mp4 stays a native looping <video> (no player chrome)" do
    url = "https://mastodon.example/media/reaction.mp4"

    html =
      render_media(
        media(path: url, media_type: "video/mp4", metadata: %{"original_type" => "image/gif"})
      )

    refute html =~ "data-vidstack"
    assert html =~ "gif-as-mp4"
  end
end
