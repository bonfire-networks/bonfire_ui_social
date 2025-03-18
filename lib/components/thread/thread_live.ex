defmodule Bonfire.UI.Social.ThreadLive do
  use Bonfire.UI.Common.Web, :stateful_component
  import Untangle
  # alias Bonfire.Fake
  #
  # alias Bonfire.Me.Users
  # alias Bonfire.UI.Me.CreateUserLive
  alias Bonfire.UI.Social.ThreadBranchLive
  alias Bonfire.UI.Social.CommentLive
  alias Bonfire.Social.Threads.LiveHandler
  # import Bonfire.Me.Integration

  prop replies, :any, default: nil
  prop page_info, :any, default: nil
  prop activity, :any, default: nil
  prop object, :any, default: nil
  prop thread_id, :any, default: nil
  prop reply_to_id, :any, default: nil

  prop main_object_component_id, :any, default: nil
  # prop page, :any, default: "thread"
  prop feed_id, :any, default: nil
  # prop create_object_type, :any, default: nil
  # prop to_boundaries, :any, default: nil
  # prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop current_url, :string, default: nil
  # prop smart_input_opts, :map, default: %{}
  prop participants, :any, default: nil

  prop thread_mode, :any, default: nil
  prop sort_by, :any, default: nil
  prop sort_order, :any, default: false

  prop showing_within, :atom, default: :thread
  prop loading, :boolean, default: false

  prop activity_inception, :any, default: nil

  prop reply_count, :any, default: nil
  prop thread_boost_count, :any, default: nil
  prop participant_count, :any, default: nil
  prop last_reply_id, :any, default: nil

  prop activity_preloads, :tuple, default: {nil, nil}

  def mount(socket) do
    {
      :ok,
      socket
      |> stream_configure(:replies, dom_id: &component_id(&1, "flat"))
      |> stream(:replies, [])
      |> stream_configure(:threaded_replies, dom_id: &component_id(&1, "nested"))
      |> stream(:threaded_replies, [])
    }
  end

  defp component_id({entry, _children}, prefix) do
    "#{prefix}_#{id(entry)}"
  end

  defp component_id(entry, prefix) do
    "#{prefix}_#{id(entry)}"
  end


  def update(%{insert_stream: entries} = assigns, socket) do
    debug("comments stream is being poured into")

    {:ok,
     socket
     |> assign(Map.drop(assigns, [:insert_stream]))
     |> assign(replies: [])
     |> LiveHandler.insert_comments(entries, reset: assigns[:reset_stream])}
  end

  def update(
        %{replies: replies, page_info: page_info, loaded_async: loaded_async} = assigns,
        socket
      )
      when is_list(replies) and is_map(page_info) and is_binary(loaded_async) do
    debug("loading async-loaded replies")

    {:ok,
     socket
     |> assign(assigns)}
  end

  def update(%{replies: replies, page_info: page_info} = assigns, socket)
      when is_list(replies) and is_map(page_info) do
    debug("showing passed-down replies")

    {:ok,
     socket
     |> assign(assigns)
     |> LiveHandler.thread_init()}
  end

  def update(%{new_reply: new_reply}, socket) when is_map(new_reply) do
    debug("adding new reply")

    thread_id = e(assigns(socket), :thread_id, nil)

    object_id =
      e(new_reply, :object, :id, nil) || e(new_reply, :activity, :object, :id, nil) ||
        e(new_reply, :id, nil)

    reply_to_id =
      e(new_reply, :replied, :reply_to_id, nil) ||
        e(new_reply, :activity, :replied, :reply_to_id, nil) ||
        e(new_reply, :reply_to_id, nil)

    debug(reply_to_id, "reply_to_idd")

    # Note: doing this here temporarily while not using pushed comment for nested threads
    permitted? =
      object_id &&
        Bonfire.Common.Needles.exists?([id: object_id],
          current_user: current_user(assigns(socket))
        )
        |> debug("double check boundary upon receiving a LivePush")

    if permitted? do
      # {:ok,
      #  socket
      #  |> LiveHandler.insert_comments(new_reply)
      # }

      if e(assigns(socket), :thread_mode, nil) == :flat do
        debug("flat thread")

        {:ok,
         socket
         |> LiveHandler.insert_comments({:replies, [new_reply]}, at: 0)}
      else
        debug("nested thread")

        insert = {:threaded_replies, [{new_reply, []}], 0}

        if is_nil(reply_to_id) or reply_to_id == thread_id do
          debug("top level reply")

          {:ok,
           socket
           |> LiveHandler.insert_comments(insert)}
        else
          debug(reply_to_id, "send to branch")

          LiveHandler.send_thread_updates(
            self(),
            component_id(reply_to_id, "nested"),
            [insert_stream: insert],
            ThreadBranchLive
          )

          {:ok, socket}
        end

        # FIXME: we should inject the reply rather than reloading
        # load_comments(socket, false)
        # ^ cannot redirect in `update` so we trigger a re-query of the thread instead

        # temporary
        # activity_id = e(new_reply, :activity, :id, nil) || e(new_reply, :id, nil)

        # thread_url =
        #   if is_struct(e(assigns(socket), :object, nil)) do
        #     path(e(assigns(socket), :object, nil))
        #   else
        # "/discussion/#{thread_id}"
        #   end

        # permalink = "#{thread_url}#activity-#{activity_id}"

        # {
        #   :ok,
        #   socket
        #   |> patch_to(permalink)
        #   # |> LiveHandler.load_thread()
        # }

        # FIMXE: nesting gets messed up when replying to a reply that was added to the thread this way
        # path = (
        #   e(new_reply, :object, :replied, :path, nil)
        #   || e(new_reply, :replied, :path, nil)
        #   || e(new_reply, :activity, :replied, :path, [])
        # )
        # |> debug("path")

        # replies = [
        #   new_reply
        #   |> Map.put(:path, path)
        # ] ++ e(assigns(socket), :replies, [])

        # {:ok, socket
        #   |> assign(
        #     replies: replies,
        #     threaded_replies: Bonfire.Social.Threads.arrange_replies_tree(replies) |> debug()
        #   )
        # }
      end
    else
      {:ok, socket}
    end
  end

  def update(%{__context__: %{new_reply: new_reply}} = assigns, socket) do
    debug(new_reply, "context_reply")
    update(Map.merge(assigns, %{new_reply: new_reply}), socket)
  end

  def update(
        %{thread_mode: new_thread_mode} = assigns,
        %{assigns: %{thread_mode: thread_mode}} = socket
      )
      when new_thread_mode != thread_mode do
    debug("(re)load comments because changing thread mode")

    socket
    |> assign(assigns)
    |> LiveHandler.load_thread_maybe_async(false, true)
  end

  def update(%{thread_id: thread_id} = assigns, %{assigns: %{loaded_async: thread_id}} = socket) do
    debug("just show previously async-loaded replies for this thread")

    {:ok,
     socket
     |> assign(assigns)}
  end

  def update(%{skip_loading_comments: true} = assigns, socket) do
    debug("skip_loading_comments")

    {:ok,
     socket
     |> assign(assigns)}
  end

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> load_comments()
  end

  def load_comments(socket, show_loading? \\ true) do
    debug("Loading comments")

    {:ok,
     socket
     |> update(:thread_mode, fn
       nil ->
         Settings.get(
           [Bonfire.UI.Social.ThreadLive, :thread_mode],
           nil,
           assigns(socket)[:__context__]
         )

       manual ->
         manual
     end)
     |> update(:sort_by, fn
       nil ->
         Settings.get(
           [Bonfire.UI.Social.ThreadLive, :sort_by],
           nil,
           assigns(socket)[:__context__]
         )

       manual ->
         manual
     end)
     |> LiveHandler.thread_init()
     |> LiveHandler.load_thread_maybe_async(show_loading?)}
  end

  def handle_event(
        "set",
        attrs,
        socket
      ) do
    debug("need to reload comments so streams are updated")

    {
      :noreply,
      socket
      |> assign(replies: [])
      |> stream(:replies, [], reset: true)
      |> stream(:threaded_replies, [], reset: true)
      |> Bonfire.UI.Common.LiveHandlers.assign_attrs(attrs)
      |> LiveHandler.load_thread_maybe_async(true, true)
      # |> debug("seeet")
    }
  end
end
