defmodule Bonfire.UI.Social.Activity.SubjectListModalLive do
  @moduledoc """
  Modal listing all the users (subjects) involved in a grouped activity
  such as "X, Y and N others liked/reacted/boosted".
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, required: true
  prop verb, :string, default: nil
  prop main_profile_id, :any, default: nil
  prop main_profile_name, :string, default: nil
  prop main_character_username, :string, default: nil
  prop main_profile_media, :any, default: nil
  prop subjects_more, :list, default: []
  prop trigger_text, :string, required: true
  prop trigger_class, :css_class, default: "link link-hover font-bold"
  prop parent_id, :any, default: nil

  def title_for_verb("React"), do: l("Reacted by")
  def title_for_verb("Boost"), do: l("Boosted by")
  def title_for_verb(_), do: l("Liked by")
end
