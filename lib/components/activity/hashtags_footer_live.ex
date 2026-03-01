defmodule Bonfire.UI.Social.Activity.HashtagsFooterLive do
  @doc "Renders out-of-band hashtags (not visible in content) as clickable badge chips."
  use Bonfire.UI.Common.Web, :stateless_component

  prop hashtags, :list, default: []
end
