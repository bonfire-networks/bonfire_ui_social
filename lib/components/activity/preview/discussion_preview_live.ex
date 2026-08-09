defmodule Bonfire.UI.Social.Activity.DiscussionPreviewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop permalink, :string, default: nil
  prop reply_count, :any, default: 0
  prop date_ago, :any, default: nil
  prop object, :any, default: nil
  prop activity, :any, default: nil
  prop activity_component_id, :string, default: nil
  prop participants, :list, default: []
  prop participants_more_count, :integer, default: 0
  prop rank, :integer, default: nil
  prop cw, :any, default: false

  @doc "Returns the thread root when an activity carries one, otherwise its displayed object."
  def display_object(activity, object) do
    e(activity, :replied, :thread, :post_content, nil)
    |> then(fn
      nil -> object
      _post_content -> e(activity, :replied, :thread, nil)
    end)
  end

  @doc "Returns the author shown in the compact discussion preview."
  def creator(activity, object) do
    display_object(activity, object)
    |> e(:created, :creator, nil)
    |> then(&(&1 || e(activity, :subject, nil)))
  end

  @doc "Returns the best available display name for the discussion author."
  def creator_name(activity, object) do
    creator = creator(activity, object)

    e(creator, :profile, :name, nil) ||
      e(creator, :character, :username, nil)
  end

  @doc "Returns a plain-text, whitespace-normalized preview without exposing hidden CW content."
  def excerpt(activity, object, content_warning?) do
    post_content = e(display_object(activity, object), :post_content, nil)
    summary = e(post_content, :summary, nil)

    candidates =
      if content_warning? do
        [summary]
      else
        [summary, e(post_content, :name, nil), e(post_content, :html_body, nil)]
      end

    Enum.find_value(candidates, fn candidate ->
      candidate
      |> Bonfire.Common.Text.text_only()
      |> Bonfire.Common.Text.normalize_whitespace()
      |> then(fn
        "" -> nil
        text -> text
      end)
    end)
  end

  @doc "Returns the root thread reply count when present, otherwise the prepared activity count."
  def display_reply_count(activity, fallback_count) do
    if e(activity, :replied, :thread, :post_content, nil) do
      e(activity, :replied, :thread, :replied, :nested_replies_count, 0) +
        e(activity, :replied, :thread, :replied, :direct_replies_count, 0)
    else
      e(fallback_count, 0)
    end
  end
end
