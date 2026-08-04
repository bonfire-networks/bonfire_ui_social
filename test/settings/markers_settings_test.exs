defmodule Bonfire.UI.Social.MarkersSettingsTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  setup do
    account = fake_account!()
    me = fake_user!(account)
    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me}
  end

  test "does not expose internal feed-window or reading-position settings", %{conn: conn} do
    conn
    |> visit("/settings/user/feeds")
    |> refute_has("form[data-scope=time_limit]")
    |> refute_has("form[data-scope=markers_enabled]")
  end

  test "does not expose the internal marker expiry safeguard", %{conn: conn} do
    conn
    |> visit("/settings/user/feeds")
    |> refute_has("form[data-scope=markers_resume_max_age]")
  end
end
