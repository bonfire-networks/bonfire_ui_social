defmodule Bonfire.UI.Social.FeedPubsubSubscriptionTest do
  @moduledoc "A feed that goes from one feed to another and back in the same process must hear each broadcast once, not once for every time it subscribed."
  use ExUnit.Case, async: false
  @moduletag :ui

  alias Bonfire.Common.PubSub
  alias Bonfire.UI.Social.FeedLive

  defp feed_socket(feed_ids),
    do: %Phoenix.LiveView.Socket{
      transport_pid: self(),
      assigns: %{__changed__: %{}, feed_ids: feed_ids}
    }

  test "switching feed A to B to A, it hears A once" do
    a = "feed_a_#{System.unique_integer([:positive])}"
    b = "feed_b_#{System.unique_integer([:positive])}"

    socket = feed_socket(a) |> FeedLive.maybe_subscribe()

    socket =
      %{socket | assigns: Map.put(socket.assigns, :feed_ids, b)} |> FeedLive.maybe_subscribe()

    %{socket | assigns: Map.put(socket.assigns, :feed_ids, a)} |> FeedLive.maybe_subscribe()

    :ok = PubSub.broadcast(a, {:probe, a})
    assert_receive {:probe, ^a}
    refute_receive {:probe, ^a}, 100
  end

  test "a feed made of several feeds still hears each of them, once" do
    [a, b] = for n <- 1..2, do: "feed_#{n}_#{System.unique_integer([:positive])}"

    feed_socket([a, b]) |> FeedLive.maybe_subscribe()

    for topic <- [a, b] do
      :ok = PubSub.broadcast(topic, {:probe, topic})
      assert_receive {:probe, ^topic}
      refute_receive {:probe, ^topic}, 100
    end
  end
end
