defmodule Bonfire.UI.Social.Activity.IntentTaskLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Surface.Components.LivePatch

  prop object, :map, required: true
  prop activity, :any, default: nil
  prop object_type, :any, required: true
  prop permalink, :string, required: true
  prop activity_component_id, :string, default: nil
  prop reply_count, :any, default: nil

  prop showing_within, :atom, default: nil
  prop hide_reply, :boolean, default: false
  prop thread_mode, :any, default: nil
  prop object_boundary, :any, default: nil
  prop object_type_readable, :any, default: nil
  prop viewing_main_object, :boolean, default: false

  def preloads(),
    do: [
      :output_of,
      creator: [:character, profile: [:icon]],
      provider: [:character, profile: [:icon]]
    ]

  # defp preload(object) do
  #   object
  #   |> repo().maybe_preload(preloads())
  #   |> repo().maybe_preload([:context])
  # end
end
