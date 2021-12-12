defmodule  Bonfire.UI.Social.ObjectThreadLive do
  use Bonfire.Web, :stateless_component

  prop page, :string
  prop page_title, :string
  prop has_private_tab, :boolean
  prop search_placeholder, :string
  prop smart_input_placeholder, :string
  prop reply_id, :string
  prop activity, :any
  prop object, :any
  prop thread_id, :string

  # TODO: FIXME! Update no longer works in stateless
  def update(assigns, socket) do
    thread_id = e(assigns, :thread_id, e(assigns, :object, :id, nil))
    participants = Bonfire.Social.Threads.list_participants(thread_id, current_user(assigns))
    participant_tuples = participants |> Map.get(:edges, []) |> Enum.map(&{e(&1, :profile, :name, "someone"), &1.id})

    {:ok, assign(socket, assigns
    |> assigns_merge(
        date_ago: date_from_now(e(assigns, :object, e(assigns, :activity, :object, nil))),
        participants: participants
      )
      ) |> assign_global(
        to_circles: e(assigns, :to_circles, []) ++ participant_tuples
      ) }
  end

end
