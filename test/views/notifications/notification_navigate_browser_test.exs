defmodule Bonfire.UI.Social.NotificationNavigateBrowserTest do
  @moduledoc """
  Opening a tapped push notification in the tab that's already open.

  The service worker posts a `NAVIGATE` message to the tab (`notificationclick` in `pwabuilder-sw.js`), which the page handles in `bonfire_live.js`. These tests dispatch that same message, so the page's own handler runs, with whatever navigation or full load it does.

  Run with HOSTNAME=localhost and matching SERVER_PORT/PUBLIC_PORT values so the browser URL and socket origin use the test server.
  """
  use ExUnit.Case, async: false

  alias Wallaby.{Browser, Query}
  require Browser
  import Wallaby.Browser, only: [execute_query: 2]
  alias Bonfire.Common.Repo
  alias Bonfire.Posts

  @moduletag :ui
  @moduletag :browser
  if System.get_env("PHX_SERVER") not in ~w(yes true 1),
    do: @moduletag(skip: "Run with just test-ui-browser and a free SERVER_PORT")

  @endpoint Application.compile_env!(:bonfire, :endpoint_module)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, _} = Application.ensure_all_started(:wallaby)
    {:ok, session} = Wallaby.start_session()
    on_exit(fn -> Wallaby.end_session(session) end)

    password = "navigate-test-password"
    account = Bonfire.Me.Fake.fake_account!(%{credential: %{password: password}})
    alice = Bonfire.Me.Fake.fake_user!(account)
    base_url = @endpoint.url()

    session =
      session
      |> Browser.resize_window(1440, 1000)
      |> Browser.visit(base_url <> "/login")
      |> Browser.fill_in(Query.fillable_field("login_fields[email_or_username]"),
        with: alice.character.username
      )
      |> Browser.fill_in(Query.fillable_field("login_fields[password]"), with: password)
      |> Browser.click(Query.css("#login_submit_btn"))
      |> Browser.assert_has(Query.css(".phx-connected"))

    %{session: session, alice: alice, base_url: base_url}
  end

  # what the service worker sends; the handler only runs while the socket is connected, else it loads the page in full
  defp tap_notification(session, path) do
    Browser.execute_script(
      session,
      """
      const channel = new MessageChannel();
      navigator.serviceWorker.dispatchEvent(
        new MessageEvent("message", {data: {type: "NAVIGATE", url: arguments[0]}, ports: [channel.port2]})
      );
      """,
      [path]
    )
  end

  # until the tab is on `path`: the page it started on can hold the same posts, so their text alone doesn't say the navigation happened
  defp await_path(session, path, tries \\ 50)

  defp await_path(session, path, 0) do
    flunk("still on #{Browser.current_path(session)} instead of #{path}")
  end

  defp await_path(session, path, tries) do
    if Browser.current_path(session) == path do
      session
    else
      Process.sleep(100)
      await_path(session, path, tries - 1)
    end
  end

  defp main_text(session) do
    session
    |> Browser.find(Query.css("[data-id=main_section]"))
    |> Wallaby.Element.text()
  end

  defp count(text, needle), do: length(String.split(text, needle)) - 1

  for start <- ["/notifications", "/feed"] do
    test "a reply further down a thread, opened from a notification while on #{start}, shows as a reload does",
         %{session: session, alice: alice, base_url: base_url} do
      bob = Bonfire.Me.Fake.fake_user!()
      carl = Bonfire.Me.Fake.fake_user!()

      {:ok, post} =
        Posts.publish(
          current_user: alice,
          post_attrs: %{post_content: %{html_body: "alice's original post"}},
          boundary: "public"
        )

      {:ok, carls} =
        Posts.publish(
          current_user: carl,
          post_attrs: %{post_content: %{html_body: "carl's reply"}, reply_to_id: post.id},
          boundary: "public"
        )

      {:ok, bobs} =
        Posts.publish(
          current_user: bob,
          post_attrs: %{post_content: %{html_body: "bob's reply to carl"}, reply_to_id: carls.id},
          boundary: "public"
        )

      path = "/post/#{bobs.id}"

      session =
        session
        |> Browser.visit(base_url <> unquote(start))
        |> Browser.assert_has(Query.css(".phx-connected"))
        |> tap_notification(path)
        |> await_path(path)
        # the main view, since a post page nests another
        |> Browser.assert_has(Query.css("[data-phx-main].phx-connected"))
        |> Browser.assert_has(Query.css("[data-id=main_section]", text: "bob's reply to carl"))

      tapped = main_text(session)

      # the reference: the same page loaded in full
      reloaded =
        session
        |> Browser.visit(base_url <> path)
        |> Browser.assert_has(Query.css("[data-id=main_section]", text: "bob's reply to carl"))
        |> main_text()

      counts = fn text ->
        for t <- ["alice's original post", "carl's reply", "bob's reply to carl"],
            do: {t, count(text, t)}
      end

      assert counts.(tapped) == counts.(reloaded)
    end
  end
end
