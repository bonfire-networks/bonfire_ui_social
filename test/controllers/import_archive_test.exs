defmodule Bonfire.UI.Social.ImportArchiveTest do
  @moduledoc """
  A person brings their account over from a Mastodon archive. Staging the zip lists what it holds with counts, the person picks what to import, and the import brings each of those in, with the posts' images taken from the zip rather than from a server that may be gone. Zips that could write outside the import dir, or are too big, are refused before anything is extracted.

  The archive is a real Mastodon export trimmed to seven items (`test/fixtures/mastodon_archive/`), so the tests meet what Mastodon really writes, eg. a `/media_attachments/…` url with a leading slash, or a `Link` attachment. Bonfire's own archive is covered by `ExportImportArchiveTest`.
  """
  # async: false: the HTTP mock is global
  use Bonfire.UI.Social.ConnCase, async: false
  use Bonfire.Common.Config

  import Tesla.Mock

  alias Bonfire.Social.Import

  @moduletag :backend

  @public "https://www.w3.org/ns/activitystreams#Public"
  @fixture Path.expand("../fixtures/mastodon_archive", __DIR__)

  # a public post, its image `url` starting with a slash
  @image_post "https://masto.local/users/olduser/statuses/117485661879047330"
  # a post addressed to nobody, imported visible only to the importer
  @to_nobody "https://masto.local/users/olduser/statuses/117485661879047999"
  @image_entry "media_attachments/files/117/485/659/384/188/882/original/5ca1a84b30ea04da.png"
  @direct_message "https://masto.local/users/olduser/statuses/13500365"

  # every GET is answered from `served`, a map of url to a JSON document, and anything else is a 404
  defp serve(served \\ %{}) do
    mock_global(fn %{method: :get, url: url} ->
      case Map.get(served, url) do
        nil ->
          %Tesla.Env{status: 404, body: ""}

        document ->
          %Tesla.Env{
            status: 200,
            headers: ActivityPub.Utils.activitypub_object_headers(),
            body: Jason.encode!(document)
          }
      end
    end)
  end

  defp tmp_path(name),
    do: Path.join(System.tmp_dir!(), "#{System.unique_integer([:positive])}-#{name}")

  defp write_zip!(entries) do
    path = tmp_path("archive.zip")

    {:ok, _} =
      :zip.create(
        String.to_charlist(path),
        for({name, content} <- entries, do: {String.to_charlist(name), content})
      )

    path
  end

  # the fixture as a zip, with `changes` replacing entries by name (`nil` leaves one out)
  defp masto_zip!(changes \\ %{}) do
    for(
      path <- Path.wildcard(Path.join(@fixture, "**/*")),
      File.regular?(path),
      into: %{},
      do: {Path.relative_to(path, @fixture), File.read!(path)}
    )
    |> Map.merge(changes)
    |> Enum.reject(fn {_name, content} -> is_nil(content) end)
    |> write_zip!()
  end

  defp fixture_json(name), do: @fixture |> Path.join(name) |> File.read!() |> Jason.decode!()

  defp outbox_item(object_id),
    do:
      Enum.find(
        fixture_json("outbox.json")["orderedItems"],
        &(e(&1, "object", "id", nil) == object_id)
      )

  # a post on another server that the archive's likes or bookmarks name, served by the mock
  defp remote_note(id) do
    %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "id" => id,
      "type" => "Note",
      "attributedTo" => id |> String.split("/statuses/") |> hd(),
      "content" => "<p>someone else's post</p>",
      "published" => "2020-01-01T00:00:00Z",
      "to" => [@public]
    }
  end

  # a post's attachments, each a `files` row with its media
  defp media_of(post) do
    post
    |> Bonfire.Common.Repo.preload([files: :media], force: true)
    |> Map.get(:files)
    |> Enum.map(& &1.media)
  end

  defp imported_post(ap_id) do
    assert {:ok, %{pointer_id: pointer_id}} = ActivityPub.Object.get_cached(ap_id: ap_id)
    assert {:ok, post} = Bonfire.Common.Needles.get(pointer_id, skip_boundary_check: true)
    post
  end

  defp importable_keys(staged),
    do: for(%{importable?: true, key: key} <- Import.staged_items(staged), do: key)

  setup do
    Process.put(:federating, true)
    serve()
    :ok
  end

  describe "a Mastodon archive" do
    test "with the origin offline, the post's picture, likes, bookmarks and profile come from the zip" do
      liked = fixture_json("likes.json")["orderedItems"]
      bookmarked = fixture_json("bookmarks.json")["orderedItems"]
      serve(Map.new(liked ++ bookmarked, &{&1, remote_note(&1)}))

      # a fake user comes with a summary, and the import only fills what's empty
      assert {:ok, b} =
               Bonfire.Me.Users.update(fake_user!("FromMastodon"), %{
                 "profile" => %{"summary" => ""}
               })

      assert {:ok, staged} = Import.stage_archive(masto_zip!())
      assert {:ok, _} = Import.import_staged(b, staged, only: importable_keys(staged))
      Oban.drain_queue(queue: :import)

      assert [media] = media_of(imported_post(@image_post))
      refute media.path |> to_string() |> String.starts_with?("http")

      for id <- liked, do: assert(Bonfire.Social.Likes.liked?(b, imported_post(id)))
      for id <- bookmarked, do: assert(Bonfire.Social.Bookmarks.bookmarked?(b, imported_post(id)))

      b = Bonfire.Common.Repo.preload(b, [profile: [:icon]], force: true)
      assert b.profile.icon
      assert b.profile.summary =~ "The account I am moving away from"
    end

    test "with the origin online, the picture is still the zip's copy" do
      online =
        outbox_item(@image_post)["object"]
        |> put_in(["attachment", Access.at(0), "url"], "https://masto.local/" <> @image_entry)

      serve(%{@image_post => online})
      b = fake_user!("FromMastodonOnline")

      assert {:ok, staged} = Import.stage_archive(masto_zip!())
      assert {:ok, _} = Import.import_staged(b, staged, only: [:posts])
      Oban.drain_queue(queue: :import)

      assert [media] = media_of(imported_post(@image_post))
      refute media.path |> to_string() |> String.starts_with?("http")
    end

    # its one recipient's server no longer has them (every GET here is a 404), so nobody else could ever see it: it comes in visible only to the person importing it, like a post addressed to nobody
    test "a direct message whose recipients can't be found is imported visible only to the importer" do
      b = fake_user!("FromMastodonPrivate")
      someone_else = fake_user!("NotTheDMImporter")

      assert {:ok, staged} = Import.stage_archive(masto_zip!())
      assert {:ok, _} = Import.import_staged(b, staged, only: [:posts])
      Oban.drain_queue(queue: :import)

      assert {:ok, %{pointer_id: post_id}} = ActivityPub.Object.get_cached(ap_id: @direct_message)
      assert is_binary(post_id), "the direct message wasn't imported"

      assert {:ok, %Bonfire.Data.Social.Post{}} =
               Bonfire.Common.Needles.get(post_id, skip_boundary_check: true)

      refute Bonfire.Boundaries.can?(nil, :see, post_id), "the direct message became public"
      assert Bonfire.Boundaries.can?(b, :read, post_id)
      refute Bonfire.Boundaries.can?(someone_else, :read, post_id)

      assert Bonfire.Social.FeedLoader.feed_contains?(:user_activities, post_id,
               current_user: b,
               by: b
             )

      refute Bonfire.Social.FeedLoader.feed_contains?(:user_activities, post_id,
               current_user: someone_else,
               by: b
             )
    end

    # Mastodon's private mention to nobody, a note only its author saw: it comes in visible only to the person importing it, on their profile, and not as a message
    test "a post addressed to nobody is imported visible only to the importer" do
      b = fake_user!("FromMastodonToNobody")
      someone_else = fake_user!("NotTheImporter")

      assert {:ok, staged} = Import.stage_archive(masto_zip!())
      assert {:ok, result} = Import.import_staged(b, staged, only: [:posts])
      Oban.drain_queue(queue: :import)

      refute Enum.find(List.wrap(result[:skipped]), &(&1.key == @to_nobody))
      assert %{reason: note} = Enum.find(List.wrap(result[:notes]), &(&1.key == @to_nobody))
      assert note =~ "only to you"

      assert {:ok, %{pointer_id: post_id}} = ActivityPub.Object.get_cached(ap_id: @to_nobody)
      assert is_binary(post_id)

      # a post, not a message
      assert {:ok, %Bonfire.Data.Social.Post{}} =
               Bonfire.Common.Needles.get(post_id, skip_boundary_check: true)

      assert Bonfire.Boundaries.can?(b, :read, post_id)
      refute Bonfire.Boundaries.can?(someone_else, :read, post_id)

      assert Bonfire.Social.FeedLoader.feed_contains?(:user_activities, post_id,
               current_user: b,
               by: b
             )

      refute Bonfire.Social.FeedLoader.feed_contains?(:user_activities, post_id,
               current_user: someone_else,
               by: b
             )

      refute Bonfire.Social.FeedLoader.feed_contains?(:local, post_id, current_user: someone_else)

      # nothing about it reaches other servers
      refute Enum.any?(
               ActivityPub.Object.get_outbox_for_actor(Bonfire.Common.URIs.canonical_url(b), 1),
               &(&1.data["object"] == @to_nobody)
             )
    end

    test "the profile import never overwrites what the profile already has" do
      b = fake_user!("FromMastodonKeepsProfile")
      summary = Bonfire.Common.Repo.preload(b, :profile, force: true).profile.summary
      assert summary not in [nil, ""]

      assert {:ok, staged} = Import.stage_archive(masto_zip!())
      assert {:ok, _} = Import.import_staged(b, staged, only: [:profile])

      assert Bonfire.Common.Repo.preload(b, :profile, force: true).profile.summary == summary
    end

    test "staging lists only what the zip holds, with its counts" do
      assert {:ok, staged} = Import.stage_archive(masto_zip!())
      items = Map.new(Import.staged_items(staged), &{&1.key, &1})

      assert items.posts.count == 8
      assert items.likes.count == 3
      assert items.bookmarks.count == 2
      assert %{importable?: true} = items.profile
      refute items[:circles]
      refute items[:following]
    end

    test "a collection with nothing in it, which Mastodon writes without `orderedItems`, counts as empty" do
      empty =
        Jason.encode!(%{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "id" => "bookmarks.json",
          "type" => "OrderedCollection"
        })

      assert {:ok, staged} = Import.stage_archive(masto_zip!(%{"bookmarks.json" => empty}))
      items = Map.new(Import.staged_items(staged), &{&1.key, &1})

      assert items.bookmarks.count == 0
      # offered greyed out, with why, rather than as a box that would import nothing
      assert %{importable?: false, reason: reason} = items.bookmarks
      assert reason =~ "Nothing"
    end
  end

  describe "an outbox post this instance already knows" do
    test "is still imported, by a second person too" do
      item = outbox_item(@image_post)

      for name <- ["FirstImporter", "SecondImporter"] do
        b = fake_user!(name)
        Import.import_from_json(:outbox, b, %{"orderedItems" => [item]})
        Oban.drain_queue(queue: :import)

        assert Bonfire.Social.Boosts.boosted?(b, imported_post(@image_post)),
               "#{name}'s import didn't bring the post in"
      end
    end
  end

  describe "an outbox without a zip" do
    test "re-fetches a post whose attachment is a relative path, and imports it without media when that fails" do
      remote_url = "https://masto.local/" <> @image_entry

      serve(%{
        @image_post =>
          put_in(
            outbox_item(@image_post)["object"],
            ["attachment", Access.at(0), "url"],
            remote_url
          )
      })

      b = fake_user!("OutboxOnly")
      Import.import_from_json(:outbox, b, %{"orderedItems" => [outbox_item(@image_post)]})
      Oban.drain_queue(queue: :import)

      assert [media] = media_of(imported_post(@image_post))
      assert to_string(media.path) == remote_url

      # the same post under another id, whose origin is gone
      offline_id = @image_post <> "0"

      offline =
        outbox_item(@image_post)
        |> put_in(["id"], offline_id <> "/activity")
        |> put_in(["object", "id"], offline_id)

      serve()
      Import.import_from_json(:outbox, b, %{"orderedItems" => [offline]})
      assert %{success: 1} = Oban.drain_queue(queue: :import)
      assert [] = media_of(imported_post(offline_id))
    end
  end

  describe "refusals" do
    test "an entry escaping the import dir refuses the whole archive and writes nothing outside it" do
      zip = write_zip!([{"outbox.json", "{}"}, {"../evil.jpg", "evil"}])
      assert {:error, _} = Import.stage_archive(zip)
      refute File.exists?(Path.join(System.tmp_dir!(), "evil.jpg"))

      # `:zip.create` itself turns an absolute name into a relative one, so the name is written into the zip's bytes afterwards, as a crafted zip would hold it
      absolute = "/tmp/evil-#{System.unique_integer([:positive])}.jpg"
      placeholder = "X" <> String.trim_leading(absolute, "/")
      zip = write_zip!([{"outbox.json", "{}"}, {placeholder, "evil"}])
      File.write!(zip, :binary.replace(File.read!(zip), placeholder, absolute, [:global]))

      assert {:error, _} = Import.stage_archive(zip)
      refute File.exists?(absolute)
    end

    test "a zip over the size limit is refused before extraction" do
      Config.put([Bonfire.Social.Import, :max_archive_size], 10, :bonfire_social)

      on_exit(fn ->
        Config.put([Bonfire.Social.Import, :max_archive_size], nil, :bonfire_social)
      end)

      zip = write_zip!([{"outbox.json", "{}"}, {"big.bin", String.duplicate("a", 1000)}])
      assert {:error, _} = Import.stage_archive(zip)
    end

    test "a file that isn't a zip, or a zip with nothing it knows, is an error" do
      not_zip = tmp_path("not.zip")
      File.write!(not_zip, "not a zip at all")
      assert {:error, _} = Import.stage_archive(not_zip)

      assert {:error, _} = Import.stage_archive(write_zip!([{"readme.txt", "hello"}]))
    end
  end

  test "the cleanup job removes the staged dir once it's older than the retention, not before" do
    assert {:ok, staged} = Import.stage_archive(masto_zip!())

    dir = Import.staged_dir(staged)
    assert File.dir?(dir)

    # as when Oban runs the scheduled job straight away (its inline mode): the import still needs the dir
    assert :ok = Import.perform(%Oban.Job{args: %{"op" => "archive_cleanup", "dir" => dir}})
    assert File.dir?(dir)

    Config.put([Bonfire.Social.Import, :archive_retention], 0, :bonfire_social)

    on_exit(fn ->
      Config.put([Bonfire.Social.Import, :archive_retention], nil, :bonfire_social)
    end)

    assert :ok = Import.perform(%Oban.Job{args: %{"op" => "archive_cleanup", "dir" => dir}})
    refute File.exists?(dir)
  end
end
