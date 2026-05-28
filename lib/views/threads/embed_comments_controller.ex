defmodule Bonfire.UI.Social.EmbedCommentsController do
  use Bonfire.UI.Common.Web, :controller

  def index(conn, params), do: maybe_redirect_live(conn, params, "/comments/embed/interactive")

  def show(conn, %{"id" => id} = params),
    do: maybe_redirect_live(conn, params, "/comments/embed/interactive/#{id}")

  defp maybe_redirect_live(conn, _params, live_path) do
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
        layout: {Bonfire.UI.Common.LayoutView, :iframe}
      )
    end
  end
end
