defmodule Bonfire.UI.Social.Activity.EconomicEventLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration

  prop activity, :map
  prop object, :map

  @resource_preloads [:image, :current_location, onhand_quantity: [:unit], accounting_quantity: [:unit]]

  def update(%{object: object} = assigns, socket) do
    # TODO: run these preloads when fetching the feed, rather than n+1
    object = object |> maybe_to_struct(ValueFlows.EconomicEvent) |> preload() |> maybe_preload_action()
 #|> IO.inspect
    {:ok, socket |>
      assigns_merge(assigns,
        verb_display: Bonfire.UI.Social.ActivityLive.verb_display(e(object, :action, :label, e(assigns.object, :action_id, ""))),
        object: object
      )
    }
  end

  def preloads() do
    resource_preloads = Bonfire.UI.Social.Activity.EconomicResourceLive.preloads()

    [
      :input_of,
      :output_of,
      resource_quantity: [:unit],
      effort_quantity: [:unit],
      resource_inventoried_as: resource_preloads,
      to_resource_inventoried_as: resource_preloads,
    ]
  end

  defp preload(object) do
    object
    |> repo().maybe_preload(preloads())
  end

  def maybe_preload_action(object) do
    if module_enabled?(ValueFlows.EconomicEvent.EconomicEvents), do: ValueFlows.EconomicEvent.EconomicEvents.preload_action(object),
    else: object
  end

end
