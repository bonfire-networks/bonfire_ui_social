defmodule Bonfire.UI.Social.Feeds.Benchmark.Test do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  @tag :benchmark
  test "feed_queries" do
    Bonfire.UI.Social.Benchmark.feed_queries()
  end

  @tag :benchmark
  test "feed_page" do
    Bonfire.UI.Social.Benchmark.feed_page()
  end
end
