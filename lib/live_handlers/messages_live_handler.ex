defmodule Bonfire.Social.Messages.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  alias Bonfire.Social.Messages

  def handle_params(%{"after" => cursor, "context" => context} = _attrs, _, socket) do
    live_more(context, [after: cursor], socket)
  end

  def handle_params(%{"before" => cursor, "context" => context} = _attrs, _, socket) do
    live_more(context, [before: cursor], socket)
  end

  def handle_event("load_more", attrs, socket) do
    live_more(nil, Keyword.new(input_to_atoms(attrs)), socket)
  end

  def handle_event("send", params, socket) do
    send_message(params, socket)
  end

  def handle_event("select_recipient", %{"id" => id, "action" => "deselect"}, socket) do
    debug(id, "remove from circles")
    # debug(e(socket.assigns, :to_circles, []))
    to_circles =
      Enum.reject(e(socket.assigns, :to_circles, []), fn {_name, cid} -> cid == id end)
      |> debug()

    {:noreply, assign(socket, to_circles: to_circles)}
  end

  def handle_event("select_recipient", %{"id" => id, "name" => name}, socket) do
    debug(id, "add to circles")
    # debug(e(socket.assigns, :to_circles, []))
    to_circles =
      [{name, id} | e(socket.assigns, :to_circles, [])]
      |> Enum.uniq()

    # |> debug()
    {:noreply, assign(socket, to_circles: to_circles)}
  end

  def live_more(context, opts, socket) do
    debug(opts, "paginate threads")

    {:noreply,
     socket
     |> assign(
       sidebar_widgets:
         threads_widget(
           current_user(socket.assigns),
           context,
           [tab_id: nil, thread_id: e(socket.assigns, :thread_id, nil)] ++ List.wrap(opts)
         )
     )}
  end

  def threads_widget(current_user, user \\ nil, opts \\ []) do
    [
      users: [
        main: [
          {Bonfire.UI.Social.MessageThreadsLive,
           [
             context: ulid(user),
             showing_within: :messages,
             threads: list_threads(current_user, user, opts),
             thread_id: opts[:thread_id]
           ] ++ List.wrap(opts)}
        ]
        # secondary: [
        #   {Bonfire.Tag.Web.WidgetTagsLive, []}
        # ]
      ]
    ]
  end

  def list_threads(current_user, user \\ nil, opts \\ []) do
    # TODO: put limit in Settings
    if current_user,
      do:
        Messages.list(current_user, user, [latest_in_threads: true, limit: 8] ++ List.wrap(opts))
        # |> debug()
        |> repo().maybe_preload(activity: [replied: [thread: :named]])
  end

  def thread_participants(thread_id, activity, object, opts) do
    current_user = current_user(opts)

    if(not is_nil(object), do: Map.put(activity, :object, object), else: activity)
    |> Bonfire.Social.Threads.list_participants(
      thread_id,
      current_user: current_user,
      skip_boundary_check: true
    )
  end

  def thread_meta(key, thread_id, activity, object, opts) do
    thread_meta(thread_id, activity, object, opts)
    |> Map.get(key)
  end

  def thread_meta(thread_id, activity, object, opts) do
    participants = thread_participants(thread_id, activity, object, opts)

    # to_circles =
    #   if is_list(participants) and participants !=[],
    #     do:
    #       participants
    #       |> Enum.reject(&(&1.id == current_user.id))
    #       |> Enum.map(&{e(&1, :character, :username, l("someone")), e(&1, :id, nil)})

    names =
      if is_list(participants) and participants != [],
        do:
          participants
          |> Enum.reject(&(&1.id == current_user_id(opts)))
          |> Enum.map_join(
            " & ",
            &e(&1, :profile, :name, e(&1, :character, :username, l("someone else")))
          )

    # mentions = if length(participants)>0, do: Enum.map_join(participants, " ", & "@"<>e(&1, :character, :username, ""))<>" "

    #  if mentions, do: "for %{people}", people: mentions), else: l "Note to self..."
    # prompt = l("Compose a thoughtful response")

    # l("Conversation between %{people}", people: names)
    title = if names && names != [], do: names, else: l("Conversation")

    %{
      participants: participants,
      names: names,
      title: title
    }
  end

  def send_message(params, socket) do
    attrs =
      params
      # |> debug("attrs")
      |> input_to_atoms()
      |> debug

    with {:ok, sent} <- Messages.send(current_user_required!(socket), attrs) do
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

  defp message_sent(_sent, %{reply_to: %{thread_id: thread_id}} = _attrs, socket)
       when is_binary(thread_id) and thread_id != "" do
    # FIXME: assign or pubsub the new message and patch instead
    {:noreply,
     socket
     |> assign_flash(:info, l("Sent!"))
     |> Bonfire.UI.Common.SmartInput.LiveHandler.reset_input()}
  end

  defp message_sent(_sent, _attrs, socket) do
    {
      :noreply,
      socket
      |> assign_flash(:info, l("Sent!"))
      #  |> redirect_to("/messages/#{e(sent, :replied, :thread_id, nil) || ulid(sent)}##{ulid(sent)}")
    }
  end
end
