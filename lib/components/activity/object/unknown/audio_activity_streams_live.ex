defmodule Bonfire.UI.Social.Activity.AudioActivityStreamsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # NOTE: probably not used now as they're being created as Media

  prop activity, :any, default: nil
  prop json, :any, default: nil
  prop viewing_main_object, :boolean, default: nil
  prop object_type_readable, :any, default: nil

  prop showing_within, :any, default: nil
  prop parent_id, :any, default: nil

  defp object_field(json, field) do
    e(json, "object", "audio", field, nil) || e(json, "object", field, nil) || e(json, field, nil)
  end
end
