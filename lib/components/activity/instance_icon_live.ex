defmodule Bonfire.UI.Social.Activity.InstanceIconLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any, required: true
  # prop verb_display, :string

  def permalink(%{peered: %{canonical_uri: permalink}}) when is_binary(permalink) do
    permalink
  end

  def permalink(%{peered: _} = object) do
    warn("FIXME: Peered should already come preloaded in object")
    object
    |> repo().maybe_preload(:peered)
    |> e(:peered, :canonical_uri, nil)
  end

  def permalink(object) do
    warn(object, "object does not have a :peered assoc")
    Bonfire.Federate.ActivityPub.Peered.get_canonical_uri(object)
  end

end
