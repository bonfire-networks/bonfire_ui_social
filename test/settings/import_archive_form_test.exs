defmodule Bonfire.UI.Social.ImportArchiveFormTest do
  @moduledoc """
  A person uploads their whole account archive (a zip) in the import settings. Once the upload finishes they see one checkbox per thing the archive holds, ticked and with its count, and the things that can't be imported, greyed with why. They see what importing will do, untick what they don't want, and import, which starts in the background.
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
    |> archive_input()
    |> render_upload("archive.zip")

    # staging reads the archive in the background
    render_async(view)

    view
  end

  defp archive_input(view),
    do:
      file_input(view, @import_form, :file, [
        %{name: "archive.zip", content: archive_zip(), type: "application/zip"}
      ])

  test "an archive being uploaded shows how far along it is", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings/user/import")

    assert view |> archive_input() |> render_upload("archive.zip", 50) =~ "50%"
  end

  # the archive is read in the background once uploaded. The "Reading the archive…" shown meanwhile isn't asserted: this small zip is often read before the upload's own render comes back, so that would fail at random
  test "an uploaded archive is read in the background, then lists what it holds", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings/user/import")

    view |> archive_input() |> render_upload("archive.zip")

    assert render_async(view) =~ "What to import from this archive"
  end

  # the import jobs, leaving out the staged dir's cleanup, which staging always queues
  defp queued_ops,
    do:
      for(
        job <- all_enqueued(worker: Bonfire.Common.Import),
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

  # runs the queued jobs of `op` here (tests queue them without running them, unless federating)
  defp run_jobs(op),
    do:
      for(
        job <- all_enqueued(worker: Bonfire.Common.Import),
        job.args["op"] == op,
        do: Bonfire.Common.Import.perform(job)
      )

  test "unticking an item imports the rest and leaves it alone, said before importing, then started in the background",
       %{conn: conn} do
    view = upload_archive(conn)

    # what the import will do is said before importing: the post addressed to nobody comes in for the person alone
    preview = render(view)
    assert preview =~ "Bookmarks"
    assert preview =~ "visible only to you"

    html =
      view
      |> form(@archive_form, %{"keys" => ["posts", "bookmarks"]})
      |> render_submit()

    assert html =~ "Import started"
    # the click only queues the job preparing the import, which then queues the items
    assert queued_ops() == ["import_materialize"]
    run_jobs("import_materialize")

    ops = queued_ops()
    assert "bookmarks_import" in ops
    assert "outbox_creations_import" in ops
    refute "likes_import" in ops
  end

  test "the archive's content offers an unticked option to also import its boosts, which imports them when ticked",
       %{conn: conn} do
    view = upload_archive(conn)

    assert has_element?(
             view,
             "#{@archive_form} input[type=checkbox][name='options[]'][value=include_boosts]"
           )

    refute has_element?(view, "#{@archive_form} input[value=include_boosts][checked]")

    view
    |> form(@archive_form)
    |> render_submit(%{"keys" => ["posts"], "options" => ["include_boosts"]})

    run_jobs("import_materialize")

    # the outbox with its boosts, rather than only its posts
    assert "outbox_import" in queued_ops()
    refute "outbox_creations_import" in queued_ops()
  end

  test "a key the archive didn't offer is refused, never turned into an atom", %{conn: conn} do
    view = upload_archive(conn)

    view
    |> form(@archive_form)
    |> render_submit(%{"keys" => ["not_a_thing_in_this_archive"]})

    assert queued_ops() == []
  end
end
