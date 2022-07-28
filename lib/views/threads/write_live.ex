defmodule Bonfire.UI.Social.WriteLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.UserRequired,
      # LivePlugs.LoadCurrentUserCircles,
      # LivePlugs.LoadCurrentAccountUsers,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  defp mounted(params, session, socket) do
    {:ok,
    socket
    |> assign(
      page_title: l("Write"),
      page: "write",
      hide_smart_input: true,
      create_activity_type: nil,
      smart_input_text: e(session, "smart_input_text", ""),
      reply_to_id: nil,
      thread_id: nil,
      to_boundaries: nil,
      to_circles: nil,
      # sidebar_widgets: [
      #   users: [
      #     main: [
      #       {Bonfire.UI.Common.WidgetInstanceInfoLive, [display_banner: false]},
      #     ]
      #   ]
      # ]
    )}
  end


  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
