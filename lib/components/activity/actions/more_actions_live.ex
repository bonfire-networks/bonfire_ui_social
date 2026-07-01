defmodule Bonfire.UI.Social.Activity.MoreActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component

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

  def render(assigns) do
    creator = assigns[:creator]

    assigns
    |> assign(
      creator_id: id(creator),
      creator_name:
        e(creator, :profile, :name, nil) || e(creator, :character, :username, nil) ||
          l("the user")
    )
    |> render_sface()
  end

  def has_my_first_quote(quotes, my_id) when is_list(quotes) and not is_nil(my_id) do
    Enum.find_value(quotes, fn quote ->
      e(quote, :created, :creator_id, nil) == my_id && id(quote)
    end)
  end
end
