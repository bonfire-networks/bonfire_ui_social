defmodule Bonfire.UI.Social.EventsLiveTest do
  use Bonfire.UI.Social.ConnCase, async: false
  import Bonfire.Classify.Simulate
  @moduletag :ui

  # Insert an APActivity-backed AS2 Event into the user's :events feed.
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
      |> put_if("tag", attrs[:tag])

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

  test "renders the events page with the category filter bar", %{conn: conn} do
    conn
    |> visit("/events")
    # the always-visible category chip bar
    |> assert_has("[aria-label='Filter events by category']")
    |> assert_has("button", text: "All")
    |> assert_has("button", text: "Music")
  end

  test "lists an upcoming event in the feed", %{conn: conn, me: me} do
    fake_event!(me, name: "Bonfire Launch Party")

    conn
    |> visit("/events")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "Bonfire Launch Party")
  end

  test "filtering by category narrows the feed", %{conn: conn, me: me} do
    fake_event!(me, name: "Jazz Night", category: "MUSIC")
    fake_event!(me, name: "Gallery Opening", category: "ARTS")

    session =
      conn
      |> visit("/events")
      |> wait_async()

    # unfiltered: both events show
    session
    |> assert_has("[data-id=feed]", text: "Jazz Night")
    |> assert_has("[data-id=feed]", text: "Gallery Opening")

    # selecting Music re-scopes the feed to that category
    session
    |> click_button("button", "Music")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "Jazz Night")
    |> refute_has("[data-id=feed]", text: "Gallery Opening")
  end

  test "a category path shows the events tagged with that category", %{conn: conn, me: me} do
    topic =
      fake_category!(me, nil, %{type: :topic, name: "Jazz"})
      |> repo().maybe_preload(:character)

    iri = Bonfire.Me.Characters.character_url(topic)

    fake_event!(me,
      name: "Jazz Night",
      tag: [%{"type" => "Category", "id" => iri, "name" => "Jazz"}]
    )

    fake_event!(me, name: "Gallery Opening")

    conn
    |> visit("/events/category/#{topic.character.username}")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "Jazz Night")
    |> refute_has("[data-id=feed]", text: "Gallery Opening")
  end

  test "a category path takes the id of a category that has no character", %{
    conn: conn,
    me: me
  } do
    topic = fake_category!(me, nil, %{type: :topic, name: "Poetry", without_character: true})

    # a category with no character has no AP IRI to name it by, so it is tagged directly
    tagged = fake_event!(me, name: "Poetry Slam")
    fake_event!(me, name: "Gallery Opening")
    assert {:ok, _} = Bonfire.Tag.maybe_tag(me, tagged, [topic])

    conn
    |> visit("/events/category/#{topic.id}")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "Poetry Slam")
    |> refute_has("[data-id=feed]", text: "Gallery Opening")
  end

  test "a category path that names no category shows an error and no events", %{
    conn: conn,
    me: me
  } do
    # an event exists, so that no events shown is the feed being withheld and not an empty database
    fake_event!(me, name: "Gallery Opening")

    conn
    |> visit("/events/category/no_such_category")
    |> wait_async()
    |> assert_has("[data-id=flash_error]")
    |> refute_has("[data-id=feed]", text: "Gallery Opening")
  end

  test "shows an empty feed when there are no events", %{conn: conn} do
    conn
    |> visit("/events")
    |> wait_async()
    |> assert_has("[data-id=feed]")
    |> refute_has("[data-id=feed] article[data-id=activity]")
  end
end
