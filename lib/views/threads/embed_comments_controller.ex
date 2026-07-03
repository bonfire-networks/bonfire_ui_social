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

  # For logged-in users the rendered HTML is personalized, but the
  # `:browser_or_cacheable` pipeline never loads the user into conn assigns, so
  # CacheControlPlug can't detect them and leaves its `public` cache-control
  # headers in place. Override with `private, no-store` so a header-trusting
  # shared cache/CDN can't store or share an authed user's HTML. (Guests keep
  # the cacheable headers.) No-op in dev, where CacheControlPlug already forces
  # `no-store`.
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
