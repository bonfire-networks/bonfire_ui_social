defmodule Bonfire.UI.Social.ProfileTimelineLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, required: true
  prop page, :string, required: true
  prop selected_tab, :string, default: "timeline"
  prop smart_input, :boolean, required: true
  prop smart_input_opts, :map, default: %{}
  prop search_placeholder, :string
  prop feed_title, :string
  prop user, :map
  prop feed, :list
  prop feed_filters, :any, default: []
  prop page_info, :any
  prop showing_within, :atom, default: nil
  prop follows_me, :boolean, default: false
  prop loading, :boolean, default: false
  prop hide_tabs, :boolean, default: false
  slot header
  slot widget
end
