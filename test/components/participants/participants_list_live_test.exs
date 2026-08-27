defmodule Bonfire.UI.Social.ParticipantsListLiveTest do
  use Bonfire.UI.Social.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Social.ParticipantsListLive

  defmodule Host do
    use Bonfire.UI.Common.Web, :stateless_component

    prop participants, :list, required: true
    prop limit, :integer, default: 5

    def render(assigns) do
      ~F"""
      <ParticipantsListLive
        id="participants_test"
        participants={@participants}
        limit={@limit}
        list_class="test-list"
        item_class="test-item"
        toggle_class="test-toggle"
        show_toggle_icon
        :let={participant: participant}
      >
        <:collapsed_label>Show more</:collapsed_label>
        <span data-role="participant">{participant}</span>
      </ParticipantsListLive>
      """
    end
  end

  test "shows the first five participants with the custom disclosure label" do
    html = render_component(&Host.render/1, %{participants: Enum.to_list(1..7)})

    assert html =~ ~s(id="participants_test_wrapper")
    assert html =~ ~s(id="participants_test_toggle")
    assert html =~ ~s(aria-expanded="false")
    assert html =~ "Show more"
    refute html =~ "Show 2 more"

    {:ok, document} = Floki.parse_fragment(html)
    assert length(Floki.find(document, ~s([data-role="participant"]))) == 5
    assert Floki.find(document, ~s(button.test-toggle)) != []
  end

  test "omits the disclosure when every participant is visible" do
    html = render_component(&Host.render/1, %{participants: Enum.to_list(1..5)})

    {:ok, document} = Floki.parse_fragment(html)
    assert length(Floki.find(document, ~s([data-role="participant"]))) == 5
    assert Floki.find(document, ~s([data-role="toggle_participants"])) == []
  end

  test "the disclosure event preserves the visible list and flips its expanded state" do
    socket = %Phoenix.LiveView.Socket{assigns: %{expanded: false, __changed__: %{}}}

    assert {:noreply, socket} =
             ParticipantsListLive.handle_event("toggle_participants", %{}, socket)

    assert socket.assigns.expanded
  end
end
