defmodule Bonfire.UI.Social.ThreadLive do
  use Bonfire.Web, :stateful_component
  require Logger
  alias Bonfire.Fake
  alias Bonfire.Web.LivePlugs
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.{CreateUserLive, LoggedDashboardLive}
  # import Bonfire.Me.Integration

  # prop reply_to_id, :any
  # prop reply_to_thread_id, :any
  prop thread_id, :any
  # prop replies, :any
  # prop threaded_replies, :any, default: []
  prop page_info, :any
  prop activity, :any
  prop object, :any
  prop smart_input_placeholder, :string
  prop smart_input_text, :string

  # TODO: put in config
  @thread_max_depth 3
  @pagination_limit 10

  def update(%{replies: replies, threaded_replies: threaded_replies, page_info: page_info} = assigns, socket) when is_list(replies) and is_list(threaded_replies) and is_map(page_info) do
    Logger.debug("ThreadLive: showing preloaded replies")
    assigns |> assign_thread(socket)
  end

  def update(%{new_reply: new_reply} = assigns, socket) when is_map(new_reply) do
    Logger.debug("ThreadLive: adding new reply")
    # IO.inspect(merge_reply: previous_replies)

    new_reply = new_reply
      |> Map.put(:path, e(new_reply, :activity, :object, :replied, :path, []))

    replies = [new_reply] ++ e(socket, :assigns, :replies, [])

    {:ok, assign(socket, assigns |> assigns_merge(
      replies: replies,
      threaded_replies: Bonfire.Social.Threads.arrange_replies_tree(replies),
      reply_to_thread_id: e(assigns, :activity, :replied, :thread_id, nil) || e(assigns, :thread_id, nil), # TODO: change for thread forking?
      thread_max_depth: @thread_max_depth
    )) }
  end

  def update(%{__context__: %{new_reply: new_reply}} = assigns, socket) do
    # IO.inspect(context_reply: new_reply)
    update(Map.merge(assigns, %{new_reply: new_reply}), socket)
  end

  def update(assigns, socket) do
    # IO.inspect(assigns, label: "Thread: assigns")

    thread_id = e(assigns, :thread_id, nil)

    if thread_id do
      # IO.inspect("Thread: loading by thread_id")
      # IO.inspect(assigns)
      current_user = current_user(assigns) #|> IO.inspect

      with %{edges: replies, page_info: page_info} <- Bonfire.Social.Threads.list_replies(thread_id, current_user, e(assigns, :after, nil), @thread_max_depth, @pagination_limit) do
        # IO.inspect(thread_id, label: "thread_id")
        # IO.inspect(replies, label: "replies")

        threaded_replies = if is_list(replies) and length(replies)>0, do: Bonfire.Social.Threads.arrange_replies_tree(replies), else: []
        # IO.inspect(threaded_replies, label: "threaded_replies")

        assigns
        |> assigns_merge(
          replies: replies || [],
          threaded_replies: threaded_replies,
          page_info: page_info,
          thread_id: thread_id
        )
        |> assign_thread(socket)
      end
    end
  end

  def assign_thread(assigns, socket) do

    # IO.inspect(assigns, label: "thread assigns")

    current_user = current_user(assigns)
    thread_id = e(assigns, :thread_id, nil)
    activity = e(assigns, :activity, nil) #|> IO.inspect
    object = e(assigns, :object, e(activity, :object)) #|> IO.inspect

    {:ok,
    assign(socket,
      assigns
      |> assigns_merge(
        # thread_id: thread_id,
        activity: activity,
        object: object,
        reply_to_id: e(activity, :object, :id, thread_id),
        reply_to_thread_id: e(activity, :replied, :thread_id, thread_id), # TODO: change for thread forking?
        current_user: current_user,
        page: "thread",
        thread_max_depth: @thread_max_depth,
        # participants: participants
      ) #|> IO.inspect
    )}


  end

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
