defmodule Bonfire.UI.Social.ExportTest do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  import Bonfire.Common.Simulation
  import Bonfire.Files.Simulation
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Social.Import

  setup do
    account = fake_account!()

    %{user: me, upload: profile_media, path: path, url: url} =
      fake_user_with_avatar!()

    conn = conn(user: me, account: account)

    # Create test data for all export types
    # Users for follow relationships
    followee1 = fake_user!("Followee1")
    followee2 = fake_user!("Followee2")
    follower = fake_user!("Follower")
    request_user = fake_user!("RequestUser", %{}, request_before_follow: true)
    other_user = fake_user!("OtherUser")
    silenced_user = fake_user!("SilencedUser")
    ghosted_user = fake_user!("GhostedUser")

    # Create follows
    assert {:ok, _follow1} = Follows.follow(me, followee1)
    assert {:ok, _follow2} = Follows.follow(me, followee2)
    assert {:ok, _follow3} = Follows.follow(follower, me)
    assert {:ok, _request} = Follows.follow(me, request_user)

    assert {:ok, attachment_media} = fake_upload(icon_file(), nil, me)

    # Create posts (one with attachment)
    assert {:ok, post1} =
             Bonfire.Posts.publish(
               current_user: me,
               boundary: "public",
               post_attrs: %{post_content: %{html_body: "Test post 1 content"}}
             )

    assert {:ok, post2} =
             Bonfire.Posts.publish(
               current_user: me,
               boundary: "public",
               post_attrs: %{
                 post_content: %{html_body: "Test post 2 content"}
               },
               uploaded_files: [attachment_media]
             )

    # Create messages
    assert {:ok, message1} =
             Bonfire.Messages.send(me, %{post_content: %{html_body: "Hello message 1"}}, [
               other_user
             ])

    assert {:ok, message2} =
             Bonfire.Messages.send(other_user, %{post_content: %{html_body: "Hello message 2"}}, [
               me
             ])

    # Create blocks
    assert {:ok, _} = Bonfire.Boundaries.Blocks.block(silenced_user, :silence, current_user: me)
    assert {:ok, _} = Bonfire.Boundaries.Blocks.block(ghosted_user, :ghost, current_user: me)

    # Create bookmarks
    assert {:ok, _bookmark1} = Bonfire.Social.Bookmarks.bookmark(me, post1)
    assert {:ok, _bookmark2} = Bonfire.Social.Bookmarks.bookmark(me, post2)

    # Create circles and add members
    {:ok, circle1} = Bonfire.Boundaries.Circles.create(me, "Friends")
    {:ok, circle2} = Bonfire.Boundaries.Circles.create(me, "Work")

    assert {:ok, _} = Bonfire.Boundaries.Circles.add_to_circles(followee1, circle1)
    assert {:ok, _} = Bonfire.Boundaries.Circles.add_to_circles(followee2, circle1)
    assert {:ok, _} = Bonfire.Boundaries.Circles.add_to_circles(other_user, circle2)

    {:ok,
     conn: conn,
     account: account,
     user: me,
     followee1: followee1,
     followee2: followee2,
     follower: follower,
     other_user: other_user,
     silenced_user: silenced_user,
     ghosted_user: ghosted_user,
     request_user: request_user,
     profile_media: profile_media,
     attachment_media: attachment_media,
     post1: post1,
     post2: post2,
     circle1: circle1,
     circle2: circle2}
  end

  test "export following works", %{
    user: user,
    conn: conn,
    followee1: followee1,
    followee2: followee2
  } do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/following")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

    # Use shared verification
    verify_following_csv(conn.resp_body, [followee1, followee2])
  end

  test "export followers works", %{user: user, conn: conn, follower: follower} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/followers")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

    # Use shared verification
    verify_followers_csv(conn.resp_body, [follower])
  end

  test "export follow requests works", %{user: user, conn: conn, request_user: request_user} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/requests")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

    # Use shared verification
    verify_requests_csv(conn.resp_body, [request_user])
  end

  test "export posts works", %{user: user, conn: conn} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/posts")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

    # Use shared verification
    verify_posts_csv(conn.resp_body, ["Test post 1 content", "Test post 2 content"])
  end

  test "export messages works", %{user: user, conn: conn, other_user: other_user} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/messages")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

    # Use shared verification
    verify_messages_csv(conn.resp_body, [user, other_user], ["Hello message 1", "Hello message 2"])
  end

  test "export silenced works", %{user: user, conn: conn, silenced_user: silenced_user} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/silenced")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

    # Use shared verification
    verify_silenced_csv(conn.resp_body, [silenced_user])
  end

  test "export ghosted works", %{user: user, conn: conn, ghosted_user: ghosted_user} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/ghosted")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

    # Use shared verification
    verify_ghosted_csv(conn.resp_body, [ghosted_user])
  end

  test "export profile JSON works", %{user: user, conn: conn} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/json/actor")

    assert conn.status == 200
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")

    # Use shared verification
    verify_actor_json(conn.resp_body, user)
  end

  test "export keys works", %{user: user, conn: conn} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/binary/keys/asc")

    assert conn.status == 200

    # Use shared verification
    verify_keys_content(conn.resp_body)
  end

  test "export outbox JSON works", %{user: user, conn: conn} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/json/outbox")

    assert conn.status == 200
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")

    # Use shared verification
    verify_outbox_json(conn.resp_body, ["Test post 1 content"])
  end

  describe "zip archive" do
    test "archive export creates a valid zip file", %{conn: conn, user: user} do
      conn = conn |> assign(:current_user, user)

      conn = get(conn, "/settings/export/archive")

      assert conn.status == 200
      assert ["application/zip" <> _] = get_resp_header(conn, "content-type")

      assert get_resp_header(conn, "content-disposition") == [
               "attachment; filename=\"bonfire_export_archive.zip\""
             ]

      # Check that we get chunked response
      assert conn.state == :chunked
    end

    test "archive async lifecycle - create, check, download, delete", %{
      conn: conn,
      user: user,
      followee1: followee1,
      followee2: followee2,
      follower: follower,
      request_user: request_user,
      silenced_user: silenced_user,
      ghosted_user: ghosted_user,
      other_user: other_user,
      profile_media: profile_media,
      attachment_media: attachment_media,
      post1: post1,
      post2: post2,
      circle1: circle1,
      circle2: circle2
    } do
      user_id = id(user)

      # Initially should return false when no archive exists
      assert Bonfire.UI.Social.ExportController.archive_previous_date(user_id) == false

      # Create archive async
      context = %{current_user: user}

      assert {:ok, pid} =
               Bonfire.UI.Social.ExportController.trigger_prepare_archive_async(context)

      # Wait for the async task to complete by checking file existence with retries
      # 10 attempts with 500ms each = 5 seconds max
      wait_for_archive(user_id, 10)

      # Check that archive file exists
      assert Bonfire.UI.Social.ExportController.archive_exists?(user_id)

      # Should return number of days (should be 0 for just created)
      days_old = Bonfire.UI.Social.ExportController.archive_previous_date(user_id)
      assert is_integer(days_old)
      assert days_old >= 0

      # Test downloading the created archive
      conn = conn |> assign(:current_user, user)
      conn = get(conn, "/settings/export/archive_download")

      assert conn.status == 200
      assert ["application/zip" <> _] = get_resp_header(conn, "content-type")

      # Verify the zip contains expected files by checking file size
      # A proper archive with our test data should be at least a few KB
      assert byte_size(conn.resp_body) > 1000, "Archive should contain substantial data"

      # Verify individual files presence and contents using stream
      verify_zip_contents(conn.resp_body, %{
        followees: [followee1],
        followers: [follower],
        requests: [request_user],
        silenced: [silenced_user],
        ghosted: [ghosted_user],
        users: [user, other_user],
        post_contents: ["Test post 1 content", "Test post 2 content"],
        message_contents: ["Hello message 1", "Hello message 2"],
        bookmarks: [post1, post2],
        circles: [{circle1, [followee1, followee2]}, {circle2, [other_user]}],
        user: user,
        media_files: [profile_media, attachment_media]
      })

      # Cleanup - delete the archive
      Bonfire.UI.Social.ExportController.archive_delete(user_id)

      # Verify it's deleted
      refute Bonfire.UI.Social.ExportController.archive_exists?(user_id)
    end
  end

  # Helper function to wait for archive creation
  defp wait_for_archive(user_id, attempts_left) when attempts_left > 0 do
    if Bonfire.UI.Social.ExportController.archive_exists?(user_id) do
      :ok
    else
      Process.sleep(500)
      wait_for_archive(user_id, attempts_left - 1)
    end
  end

  defp wait_for_archive(_user_id, 0) do
    flunk("Archive was not created within the expected time")
  end

  # Shared verification functions
  defp verify_following_csv(content, expected_users) do
    assert String.contains?(content, "Account address")

    for user <- expected_users do
      username = Bonfire.Me.Characters.display_username(user, true)
      assert String.contains?(content, username)
    end
  end

  defp verify_followers_csv(content, expected_users) do
    assert String.contains?(content, "Account address")

    for user <- expected_users do
      username = Bonfire.Me.Characters.display_username(user, true)
      assert String.contains?(content, username)
    end
  end

  defp verify_requests_csv(content, expected_users) do
    assert String.contains?(content, "Account address")

    for user <- expected_users do
      username = Bonfire.Me.Characters.display_username(user, true)
      assert String.contains?(content, username)
    end
  end

  defp verify_posts_csv(content, expected_contents) do
    assert String.contains?(content, "ID")
    assert String.contains?(content, "Date")
    assert String.contains?(content, "Text")

    for content_text <- expected_contents do
      assert String.contains?(content, content_text)
    end
  end

  defp verify_messages_csv(content, expected_users, expected_contents) do
    assert String.contains?(content, "ID")
    assert String.contains?(content, "From")
    assert String.contains?(content, "To")

    for content_text <- expected_contents do
      assert String.contains?(content, content_text)
    end

    for user <- expected_users do
      username = e(user, :character, :username, nil)
      assert String.contains?(content, username)
    end
  end

  defp verify_silenced_csv(content, expected_users) do
    assert String.contains?(content, "Account address")

    for user <- expected_users do
      username = Bonfire.Me.Characters.display_username(user, true)
      assert String.contains?(content, username)
    end
  end

  defp verify_ghosted_csv(content, expected_users) do
    assert String.contains?(content, "Account address")

    for user <- expected_users do
      username = Bonfire.Me.Characters.display_username(user, true)
      assert String.contains?(content, username)
    end
  end

  defp verify_actor_json(content, user) do
    assert {:ok, decoded} = Jason.decode(content)
    assert Map.has_key?(decoded, "type")
    assert Map.has_key?(decoded, "id")
    assert Map.has_key?(decoded, "preferredUsername")
    assert decoded["preferredUsername"] == e(user, :character, :username, nil)
  end

  defp verify_keys_content(content) do
    assert is_binary(content)
    assert String.contains?(content, "BEGIN")
    assert String.contains?(content, "END")
    assert String.length(content) > 100
  end

  defp verify_outbox_json(content, expected_contents) do
    for content_text <- expected_contents do
      assert String.contains?(content, content_text)
    end

    assert {:ok, decoded} = Jason.decode(content)
    assert Map.has_key?(decoded, "type")
    assert decoded["type"] == "OrderedCollection"
    assert Map.has_key?(decoded, "orderedItems")
    assert is_list(decoded["orderedItems"])

    # Should contain the post (as ActivityPub Create activity)
    activities = decoded["orderedItems"]
    assert length(activities) > 0
    debug(activities, "json activities")

    # FIXME: we're getting objects instead of activities
    # check we have a Create activity that contains our post content
    assert create_activity =
             Enum.find(activities, fn item ->
               is_map(item) and
                 item["type"] == "Create" and
                 is_map(item["object"]) and
                 String.contains?(
                   to_string(item["object"]["content"] || ""),
                   "Test post 1 content"
                 )
             end)

    # FIXME: we're getting repeats?
    # assert length(activities) == 1
  end

  # Stream-based zip verification using Erlang's :zip module
  defp verify_zip_contents(zip_binary, expected_data) do
    expected_files = [
      "actor.json",
      "following.csv",
      "followers.csv",
      "requests.csv",
      "posts.csv",
      "messages.csv",
      "bookmarks.csv",
      "circles.csv",
      "silenced.csv",
      "ghosted.csv",
      "keys.asc",
      "outbox.json"
    ]

    case :zip.extract(zip_binary, [:memory]) do
      {:ok, files} ->
        # Convert to map for easy lookup
        file_contents =
          Enum.into(files, %{}, fn {filename, content} ->
            {to_string(filename), content}
          end)
          |> Map.new()

        # debug(Map.keys(file_contents), "files in zip")

        # Verify media files are included
        if expected_data[:media_files] do
          for media <- expected_data[:media_files] do
            debug(media, "che3ck media")

            found_media =
              Enum.any?(file_contents, fn {filename, _content} ->
                media.path =~ filename
              end)

            assert found_media, "Archive should contain media file for #{inspect(media)}"
          end
        end

        # Verify all expected files are present, and file contents using our shared verification functions
        for file <- expected_files do
          assert Map.has_key?(file_contents, file), "Archive should contain #{file}"
          verify_file_content(file, file_contents[file], expected_data)
        end

      {:error, reason} ->
        flunk("Failed to extract zip: #{inspect(reason)}")
    end
  end

  # Helper to verify file content as it streams
  defp verify_file_content("following.csv", data, %{followees: followees}) do
    verify_following_csv(data, followees)
  end

  defp verify_file_content("followers.csv", data, %{followers: followers}) do
    verify_followers_csv(data, followers)
  end

  defp verify_file_content("requests.csv", data, %{requests: requests}) do
    verify_requests_csv(data, requests)
  end

  defp verify_file_content("posts.csv", data, %{post_contents: contents}) do
    verify_posts_csv(data, contents)
  end

  defp verify_file_content("messages.csv", data, %{users: users, message_contents: contents}) do
    verify_messages_csv(data, users, contents)
  end

  defp verify_file_content("silenced.csv", data, %{silenced: silenced}) do
    verify_silenced_csv(data, silenced)
  end

  defp verify_file_content("ghosted.csv", data, %{ghosted: ghosted}) do
    verify_ghosted_csv(data, ghosted)
  end

  defp verify_file_content("actor.json", data, %{user: user}) do
    verify_actor_json(data, user)
  end

  defp verify_file_content("outbox.json", data, %{post_contents: contents}) do
    verify_outbox_json(data, contents)
  end

  defp verify_file_content("keys.asc", data, _expected) do
    verify_keys_content(data)
  end

  defp verify_file_content("bookmarks.csv", data, %{bookmarks: bookmarks}) do
    verify_bookmarks_csv(data, bookmarks)
  end

  defp verify_file_content("circles.csv", data, %{circles: circles}) do
    verify_circles_csv(data, circles)
  end

  defp verify_file_content(_file, _data, _expected) do
    # Ignore other files
    :ok
  end

  # Add verification functions for bookmarks and circles
  defp verify_bookmarks_csv(content, expected_bookmarks) do
    # Bookmarks CSV has no headers, just URLs
    for bookmark <- expected_bookmarks do
      bookmark_url = URIs.canonical_url(bookmark)
      assert String.contains?(content, bookmark_url)
    end
  end

  defp verify_circles_csv(content, expected_circles) do
    # Circles CSV has no headers, format: circle_name,username
    for {circle, members} <- expected_circles do
      circle_name = e(circle, :named, :name, nil)

      for member <- members do
        username = Bonfire.Me.Characters.display_username(member, true)
        assert String.contains?(content, "#{circle_name},#{username}")
      end
    end
  end
end
