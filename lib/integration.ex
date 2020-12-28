defmodule Bonfire.UI.ValueFlows.Integration do

  def repo, do: Bonfire.Common.Config.get_ext!(:bonfire_ui_social, :repo_module)

  def mailer, do: Bonfire.Common.Config.get_ext!(:bonfire_ui_social, :mailer_module)

end
