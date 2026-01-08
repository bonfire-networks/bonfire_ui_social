# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Social.TrendingMediaActionsLive do
  @moduledoc """
  Renders a trending link card with metadata, sharers, and boost counts.

  Used by both the TrendingLinks widget and the trending links feed page.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.URIs
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, required: true

  # TODO: put somewhere reusable
  def to_int(val) do
    cond do
      is_nil(val) -> 0
      is_integer(val) -> val
      is_float(val) -> round(val)
      match?(%Decimal{}, val) -> Decimal.to_integer(val)
      true -> 0
    end
  end
end
