defmodule Bonfire.UI.Social.DiscussionLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    # is_guest? = is_nil(current_user_id(socket))

    {:ok,
     socket
     |> assign(
       page_title: l("Discussion"),
       thread_title: "Discussion",
       page: "discussion",
       showing_within: :thread,
       # search_placeholder: l("Search this discussion"),
       #  to_circles: [],
       no_mobile_header: true,
       participants: nil,
       #  smart_input_opts: %{prompt: l("Reply to this discussion")},
       activity: nil,
       post: nil,
       object: nil,
       object_id: nil,
       post_id: nil,
       #  thread_id: nil,
       back: true,
       #  reply_id: nil,
       page_info: nil,
       replies: nil,
       threaded_replies: nil,
       thread_id: nil,
       thread_mode:
         (maybe_to_atom(e(params, "mode", nil)) ||
            Settings.get(
              [Bonfire.UI.Social.ThreadLive, :thread_mode],
              nil,
              assigns(socket)[:__context__]
            ) || :nested)
         |> debug("thread mode"),
       #  url: nil,
       search_placeholder: nil,
       #  to_boundaries: nil,
       loading: false,
       nav_items: Bonfire.Common.ExtensionModule.default_nav()
     )}
  end

  def handle_params(%{"id" => "comment_" <> comment_id} = params, _url, socket)
      when is_binary(comment_id) do
    debug(comment_id, "comment_id that needs redirection")

    # Try to find the thread_id for this comment (optimized query)
    current_user = current_user(socket)

    with thread_id when is_binary(thread_id) <-
           Bonfire.Social.Threads.fetch_thread_id(comment_id, current_user: current_user) do
      redirect_to_thread_comment(socket, thread_id, comment_id)
    else
      error ->
        debug(error, "Could not find thread for comment")

        {:noreply,
         assign_error(socket, l("Comment not found or you don't have permission to view it"))}
    end
  end

  def handle_params(%{"id" => id} = params, _url, socket) when is_binary(id) do
    debug(id, "object_id")

    reply_id = e(params, "reply_id", nil)

    socket =
      socket
      |> assign(
        params: params,
        object_id: id,
        thread_id: id,
        #  url: url
        include_path_ids:
          Bonfire.Social.Threads.LiveHandler.maybe_include_path_ids(
            reply_id,
            e(params, "level", nil),
            e(assigns(socket), :__context__, nil) || assigns(socket)
          )
      )

    with %Phoenix.LiveView.Socket{} = socket <-
           Bonfire.Social.Objects.LiveHandler.load_object_assigns(socket) do
      {:noreply, socket}
    else
      {:error, e} ->
        {:noreply, assign_error(socket, e)}

      other ->
        error(other)
        {:noreply, socket}
    end
  end

  defp redirect_to_thread_comment(socket, thread_id, comment_id) do
    debug(thread_id, "redirecting to thread")

    redirect_path = "/discussion/#{thread_id}/reply/#{comment_id}"

    {:noreply,
     socket
     |> redirect_to(redirect_path)}
  end
end
