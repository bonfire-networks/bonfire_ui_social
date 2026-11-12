defmodule Bonfire.UI.Social.QuoteApprovedNotificationTest do
  @moduledoc """
  The person who asked to quote a post is told on their notifications pages when the author approves it, and the page no longer words it as an ask. Through the real pages, since which edges a feed loads is decided by the filters and preloads the view passes: Latest, and the Requests chip.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.Quotes

  test "an approved quote reads as approved, not as an ask, in the quoter's Latest and Requests views" do
    account = fake_account!()
    alice = fake_user!(account)
    bob = fake_user!(account)

    {:ok, quoted} =
      Posts.publish(
        current_user: alice,
        boundary: "public",
        post_attrs: %{post_content: %{html_body: "worth quoting"}}
      )

    {:ok, quoting} =
      Posts.publish(
        current_user: bob,
        boundary: "public",
        post_attrs: %{post_content: %{html_body: "quoting it"}},
        quotes: [quoted]
      )

    assert {:ok, _} = Quotes.requested(quoting, quoted), "control: it was an ask"
    assert {:ok, _} = Quotes.accept_quote(quoting, quoted, current_user: alice)

    for path <- ["/notifications", "/notifications/requests"] do
      conn(user: bob, account: account)
      |> visit(path)
      |> wait_async()
      # the row is the quoting post's own card, so what it was for is the kind the row carries
      |> assert_has("[data-id=feed] article[data-experienced-as=quote]")
      |> refute_has("[data-id=feed] article[data-experienced-as=quote_request]")
    end
  end
end
