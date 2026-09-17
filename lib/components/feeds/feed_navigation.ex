defmodule Bonfire.UI.Social.FeedNavigation do
  @moduledoc "Feed choices, labels, and paths shared by sidebar navigation and settings."

  @doc "Lists permitted built-in and custom feeds that can be opened without additional parameters."
  def list_presets(opts) do
    Bonfire.Social.Feeds.feed_presets_permitted(opts)
    |> Enum.filter(fn {_slug, preset} ->
      preset[:parameterized] in [nil, %{subjects: [:me]}]
    end)
  end

  @doc """
  Resolves a saved default against available presets, falling back when it is no longer available.

  ## Examples

      iex> Bonfire.UI.Social.FeedNavigation.resolve_default([my: %{}, custom: %{}], "custom")
      :custom

      iex> Bonfire.UI.Social.FeedNavigation.resolve_default([my: %{}], "deleted")
      :my

      iex> Bonfire.UI.Social.FeedNavigation.resolve_default([local: %{}], :my)
      :local

      iex> Bonfire.UI.Social.FeedNavigation.resolve_default([], :my)
      nil
  """
  def resolve_default(presets, preferred) do
    slugs = Enum.map(presets, fn {slug, _preset} -> slug end)

    Enum.find(slugs, &(to_string(&1) == to_string(preferred))) ||
      Enum.find(slugs, &(to_string(&1) == "my")) ||
      Enum.find(slugs, &(to_string(&1) == "local")) || List.first(slugs)
  end

  @doc """
  Builds a feed URL, encoding custom names as a single path segment.

      iex> Bonfire.UI.Social.FeedNavigation.build_path("My feed")
      "/feed/My%20feed"

      iex> Bonfire.UI.Social.FeedNavigation.build_path(nil)
      "/feed"
  """
  def build_path(nil), do: "/feed"

  def build_path(slug) do
    encoded = slug |> to_string() |> URI.encode(&URI.char_unreserved?/1)
    "/feed/#{encoded}"
  end

  @doc """
  Resolves a feed label consistently for navigation and settings.

      iex> Bonfire.UI.Social.FeedNavigation.get_name(%{name: "Following"}, :my)
      "Following"

      iex> Bonfire.UI.Social.FeedNavigation.get_name(%{description: "Saved feed"}, :custom)
      "Saved feed"

      iex> Bonfire.UI.Social.FeedNavigation.get_name(%{}, :custom)
      "custom"
  """
  def get_name(preset, slug), do: preset[:name] || preset[:description] || to_string(slug)
end
