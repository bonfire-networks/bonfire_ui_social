defmodule Bonfire.UI.Social.ToggleTypeLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # default: :activity_types
  prop field, :atom, required: true
  prop key, :any
  prop label, :string, default: nil
  # prop disabled, :boolean, default: false
  # prop scope, :any, default: nil

  prop label_default, :string, default: nil
  prop event_name, :string, default: "set_filter"
  prop event_target, :any, default: nil

  prop feed_filters, :any, default: nil

  @doc """
  Checks if a value is allowed based on inclusion/exclusion lists.

  Returns:
    - true: value is in include but not in exclude
    - false: value is not in include but in exclude
    - nil: value is in neither list or in both lists
  """
  def check_throuple(value, include, exclude) when is_list(include) or is_list(exclude) do
    # Convert to MapSets only once
    check_throuple(value, MapSet.new(include), MapSet.new(exclude))
  end

  def check_throuple(value, include, exclude) do
    value_str = to_string(value)

    case {MapSet.member?(include, value) || MapSet.member?(include, value_str),
          MapSet.member?(exclude, value) || MapSet.member?(exclude, value_str)} do
      {true, false} -> true
      {false, true} -> false
      _ -> nil
    end
  end
end
