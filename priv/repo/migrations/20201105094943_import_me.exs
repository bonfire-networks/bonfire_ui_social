defmodule Bonfire.Website.Repo.Migrations.ImportMe do
  use Ecto.Migration

  import Bonfire.Website.Migration
  # accounts & users

  def change, do: migrate_me

end
