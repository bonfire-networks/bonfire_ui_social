if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.API.MastoCompatible.StatusController do
    @moduledoc """
    Mastodon-compatible status interaction endpoints.

    Implements like/unlike (favourite/unfavourite) and boost/unboost (reblog/unreblog)
    endpoints following Mastodon API conventions while using Bonfire's GraphQL backend.
    """
    use Bonfire.UI.Common.Web, :controller
    import Untangle

    alias Bonfire.Social.API.GraphQLMasto.Adapter

    @doc "Get a single status by ID"
    def show(conn, %{"id" => id} = params) do
      debug(params, "GET /api/v1/statuses/#{id}")

      %{"id" => id}
      |> then(&Adapter.show_status(&1, conn))
    end

    @doc "Get thread context (ancestors and descendants)"
    def context(conn, %{"id" => id} = params) do
      debug(params, "GET /api/v1/statuses/#{id}/context")

      %{"id" => id}
      |> then(&Adapter.status_context(&1, conn))
    end

    @doc "Get accounts who favourited a status"
    def favourited_by(conn, %{"id" => id} = params) do
      debug(params, "GET /api/v1/statuses/#{id}/favourited_by")

      params
      |> then(&Adapter.status_favourited_by(&1, conn))
    end

    @doc "Get accounts who reblogged a status"
    def reblogged_by(conn, %{"id" => id} = params) do
      debug(params, "GET /api/v1/statuses/#{id}/reblogged_by")

      params
      |> then(&Adapter.status_reblogged_by(&1, conn))
    end

    @doc "Favourite (like) a status"
    def favourite(conn, %{"id" => id} = params) do
      debug(params, "POST /api/v1/statuses/#{id}/favourite")

      %{"id" => id}
      |> then(&Adapter.like_status(&1, conn))
    end

    @doc "Unfavourite (unlike) a status"
    def unfavourite(conn, %{"id" => id} = params) do
      debug(params, "POST /api/v1/statuses/#{id}/unfavourite")

      %{"id" => id}
      |> then(&Adapter.unlike_status(&1, conn))
    end

    @doc "Reblog (boost) a status"
    def reblog(conn, %{"id" => id} = params) do
      debug(params, "POST /api/v1/statuses/#{id}/reblog")

      %{"id" => id}
      |> then(&Adapter.boost_status(&1, conn))
    end

    @doc "Unreblog (unboost) a status"
    def unreblog(conn, %{"id" => id} = params) do
      debug(params, "POST /api/v1/statuses/#{id}/unreblog")

      %{"id" => id}
      |> then(&Adapter.unboost_status(&1, conn))
    end
  end
end
