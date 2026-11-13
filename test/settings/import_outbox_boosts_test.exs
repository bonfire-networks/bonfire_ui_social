defmodule Bonfire.UI.Social.ImportOutboxBoostsTest do
  @moduledoc """
  Importing an outbox brings in the person's own posts. Their boosts (the outbox's `Announce`s) come in only when they tick "Also import boosts", since an archive from Mastodon has no separate list of boosts.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  use Oban.Testing, repo: Bonfire.Common.Repo

  @moduletag :ui

  # the upload form, the only multipart one on the page (its `phx-submit` is a JS command, not the event name)
  @import_form "form[enctype='multipart/form-data']"

  @outbox %{
    "type" => "OrderedCollection",
    "orderedItems" => [
      %{
        "id" => "https://masto.local/users/olduser/statuses/1/activity",
        "type" => "Announce",
        "actor" => "https://masto.local/users/olduser",
        "object" => "https://masto.local/users/bob/statuses/2",
        "to" => ["https://www.w3.org/ns/activitystreams#Public"]
      }
    ]
  }

  setup do
    # the outbox is one of the import types offered only when federating
    Process.put(:federating, true)

    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account)}
  end

  defp submit_outbox(conn, params, outbox \\ @outbox) do
    {:ok, view, _html} = live(conn, "/settings/user/import")

    view
    |> file_input(@import_form, :file, [
      %{name: "outbox.json", content: Jason.encode!(outbox), type: "application/json"}
    ])
    |> render_upload("outbox.json")

    view
    |> form(@import_form, Map.merge(%{"type" => "outbox"}, params))
    |> render_submit()

    # the component's flash reaches the page on the next render, not in the submit's own
    render(view)
  end

  defp queued_ops,
    do: for(job <- all_enqueued(worker: Bonfire.Social.Import), do: job.args["op"])

  test "the outbox import offers an unticked option to also import boosts", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings/user/import")

    assert has_element?(view, "input[type=checkbox][name=include_boosts]")
    refute has_element?(view, "input[name=include_boosts][checked]")
  end

  test "ticking it imports the outbox's boosts too", %{conn: conn} do
    submit_outbox(conn, %{"include_boosts" => "true"})

    assert queued_ops() == ["outbox_import"]
  end

  test "left unticked, the boosts aren't queued, and the person is told how many were left out",
       %{conn: conn} do
    html = submit_outbox(conn, %{})

    # the outbox holds only a boost, so nothing is queued
    assert queued_ops() == []
    assert html =~ "1 boost left out"
  end

  test "a post addressed to nobody is imported for the person alone, and they're told", %{
    conn: conn
  } do
    to_nobody = %{
      "id" => "https://masto.local/users/olduser/statuses/3/activity",
      "type" => "Create",
      "actor" => "https://masto.local/users/olduser",
      "to" => [],
      "cc" => [],
      "object" => %{
        "id" => "https://masto.local/users/olduser/statuses/3",
        "type" => "Note",
        "attributedTo" => "https://masto.local/users/olduser",
        "content" => "<p>only I could see this</p>",
        "to" => [],
        "cc" => []
      }
    }

    html = submit_outbox(conn, %{}, Map.update!(@outbox, "orderedItems", &[to_nobody | &1]))

    # only the post is queued: boosts weren't asked for
    assert queued_ops() == ["outbox_creations_import"]
    assert html =~ "visible only to you"
  end
end
