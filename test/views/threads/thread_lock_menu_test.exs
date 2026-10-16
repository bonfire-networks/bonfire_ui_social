defmodule Bonfire.UI.Social.ThreadLockMenu.Test do
  @moduledoc """
  The "More actions" menu of a thread's main post offers one "Lock or unlock discussion" item to whoever may lock it, and its modal looks up whether the thread is locked when opened, so it offers whichever applies. Who may is what `Bonfire.Boundaries.Blocks.lock/2` checks: whoever may change the post's boundary or moderate it, or an instance admin.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Boundaries.Blocks

  @item "[data-role=lock_or_unlock_discussion]"

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, account: account, me: me, conn: conn(user: me, account: account)}
  end

  defp publish!(user) do
    {:ok, post} =
      Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: "<p>a thread</p>"}},
        boundary: "public"
      )

    post
  end

  defp open_lock_modal(conn, post) do
    conn
    |> visit("/post/#{id(post)}")
    |> open_more_menu()
    |> click_button("#{@item} [data-role=open_modal]", "Lock or unlock discussion")
  end

  test "on an open thread, its author is offered to lock it", %{conn: conn, me: me} do
    post = publish!(me)

    conn
    |> open_lock_modal(post)
    |> assert_has("[data-role=lock_confirm]", text: "Lock this discussion")
    |> refute_has("[data-role=unlock_confirm]")
  end

  test "on a locked thread, its author is offered to unlock it, and unlocking reopens it", %{
    conn: conn,
    me: me
  } do
    post = publish!(me)
    someone = fake_user!()
    {:ok, _} = Blocks.lock(post, current_user: me)
    refute Bonfire.Boundaries.can?(someone, :reply, post), "control: locked"

    conn
    |> open_lock_modal(post)
    |> refute_has("[data-role=lock_confirm]")
    |> click_button("[data-role=unlock_confirm]", "Unlock this discussion")

    assert Bonfire.Boundaries.can?(someone, :reply, post), "reopened"
  end

  test "an instance admin is offered it on someone else's thread, as it stands", %{
    account: account
  } do
    admin = fake_admin!(account)
    open_post = publish!(fake_user!())
    locked_author = fake_user!()
    locked_post = publish!(locked_author)
    {:ok, _} = Blocks.lock(locked_post, current_user: locked_author)

    conn = conn(user: admin, account: account)

    conn
    |> open_lock_modal(open_post)
    |> assert_has("[data-role=lock_confirm]")
    |> refute_has("[data-role=unlock_confirm]")

    conn
    |> open_lock_modal(locked_post)
    |> assert_has("[data-role=unlock_confirm]")
    |> refute_has("[data-role=lock_confirm]")
  end

  test "someone who may not lock it isn't offered it", %{conn: conn} do
    post = publish!(fake_user!())

    conn
    |> visit("/post/#{id(post)}")
    |> open_more_menu()
    # the permission rows are there, so a missing item is the check and not rows never decided
    |> assert_has("[data-id=boundary_details]")
    |> refute_has(@item)
  end
end
