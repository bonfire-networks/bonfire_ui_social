defmodule Bonfire.UI.Social.Activity.ProcessListLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Surface.Components.LivePatch

  prop object, :any, required: true
  prop showing_within, :any
  prop process_url, :string

  def activity_component(object) do
    {__MODULE__,
     [
       object: prepare(object)
     ]}
  end

  def prepare(object) do
    tasks = e(object, :intended_outputs, [])

    tasks_total = Enum.count(tasks)

    tasks_completed =
      tasks
      |> Enum.filter(fn x -> x.finished end)
      # FIXME - get a count from DB query instead
      |> Enum.count()

    percentage = if tasks_total > 0, do: ceil(tasks_completed / tasks_total * 100)

    object
    |> Map.put(:tasks_total, tasks_total)
    |> Map.put(:tasks_completed, tasks_completed)
    |> Map.put(:percentage, percentage)
    |> debug()
  end

  def preloads(),
    do: [
      :intended_outputs,
      creator: [:character, profile: [:icon]]
    ]

  defp preload(object) do
    object
    |> repo().maybe_preload(preloads())

    # |> repo().maybe_preload([:context])
  end
end
