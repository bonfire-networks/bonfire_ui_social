defmodule Bonfire.UI.Social.Activity.HtmlBodyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop html_body, :any, default: nil
  prop parent_id, :any, default: nil
  prop object, :any
  prop object_type, :any, default: nil
  prop activity, :any, default: nil
  prop activity_inception, :boolean, default: false
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop is_remote, :boolean, default: false
end
