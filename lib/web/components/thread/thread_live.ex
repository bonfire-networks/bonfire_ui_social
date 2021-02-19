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

    # replies = Bonfire.Me.Social.Posts.replies_tree(e(thread, :thread_replies, []))

    thread = Map.get(assigns, :thread) || Map.get(assigns, :thread_id)

    replies = if thread, do: Bonfire.Me.Social.Posts.list_replies(thread, @thread_max_depth)
    # IO.inspect(replies, label: "REPLIES:")

    {:ok,
     socket
     |> assign(
       thread_max_depth: @thread_max_depth,
       thread: thread,
       current_user: e(assigns, :current_user, nil),
       replies: replies || [],
       threaded_replies: Bonfire.Me.Social.Posts.arrange_replies_tree(replies || []) || []
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

  def handle_event("load_replies", %{"id" => id, "level" => level}, socket) do
    {level, _} = Integer.parse(level)
    replies = Bonfire.Me.Social.Posts.list_replies(id, level + @thread_max_depth)
    replies = replies ++ socket.assigns.replies
    {:noreply,
        assign(socket,
        replies: replies,
        threaded_replies: Bonfire.Me.Social.Posts.arrange_replies_tree(replies) || []
     )}
  end

  def handle_event("reply", attrs, socket) do

    attrs = attrs
    |> Bonfire.Common.Utils.input_to_atoms()

    with {:ok, published} <- Bonfire.Me.Social.Posts.reply(socket.assigns.current_user, attrs) do
      replies = [published] ++ socket.assigns.replies
    IO.inspect(replies, label: "rep:")
      {:noreply,
        assign(socket,
        replies: replies,
        threaded_replies: Bonfire.Me.Social.Posts.arrange_replies_tree(replies) || []
     )}
    end

  end

end
