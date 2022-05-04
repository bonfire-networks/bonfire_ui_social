defmodule Bonfire.UI.Social.BlocksLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop user, :map
  prop selected_tab, :string
  prop blocks, :list, default: []
  prop page_info, :any
  prop scope, :atom

  def update(assigns, socket) do
    current_user = current_user(assigns)
    tab = e(assigns, :selected_tab, nil)
    scope = e(assigns, :scope, nil)

    block_type = (if tab=="ghosted", do: :ghost, else: :silence)

    circle = Bonfire.Boundaries.Blocks.list(block_type, (scope || current_user))
    # |> dump

    blocks = e(circle, :encircles, [])
    # |> debug

    # blocks = for block <- blocks, do: %{activity:
    #   block
    #   |> Map.put(:verb, %{verb: block_type})
    #   |> Map.put(:object, e(block, :subject, nil))
    #   |> Map.put(:subject, e(block, :caretaker, nil))
    # } #|> debug

    {:ok, socket
    |> assign(
      scope: scope, # user or instance-wide?
      page: tab,
      selected_tab: tab,
      block_type: block_type,
      # page_title: "Flags",
      current_user: current_user,
      blocks: blocks,
      # page_info: e(q, :page_info, [])
      )}
  end

end
