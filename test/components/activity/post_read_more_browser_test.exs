defmodule Bonfire.UI.Social.PostReadMoreBrowserTest do
  @moduledoc "A long post in a feed is clamped, with Read more to show it whole and Read less to clamp it again, and a short one shows no Read more. The clamp is CSS and JS, so this runs in a browser. Run with HOSTNAME=localhost and matching SERVER_PORT/PUBLIC_PORT values so the browser URL and socket origin use the test server."
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

  @password "post-read-more-password"

  @long_body Enum.map_join(1..30, "", &"<p>Paragraph #{&1} of a long post.</p>")

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, _} = Application.ensure_all_started(:wallaby)
    {:ok, session} = Wallaby.start_session()
    on_exit(fn -> Wallaby.end_session(session) end)

    account = Bonfire.Me.Fake.fake_account!(%{credential: %{password: @password}})
    user = Bonfire.Me.Fake.fake_user!(account)

    %{session: Browser.resize_window(session, 1440, 1000), user: user}
  end

  test "a long post in a feed shows Read more, which shows its last line, and Read less clamps it again",
       %{session: session, user: user} do
    post =
      Bonfire.Posts.Fake.fake_post!(user, "public", %{post_content: %{html_body: @long_body}})

    activity = activity_of(post)

    session
    |> open_profile_feed(user, activity)
    |> Browser.assert_has(Query.css("#{activity} .read-more-btn", text: "Read more"))
    |> assert_shown(activity, "Paragraph 30 of", false, "control: the last line is clamped")
    |> Browser.click(Query.css("#{activity} .read-more-btn"))
    |> assert_shown(activity, "Paragraph 30 of", true, "the last line is shown after Read more")
    |> Browser.click(Query.css("#{activity} .read-less-btn"))
    |> assert_shown(activity, "Paragraph 30 of", false, "clamped again after Read less")
  end

  test "a short post in a feed shows no Read more", %{session: session, user: user} do
    post =
      Bonfire.Posts.Fake.fake_post!(user, "public", %{
        post_content: %{html_body: "<p>A short post.</p>"}
      })

    activity = activity_of(post)

    session
    |> open_profile_feed(user, activity)
    |> assert_shown(activity, "A short post.", true, "the post is shown")
    |> Browser.refute_has(Query.css("#{activity} .read-more-btn", text: "Read more"))
  end

  defp activity_of(post), do: "[data-object_id='#{post.id}']"

  # the author's own profile lists their posts, clamped as in any feed
  defp open_profile_feed(session, user, activity) do
    session
    |> Browser.visit(@endpoint.url() <> "/login")
    |> Browser.fill_in(Query.fillable_field("login_fields[email_or_username]"),
      with: user.character.username
    )
    |> Browser.fill_in(Query.fillable_field("login_fields[password]"), with: @password)
    |> Browser.click(Query.css("#login_submit_btn"))
    |> Browser.assert_has(Query.css(".phx-connected #sidebar-feeds-link"))
    |> Browser.visit(@endpoint.url() <> "/@#{user.character.username}")
    |> Browser.assert_has(Query.css(".phx-connected #{activity}"))
  end

  # whether the paragraph holding `text` is laid out and not cut off by an element that clips its overflow (as a line clamp does), up to `within` (the page's own scroll container would clip a long text too), polled for up to 2 seconds as the hook settles after a click
  defp assert_shown(session, within, text, expected, message, tries \\ 20) do
    result = shown(session, within, text)

    cond do
      result == expected ->
        session

      tries > 1 ->
        Process.sleep(100)
        assert_shown(session, within, text, expected, message, tries - 1)

      true ->
        flunk("#{message}: expected shown? to be #{expected}, got #{inspect(result)}")
    end
  end

  defp shown(session, within, text) do
    Browser.execute_script(
      session,
      """
      const root = document.querySelector(arguments[0]);
      const line = root && [...root.querySelectorAll('p')].find(p => p.textContent.includes(arguments[1]));
      if (!line) return null;
      const rect = line.getBoundingClientRect();
      if (rect.height === 0) return false;
      for (let el = line.parentElement; el && el !== root.parentElement; el = el.parentElement) {
        if (getComputedStyle(el).overflowY !== 'visible' && rect.bottom > el.getBoundingClientRect().bottom + 1) return false;
      }
      return true;
      """,
      [within, text],
      &send(self(), {:shown, &1})
    )

    receive do
      {:shown, result} -> result
    end
  end
end
