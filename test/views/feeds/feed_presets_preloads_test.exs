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
  alias Bonfire.Social.Objects

  alias Bonfire.Me.Users
  alias Bonfire.Me.Fake
  import Bonfire.Social.Fake
  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]
  import Tesla.Mock

  # Get feed presets from config
  @feed_presets Application.compile_env(:bonfire_social, Bonfire.Social.Feeds)[:feed_presets]

  describe "check preloaded data" do
    setup do
      account = fake_account!()
      user = fake_user!(account)
      other_user = fake_user!()
      third_user = fake_user!()

      conn = conn(user: user, account: account)

      {:ok,
       conn: conn, account: account, user: user, other_user: other_user, third_user: third_user}
    end

    # Tests for different feed presets
    for {preset, preset_config} when preset not in [:user_followers, :user_following] <-
          @feed_presets do
      test "for feed preset `#{inspect(preset)}`", %{
        conn: conn,
        account: account,
        user: user,
        other_user: other_user,
        third_user: third_user
      } do
        # setup do
        preset = unquote(Macro.escape(preset))
        preset_config = unquote(Macro.escape(preset_config))

        # Create test content based on the preset
        {object, activity} = create_test_content(preset, user, other_user)

        conn = conn(user: user, account: account)

        {:ok, object: object, activity: activity, preset: preset, preset_config: preset_config}
        #   end

        feed_path = "/feed/#{preset}"

        conn =
          conn
          |> visit(feed_path)

          # Basic verification that we're on the right page
          |> assert_path(feed_path)

        # Verify the feed contains our test object
        if object do
          conn =
            conn
            |> assert_has("[data-object_id=#{id(object)}]")
            |> assert_has("[data-id=activity]")

          # Verify preloads based on the feed preset configuration
          verify_preloads_in_html(conn, preset_config.filters)
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
      |> visit("/character/#{user.character.username}")
      |> assert_has("[data-role=boosted_by]")
      |> assert_has("[data-verb=Boost]")
    end
  end

  # Helpers to verify different preloads in the HTML
  defp verify_preloads_in_html(conn, filters) do
    conn = verify_subject(conn, Enum.member?(filters[:include] || [], :with_subject))
    conn = verify_creator(conn, Enum.member?(filters[:include] || [], :with_creator))
    conn = verify_object(conn, Enum.member?(filters[:include] || [], :with_object))
    conn = verify_object_more(conn, Enum.member?(filters[:include] || [], :with_object_more))
    conn = verify_media(conn, Enum.member?(filters[:include] || [], :with_media))
    conn = verify_reply_to(conn, Enum.member?(filters[:include] || [], :with_reply_to))
    conn
  end

  defp verify_subject(conn, expected?) do
    if expected? do
      conn
      |> assert_has("[data-id=subject]")
      |> assert_has("[data-id=subject_avatar]")
      |> assert_has("[data-id=subject_name]")
    else
      conn
    end
  end

  defp verify_creator(conn, expected?) do
    if expected? do
      conn
      # Creator info is in subject component
      |> assert_has("[data-id=subject]")
    else
      conn
    end
  end

  defp verify_object(conn, expected?) do
    if expected? do
      conn
      |> assert_has("[data-id=activity_note]")
    else
      conn
    end
  end

  defp verify_object_more(conn, expected?) do
    if expected? do
      conn
      |> assert_has("[data-id=object_body]")
    else
      conn
    end
  end

  defp verify_media(conn, expected?) do
    if expected? do
      conn
      |> assert_has("[data-id=multimedia_list]")
    else
      conn
    end
  end

  defp verify_reply_to(conn, expected?) do
    if expected? do
      # In the HTML, a reply typically shows a parent activity above the current activity
      conn
      |> assert_has(".replied")
    else
      conn
    end
  end
end
