defmodule Bonfire.UI.Social.ReadingPositionsTest do
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Common.Settings
  alias Bonfire.Social.Markers
  alias Bonfire.UI.Social.FeedLive
  alias Bonfire.Social.Feeds.LiveHandler

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, account: account, me: me}
  end

  describe "reading_position_updated event (save gate)" do
    test "stores a valid cursor for the current chronological feed", %{account: account, me: me} do
      cursor = cursor_id()
      socket = socket(account, me, feed_name: :my, feed_filters: %{})

      assert {:noreply, _socket} =
               LiveHandler.handle_event(
                 "reading_position_updated",
                 %{"feed_name" => "my", "cursor" => cursor},
                 socket
               )

      assert Markers.get_reading_position(me, "my") == cursor
    end

    test "does not store when marker tracking is disabled in settings", %{
      account: account,
      me: me
    } do
      {:ok, %{__context__: %{current_user: me}}} =
        Settings.put([Bonfire.Social.Markers, :enabled], false,
          current_user: me,
          scope: :user
        )

      cursor = cursor_id()
      socket = socket(account, me, feed_name: :my, feed_filters: %{})

      assert {:noreply, _socket} =
               LiveHandler.handle_event(
                 "reading_position_updated",
                 %{"feed_name" => "my", "cursor" => cursor},
                 socket
               )

      refute Markers.get_reading_position(me, "my")
    end

    test "does not store when marker tracking is disabled on the feed", %{
      account: account,
      me: me
    } do
      cursor = cursor_id()
      socket = socket(account, me, feed_name: :my, feed_filters: %{}, enable_marker: false)

      assert {:noreply, _socket} =
               LiveHandler.handle_event(
                 "reading_position_updated",
                 %{"feed_name" => "my", "cursor" => cursor},
                 socket
               )

      refute Markers.get_reading_position(me, "my")
    end

    test "does not store for non-chronological filters", %{account: account, me: me} do
      cursor = cursor_id()
      socket = socket(account, me, feed_name: :my, feed_filters: %{sort_by: :reply_count})

      assert {:noreply, _socket} =
               LiveHandler.handle_event(
                 "reading_position_updated",
                 %{"feed_name" => "my", "cursor" => cursor},
                 socket
               )

      refute Markers.get_reading_position(me, "my")
    end

    test "does not store for ascending chronological filters", %{account: account, me: me} do
      cursor = cursor_id()

      socket =
        socket(account, me,
          feed_name: :my,
          feed_filters: %{sort_by: :date_created, sort_order: :asc}
        )

      assert {:noreply, _socket} =
               LiveHandler.handle_event(
                 "reading_position_updated",
                 %{"feed_name" => "my", "cursor" => cursor},
                 socket
               )

      refute Markers.get_reading_position(me, "my")
    end

    test "does not store when the event feed name does not match the rendered feed", %{
      account: account,
      me: me
    } do
      cursor = cursor_id()
      socket = socket(account, me, feed_name: :my, feed_filters: %{})

      assert {:noreply, _socket} =
               LiveHandler.handle_event(
                 "reading_position_updated",
                 %{"feed_name" => "local", "cursor" => cursor},
                 socket
               )

      refute Markers.get_reading_position(me, "local")
    end

    test "does not store invalid cursors", %{account: account, me: me} do
      socket = socket(account, me, feed_name: :my, feed_filters: %{})

      assert {:noreply, _socket} =
               LiveHandler.handle_event(
                 "reading_position_updated",
                 %{"feed_name" => "my", "cursor" => "not-a-valid-cursor"},
                 socket
               )

      refute Markers.get_reading_position(me, "my")
    end

    test "component event delegates browser saves to the live handler", %{
      account: account,
      me: me
    } do
      cursor = cursor_id()
      socket = socket(account, me, feed_name: :my, feed_filters: %{})

      assert {:noreply, _socket} =
               FeedLive.handle_event(
                 "Bonfire.Social.Feeds:reading_position_updated",
                 %{"feed_name" => "my", "cursor" => cursor},
                 socket
               )

      assert Markers.get_reading_position(me, "my") == cursor
    end
  end

  describe "server-side marker store" do
    test "clears a saved reading position", %{account: account, me: me} do
      cursor = cursor_id()
      socket = socket(account, me, feed_name: :my, feed_filters: %{})

      assert {:noreply, _socket} =
               LiveHandler.handle_event(
                 "reading_position_updated",
                 %{"feed_name" => "my", "cursor" => cursor},
                 socket
               )

      assert Markers.get_reading_position(me, "my") == cursor

      assert :ok = Markers.clear_reading_position(me, "my")
      refute Markers.get_reading_position(me, "my")
    end
  end

  describe "reading position resume" do
    test "prefers a valid client cursor over the stored marker", %{me: me} do
      stored_cursor = cursor_id()
      client_cursor = cursor_id()

      Markers.save_reading_position(me, "my", stored_cursor)

      assert {opts, ^client_cursor} =
               LiveHandler.maybe_apply_reading_position(
                 :my,
                 resume_opts(me, client_reading_positions: %{"my" => client_cursor}),
                 false
               )

      assert opts[:paginate][:after] == client_cursor
      assert opts[:paginate][:cursor_inclusive] == true
      assert opts[:time_limit] == 0
    end

    test "ignores an invalid client cursor and falls back to the stored marker", %{me: me} do
      stored_cursor = cursor_id()

      Markers.save_reading_position(me, "my", stored_cursor)

      assert {opts, ^stored_cursor} =
               LiveHandler.maybe_apply_reading_position(
                 :my,
                 resume_opts(me, client_reading_positions: %{"my" => "not-a-valid-cursor"}),
                 false
               )

      assert opts[:paginate][:after] == stored_cursor
    end

    test "does not apply a reading position while resetting or paginating", %{me: me} do
      cursor = cursor_id()
      opts = resume_opts(me, client_reading_positions: %{"my" => cursor})

      assert {^opts, nil} = LiveHandler.maybe_apply_reading_position(:my, opts, true)

      paginating_opts = Keyword.put(opts, :paginate, after: cursor_id())

      assert {^paginating_opts, nil} =
               LiveHandler.maybe_apply_reading_position(:my, paginating_opts, false)
    end
  end

  describe "reading position resume (settings gate)" do
    test "does not resume when marker tracking is disabled in settings", %{me: me} do
      {:ok, %{__context__: %{current_user: me}}} =
        Settings.put([Bonfire.Social.Markers, :enabled], false,
          current_user: me,
          scope: :user
        )

      cursor = cursor_id()

      assert {_opts, nil} =
               LiveHandler.maybe_apply_reading_position(
                 :my,
                 resume_opts(me, client_reading_positions: %{"my" => cursor}),
                 false
               )
    end
  end

  describe "staleness window" do
    test "does not resume from a marker older than the max age", %{me: me} do
      cursor = cursor_id()

      {:ok, _} = Markers.save_reading_position(me, "my", cursor)
      backdate_markers(11)

      assert {_opts, nil} =
               LiveHandler.maybe_apply_reading_position(:my, resume_opts(me, []), false)

      # the marker itself is kept (e.g. for Mastodon clients), only resume skips it
      assert Markers.get_reading_position(me, "my") == cursor
    end

    test "resumes from a marker within the max age", %{me: me} do
      cursor = cursor_id()

      {:ok, _} = Markers.save_reading_position(me, "my", cursor)
      backdate_markers(1)

      assert {opts, ^cursor} =
               LiveHandler.maybe_apply_reading_position(:my, resume_opts(me, []), false)

      assert opts[:paginate][:after] == cursor
    end

    test "get_reading_position applies max_age_days only when given", %{me: me} do
      cursor = cursor_id()

      {:ok, _} = Markers.save_reading_position(me, "my", cursor)
      backdate_markers(5)

      refute Markers.get_reading_position(me, "my", max_age_days: 3)
      assert Markers.get_reading_position(me, "my", max_age_days: 30) == cursor
      assert Markers.get_reading_position(me, "my") == cursor
    end
  end

  defp socket(account, me, opts) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        __context__: %{
          current_account_id: account.id,
          current_user_id: me.id,
          current_user: me
        },
        current_account_id: account.id,
        current_user_id: me.id,
        current_user: me,
        enable_marker: Keyword.get(opts, :enable_marker, true),
        feed_name: Keyword.fetch!(opts, :feed_name),
        feed_filters: Keyword.fetch!(opts, :feed_filters)
      }
    }
  end

  defp resume_opts(me, opts) do
    Keyword.merge(
      [
        current_user: me,
        current_user_id: me.id,
        __context__: %{current_user: me, current_user_id: me.id}
      ],
      opts
    )
  end

  defp cursor_id, do: Needle.ULID.generate()

  defp backdate_markers(days_ago) do
    Bonfire.Common.Repo.update_all(Bonfire.Social.Marker,
      set: [updated_at: Bonfire.Common.DatesTimes.past(days_ago, :day)]
    )
  end
end
