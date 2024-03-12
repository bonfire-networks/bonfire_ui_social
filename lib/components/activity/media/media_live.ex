defmodule Bonfire.UI.Social.Activity.MediaLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop media, :any, default: nil
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_inception, :boolean, default: false
  prop label, :string, default: nil
  prop parent_id, :any, default: nil
  prop cw, :any, default: nil

  @image_exts [".jpg", ".jpeg", ".png", ".gif", ".webp"]
  @image_types ["image", "photo"]
  @multimedia_exts [".mp4", ".mkv", ".ogv", ".ogg", ".mp3", ".mpa", ".webm"]
  @multimedia_types ["video", "embed", "audio", "song", "rich"]

  def render(assigns) do
    # medias = the_medias(medias)

    # {multimedia_list, link_list} =
    # the_medias(medias)
    # |> Enum.split_with(
    #   &(String.starts_with?(&1.media_type, @multimedia_types) or
    #       String.ends_with?(Media.media_url(&1), @multimedia_exts))
    # )

    media =
      assigns[:media]
      # |> debug()
      |> the_medias()
      |> debug("the_medias")

    {image_list, multimedia_list, link_list} =
      media
      |> Enum.reduce({[], [], []}, fn m, {image_list, multimedia_list, link_list} ->
        cond do
          String.starts_with?(m.media_type || "", @image_types) or
              String.ends_with?(m.path || "", @image_exts) ->
            {[m | image_list], multimedia_list, link_list}

          String.starts_with?(m.media_type || "", @multimedia_types) or
              String.ends_with?(m.path || "", @multimedia_exts) ->
            {image_list, [m | multimedia_list], link_list}

          true ->
            {image_list, multimedia_list, [m | link_list]}
        end
      end)
      |> debug("3_media_lists")

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
    |> assign(:media, media)
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

  def the_medias(medias) when is_list(medias) do
    medias
    |> Enum.flat_map(&the_medias/1)
  end

  def the_medias(%{media: %{id: _} = media}) do
    the_medias(media)
  end

  def the_medias(%Bonfire.Files.Media{} = media) do
    # {e(m, :media_type, nil), media}
    [media]
  end

  def the_medias(media) do
    error(media, "no valid Media assigned")
    []
  end

  def is_image?(url), do: String.ends_with?(url || "", @image_exts)

  def is_image?(url, media_type),
    do: String.ends_with?(url, @image_exts) or String.starts_with?(media_type || "", @image_types)

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
    (e(media.metadata, "facebook", "site_name", nil) ||
       e(media.metadata, "oembed", "provider_url", nil))
    |> unwrap()
  end

  def preview_img(%{media: media}), do: preview_img(media)

  def preview_img(%{} = media) do
    (e(media, :metadata, "oembed", "thumbnail_url", nil) ||
       e(media, :metadata, "facebook", "image", nil) ||
       e(media, :metadata, "twitter", "image", nil) ||
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

  def unwrap(list) when is_list(list) do
    List.first(list)
    # |> unwrap()
  end

  def unwrap(other) do
    other
    # |> to_string()
  end
end
