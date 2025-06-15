defmodule Bonfire.UI.Social.TimeControlLive do
  use Bonfire.UI.Common.Web, :stateless_component

  @default_options [
    {1, l("Day")},
    {7, l("Week")},
    {30, l("Month")},
    {365, "Year"},
    {0, "All time"}
  ]
  prop keys, :any, default: []
  prop options, :any, default: @default_options
  prop default_value, :any, default: nil
  prop event_target, :any, default: nil
  prop scope, :any, default: nil
  prop range, :boolean, default: false

  prop name, :string, default: nil
  prop input, :string, default: "time_limit_idx"
  prop description, :string, default: nil
  prop label, :string, default: nil
  prop slider_value, :any, default: nil
  prop current_value, :any, default: :load_from_settings

  # def render(assigns) do
  #   assigns
  #   |> Bonfire.Common.Settings.LiveHandler.maybe_assign_input_value_from_keys()
  #   # |> debug("maybe_assign_input_value_from_keys")
  #   |> render_sface()
  # end

  # Find a value by its index in a sorted list of values
  def find_value_by_index(range_index, options \\ @default_options) do
    # Get tuple at index or first tuple if index is out of bounds
    {value, _label} = Enum.at(options, Types.maybe_to_integer(range_index)) || List.first(options)
    value
  end

  def get_index_value(nil, _values), do: 0

  def get_index_value(current_value, values) do
    values
    |> Enum.find_index(fn {value, _label} -> value == current_value end) || 0
  end

  # def handle_event("map_slider_value", %{"value" => index_str, "values" => values_str}, socket) do
  #   values = String.split(values_str, ",") |> Enum.map(&String.to_integer/1)
  #   index = String.to_integer(index_str)
  #   actual_value = Enum.at(values, index)

  #   # Update the socket with the mapped value
  #   {:noreply, assign(socket, current_value: actual_value)}
  # end
end
