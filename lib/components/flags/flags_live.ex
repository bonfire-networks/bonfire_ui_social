defmodule Bonfire.UI.Social.FlagsLive do
  use Bonfire.UI.Common.Web, :stateful_component
  #
  prop feed_count, :string, default: ""

  def update(_assigns, socket) do
    {:ok,
     socket
     |> assign(
       feed_id: :flags,
       loading: false
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

  # def handle_params(params, uri, socket),
  # do:
  #   Bonfire.UI.Common.LiveHandlers.handle_params(
  #     params,
  #     uri,
  #     socket,
  #     __MODULE__
  #   )
  defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

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
end
