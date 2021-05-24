defmodule Bonfire.UI.Social.Activity.ListLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch
  import Bonfire.UI.Social.Integration
  
  prop object, :map, required: true

  def update(assigns, socket) do
    tasks_total = Enum.count(assigns.object.intendedOutputs)
    tasks_completed = 
      assigns.object.intendedOutputs
      |> Enum.filter(fn x -> x.finished end)
      |> Enum.count()
    percentage = ceil(tasks_completed / tasks_total * 100)
    {:ok, socket |>
      assigns_merge(assigns,
        object: assigns.object
          |> Map.put(:percentage, percentage)
          |> Map.put(:tasks_total, tasks_total)
          |> Map.put(:tasks_completed, tasks_completed)
      )
    }
  end

end
