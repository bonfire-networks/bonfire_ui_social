defmodule Bonfire.UI.Social.Repo.Migrations.InitPointers  do
  @moduledoc false
  use Ecto.Migration
  import Needle.Migration
  import Needle.ULID.Migration

  def up(), do: init(:up)
  def down(), do: init(:down)

  defp init(dir) do
    init_pointers_ulid_extra(dir) # this one is optional but recommended
    init_pointers(dir) # this one is not optional
  end

end
