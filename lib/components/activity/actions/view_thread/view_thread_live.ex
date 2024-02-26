defmodule Bonfire.UI.Social.Activity.ViewThreadLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object_id, :string
  prop permalink, :string
  prop replied, :any
end
