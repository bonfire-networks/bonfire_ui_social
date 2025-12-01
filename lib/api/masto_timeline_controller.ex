if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.API.MastoCompatible.TimelineController do
    @moduledoc """
    Mastodon-compatible timeline endpoints.

    Implements timeline retrieval with proper pagination support following
    Mastodon API conventions while using Bonfire's GraphQL backend.
    """
    use Bonfire.UI.Common.Web, :controller

    alias Bonfire.Social.API.GraphQLMasto.Adapter
    alias Bonfire.Boundaries.API.GraphQLMasto.Adapter, as: BoundariesAdapter
    alias Bonfire.API.MastoCompat.{PaginationHelpers, Helpers}

    @doc "Home timeline for authenticated user"
    def home(conn, params) do
      params
      |> PaginationHelpers.build_feed_params(%{"feed_name" => "my"})
      |> then(&Adapter.feed(&1, conn))
    end

    @doc "Public/federated timeline with optional local filter"
    def public(conn, params) do
      # Mastodon API convention: ?local=true for local-only, otherwise federated
      feed_name = if params["local"] == "true", do: "local", else: "explore"

      params
      |> PaginationHelpers.build_feed_params(%{"feed_name" => feed_name})
      |> then(&Adapter.feed(&1, conn))
    end

    @doc "Local timeline - shows only local instance activities"
    def local(conn, params) do
      params
      |> PaginationHelpers.build_feed_params(%{"feed_name" => "local"})
      |> then(&Adapter.feed(&1, conn))
    end

    @doc "Hashtag timeline - shows posts with specific hashtag"
    def hashtag(conn, %{"hashtag" => hashtag} = params) do
      # Mastodon API convention: ?local=true for local-only, otherwise federated
      feed_name = if params["local"] == "true", do: "local", else: "explore"

      # Normalize hashtag (remove # if present, lowercase)
      normalized_tag = Helpers.normalize_hashtag(hashtag)

      params
      |> PaginationHelpers.build_feed_params(%{
        "feed_name" => feed_name,
        "tags" => [normalized_tag]
      })
      |> then(&Adapter.feed(&1, conn))
    end

    @doc "Named timeline (public, local, etc.)"
    def timeline(conn, %{"feed" => feed} = params) do
      params
      |> PaginationHelpers.build_feed_params(%{"feed_name" => feed})
      |> then(&Adapter.feed(&1, conn))
    end

    @doc "List timeline - shows posts from accounts in a list"
    def list_timeline(conn, %{"list_id" => list_id} = params) do
      # Lists are implemented as Circles in Bonfire, handled by Boundaries adapter
      BoundariesAdapter.list_timeline(list_id, params, conn)
    end

    @doc "Single notification by ID"
    def notification(conn, %{"id" => id}) do
      Adapter.notification(id, conn)
    end

    @doc "Clear all notifications"
    def clear_notifications(conn, _params) do
      Adapter.clear_notifications(conn)
    end

    @doc "Dismiss a single notification"
    def dismiss_notification(conn, %{"id" => id}) do
      Adapter.dismiss_notification(id, conn)
    end

    @doc "Notifications timeline"
    def notifications(conn, params) do
      # Build filter for notifications feed
      # Note: Mastodon clients may send exclude_types and types parameters
      # but we'll start with a simple implementation and enhance later
      params
      |> PaginationHelpers.build_feed_params(%{
        "feed_name" => "notifications",
        # Explicitly request subject preload since notifications need the account who triggered them
        # This is needed because the :notifications preload preset is not defined
        "preload" => ["with_subject"]
      })
      |> then(&Adapter.notifications(&1, conn))
    end

    @doc "Bookmarks timeline - shows posts bookmarked by authenticated user"
    def bookmarks(conn, params) do
      params
      |> PaginationHelpers.build_feed_params(%{"feed_name" => "bookmarks"})
      |> then(&Adapter.feed(&1, conn))
    end

    @doc "Favourites timeline - shows posts favourited/liked by authenticated user"
    def favourites(conn, params) do
      params
      |> PaginationHelpers.build_feed_params(%{})
      |> then(&Adapter.favourites(&1, conn))
    end

    @doc "User's statuses timeline"
    def user_statuses(conn, %{"id" => user_id} = params) do
      # TODO: Implement actual pinned post functionality
      # For now, we ignore the pinned parameter and return all posts

      filter =
        params
        |> Map.take(["feed_name", "feed_ids", "creators", "objects", "tags"])
        |> Map.put("subjects", [user_id])

      params
      |> PaginationHelpers.build_feed_params(filter)
      |> then(&Adapter.feed(&1, conn))
    end
  end
end
