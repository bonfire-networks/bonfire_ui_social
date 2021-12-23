defmodule Bonfire.UI.Social.Activity.EconomicResourceLive do
  use Bonfire.Web, :stateless_component


  prop object, :map

  def preloads(), do: [
    :image,
    :current_location,
    primary_accountable: [:character, profile: [:icon]],
    onhand_quantity: [:unit],
    accounting_quantity: [:unit]
  ]

  defp preload(object) do
    object
    |> repo().maybe_preload(preloads())
  end
end
