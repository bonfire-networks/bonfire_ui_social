defmodule Bonfire.UI.Social.SelectAutocompleteLive do
  use Bonfire.Web, :live_component

  def mount(socket) do
    {:ok, assign(socket, 
      search_results: [],
      search_phrase: ""
      )}
  end

  # def handle_event("suggest", %{"q" => query}, socket) when byte_size(query) <= 100 do
  #   {:noreply, assign(socket, matches: suggest(Enum.map(socket.assigns.locations, fn x -> x.name end), query))}
  # end


  # def handle_event("search", %{"q" => query}, socket) when byte_size(query) <= 100 do
  #   send(self(), {:search, query})
  #   {:noreply, assign(socket, query: query, result: "Searching...", loading: true, matches: [])}
  # end

  # def handle_info({:search, query}, socket) do
  #   {result, _} = System.cmd("dict", ["#{query}"], stderr_to_stdout: true)
  #   {:noreply, assign(socket, loading: false, result: result, matches: [])}
  # end
  def handle_event("search", %{"search_phrase" => search_phrase}, socket) do
    IO.inspect(socket)
    assigns = [
      search_results: search(Enum.map(socket.assigns.locations, fn x -> x.name end), search_phrase),
      search_phrase: search_phrase
    ]

    {:noreply, assign(socket, assigns)}
  end

  def handle_event("pick", %{"name" => search_phrase}, socket) do
    assigns = [
      search_results: [],
      search_phrase: search_phrase
    ]

    {:noreply, assign(socket, assigns)}
  end



  def search(""), do: []

  def search(list, prefix) do
    Enum.filter(list, &has_prefix?(&1, prefix))
  end

  defp has_prefix?(item, prefix) do
    String.starts_with?(String.downcase(item), String.downcase(prefix))
  end
end