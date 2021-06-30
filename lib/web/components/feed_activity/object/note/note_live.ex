defmodule Bonfire.UI.Social.Activity.NoteLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration

  def update(assigns, socket) do

    {:ok, socket |>
      assigns_merge(assigns,
        object: Map.merge( # fix this mess
          assigns.object,
          Map.get(assigns.object, :post_content, %{})
            |> Map.drop([:post_content])
        ) #|> IO.inspect
      )
    }
  end

end
