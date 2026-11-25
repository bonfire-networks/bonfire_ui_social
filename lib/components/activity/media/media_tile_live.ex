defmodule Bonfire.UI.Social.Activity.MediaTileLive do
  @moduledoc """
  A piece of media as a tile, for a grid of a media feed's rows (one per `Bonfire.Files.Media`, eg. `/media`, or the composer's media picker): a one-line caption (see `Bonfire.Files.Media.media_caption/1`), then the media as `Bonfire.UI.Social.Activity.MediaLive` shows it in a post (so it can be viewed bigger, or played, and with its alt button marked when an image has no alt text), then how many posts use it.

  It is a `custom_preview` for `Bonfire.UI.Social.FeedLive`, which gives it each media row as `object`. Anything in its default slot (eg. the picker's actions) goes under the caption.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  # the media row (a `Media`, with the feed's `object_count`)
  prop object, :any, default: nil
  prop showing_within, :atom, default: :media_grid
  prop parent_id, :any, default: nil

  # what `ActivityLive` gives a `custom_preview` (not used by a tile)
  prop activity, :any, default: nil
  prop activity_component_id, :any, default: nil
  prop permalink, :string, default: nil
  prop cw, :any, default: nil

  slot default

  @doc "Whether `media` is an image or a video, which fit a grid's column; anything else (eg. an audio player or a document) takes the grid's full width."
  def visual?(media) do
    type = e(media, :media_type, "") || ""
    String.starts_with?(type, "image") or String.starts_with?(type, "video")
  end
end
