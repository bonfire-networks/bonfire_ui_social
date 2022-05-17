defmodule Bonfire.UI.Social.FeedViewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, required: true
  prop feed_title, :string
  prop feed, :any
  prop feed_id, :string, required: true
  prop feed_ids, :any
  prop page_info, :any
  prop showing_within, :any, default: nil
  prop verb_default, :string

  slot default
end