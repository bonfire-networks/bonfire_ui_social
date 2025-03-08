defmodule Bonfire.UI.Social.PreloadPresetTest do
  use Bonfire.UI.Social.ConnCase, async: true
  use Bonfire.Common.Utils

  import Bonfire.Common.Simulation
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

  describe "check preloaded data" do
    setup do
      account = fake_account!()
      user = fake_admin!(account, %{name: "main user", username: "main_user"})
      other_user = fake_user!("other user")
      third_user = fake_user!("third user")

      conn = conn(user: user, account: account)

      {:ok,
       conn: conn, account: account, user: user, other_user: other_user, third_user: third_user}
    end

    # Tests for different feed presets
    # for %{preset: preset, postloads: postloads} = params when preset in [:local] <-
    for %{preset: preset, postloads: postloads} = params
        when preset not in [
               :user_followers,
               :user_following,
               :user_by_object_type,
               :hashtag,
               :mentions,
               :audio,
               :videos,
               nil
             ] <-
          feed_preset_test_params() do
      test "for `/feed/#{preset}` with #{inspect(postloads)}", %{
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

        feed_path =
          if preset in [:user_activities] do
            "/@other_user"
          else
            "/feed/#{preset}"
          end

        # Verify the feed contains our test object
        if object do
          activity = e(activity, :activity, nil) || e(object, :activity, nil) || activity

          object =
            Map.put(object, :activity, activity)
            |> Activities.activity_preloads(preload: params.postloads)

          preloaded_object = object.activity.object || object

          conn =
            conn
            |> visit(feed_path)
            |> assert_path(feed_path)
            |> assert_has_or_open_browser("[data-id=activity]")
            |> assert_has_or_open_browser("[data-object_id=#{id(preloaded_object)}]")

          # Verify preloads based on the feed preset configuration
          verify_preloads_in_html(conn, params.postloads, preloaded_object, object.activity)
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
    |> verify_verb(Enum.member?(expected, :with_verb), activity)
    |> verify_object(Enum.member?(expected, :with_object), object)
    |> verify_reply_to(Enum.member?(expected, :with_reply_to), activity)
    |> verify_peered(Enum.member?(expected, :with_peered), activity, object)
    # |> verify_tags(Enum.member?(expected, :tags), object) # TODO: needs test data
    #  TODO: needs test data
    |> verify_thread_name(Enum.member?(expected, :with_thread_name), object)
    #  TODO: needs test data
    |> verify_label(Enum.member?(expected, :maybe_with_labelled), activity)
    |> verify_media(Enum.member?(expected, :with_media), activity)
    |> verify_subject(Enum.member?(expected, :with_subject), activity)
    |> verify_creator(Enum.member?(expected, :with_creator), object)
  end

  defp verify_subject(conn, expected?, activity) do
    if expected? do
      conn =
        conn
        |> assert_has_or_open_browser("[data-id=subject]")
        |> assert_has_or_open_browser("[data-id=subject_name]",
          text: activity.subject.profile.name
        )

      # Verify the link points to the correct profile path
      if username = e(activity, :subject, :character, :username, nil) do
        expected_path = "/@#{username}"

        conn
        |> assert_has_or_open_browser("a[data-id=subject_name][href='#{expected_path}']")
      end
    end ||
      conn
  end

  defp verify_creator(conn, expected?, object) do
    if expected? do
      conn =
        conn
        # Creator info is in subject component
        |> assert_has_or_open_browser("[data-id=subject_avatar]")
        |> assert_has_or_open_browser("[data-id=subject]",
          text: object.created.creator.profile.name
        )

      # Verify the avatar link points to the correct profile path
      if username = e(object, :created, :creator, :character, :username, nil) do
        expected_path = "/@#{username}"

        conn
        |> assert_has_or_open_browser("a[data-id=subject_avatar][href='#{expected_path}']")
      end
    end ||
      conn
  end

  defp verify_object(conn, expected?, object) do
    if expected? do
      if text = object.post_content.html_body do
        conn
        |> assert_has_or_open_browser("[data-id=activity_note]", text: text)
      end
    end ||
      conn
  end

  defp verify_media(conn, expected?, activity) do
    if expected? do
      if e(activity, :media, []) != [] do
        conn
        |> assert_has_or_open_browser("[data-id=multimedia_list]")
      end
    end ||
      conn
  end

  defp verify_reply_to(conn, expected?, activity) do
    if expected? do
      if text =
           e(debug(activity, "theeeeea"), :replied, :reply_to, :post_content, :html_body, nil) do
        # In the HTML, a reply typically shows a parent activity above the current activity
        debug(text, "asserting reply_to")

        conn
        |> assert_has_or_open_browser("article.replied", text: text)
      end
    end ||
      conn
  end

  defp verify_peered(conn, expected?, activity, object) do
    if expected? do
      if e(object, :peered, nil) || e(activity, :peered, nil) ||
           e(activity, :subject, :character, :peered, nil) ||
           e(activity, :created, :creator, :character, :peered, nil) do
        conn
        |> assert_has_or_open_browser("[data-id=peered]")
      end
    end ||
      conn
  end

  defp verify_tags(conn, expected?, object) do
    if expected? do
      if e(object, :post_content, :tags, nil) do
        conn
        # TODO: what to check for?
        # |> assert_has_or_open_browser("[data-tag]")
      end
    end ||
      conn
  end

  defp verify_thread_name(conn, expected?, activity) do
    if expected? do
      if title = e(activity, :replied, :thread, :named, :name, nil) do
        # Check if thread name is displayed in the HTML
        # This might be in a header or title element
        conn
        |> assert_has_or_open_browser("[data-id=title_in_subject]", title)
      end
    end ||
      conn
  end

  defp verify_label(conn, expected?, activity) do
    if expected? do
      if text = e(activity, :labelled, :post_content, :html_body, nil) do
        # Check if content label is displayed
        conn
        |> assert_has_or_open_browser("[data-id=labelled_widget]", text: text)
      end
    end ||
      conn
  end

  defp verify_verb(conn, expected?, activity) do
    if expected? do
      if verb = e(activity, :verb, nil) do
        # Check if activity verb is displayed
        # The HTML example shows this as a data-verb attribute
        conn
        |> assert_has_or_open_browser("[data-verb=#{verb}]")
      end
    end ||
      conn
  end
end
