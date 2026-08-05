defmodule Bonfire.UI.Social.Feeds.ProfileShowOlderActivitiesTest do
  @moduledoc """
  A profile is an archive, not a timeline: the `user_activities` preset sets
  `time_limit: 0` so a profile shows a user's full history (paginated) instead
  of a 7-day window with a dead-end "Show older activities" button (which on
  profiles with a single recent activity used to end up hiding even that one,
  see the jacobin.social report of 2026-08-05).
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui
  use Bonfire.Common.Config
  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]
  alias Bonfire.Common.DatesTimes

  describe "profile feed time window" do
    setup do
      original_config = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
      # deferred joins ON, like production defaults (the bug reported on jacobin.social
      # happened with default config)
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], true)

      repo().delete_all(Bonfire.Data.Social.FeedPublish)

      account = fake_account!()
      alice = fake_user!(account)

      on_exit(fn ->
        Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_config)
      end)

      %{account: account, alice: alice}
    end

    test "shows activities older than 7 days on initial load (no time window)",
         %{account: account, alice: alice} do
      fake_post!(alice, "public", %{
        post_content: %{
          summary: "recent post",
          html_body: "<p>Recent activity</p>"
        },
        id: DatesTimes.past(2, :day) |> DatesTimes.generate_ulid()
      })

      fake_post!(alice, "public", %{
        post_content: %{
          summary: "month old post",
          html_body: "<p>Month-old activity</p>"
        },
        id: DatesTimes.past(30, :day) |> DatesTimes.generate_ulid()
      })

      me = fake_user!(account)
      conn = conn(user: me, account: account)

      conn
      |> visit("/@#{alice.character.username}")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Recent activity")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Month-old activity")
      # no time-window dead end on profiles
      |> refute_has("[data-id=load_all_time]")
    end

    test "a single recent activity never disappears when paginating",
         %{account: account, alice: alice} do
      fake_post!(alice, "public", %{
        post_content: %{
          summary: "recent post",
          html_body: "<p>Only recent activity</p>"
        },
        id: DatesTimes.past(2, :day) |> DatesTimes.generate_ulid()
      })

      me = fake_user!(account)
      conn = conn(user: me, account: account)

      session =
        conn
        |> visit("/@#{alice.character.username}")
        |> assert_has_or_open_browser("[data-id=feed] article [data-id=object_body]", count: 1)
        |> assert_has_or_open_browser("[data-id=feed] article", text: "Only recent activity")

      # if a (dead-end) Load more cursor is rendered, following it must not
      # remove the already-visible activity
      session =
        try do
          session
          |> click_button("[data-id=load_more]", "Load more")
          |> wait_async()
        rescue
          # no pagination button rendered at all: nothing to click, all good
          ArgumentError -> session
        end

      session
      |> assert_has_or_open_browser("[data-id=feed] article [data-id=object_body]", count: 1)
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Only recent activity")
    end
  end
end
