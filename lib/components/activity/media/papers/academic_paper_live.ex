defmodule Bonfire.UI.Social.Activity.AcademicPaperLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil
  prop metadata, :map, default: nil
  prop showing_within, :atom, default: nil
  prop css_borders, :css_class, default: nil

  def update(_assign, socket) do
    {:noreply, socket}
  end

  def paper_type(metadata) do
    case e(metadata, "dc.type", nil) || e(metadata, "type", nil) || e(metadata, "itemType", nil) ||
           e(metadata, "citation_categories", nil) || e(metadata, "@type", nil) do
      "JournalArticle" -> l("Journal Article")
      "journalArticle" -> l("Journal Article")
      nil -> l("Article")
      "ScholarlyArticle" -> l("Scholarly Article")
      other -> other
    end
  end
end
