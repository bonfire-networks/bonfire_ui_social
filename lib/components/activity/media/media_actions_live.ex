# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Social.MediaActionsLive do
  @moduledoc """
  What a media row of a feed (one per `Bonfire.Files.Media`) says about its use: how many posts use it, linking to the newest of them, then its replies, boosts and likes when there are any.

  Each number comes with the row: the per-media feed query always selects `object_count` and `newest_activity_id`, and the reply, boost and like counts only when the feed sorts by them (see `Bonfire.Social.Media.build_media_aggregated_query/3`), so a feed that doesn't (eg. `local_media`) shows only the count, with no extra query.

  Used by the media tile (`Bonfire.UI.Social.Activity.MediaTileLive`), the link card (`Bonfire.UI.Social.TopLevelMediaLive`) and the trending links widget.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.URIs

  prop media, :map, required: true

  @doc "One of the row's counts as an integer, 0 when the feed didn't select it (a SUM comes back from Postgres as a `Decimal`)."
  def count(media, key), do: Bonfire.Common.Types.maybe_to_integer(e(media, key, nil), 0)
end
