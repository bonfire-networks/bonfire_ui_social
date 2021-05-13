defmodule Bonfire.UI.Social.Activity.EconomicEventLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration

  prop activity, :map
  prop object, :map

  @resource_preloads [:image, :current_location, onhand_quantity: [:unit], accounting_quantity: [:unit]]

  def update(assigns, socket) do
    {:ok, socket |>
      assigns_merge(assigns,
        verb_display: Bonfire.UI.Social.ActivityLive.verb_display(assigns.object.action_id),
        object: assigns.object |> preloads() #|> IO.inspect
      )
    }
  end

  def preloads(object) do

    resource_preloads = Bonfire.UI.Social.Activity.EconomicResourceLive.resource_preloads()

    object
    |> repo().maybe_preload([
      :input_of,
      :output_of,
      resource_quantity: [:unit],
      effort_quantity: [:unit],
      resource_inventoried_as: resource_preloads,
      to_resource_inventoried_as: resource_preloads,
    ])
  end

end
