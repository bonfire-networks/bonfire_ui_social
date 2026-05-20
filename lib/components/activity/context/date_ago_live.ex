defmodule Bonfire.UI.Social.Activity.DateAgoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop date_ago, :any, default: nil
  prop date_time_format, :any, default: nil
  prop object_id, :any, default: nil
  prop activity_id, :any, default: nil
  prop parent_id, :any, default: nil

  def date_time_format(nil, context) do
    Settings.get([:ui, :date_time_format], :relative,
      context: context,
      name: l("Date format"),
      description: l("How to display the date/time of activities"),
      type: :select,
      options: Keyword.merge([relative: l("Relative")], DatesTimes.available_formats())
    )
  end

  def date_time_format(value, _context), do: value
end
