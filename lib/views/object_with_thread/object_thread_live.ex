defmodule  Bonfire.UI.Social.ObjectThreadLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :string
  prop page_title, :string
  prop show_reply_input, :boolean, default: false
  prop search_placeholder, :string
  prop create_activity_type, :any
  prop to_circles, :list
  prop smart_input_prompt, :string
  prop smart_input_text, :string
  prop reply_to_id, :string
  prop thread_id, :string
  prop activity, :any
  prop showing_within, :any
  prop object, :any
  prop url, :string
  prop thread_mode, :any
  prop reverse_order, :any
  prop participants, :list
  prop textarea_class, :string
  prop smart_input_class, :string
  prop replied_activity_class, :string
  prop replies, :any
  prop threaded_replies, :any, default: []
  prop page_info, :any

  def participants(assigns) do
    if e(assigns, :participants, nil) do
      e(assigns, :participants, [])
    # else
    #   thread_id = e(assigns, :thread_id, e(assigns, :object, :id, nil))
    #   # participants =
    #     Bonfire.Social.Threads.fetch_participants(thread_id, current_user: current_user(assigns)) |> debug("participants")
    #   # participant_tuples = participants |> Map.get(:edges, []) |> Enum.map(&{e(&1, :profile, :name, "someone"), &1.id})
    #   # to_circles = e(assigns, :to_circles, []) ++ participant_tuples
    end
  end

end