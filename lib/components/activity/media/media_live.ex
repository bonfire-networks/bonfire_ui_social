defmodule Bonfire.UI.Social.Activity.MediaLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Files

  prop media, :any, default: nil
  prop label, :string, default: nil

  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_inception, :boolean, default: false
  prop parent_id, :any, default: nil

  prop cw, :any, default: nil
  prop muted, :boolean, default: false
  prop autoplay, :any, default: false

  prop css_borders, :css_class, default: "border border-base-content/10 rounded-md"
  prop small_icon, :boolean, default: false

  # TODO: move all these to config (and move to Bonfire.Files)
  @image_types ["image", "photo"]
  @image_formats ["jpg", "jpeg", "png", "gif", "webp", "svg", "apng"]
  @image_exts Enum.map(@image_formats, &".#{&1}")

  @audio_types ["audio", "song"]
  @audio_formats ["m4a", "oga", "ogg", "mp3", "flac", "mpa", "mpeg", "aac", "caf", "wav"]
  @audio_exts Enum.map(@audio_formats, &".#{&1}")

  @video_types ["video"]
  @video_formats ["mp4", "mkv", "ogv", "ogg", "webm", "mov", "mpeg"]
  @video_exts Enum.map(@audio_formats, &".#{&1}")

  @multimedia_formats @audio_formats ++ @video_formats
  @multimedia_exts @audio_exts ++ @video_exts
  @multimedia_types @audio_types ++ @video_types ++ ["embed", "rich"]

  prop multimedia_exts, :list, default: @multimedia_exts
  prop multimedia_types, :list, default: @multimedia_types

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

    # |> debug("the_medias...")

    {image_list, multimedia_list, link_list} =
      media
      |> Enum.reduce({[], [], []}, fn m, {image_list, multimedia_list, link_list} ->
        cond do
          String.starts_with?(m.media_type || "", @image_types) or
              Files.has_extension?(m.path || "", @image_exts) ->
            {[m | image_list], multimedia_list, link_list}

          String.starts_with?(m.media_type || "", @multimedia_types) or
              Files.has_extension?(m.path || "", @multimedia_exts) ->
            {image_list, [m | multimedia_list], link_list}

          true ->
            {image_list, multimedia_list, [m | link_list]}
        end
      end)
      |> flood("3_media_lists")

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
    |> assign(:multimedia_exts, @multimedia_exts)
    |> assign(:multimedia_types, @multimedia_types)
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

  def the_medias(%struct{} = media) when struct in [Bonfire.Files.Media] do
    # {e(m, :media_type, nil), media}
    [media]
  end

  def the_medias(media) do
    error(media, "no valid Media assigned")
    []
  end

  def is_image?(url), do: Files.has_extension?(url || "", @image_exts)

  def is_image?(url, media_type),
    do: is_image?(url) or String.starts_with?(media_type || "", @image_types)

  def is_multimedia?(url), do: Files.has_extension?(url || "", @multimedia_exts)

  def is_multimedia?(url, media_type),
    do: is_multimedia?(url) or String.starts_with?(media_type || "", @multimedia_types)

  def is_supported_multimedia_format?(url, media_type),
    do:
      is_multimedia?(url, media_type) and String.ends_with?(media_type || "", @multimedia_formats)

  def is_video?(url), do: Files.has_extension?(url || "", @video_exts)

  def is_video?(url, media_type),
    do: is_video?(url) or String.starts_with?(media_type || "", @video_types)

  def is_supported_video_format?(url, media_type),
    do: is_video?(url, media_type) and String.ends_with?(media_type || "", @video_formats)

  def is_audio?(url), do: Files.has_extension?(url, @audio_exts)

  def is_audio?(url, media_type),
    do: is_audio?(url) or String.starts_with?(media_type || "", @audio_types)

  def is_supported_audio_format?(url, media_type),
    do: is_audio?(url, media_type) and String.ends_with?(media_type || "", @audio_formats)

  def is_supported_audio_format?(_url, _), do: false

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
    (Media.thumbnail_url(media)
     |> debug("medthumbur") ||
       e(media, :metadata, "oembed", "thumbnail_url", nil) ||
       e(media, :metadata, "twitter", "image", nil) ||
       (e(media, :metadata, "facebook", "image", "url", nil) ||
          e(media, :metadata, "facebook", "image", nil)) ||
       e(media, :metadata, "image", "url", nil) ||
       e(media, :metadata, "image", nil) ||
       e(media, :metadata, "icon", "url", nil) ||
       e(media, :metadata, "icon", nil) ||
       media_img(media))
    |> unwrap()
  end

  def media_img(%{} = media) do
    (e(media, :metadata, "oembed", "url", nil) || Media.image_url(media) |> debug("medimageur"))
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
