defmodule Bonfire.UI.Social.Activity.RemoteMediaLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.UI.Social.Activity.MediaLive
  alias Bonfire.UI.Common.MediaPlayerLive

  prop media, :map, default: nil
  prop parent_id, :any, default: nil

  prop muted, :boolean, default: false
  prop autoplay, :any, default: true

  prop show_embed, :boolean, default: nil

  prop base_css, :css_class, default: "max-w-screen w-full"

  # prop block_css, :css_class, default: [@default, "min-w-[400px] min-h-[260px] h-full"]

  prop base_image_css, :css_class,
    default: "max-h-[calc(var(--inner-window-height)_-_150px)] relative mx-auto"

  prop image_css, :css_class, default: ""

  prop video_css, :css_class,
    default: "h-full inline-block rounded-box border border-base-content/10"

  # prop type, :any, default: nil

  def handle_event("show_embed", _, socket) do
    {:noreply, assign(socket, show_embed: true)}
  end

  @doc """
  Rewrites a YouTube URL to use the privacy-friendly domain and appends query params.
  Only parses the URI once.

      iex> rewrite_embed_url("https://www.youtube.com/embed/abc123", %{"autoplay" => "1"})
      "https://www.youtube-nocookie.com/embed/abc123?autoplay=1"
  """
  def rewrite_embed_url(url, params \\ %{}) when is_binary(url) and is_map(params) do
    uri = URI.parse(url)

    # Rewrite host if it's a youtube domain
    new_host =
      case uri.host do
        "youtube.com" ->
          "www.youtube-nocookie.com"

        "www.youtube.com" ->
          "www.youtube-nocookie.com"

        host ->
          host
      end

    # Merge query params
    query = uri.query || ""

    query =
      if params != %{} do
        existing = URI.decode_query(query)
        merged = Map.merge(existing, params)
        URI.encode_query(merged)
      else
        query
      end

    uri = %{uri | host: new_host, query: query}

    URI.to_string(uri)
  end
end
