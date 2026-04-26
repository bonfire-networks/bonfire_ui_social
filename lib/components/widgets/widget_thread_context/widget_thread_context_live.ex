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
      :topic -> "ph:hash-duotone"
      :group -> "ph:users-three-duotone"
      _ -> "ph:folder-duotone"
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

  @doc "Display name for the category, with sensible fallbacks."
  def category_name(category) do
    e(category, :profile, :name, nil) ||
      e(category, :named, :name, nil) ||
      e(category, :character, :username, nil) ||
      l("Untitled")
  end

  def members_count(category) do
    if module_enabled?(Bonfire.Classify.Categories) do
      Bonfire.Classify.Categories.members_count(category)
    end
  end
end
