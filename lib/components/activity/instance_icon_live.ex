defmodule Bonfire.UI.Social.Activity.InstanceIconLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  # prop verb_display, :string

  def permalink(%{object: %{peered: %{canonical_uri: permalink}}} = _assigns) when is_binary(permalink) do
    permalink
  end

  def permalink(%{object: %{peered: _} = object} = _assigns) do
    warn("FIXME: Peered should already come preloaded in object")
    object
    |> repo().maybe_preload(:peered)
    |> e(:peered, :canonical_uri, nil)
  end

  def permalink(%{object: object}) do
    warn(object, "object does not have a :peered assoc")
    Bonfire.Federate.ActivityPub.Peered.get_canonical_uri(object)
  end

  def permalink(_assigns) do
    nil
  end

end
