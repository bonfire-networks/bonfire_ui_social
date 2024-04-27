if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.API.MastoCompatible.TimelineController do
    use Bonfire.UI.Common.Web, :controller

    alias Bonfire.Social.API.GraphQLMasto.Adapter
    alias Bonfire.API.GraphQL.RestAdapter

    def home(conn, _params), do: Adapter.feed(%{"filter" => %{"feed_name" => "my"}}, conn)

    def timeline(conn, %{"feed" => feed} = _params),
      do: Adapter.feed(%{"filter" => %{"feed_name" => feed}}, conn)
  end
end
