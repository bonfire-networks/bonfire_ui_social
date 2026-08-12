defmodule Bonfire.UI.Social.Activity.DiscussionPreviewActionsLive do
  @moduledoc """
  Compact actions footer for discussion previews: a reply counter plus a
  facepile of other conversation participants. Passed by the trending
  discussions widget to `ActivityLive`'s `custom_actions` prop, replacing the
  standard `ActionsLive` (so the like/boost buttons and their preloads are
  skipped entirely).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :any, default: nil
  prop object, :any, default: nil
  prop permalink, :string, default: nil
  prop reply_count, :any, default: 0
  prop participants, :list, default: []
  prop participants_more_count, :integer, default: 0
  prop activity_component_id, :string, default: nil
  prop showing_within, :atom, default: nil

  @doc "Returns the root thread reply count when present, otherwise the prepared activity count."
  def display_reply_count(activity, fallback_count) do
    if e(activity, :replied, :thread, :post_content, nil) do
      e(activity, :replied, :thread, :replied, :nested_replies_count, 0) +
        e(activity, :replied, :thread, :replied, :direct_replies_count, 0)
    else
      e(fallback_count, 0)
    end
  end
end
