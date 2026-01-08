# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Social.TopLevelMediaLive do
  @moduledoc """
  Renders a trending link card with metadata, sharers, and boost counts.

  Used by both the TrendingLinks widget and the trending links feed page.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.URIs
  alias Bonfire.UI.Social.Activity.MediaLive

  prop link, :map, required: true
  prop class, :css_class, default: nil
  prop show_thumbnail, :boolean, default: false
  prop featured, :boolean, default: false
  prop in_widget, :boolean, default: false
end
