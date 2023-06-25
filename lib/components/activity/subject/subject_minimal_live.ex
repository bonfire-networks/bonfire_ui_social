defmodule Bonfire.UI.Social.Activity.SubjectMinimalLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :any, default: nil
  prop object, :any
  prop profile, :any, default: nil
  prop character, :any, default: nil
  prop verb, :string
  prop verb_display, :string
  prop permalink, :string, default: nil
  prop showing_within, :atom, default: nil
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop thread_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop published_in, :any, default: nil
end
