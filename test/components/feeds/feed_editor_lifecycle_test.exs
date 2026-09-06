defmodule Bonfire.UI.Social.FeedEditorLifecycleTest do
  use ExUnit.Case, async: true
  @moduletag :ui

  alias Bonfire.UI.Social.FeedFiltersModalContentLive, as: Editor
  doctest Editor, only: [filters_to_apply: 2]

  test "Apply retains a pending edit across a parent render without publishing it early" do
    attrs = %{id: "draft", feed_filters: %{time_limit: 30}, context_key: :local, apply_to: :parent}
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = Editor.update(attrs, socket)
    {:noreply, socket} = Editor.handle_event("set_filter", %{"time_limit" => "1"}, socket)
    {:ok, socket} = Editor.update(attrs, socket)
    refute_received {Editor, :apply, _}

    {:noreply, _socket} = Editor.handle_event("apply", %{}, socket)
    assert_received {Editor, :apply, %{time_limit: 1}}
  end

  test "changing feed context discards a draft even when the applied filters match" do
    attrs = %{id: "draft", feed_filters: %{time_limit: 30}, context_key: :local, apply_to: :parent}
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = Editor.update(attrs, socket)
    {:noreply, socket} = Editor.handle_event("set_filter", %{"time_limit" => "1"}, socket)
    {:ok, socket} = Editor.update(%{attrs | context_key: :remote}, socket)

    {:noreply, _socket} = Editor.handle_event("apply", %{}, socket)
    assert_received {Editor, :apply, %{time_limit: 30}}
  end

  test "new applied filters replace an older draft" do
    attrs = %{id: "draft", feed_filters: %{time_limit: 30}, context_key: :local, apply_to: :parent}
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = Editor.update(attrs, socket)
    {:noreply, socket} = Editor.handle_event("set_filter", %{"time_limit" => "1"}, socket)
    {:ok, socket} = Editor.update(%{attrs | feed_filters: %{time_limit: 7}}, socket)

    {:noreply, _socket} = Editor.handle_event("apply", %{}, socket)
    assert_received {Editor, :apply, %{time_limit: 7}}
  end
end
