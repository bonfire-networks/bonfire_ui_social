defmodule Bonfire.UI.Social.Activity.NoSubjectLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Social.Feeds.LiveHandler

  prop activity_id, :any, default: nil
  prop object_id, :any, default: nil
  prop peered, :any, default: nil
  # prop profile, :any, default: nil
  # prop character, :any, default: nil
  # prop verb, :string, default: nil
  # prop verb_display, :string, default: nil
  prop permalink, :string, default: nil
  prop showing_within, :atom, default: nil
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop thread_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop published_in, :any, default: nil
  prop parent_id, :any, default: nil
end
