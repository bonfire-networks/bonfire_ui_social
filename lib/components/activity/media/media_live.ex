defmodule Bonfire.UI.Social.Activity.MediaLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop media, :list, default: nil
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop label, :string, default: nil
  prop parent_id, :any, default: nil
  prop cw, :any, default: nil

  @image_exts [".jpg", ".jpeg", ".png", ".gif", ".webp"]
  @image_types ["image", "photo"]
  @multimedia_exts [".mp4", ".mkv", ".ogv", ".ogg", ".mp3", ".mpa", ".webm"]
  @multimedia_types ["video", "embed", "audio", "song", "rich"]

  def render(%{media: medias} = assigns) when is_list(medias) do
    do_render(assigns, medias)
  end

  def render(%{media: media} = assigns) when is_map(media) do
    do_render(assigns, [media])
  end

  def do_render(assigns, medias) do
    # medias = the_medias(medias)

    # {multimedia_list, link_list} =
    # the_medias(medias)
    # |> Enum.split_with(
    #   &(String.starts_with?(&1.media_type, @multimedia_types) or
    #       String.ends_with?(Media.media_url(&1), @multimedia_exts))
    # )

    {image_list, multimedia_list, link_list} =
      the_medias(medias)
      |> Enum.reduce({[], [], []}, fn m, {image_list, multimedia_list, link_list} ->
        cond do
          String.starts_with?(m.media_type, @image_types) or
              String.ends_with?(m.path, @image_exts) ->
            {[m | image_list], multimedia_list, link_list}

          String.starts_with?(m.media_type, @multimedia_types) or
              String.ends_with?(m.path, @multimedia_exts) ->
            {image_list, [m | multimedia_list], link_list}

          true ->
            {image_list, multimedia_list, [m | link_list]}
        end
      end)

    multimedia_count = Enum.count(multimedia_list)
    image_count = Enum.count(image_list)
    link_count = Enum.count(link_list)

    case assigns[:parent_id] do
      nil ->
        nil

      id ->
        Bonfire.Common.Cache.put("num_media:#{id}", [multimedia_count, image_count, link_count])
    end

    assigns
    # |> assign(:media, medias) 
    # |> assign(:multimedia_list, multimedia_list(medias)) 
    # |> assign(:link_list, link_list(medias))     
    |> assign(:image_list, image_list)
    |> assign(:multimedia_list, multimedia_list)
    |> assign(:link_list, link_list)
    |> assign(:multimedia_count, multimedia_count)
    |> assign(:image_count, image_count)
    |> assign(:link_count, link_count)
    |> render_sface()
  end

  def the_medias(medias) do
    medias
    |> Enum.map(&the_media/1)
  end

  def the_media(%{media: media}) do
    the_media(media)
  end

  def the_media(%Bonfire.Files.Media{} = media) do
    # {e(m, :media_type, nil), media}
    media
  end

  def the_media(media) do
    error(media, "no valid Media assigned")
    %Bonfire.Files.Media{}
  end

  def is_image?(url), do: String.ends_with?(url, @image_exts)

  def is_image?(url, media_type),
    do: String.ends_with?(url, @image_exts) or String.starts_with?(media_type, @image_types)

  # def multimedia_list(media) do
  #   Enum.filter(List.wrap(media), fn m ->
  #     m_type = m |> e(:media_type, nil)

  #     # WIP: use modal for videos and embeds too
  #     # String.starts_with?(m_type, @image_types) or
  #     String.starts_with?(m_type, @multimedia_exts ) or
  #       String.ends_with?(Media.media_url(m), @image_exts)
  #   end)
  # end

  # def link_list(media) do
  #   Enum.reject(List.wrap(media), fn m ->
  #     m_type = m |> e(:media_type, nil)

  #     String.starts_with?(m_type, @multimedia_exts) or
  #       String.ends_with?(Media.media_url(m), @image_exts)
  #   end)
  # end

  def provider(%{} = media) do
    (e(media.metadata, "facebook", "og:site_name", nil) ||
       e(media.metadata, "oembed", "provider_url", nil))
    |> unwrap()
  end

  def description(%{} = media) do
    json_ld = e(media.metadata, "json_ld", nil)

    (e(json_ld, "description", nil) ||
       e(media.metadata, "facebook", "og:description", nil) ||
       e(media.metadata, "twitter", "twitter:description", nil) ||
       e(media.metadata, "other", "description", nil) ||
       e(json_ld, "headline", nil))
    |> unwrap()
  end

  def preview_img(%{media: media}), do: preview_img(media)

  def preview_img(%{} = media) do
    (e(media, :metadata, "oembed", "thumbnail_url", nil) ||
       e(media, :metadata, "facebook", "og:image", nil) ||
       e(media, :metadata, "twitter", "twitter:image", nil) ||
       e(media, :metadata, "icon", "url", nil) || e(media, :metadata, "icon", nil) ||
       e(media, :metadata, "image", "url", nil) || e(media, :metadata, "image", nil) ||
       media_img(media))
    |> unwrap()
  end

  def media_img(%{} = media) do
    (e(media, :metadata, "oembed", "url", nil) || Media.image_url(media))
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
