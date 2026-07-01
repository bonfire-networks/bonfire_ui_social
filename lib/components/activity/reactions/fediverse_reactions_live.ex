defmodule Bonfire.UI.Social.Activity.FediverseReactionsLive do
  @moduledoc """
  Summary of fediverse reactions to the root post of a thread.

  Currently renders reposts (boosts) as a facepile + count, with the count label
  acting as a trigger to open the full list. Likes and quotes can be added later
  as sibling rows by passing additional lists/counts in as props.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any, default: nil
  prop boosters, :list, default: []
  prop boost_count, :integer, default: 0
  prop max_avatars, :integer, default: 5
  prop parent_id, :any, default: nil
  prop reply_count, :integer, default: 0
end
