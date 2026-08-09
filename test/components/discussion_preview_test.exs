defmodule Bonfire.UI.Social.DiscussionPreviewTest do
  use ExUnit.Case, async: true

  alias Bonfire.UI.Social.Activity.DiscussionPreviewLive

  test "excerpt strips markup and normalizes whitespace" do
    object = %{
      post_content: %{
        html_body: "<p>Hello <strong>world</strong></p>\n<p>Second line</p>"
      }
    }

    assert DiscussionPreviewLive.excerpt(nil, object, false) == "Hello world Second line"
  end

  test "excerpt does not expose the body behind a content warning" do
    object = %{
      post_content: %{
        summary: "<p>Spoilers</p>",
        html_body: "<p>The hidden ending</p>"
      }
    }

    assert DiscussionPreviewLive.excerpt(nil, object, true) == "Spoilers"
    refute DiscussionPreviewLive.excerpt(nil, object, true) =~ "hidden ending"
  end

  test "excerpt skips blank summary and name values" do
    object = %{
      post_content: %{
        summary: "",
        name: "  ",
        html_body: "<p>Visible body</p>"
      }
    }

    assert DiscussionPreviewLive.excerpt(nil, object, false) == "Visible body"
  end

  test "excerpt returns nil for a content warning with a blank summary" do
    object = %{
      post_content: %{
        summary: "",
        html_body: "<p>Hidden body</p>"
      }
    }

    assert DiscussionPreviewLive.excerpt(nil, object, true) == nil
  end
end
