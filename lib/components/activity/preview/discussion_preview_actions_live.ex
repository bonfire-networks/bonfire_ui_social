defmodule Bonfire.UI.Social.Activity.DiscussionPreviewActionsLive do
  @moduledoc """
  Compact actions footer for discussion previews: a reply counter plus a facepile of the thread's other participants, in place of `ActionsLive` (so the like/boost buttons and their preloads are skipped entirely). It loads the facepile itself, one batch for the page's cards in `update_many/1`, so the lists it shows in, and their caches, hold no participants to go stale.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  prop activity, :any, default: nil
  prop object, :any, default: nil
  prop permalink, :string, default: nil
  prop reply_count, :any, default: 0
  prop activity_component_id, :string, default: nil
  prop showing_within, :atom, default: nil

  data participants, :list, default: nil
  data participants_more_count, :integer, default: 0

  def update_many(assigns_sockets) do
    [{first_assigns, first_socket} | _] = assigns_sockets
    current_user = current_user(first_assigns) || current_user(first_socket)

    # a signed-in page renders twice (static, then connected) while a guest's never connects: load once, on the render that stays
    load? = is_nil(current_user) or socket_connected?(first_socket)

    # only cards not loaded yet: a parent re-render brings fresh props, and must neither re-query nor blank the facepile
    loaded =
      for(
        {assigns, socket} <- assigns_sockets,
        load? and is_nil(socket.assigns[:participants]),
        do: %{id: assigns.id, activity: assigns[:activity]}
      )
      |> case do
        [] ->
          %{}

        cards ->
          cards
          |> Bonfire.Social.Threads.attach_participants(current_user)
          |> Map.new(&{&1.id, &1})
      end

    Enum.map(assigns_sockets, fn {assigns, socket} ->
      card = Map.get(loaded, assigns.id)

      socket
      |> assign(assigns)
      |> assign(
        participants: e(card, :participants, nil) || socket.assigns[:participants] || [],
        participants_more_count:
          e(card, :participants_more_count, nil) || socket.assigns[:participants_more_count] || 0
      )
    end)
  end

  @doc "Returns the root thread reply count when present, otherwise the prepared activity count."
  def display_reply_count(activity, fallback_count) do
    if e(activity, :replied, :thread, :post_content, nil) do
      e(activity, :replied, :thread, :replied, :nested_replies_count, 0) +
        e(activity, :replied, :thread, :replied, :direct_replies_count, 0)
    else
      e(fallback_count, 0)
    end
  end
end
