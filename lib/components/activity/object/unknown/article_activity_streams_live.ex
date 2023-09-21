defmodule Bonfire.UI.Social.Activity.ArticleActivityStreamsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :any, default: nil
  prop json, :any, default: nil
  prop viewing_main_object, :boolean, default: nil
  prop object_type_readable, :any, default: nil

  defp object_field(json, field) do
    e(json, "object", "audio", field, nil) || e(json, "object", field, nil) || e(json, field, nil)
  end
end
