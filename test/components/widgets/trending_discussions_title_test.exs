defmodule Bonfire.UI.Social.WidgetTrendingDiscussionsTitleTest do
  @moduledoc "The dashboard's \"Top discussions\" block takes its title, empty message and \"View all\" label from the `:top_discussions` vocabulary preset in use, so an instance can word it as a call to write (\"What do you hear in the school yard?\"). The dashboard catalogue used to pass the title as a literal, which beat any setting."
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Common.Vocabulary

  @widget "[data-id=trending_discussions_widget]"
  @heading "#{@widget} [data-role=widget-heading]"
  @school_yard "What do you hear in the school yard?"

  setup do
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)

    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account), me: me}
  end

  # an instance's own wording, as it would put it in its config
  defp use_school_yard_preset(extra \\ %{}) do
    Process.put(
      [:bonfire_common, Vocabulary, :custom_presets],
      top_discussions: %{
        school_yard: Map.merge(%{base: :top_discussions, title: @school_yard}, extra)
      }
    )

    choose(:school_yard)
  end

  defp choose(preset_id),
    do: Process.put([:bonfire_common, Vocabulary, :top_discussions], preset_id)

  # the list is cached per user for an hour, so each visit that needs a fresh list is a user of its own
  defp new_user do
    account = fake_account!()
    me = fake_user!(account)

    {conn(user: me, account: account), me}
  end

  defp dashboard(conn) do
    {:ok, view, _html} = live(conn, "/dashboard")

    view |> render_async() |> Floki.parse_document!()
  end

  defp heading(doc), do: doc |> Floki.find(@heading) |> Floki.text() |> String.trim()

  # `LinkLive` turns its `label` into the link's aria-label
  defp view_all_link(doc),
    do: Floki.find(doc, ~s(#{@widget} a[href$="/feed/trending_discussions"]))

  defp fake_discussion(me) do
    Bonfire.Posts.Fake.fake_post!(me, "public", %{
      post_content: %{html_body: "something people are talking about"}
    })
  end

  test "without a choice the block keeps its title", %{conn: conn} do
    doc = dashboard(conn)

    assert [_] = Floki.find(doc, @widget), "control: the block is on the dashboard"
    assert heading(doc) == "Top discussions"
  end

  # whatever the extension ships, now or later, the block shows it. The expected text comes from `Vocabulary`, so what is checked is that the widget reads it
  test "each built-in wording is the title and the empty message" do
    for id <- Map.keys(Vocabulary.built_in(:top_discussions)) do
      choose(id)
      preset = Vocabulary.preset(:top_discussions, nil)
      {conn, _me} = new_user()

      doc = dashboard(conn)

      assert heading(doc) == Vocabulary.phrase(preset, :title), "title of #{inspect(id)}"

      assert doc |> Floki.find(@widget) |> Floki.text() =~ Vocabulary.phrase(preset, :empty),
             "empty message of #{inspect(id)}"
    end
  end

  test "each built-in wording labels the \"View all\" link" do
    for id <- Map.keys(Vocabulary.built_in(:top_discussions)) do
      choose(id)
      preset = Vocabulary.preset(:top_discussions, nil)
      {conn, me} = new_user()
      fake_discussion(me)

      link = conn |> dashboard() |> view_all_link()

      assert Floki.attribute(link, "aria-label") == [Vocabulary.phrase(preset, :view_all)],
             "label of #{inspect(id)}"
    end
  end

  test "an instance's own wording is the title", %{conn: conn} do
    use_school_yard_preset()

    assert dashboard(conn) |> heading() == @school_yard
  end

  test "a wording that leaves out the empty message takes its base's", %{conn: conn} do
    use_school_yard_preset()

    text = conn |> dashboard() |> Floki.find(@widget) |> Floki.text()

    assert text =~ "No popular discussions yet. Why not start one?"
  end

  test "a wording that leaves out the \"View all\" label takes its base's", %{conn: conn, me: me} do
    fake_discussion(me)
    use_school_yard_preset()

    link = conn |> dashboard() |> view_all_link()

    assert [_] = link, "control: the link is there"
    assert Floki.attribute(link, "aria-label") == ["View all top discussions"]
  end

  test "a wording can have its own \"View all\" label", %{conn: conn, me: me} do
    fake_discussion(me)
    use_school_yard_preset(%{view_all: "View all conversations"})

    link = conn |> dashboard() |> view_all_link()

    assert [_] = link, "control: the link is there"
    assert Floki.attribute(link, "aria-label") == ["View all conversations"]
  end

  test "the link still reads \"View all\" for the eye", %{conn: conn, me: me} do
    fake_discussion(me)
    use_school_yard_preset(%{view_all: "View all conversations"})

    assert conn |> dashboard() |> view_all_link() |> Floki.text() =~ "View all"
  end
end
