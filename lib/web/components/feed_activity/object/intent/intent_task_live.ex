defmodule Bonfire.UI.Social.Activity.IntentTaskLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch
  import Bonfire.UI.Social.Integration

  prop object, :map, required: true

  def update(assigns, socket) do

    object = assigns.object |> preload()

    # TODO: run these preloads when fetching the feed, rather than n+1
    {:ok, socket |>
      assigns_merge(assigns,
        object: object
          |> Map.put(:context, [Map.get(object, :context)])
          # |> IO.inspect(label: "task_preloaded")
      )
    }
  end

  def preloads(), do: [
    :output_of,
    provider: [:character, profile: [:icon]]
  ]

  defp preload(object) do
    object
    |> repo().maybe_preload(preloads())
    |> repo().maybe_preload([:context])
  end
end
