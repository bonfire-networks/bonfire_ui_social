defmodule Bonfire.UI.Social.SetBoundariesLive do
  use Bonfire.Web, {:stateless_component, [module: __MODULE__]}
  use Bonfire.Common.Utils

  prop label, :string, default: ""
  prop default_circles, :list, default: []
  prop to_circles, :list

  # FIXME! update no longer works in stateless
  def update(assigns, socket), do: {:ok,
    updated(assigns, socket)
    # |> self_subscribe([:to_circles])
  }

  defp updated(%{to_circles: to_circles} = assigns, socket) when is_list(to_circles) and length(to_circles)>0, do: set_label(assigns, socket)
  defp updated(%{__context__: %{to_circles: to_circles}} = assigns, socket) when is_list(to_circles) and length(to_circles)>0, do: set_label(assigns, socket)

  defp updated(assigns, socket) do

    # debug(assigns: assigns)

    circles = Bonfire.Boundaries.Circles.list_my_defaults() # TODO link to current user for configure

    debug(set_default_circles: circles)

    assigns
    |> assigns_merge(%{
      default_circles: circles, # circles showing before typing in autocomplete
      # to_circles: circles, # default selected circles if none specified
    })
    |> set_label(socket)
  end

  def set_label(assigns, socket) do

    nobody = "Note to self"

    to_circles = e(assigns, :to_circles, [])

    label = cond do
      is_list(to_circles) && length(to_circles)==1 && to_circles |> List.first() |> elem(1) == e(current_user(assigns), :id, nil) ->
        nobody

      e(assigns, :create_activity_type, nil)==:message ->

          if length(to_circles)>0 do
            "Send a message to "
          else
            nobody
          end

      length(to_circles)>0 ->

        "Share a post with "

      true ->
        nobody
    end


    socket
    |> assigns_merge(assigns,
      label: label
    )
  end


end
