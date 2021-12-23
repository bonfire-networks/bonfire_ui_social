defmodule Bonfire.UI.Social.Activity.EconomicEventLive do
  use Bonfire.Web, :stateless_component


  prop activity, :map
  prop object, :map

  @resource_preloads [:image, :current_location, onhand_quantity: [:unit], accounting_quantity: [:unit]]


  def preloads() do
    resource_preloads = Bonfire.UI.Social.Activity.EconomicResourceLive.preloads()

    [
      :input_of,
      :output_of,
      provider: [:character, profile: [:icon]],
      receiver: [:character, profile: [:icon]],
      resource_quantity: [:unit],
      effort_quantity: [:unit],
      resource_inventoried_as: resource_preloads,
      to_resource_inventoried_as: resource_preloads,
    ]
  end

  def activity_component(object) do
    object = prepare(object)
    {__MODULE__,
      [
        object: object,
        verb_display: Bonfire.UI.Social.ActivityLive.verb_display(e(object, :action, :label, e(object, :action_id, "")))
      ]
    }
  end


  def prepare(object) do
    object
    # |> IO.inspect(label: "event")
    |> maybe_to_struct(ValueFlows.EconomicEvent)
    # |> IO.inspect(label: "struct")
    |> preload()
  end

  defp preload(object) do
    object
    |> repo().maybe_preload(preloads())
    |> maybe_preload_action()
  end

  def maybe_preload_action(object) do
    if module_enabled?(ValueFlows.EconomicEvent.EconomicEvents), do: ValueFlows.EconomicEvent.EconomicEvents.preload_action(object),
    else: object
  end

end
