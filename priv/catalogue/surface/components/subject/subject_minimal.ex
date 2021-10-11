defmodule Bonfire.UI.Social.Components.Subject.SubjectMinimal do
  use Surface.Catalogue.Example,
    catalogue: Bonfire.UI.Social.Components.Catalogue,
    subject: Bonfire.UI.Social.Activity.SubjectMinimalLive,
    height: "100px",
    direction: "vertical"

  def render(assigns) do
    ~F"""
    <SubjectMinimalLive 
      activity={%{
        subject_character: %{
          username: "alice",
          name: "Alice",
        },
        subject_profile: %{
          name: "Alice",
    
        },
      }
    }
    verb="boost",
    verb_display="boosted"    
  />
    """
  end
end
