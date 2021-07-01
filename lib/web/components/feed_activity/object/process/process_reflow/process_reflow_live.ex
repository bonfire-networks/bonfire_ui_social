defmodule Bonfire.UI.Social.Activity.ProcessReflowLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch
  import Bonfire.UI.Social.Integration
  alias Bonfire.Social.{Likes}

  prop object, :map, required: true
  prop within_feed, :boolean, required: false, default: false

  def update(assigns, socket) do
    object = assigns.object |> preloads() |> IO.inspect(label: "process_preloaded")
    # my_like = Likes.liked?(current_user(assigns), %{id: object.id})
    # IO.inspect("my_like")
    # IO.inspect(my_like)
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

  def process_preloads(), do: [:intended_outputs]

  def preloads(object) do
    object
    |> repo().maybe_preload(process_preloads())
    |> repo().maybe_preload([:context])
  end

end
