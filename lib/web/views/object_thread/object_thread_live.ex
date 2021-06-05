defmodule  Bonfire.UI.Social.ObjectThreadLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do

    thread_id = e(assigns, :thread_id, e(assigns, :object, :id, nil))

    participants = Bonfire.Social.Threads.list_participants(thread_id, e(assigns, :current_user, nil))
    # |> IO.inspect

    participant_tuples = participants |> Map.get(:entries, []) |> Enum.map(&{e(&1, :profile, :name, "someone"), &1.id})

    {:ok, assign(socket, assigns
    |> assigns_merge(
        page: "Discussion",
        has_private_tab: false,
        smart_input: false,
        thread_id: thread_id,
        date_ago: date_from_now(e(assigns, :object, e(assigns, :activity, :object, nil))),
        participants: participants
      )
      ) |> assign_global(
        to_circles: e(assigns, :to_circles, []) ++ participant_tuples
      ) }
  end


end
