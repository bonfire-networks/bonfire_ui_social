defmodule Bonfire.UI.Social.SetFilterAtomsTest do
  @moduledoc "A filter key sent by the browser never creates a new atom, since atoms are never freed."
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  import Phoenix.LiveViewTest,
    only: [
      live: 2,
      render_click: 1,
      render_hook: 3,
      with_target: 2,
      element: 2,
      element: 3,
      has_element?: 2
    ]

  setup do
    account = fake_account!()
    me = fake_user!(account)
    %{conn: conn(user: me, account: account)}
  end

  test "pushing `set_filter` with a never-seen key does not create an atom", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/feed/my")

    html = view |> element("[data-role=open_modal]", "More filters") |> render_click()

    control = "[id^=feed_filter_hide_own_activities][phx-click=set_filter]"
    assert has_element?(view, control), "control: the filters editor is on the page"

    # the editor's own component: the innermost one holding the control
    [cid | _] =
      html
      |> Floki.parse_document!()
      |> Floki.find("[data-phx-component]")
      |> Enum.filter(&(Floki.find(&1, control) != []))
      |> Enum.reverse()
      |> Enum.flat_map(&Floki.attribute(&1, "data-phx-component"))

    target = ~s([data-phx-component="#{cid}"])
    assert has_element?(view, target), "control: the editor component is addressable"

    key = "zz_" <> Base.encode16(:crypto.strong_rand_bytes(12))

    assert_raise ArgumentError, fn -> String.to_existing_atom(key) end

    view |> with_target(target) |> render_hook("set_filter", %{key => "1"})

    assert_raise ArgumentError, fn -> String.to_existing_atom(key) end
  end
end
