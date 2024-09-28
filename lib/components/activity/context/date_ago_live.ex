defmodule Bonfire.UI.Social.Activity.DateAgoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop date_ago, :any, default: nil
  prop object_id, :any, default: nil
  prop activity_id, :any, default: nil
  prop parent_id, :any, default: nil
end
