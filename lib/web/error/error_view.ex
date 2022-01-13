defmodule Bonfire.UI.Social.Web.ErrorView do
  use Bonfire.Web, {:view, [namespace: Bonfire.UI.Social]}

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  def render("404.html", _assigns) do
    html("Not found", "<img src='https://data.whicdn.com/images/304187249/original.gif'/>")
  end

  def render("500.html", %{current_account: current_account, reason: reason}) when not is_nil(current_account) do
    error(reason(reason))
  end
  def render("500.html", assigns) do
    IO.inspect(assigns)
    if Bonfire.Common.Config.get!(:env) != :prod, do: error(reason(Map.get(assigns, :reason, ""))),
    else: error("Please try again or contact the instance admins.")
  end

  defp error(error \\ "Something went wrong", details) do
    html(error, "#{details}<img src='https://media2.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.gif'/>")
  end

  defp reason(%{message: reason}), do: reason
  defp reason(reason), do: inspect reason

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    html(Phoenix.Controller.status_message_from_template(template))
  end

  def html(error, details \\ "") do
    raw """
    <!DOCTYPE html>
<html lang="en" class="dark">
  <head>
    <meta charset="utf-8"/>
    <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <meta name="description" content="Bonfire instance">
    <meta name="keywords" content="bonfire, fediverse">
    <meta name="author" content="Bonfire">
    <title data-suffix=" · Bonfire">Error · Bonfire</title>
    <link phx-track-static rel='stylesheet' href='/css/bonfire.css'/>
  </head>

  <body id="layout-root" class="bg-blueGray-50 dark:bg-neutral-800">
<div data-phx-main="true"><div id="layout-error">
<div class="">
<div class="flex flex-col mx-auto overflow-hidden lg:mt-4">
  <div class="relative z-10 flex justify-between flex-shrink-0 h-16">
      <div class="flex items-center flex-shrink-0 lg:px-4">
        <a data-phx-link="redirect" data-phx-link-state="push" href="/">
          <div class="flex items-center px-4 py-2 rounded">

            <div class="w-10 h-10 bg-center bg-no-repeat bg-contain" style="background-image: url(https://bonfirenetworks.org/img/bonfire.png)"></div>
          </div>
        </a>

        <div class="flex flex-1">
        </div>
      </div>

  </div>
</div>

    <div class="mx-auto mt-12 w-center">
      <div class="prose">
        <h1 class="text-primary-content-900">
          #{error}
        </h1>
          #{details}
      </div>
    </div>
    </div>
</div>
</div>
</html>
    """
  end
end
