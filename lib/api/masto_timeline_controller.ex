if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.API.MastoCompatible.TimelineController do
    @moduledoc """
    Mastodon-compatible timeline endpoints.

    Implements timeline retrieval with proper pagination support following
    Mastodon API conventions while using Bonfire's GraphQL backend.
    """
    use Bonfire.UI.Common.Web, :controller

    alias Bonfire.Social.API.GraphQLMasto.Adapter

    # Mastodon API timeline limits
    @default_limit 20
    @max_limit 40
    @min_limit 1

    @doc "Home timeline for authenticated user"
    def home(conn, params) do
      params
      |> build_feed_params(%{"feed_name" => "my"})
      |> then(&Adapter.feed(&1, conn))
    end

    @doc "Public/federated timeline with optional local filter"
    def public(conn, params) do
      # Mastodon API convention: ?local=true for local-only, otherwise federated
      feed_name = if params["local"] == "true", do: "local", else: "explore"

      params
      |> build_feed_params(%{"feed_name" => feed_name})
      |> then(&Adapter.feed(&1, conn))
    end

    @doc "Named timeline (public, local, etc.)"
    def timeline(conn, %{"feed" => feed} = params) do
      params
      |> build_feed_params(%{"feed_name" => feed})
      |> then(&Adapter.feed(&1, conn))
    end

    @doc "Notifications timeline"
    def notifications(conn, params) do
      # Build filter for notifications feed
      # Note: Mastodon clients may send exclude_types and types parameters
      # but we'll start with a simple implementation and enhance later
      filter = %{"feed_name" => "notifications"}

      params
      |> build_feed_params(filter)
      |> then(&Adapter.notifications(&1, conn))
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
      |> build_feed_params(filter)
      |> then(&Adapter.feed(&1, conn))
    end

    # Private helpers

    defp build_feed_params(params, filter) do
      # Merge pagination params into the filter
      filter_with_pagination =
        filter
        |> Map.merge(extract_id_filters(params))
        # Disable Bonfire's default 1-month time limit for Mastodon API
        |> Map.put("time_limit", 0)

      %{"filter" => filter_with_pagination}
      |> Map.merge(extract_limit(params))
    end

    defp extract_id_filters(params) do
      # Map Mastodon pagination IDs to filter fields
      # max_id → id_before (get older posts)
      # since_id/min_id → id_after (get newer posts, min_id takes precedence)
      result =
        params
        |> Map.take(["max_id", "since_id", "min_id"])
        |> Enum.reduce(%{}, fn
          {"max_id", id}, acc when is_binary(id) and id != "" ->
            debug(id, "max_id parameter")
            Map.put(acc, "id_before", id)

          {"min_id", id}, acc when is_binary(id) and id != "" ->
            debug(id, "min_id parameter")
            # min_id takes precedence over since_id
            Map.put(acc, "id_after", id)

          {"since_id", id}, acc when is_binary(id) and id != "" ->
            debug(id, "since_id parameter")
            # Only use since_id if min_id not already set
            if Map.has_key?(acc, "id_after"), do: acc, else: Map.put(acc, "id_after", id)

          _, acc ->
            acc
        end)

      debug(result, "extracted ID filters")
      result
    end

    defp extract_limit(params) do
      # Extract and validate limit parameter
      case params["limit"] do
        nil -> %{"first" => @default_limit}
        limit -> %{"first" => validate_limit(limit)}
      end
    end

    defp validate_limit(limit) when is_binary(limit) do
      case Integer.parse(limit) do
        {n, ""} -> validate_limit(n)
        _ -> @default_limit
      end
    end

    defp validate_limit(limit) when is_integer(limit) do
      cond do
        limit < @min_limit -> @min_limit
        limit > @max_limit -> @max_limit
        true -> limit
      end
    end

    defp validate_limit(_), do: @default_limit
  end
end
