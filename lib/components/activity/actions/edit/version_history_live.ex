defmodule Bonfire.UI.Social.VersionHistoryLive do
  use Bonfire.UI.Common.Web, :stateless_component

  slot default

  prop object, :any, default: nil
  prop versioning_enabled, :boolean, default: true
end
