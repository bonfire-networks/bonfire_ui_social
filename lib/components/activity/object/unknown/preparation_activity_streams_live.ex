defmodule Bonfire.UI.Social.Activity.PreparationActivityStreamsLive do
  @moduledoc """
  A recipe preparation (AS2 `Preparation`, e.g. federated from cuisine.social).

  Renders the structured parts a `Post` would have thrown away: what it makes, how much of it, what
  goes in and what to do. The ingredients and steps only appear on the object's own page, so a feed
  entry stays the size of a post. The dish's photo is not rendered here: it is an `attachment`, so it
  is already shown as Media alongside the card.

  The document's `name`, `servingType` and each ingredient/step text arrive as AS2 language maps and
  are derived into plain properties at ingest by `ActivityPub.Federator.Transformer.fix_language_maps/1`.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop json, :any, default: nil
  prop object_type_readable, :any, default: nil
  prop showing_within, :any, default: nil
  prop viewing_main_object, :boolean, default: false

  defp object_field(json, field) do
    e(json, "object", field, nil) || e(json, field, nil)
  end

  @doc "Ingredients in the order the sender numbered them."
  def ingredients(json), do: json |> object_field("ingredients") |> in_position()

  @doc "Steps in the order the sender numbered them."
  def steps(json), do: json |> object_field("steps") |> in_position()

  defp in_position(items) do
    items
    |> List.wrap()
    |> Enum.filter(&is_map/1)
    |> Enum.sort_by(&e(&1, "position", 0))
  end

  @doc """
  How much of an ingredient, e.g. `"250 g"`, or `"1"` when it is counted rather than measured.

  Whole quantities lose the decimal point: a recipe asks for 1 aubergine, not 1.0.
  """
  def quantity_label(ingredient) do
    [number(e(ingredient, "quantity", nil)), e(ingredient, "unit", nil)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
  end

  @doc """
  How many the preparation makes, e.g. `"6 personnes"`, using the sender's own unit where it gave one.
  """
  def serving_label(json) do
    case number(object_field(json, "serving")) do
      nil ->
        nil

      serving ->
        case object_field(json, "servingType") do
          unit when is_binary(unit) and unit != "" -> "#{serving} #{unit}"
          _ -> l("Serves %{count}", count: serving)
        end
    end
  end

  @doc "The recipe's link for humans: its `url`, falling back to the AP `id` (which often serves JSON rather than a page)."
  def source_url(json), do: href(object_field(json, "url")) || object_field(json, "id")

  @doc "Host of a source URL, for the \"View on …\" link."
  def source_host(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> nil
    end
  end

  def source_host(_), do: nil

  defp href(url) when is_binary(url), do: url
  defp href(%{"href" => href}) when is_binary(href), do: href
  defp href([_ | _] = urls), do: Enum.find_value(urls, &href/1)
  defp href(_), do: nil

  # a recipe asks for 1 aubergine, not 1.0
  defp number(n) when is_float(n) and trunc(n) == n, do: to_string(trunc(n))
  defp number(n) when is_number(n), do: to_string(n)
  defp number(_), do: nil
end
