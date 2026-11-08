defmodule Bonfire.UI.Social.EmbedThreads do
  @moduledoc """
  Finds, or creates, the Media post that a page embedding the comments widget is discussed under.

  Reading an existing thread is always allowed. A missing one is created only when both hold: a real account to attribute it to (see `creator/1`), and a host the operator allowlisted in `IFRAME_ALLOWED_ORIGINS` (or a loopback page on a dev/test instance, which is then kept local-only).
  """
  use Bonfire.Common.Utils
  use Bonfire.Common.Config

  @doc """
  The Media post for `uri` (an embedding page's URL), created when missing and allowed.

  `params` are the embed's request params (`embed_parent`, `published_at`). Returns `{:ok, media}`, `{:error, :no_creator}`, `{:error, :host_not_allowed}`, or `{:error, reason}` when creation failed.
  """
  def get_or_create(uri, params, creator) when is_binary(uri) do
    # read first, so displaying an existing thread needs no creator and no creation privileges. `get_by_url` matches by the canonical `path` or a source url in `metadata.urls` (tracking params normalised away)
    case Bonfire.Files.Media.get_by_url(uri) do
      {:ok, media} -> {:ok, media}
      _ -> maybe_create(uri, params, creator)
    end
    # with its locality, which its callers need to name it by its ActivityPub id (`URIs.canonical_url/2`)
    ~> Bonfire.Common.Repo.maybe_preload(:peered)
    |> case do
      %{id: _} = media -> {:ok, media}
      other -> other
    end
  end

  defp maybe_create(uri, params, creator) do
    cond do
      is_nil(creator) ->
        {:error, :no_creator}

      not (loopback_preview_allowed?(params) or Bonfire.UI.Common.EmbedOrigins.host_allowed?(uri)) ->
        warn(
          uri,
          "Not creating a thread anchor: the URI's host is not allowlisted in IFRAME_ALLOWED_ORIGINS"
        )

        {:error, :host_not_allowed}

      true ->
        case Bonfire.Files.Media.get_or_add_media_by_uri(
               creator,
               uri,
               # a preview loaded from a localhost/loopback page is kept local-only so dev testing can't publish public/federated content
               boundary(params),
               nil,
               # backdate the anchor to the article's publication date (if given & in the past), so importing an old article doesn't jump to the top of feeds
               update_existing: false,
               id: published_id(params)
             ) do
          {:ok, %{id: _} = media} ->
            {:ok, media}

          other ->
            error(other, "Could not resolve media_uri to a thread")
        end
    end
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
