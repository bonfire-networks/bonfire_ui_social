defmodule Bonfire.UI.Social.Activity.MediaLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop media, :list, default: nil
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop label, :string, default: nil

  def media_list(media) do
    Enum.filter(List.wrap(media), fn m ->
      m_type = m |> the_media() |> e(:media_type, nil)

      # String.starts_with?(m_type, ["image", "video", "embed", "audio", "song", "photo", "rich"]) or
        String.starts_with?(m_type, ["image", "photo", "rich"]) or
        String.contains?(Media.media_url(m), [".jpg", ".jpeg", ".png", ".gif", ".webp"])
    end)
  end

  def link_list(media) do
    Enum.reject(List.wrap(media), fn m ->
      m_type = m |> the_media() |> e(:media_type, nil)

      String.starts_with?(m_type, ["image", "photo", "rich"]) or
        String.contains?(Media.media_url(m), [".jpg", ".jpeg", ".png", ".gif", ".webp"])
    end)
  end

  def the_media(%{media: media}) do
    media
  end

  def the_media(media) do
    media
  end

  def provider(%{} = media) do
    (e(media.metadata, "facebook", "og:site_name", nil) ||
       e(media.metadata, "oembed", "provider_url", nil))
    |> unwrap()
  end

  def description(%{} = media) do
    (e(media.metadata, "facebook", "og:description", nil) ||
       e(media.metadata, "twitter", "twitter:description", nil) ||
       e(media.metadata, "other", "description", nil))
    |> unwrap()
  end

  def preview_img(%{} = media) do
    (e(media.metadata, "oembed", "thumbnail_url", nil) ||
       e(media.metadata, "facebook", "og:image", nil) ||
       e(media.metadata, "twitter", "twitter:image", nil) ||
       media_img(media))
    |> unwrap()
  end

  def media_img(%{} = media) do
    (e(media.metadata, "oembed", "url", nil) || Media.image_url(media))
    |> unwrap()
  end

  def media_img(_), do: nil

  def media_label(%{} = media) do
    (e(media.metadata, "label", nil) || e(media.metadata, "oembed", "title", nil) ||
       e(media.metadata, "facebook", "og:title", nil) ||
       e(media.metadata, "twitter", "twitter:title", nil) ||
       e(media.metadata, "other", "title", nil))
    |> unwrap()
  end

  def unwrap(list) when is_list(list) do
    List.first(list)
    # |> unwrap()
  end

  def unwrap(other) do
    other
    # |> to_string()
  end
end
