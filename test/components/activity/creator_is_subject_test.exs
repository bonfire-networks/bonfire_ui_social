defmodule Bonfire.UI.Social.Activity.CreatorIsSubjectTest do
  use ExUnit.Case, async: true

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  doctest Bonfire.UI.Social.ActivityLive, only: [creator_is_subject?: 2], import: true
end
