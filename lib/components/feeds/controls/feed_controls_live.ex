defmodule Bonfire.UI.Social.FeedControlsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop event_target, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_name, :any, default: nil
  prop showing_within, :atom, default: nil
  prop feed_filters, :any, default: nil
  prop reloading, :boolean, default: false

  @doc "Returns the modal_assigns map for the feed filters modal content component."
  def feed_filters_modal_assigns(assigns) do
    [
      modal_component: Bonfire.UI.Social.FeedFiltersModalContentLive,
      modal_component_stateful?: true,
      event_target: assigns[:event_target],
      feed_id: assigns[:feed_id],
      feed_name: assigns[:feed_name],
      showing_within: assigns[:showing_within],
      feed_filters: assigns[:feed_filters]
    ]
  end

  @doc "Returns a list of {label, icon, filter_type, key} tuples for active filters."
  def active_filters(feed_filters, context \\ nil) do
    filters = Enums.maybe_to_map(feed_filters) || %{}

    time_filter(filters) ++
      sort_filter(filters) ++
      origin_filter(filters) ++
      type_filters(filters) ++
      circle_filters(filters, context)
  end

  defp time_filter(filters) do
    case e(filters, :time_limit, nil) do
      nil -> []
      0 -> []
      days ->
        label =
          Enum.find_value(
            Bonfire.UI.Social.TimeControlLive.default_options(),
            fn {v, name} -> if v == days, do: name end
          ) || "#{days}d"

        [{label, nil, :time_limit, days}]
    end
  end

  defp sort_filter(filters) do
    case e(filters, :sort_order, nil) do
      :asc -> [{l("Oldest first"), nil, :sort_order, :asc}]
      _ -> []
    end
  end

  defp origin_filter(filters) do
    case e(filters, :origin, nil) do
      origin when origin in [:local, [:local]] -> [{l("Local only"), nil, :origin, :local}]
      origin when origin in [:remote, [:remote]] -> [{l("Remote only"), nil, :origin, :remote}]
      _ -> []
    end
  end

  defp type_filters(filters) do
    filter_chips(filters, [:activity_types, :object_types, :media_types], :show) ++
      filter_chips(filters, [:exclude_activity_types, :exclude_object_types, :exclude_media_types], :hide)
  end

  defp filter_chips(filters, fields, icon) do
    Enum.flat_map(fields, fn field ->
      case e(filters, field, nil) do
        false -> []
        list when is_list(list) and list != [] ->
          Enum.map(list, fn key ->
            {String.capitalize(to_string(key)), icon, field, key}
          end)
        _ -> []
      end
    end)
  end

  defp circle_filters(filters, context) do
    case e(filters, :subject_circles, nil) do
      list when is_list(list) and list != [] ->
        my_circles = e(context, :my_circles, [])

        Enum.map(list, fn id ->
          name =
            Enum.find_value(my_circles, fn circle ->
              if e(circle, :id, nil) == id, do: e(circle, :name, nil)
            end)

          {name || l("Circle"), nil, :subject_circles, id}
        end)

      _ ->
        []
    end
  end
end
