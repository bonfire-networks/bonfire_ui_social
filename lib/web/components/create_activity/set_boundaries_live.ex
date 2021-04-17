defmodule Bonfire.UI.Social.SetBoundariesLive do
  use Bonfire.Web, :live_component

  def mount(socket) do

    circles = Bonfire.Me.Users.Circles.list_my_defaults()

    {:ok, assign(socket,
      default_circles: circles, # circles showing before typing in autocomplete
      to_circles: circles, # default selected circles if none specified
    )}
  end

  def update(assigns, socket) do

    nobody = "Note to self"

    label = cond do
      length(e(assigns, :to_circles, []))==1 && e(assigns, :to_circles, []) |> List.first() |> elem(1) == e(assigns, :current_user, :id, nil) ->
        nobody

      e(assigns, :smart_input_private, nil) || e(assigns, :create_activity_type, nil)=="message" ->

          if length(e(assigns, :to_circles, []))>0 do
            "Send a message to "
          else
            nobody
          end

      length(e(assigns, :to_circles, []))>0 ->

        "Share a post with "

      true ->
        nobody
    end


    {:ok, assign(socket,
    assigns
      |> assigns_merge(label: label)) }
  end


end
