defmodule Bonfire.UI.Social.ImportStatusLabelsTest do
  @moduledoc """
  The import status page names each queued import job by what it does, as the extension that does it calls it, so a new kind of import shows up named without the page knowing about it.
  """
  use Bonfire.UI.Social.ConnCase, async: false

  @moduletag :ui

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account), me: me}
  end

  # a queued import job of the person's, written straight to the jobs table so it waits there rather than running (tests may run Oban inline)
  defp queue_import_job(me, op, identifier) do
    Oban.Job.new(%{"op" => op, "user_id" => me.id, "identifier" => identifier},
      worker: "Bonfire.Common.Import",
      queue: "import"
    )
    |> Bonfire.Common.Repo.insert!()
  end

  test "a job is named by the label of the extension that handles its op", %{conn: conn, me: me} do
    queue_import_job(me, "test_labelled_import", "someone@example.local")

    {:ok, _view, html} = live(conn, "/settings/user/import_status")

    # the job is listed
    assert html =~ ~s(title="someone@example.local")
    # under its extension's name (the op's code stays only as the value the type filter sends)
    assert html =~ "Labelled by its extension"
  end

  test "a job's row says what it's doing in the words of the extension that handles its op",
       %{conn: conn, me: me} do
    queue_import_job(me, "test_labelled_import", "someone@example.local")

    {:ok, _view, html} = live(conn, "/settings/user/import_status")

    assert html =~ "Doing a labelled import"
  end

  # the phrase is picked by the job's op, not by matching its label, which would also break once labels are translated
  test "a job whose label is the same as following's still gets its own phrase",
       %{conn: conn, me: me} do
    queue_import_job(me, "test_follow_labelled_import", "someone@example.local")

    {:ok, _view, html} = live(conn, "/settings/user/import_status")

    assert html =~ "Doing something else than following"
    refute html =~ "Following user"
  end

  test "the list ops keep the names they had", %{conn: conn, me: me} do
    queue_import_job(me, "follows_import", "someone@example.local")
    queue_import_job(me, "blocks_import", "spammer@example.local")

    {:ok, _view, html} = live(conn, "/settings/user/import_status")

    assert html =~ "Following user"
    assert html =~ "Blocking or instance"
  end
end
