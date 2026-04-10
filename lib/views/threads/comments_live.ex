defmodule Bonfire.UI.Social.CommentsLive do
  use Bonfire.UI.Common.Web, {:surface_live_view, layout: {Bonfire.UI.Common.LayoutView, :iframe}}

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.LoadCurrentUser,
              Bonfire.UI.Me.LivePlugs.LoadCurrentUserFromEmbedToken
            ]}

  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: l("Comments"),
       page: "comments",
       showing_within: :thread_embed,
       reply_to_id: nil,
       no_mobile_header: true,
       hide_thread_stats: true,
       embed_theme: e(params, "theme", nil),
       participants: nil,
       sort_by: nil,
       sort_order: nil,
       activity: nil,
       object: nil,
       object_id: nil,
       reply_id: nil,
       thread_id: nil,
       page_info: nil,
       replies: nil,
       threaded_replies: nil,
       include_path_ids: nil,
       thread_mode:
         maybe_to_atom(e(params, "mode", nil)) ||
           Settings.get(
             [Bonfire.UI.Social.ThreadLive, :thread_mode],
             nil,
             assigns(socket)[:__context__]
           ) || :nested,
       loading: false
     )}
  end

  def handle_params(%{"id" => "comment_" <> comment_id} = _params, _url, socket)
      when is_binary(comment_id) do
    debug(comment_id, "comment_id that needs redirection")

    with thread_id when is_binary(thread_id) <-
           Bonfire.Social.Threads.fetch_thread_id(comment_id,
             current_user: current_user(socket)
           ) do
      {:noreply, redirect_to(socket, "/comments/#{thread_id}/reply/#{comment_id}")}
    else
      error ->
        debug(error, "Could not find thread for comment")

        {:noreply,
         assign_error(socket, l("Comment not found or you don't have permission to view it"))}
    end
  end

  def handle_info({:set_reply_to, reply_to_id}, socket) do
    {:noreply, assign(socket, reply_to_id: reply_to_id)}
  end

  def handle_params(%{"id" => id} = params, _url, socket) when is_binary(id) do
    debug(id, "object_id")

    reply_id = e(params, "reply_id", nil)

    {:noreply,
     socket
     |> assign(
       object_id: id,
       thread_id: id,
       reply_id: reply_id
       #  include_path_ids:
       #    Bonfire.Social.Threads.LiveHandler.maybe_include_path_ids(
       #      reply_id,
       #      e(params, "level", nil),
       #      e(assigns(socket), :__context__, nil) || assigns(socket)
       #    )
     )
     |> assign_new(:main_object_component_id, fn ->
       Bonfire.UI.Social.ActivityLive.component_id(id, "main_object", nil)
     end)}
  end

  def handle_params(%{"media_uri" => uri} = params, _url, socket) when is_binary(uri) do
    socket = assign_global(socket, :go, uri)

    # TODO: cache result
    with {:ok, %{id: id} = _media} <-
           Bonfire.Files.Media.get_or_add_media_by_uri(
             params["creator"] || current_user_or_id(socket),
             uri,
             params["boundary"] || "public",
             params["to_circles"],
             update_existing: false
           ) do
      handle_params(%{"id" => id}, nil, socket)
    end
  end

  def handle_params(params, _url, socket) do
    error(params, "Need an ID or media URI")
  end
end
