defmodule Bonfire.UI.Social.EditPostLive do
  use Bonfire.UI.Common.Web, :stateless_component

  slot default

  prop object, :any, default: nil
  prop object_boundary, :any, default: nil

  prop parent_id, :string, default: nil
end
