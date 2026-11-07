defmodule Bonfire.UI.Social.EmbedCommentsController do
  use Bonfire.UI.Common.Web, :controller

  # A page template can point fediverse fetchers here with `<link rel="alternate" type="application/activity+json" href="…/comments/embed?media_uri=<page url>">`, so an ActivityPub request is answered with the page's Media post, never with the embed's HTML.
  def index(conn, %{"media_uri" => uri} = params) when is_binary(uri) do
    if activity_pub_request?(conn),
      do: redirect_to_ap_object(conn, uri, params),
      else: render_embed(conn, params)
  end

  def index(conn, params), do: render_embed(conn, params)

  def show(conn, params),
    do: render_embed(conn, params)

  defp activity_pub_request?(conn),
    do: Phoenix.Controller.get_format(conn) in ["activity+json", "ld+json", "json"]

  # same creation rules as an embed load (no signed-in viewer here, so only an import author can create)
  defp redirect_to_ap_object(conn, uri, params) do
    conn = vary_on_accept(conn)

    with {:ok, media} <-
           Bonfire.UI.Social.EmbedThreads.get_or_create(
             uri,
             params,
             Bonfire.UI.Social.EmbedThreads.creator(nil)
           ),
         ap_id when is_binary(ap_id) <-
           Bonfire.Common.URIs.canonical_url(media) do
      conn
      |> Plug.Conn.put_resp_header("cache-control", "private, no-store")
      |> redirect(external: ap_id)
    else
      _ -> send_resp(conn, 404, "Not found")
    end
  end

  # the same URL answers browsers with HTML and fetchers with a redirect, so caches must key on Accept
  defp vary_on_accept(conn), do: Plug.Conn.put_resp_header(conn, "vary", "Accept")

  defp render_embed(conn, params) do
    authed? = not is_nil(Plug.Conn.get_session(conn, :current_user_id))

    conn
    |> vary_on_accept()
    |> maybe_no_cache(authed?)
    |> assign(
      no_header: true,
      without_sidebar: true,
      without_secondary_widgets: true,
      sidebar_widgets: [],
      force_static: true,
      force_live: authed?
    )
    |> live_render(Bonfire.UI.Social.EmbedCommentsLive,
      layout: {Bonfire.UI.Common.LayoutView, :iframe},
      # This LiveView is rendered via the controller (not mounted at the
      # router), so the connected mount receives `:not_mounted_at_router`
      # and would lose the query params. Carry them through the session so
      # the framework's `init_mount` can restore them as `current_params`.
      session: embed_session(conn, params)
    )
  end

  # CacheControlPlug detects auth via conn assigns, but `:browser_or_cacheable`
  # never loads the user there, so it stamps authed HTML `public` too. Override
  # to keep a shared cache/CDN from storing a logged-in user's response.
  defp maybe_no_cache(conn, true),
    do: Plug.Conn.put_resp_header(conn, "cache-control", "private, no-store")

  defp maybe_no_cache(conn, false), do: conn

  defp embed_session(conn, params) do
    %{
      "params" => params,
      "current_user_id" => Plug.Conn.get_session(conn, :current_user_id),
      "current_account_id" => Plug.Conn.get_session(conn, :current_account_id)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
