defmodule Bonfire.UI.Social.ThreadLive do
  use Bonfire.Web, :stateful_component
  alias Bonfire.Fake
  alias Bonfire.Web.LivePlugs
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.{CreateUserLive, LoggedDashboardLive}
  # import Bonfire.Me.Integration

  # prop reply_to_id, :any
  prop thread_id, :any
  # prop replies, :any
  # prop threaded_replies, :any, default: []
  prop page_info, :any
  prop activity, :any
  prop object, :any
  # TODO: put in config
  @thread_max_depth 3
  @pagination_limit 10

  def update(%{replies: replies, threaded_replies: threaded_replies, page_info: page_info} = assigns, socket) when is_list(replies) and is_list(threaded_replies) and is_map(page_info) do
    IO.inspect("preloaded replies")
    assigns |> assign_thread(socket)
  end


  def update(%{new_reply: new_reply} = assigns, socket) when is_map(new_reply) do
    IO.inspect("Thread: adding new thread reply")
    # IO.inspect(merge_reply: previous_replies)

    new_reply = new_reply |> Map.put(:path, e(new_reply, :activity, :object, :replied, :path, []))
    # IO.inspect(new_reply: new_reply)
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
    thread_id = e(assigns, :thread_id, nil)
  

    if thread_id do
      
      current_user = current_user(assigns)

      with %{entries: replies, metadata: page_info} <- Bonfire.Social.Threads.list_replies(thread_id, current_user, e(assigns, :after, nil), @thread_max_depth, @pagination_limit) do
        IO.inspect(thread_id, label: "thread_id")
        IO.inspect(page_info, label: "page_info")

        threaded_replies = if is_list(replies) and length(replies)>0, do: Bonfire.Social.Threads.arrange_replies_tree(replies), else: []

        assigns_merge(assigns,
          replies: replies || [],
          threaded_replies: threaded_replies,
          page_info: page_info,
          # thread_id: thread_id
        )
        |> assign_thread(socket)
      end
    end
  end

  def assign_thread(assigns, socket) do

    # replies = Bonfire.Data.Social.Replied.descendants(thread)
    #IO.inspect(replies, label: "REPLIES:")
    # replies = replies |> repo().many

    # replies = Bonfire.Social.Posts.replies_tree(e(thread, :thread_replies, []))

    thread_id = e(assigns, :object, :thread_id, nil)

    if thread_id do

      current_user = current_user(assigns)
      activity = e(assigns, :activity, nil)
      object = e(assigns, :object, e(activity, :object))

      {:ok,
      assign(socket, assigns
      |> assigns_merge(
        # thread_id: thread_id,
        activity: activity,
        object: object,
        reply_to_id: e(activity, :object, :id, nil) || thread_id, # TODO: change for thread forking?
        reply_to_thread_id: e(activity, :replied, :thread_id, nil) || thread_id, # TODO: change for thread forking?
        current_user: current_user,
        page: "thread",
        thread_max_depth: @thread_max_depth,
        # participants: participants
      ))}

    end
  end

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
