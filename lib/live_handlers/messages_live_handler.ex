defmodule Bonfire.Social.Messages.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  alias Bonfire.Social.Messages

  def handle_params(%{"after" => cursor, "context" => context} = attrs, _, socket) do
    live_more(context, [after: cursor], socket)
  end

  def handle_params(%{"before" => cursor, "context" => context} = attrs, _, socket) do
    live_more(context, [before: cursor], socket)
  end

  def handle_event("load_more", attrs, socket) do
    live_more(nil, Keyword.new(input_to_atoms(attrs)), socket)
  end

  def handle_event("send", params, socket) do
    send_message(params, socket)
  end

  def handle_event("select_recipient", %{"id"=> id, "action" =>"deselect"}, socket) do
    debug(id, "remove from circles")
    # debug(e(socket.assigns, :to_circles, []))
    to_circles = Enum.reject(e(socket.assigns, :to_circles, []), fn {_name, cid} -> cid==id end)
    |> debug()
    {:noreply,
      assign(socket, to_circles: to_circles)
    }
  end

  def handle_event("select_recipient", %{"id"=> id, "name"=>name}, socket) do
    debug(id, "add to circles")
    # debug(e(socket.assigns, :to_circles, []))
    to_circles = [{name, id} | e(socket.assigns, :to_circles, [])]
    |> Enum.uniq()
    # |> debug()
    {:noreply,
      assign(socket, to_circles: to_circles)
    }
  end

  def live_more(context, opts, socket) do
    debug(opts, "paginate threads")
    {:noreply, socket
      |> assign(
        sidebar_widgets: threads_widget(current_user(socket), context, [tab_id: nil, thread_id: e(socket.assigns, :thread_id, nil)] ++ opts)
    )}
  end

  def threads_widget(current_user, user \\ nil, opts \\ []) do
    [
      users: [
        main: [
          {Bonfire.UI.Social.MessageThreadsLive, [
              context: ulid(user),
              showing_within: :messages,
              threads: list_threads(current_user, user, opts),
              thread_id: opts[:thread_id]
            ] ++ opts
          }
        ]      ]
    ]
  end


  def list_threads(current_user, user \\ nil, opts \\ []) do
    # TODO: put limit in Settings
    if current_user, do: Messages.list(current_user, user, [latest_in_threads: true, limit: 8] ++ opts) |> dump()
  end


  def send_message(params, socket) do
    attrs = params
    # |> debug("attrs")
    |> input_to_atoms()
    # |> debug

    with {:ok, sent} <- Messages.send(current_user(socket), attrs) do
      # debug(sent, "sent!")
      message_sent(sent, attrs, socket)
    # else e ->
    #   debug(message_error: e)
    #   {:noreply,
    #     socket
    #     |> assign_flash(:error, "Could not send...")
    #   }
    end
  end

  defp message_sent(_sent, %{reply_to: %{thread_id: thread_id}} = _attrs, socket) when is_binary(thread_id) and thread_id !="" do
    # FIXME: assign or pubsub the new message and patch instead
    {:noreply,
      socket
      |> assign_flash(:info, l "Sent!")
      |> Bonfire.UI.Common.SmartInputLive.reset_input()
    }
  end

  defp message_sent(sent, _attrs, socket) do
    {:noreply,
      socket
      |> assign_flash(:info, l "Sent!")
      |> redirect_to("/messages/#{e(sent, :replied, :thread_id, nil) || ulid(sent)}##{ulid(sent)}")
    }
  end
end
