defmodule Bonfire.UI.Social.Activity.BookActivityStreamsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop json, :any, default: nil
  # prop object_type, :any, default: nil
  prop object_type_readable, :any, default: nil

  defp object_field(json, field) do
    e(json, "object", field, nil) || e(json, field, nil)
  end
end
