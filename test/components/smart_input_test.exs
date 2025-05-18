defmodule Bonfire.UI.Social.SmartInputTest do
  use Bonfire.UI.Social.ConnCase, async: true
  use Bonfire.Common.Utils
  import Bonfire.Files.Simulation

  alias Bonfire.Social.Fake
  alias Bonfire.Files.Test

  test "create a post with uploads" do
    # Create alice user
    account = fake_account!()
    alice = fake_user!(account)

    conn = conn(user: alice, account: account)

    file = Path.expand("../fixtures/icon.png", __DIR__)
    file2 = Path.expand("../fixtures/favicon-16x16.png", __DIR__)

    session =
      conn
      |> visit("/write")
      |> assert_has_or_open_browser("input[name=files][type=file]")

    # |> fill_in("#editor_hidden_input", "Content", with: "here is an epic html post")

    # find_cid!(session.view, "#smart_input_form")
    # |> IO.inspect(label: "form cid")

    session
    |> upload("Upload an attachment", file)
    |> upload("Upload an attachment", file2)
    |> click_button("Publish")
    |> visit("/feed/local")
    |> assert_has_or_open_browser("[data-id=feed] article[data-id=article_media]", count: 2)
  end

  # alias Phoenix.LiveViewTest.DOM
  # defp find_cid!(view, selector) do
  #   html_tree = view |> render() |> DOM.parse()

  #   with {:ok, form} <- DOM.maybe_one(html_tree, selector) do
  #     form
  #     |> IO.inspect(label: "form")
  #     [cid | _] = targets_from_node(html_tree, form)
  #     cid
  #   else
  #     {:error, _reason, msg} -> raise ArgumentError, msg
  #   end
  # end

  # def targets_from_node(tree, node) do
  #   case node && DOM.all_attributes(node, "phx-target") |> IO.inspect(label: "phxt") do
  #     nil -> [nil]
  #     [] -> [nil]
  #     [selector] -> targets_from_selector(tree, selector)
  #   end
  # end

  # def targets_from_selector(tree, selector)

  # def targets_from_selector(_tree, nil), do: [nil]

  # def targets_from_selector(_tree, cid) when is_integer(cid), do: [cid]

  # def targets_from_selector(tree, selector) when is_binary(selector) do
  #   case Integer.parse(selector) |> IO.inspect(label: "int") do
  #     {cid, ""} ->
  #       [cid]

  #     _ ->
  #       case DOM.all(tree, selector) |> IO.inspect(label: "all") do
  #         [] ->
  #           [nil]

  #         elements ->
  #           for element <- elements do
  #             if cid = DOM.component_id(element) |> IO.inspect(label: "cid") do
  #               String.to_integer(cid)
  #             end
  #           end
  #       end
  #   end
  # end

  # def component_id(html_tree), do: Floki.attribute(html_tree, "data-phx-component") |> List.first()
end
