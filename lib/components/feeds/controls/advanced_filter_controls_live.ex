defmodule Bonfire.UI.Social.AdvancedFilterControlsLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop feed_filters, :any, default: nil
  prop event_target, :any, required: true
  prop show_circles_button, :boolean, default: true
  prop show_sort_dropdown, :boolean, default: true
  prop circles_button_action, :string, default: nil

  def update(assigns, socket) do
    preset_info = get_preset_origin_info(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(preset_info)}
  end

  defp get_preset_origin_info(assigns) do
    feed_name = e(assigns, :feed_filters, :feed_name, nil)

    case Bonfire.Social.Feeds.feed_preset_if_permitted(feed_name, context: assigns[:__context__]) do
      {:ok, %{filters: %{origin: preset_origin}}} when not is_nil(preset_origin) ->
        %{
          preset_has_fixed_origin: true,
          preset_origin: preset_origin
        }

      _ ->
        %{
          preset_has_fixed_origin: false,
          preset_origin: nil
        }
    end
  end
end
