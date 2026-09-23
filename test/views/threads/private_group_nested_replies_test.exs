defmodule Bonfire.UI.Social.PrivateGroupNestedRepliesTest do
  @moduledoc """
  In a members-private group, every member reads every reply in a thread, at any depth, including their own.

  Who else reads a reply follows one rule, pinned here in both directions: answering someone grants them the answer, even outside the group's audience, while @-mentioning someone only notifies them. A mention grants only under the `public` and `mentions` presets.

  Each reply is made the way the product makes it: open the thread page as that person and press Reply on one specific comment. That matters because a reply's boundary is whatever the composer submits (`{:clone_context, _}` when the reply handler can tell which group the thread is in, a preset read off the parent's ACLs when it cannot), and replying to a REPLY is a different starting point from replying to the thread's first post.

  Two ways of finishing the reply, because they cover different halves of the path:
    * through the composer itself: press Reply, then submit `#smart_input_form` with only the text, so the boundary, `context_id` and `reply_to` are whatever the composer put in its own hidden fields. This is the whole product path
    * from the reply handler's output: capture what `prepare_reply_assigns/4` hands the composer and publish that directly, which isolates the handler from the form
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  import Ecto.Query
  alias Bonfire.Classify.Simulate
  alias Bonfire.Classify.Categories
  alias Bonfire.Posts

  setup do
    me_account = fake_account!()
    me = fake_user!(me_account)
    other_account = fake_account!()
    other = fake_user!(other_account)

    %{
      me: me,
      me_conn: conn(user: me, account: me_account),
      other: other,
      other_conn: conn(user: other, account: other_account)
    }
  end

  # a members-private group made by `creator`, with `member` added, and a thread in it started by `starter`
  defp private_group_thread(creator, member, starter) do
    group =
      Simulate.fake_group!(creator, %{
        membership: "invite_only",
        visibility: "members:private",
        participation: "group_members",
        default_content_visibility: "members:private"
      })

    {:ok, _} = Categories.add_member(creator, group, id(member))

    {group, Simulate.fake_post_in_group!(starter, group, "<p>the thread</p>")}
  end

  # capture what the reply handler hands the composer, for `reply_via_handler/5`. Patched per test rather than in `setup`, since the composer tests need the real function; `mode: :shared` because the handler runs in the LiveView process
  defp capture_composer_open do
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
  end

  defp open_thread(conn, root) do
    {:ok, view, _html} = live(conn, "/discussion/#{id(root)}")

    # let the async preloads land, as they would in a browser, since `published_in` is read from them
    Process.sleep(1000)
    render(view)
    view
  end

  # the composer's hidden fields that decide where a reply goes and who reads it, printed on failure
  defp composer_state(form_html) do
    Regex.scan(
      ~r{<input[^>]*name="(?:reply_to\[reply_to_id\]|context_id|to_boundaries[^"]*|to_circles[^"]*)"[^>]*>},
      form_html
    )
    |> List.flatten()
    |> Enum.join("\n")
  end

  # the reply's id, found by its unique text, since submitting the form does not hand it back
  defp post_id_by_text!(text) do
    repo().one!(
      from(pc in Bonfire.Data.Social.PostContent,
        where: ilike(pc.html_body, ^"%#{text}%"),
        select: pc.id
      )
    )
  end

  # Press Reply on `target`, then submit the composer with only the text: everything else is what the composer itself put in the form
  defp reply_via_composer(conn, root, target, text) do
    view = open_thread(conn, root)

    view
    |> element("[data-id=action_reply][phx-value-id='#{id(target)}']")
    |> render_click()

    # the Reply press reaches the composer as a message to its own LiveView; rendering that view is a synchronous call, so the message has been handled by the time this returns
    composer = composer_view(view)
    render(composer)

    form_html = composer |> element("#smart_input_form") |> render()
    state = composer_state(form_html)

    assert form_html =~ ~s(value="#{id(target)}"),
           "control: pressing Reply did not reach the composer's reply_to field, so what follows would not be a reply to it. Composer fields:\n#{state}"

    submit_composer(view, "<p>#{text}</p>")

    {post_id_by_text!(text), state}
  end

  # Press Reply on `target`, capture what the reply handler hands the composer, and publish exactly that, mapped the way `PostsLiveHandler.publish_post/3` maps the submitted form
  defp reply_via_handler(conn, user, root, target, html) do
    view = open_thread(conn, root)

    view
    |> element("[data-id=action_reply][phx-value-id='#{id(target)}']")
    |> render_click()

    assert_receive {:composer_opened, assigns}, 2000

    {:ok, reply} =
      Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: html}, reply_to_id: assigns[:reply_to_id]},
        # the form submits each boundary's id, not the `{id, label}` pair the composer displays
        boundary: Enum.map(List.wrap(assigns[:to_boundaries]), &form_value/1),
        to_circles: Enum.map(List.wrap(assigns[:to_circles]), &form_value/1),
        context_id: assigns[:context_id]
      )

    {reply, assigns}
  end

  defp form_value({id, _label}), do: to_string(id)
  defp form_value(other), do: other

  # The page learns which process runs its composer when that process announces itself on mount, and keeps it, so a Reply press can reach the composer directly rather than by a lookup a test session cannot make
  test "after mount, the page knows which process runs its composer", %{
    me: me,
    me_conn: me_conn,
    other: other
  } do
    {_group, root} = private_group_thread(me, other, other)
    view = open_thread(me_conn, root)

    persistent = find_live_child(view, "persistent")
    assert persistent, "control: the page has a sticky composer process at all"

    # both renders are synchronous calls, so the child's announcement and the page's handling of it are done by now
    render(persistent)
    render(view)

    assert live_assigns(view)[:__context__][:child_pid] == persistent.pid
  end

  # Who made the group is a real branch: its creator holds `:administer` over it, a plain member holds only what membership grants, so a reply readable by one may not be by the other
  for group_creator <- [:me, :other] do
    # Parked: a Reply press reaches the composer through `PersistentLive.maybe_send/2`, which needs the composer's `child_pid` in the pressing handler's context, or a session token a LiveViewTest session does not have. The page now keeps `child_pid` in its own context (the test above), but the Reply runs in the activity's COMPONENT, whose context is a copy that never receives it, so the state still falls back to a `send_update` in the page process and the form keeps its defaults. Restore once `maybe_send/2` can find the pid from any component on the page (keeping it in the page process, OPEN in the plan), or as a browser test
    @tag skip:
           "the Reply runs in a component whose context copy lacks the composer's child_pid, and a LiveViewTest session has no token for the fallback"
    test "through the composer, my reply to someone's reply is readable by me and by them (group made by #{group_creator})",
         %{me: me, me_conn: me_conn, other: other, other_conn: other_conn} do
      {creator, member} =
        if unquote(group_creator) == :me, do: {me, other}, else: {other, me}

      {_group, root} = private_group_thread(creator, member, other)

      {my_reply, _} = reply_via_composer(me_conn, root, root, "my first reply")
      {their_reply, _} = reply_via_composer(other_conn, root, my_reply, "their reply to me")
      {my_nested, state} = reply_via_composer(me_conn, root, their_reply, "my nested reply")

      context = "Composer fields when I replied to their reply:\n#{state}"

      assert Bonfire.Boundaries.can?(other, :read, their_reply),
             "control: the other person's reply is readable, as reported"

      assert Bonfire.Boundaries.can?(me, :read, my_reply),
             "my top-level reply is not readable by me. #{context}"

      assert Bonfire.Boundaries.can?(me, :read, my_nested),
             "my own nested reply is not readable by me. #{context}"

      assert Bonfire.Boundaries.can?(other, :read, my_nested),
             "a fellow member cannot read my nested reply. #{context}"

      # the user-visible outcome: no placeholder in place of my comment when I open the thread
      html = me_conn |> open_thread(root) |> render()

      assert html =~ "my nested reply"
      refute html =~ "This comment is unavailable"
    end
  end

  test "from the reply handler's output, my reply to someone's reply is readable by me and by them",
       %{me: me, me_conn: me_conn, other: other, other_conn: other_conn} do
    {_group, root} = private_group_thread(me, other, other)
    capture_composer_open()

    {my_reply, _} = reply_via_handler(me_conn, me, root, root, "<p>my first reply</p>")

    {their_reply, _} =
      reply_via_handler(other_conn, other, root, my_reply, "<p>their reply to me</p>")

    {my_nested, nested_assigns} =
      reply_via_handler(me_conn, me, root, their_reply, "<p>my nested reply</p>")

    # what the composer was handed for the nested reply, printed on failure because it is the likeliest cause
    context =
      "nested reply composer assigns: #{inspect(Map.take(nested_assigns, [:to_boundaries, :context_id, :to_circles]))}"

    assert Bonfire.Boundaries.can?(other, :read, their_reply),
           "control: the other person's reply is readable, as reported"

    assert Bonfire.Boundaries.can?(me, :read, my_reply),
           "my top-level reply is not readable by me. #{context}"

    assert Bonfire.Boundaries.can?(me, :read, my_nested),
           "my own nested reply is not readable by me. #{context}"

    assert Bonfire.Boundaries.can?(other, :read, my_nested),
           "a fellow member cannot read my nested reply. #{context}"

    html = me_conn |> open_thread(root) |> render()

    assert html =~ "my nested reply"
    refute html =~ "This comment is unavailable"
  end

  # The other half of the same rule: @-mentioning someone in a group post notifies them but does not add them to the group's audience. Mentions grant only under the `public` and `mentions` presets (`Acls.mentions_grants/3`), and a group post is neither
  test "@-mentioning someone outside a members-private group does not let them read the post",
       %{me: me, other: other} do
    {group, _root} = private_group_thread(me, other, other)
    outsider = fake_user!()
    text = "<p>@#{outsider.character.username} have a look</p>"

    # control: the same text under the `mentions` preset DOES grant them, so the mention is recognised and the refusal below is the group's audience holding
    {:ok, mentions_post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: text}},
        boundary: "mentions"
      )

    assert Bonfire.Boundaries.can?(outsider, :read, mentions_post),
           "control: the mention was not recognised at all, so a refusal below would prove nothing"

    group_post = Simulate.fake_post_in_group!(me, group, text)

    assert Bonfire.Boundaries.can?(other, :read, group_post),
           "control: a member reads the group post"

    refute Bonfire.Boundaries.can?(outsider, :read, group_post),
           "an @-mention in a members-private group post granted someone outside the group"
  end

  # A reply in a group thread copies the group's audience, and ALSO grants the person it answers, even outside that audience: you are answering them, so they can read the answer. This is the difference from an @-mention (the test above), which only notifies. So a member removed from a private group still reads a reply addressed to them, but not the rest of the thread
  test "a reply in a group thread is readable by the person it answers, even outside the group's audience",
       %{me: me, me_conn: me_conn, other: other} do
    {group, root} = private_group_thread(me, other, other)

    fellow = fake_user!()
    {:ok, _} = Categories.add_member(me, group, id(fellow))

    fellow_post = Simulate.fake_post_in_group!(fellow, group, "<p>a fellow member's post</p>")

    {:ok, true} = Categories.remove_member(me, group, id(other))

    # not the root: that one is theirs, and keeping sight of your own post is right
    refute Bonfire.Boundaries.can?(other, :read, fellow_post),
           "control: the removal took effect, so the group's posts are closed to them"

    capture_composer_open()

    {reply, assigns} =
      reply_via_handler(me_conn, me, root, root, "<p>replying to someone who left</p>")

    assert Bonfire.Boundaries.can?(fellow, :read, reply),
           "the group's audience reads the reply"

    assert Bonfire.Boundaries.can?(other, :read, reply),
           "the person answered cannot read the answer. Composer assigns: #{inspect(Map.take(assigns, [:to_boundaries, :to_circles]))}"

    # the grant is to this reply only: the rest of the group, including the thread they started, stays closed
    refute Bonfire.Boundaries.can?(other, :read, fellow_post)
  end
end
