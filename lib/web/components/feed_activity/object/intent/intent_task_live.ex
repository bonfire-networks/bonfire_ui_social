defmodule Bonfire.UI.Social.Activity.IntentTaskLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch
  import Bonfire.UI.Social.Integration

  prop object, :map, required: true

  def update(assigns, socket) do

    object = assigns.object |> preloads()

    # TODO: run these preloads when fetching the feed, rather than n+1
    {:ok, socket |>
      assigns_merge(assigns,
        object: object
          |> Map.put(:in_scope_of, [Map.get(object, :context)])
          |> IO.inspect(label: "task_preloaded")
      )
    }
  end

  def intent_preloads(), do: [:output_of, provider: [:profile, :character]]

  def preloads(object) do
    object
    |> repo().maybe_preload(intent_preloads())
    |> repo().maybe_preload([:context])
  end
end
