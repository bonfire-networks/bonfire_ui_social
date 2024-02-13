defmodule Bonfire.UI.Social.Activity.InstanceIconLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any, default: nil
  prop peered, :any, default: nil
  # prop verb_display, :string

  def permalink(%{canonical_uri: permalink}) do
    permalink
  end

  def permalink(%{peered: %{canonical_uri: permalink}}) do
    permalink
  end

  def permalink(%{peered: _} = object) do
    warn("FIXME: Peered should already come preloaded in object")

    object
    # |> repo().maybe_preload(:peered)
    |> e(:peered, :canonical_uri, nil)
  end

  def permalink(object) when is_map(object) or is_binary(object) do
    warn(object, "FIXME: object does not have a :peered assoc, query it instead")
    Utils.maybe_apply(
    Bonfire.Federate.ActivityPub.Peered,
    :get_canonical_uri,
    [object])
  end

  def permalink(other) do
    debug(other, "seems to be a local object")
    nil
  end
end
