defmodule Bonfire.UI.Social.Threads.TimeGapTest do
  @moduledoc """
  Time-gap dividers between thread replies ("2 years later/earlier").

  Unit-tests the label computation (`ThreadBranchLive.time_gap_label/2` and
  `time_gap_before/3`), plus an integration pass through the top-level stream path
  (`LiveHandler.maybe_track_time_gaps/3`) using a genuinely backdated reply — reply ids
  are ULIDs, so a backdated `post_id` gives the reply an old timestamp.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Common.DatesTimes
  alias Bonfire.UI.Social.ThreadBranchLive

  describe "time_gap_label/2 (unit)" do
    test "close in time → no label" do
      now = DateTime.utc_now()
      assert ThreadBranchLive.time_gap_label(now, DateTime.add(now, 10 * 86_400)) == nil
    end

    test "months later" do
      now = DateTime.utc_now()
      label = ThreadBranchLive.time_gap_label(now, DateTime.add(now, 100 * 86_400))
      assert label =~ "3 months later"
    end

    test "a year later (singular)" do
      now = DateTime.utc_now()
      label = ThreadBranchLive.time_gap_label(now, DateTime.add(now, 400 * 86_400))
      assert label =~ "1 year later"
    end

    test "years later (plural)" do
      now = DateTime.utc_now()
      label = ThreadBranchLive.time_gap_label(now, DateTime.add(now, 800 * 86_400))
      assert label =~ "2 years later"
    end

    test "newest-first order reads as earlier" do
      now = DateTime.utc_now()
      label = ThreadBranchLive.time_gap_label(now, DateTime.add(now, -800 * 86_400))
      assert label =~ "2 years earlier"

      label = ThreadBranchLive.time_gap_label(now, DateTime.add(now, -100 * 86_400))
      assert label =~ "3 months earlier"
    end

    test "nil neighbours → no label" do
      assert ThreadBranchLive.time_gap_label(nil, DateTime.utc_now()) == nil
      assert ThreadBranchLive.time_gap_label(DateTime.utc_now(), nil) == nil
    end
  end

  describe "time_gap_before/3 (unit)" do
    test "without a parent, the first child never gets a divider" do
      assert ThreadBranchLive.time_gap_before(nil, [{%{id: "x"}, []}], 0) == nil
    end

    test "the first child is compared to the parent (necro reply to an old comment)" do
      old_id = DatesTimes.generate_ulid_if_past(DateTime.add(DateTime.utc_now(), -800 * 86_400))
      new_id = DatesTimes.generate_ulid_if_past(DateTime.add(DateTime.utc_now(), -60))

      assert ThreadBranchLive.time_gap_before(%{id: old_id}, [{%{id: new_id}, []}], 0) =~
               "2 years later"
    end

    test "later children are compared to the sibling above, via their ULID timestamps" do
      old_id = DatesTimes.generate_ulid_if_past(DateTime.add(DateTime.utc_now(), -800 * 86_400))
      new_id = DatesTimes.generate_ulid_if_past(DateTime.add(DateTime.utc_now(), -60))

      siblings = [{%{id: old_id}, []}, {%{id: new_id}, []}]
      assert ThreadBranchLive.time_gap_before(nil, siblings, 1) =~ "2 years later"
      # close siblings, even under an old parent → no divider
      close = [{%{id: new_id}, []}, {%{id: new_id}, []}]
      assert ThreadBranchLive.time_gap_before(%{id: old_id}, close, 1) == nil
    end
  end

  describe "in the thread view" do
    setup do
      account = fake_account!()
      alice = fake_user!(account)

      {:ok, op} =
        Posts.publish(
          current_user: alice,
          post_attrs: %{post_content: %{html_body: "<p>Original post</p>"}},
          boundary: "public"
        )

      {:ok, conn: conn(user: alice, account: account), alice: alice, op: op}
    end

    defp publish_reply(user, reply_to_id, body, attrs \\ %{}) do
      {:ok, post} =
        Posts.publish(
          current_user: user,
          # `post_id` (not just `post_attrs.id`) is what actually backdates — same as the Ghost importer
          post_id: attrs[:id],
          post_attrs:
            Map.merge(
              %{post_content: %{html_body: "<p>#{body}</p>"}, reply_to_id: reply_to_id},
              attrs
            ),
          boundary: "public"
        )

      post
    end

    test "a necro'd thread shows a divider above the much older reply", %{
      conn: conn,
      alice: alice,
      op: op
    } do
      old_id = DatesTimes.generate_ulid_if_past(DateTime.add(DateTime.utc_now(), -800 * 86_400))
      old_reply = publish_reply(alice, id(op), "ancient reply", %{id: old_id})
      # if the explicit id were silently dropped, the reply wouldn't be backdated and
      # the whole test would pass vacuously — fail loudly instead
      assert id(old_reply) == old_id
      _fresh_reply = publish_reply(alice, id(op), "fresh reply")

      conn
      |> visit("/post/#{id(op)}")
      |> assert_has("[data-role='time-gap']", text: "2 years earlier")
      # the divider belongs to the older reply's branch
      |> assert_has("#nested_#{id(old_reply)} [data-role='time-gap']")
    end

    test "a thread with only recent replies shows no dividers", %{
      conn: conn,
      alice: alice,
      op: op
    } do
      publish_reply(alice, id(op), "reply one")
      publish_reply(alice, id(op), "reply two")

      conn
      |> visit("/post/#{id(op)}")
      |> assert_has("[data-id='comment']", text: "reply one")
      |> refute_has("[data-role='time-gap']")
    end
  end
end
