defmodule Bonfire.UI.Social.Activity.FediverseReactionsLive do
  @moduledoc """
  Reply and boost counts for the root post of a thread.

  Rendered inside `Bonfire.UI.Social.Activity.ThreadStatsLive`, sharing the one
  metadata row with the thread layout/sort controls. Likes and quotes can be
  added later as sibling counts by passing them in as props.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any, default: nil
  prop boost_count, :integer, default: 0
  prop parent_id, :any, default: nil
  prop reply_count, :integer, default: 0
end
