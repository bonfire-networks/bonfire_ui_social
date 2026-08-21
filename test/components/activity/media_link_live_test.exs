defmodule Bonfire.UI.Social.Activity.MediaLinkLiveTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Social.Activity.MediaLinkLive
  alias Bonfire.UI.Social.Activity.MediaLive

  test "an Open Graph image duplicated as the favicon is not treated as a cover" do
    site_icon = "https://example.com/site-icon.svg"

    media =
      media(%{
        "favicon" => site_icon,
        "other" => %{"og:image" => site_icon}
      })

    assert MediaLive.preview_img(media) == nil
  end

  test "an Open Graph image different from the favicon remains a cover" do
    cover = "https://example.com/article-cover.jpg"

    media =
      media(%{
        "favicon" => "https://example.com/favicon.svg",
        "other" => %{"og:image" => cover}
      })

    assert MediaLive.preview_img(media) == cover
  end

  test "an SVG remains a cover when it is not the favicon" do
    cover = "https://example.com/article-illustration.svg"

    media =
      media(%{
        "favicon" => "https://example.com/favicon.svg",
        "other" => %{"og:image" => cover}
      })

    assert MediaLive.preview_img(media) == cover
  end

  test "favicon fallback stays compact and preserves the whole icon" do
    favicon = "https://example.com/favicon.png"

    media =
      media(%{
        "favicon" => favicon,
        "facebook" => %{"site_name" => "EXAMPLE.COM"},
        "other" => %{
          "title" => "Example article",
          "description" => "A useful description",
          "og:image" => favicon
        }
      })

    preview_img = MediaLive.preview_img(media)

    html =
      render_component(&MediaLinkLive.render/1, %{
        media: media,
        media_url: media.path,
        preview_img: preview_img,
        parent_id: "favicon-preview-test",
        __context__: %{}
      })

    assert preview_img == nil
    assert html =~ ~s(data-id="media_favicon")
    assert html =~ "w-10 h-10 shrink-0"
    assert html =~ "w-full h-full rounded-md object-contain"
    assert html =~ "text-pretty max-w-prose"
    refute html =~ "max-w-[120px] w-full h-full"
    refute html =~ "object-cover rounded-l-lg"

    {:ok, document} = Floki.parse_fragment(html)
    [identity] = Floki.find(document, ~s([data-id="media_identity"]))

    assert Floki.find(identity, ~s([data-id="media_favicon"])) != []
    assert Floki.find(identity, ~s([data-id="media_author"])) != []
  end

  defp media(metadata) do
    %Bonfire.Files.Media{
      id: "01K36J7G8R4PN6X4F9WQ2ZTCE",
      path: "https://example.com/article",
      media_type: "link",
      metadata: metadata
    }
  end
end
