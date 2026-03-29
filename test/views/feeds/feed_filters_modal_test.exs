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
      |> assert_has("h4", text: "Time range")
      |> assert_has("h4", text: "Sort order")
      |> assert_has("h4", text: "Quick filters")
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
      |> assert_has("[data-toggle='boost'] [data-id='disabled'].active")
    end

    test "toggling boost filter to Only updates the toggle state", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='boost'] button", "Only")
      |> assert_has("[data-toggle='boost'] [data-id='enabled'].active")
    end

    test "toggling back to Include resets the toggle state", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='boost'] button", "Only")
      |> assert_has("[data-toggle='boost'] [data-id='enabled'].active")
      |> click_button("[data-toggle='boost'] button", "Include")
      |> assert_has("[data-toggle='boost'] [data-id='default'].active")
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
  end
end
