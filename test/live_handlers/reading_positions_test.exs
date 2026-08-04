defmodule Bonfire.UI.Social.ReadingPositionsTest do
  use Bonfire.UI.Social.ConnCase, async: false
  use Bonfire.Common.Utils

  alias Bonfire.Common.Settings
  alias Bonfire.Social.{FeedFilters, FeedLoader, Markers}
  alias Bonfire.UI.Common.LoadMoreLive
  alias Bonfire.UI.Social.FeedLive
  alias Bonfire.Social.Feeds.LiveHandler

  import Bonfire.Posts.Fake

  doctest Bonfire.Social.Feeds.LiveHandler, only: [merge_restored_entries: 3]

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

    test "clears the marker when the browser reaches the true feed top", %{
      account: account,
      me: me
    } do
      cursor = cursor_id()
      Markers.save_reading_position(me, "my", cursor)
      socket = socket(account, me, feed_name: :my, feed_filters: %{})

      assert {:noreply, _socket} =
               FeedLive.handle_event(
                 "Bonfire.Social.Feeds:reading_position_cleared",
                 %{"feed_name" => "my"},
                 socket
               )

      refute Markers.get_reading_position(me, "my")
    end

    test "does not clear a marker while newer server pages remain", %{
      account: account,
      me: me
    } do
      cursor = cursor_id()
      Markers.save_reading_position(me, "my", cursor)

      socket =
        socket(account, me,
          feed_name: :my,
          feed_filters: %{},
          newer_page_info: %{start_cursor: cursor_id()}
        )

      assert {:noreply, _socket} =
               LiveHandler.handle_event(
                 "reading_position_cleared",
                 %{"feed_name" => "my"},
                 socket
               )

      assert Markers.get_reading_position(me, "my") == cursor
    end

    test "does not clear a marker for a different rendered feed", %{
      account: account,
      me: me
    } do
      cursor = cursor_id()
      Markers.save_reading_position(me, "my", cursor)
      socket = socket(account, me, feed_name: :local, feed_filters: %{})

      assert {:noreply, _socket} =
               LiveHandler.handle_event(
                 "reading_position_cleared",
                 %{"feed_name" => "my"},
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
    test "places newer entries above the marker while preserving older entries below" do
      newer = [%{id: "newest"}, %{id: "newer"}]
      marker_and_older = [%{id: "marker"}, %{id: "older"}]

      assert {:ok, expected} =
               LiveHandler.merge_restored_entries(newer, marker_and_older, "marker")

      assert expected == newer ++ marker_and_older
    end

    test "rejects a resume window when the marker is no longer available" do
      assert {:error, :marker_missing} =
               LiveHandler.merge_restored_entries(
                 [%{id: "newer"}],
                 [%{id: "older"}],
                 "missing"
               )
    end

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

    test "rejects UUID client cursors because feed pagination requires ULIDs", %{me: me} do
      stored_cursor = cursor_id()

      Markers.save_reading_position(me, "my", stored_cursor)

      assert {opts, ^stored_cursor} =
               LiveHandler.maybe_apply_reading_position(
                 :my,
                 resume_opts(me, client_reading_positions: %{"my" => Ecto.UUID.generate()}),
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

    test "does not resume feeds that did not explicitly enable markers", %{me: me} do
      opts =
        resume_opts(me, client_reading_positions: %{"my" => cursor_id()})
        |> Keyword.delete(:enable_marker)

      assert {^opts, nil} = LiveHandler.maybe_apply_reading_position(:my, opts, false)
    end
  end

  describe "newer feed pagination" do
    test "loads consecutive server pages into the stream without gaps or duplicates", %{
      account: account,
      me: me
    } do
      Process.put([:bonfire, :default_pagination_limit], 20)

      Enum.each(1..8, fn index ->
        fake_post!(me, "public", %{
          post_content: %{
            name: "UI newer-page post #{index}",
            html_body: "UI newer-page post #{index}"
          }
        })
      end)

      filters = %FeedFilters{
        subjects: [me.id],
        activity_types: [:create],
        time_limit: 0
      }

      base_cursors =
        FeedLoader.feed(:custom, filters,
          current_user: me,
          paginate: [limit: 20]
        )
        |> Map.fetch!(:edges)
        |> Enum.map(&entry_cursor/1)

      marker_index = 6
      marker_cursor = Enum.at(base_cursors, marker_index)

      socket =
        socket(account, me,
          feed_name: :custom,
          feed_filters: filters,
          paginate: [limit: 2],
          activity_preloads: {[], []}
        )
        |> Phoenix.LiveView.stream_configure(:feed,
          dom_id: fn entry -> "fa_#{entry_cursor(entry)}" end
        )
        |> Phoenix.LiveView.stream(:feed, [])

      assert {:noreply, first_socket} =
               LiveHandler.paginate_newer_feed(:custom, marker_cursor, socket)

      assert newest_stream_cursors(first_socket, 2) ==
               Enum.slice(base_cursors, marker_index - 2, 2)

      first_cursor = LoadMoreLive.start_cursor(first_socket.assigns.newer_page_info)
      assert is_binary(first_cursor)

      assert {:noreply, second_socket} =
               LiveHandler.paginate_newer_feed(:custom, first_cursor, first_socket)

      assert newest_stream_cursors(second_socket, 2) ==
               Enum.slice(base_cursors, marker_index - 4, 2)

      second_cursor = LoadMoreLive.start_cursor(second_socket.assigns.newer_page_info)
      assert is_binary(second_cursor)

      assert {:noreply, final_socket} =
               LiveHandler.paginate_newer_feed(:custom, second_cursor, second_socket)

      assert newest_stream_cursors(final_socket, 2) == Enum.slice(base_cursors, 0, 2)
      refute LoadMoreLive.start_cursor(final_socket.assigns.newer_page_info)

      loaded_cursors =
        final_socket
        |> newest_stream_cursors(6)

      assert length(loaded_cursors) == MapSet.size(MapSet.new(loaded_cursors))
      assert Enum.sort(loaded_cursors) == Enum.sort(Enum.slice(base_cursors, 0, 6))
    end
  end

  describe "reading position resume (obsolete settings compatibility)" do
    test "ignores a previously saved marker preference", %{me: me} do
      {:ok, %{__context__: %{current_user: me}}} =
        Settings.put([Bonfire.Social.Markers, :enabled], false,
          current_user: me,
          scope: :user
        )

      cursor = cursor_id()

      assert {opts, ^cursor} =
               LiveHandler.maybe_apply_reading_position(
                 :my,
                 resume_opts(me, client_reading_positions: %{"my" => cursor}),
                 false
               )

      assert opts[:paginate][:after] == cursor
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
      private: %{
        live_temp: %{},
        lifecycle: %Phoenix.LiveView.Lifecycle{}
      },
      assigns:
        Map.merge(
          %{
            __changed__: %{},
            __context__: %{
              current_account_id: account.id,
              current_user_id: me.id,
              current_user: me
            },
            current_account_id: account.id,
            current_user_id: me.id,
            current_user: me,
            enable_marker: true
          },
          Map.new(opts)
        )
    }
  end

  defp resume_opts(me, opts) do
    Keyword.merge(
      [
        current_user: me,
        current_user_id: me.id,
        enable_marker: true,
        __context__: %{current_user: me, current_user_id: me.id}
      ],
      opts
    )
  end

  defp cursor_id, do: Needle.ULID.generate()

  defp newest_stream_cursors(socket, count) do
    socket.assigns.streams.feed.inserts
    |> Enum.take(count)
    |> Enum.map(fn {_dom_id, 0, entry, _limit, _update_only} -> entry_cursor(entry) end)
  end

  defp entry_cursor(entry) do
    id(entry) || e(entry, :activity, :id, nil) || e(entry, :object, :id, nil) ||
      e(entry, :edge, :id, nil)
  end

  defp backdate_markers(days_ago) do
    Bonfire.Common.Repo.update_all(Bonfire.Social.Marker,
      set: [updated_at: Bonfire.Common.DatesTimes.past(days_ago, :day)]
    )
  end
end
