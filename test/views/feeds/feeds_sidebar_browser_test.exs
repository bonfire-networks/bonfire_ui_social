defmodule Bonfire.UI.Social.FeedsSidebarBrowserTest do
  @moduledoc "Run with HOSTNAME=localhost and matching SERVER_PORT/PUBLIC_PORT values so the browser URL and socket origin use the test server."
  use ExUnit.Case, async: false

  alias Wallaby.{Browser, Query}
  require Browser
  import Wallaby.Browser, only: [execute_query: 2]
  alias Bonfire.Common.Repo

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

    password = "sidebar-test-password"
    account = Bonfire.Me.Fake.fake_account!(%{credential: %{password: password}})
    user = Bonfire.Me.Fake.fake_user!(account)
    base_url = @endpoint.url()

    session =
      session
      |> Browser.resize_window(1440, 1000)
      |> Browser.visit(base_url <> "/login")
      |> Browser.fill_in(Query.fillable_field("login_fields[email_or_username]"),
        with: user.character.username
      )
      |> Browser.fill_in(Query.fillable_field("login_fields[password]"), with: password)
      |> Browser.click(Query.css("#login_submit_btn"))
      |> Browser.assert_has(Query.css(".phx-connected #sidebar-feeds-link"))

    %{session: session}
  end

  test "feed tabs navigate while the sidebar remains a single link", %{session: session} do
    session
    |> Browser.refute_has(Query.css("#sidebar-feeds-list"))
    |> Browser.click(Query.css("#sidebar-feeds-link"))
    |> Browser.assert_has(Query.css("#feed-tab-my[aria-current='page']"))
    |> Browser.assert_has(Query.css("h1[data-role=page_title]", text: "Feeds"))
    |> Browser.click(Query.css("#feed-tab-local"))
    |> Browser.assert_has(Query.css("#feed-tab-local[aria-current='page']"))
    |> Browser.refute_has(Query.css("#sidebar-feeds-list"))
    |> Browser.click(Query.link("Dashboard"))
    |> Browser.assert_has(Query.css("#nav_sidebar a[aria-current='page']", text: "Dashboard"))
    |> Browser.refute_has(Query.css("#feed-tabs"))
  end

  test "feed tabs scroll horizontally on a narrow screen", %{session: session} do
    session
    |> Browser.visit(@endpoint.url() <> "/feed/local")
    |> Browser.resize_window(390, 844)
    |> Browser.assert_has(Query.css("#feed-tab-local[aria-current='page']"))
    |> Browser.execute_script("""
    const tabs = document.querySelector('#feed-tabs ul');
    const first = tabs.querySelector('li').getBoundingClientRect();
    const last = tabs.querySelector('li:last-child').getBoundingClientRect();
    return {overflow: getComputedStyle(tabs).overflowX,
            scrollable: tabs.scrollWidth > tabs.clientWidth,
            singleRow: first.top === last.top,
            pageFits: document.documentElement.scrollWidth <= window.innerWidth};
    """, fn result ->
      assert result["overflow"] == "auto"
      assert result["scrollable"]
      assert result["singleRow"]
      assert result["pageFits"]
    end)
  end

end
