defmodule Bonfire.UI.Social.EventCategories do
  @moduledoc """
  Localised labels for the FEP-8a8e event categories. The vocabulary itself lives
  in `Bonfire.Social.Events.Categories`; icons/colours in `EventCategoryIconLive`.
  """
  use Bonfire.Common.Utils

  defdelegate all(), to: Bonfire.Social.Events.Categories

  @doc "Localised label for a category key (humanises unknown keys)."
  def label("ARTS"), do: l("Arts")
  def label("AUTO_BOAT_AIR"), do: l("Auto, Boat & Air")
  def label("BOOK_CLUBS"), do: l("Book Clubs")
  def label("BUSINESS"), do: l("Business")
  def label("CAUSES"), do: l("Causes")
  def label("CLIMATE_ENVIRONMENT"), do: l("Climate & Environment")
  def label("COMMUNITY"), do: l("Community")
  def label("COMEDY"), do: l("Comedy")
  def label("CRAFTS"), do: l("Crafts")
  def label("CREATIVE_JAM"), do: l("Creative Jam")
  def label("DIY_MAKER_SPACES"), do: l("DIY & Maker Spaces")
  def label("FAMILY_EDUCATION"), do: l("Family & Education")
  def label("FASHION_BEAUTY"), do: l("Fashion & Beauty")
  def label("FESTIVALS"), do: l("Festivals")
  def label("FILM_MEDIA"), do: l("Film & Media")
  def label("FOOD_DRINK"), do: l("Food & Drink")
  def label("GAMES"), do: l("Games")
  def label("INCLUSIVE_SPACES"), do: l("Inclusive Spaces")
  def label("LANGUAGE_CULTURE"), do: l("Language & Culture")
  def label("LEARNING"), do: l("Learning")
  def label("LGBTQ"), do: l("LGBTQ")
  def label("MEETING"), do: l("Meeting")
  def label("MEDITATION_WELLBEING"), do: l("Meditation & Wellbeing")
  def label("MOVEMENTS_POLITICS"), do: l("Movements & Politics")
  def label("MUSIC"), do: l("Music")
  def label("NETWORKING"), do: l("Networking")
  def label("OUTDOORS_ADVENTURE"), do: l("Outdoors & Adventure")
  def label("PARTY"), do: l("Party")
  def label("PERFORMING_VISUAL_ARTS"), do: l("Performing & Visual Arts")
  def label("PETS"), do: l("Pets")
  def label("PHOTOGRAPHY"), do: l("Photography")
  def label("SCIENCE_TECH"), do: l("Science & Tech")
  def label("SPIRITUALITY_RELIGION_BELIEFS"), do: l("Spirituality & Beliefs")
  def label("SPORTS"), do: l("Sports")
  def label("THEATRE"), do: l("Theatre")
  def label("WORKSHOPS_SKILL_SHARING"), do: l("Workshops & Skill-sharing")

  def label(key) when is_binary(key) do
    key |> String.downcase() |> String.split("_") |> Enum.map_join(" ", &String.capitalize/1)
  end
end
