defmodule Bonfire.UI.Social.FlagsLive do
  use Bonfire.UI.Common.Web, :stateful_component
  #

  prop page_title, :string, default: "Flags"
  prop feed, :list, default: []
  prop page_info, :list, default: []




  def update(_assigns, socket) do
    current_user = current_user(socket.assigns)
    scope = socket.assigns[:scope]

    feed =
      Bonfire.Social.Flags.list_preloaded(socket)
      |> debug("flags for #{id(scope) || inspect(scope)}")

    edges =
      for %{edge: %{} = edge} <- e(feed, :edges, []),
          do: %{activity: edge |> Map.put(:verb, %{verb: "Flag"})}

    {:ok,
     socket
     |> assign(
       page: "flags",
       page_title: "Flags",
       current_user: current_user,
       feed_id: :flags,
       feed: edges || [],
       loading: false,
       page_info: e(feed, :page_info, [])
     )}
  end

  # def handle_params(%{"tab" => tab} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      selected_tab: tab
  #    )}
  # end

  # def handle_params(%{} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      current_user: Fake.user_live()
  #    )}
  # end

  defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
