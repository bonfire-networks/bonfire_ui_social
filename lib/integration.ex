defmodule Bonfire.UI.Social.Integration do

  def repo, do: Bonfire.Common.Config.get!(:repo_module)
  def mailer, do: Bonfire.Common.Config.get!(:mailer_module)

  def is_admin?(user) do
    if Map.get(user, :instance_admin) do
      Map.get(user.instance_admin, :is_instance_admin)
    else
      false # FIXME
    end
  end
end
