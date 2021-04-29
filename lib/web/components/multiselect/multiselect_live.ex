defmodule Bonfire.UI.Social.MultiselectLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.Common.Utils

  prop form_input_name, :string, required: true
  prop label, :string, default: ""
  prop preloaded_options, :list, default: []
  prop selected_options, :list, default: []
  prop pick_event, :event, required: true
  prop remove_event, :event, required: true

end
