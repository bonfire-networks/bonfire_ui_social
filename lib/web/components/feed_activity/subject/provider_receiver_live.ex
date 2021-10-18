defmodule Bonfire.UI.Social.Activity.ProviderReceiverLive do
  use Bonfire.Web, :stateless_component

  prop activity, :map
  prop object, :map
  prop provider, :map, required: false
  prop date_ago, :any
  prop permalink, :string

  def provider(%{provider: provider}), do: provider
  def provider(%{object: %{provider: provider}}), do: provider

  def receiver(%{receiver: receiver}), do: receiver
  def receiver(%{object: %{receiver: receiver}}), do: receiver

  def profile(object, field), do: e(object, field, nil) |> profile
  def profile(%{profile: %{name: _} = profile}), do: profile
  def profile(profile), do: profile

  def character(object, field), do: e(object, field, nil) |> character
  def character(%{character: %{username: _} = character}), do: character
  def character(character), do: character
end
