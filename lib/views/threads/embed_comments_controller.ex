defmodule Bonfire.UI.Social.EmbedCommentsController do
  use Bonfire.UI.Common.Web, :controller

  def index(conn, params), do: maybe_redirect_live(conn, params, "/comments/embed/interactive")

  def show(conn, %{"id" => id} = params),
    do: maybe_redirect_live(conn, params, "/comments/embed/interactive/#{id}")

  defp maybe_redirect_live(conn, params, live_path) do
    if Plug.Conn.get_session(conn, :current_user_id) do
      qs = conn.query_string
      redirect(conn, to: if(qs != "", do: "#{live_path}?#{qs}", else: live_path))
    else
      conn
      |> assign(
        no_header: true,
        without_sidebar: true,
        without_secondary_widgets: true,
        sidebar_widgets: [],
        force_static: true
      )
      |> live_render(Bonfire.UI.Social.EmbedCommentsLive,
        layout: {Bonfire.UI.Common.LayoutView, :iframe},
        # This LiveView is rendered via the controller (not mounted at the
        # router), so the connected mount receives `:not_mounted_at_router`
        # and would lose the query params. Carry them through the session so
        # the framework's `init_mount` can restore them as `current_params`.
        session: %{"params" => params}
      )
    end
  end
end
