
defmodule Bonfire.UI.Social.SettingsViewLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.UI.Social.Integration, only: [is_admin?: 1]

  prop selected_tab, :string
  prop tab_id, :string
  prop uploads, :any

end
