defmodule Bonfire.UI.Social.MultiselectLive.UserSelectorLive.LiveHandler do
  use Bonfire.Web, :live_handler

  def handle_event("select", %{"id" => id, "name"=>name, "field"=>field} = _attrs, socket) when is_binary(id) do

    # TODO, handle cases when we want to select multiple
    {:noreply,
        socket
        |> cast_self(
          {field, [{name, id}]}
        )
    }
  end

  def handle_event("deselect", %{"id" => _deselected, "field"=>field} = _attrs, socket) do

    {:noreply,
        socket
        |> cast_self(
          {field, []}
        )
    }
  end

end
