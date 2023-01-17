defmodule Bonfire.UI.Social.Activity.SubjectMinimalLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :map
  prop object, :any
  prop profile, :any, default: nil
  prop character, :any, default: nil
  prop verb, :string
  prop verb_display, :string
  prop permalink, :string, default: nil
  prop showing_within, :any
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop thread_id, :string, default: nil
end
