defmodule Bonfire.UI.Social.Activity.MediaLive do
  use Bonfire.Web, :stateless_component

  prop media, :list, default: []
  prop showing_within, :any
  
end
