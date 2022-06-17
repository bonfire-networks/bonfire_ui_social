defmodule Bonfire.Social.Posts.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Where

  alias Bonfire.Social.Posts
  alias Bonfire.Social.PostContents
  alias Bonfire.Data.Social.PostContent
  alias Bonfire.Data.Social.Post
  alias Ecto.Changeset


  def handle_params(%{"after" => cursor} = attrs, _, %{assigns: %{thread_id: thread_id}} = socket) do
    live_more(thread_id, [after: cursor], socket)
  end

  def handle_params(%{"after" => cursor, "context" => thread_id} = attrs, _, socket) do
    live_more(thread_id, [after: cursor], socket)
  end

  def handle_params(attrs, uri, socket) do # workaround for a weird issue appearing in tests
    case URI.parse(uri) do
      %{path: "/discussion/"<>thread_id} -> live_more(thread_id, input_to_atoms(attrs), socket)
      %{path: "/post/"<>thread_id} -> live_more(thread_id, input_to_atoms(attrs), socket)
    end
  end


  def handle_event("load_more", %{"after" => cursor} = attrs, %{assigns: %{thread_id: thread_id}} = socket) do
    live_more(thread_id, input_to_atoms(attrs), socket)
  end

  def handle_event("post", %{"create_activity_type"=>"message"}=params, socket) do
    Bonfire.Social.Messages.LiveHandler.send_message(params, socket)
  end

  def handle_event("post", %{"post" => %{"create_activity_type"=>"message"}}=params, socket) do
    Bonfire.Social.Messages.LiveHandler.send_message(params, socket)
  end

  def handle_event("post", params, socket) do # if not a message, it's a post by default
    attrs = params
    |> debug("post params")
    |> input_to_atoms()
    # |> debug("post attrs")

    # debug(e(socket.assigns, :showing_within, nil), "SHOWING")
    current_user = current_user(socket)

    with %{} <- current_user || {:error, "You must be logged in"},
         %{valid?: true} <- post_changeset(attrs, current_user),
         uploaded_media <- multi_upload(current_user, params["upload_metadata"], socket),
         opts <- [
            current_user: current_user,
            post_attrs: attrs |> Map.put(:uploaded_media, uploaded_media),
            boundary: e(params, "boundary_selected", "mentions")
          ] |> debug("opts"),
         {:ok, published} <- Bonfire.Social.Posts.publish(opts) do

      debug(published, "published!")

      {:noreply,
        socket
        |> assign_flash(:info, "Posted!")
        |> reset_smart_input()
        # |> push_patch_with_fallback(current_url(socket), path(published)) # so the flash appears - TODO: causes a conflict between the activity coming in via pubsub

        # Phoenix.LiveView.assign(socket,
        #   feed: [%{published.activity | object_post: published.post, subject_user: current_user(socket)}] ++ Map.get(socket.assigns, :feed, [])
        # )
      }
    else e ->
      error(error_msg(e))
      {:noreply,
        socket
        |> assign_flash(:error, "Could not post 😢 (#{error_msg(e)})")
        # |> patch_to(current_url(socket), fallback: "/error") # so the flash appears
      }
    end
  end

  def handle_event("post_error", _, socket) do
    default_template = "I encountered this issue while using Bonfire: \n```\n%{error_message}\n```\n@admins @bonfire_builders #bonfire_feedback \n%{error_link}"


    link = case maybe_last_sentry_event_id() do
      id when is_binary(id) ->
        org = Settings.get(:sentry_org, "bonfire-networks")
        "https://sentry.io/organizations/#{org}/issues/?query=#{id}"
      _ -> nil
    end

    text = Settings.get([:ui, :feedback_post_template], default_template, socket)
    |> String.replace("%{error_message}", e(socket.assigns, :error, nil) || live_flash(e(socket.assigns, :root_flash, nil) || e(socket.assigns, :flash, nil), :error))
    |> String.replace("%{error_link}", link)

    {:noreply,
      socket
      |> set_smart_input_text(text)
    }
  end

  def handle_event("load_replies", %{"id" => id, "level" => level}, socket) do
    info("load extra replies")
    {level, _} = Integer.parse(level)
    %{edges: replies} = Bonfire.Social.Threads.list_replies(id, socket: socket, max_depth: level + 1)
    replies = replies ++ Utils.e(socket.assigns, :replies, [])
    {:noreply,
        assign(socket,
        replies: replies
        # threaded_replies: Bonfire.Social.Threads.arrange_replies_tree(replies) || []
    )}
  end

  def handle_event("switch_thread_mode", %{"thread_mode" => thread_mode} = _attrs, socket) do
    IO.inspect(thread_mode, label: "THREAD MODE")
    if (thread_mode == "flat") do
      {:noreply,
        assign(socket,
        thread_mode: :thread
      )}
    else
      {:noreply,
        assign(socket,
        thread_mode: :flat
      )}
    end

  end

  def handle_event("input", %{"circles" => selected_circles} = _attrs, socket) when is_list(selected_circles) and length(selected_circles)>0 do

    previous_circles = e(socket, :assigns, :to_circles, []) #|> Enum.uniq()

    new_circles = Bonfire.UI.Me.LiveHandlers.Boundaries.set_circles(selected_circles, previous_circles)

    {:noreply,
        socket
        |> assign(
          to_circles: new_circles
        )
    }
  end

  def handle_event("input", _attrs, socket) do # no circle
    {:noreply,
      socket
        |> assign(
          to_circles: []
        )
    }
  end

  def handle_info({:new_reply, {thread_id, data}}, socket) do

    debug("received :new_reply")

    # debug(replies: Utils.e(socket.assigns, :replies, []))
    # replies = [data] ++ Utils.e(socket.assigns, :replies, [])

    id = e(data, :object, :id, nil) || e(data, :id, nil)

    permitted? = id && Bonfire.Common.Pointers.exists?([id: id], current_user: current_user(socket)) |> debug("double check boundary upon receiving a LivePush")

    if permitted?, do: send_update(Bonfire.UI.Social.ThreadLive, id: thread_id, new_reply: data)

    {:noreply, socket}
  end

  # def handle_event("add_data", %{"activity" => activity_id}, socket) do
  #   IO.inspect("TEST")
  #   send_update(Bonfire.UI.Social.ActivityLive, id: "activity_component_" <> activity_id, activity_id: activity_id)
  #   {:noreply, socket}
  # end


  def live_more(thread_id, paginate, socket) do
    # info(paginate, "paginate thread")
    current_user = current_user(socket)
    with %{edges: replies, page_info: page_info} <- Bonfire.Social.Threads.list_replies(thread_id, current_user: current_user, paginate: paginate) do

      replies = ( e(socket.assigns, :replies, []) ++ replies )
      |> Enum.uniq()
      # |> info("REPLIES")

      threaded_replies = if is_list(replies) and length(replies)>0, do: Bonfire.Social.Threads.arrange_replies_tree(replies), else: []
      # debug(threaded_replies, "REPLIES threaded")

      {:noreply, socket
      |> assign([
        replies: replies,
        threaded_replies: threaded_replies,
        page_info: page_info
      ])}
    end
  end


  def post_changeset(attrs \\ %{}, creator) do
    # debug(attrs, "ATTRS")
    Posts.changeset(:create, attrs, creator)
    # |> debug("pc")
  end

  defp multi_upload(current_user, metadata, socket) do
    maybe_consume_uploaded_entries(socket, :files, fn %{path: path} = meta, entry ->
      debug(meta, "consume_uploaded_entries meta")
      debug(entry, "consume_uploaded_entries entry")
      with {:ok, uploaded} <- Bonfire.Files.upload(nil, current_user, path, %{client_name: entry.client_name, metadata: metadata[entry.ref]})
      |> debug("uploaded") do
        {:ok, uploaded}
      else e ->
        error(e, "Could not upload #{entry.client_name}")
        {:postpone, nil}
      end
    end)
    |> filter_empty([])
  end


  def set_smart_input_text(socket, text \\ "\n") do
    socket
    |> push_event("smart_input:set_body", %{text: text})
  end

  def reset_smart_input(%{assigns: %{showing_within: :thread}} = socket) do
    # debug("THREad")
    socket
    |> set_smart_input_text()
    |> assign(
      activity: nil,
      to_circles: nil,
      reply_to_id: e(socket.assigns, :thread_id, nil),
    )
  end

  def reset_smart_input(%{assigns: %{showing_within: :messages}} = socket) do
    # debug("messages")

    socket
    |> set_smart_input_text()
    |> assign(
      activity: nil,
      smart_input_text: nil
    )
  end

  def reset_smart_input(socket) do
    # debug("VOID")

    socket
    |> set_smart_input_text()
    |> assign(
      reply_to_id: nil,
      thread_id: nil,
      to_circles: nil,
      activity: nil,
      smart_input_text: nil
    )
  end

end
