defmodule Bonfire.UI.Social.ImportArchiveFormTest do
  @moduledoc """
  A person uploads their whole account archive (a zip) in the import settings. Once the upload finishes they see one checkbox per thing the archive holds, ticked and with its count, and the things that can't be imported, greyed with why. They untick what they don't want, import, and get a report of what was queued and what was skipped.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  use Oban.Testing, repo: Bonfire.Common.Repo

  @moduletag :ui

  # the upload form, the only multipart one on the page (its `phx-submit` is a JS command, not the event name)
  @import_form "form[enctype='multipart/form-data']"
  @archive_form "#archive_import_form"
  @fixture Path.expand("../fixtures/mastodon_archive", __DIR__)

  setup do
    # the outbox is one of the import types offered only when federating
    Process.put(:federating, true)
    # the archive's old server is offline, as no request should reach a real one
    Tesla.Mock.mock_global(fn _ -> %Tesla.Env{status: 404, body: ""} end)

    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account)}
  end

  # the trimmed real Mastodon archive, as the zip a person would upload
  defp archive_zip do
    path = Path.join(System.tmp_dir!(), "#{System.unique_integer([:positive])}-archive.zip")

    entries =
      for file <- Path.wildcard(Path.join(@fixture, "**/*")), File.regular?(file) do
        {String.to_charlist(Path.relative_to(file, @fixture)), File.read!(file)}
      end

    {:ok, _} = :zip.create(String.to_charlist(path), entries)
    File.read!(path)
  end

  defp upload_archive(conn) do
    {:ok, view, _html} = live(conn, "/settings/user/import")

    view
    |> file_input(@import_form, :file, [
      %{name: "archive.zip", content: archive_zip(), type: "application/zip"}
    ])
    |> render_upload("archive.zip")

    view
  end

  # the import jobs, leaving out the staged dir's cleanup, which staging always queues
  defp queued_ops,
    do:
      for(
        job <- all_enqueued(worker: Bonfire.Social.Import),
        job.args["op"] != "archive_cleanup",
        do: job.args["op"]
      )

  test "uploading an archive lists what it holds, each ticked with its count", %{conn: conn} do
    view = upload_archive(conn)

    for key <- ["posts", "likes", "bookmarks", "profile"] do
      assert has_element?(view, "#{@archive_form} input[type=checkbox][value=#{key}][checked]"),
             "expected a ticked checkbox for #{key}"
    end

    assert has_element?(view, "#{@archive_form} label", "Likes (3)")
    # the outbox's posts and boosts together, and the one picture, in the singular
    assert has_element?(view, "#{@archive_form} label", "Content (8 objects, with 1 media file)")
    refute has_element?(view, "#{@archive_form} input[value=circles]")
  end

  test "unticking an item imports the rest and leaves it alone, then reports what was queued",
       %{conn: conn} do
    view = upload_archive(conn)

    html =
      view
      |> form(@archive_form, %{"keys" => ["posts", "bookmarks"]})
      |> render_submit()

    ops = queued_ops()
    assert "bookmarks_import" in ops
    assert "outbox_creations_import" in ops
    refute "likes_import" in ops

    assert html =~ "Bookmarks"
    # the post addressed to nobody is reported as imported for the person alone
    assert html =~ "visible only to you"
  end

  test "a key the archive didn't offer is refused, never turned into an atom", %{conn: conn} do
    view = upload_archive(conn)

    view
    |> form(@archive_form)
    |> render_submit(%{"keys" => ["not_a_thing_in_this_archive"]})

    assert queued_ops() == []
  end
end
