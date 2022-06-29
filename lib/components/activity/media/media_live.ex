defmodule Bonfire.UI.Social.Activity.MediaLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop media, :list, default: []
  prop showing_within, :any

  def preview_img(media) do
    e(media.metadata, "facebook", "og:image", nil) || e(media.metadata, "twitter", "twitter:image", nil) || e(media.metadata, "oembed", "thumbnail_url", nil) || media_img(media)
  end

  def media_img(media) do
    e(media.metadata, "oembed", "url", nil) || media_url(media)
  end

  def media_label(media) do
    e(media.metadata, "label", nil) || e(media.metadata, "oembed", "title", nil) || e(media.metadata, "facebook", "og:title", nil) || e(media.metadata, "twitter", "twitter:title", nil) || e(media.metadata, "other", "title", nil)
  end
end
