defmodule Bonfire.UI.Social.Test.ConnHelpers do

  import ExUnit.Assertions
  import Plug.Conn
  import Phoenix.ConnTest

      import Bonfire.UI.Common.Testing.Helpers

  import Phoenix.LiveViewTest
  # alias CommonsPub.Accounts
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.User

  @endpoint Bonfire.Common.Config.get!(:endpoint_module)


  def render_surface(component, assigns \\ []) do
    render_component(&component.render/1, Keyword.merge([__context__: %{}], assigns))
  end

  # defmacro render_surface(component, assigns) do
  #   quote do
  #     import Surface.LiveViewTest
  #     assigns = unquote(assigns)
  #     render_surface unquote(component)
  #   end
  # end

  ### conn

  def session_conn(conn \\ build_conn()), do: Plug.Test.init_test_session(conn, %{})



end
