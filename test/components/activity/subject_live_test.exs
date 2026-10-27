defmodule Bonfire.UI.Social.Activity.SubjectLiveTest do
  use ExUnit.Case, async: true

  @moduletag :ui

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Social.Activity.SubjectLive

  alias Bonfire.UI.Social.ActivityLive

  @viewer_id "01JBBBBBBBBBBBBBBBBBBBBBBB"

  test "hovercard_id: a post's creator shown under a boost or like gets a card" do
    user = %Needle.Pointer{
      id: "01JAAAAAAAAAAAAAAAAAAAAAAA",
      table_id: "5EVSER1S0STENS1B1YHVMAN01D"
    }

    assert ActivityLive.hovercard_id(
             user.id,
             %{subject: %Ecto.Association.NotLoaded{}},
             %{created: %{creator: user}},
             @viewer_id
           ) == user.id
  end

  test "hovercard_id: a group subject gets no card" do
    group = %Needle.Pointer{
      id: "01JDDDDDDDDDDDDDDDDDDDDDDD",
      table_id: "2AGSCANBECATEG0RY0RHASHTAG"
    }

    assert ActivityLive.hovercard_id(group.id, %{subject: group}, nil, @viewer_id) == nil
  end

  describe "hovercard_user/2, the post's loaded user for the profile hover card" do
    setup do
      user = %Needle.Pointer{
        id: "01JAAAAAAAAAAAAAAAAAAAAAAA",
        table_id: "5EVSER1S0STENS1B1YHVMAN01D"
      }

      booster = %Needle.Pointer{
        id: "01JCCCCCCCCCCCCCCCCCCCCCCC",
        table_id: "5EVSER1S0STENS1B1YHVMAN01D"
      }

      {:ok, user: user, booster: booster}
    end

    defp post_assigns(activity, object, viewer_id \\ "01JBBBBBBBBBBBBBBBBBBBBBBB"),
      do: %{activity: activity, object: object, __context__: %{current_user_id: viewer_id}}

    test "the loaded actor", %{user: user} do
      assert ActivityLive.hovercard_user(post_assigns(%{subject: user}, nil), user.id) == user
    end

    test "under a boost, the post's creator, not the booster", %{user: user, booster: booster} do
      assigns = post_assigns(%{subject: booster}, %{created: %{creator: user}})

      assert ActivityLive.hovercard_user(assigns, user.id) == user
    end

    test "nothing for the viewer, a group, or a user that wasn't loaded", %{user: user} do
      group = %Needle.Pointer{
        id: "01JDDDDDDDDDDDDDDDDDDDDDDD",
        table_id: "2AGSCANBECATEG0RY0RHASHTAG"
      }

      assert ActivityLive.hovercard_user(post_assigns(%{subject: user}, nil, user.id), user.id) ==
               nil

      assert ActivityLive.hovercard_user(post_assigns(%{subject: group}, nil), group.id) == nil

      assert ActivityLive.hovercard_user(
               post_assigns(%{subject: %Ecto.Association.NotLoaded{}}, nil),
               user.id
             ) == nil
    end
  end

  defp render_subject(overrides) do
    render_component(
      &SubjectLive.render/1,
      Map.merge(
        %{
          profile_name: "ivana",
          character_username: "ivan",
          path: "/@ivan",
          permalink: "/post/example",
          parent_id: "group-post",
          showing_within: :feed,
          published_in: %{profile: %{name: "Fedi Pub"}},
          published_in_path: "/group/fedi-pub",
          published_in_placement: :standalone,
          __context__: %{}
        },
        Map.new(overrides)
      )
    )
    |> Floki.parse_document!()
  end

  test "group destination shares the author line and links to the group" do
    for placement <- [:standalone, :chained] do
      html = render_subject(published_in_placement: placement)
      group = Floki.find(html, ~s([data-id="name_username"] > [data-role="author_group"]))

      assert Floki.text(group) =~ "in"
      assert Floki.text(group) =~ "Fedi Pub"
      assert Floki.attribute(Floki.find(group, "a"), "href") == ["/group/fedi-pub"]
      assert Floki.find(group, "svg") == []
    end
  end

  test "hidden publication context and nested parents do not repeat the group" do
    for overrides <- [[published_in_placement: :hidden], [activity_inception: "reply_to"]] do
      assert render_subject(overrides) |> Floki.find(~s([data-role="author_group"])) == []
    end
  end

  describe "profile hover card tagging" do
    @user_table_id "5EVSER1S0STENS1B1YHVMAN01D"
    @category_table_id "2AGSCANBECATEG0RY0RHASHTAG"
    # real ULIDs: `current_user_id/1` ignores anything that isn't an id
    @them "01JAAAAAAAAAAAAAAAAAAAAAAA"
    @me "01JBBBBBBBBBBBBBBBBBBBBBBB"
    @other "01JCCCCCCCCCCCCCCCCCCCCCCC"
    @group "01JDDDDDDDDDDDDDDDDDDDDDDD"

    test "ActivityLive.hovercard_id/4 tags the person the byline shows, found among the loaded entities" do
      alias Bonfire.UI.Social.ActivityLive

      them = %Needle.Pointer{id: @them, table_id: @user_table_id}
      other = %Needle.Pointer{id: @other, table_id: @user_table_id}
      group = %Needle.Pointer{id: @group, table_id: @category_table_id}

      # the actor is the person shown
      assert ActivityLive.hovercard_id(@them, %{subject: them}, nil, @me) == @them

      # my like of their post: the actor (me) isn't loaded, the byline shows the post's creator
      assert ActivityLive.hovercard_id(
               @them,
               %{subject: %Ecto.Association.NotLoaded{}},
               %{created: %{creator: them}},
               @me
             ) == @them

      # a group boosts their post: the actor is the group, the byline shows them
      assert ActivityLive.hovercard_id(
               @them,
               %{subject: group},
               %{created: %{creator: them}},
               @me
             ) ==
               @them

      # someone boosts a group's post: the byline shows the group, which gets no card
      assert ActivityLive.hovercard_id(
               @group,
               %{subject: other},
               %{created: %{creator: group}},
               @me
             ) ==
               nil

      # my own post
      assert ActivityLive.hovercard_id(
               @me,
               %{subject: %Needle.Pointer{id: @me, table_id: @user_table_id}},
               nil,
               @me
             ) ==
               nil

      # nothing loaded has the shown id: no card rather than a guess
      assert ActivityLive.hovercard_id(@them, %{subject: other}, nil, @me) == nil

      # `Types.object_type/2` would log an error for a NotLoaded actor
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          ActivityLive.hovercard_id(@them, %{subject: %Ecto.Association.NotLoaded{}}, nil, @me)
        end)

      refute log =~ "cannot detect the type"
    end

    # "no id, no attribute" sits in the same test so it can't pass before the prop is used
    test "the avatar, name and username links carry the hovercard_id they're given, and nothing without one" do
      tagged = render_subject(subject_id: @them, hovercard_id: @them)

      for link <- ["subject_avatar", "subject_name", "subject_username"] do
        assert Floki.attribute(Floki.find(tagged, ~s([data-id="#{link}"])), "data-hovercard-id") ==
                 [@them],
               "expected #{link} to carry the hover card id"
      end

      assert render_subject(subject_id: @them) |> Floki.find("[data-hovercard-id]") == []
    end
  end

  test "long group names remain intact" do
    name = "Fedi Pub — Community Organising & Decentralised Social Networks"
    html = render_subject(published_in: %{profile: %{name: name}})

    # the name alone: the link also holds the group's tile, which without an avatar is its initial
    assert html
           |> Floki.find(~s([data-role="author_group"] [data-role="group_name"]))
           |> Floki.text()
           |> String.trim() == name
  end
end
