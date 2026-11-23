defmodule Bonfire.UI.Social.SortItemsDropdownLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop feed_filters, :any, default: nil
  prop event_target, :any, default: nil

  @doc """
  Whether the filters have a Happening filter (when things happen, eg. events), which is when sorting by that is offered: things without dates have no start to sort by.

      iex> Bonfire.UI.Social.SortItemsDropdownLive.starts_sort?(%{time_span: :upcoming})
      true
      iex> Bonfire.UI.Social.SortItemsDropdownLive.starts_sort?(%{happening_from: ~U[2030-01-01 00:00:00Z]})
      true
      iex> Bonfire.UI.Social.SortItemsDropdownLive.starts_sort?(%{time_span: nil, time_limit: 7})
      false
      iex> Bonfire.UI.Social.SortItemsDropdownLive.starts_sort?(nil)
      false
  """
  def starts_sort?(filters) do
    filters = Enums.maybe_to_map(filters) || %{}

    Enum.any?([:time_span, :happening_from, :happening_until], &(not is_nil(filters[&1])))
  end

  @doc """
  Whether sorting by when things happen goes latest first, which is when the filters are about past things (earliest first otherwise).

      iex> Bonfire.UI.Social.SortItemsDropdownLive.starts_sort_desc?(%{time_span: :past})
      true
      iex> Bonfire.UI.Social.SortItemsDropdownLive.starts_sort_desc?(%{time_span: :upcoming})
      false
      iex> Bonfire.UI.Social.SortItemsDropdownLive.starts_sort_desc?(nil)
      false
  """
  def starts_sort_desc?(filters) do
    filters = Enums.maybe_to_map(filters) || %{}

    filters[:time_span] in [:past, :past_and_current, "past", "past_and_current"]
  end

  @doc "The label of the sort by when things happen: soonest first, or most recent first for past things."
  def starts_sort_label(filters) do
    if starts_sort_desc?(filters), do: l("Most recent first"), else: l("Soonest first")
  end
end
