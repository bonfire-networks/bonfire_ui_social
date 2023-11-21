defmodule Bonfire.UI.Social.FlagActionLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Social.Flags

  prop object, :any
  prop parent_id, :string, default: nil
  prop label, :string, default: nil
  prop flagged, :any, default: nil
  prop hide_icon, :boolean, default: false
  prop object_type, :string, default: nil
end
