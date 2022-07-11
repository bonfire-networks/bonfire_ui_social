defmodule Bonfire.UI.Social.Activity.MediaLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop media, :list, default: []
  prop showing_within, :any


  def provider(media) do
    (e(media.metadata, "facebook", "og:site_name", nil) || e(media.metadata, "oembed", "provider_url", nil))
    |> as_string()
  end

  def description(media) do
    (e(media.metadata, "facebook", "og:description", nil) || e(media.metadata, "twitter", "twitter:description") || e(media.metadata, "other", "description", nil))
    |> as_string()
  end

  def preview_img(media) do
    ( e(media.metadata, "facebook", "og:image", nil) || e(media.metadata, "twitter", "twitter:image", nil) || e(media.metadata, "oembed", "thumbnail_url", nil) || media_img(media) )
    |> as_string()
  end

  def media_img(media) do
    ( e(media.metadata, "oembed", "url", nil) || media_url(media) )
    |> as_string()
  end

  def media_label(media) do
    ( e(media.metadata, "label", nil) || e(media.metadata, "oembed", "title", nil) || e(media.metadata, "facebook", "og:title", nil) || e(media.metadata, "twitter", "twitter:title", nil) || e(media.metadata, "other", "title", nil) )
    |> as_string()
  end

  def as_string(list) when is_list(list) do
    List.first(list) |> as_string()
  end
  def as_string(other) do
    to_string(other)
  end

end
