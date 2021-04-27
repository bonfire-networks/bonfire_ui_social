defmodule Bonfire.UI.Social.MultiselectLive do
  use Surface.Component
  import Bonfire.Common.Utils

  prop preloaded_options, :list, required: true
  prop selected_options, :list, required: true
  prop label, :string, required: true
  prop form_input_name, :string, required: true
  prop pick_event, :event, required: true
  prop remove_event, :event, required: true

end
