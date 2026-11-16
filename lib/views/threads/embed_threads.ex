defmodule Bonfire.UI.Social.EmbedThreads do
  @moduledoc """
  Finds, or creates, the Media post that a page embedding the comments widget is discussed under.

  Reading an existing thread is always allowed. A missing one is created only when both hold: a real account to attribute it to (see `creator/1`), and a host the operator allowlisted in `IFRAME_ALLOWED_ORIGINS` (or a loopback page on a dev/test instance, which is then kept local-only).
  """
  use Bonfire.Common.Utils
  use Bonfire.Common.Config

  @doc """
  The Media post for `uri` (an embedding page's URL), created when missing and allowed.

  `params` are the embed's request params (`embed_parent`, `published_at`). A missing thread is created only for a page its origin serves (a loopback preview on a dev/test instance excepted), and, with `rate_limit_ip:` in `opts`, at most a few attempts a minute from that IP. Returns `{:ok, media}`, `{:error, :no_creator}`, `{:error, :host_not_allowed}`, `{:error, :rate_limited}`, or `{:error, reason}` when creation failed (also when the page is not served).
  """
  def get_or_create(uri, params, creator, opts \\ []) when is_binary(uri) do
    # read first, so displaying an existing thread needs no creator and no creation privileges. `get_by_url` matches by the canonical `path` or a source url in `metadata.urls` (tracking params normalised away)
    case Bonfire.Files.Media.get_by_url(uri) do
      {:ok, media} -> {:ok, media}
      _ -> maybe_create(uri, params, creator, opts)
    end
    # with its locality, which its callers need to name it by its ActivityPub id (`URIs.canonical_url/2`)
    ~> Bonfire.Common.Repo.maybe_preload(:peered)
    |> case do
      %{id: _} = media -> {:ok, media}
      other -> other
    end
  end

  defp maybe_create(uri, params, creator, opts) do
    cond do
      is_nil(creator) ->
        {:error, :no_creator}

      not (loopback_preview_allowed?(params) or Bonfire.UI.Common.EmbedOrigins.host_allowed?(uri)) ->
        warn(
          uri,
          "Not creating a thread anchor: the URI's host is not allowlisted in IFRAME_ALLOWED_ORIGINS"
        )

        {:error, :host_not_allowed}

      # every attempt to start a thread counts, whether or not its page exists: a guest asking for pages one after the other is told to wait
      match?({:error, _}, rate_limit(opts[:rate_limit_ip])) ->
        warn(uri, "Not creating a thread anchor: too many attempts from this address")
        {:error, :rate_limited}

      true ->
        case Bonfire.Files.Media.get_or_add_media_by_uri(
               creator,
               uri,
               # a preview loaded from a localhost/loopback page is kept local-only so dev testing can't publish public/federated content
               boundary(params),
               nil,
               # backdate the anchor to the article's publication date (if given & in the past), so importing an old article doesn't jump to the top of feeds
               update_existing: false,
               id: published_id(params),
               # the fetch that makes the preview is also the check that the page exists: one its origin does not serve (the address is a guest's choice) makes no thread. A loopback dev preview may have no server
               require_ok_status: not loopback_preview_allowed?(params)
             ) do
          {:ok, %{id: _} = media} ->
            {:ok, media}

          other ->
            error(other, "Could not resolve media_uri to a thread")
        end
    end
  end

  # per IP, as the forms are (`:throttle_forms`); no IP given (a caller that is not a guest's request) is not limited
  defp rate_limit(nil), do: :ok

  defp rate_limit(ip) do
    # tunable: `:bonfire, :rate_limit, :embed_threads` (`scale_ms`, `limit`)
    Bonfire.UI.Common.RateLimit.check(:embed_threads, ip, 60_000, 5)
  end

  @doc "Who a newly created Media post is attributed to: the configured import author, else the signed-in viewer (`nil` when neither)."
  def creator(current_user) do
    configured_import_author() || current_user
  end

  defp configured_import_author do
    maybe_apply(Bonfire.Ghost, :auto_import_as, [], fallback_return: nil) ||
      Config.get([:bonfire_ghost, :auto_import_as], nil)
  end

  # the boundary to give a post CREATED from an embed: local-only when the embedding page is a localhost/loopback origin (dev preview), so testing can't publish public/federated content
  defp boundary(params), do: if(loopback_origin?(params), do: "local", else: "public")

  # a backdated id from the `published_at` param (nil when absent, unparseable, or in the future: `generate_ulid_if_past/1` only ever moves a post EARLIER), so importing an old article doesn't surface as freshly posted
  defp published_id(params) do
    case e(params, "published_at", nil) do
      date when is_binary(date) and date != "" ->
        Bonfire.Common.DatesTimes.generate_ulid_if_past(date)

      _ ->
        nil
    end
  end

  # `embed_parent` is supplied by the client, so anyone can claim a loopback page: only skip the allowlisted domains for one on a dev/test instance (it's still created local-only, see `boundary/1`)
  defp loopback_preview_allowed?(params) do
    Config.get([:bonfire_ui_social, :embed_loopback_previews], Config.env() in [:dev, :test]) and
      loopback_origin?(params)
  end

  # is the embedding page (or the media URI it points at) served from a loopback host?
  defp loopback_origin?(params) do
    loopback_host?(e(params, "embed_parent", nil) || e(params, "media_uri", nil))
  end

  defp loopback_host?(url) when is_binary(url) do
    case URI.parse(url).host do
      nil -> false
      host -> host in ~w(localhost 0.0.0.0 ::1 [::1]) or String.starts_with?(host, "127.")
    end
  end

  defp loopback_host?(_), do: false
end
