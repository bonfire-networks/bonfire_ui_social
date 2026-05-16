defmodule Bonfire.UI.Social.PostContentSEOTest do
  use ExUnit.Case, async: true

  alias Bonfire.UI.Social.PostContentSEO

  describe "title/2" do
    test "uses the post title when present" do
      assert PostContentSEO.title(%{title: "Hello world"}, "alice") == "Hello world"
    end

    test "falls back to the thread name" do
      post = %{title: nil, activity: %{replied: %{thread: %{named: %{name: "A thread"}}}}}
      assert PostContentSEO.title(post, "alice") == "A thread"
    end

    test "falls back to `Post by {author}` for a plain post" do
      assert PostContentSEO.title(%{title: nil}, "alice") =~ "alice"
    end
  end

  describe "description/1" do
    test "uses the summary when present" do
      assert PostContentSEO.description(%{summary: "A short summary"}) == "A short summary"
    end

    test "falls back to a plain-text excerpt of the body" do
      desc = PostContentSEO.description(%{summary: nil, html_body: "<p>Hello <b>there</b></p>"})
      assert desc == "Hello there"
    end

    test "returns nil when there is nothing to describe" do
      assert PostContentSEO.description(%{summary: nil, html_body: nil}) == nil
    end
  end

  describe "SEOImage.absolute_url/1" do
    alias Bonfire.UI.Common.SEOImage

    test "keeps absolute URLs unchanged" do
      assert SEOImage.absolute_url("https://example.com/a.png") ==
               "https://example.com/a.png"
    end

    test "returns nil for falsey input" do
      assert SEOImage.absolute_url(nil) == nil
      assert SEOImage.absolute_url(false) == nil
    end

    test "prefixes the instance base URL for relative paths" do
      url = SEOImage.absolute_url("data/uploads/x.png")
      assert String.starts_with?(url, "http")
      assert String.ends_with?(url, "/data/uploads/x.png")
    end
  end
end
