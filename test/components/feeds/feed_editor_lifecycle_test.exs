defmodule Bonfire.UI.Social.FeedEditorLifecycleTest do
  use ExUnit.Case, async: true
  @moduletag :ui

  alias Bonfire.UI.Social.FeedFiltersModalContentLive, as: Editor
  # (arity 3 since the optional list of declared controls was added)
  # doctest Editor, only: [filters_to_apply: 2]
  doctest Editor, only: [filters_to_apply: 3]

  test "Apply retains a pending edit across a parent render without publishing it early" do
    attrs = %{
      id: "draft",
      feed_filters: %{time_limit: 30},
      context_key: :local,
      apply_to: :parent
    }

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = Editor.update(attrs, socket)
    {:noreply, socket} = Editor.handle_event("set_filter", %{"time_limit" => "1"}, socket)
    {:ok, socket} = Editor.update(attrs, socket)
    refute_received {Editor, :apply, _}

    {:noreply, _socket} = Editor.handle_event("apply", %{}, socket)
    assert_received {Editor, :apply, %{time_limit: 1}}
  end

  test "changing feed context discards a draft even when the applied filters match" do
    attrs = %{
      id: "draft",
      feed_filters: %{time_limit: 30},
      context_key: :local,
      apply_to: :parent
    }

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = Editor.update(attrs, socket)
    {:noreply, socket} = Editor.handle_event("set_filter", %{"time_limit" => "1"}, socket)
    {:ok, socket} = Editor.update(%{attrs | context_key: :remote}, socket)

    {:noreply, _socket} = Editor.handle_event("apply", %{}, socket)
    assert_received {Editor, :apply, %{time_limit: 30}}
  end

  test "an editor given no sections shows all of them, and one given a list keeps it" do
    attrs = %{id: "draft", feed_filters: %{}, context_key: :local, apply_to: :parent}
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

    {:ok, all} = Editor.update(attrs, socket)
    assert all.assigns.sections == Editor.sections()

    {:ok, some} = Editor.update(Map.put(attrs, :sections, [:origin, :time_range]), socket)
    assert some.assigns.sections == [:origin, :time_range]
  end

  test "Reset then Apply clears a nearby filter that was applied" do
    attrs = %{
      id: "draft",
      feed_filters: %{nearby: %{lat: 50.4, long: -3.6, km: 10}},
      context_key: :local,
      apply_to: :parent
    }

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = Editor.update(attrs, socket)
    {:noreply, socket} = Editor.handle_event("reset_pending", %{}, socket)
    {:noreply, _socket} = Editor.handle_event("apply", %{}, socket)

    assert_received {Editor, :apply, applied}

    # the host merges what it is sent into the feed's filters, so a key that is missing keeps its old value
    assert Map.get(applied, :nearby, :missing) == nil
  end

  describe "put_pending/2, the way a declared control's handler updates the draft" do
    @attrs %{id: "draft", feed_filters: %{time_limit: 30}, context_key: :local, apply_to: :parent}

    defp fresh_editor do
      {:ok, socket} =
        Editor.update(@attrs, %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}})

      socket
    end

    test "merges the patch into the pending filters and keeps the others" do
      socket = Editor.put_pending(fresh_editor(), %{stub_key: %{a: 1}})
      assert socket.assigns.pending_filters == %{time_limit: 30, stub_key: %{a: 1}}

      socket = Editor.put_pending(socket, %{other: 2})
      assert socket.assigns.pending_filters == %{time_limit: 30, stub_key: %{a: 1}, other: 2}
    end

    test "recomputes the derived assigns" do
      socket = fresh_editor()
      before = socket.assigns.active_filters
      socket = Editor.put_pending(socket, %{time_limit: 7})
      assert socket.assigns.pending_filters.time_limit == 7
      assert socket.assigns.active_filters != before
    end

    test "nil is kept as an explicit nil, and Apply sends it" do
      socket = Editor.put_pending(fresh_editor(), %{stub_key: nil})
      assert Map.fetch(socket.assigns.pending_filters, :stub_key) == {:ok, nil}

      {:noreply, _} = Editor.handle_event("apply", %{}, socket)
      assert_received {Editor, :apply, %{stub_key: nil, time_limit: 30}}
    end

    test "the draft survives a parent update with the same filters" do
      socket = Editor.put_pending(fresh_editor(), %{stub_key: %{a: 1}})
      {:ok, socket} = Editor.update(@attrs, socket)
      assert socket.assigns.pending_filters.stub_key == %{a: 1}
    end

    test "control_state starts empty, and resets with the draft" do
      socket = fresh_editor()
      assert socket.assigns.control_state == %{}

      socket = Phoenix.Component.assign(socket, :control_state, %{stub: %{checked?: true}})
      {:ok, same} = Editor.update(@attrs, socket)
      assert same.assigns.control_state == %{stub: %{checked?: true}}

      {:ok, changed} = Editor.update(%{@attrs | context_key: :remote}, socket)
      assert changed.assigns.control_state == %{}
    end
  end

  test "new applied filters replace an older draft" do
    attrs = %{
      id: "draft",
      feed_filters: %{time_limit: 30},
      context_key: :local,
      apply_to: :parent
    }

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = Editor.update(attrs, socket)
    {:noreply, socket} = Editor.handle_event("set_filter", %{"time_limit" => "1"}, socket)
    {:ok, socket} = Editor.update(%{attrs | feed_filters: %{time_limit: 7}}, socket)

    {:noreply, _socket} = Editor.handle_event("apply", %{}, socket)
    assert_received {Editor, :apply, %{time_limit: 7}}
  end
end
