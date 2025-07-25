defmodule Bonfire.UI.Social.ProfileTimelineLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.FeedController

  # prop page_title, :string, required: true
  # prop page, :string, required: true
  prop selected_tab, :any, default: :timeline
  # prop smart_input, :boolean, required: true
  # prop smart_input_opts, :map, default: %{}
  # prop search_placeholder, :string
  prop feed_title, :string, default: nil
  prop feed_name, :any, default: nil
  prop feed_id, :any, default: nil
  prop user, :map, default: %{}
  prop feed, :list, default: nil
  prop feed_filters, :any, default: nil
  prop page_info, :any, default: nil
  prop permalink, :string, default: nil
  prop showing_within, :atom, default: nil
  # prop follows_me, :atom, default: false
  prop loading, :boolean, default: false
  prop hide_filters, :boolean, default: false
  prop feed_component_id, :any, default: nil

  slot header
  slot widget
end
