defmodule Bonfire.UI.Social.Activity.SubjectMinimalLiveTest do
  use ExUnit.Case, async: true

  # bare `ExUnit.Case` skips the tag the extension case templates apply, so without this it also runs in the federation CI leg
  @moduletag :ui

  alias Bonfire.UI.Social.Activity.SubjectMinimalLive

  describe "hide_boost_reason?/4" do
    test "hides a group's auto-boost of its own content, keeps a person's boost" do
      assert SubjectMinimalLive.hide_boost_reason?("Boost", "group", %{id: "group"}, :profile)
      refute SubjectMinimalLive.hide_boost_reason?("Boost", "person", %{id: "group"}, :profile)
    end

    test "keeps the line on surfaces that exist to say who acted" do
      for showing_within <- [:widget, :notifications] do
        refute SubjectMinimalLive.hide_boost_reason?(
                 "Boost",
                 "group",
                 %{id: "group"},
                 showing_within
               ),
               "expected #{showing_within} to keep the boost attribution"
      end
    end
  end
end
