defmodule Bonfire.UI.Social.EventsLiveTest do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  # Insert an APActivity-backed Event into the user's :events feed.
  defp fake_event!(user, attrs) do
    start_time = attrs[:start] || DateTime.add(DateTime.utc_now(), 7, :day)

    event_object =
      %{
        "type" => "Event",
        "name" => attrs[:name],
        "content" => attrs[:content] || "Come along!",
        "startTime" => DateTime.to_iso8601(start_time)
      }
      |> put_if("endTime", attrs[:end] && DateTime.to_iso8601(attrs[:end]))
      |> put_if("category", attrs[:category])

    activity_json = %{
      "type" => "Create",
      "actor" => Bonfire.Common.URIs.canonical_url(user),
      "published" => DateTime.to_iso8601(DateTime.utc_now()),
      "to" => ["https://www.w3.org/ns/activitystreams#Public"]
    }

    {:ok, activity} =
      Bonfire.Social.APActivities.ap_receive(user, activity_json, event_object, true)

    activity
  end

  defp put_if(map, _k, nil), do: map
  defp put_if(map, k, v), do: Map.put(map, k, v)

  setup do
    account = fake_account!()
    me = fake_user!(account)
    {:ok, conn: conn(user: me, account: account), me: me, account: account}
  end

  test "renders the events page hero", %{conn: conn} do
    conn
    |> visit("/events")
    |> assert_has("h1", text: "Discover Events")
  end

  test "shows the category grid only when events have categories", %{conn: conn, me: me} do
    # no categorised events yet → grid hidden
    conn |> visit("/events") |> refute_has("h2", text: "Browse by Category")

    fake_event!(me, name: "Jazz Night", category: "MUSIC")
    conn |> visit("/events") |> assert_has("h2", text: "Browse by Category")
  end

  test "lists an upcoming event in the agenda", %{conn: conn, me: me} do
    fake_event!(me, name: "Bonfire Launch Party")

    conn
    |> visit("/events")
    |> assert_has("[role=feed]", text: "Bonfire Launch Party")
  end

  test "filtering by category narrows the agenda", %{conn: conn, me: me} do
    fake_event!(me, name: "Jazz Night", category: "MUSIC")
    fake_event!(me, name: "Gallery Opening", category: "ARTS")

    conn
    |> visit("/events")
    |> assert_has("[role=feed]", text: "Jazz Night")
    |> assert_has("[role=feed]", text: "Gallery Opening")
    |> click_button("Music")
    |> assert_has("[role=feed]", text: "Jazz Night")
    |> refute_has("[role=feed]", text: "Gallery Opening")
  end

  test "shows the empty state when there are no events", %{conn: conn} do
    conn
    |> visit("/events")
    |> assert_has("p", text: "No events found")
  end

  test "paginates: a 'Load more' control appends further pages", %{conn: conn, me: me} do
    # small page size avoids seeding 50+ events to reach a 2nd page
    Config.put([Bonfire.UI.Social.EventsLive, :per_page], 2)

    # the feed pages by ULID (federation order), so the first-federated event
    # ("Early Bird") is the one held back to page 2
    fake_event!(me, name: "Early Bird", start: DateTime.add(DateTime.utc_now(), 3, :day))
    fake_event!(me, name: "Second Event", start: DateTime.add(DateTime.utc_now(), 5, :day))
    fake_event!(me, name: "Third Event", start: DateTime.add(DateTime.utc_now(), 7, :day))

    session = conn |> visit("/events")

    session
    |> assert_has("[role=feed]", text: "Second Event")
    |> assert_has("[role=feed]", text: "Third Event")
    |> refute_has("[role=feed]", text: "Early Bird")

    session
    |> click_button("Load more")
    |> assert_has("[role=feed]", text: "Early Bird")
    |> assert_has("[role=feed]", text: "Third Event")
  end
end
