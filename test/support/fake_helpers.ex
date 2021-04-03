defmodule Bonfire.UI.Social.Test.FakeHelpers do

  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Fake
  alias Bonfire.UI.Social.Identity.{Accounts, Users}
  import ExUnit.Assertions

  import Bonfire.UI.Social.Integration

  Bonfire.Common.Utils.import_if_available(Bonfire.Me.Fake)


end
