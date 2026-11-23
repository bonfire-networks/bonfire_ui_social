defmodule Bonfire.UI.Social.FeedWhenFilterTest do
  @moduledoc "The filter editor's \"When\" section: when things happen (eg. events), by a preset or, in advanced mode, by dates, in the viewer's time zone."
  use ExUnit.Case, async: true
  @moduletag :ui

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Bonfire.UI.Social.FeedFiltersModalContentLive, as: Editor
  alias Bonfire.Social.FeedFilters

  defp editor(filters \\ %{}, time_zone \\ "Pacific/Auckland") do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, __context__: %{client_timezone: time_zone}}
    }

    {:ok, socket} =
      Editor.update(
        %{id: "draft", feed_filters: filters, context_key: :local, apply_to: :parent},
        socket
      )

    socket
  end

  defp applied(socket) do
    {:noreply, _socket} = Editor.handle_event("apply", %{}, socket)
    assert_received {Editor, :apply, filters}
    filters
  end

  test "a preset is the period it names, in the viewer's time zone" do
    {:noreply, socket} = Editor.handle_event("set_filter", %{"happening" => "today"}, editor())

    expected = FeedFilters.happening_range(:today, DateTime.utc_now(), "Pacific/Auckland")
    filters = applied(socket)

    assert filters[:happening_from] == expected.happening_from
    assert filters[:happening_until] == expected.happening_until
  end

  test "which side of now replaces a period, and a period replaces it" do
    {:noreply, socket} =
      Editor.handle_event(
        "set_filter",
        %{"happening" => "upcoming"},
        editor(%{
          happening_from: ~U[2026-11-28 00:00:00Z],
          happening_until: ~U[2026-11-30 00:00:00Z]
        })
      )

    filters = applied(socket)
    assert filters[:time_span] == :upcoming
    # cleared explicitly, as the host merges what's applied into the filters it has
    assert Map.fetch(filters, :happening_from) == {:ok, nil}
    assert Map.fetch(filters, :happening_until) == {:ok, nil}

    {:noreply, socket} =
      Editor.handle_event(
        "set_filter",
        %{"happening" => "this_weekend"},
        editor(%{time_span: :upcoming})
      )

    filters = applied(socket)
    assert Map.fetch(filters, :time_span) == {:ok, nil}
    assert %DateTime{} = filters[:happening_from]
  end

  test "in advanced mode, two dates are a period from the start of the first to the end of the second, in the viewer's time zone" do
    {:noreply, socket} =
      Editor.handle_event(
        "set_filter",
        %{"happening_from_date" => "2026-12-24", "happening_until_date" => "2026-12-26"},
        editor()
      )

    filters = applied(socket)
    # midnight in Auckland (UTC+13 in December) is 11:00 UTC the day before
    assert filters[:happening_from] == ~U[2026-12-23 11:00:00Z]
    assert filters[:happening_until] == ~U[2026-12-26 11:00:00Z]
  end

  describe "sort by when things happen" do
    test "choosing it sorts by start date, earliest first; latest first for past things; and newest or oldest first replaces it" do
      {:noreply, socket} =
        Editor.handle_event("set_filter", %{"sort_by" => "starts_at"}, editor())

      assert %{sort_by: :starts_at, sort_order: :asc} = applied(socket)

      {:noreply, socket} =
        Editor.handle_event(
          "set_filter",
          %{"sort_by" => "starts_at"},
          editor(%{time_span: :past})
        )

      assert %{sort_by: :starts_at, sort_order: :desc} = applied(socket)

      # an applied sort by start date goes (the host is told to drop it) when newest first is chosen
      {:noreply, socket} =
        Editor.handle_event(
          "set_filter",
          %{"sort_order" => "desc"},
          editor(%{sort_by: :starts_at, sort_order: :asc})
        )

      assert %{sort_by: false, sort_order: :desc} = applied(socket)
    end

    test "the feed's sort menu offers it only with a Happening filter" do
      render = fn filters ->
        render_component(&Bonfire.UI.Social.SortItemsDropdownLive.render/1, %{
          feed_filters: filters,
          event_target: nil,
          __context__: %{}
        })
      end

      # control: the menu renders its usual choices
      assert render.(%{}) =~ "Most replied"
      refute render.(%{}) =~ "Soonest first"
      refute render.(%{time_limit: 7}) =~ "Soonest first"
      assert render.(%{time_span: :upcoming}) =~ "Soonest first"
      assert render.(%{happening_from: ~U[2030-01-01 00:00:00Z]}) =~ "Soonest first"
      # past things sort latest first
      assert render.(%{time_span: :past}) =~ "Most recent first"
      refute render.(%{time_span: :past}) =~ "Soonest first"
    end
  end
end
