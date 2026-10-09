defmodule Bonfire.UI.Social.FeedDetailsButtonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The feed whose description and actions the menu shows."
  prop feed_name, :any, required: true
end
