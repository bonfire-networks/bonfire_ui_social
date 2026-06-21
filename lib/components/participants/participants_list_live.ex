defmodule Bonfire.UI.Social.ParticipantsListLive do
  @moduledoc """
  Shared component for rendering a list of thread participants with a "show top N, reveal
  the rest" control. The rest is already in memory (the full list is passed in), so the
  reveal is a pure client/LiveComponent state toggle — no extra query. See bonfire-app#1988.

  Each item is rendered via the default slot, so callers control the per-item markup
  (e.g. the messages thread list renders a name, the discussion widget renders an avatar
  card). The cap + reveal logic lives here, once.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  @doc "The full (already sorted/prepared) list of participants to render."
  prop participants, :list, default: []

  @doc "How many to show before the reveal control."
  prop limit, :integer, default: 4

  @doc "CSS class for the wrapping list element."
  prop list_class, :css_class, default: ""

  @doc "CSS class for each list item."
  prop item_class, :css_class, default: ""

  data expanded, :boolean, default: false

  @doc "Renders a single participant. Receives `participant`."
  slot default, arg: [participant: :any]

  def handle_event("toggle_participants", _params, socket) do
    {:noreply, assign(socket, expanded: !e(assigns(socket), :expanded, false))}
  end
end
