defmodule Bonfire.UI.Social.Activity.NoteLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration

  prop object, :any
  prop activity, :any
  prop viewing_main_object, :boolean
  prop permalink, :string
  prop date_ago, :string
  prop showing_within, :any

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
