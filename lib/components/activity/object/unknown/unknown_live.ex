defmodule Bonfire.UI.Social.Activity.UnknownLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any, default: nil
  prop object_type_readable, :any, default: nil
end
