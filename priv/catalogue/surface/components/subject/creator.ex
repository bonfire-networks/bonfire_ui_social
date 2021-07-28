defmodule Bonfire.UI.Social.Components.Subject.Creator do
  use Surface.Catalogue.Example,
    catalogue: Bonfire.UI.Social.Components.Catalogue,
    subject: Bonfire.UI.Social.Activity.CreatorLive,
    height: "100px",
    direction: "vertical"

  def render(assigns) do
    ~F"""
    <CreatorLive 
      profile={%{
        character: %{
          username: "bob"
        }
      }}
      character={%{
          username: "alice",
          name: "Alice", 
      }
    }
    permalink="http://example.com",
    date_ago="1 day ago",
    created_verb_display="followed"
    />
    """
  end
end
