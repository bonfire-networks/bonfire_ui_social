defmodule Bonfire.UI.Social.EditPostLive do
  use Bonfire.UI.Common.Web, :stateless_component

  slot default

  prop object, :any, default: nil
  prop object_boundary, :any, default: nil

  prop parent_id, :string, default: nil
  prop activity_component_id, :string, default: nil

  def diff(previous_version, current_version) do
    # KinoDiff.new(previous_version, current_version, layout: :inline)
    Exdiff.diff(previous_version, current_version, wrapper_tag: "span")
    |> Map.get(:html)
  end
end