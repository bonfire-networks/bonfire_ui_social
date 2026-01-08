defmodule Bonfire.UI.Social.WidgetSuggestedProfilesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  @default_cache_ttl 1_000 * 60 * 60 * 6

  @doc """
  Lists suggested profiles from the instance's suggested profiles circle.
  Results are cached for 6 hours since this is public, instance-wide data.
  """
  def list_suggested_profiles() do
    Cache.maybe_apply_cached(&do_list_suggested_profiles/0, [], expire: @default_cache_ttl)
  end

  defp do_list_suggested_profiles() do
    circle_id = Bonfire.Boundaries.Scaffold.Instance.suggested_profiles_circle()

    case Bonfire.Boundaries.Circles.list_members(circle_id, paginate: false) do
      members when is_list(members) ->
        members
        |> Enum.map(& &1.subject)
        |> Enum.reject(&is_nil/1)

      %{edges: members} ->
        members
        |> Enum.map(& &1.subject)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @doc """
  Resets the cached suggested profiles list.
  """
  def list_suggested_profiles_reset do
    Cache.reset(&do_list_suggested_profiles/0, [])
  end
end
