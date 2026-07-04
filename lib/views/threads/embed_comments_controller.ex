defmodule Bonfire.UI.Social.EmbedCommentsController do
  use Bonfire.UI.Common.Web, :controller

  def index(conn, params), do: render_embed(conn, params)

  def show(conn, params),
    do: render_embed(conn, params)

  defp render_embed(conn, params) do
    authed? = not is_nil(Plug.Conn.get_session(conn, :current_user_id))

    conn
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
