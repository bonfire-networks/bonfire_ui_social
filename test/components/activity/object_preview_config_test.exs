defmodule Bonfire.UI.Social.Activity.ObjectPreviewConfigTest do
  @moduledoc """
  `ActivityLive.component_for_object_type/3` resolves an object's preview component from `config :bonfire, :ui, object_preview`. Callers concatenate its result with other component lists (`++`), so every kind of registration must come back as a list.

  Regression: a function registration returning a single `{module, assigns}` tuple (as `ProcessListLive.activity_component/1` does) came back as a bare tuple and raised `ArgumentError` in `:erlang.++/2` when rendering a process in a feed.
  """
  use ExUnit.Case, async: true

  @moduletag :backend

  alias Bonfire.UI.Social.ActivityLive

  defp register(type, registration),
    do: Process.put([:bonfire, :ui, :object_preview, type], registration)

  test "a function returning a {module, assigns} tuple resolves to a list" do
    register(:preview_fun_tuple, fn object -> {SomeLive, [object: object]} end)

    assert [{SomeLive, [object: %{id: 1}]}] =
             ActivityLive.component_for_object_type(:preview_fun_tuple, %{id: 1}, %{})
  end

  test "a function returning a list is left as a list" do
    register(:preview_fun_list, fn _ -> [SomeLive, OtherLive] end)

    assert [SomeLive, OtherLive] =
             ActivityLive.component_for_object_type(:preview_fun_list, %{id: 1}, %{})
  end

  test "a bare module and a {module, assigns} tuple both resolve to a list" do
    register(:preview_module, SomeLive)
    register(:preview_tuple, {SomeLive, a: 1})

    assert [SomeLive] = ActivityLive.component_for_object_type(:preview_module, %{id: 1}, %{})

    assert [{SomeLive, a: 1}] =
             ActivityLive.component_for_object_type(:preview_tuple, %{id: 1}, %{})
  end
end
