defmodule Bonfire.UI.Social.Activity.MediaTileLive do
  @moduledoc """
  A piece of media as a tile, for a media feed's rows (one per `Bonfire.Files.Media`): on `/media` and the media feed presets, its caption, the media as `Bonfire.UI.Social.Activity.MediaLive` shows it in a post, and how many posts use it. In the composer's picker (`showing_within: :media_picker`) it is only a thumbnail, square for an image or video and a compact row for audio or a document, with the picker's actions (its default slot) laid over it: a full player there was too heavy for choosing a file.

  It is a `custom_preview` for `Bonfire.UI.Social.FeedLive`, which gives it each media row as `object`.
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

  @doc "The kind of a compact row in the composer's picker, as `Bonfire.UI.Common.UploadPreviewEntryLive.preview_kind/1` names it."
  def kind_label("audio"), do: l("Audio")
  def kind_label("pdf"), do: l("PDF")
  def kind_label(_), do: l("Document")

  @doc "Whether `media` is an image or a video, which fit a grid's column; anything else (eg. an audio player or a document) takes the grid's full width."
  def visual?(media) do
    type = e(media, :media_type, "") || ""

    not Bonfire.Files.Media.embed_type?(type) and
      (String.starts_with?(type, "image") or String.starts_with?(type, "video"))
  end
end
