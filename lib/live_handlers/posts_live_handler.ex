defmodule Bonfire.Social.Posts.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

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

  # workaround for a weird issue appearing in tests
  def handle_params(attrs, uri, socket) do
    case URI.parse(uri) do
      %{path: "/discussion/" <> thread_id} -> live_more(thread_id, input_to_atoms(attrs), socket)
      %{path: "/post/" <> thread_id} -> live_more(thread_id, input_to_atoms(attrs), socket)
    end
  end

  def handle_event(
        "load_more",
        %{"after" => cursor} = attrs,
        %{assigns: %{thread_id: thread_id}} = socket
      ) do
    live_more(thread_id, input_to_atoms(attrs), socket)
  end

  def handle_event("post", %{"create_object_type" => "message"} = params, socket) do
    Bonfire.Social.Messages.LiveHandler.send_message(params, socket)
  end

  def handle_event("post", %{"post" => %{"create_object_type" => "message"}} = params, socket) do
    Bonfire.Social.Messages.LiveHandler.send_message(params, socket)
  end

  # if not a message, it's a post by default
  def handle_event("post", params, socket) do
    attrs =
      params
      # |> debug("post params")
      |> input_to_atoms()

    # |> debug("post attrs")

    # debug(e(socket.assigns, :showing_within, nil), "SHOWING")
    current_user = current_user(socket)

    with %{} <- current_user || {:error, "You must be logged in"},
         %{valid?: true} <- post_changeset(attrs, current_user),
         uploaded_media <- multi_upload(current_user, params["upload_metadata"], socket),
         opts <-
           [
             current_user: current_user,
             post_attrs:
               Bonfire.Social.Posts.prepare_post_attrs(attrs)
               |> Map.put(:uploaded_media, uploaded_media),
             boundary: e(params, "to_boundaries", "mentions")
           ]
           |> debug("publish opts"),
         {:ok, published} <- Bonfire.Social.Posts.publish(opts) do
      debug(published, "published!")

      activity = e(published, :activity, nil)
      thread = e(activity, :replied, :thread, nil) || e(activity, :replied, :thread_id, nil)

      thread_url =
        if thread do
          if is_struct(thread) do
            path(thread)
          else
            "/discussion/#{ulid(thread)}"
          end
        else
          nil
        end

      permalink =
        if thread_url && ulid(thread) != activity.object.id,
          do: "#{thread_url}#activity-#{activity.object.id}",
          else: "#{path(activity.object)}#"

      debug(permalink, "permalink")

      {
        :noreply,
        socket
        |> assign_flash(
          :info,
          "#{l("Posted!")} <a href='#{permalink}' class='mx-1 text-sm text-gray-500 capitalize link'>#{l("Show")}</a>"
        )
        |> Bonfire.UI.Common.SmartInputLive.reset_input()
        # |> push_patch_with_fallback(current_url(socket), path(published)) # so the flash appears - TODO: causes a conflict between the activity coming in via pubsub

        # assign_generic(socket,
        #   feed: [%{published.activity | object_post: published.post, subject_user: current_user(socket)}] ++ Map.get(socket.assigns, :feed, [])
        # )
      }
    else
      e ->
        error(error_msg(e))

        {
          :noreply,
          socket
          |> assign_flash(:error, "Could not post 😢 (#{error_msg(e)})")
          # |> patch_to(current_url(socket), fallback: "/error") # so the flash appears
        }
    end
  end

  def handle_event("write_error", _, socket) do
    Bonfire.UI.Common.NotificationLive.error_template(socket.assigns)
    |> write_feedback(socket)
  end

  def handle_event("write_feedback", _, socket) do
    write_feedback(
      Settings.get(
        [:ui, :feedback_post_template],
        "I have a suggestion for Bonfire: \n\n@BonfireBuilders #bonfire_feedback",
        socket
      ),
      socket
    )
  end

  def handle_event("load_replies", %{"id" => id, "level" => level}, socket) do
    info("load extra replies")
    {level, _} = Integer.parse(level)

    %{edges: replies} =
      Bonfire.Social.Threads.list_replies(id, socket: socket, max_depth: level + 1)

    replies = replies ++ Utils.e(socket.assigns, :replies, [])

    {:noreply,
     assign(socket,
       replies: replies
       # threaded_replies: Bonfire.Social.Threads.arrange_replies_tree(replies) || []
     )}
  end

  def handle_event("switch_thread_mode", %{"thread_mode" => thread_mode} = _attrs, socket) do
    IO.inspect(thread_mode, label: "THREAD MODE")

    if thread_mode == "flat" do
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

  def handle_event("input", %{"circles" => selected_circles} = _attrs, socket)
      when is_list(selected_circles) and length(selected_circles) > 0 do
    # |> Enum.uniq()
    previous_circles = e(socket, :assigns, :to_circles, [])

    new_circles =
      Bonfire.UI.Me.LiveHandlers.Boundaries.set_circles(selected_circles, previous_circles)

    {:noreply,
     socket
     |> assign(to_circles: new_circles)}
  end

  # no circle
  def handle_event("input", _attrs, socket) do
    {:noreply,
     socket
     |> assign(to_circles: [])}
  end

  # def handle_event("add_data", %{"activity" => activity_id}, socket) do
  #   IO.inspect("TEST")
  #   maybe_send_update(Bonfire.UI.Social.ActivityLive, "activity_component_" <> activity_id, activity_id: activity_id)
  #   {:noreply, socket}
  # end

  def write_feedback(text, socket) do
    {:noreply,
     socket
     |> Bonfire.UI.Common.SmartInputLive.set_smart_input_text(text)}
  end

  def live_more(thread_id, paginate, socket) do
    # info(paginate, "paginate thread")
    current_user = current_user(socket)

    with %{edges: replies, page_info: page_info} <-
           Bonfire.Social.Threads.list_replies(thread_id,
             current_user: current_user,
             paginate: paginate
           ) do
      replies =
        (e(socket.assigns, :replies, []) ++ replies)
        |> Enum.uniq()

      # |> info("REPLIES")

      threaded_replies =
        if is_list(replies) and length(replies) > 0,
          do: Bonfire.Social.Threads.arrange_replies_tree(replies),
          else: []

      # debug(threaded_replies, "REPLIES threaded")

      {:noreply,
       socket
       |> assign(
         replies: replies,
         threaded_replies: threaded_replies,
         page_info: page_info
       )}
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

      with {:ok, uploaded} <-
             Bonfire.Files.upload(nil, current_user, path, %{
               client_name: entry.client_name,
               metadata: metadata[entry.ref]
             })
             |> debug("uploaded") do
        {:ok, uploaded}
      else
        e ->
          error(e, "Did not upload #{entry.client_name}")
          {:postpone, nil}
      end
    end)
    |> filter_empty([])
  end
end
