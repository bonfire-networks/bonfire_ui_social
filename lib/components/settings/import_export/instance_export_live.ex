defmodule Bonfire.UI.Social.InstanceExportLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :any
  prop scope, :atom, default: :instance_wide
end
