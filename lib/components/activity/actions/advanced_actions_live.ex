defmodule Bonfire.UI.Social.Activity.AdvancedActionsLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop activity, :any, default: nil
  prop object, :any, required: true
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop creator, :any, default: nil
  prop thread_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_component_id, :string, default: nil
  prop parent_id, :any, default: nil
  prop object_type_readable, :any, default: nil
  prop verb, :string, default: nil
  prop permalink, :string, default: nil
  prop published_in, :any, default: nil
  prop participants, :any, default: nil
  prop quotes, :list, default: []

  data panel_prefix, :string, default: ""
  data can_remove_from_group, :boolean, default: false
  data post_content, :any, default: nil
  data object_type_label, :string, default: ""

  @doc "Batch-preloads object_boundary for all instances, delegating to Bonfire.Boundaries.LiveHandler"
  def update_many(assigns_sockets) do
    (Bonfire.Boundaries.LiveHandler.update_many(assigns_sockets,
       caller_module: __MODULE__
     ) || assigns_sockets)
    |> Enum.map(fn
      {assigns, socket} ->
        socket
        |> Phoenix.Component.assign(assigns)
        |> assign_derived()

      socket ->
        assign_derived(socket)
    end)
  end

  # worked out when the assigns change, rather than in `render/1` on every re-render
  defp assign_derived(socket) do
    assigns = socket.assigns

    Phoenix.Component.assign(socket,
      creator_id: id(assigns[:creator]),
      creator_name:
        e(assigns[:creator], :profile, :name, nil) ||
          e(assigns[:creator], :character, :username, nil) ||
          l("the user"),
      panel_prefix:
        "av-" <>
          deterministic_dom_id(
            __MODULE__,
            id(assigns[:activity] || assigns[:object]),
            nil,
            assigns[:parent_id]
          ),
      post_content: Bonfire.UI.Social.Activity.NoteLive.post_content(assigns[:object]),
      object_type_label: e(assigns[:object_type_readable], l("object")),
      # for both the menu item and its confirmation panel: the post's author, or whoever moderates the group it's in, may take it out of the group (the context decides)
      can_remove_from_group:
        not is_nil(assigns[:published_in]) and not is_nil(id(assigns[:object])) and
          maybe_apply(
            Bonfire.Classify.Categories,
            :can_remove_post_from_group?,
            [current_user(assigns[:__context__]), assigns[:published_in], assigns[:object]],
            fallback_return: false
          ) == true
    )
  end
end
