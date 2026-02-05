defmodule Bonfire.UI.Social.Activity.MoreActionsLive do
  use Bonfire.UI.Common.Web, :stateful_component
  # import Bonfire.UI.Social.Integration
  # alias Bonfire.UI.Common.OpenModalLive
  # alias Bonfire.UI.Social.Integration

  alias Bonfire.Social.Feeds.LiveHandler

  prop activity, :any, default: nil
  prop subject_user, :any, default: nil
  prop creator, :any, default: nil
  prop object, :any, required: true
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop verb, :string, default: nil
  prop object_type_readable, :any, default: nil
  prop permalink, :string, default: nil
  prop flagged, :any, default: nil
  prop activity_component_id, :string, default: nil
  prop thread_id, :string, required: true
  prop thread_mode, :any, default: nil
  prop thread_title, :any, default: nil
  prop is_remote, :boolean, default: false
  prop parent_id, :any, default: nil
  prop published_in, :any, default: nil
  prop participants, :any, default: nil
  prop quotes, :list, default: []
  prop showing_within, :atom, default: nil
  prop feed_name, :any, default: nil
  prop viewing_main_object, :boolean, default: false

  slot extra_items, required: false
  slot admin_items, required: false

  data menu_loaded, :boolean, default: false

  def update(assigns, socket) do
    creator = assigns[:creator]

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:menu_loaded, fn -> false end)
     |> assign(
       creator_id: id(creator),
       creator_name:
         e(creator, :profile, :name, nil) || e(creator, :character, :username, nil) ||
           l("the user")
     )}
  end

  def handle_event("load_menu_content", _params, socket) do
    debug("load_menu_content event received!")
    {:noreply, assign(socket, menu_loaded: true)}
  end

  def has_my_first_quote(quotes, my_id) when is_list(quotes) and not is_nil(my_id) do
    Enum.find_value(quotes, fn quote ->
      e(quote, :created, :creator_id, nil) == my_id && id(quote)
    end)
  end

  # def prepare(assigns) do
  #   if creator_or_subject =
  #        Bonfire.UI.Social.Activity.SubjectLive.current_creator_or_subject(assigns) do
  #     # || id(creator_or_subject(activity, object)) || creator_or_subject_id(activity, object)
  #     creator_or_subject_id = id(creator_or_subject)
  #     character_username = e(creator_or_subject, :character, :username, nil)

  #     assigns
  #     |> assign(
  #       creator: creator_or_subject,
  #       creator_id: creator_or_subject_id,
  #       # name(assigns.activity, assigns.object, creator_or_subject)
  #       creator_name: e(creator_or_subject, :profile, :name, l("this user"))
  #     )
  #   else
  #     creator_or_subject = creator_or_subject(assigns[:activity], assigns[:object])

  #     assigns
  #     |> assign(
  #       creator: creator_or_subject,
  #       creator_id:
  #         id(creator_or_subject) || creator_or_subject_id(assigns[:activity], assigns[:object]),
  #       creator_name: e(creator_or_subject, :profile, :name, l("this user"))
  #     )
  #   end
  # end

  # def creator_or_subject(activity, object) do
  #   e(object, :created, :creator, nil) || e(activity, :created, :creator, nil) ||
  #     e(activity, :subject, nil)
  # end

  # def creator_or_subject_id(activity, object, subject \\ nil) do
  #   id(subject) || e(object, :created, :creator_id, nil) || e(object, :creator_id, nil) ||
  #     e(activity, :subject_id, nil)
  # end

  # def name(activity, object, subject \\ nil) do
  #   e(subject || creator_or_subject(activity, object), :profile, :name, l("this user"))
  # end
end
