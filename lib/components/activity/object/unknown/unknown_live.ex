defmodule Bonfire.UI.Social.Activity.UnknownLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any, default: nil
  prop object_type_readable, :any, default: nil

  defp the_data(%{json: %{"object" => %{} = object}}), do: object
  defp the_data(%{json: data}), do: data
  defp the_data(%{data: %{"object" => %{} = object}}), do: object
  defp the_data(%{data: data}), do: data
  defp the_data(data), do: data
end
