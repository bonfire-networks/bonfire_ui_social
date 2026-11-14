defmodule Bonfire.UI.Social.Threads.ViewOptionsTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts

  test "native layout and sort controls update the thread independently" do
    account = fake_account!()
    user = fake_user!(account)

    {:ok, post} =
      Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: Faker.Lorem.sentence()}},
        boundary: "public"
      )

    conn(user: user, account: account)
    |> visit("/post/#{id(post)}")
    |> assert_has("input[type=radio][value=nested][checked]")
    |> refute_has("input[type=radio][value=flat][checked]")
    |> choose("Linear replies")
    |> assert_has("input[type=radio][value=flat][checked]")
    |> choose("Newest first")
    |> assert_has("input[type=radio][value=default-desc][checked]")
    |> assert_has("input[type=radio][value=flat][checked]")
    |> choose("Oldest first")
    |> assert_has("input[type=radio][value=default-asc][checked]")
    |> choose("Threaded replies")
    |> choose("Recently active")
    |> assert_has("input[type=radio][value=latest_reply-desc][checked]")
    |> choose("Linear replies")
    |> assert_has("input[type=radio][value=flat][checked]")
    |> assert_has("input[type=radio][value=default-desc][checked]")
    |> refute_has("input[type=radio][value=latest_reply-desc]")
    |> choose("Threaded replies")
    |> choose("Thread order")
    |> assert_has("input[type=radio][value=default-asc][checked]")
    |> refute_has("input[type=radio][value=latest_reply-desc][checked]")
  end

  test "a thread opens in thread order: replies oldest first, with Thread order selected" do
    account = fake_account!()
    user = fake_user!(account)

    {:ok, op} =
      Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: "the opening post"}},
        boundary: "public"
      )

    for text <- ["first reply", "second reply", "third reply"] do
      {:ok, _} =
        Posts.publish(
          current_user: user,
          post_attrs: %{post_content: %{html_body: text}, reply_to_id: op.id},
          boundary: "public"
        )
    end

    conn(user: user, account: account)
    |> visit("/post/#{id(op)}")
    |> assert_has("input[type=radio][value=default-asc][checked]")
    |> assert_has("div", text: "third reply")
    |> unwrap(fn view ->
      html = Phoenix.LiveViewTest.render(view)
      position = fn text -> html |> :binary.match(text) |> elem(0) end

      assert position.("first reply") < position.("second reply")
      assert position.("second reply") < position.("third reply")

      html
    end)
  end
end
