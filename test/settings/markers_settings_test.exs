defmodule Bonfire.UI.Social.MarkersSettingsTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Common.Settings

  setup do
    account = fake_account!()
    me = fake_user!(account)
    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me}
  end

  describe "Remember reading position toggle" do
    test "toggle is visible and enabled by default in feed settings", %{conn: conn} do
      conn
      |> visit("/settings/user/feeds")
      |> assert_has("#markers_toggle[checked]")
    end

    test "user can disable reading position tracking", %{conn: conn} do
      conn
      |> visit("/settings/user/feeds")
      |> within("form[data-scope=markers_enabled]", fn session ->
        session
        |> uncheck("Remember reading position", exact: false)
      end)
      # Revisit to confirm the toggle persisted as unchecked
      |> visit("/settings/user/feeds")
      |> refute_has("#markers_toggle[checked]")
    end

    test "user can re-enable reading position tracking after disabling", %{conn: conn, me: me} do
      Settings.put([Bonfire.Social.Markers, :enabled], false,
        current_user: me,
        scope: :user
      )

      conn
      |> visit("/settings/user/feeds")
      |> refute_has("#markers_toggle[checked]")
      |> within("form[data-scope=markers_enabled]", fn session ->
        session
        |> check("Remember reading position", exact: false)
      end)
      |> visit("/settings/user/feeds")
      |> assert_has("#markers_toggle[checked]")
    end
  end

  describe "Reading position duration select" do
    test "duration select is visible in feed settings", %{conn: conn} do
      conn
      |> visit("/settings/user/feeds")
      |> assert_has("#markers_ttl")
    end

    test "user can change reading position TTL", %{conn: conn} do
      conn
      |> visit("/settings/user/feeds")
      |> within("form[data-scope=markers_ttl]", fn session ->
        session
        |> PhoenixTest.select("Reading position duration", option: "4 hours")
      end)
      # Revisit to confirm the select persisted
      |> visit("/settings/user/feeds")
      |> assert_has("#markers_ttl option[selected][value='14400000']")
    end
  end
end
