defmodule Bonfire.UI.Social.Components.Catalogue do
  use Surface.Catalogue

  @impl true
  def config() do
    [
      # WIP - find a better way to include the css
      head_css: """
      <link rel="stylesheet" href="https://bonjour.bonfire.cafe/css/bonfire-51715cf963ed6e7f47c721c27385e3ca.css?vsn=d" /> 
      """,
      # WIP - Uncaught SyntaxError: Invalid shorthand property initializer
      head_js: """
      <script src="//unpkg.com/alpinejs" defer></script>
      """
    ]
  end
end
