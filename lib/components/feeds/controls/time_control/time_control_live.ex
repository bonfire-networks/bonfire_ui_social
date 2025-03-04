defmodule Bonfire.UI.Social.TimeControlLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop keys, :any, default: []
  prop options, :any, default: []
  prop default_value, :any, default: nil
  prop event_target, :any, default: nil
  prop scope, :any, default: nil
  prop range, :boolean, default: false

  prop name, :string, default: nil
  prop description, :string, default: nil
  prop label, :string, default: nil
  prop slider_value, :any, default: nil
  prop current_value, :any, default: :load_from_settings
  prop input, :string, default: nil

  def render(assigns) do
    assigns
    |> Bonfire.Common.Settings.LiveHandler.maybe_assign_input_value_from_keys()
    # |> debug("maybe_assign_input_value_from_keys")
    |> render_sface()
  end

  def get_index_value(nil, values), do: 0
  def get_index_value(current_value, values) do
    Enum.find_index(values, fn v -> v == current_value end) || 0
  end

  # Converts an index position to the actual value
  def get_actual_value(nil, values), do: List.first(values)
  def get_actual_value(current_value, values) do
    debug(current_value, "current_value")
    debug(values, "values")
    idx = get_index_value(current_value, values)
    Enum.at(values, idx)
  end

  def get_max_index(values) do
    Enum.count(values)
  end

  # def handle_event("map_slider_value", %{"value" => index_str, "values" => values_str}, socket) do
  #   values = String.split(values_str, ",") |> Enum.map(&String.to_integer/1)
  #   index = String.to_integer(index_str)
  #   actual_value = Enum.at(values, index)

  #   # Update the socket with the mapped value
  #   {:noreply, assign(socket, current_value: actual_value)}
  # end

  def find_index_by_value(nil, values), do: 0
def find_index_by_value(current_value, values) do
  current_value_str = to_string(current_value)

  case Enum.find_index(values, fn v -> to_string(v) == current_value_str end) do
    nil -> 0
    index -> index
  end
end

# Find a value by its index in a sorted list of values
def find_value_by_index(index, values) do
  index_int =
    case Integer.parse(to_string(index)) do
      {num, _} -> num
      :error -> 0
    end

  Enum.at(values, index_int, List.first(values))
end

end
