defmodule Bonfire.UI.Social.FlagsLive do
  use Bonfire.UI.Common.Web, :stateful_component
  # alias Bonfire.UI.Me.LivePlugs

  prop page_title, :string, default: "Flags"
  prop feed, :list, default: []
  prop page_info, :list, default: []
  prop test, :string

  def update(assigns, socket) do
    current_user = current_user(assigns) || current_user(socket.assigns)
    scope = assigns[:scope] || socket.assigns[:scope]

    feed =
      Bonfire.Social.FeedActivities.feed(:flags, scope: scope, current_user: current_user)
      |> debug("fflags")

    edges =
      for %{edge: %{} = edge} <- e(feed, :edges, []),
          do: %{activity: edge |> Map.put(:verb, %{verb: "Flag"})}

    {:ok,
     socket
     |> assign(
       page: "flags",
       # selected_tab: "flags",
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
