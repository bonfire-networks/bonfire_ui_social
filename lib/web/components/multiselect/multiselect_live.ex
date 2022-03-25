defmodule Bonfire.UI.Social.MultiselectLive do
  use Bonfire.Web, :stateless_component
  use Bonfire.Common.Utils

  prop form_input_name, :string, required: true
  prop label, :string, default: ""
  prop preloaded_options, :any, default: []
  prop selected_options, :any, default: []
  prop focus_event, :string, required: false
  # prop autocomplete_event, :string, required: false
  prop pick_event, :string, required: false
  prop remove_event, :string, required: false
  prop context_id, :string

  def options(selected_options) when not is_list(selected_options) do
    [selected_options]
  end

  def options(selected_options) do
    selected_options
  end

end
