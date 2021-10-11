defmodule Bonfire.UI.Social.Components.Object.Character do
  use Surface.Catalogue.Example,
    catalogue: Bonfire.UI.Social.Components.Catalogue,
    subject: Bonfire.UI.Social.Activity.CharacterLive,
    height: "100px",
    direction: "vertical"

  def render(assigns) do
    ~F"""
    <CharacterLive 
      object={%{
        character: %{
          username: "bob"
        },
        profile: %{
          name: "Bob"
        }
      }}
      activity={%{
        subject_character: %{
          username: "alice",
          name: "Alice",
        },
        subject_profile: %{
          name: "Alice",
    
        },
        verb: "", 
      }
    }
    permalink="http://example.com",
    date_ago="1 day ago",
    verb_display="followed"
    />
    """
  end
end
