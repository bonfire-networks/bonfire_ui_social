defmodule Bonfire.UI.Social.Activity.EventPreviewLive do
  @moduledoc """
  Compact event card body, rendered by `ActivityLive` via its `custom_preview`
  prop.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.EventHelpers, as: EH

  # assigns passed by ActivityLive's custom_preview render:
  prop object, :any, default: nil
  prop activity, :any, default: nil
  prop permalink, :string, default: nil
  prop date_ago, :any, default: nil
  prop reply_count, :any, default: 0
  prop activity_component_id, :string, default: nil
  prop is_remote, :boolean, default: false

  @doc "A pseudo-edge so we can reuse the `EventHelpers.event_*` display helpers."
  def edge(assigns) do
    json = e(assigns.object, :json, nil) || e(assigns.activity, :object, :json, nil) || %{}
    base = %{event_json: json, activity: assigns.activity}
    Map.put(base, :start_at, EH.event_start(base))
  end
end
