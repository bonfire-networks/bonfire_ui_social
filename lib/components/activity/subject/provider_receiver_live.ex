defmodule Bonfire.UI.Social.Activity.ProviderReceiverLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.Boundaries.Web.BoundaryIconStatelessLive

  prop object, :any, default: nil
  prop activity, :any, default: nil

  prop provider, :any, default: nil
  prop receiver, :any, default: nil
  prop primary_accountable, :any, default: nil

  prop date_ago, :any, default: nil
  prop permalink, :string, default: nil
  prop object_boundary, :any, default: nil

  def provider(%{id: _} = provider, _primary_accountable, _object), do: provider
  def provider(_provider, %{id: _} = primary_accountable, _object), do: primary_accountable
  def provider(_provider, _primary_accountable, %{id: _} = object), do: provider(object)
  def provider(_, _, _), do: nil

  def provider(%{provider: %{id: _} = provider}), do: provider
  def provider(%{primary_accountable: %{id: _} = primary_accountable}), do: primary_accountable
  def provider(%{creator: %{id: _} = creator}), do: creator
  def provider(_), do: nil

  def receiver(%{id: _} = receiver, _object), do: receiver
  def receiver(_, %{id: _} = object), do: receiver(object)
  def receiver(_, _), do: nil

  def receiver(%{receiver: %{id: _} = receiver}), do: receiver
  def receiver(_), do: nil

  def profile(object, field), do: e(object, field, nil) |> profile()
  def profile(%{profile: %{name: _} = profile}), do: profile
  def profile(profile), do: profile

  def character(object, field), do: e(object, field, nil) |> character()
  def character(%{character: %{username: _} = character}), do: character
  def character(character), do: character
end
