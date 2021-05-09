defmodule Bonfire.UI.Social.Test.FakeHelpers do

  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Fake
  alias Bonfire.UI.Social.Identity.{Accounts, Users}
  import ExUnit.Assertions

  import Bonfire.UI.Social.Integration

  require Bonfire.Common.Extend
  Bonfire.Common.Extend.import_if_enabled(Bonfire.Me.Fake)


end
