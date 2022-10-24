defmodule Bonfire.UI.Social.Integration do
  def repo, do: Bonfire.Common.Config.repo()
  def mailer, do: Bonfire.Common.Config.get!(:mailer_module)

  def is_admin?(user) do
    if is_map(user) and Map.get(user, :instance_admin) do
      Map.get(user.instance_admin, :is_instance_admin)
    else
      # FIXME
      false
    end
  end
end
