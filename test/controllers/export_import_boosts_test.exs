defmodule Bonfire.UI.Social.ExportImportBoostsTest do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  alias Bonfire.Common.URIs
  alias Bonfire.Social.Import

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, user: me}
  end

  test "export and then import boosts with valid CSV data works", %{user: user, conn: conn} do
    # Create users and posts to boost
    other_user1 = fake_user!("OtherUser1")
    other_user2 = fake_user!("OtherUser2")

    assert {:ok, post1} =
             Bonfire.Posts.publish(
               current_user: other_user1,
               boundary: "public",
               post_attrs: %{post_content: %{html_body: "Boostable post 1"}}
             )

    assert {:ok, post2} =
             Bonfire.Posts.publish(
               current_user: other_user2,
               boundary: "public",
               post_attrs: %{post_content: %{html_body: "Boostable post 2"}}
             )

    # Create initial boosts
    assert {:ok, _boost1} = Bonfire.Social.Boosts.boost(user, post1)
    assert {:ok, _boost2} = Bonfire.Social.Boosts.boost(user, post2)

    # Verify boosts exist
    assert Bonfire.Social.Boosts.boosted?(user, post1)
    assert Bonfire.Social.Boosts.boosted?(user, post2)

    # Test export via controller
    Logger.metadata(action: info("export boosts via controller"))

    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/boosts")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

    # Verify exported CSV contains the expected URLs
    exported_content = conn.resp_body
    assert String.contains?(exported_content, URIs.canonical_url(post1))
    assert String.contains?(exported_content, URIs.canonical_url(post2))

    # Write exported CSV to file
    csv_path = "/tmp/test_exported_boosts.csv"
    File.write!(csv_path, conn.resp_body)

    # Create a new user to test import
    import_user = fake_user!("ImportUser")

    # Verify new user has no boosts initially
    refute Bonfire.Social.Boosts.boosted?(import_user, post1)
    refute Bonfire.Social.Boosts.boosted?(import_user, post2)

    Logger.metadata(action: info("import exported CSV"))

    # Import the exported CSV
    assert %{ok: 2} = Import.import_from_csv_file(:boosts, import_user.id, csv_path)

    assert %{success: 2} = Oban.drain_queue(queue: :import)

    # Verify boosts were imported correctly
    assert Bonfire.Social.Boosts.boosted?(import_user, post1)
    assert Bonfire.Social.Boosts.boosted?(import_user, post2)

    File.rm(csv_path)
  end

  test "import boosts handles invalid CSV data gracefully", %{user: user} do
    # Create invalid CSV file
    csv_path = "/tmp/test_invalid_boosts.csv"
    invalid_content = "invalid_url\nnot_a_url_at_all\n"
    File.write!(csv_path, invalid_content)

    Logger.metadata(action: info("import invalid CSV"))

    # Import should handle errors gracefully
    Import.import_from_csv_file(:boosts, user.id, csv_path)

    assert %{discard: 2} = Oban.drain_queue(queue: :import)

    File.rm(csv_path)
  end

  test "import boosts with mixed valid/invalid CSV data", %{user: user} do
    # Create user and post to boost
    other_user = fake_user!("OtherUser")

    assert {:ok, post} =
             Bonfire.Posts.publish(
               current_user: other_user,
               boundary: "public",
               post_attrs: %{post_content: %{html_body: "Valid boostable post"}}
             )

    # Create CSV with mixed valid and invalid data
    csv_path = "/tmp/test_mixed_boosts.csv"

    mixed_content = """
    #{URIs.canonical_url(post)}
    invalid_url
    not_a_url
    """

    File.write!(csv_path, mixed_content)

    Logger.metadata(action: info("import mixed CSV"))

    # Verify no boosts exist initially
    refute Bonfire.Social.Boosts.boosted?(user, post)

    # Import should handle partial success
    Import.import_from_csv_file(:boosts, user.id, csv_path)

    assert %{success: 1, discard: 2} = Oban.drain_queue(queue: :import)

    # Valid entry should be imported
    assert Bonfire.Social.Boosts.boosted?(user, post)

    File.rm(csv_path)
  end
end
