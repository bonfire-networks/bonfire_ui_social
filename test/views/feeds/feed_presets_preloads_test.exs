defmodule Bonfire.UI.Social.PreloadPresetTest do
  use Bonfire.UI.Social.ConnCase, async: true
  use Bonfire.Common.Utils

  import Bonfire.Files.Simulation
  alias Bonfire.Files
  alias Bonfire.Files.ImageUploader

  alias Bonfire.Social.FeedActivities
  alias Bonfire.Social.FeedLoader
  alias Bonfire.Posts
  alias Bonfire.Messages
  alias Bonfire.Social.Activities
  alias Bonfire.Social.Objects

  alias Bonfire.Me.Users
  alias Bonfire.Me.Fake
  import Bonfire.Social.Fake
  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]
  import Tesla.Mock


def assert_has_or_open_browser(session, selector, opts \\ []) do 
  assert_has(session, selector, opts)
rescue
  e -> 
    PhoenixTest.open_browser(session)
    reraise e, __STACKTRACE__
end

  describe "check preloaded data" do
    setup do
      account = fake_account!()
      user = fake_user!(account, %{name: "main user", username: "main_user"})
      other_user = fake_user!("other user")
      third_user = fake_user!("third user")

      conn = conn(user: user, account: account)

      {:ok,
       conn: conn, account: account, user: user, other_user: other_user, third_user: third_user}
    end

    # Tests for different feed presets
    for %{preset: preset, filters: filters} = params when preset not in [:user_followers, :user_following, :user_by_object_type, :hashtag, :mentions, nil] <-
          feed_preset_test_params() do
      test "for `/feed/#{preset}`", %{
        conn: conn,
        account: account,
        user: user,
        other_user: other_user,
        third_user: third_user
      } do
        preset = unquote(Macro.escape(preset))
        params = unquote(Macro.escape(params))

        # Create test content based on the preset
        {object, activity} = create_test_content(preset, user, other_user)

        conn = conn(user: user, account: account)

        feed_path = "/feed/#{preset}"

        # Verify the feed contains our test object
        if object do
          conn =
            conn
            |> visit(feed_path)
            |> assert_path(feed_path)
            |> assert_has_or_open_browser("[data-id=activity]")
            |> assert_has_or_open_browser("[data-object_id=#{id(object)}]")

          preloads = params.preloads ++ params.postloads

          activity = e(activity, :activity, nil)  || e(object, :activity, nil) || activity

          object = Map.put(object, :activity, activity)
          |> Activities.activity_preloads(preload: preloads)

          # Verify preloads based on the feed preset configuration
          verify_preloads_in_html(conn, preloads, object.activity.object || object, object.activity)
        end
      end
    end

    # Test for boost visibility
    test "for boosted content: should show proper attribution", %{
      conn: conn,
      user: user,
      other_user: other_user
    } do
      # Create a post by other_user
      object = fake_post!(other_user)

      # User boosts it
      {:ok, _} = Bonfire.Social.Boosts.boost(user, object)

      # Visit user's profile feed to see the boost
      conn
      |> visit("/@#{user.character.username}")
      |> assert_has_or_open_browser("[data-role=boosted_by]")
      |> assert_has_or_open_browser("[data-verb=Boost]")
    end
  end

  # Helpers to verify different preloads in the HTML
  defp verify_preloads_in_html(conn, [], object, activity) do
    conn
  end
  defp verify_preloads_in_html(conn, expected, object, activity) do
    conn
    |> verify_subject(Enum.member?(expected, :with_subject), activity)
    |> verify_creator(Enum.member?(expected, :with_creator), object)
    |> verify_object(Enum.member?(expected, :with_object), object)
    |> verify_media(Enum.member?(expected, :with_media), activity)
    |> verify_reply_to(Enum.member?(expected, :with_reply_to), activity)
    # TODO: add verify_peered for :with_peered
    # TODO: add verify_tags for :tags
    # TODO: add verify_thread_name for :with_thread_name
    # TODO: add verify_label for :maybe_with_labelled
    # TODO: add verify_verb for :with_verb
  end

  defp verify_subject(conn, expected?, activity) do
    if expected? do
      conn
      |> assert_has_or_open_browser("[data-id=subject]")
      |> assert_has_or_open_browser("[data-id=subject_name]", text: activity.subject.profile.name)
      # TODO: verify the link matches /@username
    else
      conn
    end
  end

  defp verify_creator(conn, expected?, object) do
    if expected? do
      conn
      # Creator info is in subject component
      |> assert_has_or_open_browser("[data-id=subject_avatar]") 
      # TODO: verify the link around avatar matches /@username
      |> assert_has_or_open_browser("[data-id=subject]", text: object.created.creator.profile.name)
    else
      conn
    end
  end

  defp verify_object(conn, expected?, object) do
    if expected? do
      conn
      |> assert_has_or_open_browser("[data-id=activity_note]", text: object.post_content.html_body)
    else
      conn
    end
  end


  defp verify_media(conn, expected?, _activity) do
    if expected? do
      conn
      |> assert_has_or_open_browser("[data-id=multimedia_list]")
    else
      conn
    end
  end

  defp verify_reply_to(conn, expected?, activity) do
    if expected? do
      # In the HTML, a reply typically shows a parent activity above the current activity
      conn
      |> assert_has_or_open_browser(".replied", text: e(activity, :replied, :reply_to, :post_content, nil) )
    else
      conn
    end
  end
end
