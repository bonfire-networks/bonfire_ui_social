defmodule Bonfire.UI.Social.CommentsEmbedTokenTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  # see also Bonfire.UI.Me.LoginController.Test

  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.LivePlugs.LoadCurrentUserFromEmbedToken

  @external_host "https://blog.example.com"
  @media_uri "#{@external_host}/my-article/"

  setup do
    # Allow the external host so LoginController appends a token on redirect
    System.put_env("IFRAME_ALLOWED_ORIGINS", @external_host)
    on_exit(fn -> System.delete_env("IFRAME_ALLOWED_ORIGINS") end)

    account = fake_account!()
    user = fake_user!(account)
    {:ok, account} = Accounts.confirm_email(account)

    {:ok, account: account, user: user}
  end

  describe "CommentsLive with media_uri sets go meta tag" do
    test "renders session-param-go so guests are redirected back after login",
         %{user: user} do
      # Stub HTTP so the media fetch returns a minimal HTML page for the external URL
      Tesla.Mock.mock_global(fn _env ->
        {:ok,
         %Tesla.Env{
           status: 200,
           body: "<html><head><title>Test</title></head><body></body></html>"
         }}
      end)

      {:ok, _view, html} =
        live(conn(), "/comments/embed?media_uri=#{URI.encode(@media_uri)}&creator=#{user.id}")

      assert html =~ "session-param-go"
      assert html =~ @media_uri
    end
  end

  describe "CommentsLive authenticates from bonfire_embed_token param" do
    test "visiting /comments/embed/:id with a valid token renders the reply composer", %{
      user: user
    } do
      {:ok, post} =
        Bonfire.Posts.publish(
          current_user: user,
          post_attrs: %{post_content: %{html_body: "test post"}},
          boundary: "public"
        )

      token = LoadCurrentUserFromEmbedToken.sign(@endpoint, user.id)

      conn = conn()

      {:ok, view, _html} =
        live(conn, "/comments/embed/#{post.id}?bonfire_embed_token=#{token}")

      # The inline reply portal only renders when current_user_id is set
      assert has_element?(view, "#inline-reply-portal")
    end

    test "visiting /comments/embed/:id with an invalid token does not render the reply composer",
         %{user: user} do
      {:ok, post} =
        Bonfire.Posts.publish(
          current_user: user,
          post_attrs: %{post_content: %{html_body: "test post"}},
          boundary: "public"
        )

      conn = conn()

      {:ok, view, _html} =
        live(conn, "/comments/embed/#{post.id}?bonfire_embed_token=badtoken")

      refute has_element?(view, "#inline-reply-portal")
    end
  end
end
