defmodule Bonfire.UI.Social.Repo.Migrations.ImportMe do
  use Ecto.Migration

  import Bonfire.UI.Social.Migration
  # accounts & users

  def change, do: migrate_me

end
