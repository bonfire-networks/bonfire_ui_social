defmodule Bonfire.UI.Social.Activity.TruncatableContentLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop html_body, :string, required: true
  prop activity, :any, default: nil
  prop object, :any, required: true
  prop parent_id, :any, required: true
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_inception, :boolean, default: false
  prop object_type, :atom, default: nil
end