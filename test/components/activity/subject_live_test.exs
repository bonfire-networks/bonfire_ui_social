defmodule Bonfire.UI.Social.Activity.SubjectLiveTest do
  use ExUnit.Case, async: true

  @moduletag :ui

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Social.Activity.SubjectLive

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

  test "long group names remain intact" do
    name = "Fedi Pub — Community Organising & Decentralised Social Networks"
    html = render_subject(published_in: %{profile: %{name: name}})

    assert html |> Floki.find(~s([data-role="author_group"] a)) |> Floki.text() |> String.trim() ==
             name
  end
end
