defmodule Bonfire.UI.Social.Activity.ThreadStatsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.Common.Text

  prop object, :any, default: nil
  prop activity, :any, default: nil
  prop event_target, :any, default: nil
  prop is_remote, :boolean, default: false
  prop reply_count, :any, default: nil
  prop participants, :any, default: nil
  prop participant_count, :any, default: nil
  prop thread_boost_count, :any, default: nil
  prop last_reply_id, :any, default: nil
  prop showing_within, :any, default: nil

  slot default
end
