defmodule Bonfire.UI.Social.Activity.EventActivityStreamsLiveTest do
  @moduledoc "The AS2 accessors of the fallback event card (moved with their tests from `Bonfire.Social.Events`)."
  use ExUnit.Case, async: true
  @moduletag :backend

  alias Bonfire.UI.Social.Activity.EventActivityStreamsLive, as: Card

  doctest Bonfire.UI.Social.Activity.EventActivityStreamsLive, import: true

  describe "source_url/1" do
    test "prefers the human-readable url over the AP id" do
      assert Card.source_url(%{
               "id" => "https://gancio.cisti.org/federation/m/42",
               "url" => "https://gancio.cisti.org/event/42"
             }) == "https://gancio.cisti.org/event/42"
    end

    test "falls back to the id when there is no url" do
      assert Card.source_url(%{"id" => "https://gancio.cisti.org/event/42"}) ==
               "https://gancio.cisti.org/event/42"
    end

    test "unwraps a Link object" do
      assert Card.source_url(%{
               "id" => "https://example.org/o/1",
               "url" => %{"type" => "Link", "href" => "https://example.org/event/1"}
             }) == "https://example.org/event/1"
    end

    test "takes the first usable entry of a url list" do
      assert Card.source_url(%{
               "id" => "https://example.org/o/1",
               "url" => [
                 %{"type" => "Link", "mediaType" => "text/html"},
                 %{"type" => "Link", "href" => "https://example.org/event/1"}
               ]
             }) == "https://example.org/event/1"
    end

    test "reads through the nested object shape" do
      assert Card.source_url(%{
               "object" => %{
                 "id" => "https://example.org/o/1",
                 "url" => "https://example.org/e/1"
               }
             }) == "https://example.org/e/1"
    end

    test "is nil when there is neither url nor id" do
      assert Card.source_url(%{"name" => "no links here"}) == nil
      assert Card.source_url(nil) == nil
    end
  end
end
