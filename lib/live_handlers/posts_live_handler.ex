defmodule Bonfire.Social.Posts.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle
  use Bonfire.Common.Utils
  alias Bonfire.Social.Posts
  # alias Bonfire.Social.PostContents
  # alias Bonfire.Data.Social.PostContent
  # alias Bonfire.Data.Social.Post
  # alias Ecto.Changeset

  def handle_params(
        %{"after" => cursor} = _attrs,
        _,
        %{assigns: %{thread_id: thread_id}} = socket
      ) do
    live_more(thread_id, [after: cursor], socket)
  end

  def handle_params(%{"after" => cursor, "context" => thread_id} = _attrs, _, socket) do
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
        %{"after" => _cursor} = attrs,
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
    current_user = current_user_required!(socket)

    with %{valid?: true} <- post_changeset(attrs, current_user),
         uploaded_media <- live_upload_files(current_user, params["upload_metadata"], socket),
         opts <-
           [
             current_user: current_user,
             post_attrs:
               Bonfire.Social.Posts.prepare_post_attrs(attrs)
               |> Map.put(:uploaded_media, uploaded_media),
             boundary: e(params, "to_boundaries", "mentions"),
             to_circles: e(params, "to_circles", []),
             context_id: e(params, "context_id", nil),
             return_epic_on_error: true
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
          "<div class='flex justify-between items-center'> <span>#{l("Posted!")} </span><a href='#{permalink}' class='btn-outline btn btn-xs normal-case font-medium text-info-content rounded'>#{l("Show")}</a></div>"
        )
        # |> Bonfire.UI.Common.SmartInput.LiveHandler.close_smart_input()
        |> Bonfire.UI.Common.SmartInput.LiveHandler.reset_input()
        # |> patch_to(current_url(socket), fallback: path(published)) # so the flash appears - TODO: causes a conflict between the activity coming in via pubsub

        # assign_generic(socket,
        #   feed: [%{published.activity | object_post: published.post, subject_user: current_user_required!(socket)}] ++ Map.get(socket.assigns, :feed, [])
        # )
      }

      # else
      #   {:error, error} ->
      #     {
      #       :noreply,
      #       socket
      #       |> assign_error(error)
      #     }
      #   e ->
      #     error = Errors.error_msg(e)
      #     error(error)

      #     {
      #       :noreply,
      #       socket
      #       |> assign_error("Could not post 😢 (#{error})")
      #     }
    end
  end

  # def toggle_minimized_composer(js \\ %JS{}) do
  #   js
  #   |> JS.toggle(to: ".smart_input_show_on_minimize", in: "fade-in-scale", out: "fade-out-scale")
  # end

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
    debug("load extra replies")
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

  # def handle_event("switch_thread_mode", %{"thread_mode" => thread_mode} = _attrs, socket) do
  #   IO.inspect(thread_mode, label: "THREAD MODE")

  #   if thread_mode == "flat" do
  #     {:noreply,
  #      assign(socket,
  #        thread_mode: :thread
  #      )}
  #   else
  #     {:noreply,
  #      assign(socket,
  #        thread_mode: :flat
  #      )}
  #   end
  # end

  def handle_event("input", %{"circles" => selected_circles} = _attrs, socket)
      when is_list(selected_circles) and length(selected_circles) > 0 do
    # |> Enum.uniq()
    previous_circles = e(socket, :assigns, :to_circles, [])

    new_circles = Bonfire.Boundaries.LiveHandler.set_circles(selected_circles, previous_circles)

    {:noreply,
     socket
     |> assign(to_circles: new_circles || [])}
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
     |> Bonfire.UI.Common.SmartInput.LiveHandler.set_smart_input_text(text)}
  end

  def live_more(thread_id, paginate, socket) do
    # debug(paginate, "paginate thread")
    current_user = current_user(socket)

    with %{edges: replies, page_info: page_info} <-
           Bonfire.Social.Threads.list_replies(thread_id,
             current_user: current_user,
             paginate: paginate
           ) do
      replies =
        (e(socket.assigns, :replies, []) ++ replies)
        |> Enum.uniq()

      # |> debug("REPLIES")

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
end
