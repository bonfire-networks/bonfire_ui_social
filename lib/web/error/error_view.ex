defmodule Bonfire.UI.Social.Web.ErrorView do
  use Bonfire.Web, {:view, [namespace: Bonfire.UI.Social]}

  @codes %{
    404=> "Not allowed",
    404=> "Not found",
    500=> "Something went wrong"
  }

  def render("403.html", assigns) do
    show_error(403, reason(assigns)<>"<p><img src='https://media.sciencephoto.com/image/c0021814/800wm'/>", true)
  end
  def render("404.html", _assigns) do
    show_html(404, "<img src='https://i.pinimg.com/originals/98/8d/ef/988def4abdcba22f2c9e907d041a56ce.gif'/>")
  end
  def render("500.html", assigns) do
    show_error(500, (reason(assigns) || "Please try again or contact the instance admins.")<>"<p><img src='https://media2.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.gif'/>", true)
  end

  def render("403.activity+json", assigns) do
    show_error(403, reason(assigns), false)
  end
  def render("404.activity+json", _assigns) do
    show_error(404, nil, false)
  end
  def render("500.activity+json", assigns) do
    show_error(500, (reason(assigns) || "Please try again or contact the instance admins."), false)
  end

  def render("403.json", assigns) do
    show_error(403, reason(assigns), false)
  end
  def render("404.json", assigns) do
    show_error(404, nil, false)
  end
  def render("500.json", assigns) do
    show_error(500, (reason(assigns) || "Please try again or contact the instance admins."), false)
  end

  defp show_error(error_code, details, as_html?) do
    error(details)

    if as_html?, do: show_html(error_code, details),
    else: Jason.encode!(%{
      "errors"=> [
        %{
          "status"=> error_code,
          "title"=> @codes[error_code],
          "detail"=> details
        }
      ]
    })
  end

  defp reason(%{reason: reason}), do: reason(reason)
  defp reason(%{message: reason}), do: reason
  defp reason(reason) when is_binary(reason), do: reason
  defp reason(reason), do: inspect reason

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # 404.
  def template_not_found(template, assigns) do
    warn(template, "No template defined for")
    show_error(Phoenix.Controller.status_message_from_template(template), Map.get(assigns, :reason, "Unknown Error"), true)
  end

  defp show_html(error_code, details) when is_integer(error_code), do: show_html(@codes[error_code], details)
  defp show_html(error, details) do
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

  <body id="layout-root" class="bg-base-200">
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
        <h1 class="text-primary-content">
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
