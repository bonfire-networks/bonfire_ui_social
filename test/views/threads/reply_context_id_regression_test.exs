defmodule Bonfire.UI.Social.ReplyContextIdRegressionTest do
  @moduledoc """
  Repro: replying to a post published in a group must carry the thread root's id
  as `context_id` into the composer. `to_boundaries: [{:clone_context, name}]`
  only carries the group's display name — the id travels separately via
  `context_id`, and when it's nil the `clone_context` boundary fails closed at
  publish time ("no preset ACLs"), silently dropping the group audience so only
  the author and explicit recipients can see the reply.

  `prepare_reply_assigns` derived `context_id` solely from
  `activity.replied.thread_id || reply_to.replied.thread_id`, which is nil on
  surfaces that don't preload `replied` on the activity (or that pass a bare id
  as `reply_to`), even though the thread root always has a `Replied` row in the
  DB — so the regression tests exercise exactly those conditions, while feed /
  thread-page click-through (where `replied` happens to be preloaded) serves as
  integration coverage.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)
    other = fake_user!()

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me, other: other}
  end

  defp handler_socket(account, me) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        __context__: %{
          current_account_id: account.id,
          current_user_id: me.id,
          current_user: me
        },
        current_account_id: account.id,
        current_user_id: me.id,
        current_user: me
      }
    }
  end

  defp without_replied(%{} = post) do
    %{
      post
      | replied: %Ecto.Association.NotLoaded{
          __field__: :replied,
          __owner__: post.__struct__,
          __cardinality__: :one
        }
    }
  end

  describe "prepare_reply_assigns context_id (regression)" do
    test "falls back to fetching the thread root when `replied` is not preloaded",
         %{account: account, me: me, other: other} do
      {:ok, post} =
        Posts.publish(
          current_user: other,
          post_attrs: %{post_content: %{html_body: "root without replied preload"}},
          boundary: "public"
        )

      assigns =
        Bonfire.Social.Threads.LiveHandler.prepare_reply_assigns(
          without_replied(post),
          %{},
          nil,
          handler_socket(account, me)
        )

      assert is_list(assigns), "expected reply assigns, got: #{inspect(assigns)}"

      assert assigns[:context_id] == id(post),
             "expected context_id to be the thread root, got: #{inspect(assigns[:context_id])}"
    end

    test "falls back to fetching the thread root when reply_to is a bare id",
         %{account: account, me: me, other: other} do
      {:ok, post} =
        Posts.publish(
          current_user: other,
          post_attrs: %{post_content: %{html_body: "root replied to by bare id"}},
          boundary: "public"
        )

      assigns =
        Bonfire.Social.Threads.LiveHandler.prepare_reply_assigns(
          id(post),
          %{},
          nil,
          handler_socket(account, me)
        )

      assert is_list(assigns), "expected reply assigns, got: #{inspect(assigns)}"

      assert assigns[:context_id] == id(post),
             "expected context_id to be the thread root, got: #{inspect(assigns[:context_id])}"
    end

    test "when replying to a NON-root reply, still resolves the thread root",
         %{account: account, me: me, other: other} do
      {:ok, post} =
        Posts.publish(
          current_user: other,
          post_attrs: %{post_content: %{html_body: "thread root"}},
          boundary: "public"
        )

      {:ok, reply} =
        Posts.publish(
          current_user: other,
          post_attrs: %{
            post_content: %{html_body: "intermediate reply"},
            reply_to_id: id(post)
          },
          boundary: "public"
        )

      assigns =
        Bonfire.Social.Threads.LiveHandler.prepare_reply_assigns(
          without_replied(reply),
          %{},
          nil,
          handler_socket(account, me)
        )

      assert is_list(assigns), "expected reply assigns, got: #{inspect(assigns)}"

      assert assigns[:context_id] == id(post),
             "expected context_id to be the thread root, got: #{inspect(assigns[:context_id])}"
    end
  end

  describe "reply click-through (integration)" do
    test "replying to a group post from the THREAD page carries the root as context_id and clone_context boundary",
         %{conn: conn, other: other} do
      group = Bonfire.Classify.Simulate.fake_group!(other, %{name: "context id group"})

      group_post =
        Bonfire.Classify.Simulate.fake_post_in_group!(
          other,
          group,
          "<p>group context post</p>"
        )

      # capture what the reply handler sends to the composer; `mode: :shared` because
      # the handler runs in the LiveView process, not the test process
      test_pid = self()

      Repatch.patch(
        Bonfire.UI.Common.SmartInput.LiveHandler,
        :open_with_text_suggestion,
        [mode: :shared],
        fn _text, set_assigns, _socket ->
          send(test_pid, {:composer_opened, Map.new(set_assigns)})
          :ok
        end
      )

      {:ok, view, _html} = live(conn, "/discussion/#{id(group_post)}")

      assert render(view) =~ "group context post"

      # let async (:async_actions-mode) update_many preloads land, as they would in dev
      Process.sleep(1000)
      render(view)

      view
      |> element("[data-id=action_reply][phx-value-id='#{id(group_post)}']")
      |> render_click()

      assert_receive {:composer_opened, assigns}, 2000

      assert [{:clone_context, _}] = assigns[:to_boundaries],
             "expected clone_context boundary, got: #{inspect(assigns[:to_boundaries])}"

      assert assigns[:context_id] == id(group_post),
             "expected context_id to be the thread root, got: #{inspect(assigns[:context_id])}"
    end
  end
end
