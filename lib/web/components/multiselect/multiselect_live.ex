defmodule Bonfire.UI.Social.MultiselectLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.Common.Utils

  prop form_input_name, :string, required: true
  prop label, :string, default: ""
  prop preloaded_options, :list, default: []
  prop selected_options, :any, default: []
  prop pick_event, :string, required: true
  prop remove_event, :string, required: true
  prop context_id, :string

  def update(%{selected_options: selected_options} = assigns, socket) when not is_list(selected_options) do
    {:ok, socket |> assigns_merge(assigns, selected_options: [selected_options])}
  end

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end
end
