defmodule Bonfire.UI.Social.Activity.MediaGifDetectionTest do
  @moduledoc """
  Regression tests for bonfire-app#1643:
  "Video playback in a post has no controls and no volume. It says gif in
  upper right hand corner."

  When `MediaLive.is_gif?/3` returns true the video is rendered as a
  `gif-as-mp4`: `autoplay loop muted` with **no `controls`** and a "GIF" badge
  (see `remote_media_live.sface`). So any normal video misdetected as a GIF
  loses its controls and volume — exactly the reported bug.

  The current heuristic in `is_likely_converted_gif?/3` treats *any* `video/*`
  whose metadata width/height are within 1280x720 (1MP) as a converted GIF,
  with no check that the source was ever actually a GIF (e.g. no audio-track
  check, no explicit gif marker). 720p is an utterly ordinary video resolution,
  so this over-matches normal videos.
  """
  use ExUnit.Case, async: true

  alias Bonfire.UI.Social.Activity.MediaLive

  defp media(attrs), do: struct(Bonfire.Files.Media, attrs)

  describe "is_gif?/3 (GIF-vs-video detection)" do
    test "a normal 720p mp4 video is NOT a GIF (regression #1643)" do
      # A standard landscape video at exactly the 1280x720 limit, with no
      # 'gif' anywhere in its metadata or filename. This must keep its player
      # controls — i.e. must NOT be classified as a GIF.
      m =
        media(
          media_type: "video/mp4",
          path: "https://peertube.example/static/videos/holiday-clip.mp4",
          metadata: %{"width" => 1280, "height" => 720}
        )

      refute MediaLive.is_gif?(m.path, m.media_type, m),
             "a 1280x720 mp4 with no gif marker must not be treated as a GIF"
    end

    test "a small 480p mp4 video is NOT a GIF" do
      m =
        media(
          media_type: "video/mp4",
          path: "https://mastodon.example/media/short-talk.mp4",
          metadata: %{"width" => 640, "height" => 480}
        )

      refute MediaLive.is_gif?(m.path, m.media_type, m)
    end

    # --- the following document intended behaviour and should already pass ---

    test "an actual .gif file IS a GIF" do
      m = media(media_type: "image/gif", path: "https://example.com/cat.gif", metadata: %{})
      assert MediaLive.is_gif?(m.path, m.media_type, m)
    end

    test "an mp4 explicitly marked as a converted gif IS a GIF" do
      m =
        media(
          media_type: "video/mp4",
          path: "https://example.com/reaction.mp4",
          metadata: %{"width" => 480, "height" => 480, "original_type" => "image/gif"}
        )

      assert MediaLive.is_gif?(m.path, m.media_type, m)
    end

    test "an mp4 whose filename mentions gif IS a GIF" do
      m =
        media(
          media_type: "video/mp4",
          path: "https://example.com/funny-gif.mp4",
          metadata: %{}
        )

      assert MediaLive.is_gif?(m.path, m.media_type, m)
    end
  end
end
