defmodule Bonfire.UI.Social.Activity.ProviderReceiverLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Boundaries.Web.BoundaryIconLive

  prop activity, :map
  prop object, :any
  prop date_ago, :any
  prop permalink, :string
  prop object_boundary, :any, default: nil

  def provider(%{provider: provider}), do: provider
  def provider(%{object: object}), do: provider(object)
  def provider(%{activity: activity}), do: provider(activity)
  def provider(_), do: nil

  def receiver(%{receiver: receiver}), do: receiver
  def receiver(%{object: object}), do: receiver(object)
  def receiver(%{activity: activity}), do: receiver(activity)
  def receiver(_), do: nil

  def profile(object, field), do: e(object, field, nil) |> profile
  def profile(%{profile: %{name: _} = profile}), do: profile
  def profile(profile), do: profile

  def character(object, field), do: e(object, field, nil) |> character
  def character(%{character: %{username: _} = character}), do: character
  def character(character), do: character
end
