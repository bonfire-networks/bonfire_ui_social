defmodule Bonfire.UI.Social.Activity.FediverseReactionsLive do
  @moduledoc """
  Boost, like, and quote totals in the discussion's metadata row, with people lists for reactions.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any, default: nil
  prop boost_count, :integer, default: 0
  prop like_count, :integer, default: 0
  prop quote_count, :integer, default: 0
  prop thread_id, :string, default: nil
  prop parent_id, :any, default: nil
end
