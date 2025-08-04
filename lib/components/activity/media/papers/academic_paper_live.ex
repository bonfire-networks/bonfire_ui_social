defmodule Bonfire.UI.Social.Activity.AcademicPaperLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil
  prop metadata, :map, default: nil
  prop showing_within, :atom, default: nil
  prop css_borders, :css_class, default: nil
  prop parent_id, :any, default: nil

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

  def extract_doi_from_orcid(metadata) when is_map(metadata) do
    metadata
    |> e("external-ids", "external-id", [])
    |> List.wrap()
    |> Enum.find_value(&extract_doi_from_external_id/1)
  end

  def extract_doi_from_orcid(_), do: nil

  defp extract_doi_from_external_id(%{"external-id-type" => "doi"} = ext_id) do
    # Prefer the DOI URL if available, otherwise use the DOI value
    e(ext_id, "external-id-url", "value", nil) || e(ext_id, "external-id-value", nil)
  end

  defp extract_doi_from_external_id(_), do: nil

  def is_orcid_work_url?(url) when is_binary(url) do
    String.contains?(url, "orcid.org/") and String.contains?(url, "/work/")
  end

  def is_orcid_work_url?(_), do: false

  def format_doi_url(doi_value) when is_binary(doi_value) do
    if String.starts_with?(doi_value, "http") do
      doi_value
    else
      "https://doi.org/#{doi_value}"
    end
  end

  def format_doi_url(_), do: nil
end
