defmodule Bonfire.UI.Social.ThreadLive do
  use Bonfire.UI.Common.Web, :stateful_component
  import Where
  alias Bonfire.Fake
  alias Bonfire.UI.Me.LivePlugs
  alias Bonfire.Me.Users
  alias Bonfire.UI.Me.CreateUserLive
  # import Bonfire.Me.Integration

  prop replies, :any
  prop threaded_replies, :any, default: []
  prop page_info, :any
  prop activity, :any
  prop object, :any
  prop reply_to_id, :any
  prop thread_id, :any
  prop create_activity_type, :any
  prop to_circles, :list
  prop url, :string
  prop smart_input_prompt, :string
  prop smart_input_text, :string
  prop thread_mode, :any
  prop reverse_order, :any




  def update(%{replies: replies, page_info: page_info} = assigns, socket) when is_list(replies) and is_map(page_info) do
    info("showing preloaded replies")
    assigns |> assign_thread(socket)
  end

  def update(%{new_reply: new_reply} = assigns, socket) when is_map(new_reply) do
    debug("adding new reply")

    new_reply = new_reply
      |> Map.put(:path, e(new_reply, :object, :replied, :path, nil) || e(new_reply, :replied, :path, nil) || e(new_reply, :replied, :path, nil) || e(new_reply, :activity, :replied, :path, []))
      # |> dump("new_reply")

    replies = [new_reply] ++ e(socket, :assigns, :replies, [])

    {:ok, assign(socket, assigns |> assigns_merge(
      replies: replies,
      threaded_replies: (if e(assigns, :thread_mode, nil) !=:flat, do: Bonfire.Social.Threads.arrange_replies_tree(replies)),
      thread_id: e(assigns, :activity, :replied, :thread_id, nil) || e(assigns, :thread_id, nil), # TODO: change for thread forking?
    )) }
  end

  def update(%{__context__: %{new_reply: new_reply}} = assigns, socket) do
    # debug(context_reply: new_reply)
    update(Map.merge(assigns, %{new_reply: new_reply}), socket)
  end

  def update(assigns, socket) do
    # debug(assigns, "Thread: assigns")

    thread_id = e(assigns, :thread_id, e(assigns, :object, :id, nil))

    if thread_id do
      info("loading by thread_id")
      # debug(assigns)
      current_user = current_user(assigns) #|> IO.inspect

      max_depth = if e(assigns, :thread_mode, nil) !=:flat, do: Config.get(:thread_default_max_depth, 3)

      with %{edges: replies, page_info: page_info} <- Bonfire.Social.Threads.list_replies(thread_id, current_user: current_user, after: e(assigns, :after, nil), max_depth: max_depth, thread_mode: e(assigns, :thread_mode, nil), reverse_order: e(assigns, :reverse_order, nil)) do
        # debug(thread_id, "thread_id")
        debug(replies, "queried replies")

        threaded_replies = if e(assigns, :thread_mode, nil) !=:flat and is_list(replies) and length(replies)>0, do: Bonfire.Social.Threads.arrange_replies_tree(replies)
        # debug(threaded_replies, "threaded_replies")

        assigns
        |> assigns_merge(
          replies: replies,
          threaded_replies: threaded_replies,
          page_info: page_info,
          thread_id: thread_id
        )
        |> assign_thread(socket)
      end
    end
  end

  def assign_thread(assigns, socket) do

    # debug(assigns, "thread assigns")
    current_user = current_user(assigns)
    activity = e(assigns, :activity, nil) #|> IO.inspect
    object = e(assigns, :object, e(activity, :object)) #|> IO.inspect
    thread_id = e(activity, :replied, :thread_id, nil) || e(assigns, :thread_id, nil)

    maybe_subscribe(thread_id, socket)

    {:ok,
    assign(socket,
      assigns
      |> assigns_merge(
        # thread_id: thread_id,
        activity: activity,
        object: object,
        reply_to_id: e(activity, :object, :id, thread_id),
        thread_id: thread_id, # TODO: change for thread forking?
        current_user: current_user,
        page: "thread",
        # participants: participants
      ) #|> IO.inspect
    )}
  end

  def maybe_subscribe(thread_id, socket) do
    if thread_id do
      pubsub_subscribe(thread_id, socket)
    else
      debug("no thread_id known, not subscribing to live updates")
    end
  end


  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
