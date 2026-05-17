defmodule Bonfire.UI.Social.Feeds.DeferredJoinActualCasesTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  use Bonfire.Common.Config

  alias Bonfire.Classify.Simulate
  alias Bonfire.Posts

  setup do
    account = fake_account!()
    viewer = fake_user!(account)
    other_user = fake_user!()

    original_deferred = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
    Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], true)

    on_exit(fn ->
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_deferred)
    end)

    repo().delete_all(Bonfire.Data.Social.FeedPublish)

    %{account: account, viewer: viewer, other_user: other_user}
  end

  test "group feed load_more stays scoped with deferred join and unrelated activity noise", %{
    account: account,
    viewer: viewer,
    other_user: other_user
  } do
    limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)
    group_marker = "GROUP_DEFERRED_#{System.unique_integer([:positive])}"
    unrelated_marker = "GROUP_UNRELATED_#{System.unique_integer([:positive])}"
    private_marker = "GROUP_PRIVATE_#{System.unique_integer([:positive])}"

    group =
      Simulate.fake_group!(viewer, %{
        name: "Deferred Group",
        membership: "local:members",
        visibility: "nonfederated",
        participation: "anyone"
      })

    group_markers =
      for n <- 1..(limit * 3) do
        marker = "#{group_marker}_#{n}_END"
        Simulate.fake_post_in_group!(viewer, group, "<p>#{marker}</p>")
        marker
      end

    create_public_noise(viewer, unrelated_marker, limit * 3)
    create_private_noise(other_user, private_marker, limit * 12)

    session =
      conn(user: viewer, account: account)
      |> visit("/&#{group.character.username}")
      |> wait_async()
      |> refute_has("article", text: unrelated_marker)
      |> refute_has("article", text: private_marker)
      |> load_more_times(2)

    assert_all_present(session, group_markers)
    refute_has(session, "article", text: unrelated_marker)
    refute_has(session, "article", text: private_marker)
  end

  test "profile feed load_more stays scoped to the profile author", %{
    account: account,
    viewer: viewer,
    other_user: other_user
  } do
    limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)
    author = fake_user!()
    profile_marker = "PROFILE_DEFERRED_#{System.unique_integer([:positive])}"
    unrelated_marker = "PROFILE_UNRELATED_#{System.unique_integer([:positive])}"
    private_marker = "PROFILE_PRIVATE_#{System.unique_integer([:positive])}"

    profile_markers = create_public_noise(author, profile_marker, limit * 3)
    create_public_noise(viewer, unrelated_marker, limit * 3)
    create_private_noise(other_user, private_marker, limit * 12)

    session =
      conn(user: viewer, account: account)
      |> visit("/@#{author.character.username}")
      |> wait_async()
      |> refute_has("article", text: unrelated_marker)
      |> refute_has("article", text: private_marker)
      |> load_more_times(2)

    assert_all_present(session, profile_markers)
    refute_has(session, "article", text: unrelated_marker)
    refute_has(session, "article", text: private_marker)
  end

  test "hashtag feed load_more keeps the hashtag filter through deferred join windows", %{
    account: account,
    viewer: viewer,
    other_user: other_user
  } do
    limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)
    tag = "ActualDeferred#{System.unique_integer([:positive])}"
    tagged_marker = "HASHTAG_DEFERRED_#{System.unique_integer([:positive])}"
    unrelated_marker = "HASHTAG_UNRELATED_#{System.unique_integer([:positive])}"
    private_marker = "HASHTAG_PRIVATE_#{System.unique_integer([:positive])}"

    tagged_markers =
      for n <- 1..(limit * 3) do
        marker = "#{tagged_marker}_#{n}_END"
        publish(viewer, "public", "#{marker} ##{tag}")
        marker
      end

    create_public_noise(viewer, unrelated_marker, limit * 3)
    create_private_noise(other_user, private_marker, limit * 12)

    session =
      conn(user: viewer, account: account)
      |> visit("/hashtag/#{tag}")
      |> wait_async()
      |> refute_has("article", text: unrelated_marker)
      |> refute_has("article", text: private_marker)
      |> load_more_times(2)

    assert_all_present(session, tagged_markers)
    refute_has(session, "article", text: unrelated_marker)
    refute_has(session, "article", text: private_marker)
  end

  defp create_public_noise(user, marker_prefix, count) do
    for n <- 1..count do
      marker = "#{marker_prefix}_#{n}_END"
      publish(user, "public", marker)
      marker
    end
  end

  defp create_private_noise(user, marker_prefix, count) do
    for n <- 1..count do
      marker = "#{marker_prefix}_#{n}_END"
      publish(user, "mentions", marker)
      marker
    end
  end

  defp publish(user, boundary, body) do
    assert {:ok, _post} =
             Posts.publish(
               current_user: user,
               boundary: boundary,
               post_attrs: %{post_content: %{html_body: "<p>#{body}</p>"}}
             )
  end

  defp load_more_times(session, times) do
    Enum.reduce(1..times, session, fn _, current_session ->
      current_session
      |> assert_has("[data-id=load_more]")
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
    end)
  end

  defp assert_all_present(session, markers) do
    Enum.each(markers, fn marker ->
      assert_has(session, "article", text: marker)
    end)

    session
  end
end
