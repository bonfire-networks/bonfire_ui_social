defmodule Bonfire.UI.Social.LinkPreviewCardXSSTest do
  @moduledoc """
  What a link preview card shows of a remote page (its title, its description, a paper's abstract) is text from a stranger's page, kept as received: it must reach the screen without a live tag or event handler, whichever of the fields the page filled.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  use Surface.LiveViewTest
  @moduletag :ui

  alias Bonfire.UI.Social.Activity.MediaLinkLive
  alias Bonfire.UI.Social.Activity.AcademicPaperLive

  @payload "<img src=x onerror=alert(1)>"
  @script "<script>alert(1)</script>"

  defp media(path, metadata) do
    struct(
      Bonfire.Files.Media,
      id: "01HZZ0CardXSSMediaTESTX",
      path: path,
      media_type: "link",
      metadata: metadata
    )
  end

  defp live_tag?(html), do: html =~ ~r/<img src=x onerror=alert/i or html =~ ~r/<script>alert/i

  defp render_link(media) do
    assigns = %{media: media}

    render_surface do
      ~F"""
      <MediaLinkLive media={@media} media_url={@media.path} showing_within={:feed} />
      """
    end
  end

  defp render_paper(media) do
    assigns = %{media: media, metadata: media.metadata}

    render_surface do
      ~F"""
      <AcademicPaperLive media={@media} metadata={@metadata} showing_within={:feed} />
      """
    end
  end

  defp link_metadata(:oembed_title, v), do: %{"oembed" => %{"title" => v}}
  defp link_metadata(:page_title, v), do: %{"title" => v}
  defp link_metadata(:json_ld_name, v), do: %{"json_ld" => %{"name" => v}}
  defp link_metadata(:description, v), do: %{"title" => "a title", "description" => v}

  defp link_metadata(:json_ld_description, v),
    do: %{"title" => "a title", "json_ld" => %{"description" => v}}

  describe "a link card" do
    for source <- [:oembed_title, :page_title, :json_ld_name, :description, :json_ld_description] do
      test "a hostile #{source} renders without a live tag" do
        for hostile <- [@payload, @script] do
          html =
            render_link(
              media("https://remote.local/page", link_metadata(unquote(source), hostile))
            )

          refute live_tag?(html), "#{unquote(source)} #{inspect(hostile)} was rendered as HTML"
        end
      end

      test "a plain #{source} is shown (control)" do
        html =
          render_link(
            media("https://remote.local/page", link_metadata(unquote(source), "A plain text"))
          )

        assert html =~ "A plain text"
      end
    end
  end

  describe "a paper card" do
    for key <- ["citation_abstract", "abstractNote", "citation_title", "citation_journal_title"] do
      test "a hostile #{key} renders without a live tag" do
        for hostile <- [@payload, @script] do
          metadata = %{unquote(key) => hostile, "title" => "a paper"}
          html = render_paper(media("https://doi.org/10.1000/xyz", metadata))
          refute live_tag?(html), "#{unquote(key)} #{inspect(hostile)} was rendered as HTML"
        end
      end

      test "a plain #{key} is shown (control)" do
        metadata = %{unquote(key) => "A plain text", "title" => "a paper"}
        html = render_paper(media("https://doi.org/10.1000/xyz", metadata))
        assert html =~ "A plain text"
      end
    end
  end
end
