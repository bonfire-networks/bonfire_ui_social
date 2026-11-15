defmodule Bonfire.UI.Social.WidgetsOriginTest do
  @moduledoc "The instance chooses whether content widgets show only what was posted on this instance, or content from everywhere (`[Bonfire.Social.Feeds, :widget_origin]`)."
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Social.Pins

  @limit 20

  setup do
    # creating the remote actor fetches it, as the per-user block tests mock it
    Tesla.Mock.mock(fn %{method: :get, url: url} ->
      Tesla.Mock.json(Bonfire.Federate.ActivityPub.Simulate.actor_json(url))
    end)

    admin = fake_admin!(fake_account!())
    me = fake_user!(fake_account!())
    # made before federation is turned off, which would refuse creating a remote actor
    remote = Bonfire.Social.Fake.fake_remote_user!()

    reset = fn ->
      for viewer <- [me, nil] do
        Bonfire.Social.Threads.list_trending(viewer, @limit, cache: :reset)
        Bonfire.Articles.list_recent(viewer, @limit, cache: :reset)
        Bonfire.Poll.Questions.closing_soon_widget(viewer, @limit, cache: :reset)
      end

      Pins.list_spotlight_activities(cache: :reset)
    end

    reset.()
    on_exit(reset)

    {:ok, admin: admin, me: me, remote: remote}
  end

  defp only_local!,
    do: Process.put([:bonfire_social, Bonfire.Social.Feeds, :widget_origin], :local)

  defp post!(user, text) do
    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: text}},
        boundary: "public"
      )

    post
  end

  # received from another instance, as a feed would get it, rather than published here by a remote user, which would still address this instance's local feed
  defp incoming!(remote, type, name) do
    {:ok, actor} = ActivityPub.Actor.get_cached(pointer: id(remote))
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    {:ok, activity} =
      ActivityPub.create(%{
        type: "Create",
        actor: actor,
        context: "widgets-origin",
        to: [ActivityPub.Config.public_uri()],
        local: false,
        object: %{
          "id" => "https://mocked.local/pub/" <> Needle.UID.generate(),
          "type" => type,
          "name" => name,
          "content" => "#{name}: a long-form body",
          "published" => now
        },
        additional: %{
          "id" => "https://mocked.local/pub/" <> Needle.UID.generate(),
          "published" => now
        }
      })

    {:ok, object} = Bonfire.Federate.ActivityPub.Incoming.receive_activity(activity)
    object
  end

  defp article!(user, name) do
    {:ok, article} =
      Bonfire.Posts.publish(
        current_user: user,
        schema: Bonfire.Articles.Article,
        post_attrs: %{post_content: %{name: name, html_body: "a long-form body"}},
        boundary: "public"
      )

    article
  end

  defp poll!(user, name) do
    now = DateTime.utc_now()

    {:ok, poll} =
      Bonfire.Poll.Fake.fake_question(
        %{
          post_content: %{name: name},
          voting_dates: [DateTime.add(now, -60, :second), DateTime.add(now, 3600, :second)]
        },
        current_user: user,
        boundary: "public"
      )

    poll
  end

  defp object_ids(edges),
    do:
      Enum.map(edges, &(e(&1, :activity, :object_id, nil) || id(e(&1, :activity, :object, nil))))

  test "top discussions", %{me: me, remote: remote} do
    local = post!(me, "local discussion")
    far = incoming!(remote, "Note", "remote discussion")

    # the positive first: by default both are listed
    ids = object_ids(Bonfire.Social.Threads.list_trending(me, @limit, cache: :refresh))
    assert id(local) in ids
    assert id(far) in ids

    only_local!()
    ids = object_ids(Bonfire.Social.Threads.list_trending(me, @limit, cache: :refresh))
    assert id(local) in ids
    refute id(far) in ids
  end

  test "recent articles", %{me: me, remote: remote} do
    local = article!(me, "Local article")
    far = incoming!(remote, "Article", "Remote article")

    ids = object_ids(Bonfire.Articles.list_recent(me, @limit, cache: :refresh))
    assert id(local) in ids
    assert id(far) in ids

    only_local!()
    ids = object_ids(Bonfire.Articles.list_recent(me, @limit, cache: :refresh))
    assert id(local) in ids
    refute id(far) in ids
  end

  test "polls closing soon", %{me: me, remote: remote} do
    local = poll!(me, "Local poll")
    far = poll!(remote, "Remote poll")

    ids =
      Bonfire.Poll.Questions.closing_soon_widget(me, @limit, cache: :refresh).polls
      |> Enum.map(&id/1)

    assert id(local) in ids
    assert id(far) in ids

    only_local!()

    ids =
      Bonfire.Poll.Questions.closing_soon_widget(me, @limit, cache: :refresh).polls
      |> Enum.map(&id/1)

    assert id(local) in ids
    refute id(far) in ids
  end

  test "spotlight", %{admin: admin, me: me, remote: remote} do
    local = post!(me, "local pinned")
    far = post!(remote, "remote pinned")
    Pins.pin(admin, local, :instance)
    Pins.pin(admin, far, :instance)

    ids = object_ids(Pins.list_spotlight_activities(current_user: me, cache: :refresh))
    assert id(local) in ids
    assert id(far) in ids

    only_local!()
    ids = object_ids(Pins.list_spotlight_activities(current_user: me, cache: :refresh))
    assert id(local) in ids
    refute id(far) in ids
  end
end
