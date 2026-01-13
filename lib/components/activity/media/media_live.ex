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
  prop autoplay, :any, default: nil

  prop css_borders, :css_class, default: "border border-base-content/20 rounded-md"
  prop small_icon, :boolean, default: false
  prop disable_lazy, :boolean, default: true

  # TODO: move all these to config (and move to Bonfire.Files)
  @image_types ["image", "photo"]
  @image_formats ["jpg", "jpeg", "png", "gif", "webp", "svg", "apng", "ico"]
  @image_exts Enum.map(@image_formats, &".#{&1}")

  @audio_types ["audio", "song"]
  @audio_formats ["m4a", "oga", "ogg", "mp3", "flac", "mpa", "mpeg", "aac", "caf", "wav"]
  @audio_exts Enum.map(@audio_formats, &".#{&1}")

  @video_types ["video"]
  @video_formats ["mp4", "mkv", "ogv", "ogg", "webm", "mov", "mpeg"]
  @video_exts Enum.map(@video_formats, &".#{&1}")

  @multimedia_formats @audio_formats ++ @video_formats
  @multimedia_exts @audio_exts ++ @video_exts
  @multimedia_types @audio_types ++ @video_types ++ ["embed"]

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

    {image_list, gif_list, multimedia_list, link_list} =
      media
      |> Enum.reduce({[], [], [], []}, fn m, {image_list, gif_list, multimedia_list, link_list} ->
        cond do
          is_gif?(m.path, m.media_type, m) ->
            {image_list, [m | gif_list], multimedia_list, link_list}

          String.starts_with?(m.media_type || "", @image_types) or
              Files.has_extension?(m.path || "", @image_exts) ->
            {[m | image_list], gif_list, multimedia_list, link_list}

          String.starts_with?(m.media_type || "", @multimedia_types) or
              Files.has_extension?(m.path || "", @multimedia_exts) ->
            {image_list, gif_list, [m | multimedia_list], link_list}

          # Video page links with embeddable content (YouTube, Vimeo, PeerTube, Owncast, etc.)
          is_embeddable?(m.media_type, e(m.metadata, "oembed", nil)) and preview_img(m) ->
            {image_list, gif_list, [m | multimedia_list], link_list}

          true ->
            {image_list, gif_list, multimedia_list, [m | link_list]}
        end
      end)
      |> debug("3_media_lists")

    multimedia_count = Enum.count(multimedia_list)
    image_count = Enum.count(image_list)
    gif_count = Enum.count(gif_list)
    link_count = Enum.count(link_list)

    case assigns[:parent_id] do
      nil ->
        nil

      id ->
        Bonfire.Common.Cache.put("num_media:#{id}", [
          multimedia_count,
          image_count,
          gif_count,
          link_count
        ])
    end

    # Determine autoplay value based on prop and settings
    autoplay =
      case assigns[:autoplay] do
        nil ->
          case assigns[:viewing_main_object] &&
                 Settings.get(
                   [Bonfire.UI.Social.Activity.MediaLive, :autoplay],
                   nil,
                   assigns[:__context__]
                 ) do
            true -> true
            _ -> false
          end

        other ->
          other
      end

    assigns =
      assigns
      |> assign(:autoplay, autoplay)
      |> assign(:media, media)
      # |> assign(:multimedia_list, multimedia_list(medias))
      # |> assign(:link_list, link_list(medias))
      |> assign(:image_list, image_list)
      |> assign(:gif_list, gif_list)
      |> assign(:multimedia_exts, @multimedia_exts)
      |> assign(:multimedia_types, @multimedia_types)
      |> assign(:multimedia_list, multimedia_list)
      |> assign(:link_list, link_list)
      |> assign(:multimedia_count, multimedia_count)
      |> assign(:image_count, image_count)
      |> assign(:gif_count, gif_count)
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

  def is_supported_multimedia_format?(url, media_type) do
    is_multimedia?(url, media_type) and String.ends_with?(media_type || "", @multimedia_formats)
  end

  def is_playable_multimedia_format?(url, media_type, oembed \\ nil) do
    # Handle embedded content (YouTube, Vimeo, etc.) + video or audio formats that can be played in the browser
    is_embeddable?(media_type, oembed) || is_supported_multimedia_format?(url, media_type)
  end

  def is_embeddable?(media_type, oembed \\ nil) do
    e(oembed, "html", nil) || e(oembed, "url", nil) ||
      String.starts_with?(media_type || "", "embed")
  end

  @doc """
  Extract the embed URL from oEmbed HTML iframe src attribute.
  Returns nil if no iframe or src attribute is found.
  """
  def extract_oembed_url(nil), do: nil

  def extract_oembed_url(html) when is_binary(html) do
    case Regex.run(~r/src=["']([^"']+)["']/, html) do
      [_, url] -> url
      _ -> nil
    end
  end

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

  def is_gif?(url), do: Files.has_extension?(url || "", [".gif"])

  def is_gif?(url, media_type),
    do: is_gif?(url) or String.starts_with?(media_type || "", "image/gif")

  def is_gif?(url, media_type, media) do
    # Basic file extension/type check first
    basic_gif_check = is_gif?(url, media_type)

    if basic_gif_check do
      true
    else
      # Simple converted GIF detection
      is_likely_converted_gif?(url, media_type, media)
    end
  end

  @doc """
  Detects videos that were likely originally GIFs but converted to MP4.
  Uses common conversion rules: GIFs up to 1MP (1280x720) are typically converted to soundless MP4s.
  """
  def is_converted_gif?(url, media_type, media) do
    is_likely_converted_gif?(url, media_type, media)
  end

  defp is_likely_converted_gif?(url, media_type, media) do
    if String.starts_with?(media_type || "", "video/") do
      metadata = media.metadata || %{}

      # Priority order: explicit indicators > size rules > conservative fallback
      cond do
        # 1. Explicit mentions (highest confidence)
        gif_explicitly_mentioned?(media, url) -> true
        # 2. Size-based (standard conversion: GIFs ≤ 1MP converted to MP4)
        within_gif_conversion_limits?(metadata) -> true
        # 3. Conservative fallback
        true -> false
      end
    else
      false
    end
  end

  # Check if GIF is explicitly mentioned in metadata or filename
  defp gif_explicitly_mentioned?(media, url) do
    gif_in_metadata?(media) or gif_in_filename?(url)
  end

  # Check if metadata contains GIF-related information
  defp gif_in_metadata?(media) do
    metadata = media.metadata || %{}
    label = get_in(metadata, ["label"]) || ""
    description = get_in(metadata, ["description"]) || ""

    # Check various metadata fields for GIF indicators
    String.contains?(String.downcase(label), "gif") or
      String.contains?(String.downcase(description), "gif") or
      get_in(metadata, ["original_type"]) == "image/gif" or
      get_in(metadata, ["converted_from"]) == "gif"
  end

  # Check if filename suggests it was originally a GIF
  defp gif_in_filename?(url) when is_binary(url) do
    # Extract filename from URL
    filename = Path.basename(url)

    # Check for explicit GIF indicators in filename
    String.contains?(String.downcase(filename), "gif")
  end

  defp gif_in_filename?(_), do: false

  # Check if dimensions are within common GIF conversion limits
  defp within_gif_conversion_limits?(metadata) do
    width = get_in(metadata, ["width"])
    height = get_in(metadata, ["height"])

    # Use standard conversion rules:
    # - GIFs up to 1MP (1280x720 = 921,600 pixels) are typically converted to MP4
    # - Dimensions must be ≤ 1280x720
    case {width, height} do
      {w, h} when is_integer(w) and is_integer(h) ->
        # 1MP limit
        w <= 1280 and h <= 720 and w * h <= 921_600

      _ ->
        # No dimensions = can't determine, be conservative
        false
    end
  end

  def provider(%{} = media) do
    (e(media.metadata, "facebook", "site_name", nil) ||
       e(media.metadata, "oembed", "provider_url", nil))
    |> unwrap()
  end

  def author(%{} = media) do
    (fediverse_creator(media) ||
       e(media, :metadata, "oembed", "author_name", nil) ||
       e(media, :metadata, "twitter", "creator", nil) ||
       e(media, :metadata, "other", "author", nil))
    |> unwrap()
  end

  def fediverse_creator_names(%{} = media, article_url \\ nil) do
    media
    |> fediverse_creators()
    # TODO: fetch these once when link metadata is fetched rather than checking every time
    |> Enum.map(&fetch_creator_profile(&1, article_url))
    |> Enum.filter(&(&1 != nil))
  end

  def fediverse_creator_names(_, _), do: []

  defp fediverse_creators(%{} = media) do
    # Handle multiple fediverse:creator tags
    creators = fediverse_creator(media)

    cond do
      is_list(creators) -> creators
      is_binary(creators) -> [creators]
      true -> []
    end
  end

  defp fediverse_creators(_), do: []

  defp fediverse_creator(%{} = media) do
    e(media, :metadata, "twitter", "fediverse:creator", nil) ||
      e(media, :metadata, "other", "fediverse:creator", nil)
  end

  # TODO: move to federation extension
  defp fetch_creator_profile("@" <> normalized_handle, article_url),
    do: fetch_creator_profile(normalized_handle, article_url)

  defp fetch_creator_profile(handle, article_url) do
    case ActivityPub.Actor.get_cached_or_fetch(username: handle) do
      {:ok, actor} ->
        # Check domain verification if article_url is provided
        if article_url && !is_domain_verified?(actor, article_url) do
          nil
        else
          [username, instance] = String.split(handle, "@", parts: 2)

          %{
            username: actor.username,
            display_name: actor.data["name"] || actor.data["preferredUsername"] || username,
            avatar_url: get_in(actor.data, ["icon", "url"]),
            profile_url: actor.data["url"] || "https://#{instance}/@#{username}"
          }
        end

      {:error, _reason} ->
        nil
    end
  end

  defp fetch_creator_profile(_, _), do: nil

  defp is_domain_verified?(actor, article_url) do
    article_domain = URI.parse(article_url).host
    allowed_domains = actor.data["attributionDomains"] || []

    cond do
      # If user has configured allowlist, check it
      length(allowed_domains) > 0 ->
        article_domain in allowed_domains

      # Fallback: if no allowlist, only allow same-domain attribution
      true ->
        creator_domain = String.split(actor.username, "@") |> List.last()
        article_domain == creator_domain
    end
  end

  def author_url(%{} = media) do
    (e(media, :metadata, "oembed", "author_url", nil) ||
       e(media, :metadata, "twitter", "creator_url", nil))
    |> unwrap()
  end

  def preview_img(%{media: media}), do: preview_img(media)

  def preview_img(%{} = media) do
    # Check for common app/site tile images which are often good previews
    # Check for Open Graph images which might be nested
    # Handle ActivityPub icon (can be object or array, e.g., from PeerTube)
    # Check json_ld for PeerTube videos
    # Check preview field for Mastodon videos
    preview =
      e(media, :metadata, "oembed", "thumbnail_url", nil) ||
        e(media, :metadata, "twitter", "image", nil) ||
        (e(media, :metadata, "facebook", "image", "url", nil) ||
           e(media, :metadata, "facebook", "image", nil)) ||
        e(media, :metadata, "image", "url", nil) ||
        e(media, :metadata, "image", nil) ||
        extract_ap_icon_url(e(media, :metadata, "icon", nil)) ||
        extract_ap_icon_url(e(media, :metadata, "json_ld", "icon", nil)) ||
        extract_ap_icon_url(e(media, :metadata, "preview", nil)) ||
        e(media, :metadata, "other", "msapplication-TileImage", nil) ||
        e(media, :metadata, "other", "apple-touch-icon", nil) ||
        e(media, :metadata, "other", "og:image", nil) ||
        e(media, :metadata, "other", "og:image:url", nil) ||
        Media.thumbnail_url(media)
        |> debug("medthumbur")

    # Only fall back to media_img if we have a proper image media type
    # Never use video URLs as poster images
    preview =
      preview ||
        if is_image_media_type?(media.media_type), do: media_img(media), else: nil

    preview |> unwrap()
  end

  # Extract URL from ActivityPub icon (handles both single object and array)
  defp extract_ap_icon_url(nil), do: nil

  defp extract_ap_icon_url(icons) when is_list(icons) do
    # Pick the largest icon (best quality thumbnail)
    icons
    |> Enum.filter(&is_map/1)
    |> Enum.max_by(fn icon -> (icon["width"] || 0) * (icon["height"] || 0) end, fn -> nil end)
    |> extract_ap_icon_url()
  end

  defp extract_ap_icon_url(%{"url" => url}) when is_binary(url), do: url
  defp extract_ap_icon_url(%{"href" => url}) when is_binary(url), do: url
  defp extract_ap_icon_url(url) when is_binary(url), do: url
  defp extract_ap_icon_url(_), do: nil

  # Helper to check if media type is actually an image
  defp is_image_media_type?(media_type) do
    String.starts_with?(media_type || "", @image_types)
  end

  def media_img(%{} = media) do
    Media.image_url(media)
    |> debug("medimageur")
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
