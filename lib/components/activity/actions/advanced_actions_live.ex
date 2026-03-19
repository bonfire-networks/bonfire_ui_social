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

  @doc "Batch-preloads object_boundary for all instances, delegating to Bonfire.Boundaries.LiveHandler"
  def update_many(assigns_sockets) do
    (Bonfire.Boundaries.LiveHandler.update_many(assigns_sockets,
       caller_module: __MODULE__
     ) || assigns_sockets)
    |> Enum.map(fn
      {assigns, socket} ->
        socket
        |> Phoenix.Component.assign(assigns)

      socket ->
        socket
    end)
  end

  def render(assigns) do
    assigns
    |> assign(
      creator_id: id(assigns[:creator]),
      creator_name:
        e(assigns[:creator], :profile, :name, nil) ||
          e(assigns[:creator], :character, :username, nil) ||
          l("the user")
    )
    |> render_sface()
  end
end
