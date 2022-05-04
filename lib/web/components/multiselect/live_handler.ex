defmodule Bonfire.UI.Social.MultiselectLive.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  def handle_event("select", %{"id" => id, "name"=>name, "field"=>field} = _attrs, socket) when is_binary(id) do
    debug("selected for #{field} : #{name}")
    # TODO, handle cases when we want to select multiple
    {:noreply,
        socket
        |> assign_global(
          {field, [{name, id}]}
        )
    }
  end

  def handle_event("deselect", %{"id" => _deselected, "field"=>field} = _attrs, socket) do

    {:noreply,
        socket
        |> assign_global(
          {field, []}
        )
    }
  end

end
