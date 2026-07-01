defmodule Bonfire.UI.Social.Activity.InstanceIconLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any, default: nil
  prop peered, :any, default: nil
end
