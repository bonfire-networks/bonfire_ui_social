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
      |> build_feed_params(%{
        "feed_name" => "my",
        # Preload associations to ensure user data (character, peered) is loaded
        "preload" => ["with_subject", "with_creator", "with_media"],
        # Ensure current user's data loads properly (needed for user profiles in timeline)
        "skip_current_user_preload" => false
      })
      |> then(&Adapter.feed(&1, conn))
    end

    @doc "Public/federated timeline with optional local filter"
    def public(conn, params) do
      # Mastodon API convention: ?local=true for local-only, otherwise federated
      feed_name = if params["local"] == "true", do: "local", else: "explore"

      params
      |> build_feed_params(%{
        "feed_name" => feed_name,
        # Preload associations to ensure user data (character, peered) is loaded
        "preload" => ["with_subject", "with_creator", "with_media"],
        # Ensure current user's data loads properly (needed for user profiles in timeline)
        "skip_current_user_preload" => false
      })
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
      filter = %{
        "feed_name" => "notifications",
        # Preload associations to avoid N+1 queries in GraphQL resolution
        "preload" => ["with_subject", "with_creator", "with_media"],
        # CRITICAL: Don't skip loading current user's data in notifications
        # The current user is often the subject of notification actions (likes, boosts, etc.)
        # Without this, their account data won't load properly in the Mastodon API
        "skip_current_user_preload" => false
      }

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
      # Build filter without pagination cursors (cursors are top-level GraphQL args, not filters)
      filter_without_pagination =
        filter
        # Disable Bonfire's default 1-month time limit for Mastodon API
        |> Map.put("time_limit", 0)

      # Extract pagination cursors first to determine direction
      cursors = extract_pagination_cursors(params)

      # Atomize pagination keys because pagination_args_filter expects atom keys
      %{"filter" => filter_without_pagination}
      # Merge cursors at top level
      |> Map.merge(cursors)
      # Pass cursors to determine first vs last
      |> Map.merge(extract_limit(params, cursors))
      |> atomize_pagination_keys()
    end

    # Convert pagination param keys from strings to atoms
    # pagination_args_filter in Pagination module expects atom keys
    defp atomize_pagination_keys(params) do
      params
      |> Enum.map(fn
        {"after", val} -> {:after, val}
        {"before", val} -> {:before, val}
        {"first", val} -> {:first, val}
        {"last", val} -> {:last, val}
        # Keep other keys as-is
        {key, val} -> {key, val}
      end)
      |> Enum.into(%{})
    end

    defp extract_pagination_cursors(params) do
      # Map Mastodon pagination IDs to Relay cursor params
      # With descending sort (newest first):
      # - max_id → after (items AFTER cursor in list = older/lower IDs)
      # - since_id/min_id → before (items BEFORE cursor in list = newer/higher IDs)
      # Encode cursors as base64 for GraphQL (will be decoded in resolver)
      params
      |> Map.take(["max_id", "since_id", "min_id"])
      |> Enum.reduce(%{}, fn
        {"max_id", id}, acc when is_binary(id) and id != "" ->
          # max_id: get older posts (items after cursor in descending list)
          case encode_cursor_for_graphql(id) do
            {:ok, cursor} -> Map.put(acc, "after", cursor)
            {:error, _reason} -> acc
          end

        {"min_id", id}, acc when is_binary(id) and id != "" ->
          # min_id: get newer posts (items before cursor in descending list)
          # min_id takes precedence over since_id
          case encode_cursor_for_graphql(id) do
            {:ok, cursor} -> Map.put(acc, "before", cursor)
            {:error, _reason} -> acc
          end

        {"since_id", id}, acc when is_binary(id) and id != "" ->
          # since_id: get newer posts (items before cursor in descending list)
          # Only use since_id if min_id not already set
          if Map.has_key?(acc, "before") do
            acc
          else
            case encode_cursor_for_graphql(id) do
              {:ok, cursor} -> Map.put(acc, "before", cursor)
              {:error, _reason} -> acc
            end
          end

        _, acc ->
          acc
      end)
    end

    # Prepare cursor for Paginator with validation
    # - If already base64 encoded (from our Link headers), validate and pass through
    # - If plain ID (ULID), create proper cursor map and encode it
    #   (Bonfire uses tuple-based cursor_fields: {{:activity, :id}, :desc})
    # Returns {:ok, cursor} or {:error, reason}
    defp encode_cursor_for_graphql(id) when is_binary(id) do
      # Check if already base64 encoded (starts with "g3" from Erlang term format)
      if String.match?(id, ~r/^g3[A-Za-z0-9_-]+=*$/) do
        # Already encoded - validate it can be decoded
        validate_encoded_cursor(id)
      else
        # Plain ID - create cursor map matching Bonfire's cursor_fields format
        # cursor_fields: [{{:activity, :id}, :desc}]
        # cursor must be: %{{:activity, :id} => id}
        encode_plain_id_cursor(id)
      end
    end

    defp encode_cursor_for_graphql(_), do: {:error, :invalid_cursor_format}

    # Validate that an already-encoded cursor can be decoded properly
    defp validate_encoded_cursor(cursor) do
      case Base.url_decode64(cursor) do
        {:ok, binary} ->
          # Try to decode the Erlang term to ensure it's valid
          try do
            _term = :erlang.binary_to_term(binary, [:safe])
            {:ok, cursor}
          rescue
            ArgumentError -> {:error, :invalid_erlang_term}
          end

        :error ->
          {:error, :invalid_base64}
      end
    end

    # Encode a plain ULID as a cursor
    defp encode_plain_id_cursor(id) do
      try do
        cursor =
          %{{:activity, :id} => id}
          |> :erlang.term_to_binary()
          |> Base.url_encode64()

        {:ok, cursor}
      rescue
        e ->
          require Logger
          Logger.warning("Failed to encode cursor for ID #{inspect(id)}: #{inspect(e)}")
          {:error, :cursor_encoding_failed}
      end
    end

    defp extract_limit(params, cursors) do
      # Extract and validate limit parameter
      # Relay pagination: "first" with "after", "last" with "before"
      # With our descending sort:
      # - "after" + "first" = older posts (max_id)
      # - "before" + "last" = newer posts (min_id/since_id)
      limit =
        case params["limit"] do
          nil -> @default_limit
          limit -> validate_limit(limit)
        end

      cond do
        Map.has_key?(cursors, "after") ->
          # Forward through descending list (older posts) - use "first"
          %{"first" => limit}

        Map.has_key?(cursors, "before") ->
          # Backward through descending list (newer posts) - use "last"
          %{"last" => limit}

        true ->
          # No cursor (initial page) - use "first" (start from newest)
          %{"first" => limit}
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
