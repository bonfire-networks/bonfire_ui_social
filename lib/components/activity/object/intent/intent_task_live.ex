defmodule Bonfire.UI.Social.Activity.IntentTaskLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Surface.Components.LivePatch

  prop object, :map, required: true
  prop showing_within, :atom, default: nil

  def preloads(),
    do: [
      :output_of,
      creator: [:character, profile: [:icon]],
      provider: [:character, profile: [:icon]]
    ]

  defp preload(object) do
    object
    |> repo().maybe_preload(preloads())
    |> repo().maybe_preload([:context])
  end
end
