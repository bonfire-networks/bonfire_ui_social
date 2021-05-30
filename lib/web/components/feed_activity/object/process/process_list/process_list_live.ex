defmodule Bonfire.UI.Social.Activity.ProcessListLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch
  import Bonfire.UI.Social.Integration

  prop object, :map, required: true
  prop within_feed, :boolean, required: false, default: false

  def update(assigns, socket) do

    object = assigns.object |> preload() |> IO.inspect(label: "process_preloaded")

    tasks = e(object, :intended_outputs, [])

    tasks_total = Enum.count(tasks)

    tasks_completed =
      tasks
      |> Enum.filter(fn x -> x.finished end)
      |> Enum.count() # FIXME - get a count from DB query instead

    percentage = if tasks_total >0, do: ceil(tasks_completed / tasks_total * 100)

    {:ok, socket |>
      assigns_merge(assigns,
        object: object
          |> Map.put(:tasks_total, tasks_total)
          |> Map.put(:tasks_completed, tasks_completed)
          |> Map.put(:percentage, percentage)
      )
    }
  end

  def preloads(), do: [:intended_outputs]

  defp preload(object) do
    object
    |> repo().maybe_preload(preloads())
    # |> repo().maybe_preload([:context])
  end

end
