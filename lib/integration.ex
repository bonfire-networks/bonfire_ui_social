defmodule Bonfire.UI.Social.Integration do
  use Bonfire.Common.Config
  def repo, do: Bonfire.Common.Config.repo()
  def mailer, do: Bonfire.Common.Config.get!(:mailer_module)
end
