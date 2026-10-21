defmodule Bonfire.UI.Social.ThreadPinMenu.Test do
  @moduledoc """
  A reply's "More actions" menu offers "Mark as answer" and "Pin to thread" only to whoever may pin in that thread, which is what `Bonfire.Social.Pins.may_pin_in?/3` checks on the server: `:pin` on the thread, which its author holds, and a moderator may be granted.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  doctest Bonfire.UI.Social.ActivityLive, only: [thread: 2]

  alias Bonfire.Posts
  alias Bonfire.Boundaries.{Acls, Grants}

  @answer "[data-role=mark_as_answer]"
  @pin "[data-role=pin_to_thread]"

  # answers are switched off in some flavours, so each viewer switches them on for themselves
  defp with_answers(user),
    do:
      current_user(
        Bonfire.Common.Settings.put([Bonfire.Social.Answers, :modularity], :enabled,
          current_user: user
        )
      )

  setup do
    author = fake_user!()
    replier = fake_user!()

    {:ok, thread} =
      Posts.publish(
        current_user: author,
        post_attrs: %{post_content: %{html_body: "<p>a question</p>"}},
        boundary: "public"
      )

    {:ok, _reply} =
      Posts.publish(
        current_user: replier,
        post_attrs: %{post_content: %{html_body: "<p>an answer</p>"}, reply_to_id: id(thread)},
        boundary: "public"
      )

    {:ok, author: with_answers(author), replier: with_answers(replier), thread: thread}
  end

  test "a participant who may not pin in the thread isn't offered either", %{
    replier: replier,
    thread: thread
  } do
    refute Bonfire.Boundaries.can?(replier, :pin, thread), "control: no :pin"

    conn(user: replier)
    |> visit("/post/#{id(thread)}")
    |> assert_has("article", text: "an answer")
    |> refute_has(@answer)
    |> refute_has(@pin)
  end

  test "Pin to thread sits in the Pin entry, Mark as answer beside it", %{
    author: author,
    thread: thread
  } do
    conn(user: author)
    |> visit("/post/#{id(thread)}")
    |> assert_has("article", text: "an answer")
    |> assert_has("[data-role=pin_menu] #{@pin}")
    |> assert_has(@answer)
    |> refute_has("[data-role=pin_menu] #{@answer}")
  end

  test "someone granted :pin on the thread is offered both", %{author: author, thread: thread} do
    moderator = with_answers(fake_user!())
    {:ok, acl} = Acls.get_or_create_object_custom_acl(thread, author)
    Grants.grant(id(moderator), acl.id, :pin, true, current_user: author)
    assert Bonfire.Boundaries.can?(moderator, :pin, thread), "control: granted :pin"

    conn(user: moderator)
    |> visit("/post/#{id(thread)}")
    |> assert_has("article", text: "an answer")
    |> assert_has(@answer)
    |> assert_has(@pin)
  end
end
