defmodule Bonfire.UI.Social.ThreadLive do
  use Bonfire.Web, :live_component
  alias Bonfire.Fake
  alias Bonfire.Web.LivePlugs
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.{CreateUserLive, LoggedDashboardLive}
  # import Bonfire.Me.Integration

  @thread_max_depth 3 # TODO: put in config


  def update(%{replies: replies, threaded_replies: threaded_replies, page_info: page_info} = assigns, socket) when is_list(replies) and length(replies)>0 do
    IO.inspect("merge")
    {:ok, assign(socket, assigns |> assigns_merge(%{
      reply_to_thread_id: e(assigns, :activity, :thread_post_content, :id, nil) || e(assigns, :thread_id, nil), # TODO: change for thread forking?
      thread_max_depth: @thread_max_depth
    })) }
  end

  def update(assigns, socket) do
    IO.inspect(assigns)

    # replies = Bonfire.Data.Social.Replied.descendants(thread)
    # IO.inspect(replies, label: "REPLIES:")
    # replies = replies |> repo().all

    # replies = Bonfire.Social.Posts.replies_tree(e(thread, :thread_replies, []))

    thread_id = e(assigns, :thread_id, nil)

    if thread_id do

      activity = e(assigns, :activity, nil)
      current_user = e(assigns, :current_user, nil)

      with %{entries: replies, metadata: page_info} <- Bonfire.Social.Posts.list_replies(thread_id, current_user, e(assigns, :after, nil), @thread_max_depth) do
        threaded_replies = if is_list(replies) and length(replies)>0, do: Bonfire.Social.Posts.arrange_replies_tree(replies), else: []
        # IO.inspect(replies, label: "REPLIES:")

        {:ok,
        socket
        |> assign(
          thread_id: thread_id,
          activity: activity,
          reply_to_thread_id: e(activity, :thread_post_content, :id, nil) || thread_id, # TODO: change for thread forking?
          current_user: current_user,
          page: "thread",
          replies: replies || [],
          threaded_replies: threaded_replies,
          page_info: page_info,
          thread_max_depth: @thread_max_depth
        )}
      end
    end
  end


  defdelegate handle_event(action, attrs, socket), to: Bonfire.Web.LiveHandler

end
