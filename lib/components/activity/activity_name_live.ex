defmodule Bonfire.UI.Social.Activity.ActivityNameLive do
  @doc "Shows an activity's own name (its `named`, eg. a moderation record's reason or a flag's comment), when the feed preloaded it (`:activity_name`). Says nothing about what the name means for that activity."
  use Bonfire.UI.Common.Web, :stateless_component

  prop name, :string, required: true
end
