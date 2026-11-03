defmodule Bonfire.UI.Social.CarouselReadMoreBrowserTest do
  @moduledoc "Long posts in an expandable carousel (\"Top discussions\", and the pinned spotlight): Read more and the card's Show more pill both show the whole post, and an expanded card's height becomes the cap of every card. Clamps and caps are CSS and JS, so this runs in a browser. Run with HOSTNAME=localhost and matching SERVER_PORT/PUBLIC_PORT values so the browser URL and socket origin use the test server."
  use ExUnit.Case, async: false

  alias Wallaby.{Browser, Query}
  require Browser
  import Wallaby.Browser, only: [execute_query: 2]
  alias Bonfire.Common.Repo
  alias Bonfire.Social.Pins

  @moduletag :ui
  @moduletag :browser
  if System.get_env("PHX_SERVER") not in ~w(yes true 1),
    do: @moduletag(skip: "Run with just test-ui-browser and a free SERVER_PORT")

  @endpoint Application.compile_env!(:bonfire, :endpoint_module)

  # the card cap when no card is expanded: 22rem
  @default_cap "352px"

  @password "carousel-read-more-password"

  @long_body Enum.map_join(1..40, "", &"<p>Paragraph #{&1} of a long discussion.</p>")

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, _} = Application.ensure_all_started(:wallaby)
    {:ok, session} = Wallaby.start_session()
    on_exit(fn -> Wallaby.end_session(session) end)

    # the spotlight's pins are cached across tests; `:reset` takes no DB, so it still works once the sandbox is gone
    Pins.list_spotlight_activities(cache: :reset)
    on_exit(fn -> Pins.list_spotlight_activities(cache: :reset) end)

    account = Bonfire.Me.Fake.fake_account!(%{credential: %{password: @password}})
    user = Bonfire.UI.Common.Testing.Helpers.fake_admin!(account)

    %{session: Browser.resize_window(session, 1440, 1000), user: user}
  end

  test "Read more on a long post in Top discussions shows the whole post", %{
    session: session,
    user: user
  } do
    card = trending_card(long_post!(user))

    session
    |> open_dashboard(user, card)
    |> assert_state(card, &(&1["overflows"] and not &1["expanded"]), "control: clamped")
    |> click_in_view(Query.css(card <> " .read-more-btn"))
    |> assert_state(card, &(not &1["overflows"] and &1["expanded"]), "text shown, card expanded")
  end

  test "Read less clamps the post and collapses its card again", %{
    session: session,
    user: user
  } do
    card = trending_card(long_post!(user))

    session
    |> open_dashboard(user, card)
    |> click_in_view(Query.css(card <> " .read-more-btn"))
    |> assert_state(card, &(not &1["overflows"] and &1["expanded"]), "expanded")
    |> click_in_view(Query.css(card <> " .read-less-btn"))
    |> assert_state(card, &(&1["overflows"] and not &1["expanded"]), "clamped again")
  end

  test "Show more on one card lets the other cards grow to its height", %{
    session: session,
    user: user
  } do
    # B first: with no replies, the newest post leads the carousel, so A's pill is in view
    card_b = trending_card(long_post!(user))
    card_a = trending_card(long_post_with_image!(user))

    session =
      session
      |> open_dashboard(user, card_a)
      |> Browser.assert_has(Query.css(card_b))
      |> assert_state(card_b, &(&1["maxHeight"] == @default_cap), "control: default cap")
      |> click_in_view(Query.css(card_a <> " [data-role=carousel_card_expand]"))
      |> assert_state(
        card_a,
        &(&1["expanded"] and &1["height"] > 352),
        "A expanded past the default cap"
      )

    # A keeps growing for a moment (its text unclamps, its image loads), and the cap follows, so each poll measures A afresh
    session
    |> assert_state(
      card_b,
      &(&1["maxHeight"] == "#{state(session, card_a)["height"]}px"),
      "B capped at A's height"
    )
    |> click_in_view(Query.css(card_a <> " [data-role=carousel_card_expand]"))
    |> assert_state(card_a, &(not &1["expanded"]), "A collapsed")
    |> assert_state(card_b, &(&1["maxHeight"] == @default_cap), "B back to the default cap")
  end

  test "Show more on a long post also shows the whole text, and Show less clamps it again", %{
    session: session,
    user: user
  } do
    card = trending_card(long_post_with_image!(user))

    session
    |> open_dashboard(user, card)
    |> assert_state(card, &(&1["overflows"] and &1["clamped"]), "control: text and card clipped")
    |> click_in_view(Query.css(card <> " [data-role=carousel_card_expand]"))
    |> assert_state(card, &(not &1["overflows"] and &1["readLessShown"]), "text shown")
    |> click_in_view(Query.css(card <> " [data-role=carousel_card_expand]"))
    |> assert_state(card, &(&1["overflows"] and not &1["readLessShown"]), "clamped again")
  end

  test "Read more on a long pinned post in the spotlight shows the whole post", %{
    session: session,
    user: user
  } do
    post = long_post!(user)
    {:ok, _} = Pins.pin(user, post, :instance)
    card = "[data-id=instance_pinned_widget] " <> card_of(post)

    session
    |> open_dashboard(user, card)
    |> assert_state(card, &(&1["overflows"] and not &1["expanded"]), "control: clamped")
    |> click_in_view(Query.css(card <> " .read-more-btn"))
    |> assert_state(card, &(not &1["overflows"] and &1["expanded"]), "text shown, card expanded")
  end

  defp long_post!(user) do
    Bonfire.Posts.Fake.fake_post!(user, "public", %{post_content: %{html_body: @long_body}})
  end

  # with its text clamped to 5 lines a post stays under the card cap, so only an image makes the card clip and show its Show more pill
  defp long_post_with_image!(user) do
    Bonfire.Posts.Fake.fake_post!(user, "public", %{
      post_content: %{html_body: @long_body},
      uploaded_media: [Bonfire.Social.Fake.upload_media(:images, user)]
    })
  end

  @trending "[data-id=trending_discussions]"
  @pinned "[data-id=instance_pinned_widget]"

  defp trending_card(post), do: "#{@trending} " <> card_of(post)

  defp card_of(post), do: "[data-carousel-card]:has([data-object_id='#{post.id}'])"

  # Signs in only once the posts exist: signing in lands on the dashboard, which caches the user's Top discussions for an hour. Then checks step by step, so a failure says whether the carousel, the card or its Read more is missing. Read more works only once the LiveView has connected and its hook has mounted, so the last step waits for that: before it, a click is lost.
  defp open_dashboard(session, user, card) do
    carousel = if String.starts_with?(card, @pinned), do: @pinned, else: @trending

    session
    |> Browser.visit(@endpoint.url() <> "/login")
    |> Browser.fill_in(Query.fillable_field("login_fields[email_or_username]"),
      with: user.character.username
    )
    |> Browser.fill_in(Query.fillable_field("login_fields[password]"), with: @password)
    |> Browser.click(Query.css("#login_submit_btn"))
    |> Browser.assert_has(Query.css(".phx-connected #sidebar-feeds-link"))
    |> Browser.visit(@endpoint.url() <> "/dashboard")
    |> Browser.assert_has(Query.css(carousel <> " [data-carousel-card]", minimum: 1))
    |> Browser.assert_has(Query.css(card, visible: :any))
    |> Browser.assert_has(Query.css(".phx-connected " <> card <> " .read-more-btn"))
  end

  # scrolls the control to the middle of the window first, as a user would: chromedriver's own scroll leaves a pill under a tall expanded card where its click dispatches no click event at all
  defp click_in_view(session, %Query{selector: selector} = query) do
    session
    |> Browser.execute_script(
      "document.querySelector(arguments[0]).scrollIntoView({block: 'center'})",
      [selector]
    )
    |> Browser.click(query)
  end

  defp state(session, card) do
    Browser.execute_script(
      session,
      """
      const card = document.querySelector(arguments[0]);
      const body = card.querySelector('[data-id=object_body]');
      return {
        overflows: body.scrollHeight > body.clientHeight + 1,
        expanded: card.hasAttribute('data-expanded'),
        clamped: card.hasAttribute('data-clamped'),
        maxHeight: getComputedStyle(card).maxHeight,
        height: card.offsetHeight,
        readLessShown: getComputedStyle(card.querySelector('.read-less-btn')).display !== 'none'
      };
      """,
      [card],
      &send(self(), {:card_state, &1})
    )

    receive do
      {:card_state, result} -> result
    end
  end

  # the hooks and observers settle after a click, so poll for up to 2 seconds
  defp assert_state(session, card, check, message, tries \\ 20) do
    result = state(session, card)

    cond do
      check.(result) ->
        session

      tries > 1 ->
        Process.sleep(100)
        assert_state(session, card, check, message, tries - 1)

      true ->
        flunk("#{message}: #{inspect(result)}")
    end
  end
end
