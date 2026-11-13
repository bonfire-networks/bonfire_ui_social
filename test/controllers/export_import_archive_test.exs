defmodule Bonfire.UI.Social.ExportImportArchiveTest do
  @moduledoc """
  A person moves to another account with the archive Bonfire exports for them: everything they had (follows, circles, likes, bookmarks, boosts, ghosts, silences and their posts with pictures) comes back in the account that imports it. The zip is always one made by the export feature, never one built by hand.
  """
  # async: false: the HTTP mock is global, and the export preloads race under the concurrent ui battery (see export_test.exs)
  use Bonfire.UI.Social.ConnCase, async: false

  import Tesla.Mock
  import Bonfire.Files.Simulation

  alias Bonfire.Social.Import
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Boundaries.Blocks
  alias Bonfire.Boundaries.Circles
  alias Bonfire.UI.Social.ExportController

  @moduletag :backend

  # anything not in the library's fixtures is a 404, so nothing reaches a real server
  setup do
    Process.put(:federating, true)
    mock_global(&ActivityPub.Fixtures.request/1)

    %{user: a} = fake_user_with_avatar!()
    followee = fake_user!("Followee")
    remote = Bonfire.Social.Fake.fake_remote_user!()
    member = fake_user!("CircleMember")
    other = fake_user!("Other")
    ghosted = fake_user!("Ghosted")
    silenced = fake_user!("Silenced")

    assert {:ok, _} = Follows.follow(a, followee)
    assert {:ok, _} = Follows.follow(a, remote)

    {:ok, circle} = Circles.create(a, "Archive friends")
    assert {:ok, _} = Circles.add_to_circles(member, circle)

    assert {:ok, other_post} =
             Bonfire.Posts.publish(
               current_user: other,
               boundary: "public",
               post_attrs: %{post_content: %{html_body: "someone else's post"}}
             )

    assert {:ok, _} = Bonfire.Social.Likes.like(a, other_post)
    assert {:ok, _} = Bonfire.Social.Bookmarks.bookmark(a, other_post)
    assert {:ok, _} = Bonfire.Social.Boosts.boost(a, other_post)
    assert {:ok, _} = Blocks.block(ghosted, :ghost, current_user: a)
    assert {:ok, _} = Blocks.block(silenced, :silence, current_user: a)

    assert {:ok, media} = fake_upload(icon_file(), nil, a)

    assert {:ok, own_post} =
             Bonfire.Posts.publish(
               current_user: a,
               boundary: "public",
               post_attrs: %{post_content: %{html_body: "my post with a picture"}},
               uploaded_media: [media]
             )

    zip = export_zip!(a)
    on_exit(fn -> File.rm(zip) end)

    {:ok,
     zip: zip,
     followee: followee,
     remote: remote,
     member: member,
     other_post: other_post,
     ghosted: ghosted,
     silenced: silenced,
     own_post: own_post}
  end

  # the export feature writes the zip in the background, then the person downloads it
  defp export_zip!(user) do
    user_id = id(user)
    assert {:ok, _pid} = ExportController.trigger_prepare_archive_async(%{current_user: user})
    wait_for_archive(user_id, 20)

    conn =
      conn(user: user)
      |> get("/settings/export/archive_download")

    assert conn.status == 200

    path =
      Path.join(System.tmp_dir!(), "#{System.unique_integer([:positive])}-bonfire_archive.zip")

    File.write!(path, conn.resp_body)
    ExportController.archive_delete(user_id)
    path
  end

  defp wait_for_archive(user_id, attempts_left) when attempts_left > 0 do
    if ExportController.archive_exists?(user_id) do
      :ok
    else
      Process.sleep(500)
      wait_for_archive(user_id, attempts_left - 1)
    end
  end

  defp wait_for_archive(_user_id, 0), do: flunk("Archive was not created in time")

  # a post's attachments, each a `files` row with its media
  defp media_of(post) do
    post
    |> Bonfire.Common.Repo.preload([files: :media], force: true)
    |> Map.get(:files)
    |> Enum.map(& &1.media)
  end

  defp importable_keys(staged),
    do: for(%{importable?: true, key: key} <- Import.staged_items(staged), do: key)

  test "another account imports everything the archive lists", ctx do
    b = fake_user!("ArchiveImporter")

    assert {:ok, staged} = Import.stage_archive(ctx.zip)
    assert {:ok, %{skipped: _}} = Import.import_staged(b, staged, only: importable_keys(staged))

    # each item of the archive is its own job, so a failing one would otherwise go unnoticed
    drained = Oban.drain_queue(queue: :import)
    assert drained.discard == 0 and drained.failure == 0, inspect(drained)

    assert Follows.following?(b, ctx.followee)

    # the remote follow waited for the other server's accept, so it comes back as a request, found by the handle exported with its domain
    assert Follows.following?(b, ctx.remote) or Follows.requested?(b, ctx.remote)

    assert {:ok, circle} = Circles.get_by_name("Archive friends", b)
    assert Circles.is_encircled_by?(ctx.member, circle)

    assert Bonfire.Social.Likes.liked?(b, ctx.other_post)
    assert Bonfire.Social.Bookmarks.bookmarked?(b, ctx.other_post)
    assert Bonfire.Social.Boosts.boosted?(b, ctx.other_post)
    assert Blocks.is_blocked?(ctx.ghosted, :ghost, current_user: b)
    assert Blocks.is_blocked?(ctx.silenced, :silence, current_user: b)

    # the post keeps its picture, as a media record on our server
    assert Bonfire.Social.Boosts.boosted?(b, ctx.own_post)
    assert [%{path: path} | _] = media_of(ctx.own_post)
    refute String.starts_with?(to_string(path), "http")
  end

  test "staging lists each thing it holds with its count, and what can't be imported with why",
       ctx do
    assert {:ok, staged} = Import.stage_archive(ctx.zip)
    items = Map.new(Import.staged_items(staged), &{&1.key, &1})

    for key <- [
          :posts,
          :following,
          :requests,
          :circles,
          :bookmarks,
          :likes,
          :boosts,
          :ghosted,
          :silenced,
          :profile
        ] do
      assert %{importable?: true} = items[key], "expected #{key} to be importable"
    end

    # the remote follow waits for the other server to accept it, so it's exported as a request
    assert items.following.count == 1
    assert items.requests.count == 1
    assert items.likes.count == 1
    assert items.posts.count >= 1
    # there's one profile, so it has no count to show
    assert items.profile.count == nil

    # nothing dispatches on these, so they're named by their file
    for key <- ["followers.csv", "posts.csv", "messages.csv", "keys.asc"] do
      assert %{importable?: false, reason: reason} = items[key], "expected #{key} not importable"
      assert is_binary(reason)
    end
  end

  test "imports only the picked items, and extracts no media without posts", ctx do
    b = fake_user!("PickyImporter")

    assert {:ok, staged} = Import.stage_archive(ctx.zip)
    assert {:ok, _} = Import.import_staged(b, staged, only: [:likes])
    Oban.drain_queue(queue: :import)

    assert Bonfire.Social.Likes.liked?(b, ctx.other_post)
    refute Bonfire.Social.Bookmarks.bookmarked?(b, ctx.other_post)
    refute Follows.following?(b, ctx.followee)
    refute Bonfire.Social.Boosts.boosted?(b, ctx.own_post)

    refute staged
           |> Import.staged_dir()
           |> Path.join("**/*.png")
           |> Path.wildcard()
           |> Enum.any?()
  end

  test "a key it didn't stage is rejected", ctx do
    assert {:ok, staged} = Import.stage_archive(ctx.zip)

    assert {:error, _} =
             Import.import_staged(fake_user!(), staged, only: [:not_in_this_archive])
  end
end
