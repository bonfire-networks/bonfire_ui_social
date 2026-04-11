defmodule Bonfire.UI.Social.Activity.DiscussionPreviewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop permalink, :string, default: nil
  prop reply_count, :any, default: 0
  prop date_ago, :any, default: nil
  prop object, :any, default: nil
  prop activity, :any, default: nil
  prop activity_component_id, :string, default: nil
  prop is_remote, :boolean, default: false
end
