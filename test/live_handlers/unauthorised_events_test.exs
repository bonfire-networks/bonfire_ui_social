defmodule Bonfire.UI.Social.UnauthorisedEventsTest do
  @moduledoc """
  Events sent straight to a LiveHandler, by a visitor with no session (`/LiveHandler/<Module>/<event>`) or by a signed-in user over their own socket, can't change what the sender may not change. The buttons that send them are hidden from the sender, but the handler is what has to refuse.
  """
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Posts

  @moduletag :ui
  @moduletag capture_log: true

  setup do
    Process.put([:bonfire, :skip_all_boundary_checks], false)

    owner = fake_user!("events_owner")
    account = fake_account!()
    stranger = fake_user!(account)

    {:ok, post} =
      Posts.publish(
        current_user: owner,
        post_attrs: %{post_content: %{html_body: "Someone's public post"}},
        boundary: "public"
      )

    activity_id = id(e(post, :activity, nil))
    assert activity_id

    {:ok,
     owner: owner, account: account, stranger: stranger, post: post, activity_id: activity_id}
  end

  defp activity_exists?(activity_id),
    do: not is_nil(Bonfire.Common.Repo.get(Bonfire.Data.Social.Activity, activity_id))

  defp name_of(id),
    do: e(Bonfire.Common.Repo.get(Bonfire.Data.Identity.Named, id), :name, nil)

  describe "Bonfire.Social.Feeds:delete" do
    test "a visitor with no session can't delete someone's activity", %{activity_id: activity_id} do
      assert activity_exists?(activity_id)

      get(build_conn(), "/LiveHandler/Bonfire.Social.Feeds/delete?id=#{activity_id}")

      assert activity_exists?(activity_id),
             "a guest deleted someone else's activity"
    end

    test "a signed-in user can't delete someone else's activity", %{
      account: account,
      stranger: stranger,
      activity_id: activity_id
    } do
      assert activity_exists?(activity_id)

      {:ok, view, _html} = live(conn(user: stranger, account: account), "/feed/local")

      render_hook(view, "Bonfire.Social.Feeds:delete", %{"id" => activity_id})

      assert activity_exists?(activity_id),
             "an unrelated user deleted someone else's activity"
    end
  end

  describe "Bonfire.Social.Objects:set_name" do
    test "a user who can only read a post can't rename its thread", %{
      owner: owner,
      account: account,
      stranger: stranger,
      post: post
    } do
      assert {:ok, _} =
               Bonfire.Social.Objects.set_name(post.id, "Original name", current_user: owner)

      assert name_of(post.id) == "Original name"
      assert {:ok, _} = Posts.read(post.id, current_user: stranger)

      {:ok, view, _html} = live(conn(user: stranger, account: account), "/post/#{post.id}")

      render_hook(view, "Bonfire.Social.Objects:set_name", %{
        "thread_id" => post.id,
        "name" => "Renamed by a stranger"
      })

      assert name_of(post.id) == "Original name",
             "a reader renamed a thread they can't edit"
    end

    test "an author can set the title of their own post through the event", %{post: post} do
      owner_account = fake_account!()
      owner = fake_user!(owner_account)

      {:ok, own_post} =
        Posts.publish(
          current_user: owner,
          post_attrs: %{post_content: %{html_body: "My own post"}},
          boundary: "public"
        )

      {:ok, view, _html} =
        live(conn(user: owner, account: owner_account), "/post/#{own_post.id}")

      render_hook(view, "Bonfire.Social.Objects:set_name", %{
        "thread_id" => own_post.id,
        "name" => "Owner's title"
      })

      assert name_of(own_post.id) == "Owner's title"
      refute name_of(post.id) == "Owner's title"
    end

    test "someone permitted to :describe but not :edit can set the title through the event", %{
      owner: owner,
      post: post
    } do
      describer_account = fake_account!()
      describer = fake_user!(describer_account)

      {:ok, acl} =
        Bonfire.Boundaries.Acls.get_or_create_object_custom_acl(post, current_user: owner)

      assert [_ | _] =
               Bonfire.Boundaries.Grants.grant(
                 describer.id,
                 acl.id,
                 [:see, :read, :describe],
                 true,
                 current_user: owner
               )

      assert Bonfire.Boundaries.can?(describer, :describe, post)
      refute Bonfire.Boundaries.can?(describer, :edit, post)

      {:ok, view, _html} =
        live(conn(user: describer, account: describer_account), "/post/#{post.id}")

      render_hook(view, "Bonfire.Social.Objects:set_name", %{
        "thread_id" => post.id,
        "name" => "Titled by a describer"
      })

      assert name_of(post.id) == "Titled by a describer"
    end
  end

  # a component's socket carries the activity it renders, so the event is sent straight to the handler with one, as the component would
  describe "Bonfire.Social.Feeds:publish" do
    test "a user can't put someone else's activity into another user's notifications feed", %{
      account: account,
      stranger: stranger,
      post: post
    } do
      victim = fake_user!(fake_account!())
      victim_feed_id = Bonfire.Social.Feeds.feed_id(:notifications, victim)
      assert victim_feed_id

      activity = Bonfire.Common.Repo.preload(post.activity, :verb)

      in_victims_feed? = fn ->
        not is_nil(
          Bonfire.Common.Repo.get_by(Bonfire.Data.Social.FeedPublish,
            feed_id: victim_feed_id,
            id: activity.id
          )
        )
      end

      refute in_victims_feed?.()

      socket = %Phoenix.LiveView.Socket{
        endpoint: @endpoint,
        private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}},
        assigns: %{
          __changed__: %{},
          flash: %{},
          __context__: %{
            current_account_id: account.id,
            current_user_id: stranger.id,
            current_user: stranger
          },
          current_account_id: account.id,
          current_user_id: stranger.id,
          current_user: stranger,
          activity: activity,
          object: post
        }
      }

      Bonfire.Social.Feeds.LiveHandler.handle_event(
        "publish",
        %{"to" => [victim_feed_id]},
        socket
      )

      refute in_victims_feed?.(),
             "a user put someone else's activity into another user's notifications feed"
    end
  end
end
