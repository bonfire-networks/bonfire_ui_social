defmodule Bonfire.UI.Social.Activity.CategoryActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop activity_id, :string, default: nil
  prop object_boundary, :any, default: nil
  prop type, :any, default: nil

  # def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
end
