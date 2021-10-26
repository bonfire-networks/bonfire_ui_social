defmodule Bonfire.UI.Social.SetBoundariesLive do
  use Bonfire.Web, {:stateless_component, [module: __MODULE__]}
  import Bonfire.Common.Utils

  prop label, :string, default: ""
  prop default_circles, :list, default: []
  prop to_circles, :list

  def update(assigns, socket), do: {:ok, updated(assigns, socket)
  # |> self_subscribe([:to_circles])
  }

  defp updated(%{to_circles: to_circles} = assigns, socket) when is_list(to_circles) and length(to_circles)>0, do: set_label(assigns, socket)
  defp updated(%{__context__: %{to_circles: to_circles}} = assigns, socket) when is_list(to_circles) and length(to_circles)>0, do: set_label(assigns, socket)

  defp updated(assigns, socket) do

    # IO.inspect(assigns: assigns)

    circles = Bonfire.Me.Users.Circles.list_my_defaults() # TODO link to current user for configure

    IO.inspect(set_default_circles: circles)

    assigns
    |> assigns_merge(%{
      default_circles: circles, # circles showing before typing in autocomplete
      # to_circles: circles, # default selected circles if none specified
    })
    |> set_label(socket)
  end

  def set_label(assigns, socket) do

    nobody = "Note to self"

    to_circles = (e(assigns, :to_circles, []) || []) |> IO.inspect()

    label = cond do
      length(to_circles)==1 && to_circles |> List.first() |> elem(1) == e(assigns, :current_user, :id, nil) ->
        nobody

      e(assigns, :create_activity_type, nil)=="message" ->

          if length(e(assigns, :to_circles, []))>0 do
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
