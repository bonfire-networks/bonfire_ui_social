defmodule Bonfire.UI.Social.Activity.ProviderReceiverLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Boundaries.Web.BoundaryIconLive

  prop activity, :map
  prop object, :any
  prop date_ago, :any
  prop permalink, :string
  prop object_boundary, :any, default: nil

  def provider(%{provider: %{id: _} = provider}), do: provider
  def provider(%{object: %{id: _} = object}), do: provider(object)
  def provider(%{activity: %{id: _} = activity}), do: provider(activity)
  def provider(_), do: nil

  def receiver(%{receiver: %{id: _} = receiver}), do: receiver
  def receiver(%{object: %{id: _} = object}), do: receiver(object)
  def receiver(%{activity: %{id: _} = activity}), do: receiver(activity)
  def receiver(_), do: nil

  def profile(object, field), do: e(object, field, nil) |> profile()
  def profile(%{profile: %{name: _} = profile}), do: profile
  def profile(profile), do: profile

  def character(object, field), do: e(object, field, nil) |> character()
  def character(%{character: %{username: _} = character}), do: character
  def character(character), do: character
end
