defmodule Bonfire.UI.Social.ThreadLive do
  use Bonfire.Web, :live_component
  alias Bonfire.Fake
  alias Bonfire.Common.Web.LivePlugs
  alias Bonfire.Me.Users
  alias Bonfire.Me.Web.{CreateUserLive, LoggedDashboardLive}
  # import Bonfire.Me.Integration

  @thread_max_depth 3 # TODO: put in config

  def update(assigns, socket) do

    # replies = Bonfire.Data.Social.Replied.descendants(thread)
    # IO.inspect(replies, label: "REPLIES:")
    # replies = replies |> repo().all

    # replies = Bonfire.Social.Posts.replies_tree(e(thread, :thread_replies, []))

    thread_id = e(assigns, :thread_id, nil)

    if thread_id do

      activity = e(assigns, :activity, nil)
      current_user = e(assigns, :current_user, nil)

      replies = Bonfire.Social.Posts.list_replies(thread_id, current_user, @thread_max_depth)
      # IO.inspect(replies, label: "REPLIES:")

      {:ok,
      socket
      |> assign(
        thread_id: thread_id,
        activity: activity,
        reply_to_thread_id: e(activity, :thread_post_content, :id, nil) || thread_id, # TODO: change for thread forking?
        current_user: current_user,
        replies: replies || [],
        threaded_replies: Bonfire.Social.Posts.arrange_replies_tree(replies || []) || [],
        thread_max_depth: @thread_max_depth
      )}
    end
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

  defdelegate handle_event(action, attrs, socket), to: Bonfire.Web.LiveHandler


end
