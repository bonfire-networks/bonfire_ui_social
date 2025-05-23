defmodule Bonfire.UI.Social.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MyApp.Web.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest

      import Bonfire.UI.Common.Testing.Helpers

      import Phoenix.LiveViewTest
      import Surface.LiveViewTest
      # import Bonfire.UI.Social.ConnCase
      import Bonfire.UI.Social.Test.ConnHelpers
      import Bonfire.UI.Social.Test.FakeHelpers

      import PhoenixTest

      use Bonfire.Common.Config
      use Bonfire.Common.Settings
      import Untangle
      use Arrows
      # alias Bonfire.UI.Social.Router.Helpers, as: Routes
      use Bonfire.Common.Repo

      # The default endpoint for testing
      @endpoint Application.compile_env!(:bonfire, :endpoint_module)
    end
  end

  setup tags do
    # import Bonfire.UI.Social.Integration

    Bonfire.Common.Test.Interactive.setup_test_repo(tags)

    {:ok, []}
  end
end
