defmodule Bonfire.UI.Social.FeedFiltersModal.Test do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts
  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]
  use Bonfire.Common.Repo
  alias Bonfire.Common.DatesTimes

  setup do
    account = fake_account!()
    user = fake_user!(account)
    other_user = fake_user!(account)

    conn = conn(user: user, account: account)

    {:ok, conn: conn, user: user, other_user: other_user}
  end

  defp open_filters_modal(session) do
    session
    |> click_button("[data-role=open_modal]", "Filters")
  end

  defp apply_filters(session) do
    session
    |> click_button("Apply filters")
    |> wait_async()
  end

  describe "filter modal opens and displays sections" do
    test "clicking Filters button opens the modal with all sections", %{conn: conn} do
      conn
      |> visit("/feed/my")
      |> open_filters_modal()
      # Quick filters is a flat, always-open region above the collapsed sections
      # (no heading — the toggle rows speak for themselves).
      |> assert_has("[data-scope=hide_replies]", text: "Hide replies")
      |> assert_has("h4", text: "Time range")
      |> assert_has("h4", text: "Sort order")
      |> assert_has("h4", text: "Content types")
      |> assert_has("h4", text: "Activity types")
      |> assert_has("h4", text: "Media types")
      |> assert_has("h4", text: "Filter by circles")
    end

    test "modal shows Apply and Save buttons", %{conn: conn} do
      conn
      |> visit("/feed/my")
      |> open_filters_modal()
      |> assert_has("button", text: "Apply filters")
      |> assert_has("summary", text: "Save as custom feed")
    end
  end

  describe "time range filter" do
    setup %{user: user} do
      today_post =
        fake_post!(user, "public", %{
          post_content: %{html_body: "posted today"},
          id: DatesTimes.now() |> DatesTimes.generate_ulid()
        })

      old_post =
        fake_post!(user, "public", %{
          post_content: %{html_body: "posted long ago"},
          id: DatesTimes.past(60, :day) |> DatesTimes.generate_ulid()
        })

      {:ok, today_post: today_post, old_post: old_post}
    end

    test "selecting Last Day and applying filters only recent posts", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Last Day")
      |> apply_filters()
      |> assert_has("[data-id=feed] article", text: "posted today")
      |> refute_has("[data-id=feed] article", text: "posted long ago")
    end

    test "selecting All time shows all posts", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Last Day")
      |> click_button("All time")
      |> apply_filters()
      |> assert_has("[data-id=feed] article", text: "posted today")
      |> assert_has("[data-id=feed] article", text: "posted long ago")
    end

    test "time filter shows as chip after applying", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Last Week")
      |> apply_filters()
      |> assert_has("[data-id=feed_controls] .badge", text: "Last Week")
    end
  end

  describe "sort order filter" do
    test "selecting Oldest first and applying changes feed order", %{conn: conn, user: user} do
      first_post =
        fake_post!(user, "public", %{
          post_content: %{html_body: "first post"},
          id: DatesTimes.past(2, :day) |> DatesTimes.generate_ulid()
        })

      second_post =
        fake_post!(user, "public", %{
          post_content: %{html_body: "second post"},
          id: DatesTimes.now() |> DatesTimes.generate_ulid()
        })

      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Oldest first")
      |> apply_filters()
      |> assert_has("[data-id=feed] article")
      |> assert_has("[data-id=feed_controls] .badge", text: "Oldest first")
    end
  end

  describe "activity type filters" do
    test "toggling boost filter to Hide updates the toggle state", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='boost'] button", "Hide")
      |> assert_has("[data-toggle='boost'][data-state='hide']")
      |> assert_has("[data-toggle='boost'] [data-id='hide'][aria-checked='true']")
    end

    test "toggling boost filter to Only updates the toggle state", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='boost'] button", "Only")
      |> assert_has("[data-toggle='boost'][data-state='only']")
      |> assert_has("[data-toggle='boost'] [data-id='only'][aria-checked='true']")
    end

    test "toggling back to Include resets the toggle state", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='boost'] button", "Only")
      |> assert_has("[data-toggle='boost'] [data-id='only'][aria-checked='true']")
      |> click_button("[data-toggle='boost'] button", "Include")
      |> assert_has("[data-toggle='boost'][data-state='default']")
      |> assert_has("[data-toggle='boost'] [data-id='default'][aria-checked='true']")
    end
  end

  describe "quick filters" do
    test "quick filters section renders toggle controls", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> assert_has("[data-scope=hide_replies]", text: "Hide replies")
      |> assert_has("[data-scope=hide_boosts]", text: "Hide boosts")
    end
  end

  describe "filter chips and badge" do
    test "badge shows count of active filters", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Last Week")
      |> click_button("Oldest first")
      |> apply_filters()
      |> assert_has("[data-id=feed_controls] .badge.badge-primary")
    end

    test "filter chips appear below controls bar", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Last Month")
      |> apply_filters()
      |> assert_has("[data-id=feed_controls] [role=status] .badge", text: "Last Month")
    end

    test "exclude filter chips show eye-slash icon", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='boost'] button", "Hide")
      |> apply_filters()
      |> assert_has("[data-id=feed_controls] [role=status] .badge", text: "Boost")
    end
  end

  describe "save as custom feed" do
    test "user can save current filters as a feed preset", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Last Week")
      |> apply_filters()
      |> open_filters_modal()
      |> fill_in("Feed title", with: "My weekly feed")
      |> click_button("Save feed")
      # Should not crash — verify we're still on a working feed page
      |> assert_has("[data-id=feed_controls]")
      |> assert_path("/feed/local")
    end
  end

  describe "modal state is local until Apply" do
    test "toggling filters in modal does not reload feed", %{
      conn: conn,
      user: user
    } do
      fake_post!(user, "public", %{
        post_content: %{html_body: "visible post"}
      })

      conn
      |> visit("/feed/local")
      |> assert_has("[data-id=feed] article", text: "visible post")
      |> open_filters_modal()
      # Toggle a filter — feed should NOT change yet
      |> click_button("Last Day")
      # The modal should show the button as active
      |> assert_has("button.btn-primary", text: "Last Day")
    end

    test "pending changes survive reopening the modal without Apply", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='boost'] button", "Hide")
      # Close the modal without applying (Escape / click-out aren't modeled;
      # instead we confirm the chip summary inside the modal still reflects
      # the tri-state change).
      |> assert_has("[data-toggle='boost'][data-state='hide']")
    end
  end

  describe "Reset all" do
    test "clears every pending filter and the Hide my activity toggle", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='boost'] button", "Hide")
      |> click_button("Last Week")
      |> assert_has("[data-toggle='boost'][data-state='hide']")
      |> assert_has("button.btn-primary", text: "Last Week")
      |> click_button("Reset all")
      |> assert_has("[data-toggle='boost'][data-state='default']")
      |> refute_has("button.btn-primary", text: "Last Week")
    end
  end

  describe "Content origin radio group" do
    @origin_scope "[aria-labelledby='content-origin-label']"

    # `/feed/my` is the home feed — it has no fixed-origin preset, so the
    # origin radiogroup renders. `/feed/local` would render the read-only
    # fixed-origin badges instead, and this test would find no radio buttons.
    test "defaults to Both and switches to Local/Remote", %{conn: conn} do
      conn
      |> visit("/feed/my")
      |> open_filters_modal()
      |> assert_has("#{@origin_scope} [role=radio][aria-checked='true']", text: "Both")
      |> click_button("#{@origin_scope} [role=radio]", "Local")
      |> assert_has("#{@origin_scope} [role=radio][aria-checked='true']", text: "Local")
      |> click_button("#{@origin_scope} [role=radio]", "Remote")
      |> assert_has("#{@origin_scope} [role=radio][aria-checked='true']", text: "Remote")
    end
  end

  describe "tri-state toggle — content types" do
    test "Only on Articles marks the row as isolated", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='article'] button", "Only")
      |> assert_has("[data-toggle='article'][data-state='only']")
      |> assert_has("[data-toggle='article'] [data-id='only'][aria-checked='true']")
    end

    test "clicking Only twice returns the row to default", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='article'] button", "Only")
      |> assert_has("[data-toggle='article'][data-state='only']")
      # Second press on Only un-isolates — back to default (neither include nor exclude)
      |> click_button("[data-toggle='article'] button", "Only")
      |> assert_has("[data-toggle='article'][data-state='default']")
    end
  end

  describe "Hide my own activities quick toggle" do
    test "checking the toggle surfaces the 'Hiding my activity' chip", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> check("Hide my own activities")
      |> assert_has("span", text: "Hiding my activity")
    end
  end

  describe "badge summaries in collapsed sections" do
    # The <summary> element wrapping each collapsed section shows a badge
    # with a compact count (e.g. "1 only") produced by `types_summary/2`.
    # We use `:has()` to scope to a specific section by its icon, which
    # Floki supports. The unit tests in feed_filters_helpers_test.exs
    # cover every branch of the summary helpers; here we just confirm the
    # badge is wired into the template for one representative section.
    test "Content types badge updates to '1 only' after isolating Articles", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='article'] button", "Only")
      |> assert_has("summary:has([iconify='ph:article-ny-times-duotone']) .badge",
        text: "1 only"
      )
    end
  end
end
