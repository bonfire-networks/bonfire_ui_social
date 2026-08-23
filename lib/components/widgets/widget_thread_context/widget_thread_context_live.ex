defmodule Bonfire.UI.Social.WidgetThreadContextLive do
  @moduledoc """
  Sidebar widget shown on a discussion view when the post was published within
  a group, topic, or other category. Gives the reader immediate context about
  where the conversation is happening.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop category, :any, required: true

  @doc "Iconify name keyed off category type."
  def icon(category) do
    case e(category, :type, nil) do
      :topic -> "ph:hash-fill"
      :group -> "ph:users-three-fill"
      _ -> "ph:folder-fill"
    end
  end

  @doc "Eyebrow label naming the kind of container the thread lives in."
  def eyebrow(category) do
    case e(category, :type, nil) do
      :topic -> l("Posted in topic")
      :group -> l("Posted in group")
      _ -> l("Posted in")
    end
  end

  @doc "Display name for the category — delegates to `Bonfire.UI.Social.Activity.PublishedInLive.context_label/1` so the sidebar and the feed's \"Posted in\" chip can't resolve the same category differently."
  def category_name(category) do
    Bonfire.UI.Social.Activity.PublishedInLive.context_label(category) || l("Untitled")
  end

  def members_count(category) do
    if module_enabled?(Bonfire.Classify.Categories) do
      Bonfire.Classify.Categories.members_count(category)
    end
  end
end
