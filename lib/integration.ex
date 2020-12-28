defmodule Bonfire.UI.ValueFlows.Integration do

  def repo, do: Bonfire.Common.Config.get_ext!(:bonfire_ui_valueflows, :repo_module)

  def mailer, do: Bonfire.Common.Config.get_ext!(:bonfire_ui_valueflows, :mailer_module)

end
