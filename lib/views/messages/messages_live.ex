defmodule Bonfire.UI.Social.MessagesLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs
  alias Bonfire.Social.Integration
  alias Bonfire.Social.Messages.LiveHandler
  import Where

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

  defp mounted(params, _session, socket) do

    feed_id = :inbox
    # feed_id = Bonfire.Social.Feeds.my_feed_id(feed_id, socket)

    {:ok,
      socket
      |> assign(
        create_activity_type: :message,
        showing_within: :messages,
        to_boundaries: [{"message", "Message"}],
        page_title: l("Messages"),
        page: "messages",
        feed_id: feed_id,
        activity: nil,
        object: nil,
        reply_to_id: nil,
        thread_id: nil,
        hide_smart_input: true,
        smart_input_text: nil,
        feedback_title: l("Your direct messages"),
        feedback_message: l("Select a thread or start a new one..."),
        threads: LiveHandler.list_threads(current_user(socket), socket),
        smart_input_prompt: l("Compose a thoughtful message..."),
        page_header_aside: [
          {Bonfire.UI.Social.HeaderAsideNotificationsSeenLive, [
            feed_id: feed_id
          ]}
        ],
        show_less_menu_items: true,
        sidebar_widgets: [
          users: [
            main: [
              {Bonfire.UI.Social.MessageThreadsLive, [
                context: nil,
                thread_id: nil,
                tab_id: nil,
                showing_within: :messages,
                threads: []
              ]}
            ],
          ]
        ]
        # without_sidebar: true
      )
    }
  end

  def do_handle_params(%{"username" => username} = params, url, socket) do
    # view messages excanged with a particular user

    current_user = current_user(socket)
    current_username = e(current_user, :character, :username, nil)

    user = case username do
      nil ->
        current_user

      username when username == current_username ->
        current_user

      username ->
        with {:ok, user} <- Bonfire.Me.Users.by_username(username) do
          user
        else _ ->
          nil
        end
    end
    # debug(user: user)

    if user do

      smart_input_text = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do:
      "", else: "@"<>e(user, :character, :username, "")<>" "

      to_circles = [{e(user, :profile, :name, e(user, :character, :username, l "someone")), ulid(user)}]

      {:noreply,
        socket
        |> assign(
          page: "messages",
          # feed: e(feed, :edges, []),
          smart_input: true,
          tab_id: "compose",
          feed_title: l("Messages"),
          user: user, # the user to display
          reply_to_id: nil,
          thread_id: nil,
          smart_input_prompt: l("Compose a thoughtful message..."),
          # smart_input_text: smart_input_text,
          to_circles: to_circles,
          sidebar_widgets: LiveHandler.threads_widget(current_user, ulid(e(socket.assigns, :user, nil)), thread_id: nil, tab_id: "compose")
        )
      }
    else
      {:noreply,
        socket
        |> assign_flash(:error, l("User not found"))
        |> redirect_to(path(:error))
      }
    end
  end

  def do_handle_params(%{"id" => "compose" = id} = params, url, socket) do
    current_user = current_user(socket)
    users = Bonfire.Social.Follows.list_my_followed(current_user, paginate: false)
    {:noreply,
    socket
    |> assign(
      page_title: l("Direct Messages"),
      page: "messages",
      users: users,
      tab_id: "select_recipients",
      reply_to_id: nil,
      thread_id: nil,
      to_circles: [],
      sidebar_widgets: LiveHandler.threads_widget(current_user, ulid(e(socket.assigns, :user, nil)), thread_id: nil, tab_id: "select_recipients")
      )
    }
  end

  def do_handle_params(%{"id" => id} = params, url, socket) do
    if not is_ulid?(id) do
      do_handle_params(%{"username" => id}, url, socket)
    else
      # show a message thread

      current_user = current_user(socket)

      with {:ok, message} <- Bonfire.Social.Messages.read(id, current_user: current_user) do
        # dump(message, "the first message in thread")

        {activity, message} = Map.pop(message, :activity)
        {preloaded_object, activity} = Map.pop(activity, :object)

        activity = Bonfire.Social.Activities.activity_preloads(activity, :all, current_user: current_user)
        |> debug("preloaded")

        message = Map.merge(message, preloaded_object)
                # |> debug("the message object")

        reply_to_id = e(params, "reply_to_id", nil)
        thread_id = e(activity, :replied, :thread_id, id)

        # debug(activity, "activity")
        smart_input_prompt = l("Reply to message:")<>" "<>Text.text_only(e(message, :post_content, :name, e(message, :post_content, :summary, e(message, :post_content, :html_body, reply_to_id))))

        participants = Bonfire.Social.Threads.list_participants(activity, thread_id, current_user: current_user)

        to_circles = if length(participants)>0, do: Enum.map(participants, & {e(&1, :character, :username, l "someone"), e(&1, :id, nil)})

        names = if length(participants)>0, do: Enum.map_join(participants, " & ", &e(&1, :profile, :name, e(&1, :character, :username, l "someone else")))

        # mentions = if length(participants)>0, do: Enum.map_join(participants, " ", & "@"<>e(&1, :character, :username, ""))<>" "

        prompt =  l("Compose a thoughtful response") #  if mentions, do: "for %{people}", people: mentions), else: l "Note to self..."

        # l("Conversation between %{people}", people: names)
        title = if names, do: names, else: l "Conversation"

        {:noreply,
        socket
        |> assign(
          page_title: e(activity, :replied, :thread, :named, :name, title),
          page: "messages",
          tab_id: "thread",
          reply_to_id: reply_to_id,
          url: url,
          activity: activity,
          object: message,
          thread_id: e(message, :id, nil),
          participants: participants,
          smart_input_prompt: prompt,
          to_circles: to_circles || [],
          page_header_aside: [
            {Bonfire.UI.Social.ObjectHeaderAsideLive, [
              page_title: e(activity, :replied, :thread, :named, :name, title),
              participants: participants,
              thread_id: e(message, :id, nil),
              object: activity,
            ]}
          ],
          sidebar_widgets: LiveHandler.threads_widget(current_user, ulid(e(socket.assigns, :user, nil)), thread_id: e(message, :id, nil), tab_id: "thread")
        )
        # |> assign_new(:messages, fn -> LiveHandler.list_threads(current_user) |> e(:edges, []) end)
      }

      else _e ->
        {:error, l("Not found (or you don't have permission to view this message)")}
      end
    end
  end

  def do_handle_params(_params, url, socket) do # show all my threads
    current_user = current_user(socket)

    {:noreply,
    socket
    |> assign(
      page_title: l("Direct Messages"),
      page: "messages",
      # feed: e(feed, :edges, []),
      tab_id: nil,
      reply_to_id: nil,
      thread_id: nil,
      to_cicles: [],
      sidebar_widgets: LiveHandler.threads_widget(current_user)
    ) #|> IO.inspect
  }
  end

  # def handle_event("compose_thread", _ , socket) do
  #   debug("start a thread")
  #   debug(e(socket, :to_circles, []))
  #   {:noreply, assign(socket, tab_id: "select_recipients")}
  # end

  def handle_params(params, uri, socket) do
    # debug(params, "params")
    # poor man's hook I guess
    with {_, socket} <- Bonfire.UI.Common.LiveHandlers.handle_params(params, uri, socket) do
      undead_params(socket, fn ->
        do_handle_params(params, uri, socket)
      end)
    end
  end

  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
