defmodule Bonfire.UI.Social.Activity.EconomicResourceLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration

  prop object, :map

  def update(assigns, socket) do
    # TODO: run these preloads when fetching the feed, rather than n+1
    {:ok, socket |>
      assigns_merge(assigns,
        object: assigns.object
        |> preload() #|> IO.inspect
      )
    }
  end

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
