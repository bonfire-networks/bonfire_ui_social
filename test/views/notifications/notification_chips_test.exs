defmodule Bonfire.UI.Social.NotificationChipsTest do
  @moduledoc """
  Category chips on the notifications feed.

  Each chip is a URL (`/notifications/<verb>`, with plural path aliases), declared in config,
  and a segment resolves against the verb registry so any declared verb works whether or not a
  chip is shown for it.
  """
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.UI.Social.NotificationFiltersLive

  setup do
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)

    # the test default is 2, which would cut the oldest fixture off the unfiltered feed's first page
    Process.put([:bonfire, :default_pagination_limit], 10)

    me = fake_user!("chips_me")
    other = fake_user!("chips_other")

    {:ok, my_post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "my post that gets liked"}},
        boundary: "public"
      )

    {:ok, _like} = Likes.like(other, my_post)
    {:ok, _follow} = Follows.follow(other, me)

    {:ok, _mention} =
      Posts.publish(
        current_user: other,
        post_attrs: %{
          post_content: %{html_body: "hey @#{me.character.username} a mention for you"}
        },
        boundary: "public"
      )

    {:ok, conn: conn(user: me, account: me.account), me: me, other: other}
  end

  test "the unfiltered feed shows every notification and marks the Latest chip current", %{
    conn: conn
  } do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("#notification-filter-latest[aria-current=page]")
    |> assert_has("[data-verb=like]")
    |> assert_has("[data-verb=follow]")
    |> assert_has("[data-id=feed]", text: "a mention for you")
  end

  test "a chip path filters the feed to that verb and marks that chip current", %{conn: conn} do
    conn
    |> visit("/notifications/likes")
    |> wait_async()
    |> assert_has("#notification-filter-react[aria-current=page]")
    |> assert_has("[data-verb=like]")
    |> refute_has("#notification-filter-latest[aria-current=page]")
    |> refute_has("[data-verb=follow]")
  end

  test "chips link to their plural path, with the bare verb still resolving", %{conn: conn} do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("#notification-filter-react[href='/notifications/reactions']")

    conn
    |> visit("/notifications/like")
    |> wait_async()
    |> assert_has("#notification-filter-react[aria-current=page]")
    |> assert_has("[data-verb=like]")
    |> refute_has("[data-verb=follow]")
  end

  test "clicking a chip filters the already-loaded feed, and clicking Latest restores it", %{
    conn: conn
  } do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> click_link("#notification-filter-react", "Reactions")
    |> wait_async()
    |> assert_path("/notifications/reactions")
    |> assert_has("[data-verb=like]")
    |> refute_has("[data-verb=follow]")
    |> click_link("#notification-filter-latest", "Latest")
    |> wait_async()
    |> assert_path("/notifications")
    |> assert_has("[data-verb=follow]")
  end

  test "a chip with no matching notifications says so, and going back restores the feed",
       %{conn: conn} do
    conn
    |> visit("/notifications")
    |> wait_async()
    # nothing in the fixtures is a boost
    |> click_link("#notification-filter-boost", "Boosts")
    |> wait_async()
    # the notifications preset queries a 30-day window, so the answer names the window and offers to look further back, rather than the preset's "You have no notifications", which would claim more than the query asked
    |> assert_has("[data-id=feed]", text: "Last 30 days")
    |> assert_has("[data-id=load_all_time]", text: "Show older activities")
    |> refute_has("[data-verb=like]")
    |> click_link("#notification-filter-latest", "Latest")
    |> wait_async()
    |> assert_has("[data-verb=like]")
    |> assert_has("[data-verb=follow]")
  end

  test "a preset-backed chip is hidden from users the preset's own gate excludes", %{conn: conn} do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("#notification-filter-react")
    |> refute_has("#notification-filter-flag")
  end

  test "a moderator sees the preset-backed chip, and it loads that preset's feed" do
    admin = fake_admin!(fake_account!())
    flagger = fake_user!("chips_flagger")

    {:ok, post} =
      Posts.publish(
        current_user: flagger,
        post_attrs: %{post_content: %{html_body: "something worth flagging"}},
        boundary: "public"
      )

    {:ok, _flag} = Bonfire.Social.Flags.flag(flagger, post)

    conn(user: admin, account: admin.account)
    |> visit("/notifications")
    |> wait_async()
    |> click_link("#notification-filter-flag", "Flagged")
    |> wait_async()
    |> assert_path("/notifications/flags")
    # the chip bar survives the preset switch, so the moderator can get back
    |> assert_has("#notification-filter-latest")
    |> assert_has("[data-id=feed]", text: "something worth flagging")
  end

  test "a declared verb resolves even with no chip shown for it", %{conn: conn} do
    conn
    |> visit("/notifications/follow")
    |> wait_async()
    |> assert_has("[data-verb=follow]")
    |> refute_has("[data-verb=like]")
  end

  test "a segment matching no verb redirects to the unfiltered feed", %{conn: conn} do
    conn
    |> visit("/notifications/not-a-verb")
    |> wait_async()
    |> assert_path("/notifications")
    |> assert_has("#notification-filter-latest[aria-current=page]")
    |> assert_has("[data-verb=like]")
  end

  test "chips render from config, in config order, falling back to the key for the path" do
    Process.put(
      [:bonfire_social, Bonfire.Social.Notifications, :categories],
      latest: %{name_pluralized: "Everything", activity_types: []},
      like: %{name_pluralized: "Faves"}
    )

    doc =
      render_component(&NotificationFiltersLive.render/1, %{__context__: %{}})
      |> Floki.parse_document!()

    assert Floki.attribute(doc, "#notification-filters a", "href") == [
             "/notifications",
             "/notifications/like"
           ]

    assert Floki.find(doc, "#notification-filter-like") |> Floki.text() =~ "Faves"
    assert Floki.find(doc, "#notification-filter-latest") |> Floki.text() =~ "Everything"
    assert [] = Floki.find(doc, "#notification-filter-boost")
  end

  describe "Mentions" do
    # a mention is a Tagged row pointing at the person named, whatever kind of post carries it, so the chip asks that rather than which verb stored the post: a reply that names you is a mention too
    setup %{me: me, other: other} do
      {:ok, my_post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "my post that gets answered"}},
          boundary: "public"
        )

      {:ok, _} =
        Posts.publish(
          current_user: other,
          post_attrs: %{
            post_content: %{html_body: "answering and naming @#{me.character.username} too"},
            reply_to_id: my_post.id
          },
          boundary: "public"
        )

      bystander = fake_user!("chips_bystander")

      {:ok, _} =
        Posts.publish(
          current_user: other,
          post_attrs: %{
            post_content: %{
              html_body: "answering but naming @#{bystander.character.username} instead"
            },
            reply_to_id: my_post.id
          },
          boundary: "public"
        )

      :ok
    end

    test "shows posts and replies that name me", %{conn: conn} do
      conn
      |> visit("/notifications/mentions")
      |> wait_async()
      |> assert_has("#notification-filter-mention[aria-current=page]")
      |> assert_has("[data-id=feed]", text: "a mention for you")
      |> assert_has("[data-id=feed]", text: "answering and naming")
    end

    test "a reply that names me is not under Replies (without mentioning you), since it is a mention",
         %{conn: conn} do
      # the other reply is the positive: it is there, so this one's absence is the filter's doing
      conn
      |> visit("/notifications/replies")
      |> wait_async()
      |> assert_has("#notification-filter-extra_replies[aria-current=page]")
      |> assert_has("[data-id=feed]", text: "answering but naming")
      |> refute_has("[data-id=feed]", text: "answering and naming")
    end

    test "leaves out a reply to me that names somebody else, which Replies still shows", %{
      conn: conn
    } do
      # the positive first, so the refute below cannot pass just because the reply never arrived
      conn
      |> visit("/notifications/replies")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "answering but naming")

      conn
      |> visit("/notifications/mentions")
      |> wait_async()
      |> refute_has("[data-id=feed]", text: "answering but naming")
    end

    test "leaves out what names nobody, like a like", %{conn: conn} do
      conn
      |> visit("/notifications/mentions")
      |> wait_async()
      |> refute_has("[data-verb=like]")
      |> refute_has("[data-verb=follow]")
    end
  end

  describe "Other" do
    # a vote on my poll reaches my notifications, and the `vote` category has no chip, so it is exactly what Other exists for
    setup %{me: me, other: other} do
      {:ok, question} =
        Bonfire.Poll.Fake.fake_question_with_choices(
          %{
            post_content: %{html_body: "a poll of mine"},
            voting_format: "single",
            voting_dates: [DateTime.utc_now()]
          },
          [%{name: "alpha"}, %{name: "beta"}],
          current_user: me,
          boundary: "public"
        )

      {:ok, _} =
        Bonfire.Poll.Votes.vote(other, question, [
          %{choice_id: hd(question.choices).id, weight: 1}
        ])

      :ok
    end

    test "shows what no other chip covers, and none of what they do", %{conn: conn} do
      # the positive first: the vote did arrive, so its absence elsewhere is the chips' doing
      conn
      |> visit("/notifications")
      |> wait_async()
      |> assert_has("[data-verb=vote]")

      conn
      |> visit("/notifications/other")
      |> wait_async()
      |> assert_has("#notification-filter-other[aria-current=page]")
      |> assert_has("[data-verb=vote]")
      |> refute_has("[data-verb=like]")
      |> refute_has("[data-verb=follow]")
      |> refute_has("[data-id=feed]", text: "a mention for you")
    end

    test "a vote is under none of the named chips", %{conn: conn} do
      for path <- ["mentions", "replies", "reactions", "boosts", "requests"] do
        conn
        |> visit("/notifications/#{path}")
        |> wait_async()
        |> refute_has("[data-verb=vote]")
      end
    end
  end

  describe "Requests" do
    # somebody whose follows arrive as asks, which is the followed person's own setting, and three people asking: one to follow still waiting, one to follow set aside, and one to quote already accepted
    setup do
      account = fake_account!()
      asked = Bonfire.Me.Fake.fake_user!(account, %{}, request_before_follow: true)

      {:ok, _} = Follows.follow(fake_user!("Patient Asker"), asked)
      {:ok, ignored} = Follows.follow(fake_user!("Ignored Asker"), asked)
      {:ok, _} = Follows.ignore(ignored, current_user: asked)

      {:ok, quoted} =
        Posts.publish(
          current_user: asked,
          post_attrs: %{post_content: %{html_body: "worth quoting"}},
          boundary: "public"
        )

      {:ok, quoting} =
        Posts.publish(
          current_user: fake_user!("Accepted Quoter"),
          post_attrs: %{post_content: %{html_body: "quoting it"}},
          boundary: "public",
          quotes: [quoted]
        )

      {:ok, _} = Bonfire.Social.Quotes.accept_quote(quoting, quoted, current_user: asked)

      {:ok, asked_conn: conn(user: asked, account: account)}
    end

    @tag skip:
           "the chip shows every ask whatever its status, so an accepted one stays reachable, for example to take back a quote permission"
    test "shows the asks still waiting, and not one already set aside", %{asked_conn: conn} do
      conn
      |> visit("/notifications/requests")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "Patient Asker")
      |> refute_has("[data-id=feed]", text: "Ignored Asker")
    end

    test "shows every ask, whatever its status", %{asked_conn: conn} do
      conn
      |> visit("/notifications/requests")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "Patient Asker")
      |> assert_has("[data-id=feed]", text: "Ignored Asker")
      |> assert_has("[data-id=feed]", text: "Accepted Quoter")
    end

    test "Latest still shows the one set aside, since leaving answered asks out is not the default",
         %{asked_conn: conn} do
      conn
      |> visit("/notifications")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "Patient Asker")
      |> assert_has("[data-id=feed]", text: "Ignored Asker")
    end
  end
end
