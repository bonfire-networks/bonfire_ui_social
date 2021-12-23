defmodule Bonfire.UI.Social.Activity.IntentTaskLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch


  prop object, :map, required: true


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
