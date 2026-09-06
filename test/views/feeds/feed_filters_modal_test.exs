defmodule Bonfire.UI.Social.FeedFiltersModal.Test do
  @moduledoc "Integration coverage for the inline feed-customization widget and advanced editor."
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Social.Boosts
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

  # Expands the advanced-filters editor inline via the customize-feed sidebar widget. NB the trigger is a toggle: calling this while already open collapses (and unmounts) the editor.
  defp open_filters_modal(session) do
    session
    |> wait_async()
    |> click_button("[data-role=open_modal]", "More filters")
  end

  defp apply_filters(session) do
    session
    |> click_button("Apply filters")
    |> wait_async()
  end

  test "user profiles do not receive feed preferences", %{conn: conn, other_user: user} do
    conn
    |> visit("/@#{user.character.username}")
    |> wait_async()
    |> assert_has("[data-id=profile]")
    |> refute_has("[data-id=widget_customize_feed]")
  end

  test "group profiles retain their About widget", %{conn: conn, user: user} do
    group = Bonfire.Classify.Simulate.fake_group!(user, %{name: "Sidebar ownership group"})

    conn
    |> visit("/&#{group.character.username}/discussions")
    |> wait_async()
    |> assert_has("[data-id=group]")
    |> assert_has("aside", text: "Who can join")
    |> assert_has("aside", text: "Who can see")
    |> assert_has("aside", text: "Who can post")
    |> refute_has("[data-id=widget_customize_feed]")
  end

  describe "filter modal opens and displays sections" do
    test "opening advanced filters shows all sections", %{conn: conn} do
      conn
      |> visit("/feed/my")
      |> open_filters_modal()
      |> assert_has("h4", text: "Time range")
      |> refute_has("[data-row=sort_order]")
      |> assert_has("h4", text: "Content types")
      |> assert_has("h4", text: "Activity types")
      |> assert_has("h4", text: "Media")
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

    test "time filter remains selected after applying", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Last Week")
      |> apply_filters()
      # the inline editor stays open after applying
      |> assert_has("[data-row=time_range] [data-role=row_value]", text: "Last Week")
    end
  end

  describe "sort order filter" do
    test "selecting Oldest first changes feed order", %{conn: conn, user: user} do
      _first_post =
        fake_post!(user, "public", %{
          post_content: %{html_body: "first post"},
          id: DatesTimes.past(2, :day) |> DatesTimes.generate_ulid()
        })

      _second_post =
        fake_post!(user, "public", %{
          post_content: %{html_body: "second post"},
          id: DatesTimes.now() |> DatesTimes.generate_ulid()
        })

      conn
      |> visit("/feed/local")
      |> wait_async()
      |> PhoenixTest.select("Order", option: "Oldest first")
      |> wait_async()
      |> assert_has("[data-id=feed] article:first-child", text: "first post")
      |> assert_has("select[name=feed_order] option[value=oldest][selected]")
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

  describe "scope override toggles" do
    test "customize widget uses positive inclusion toggles", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> wait_async()
      |> assert_has("[data-role=calm_override_group]", text: "Group activities")
      |> assert_has("[data-role=calm_override_group]", text: "Replies")
      |> assert_has("[data-role=calm_override_group]", text: "Boosts")
      |> assert_has("input[name='scope[replies]'][type=checkbox]:checked")
      |> assert_has("input[name='scope[boosts]'][type=checkbox]:checked")
    end

    test "group activities can be excluded and restored", %{conn: conn} do
      conn
      |> visit("/feed/my")
      |> wait_async()
      |> assert_has("input[name='scope[group_activity]'][type=checkbox]:checked")
      |> uncheck("Group activities")
      |> wait_async()
      |> assert_has("input[name='scope[group_activity]'][type=checkbox]:not(:checked)")
      |> check("Group activities")
      |> wait_async()
      |> assert_has("input[name='scope[group_activity]'][type=checkbox]:checked")
    end

    test "ordering and inclusion compose independently", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> wait_async()
      |> uncheck("Replies")
      |> PhoenixTest.select("Order", option: "Most replied")
      |> wait_async()
      |> assert_has("select[name=feed_order] option[value=reply_count][selected]")
      |> refute_has("form[id^=feed_range_form]")
      |> assert_has("input[name='scope[replies]']:not(:checked)")
      |> assert_has("input[name='scope[boosts]']:checked")
      |> check("Replies")
      |> wait_async()
      |> assert_has("select[name=feed_order] option[value=reply_count][selected]")
    end

    test "inclusion choices preserve ordering", %{conn: conn} do
      conn
      |> visit("/feed/explore")
      |> wait_async()
      |> PhoenixTest.select("Order", option: "Oldest first")
      |> open_filters_modal()
      |> refute_has("button", text: "Focus: hide replies and boosts")
      |> uncheck("Replies")
      |> wait_async()
      |> uncheck("Boosts")
      |> wait_async()
      |> assert_has("select[name=feed_order] option[value=oldest][selected]")
      |> assert_has("input[name='scope[replies]']:not(:checked)")
      |> assert_has("input[name='scope[boosts]']:not(:checked)")
      |> assert_has("select[name=feed_order] option[value=oldest][selected]")
      |> check("Replies")
      |> wait_async()
      |> assert_has("select[name=feed_order] option[value=oldest][selected]")
    end

    test "reset restores the current feed defaults", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> wait_async()
      |> uncheck("Replies")
      |> PhoenixTest.select("Order", option: "Most boosted")
      |> open_filters_modal()
      |> click_button("Reset feed preferences")
      |> wait_async()
      |> assert_has("select[name=feed_order] option[value=newest][selected]")
      |> assert_has("input[name='scope[replies]']:checked")
      |> refute_has("select[name=time_limit]")
    end

  end

  describe "applied filters" do
    test "active time filter is available in the modal after applying", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Last Month")
      |> apply_filters()
      |> assert_has("[data-row=time_range] [data-role=row_value]", text: "Last Month")
    end

    test "exclude boost filter hides boost activities", %{
      conn: conn,
      user: user,
      other_user: other_user
    } do
      original_post =
        fake_post!(other_user, "public", %{
          post_content: %{html_body: "boost filter original post"}
        })

      assert {:ok, _follow} = Bonfire.Social.Graph.Follows.follow(user, other_user)
      assert {:ok, _boost} = Boosts.boost(user, original_post)

      # Following includes both outboxes; locality feeds do not contain the boost entry.
      conn
      |> visit("/feed/my")
      |> wait_async()
      |> assert_has("[data-id=feed] [data-role=boosted_by]")
      |> open_filters_modal()
      |> click_button("[data-toggle='boost'] button", "Hide")
      |> apply_filters()
      |> refute_has("[data-id=feed] [data-role=boosted_by]")
      |> assert_has("[data-id=feed] article", text: "boost filter original post")
      |> assert_has("[data-toggle=boost][data-state=hide]")
    end
  end

  describe "save as custom feed" do
    test "user can save current filters as a feed preset", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Last Week")
      |> apply_filters()
      |> fill_in("Feed title", with: "weekly-filter-review")
      |> click_button("Save feed")
      |> assert_has("[data-id=flash_info]", text: "Feed created successfully")
      |> visit("/settings/user/feeds")
      |> assert_has("div", text: "weekly-filter-review")
      |> visit("/feed/weekly-filter-review")
      |> open_filters_modal()
      |> assert_has("[data-row=time_range] [data-role=row_value]", text: "Last Week")
    end
  end

  describe "modal state is local until Apply" do
    test "toggling filters in modal does not reload feed", %{
      conn: conn,
      user: user
    } do
      fake_post!(user, "public", %{
        post_content: %{html_body: "visible post"},
        id: DatesTimes.past(2, :day) |> DatesTimes.generate_ulid()
      })

      conn
      |> visit("/feed/local")
      |> assert_has("[data-id=feed] article", text: "visible post")
      |> open_filters_modal()
      # Toggle a filter — feed should NOT change yet
      |> click_button("Last Day")
      |> assert_has("button.btn-primary", text: "Last Day")
      |> assert_has("[data-id=feed] article", text: "visible post")
      |> apply_filters()
      |> refute_has("[data-id=feed] article", text: "visible post")
    end
  end

  describe "Reset all" do
    test "header Reset discards pending edits even when applied filters already match defaults", %{conn: conn} do
      Process.put(Bonfire.Common.Config.keys_tree([Bonfire.UI.Social.FeedLive, :time_limit]), 30)

      conn
      |> visit("/feed/local")
      |> wait_async()
      |> click_button("Reset feed preferences")
      |> open_filters_modal()
      |> click_button("Last Day")
      |> click_button("Reset feed preferences")
      |> wait_async()
      |> assert_has("[data-row=time_range] [data-role=row_value]", text: "Last Month")
      |> apply_filters()
      |> assert_has("[data-row=time_range] [data-role=row_value]", text: "Last Month")
    end

    test "header Reset restores the configured time window and sort order", %{conn: conn, user: user} do
      Process.put(Bonfire.Common.Config.keys_tree([Bonfire.UI.Social.FeedLive, :time_limit]), 7)

      fake_post!(user, "public", %{
        post_content: %{html_body: "reset restores this older post"},
        id: DatesTimes.past(2, :day) |> DatesTimes.generate_ulid()
      })

      fake_post!(user, "public", %{
        post_content: %{html_body: "outside the configured default window"},
        id: DatesTimes.past(60, :day) |> DatesTimes.generate_ulid()
      })

      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> PhoenixTest.select("Order", option: "Oldest first")
      |> wait_async()
      |> click_button("Last Day")
      |> apply_filters()
      |> refute_has("[data-id=feed] article", text: "reset restores this older post")
      |> click_button("Reset feed preferences")
      |> wait_async()
      |> assert_has("[data-id=feed] article", text: "reset restores this older post")
      |> refute_has("[data-id=feed] article", text: "outside the configured default window")
      |> assert_has("[data-row=time_range] [data-role=row_value]", text: "Last Week")
      |> assert_has("select[name=feed_order] option[value=newest][selected]")
    end

    test "More filters has no additional Reset button", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("Last Week")
      |> refute_has("[data-role=reset_filters]")
      |> assert_has("button[aria-label='Reset feed preferences']")
    end

  end

  describe "Content origin radio group" do
    # the label id is prefixed with the component id (the editor can mount twice on a page)
    @origin_scope "[role=radiogroup][aria-labelledby$='_origin_label']"

    # `/feed/my` is the home feed — it has no fixed-origin preset, so the
    # origin radiogroup renders. `/feed/local` would render the read-only
    # fixed-origin badges instead, and this test would find no radio buttons.
    test "defaults to Both and switches to Local/Remote", %{conn: conn} do
      conn
      |> visit("/feed/my")
      |> open_filters_modal()
      |> assert_has("#{@origin_scope} [role=radio][aria-checked='true']", text: "Anywhere")
      |> click_button("#{@origin_scope} [role=radio]", "This instance")
      |> assert_has("#{@origin_scope} [role=radio][aria-checked='true']", text: "This instance")
      |> click_button("#{@origin_scope} [role=radio]", "Other instances")
      |> assert_has("#{@origin_scope} [role=radio][aria-checked='true']", text: "Other instances")
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
    test "Reset counts the current user's exclusion once", %{user: user} do
      html =
        render_component(Bonfire.UI.Social.FeedFiltersModalContentLive, %{
          id: "reset_count_editor",
          __context__: %{current_user: user},
          feed_filters: %{exclude_subjects: [user.id]},
          sections: [:hide_own],
          show_reset: true
        })

      assert html |> Floki.parse_fragment!() |> Floki.find("[data-role=reset_filters]") |> Floki.text() |> String.trim() == "Reset 1"
    end

    test "Hide my own activities updates the checkbox", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> check("Hide my own activities")
      |> assert_has("[data-row=hide_own] input[type=checkbox][checked]")
      |> refute_has("[data-role=reset_filters]")
    end
  end

  describe "advanced filters expander (customize-feed widget)" do
    # The sidebar widget reveals the same filters editor inline (OpenExpanderLive)
    # instead of in the modal singleton; the editor must only mount while expanded.
    test "expands inline, stays open after apply, and unmounts on collapse", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> wait_async()
      # trigger row is there, but the (stateful) editor is not mounted yet
      |> assert_has("[data-role=feed_advanced_filters]")
      |> refute_has("button", text: "Apply filters")
      # expanding mounts the editor inline
      |> click_button("[data-role=open_modal]", "More filters")
      |> assert_has("button[aria-expanded='true'] [data-role=feed_advanced_filters]")
      |> assert_has("button", text: "Apply filters")
      # applying reloads the feed but the expander stays open
      |> click_button("Last Day")
      |> apply_filters()
      |> assert_has("button", text: "Apply filters")
      # collapsing unmounts the editor again
      |> click_button("[data-role=open_modal]", "More filters")
      |> assert_has("button[aria-expanded='false'] [data-role=feed_advanced_filters]")
      |> refute_has("button", text: "Apply filters")
      |> click_button("[data-role=open_modal]", "More filters")
      |> assert_has("[data-row=time_range] [data-role=row_value]", text: "Last Day")
    end
  end

  describe "collapsed section summaries" do
    test "Content types summary updates to '1 only' after isolating Articles", %{conn: conn} do
      conn
      |> visit("/feed/local")
      |> open_filters_modal()
      |> click_button("[data-toggle='article'] button", "Only")
      |> assert_has("[data-row=object_types] summary [data-role=row_value]", text: "1 only")
    end
  end
end
