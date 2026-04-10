defmodule Bonfire.UI.Social.CommentsEmbedTokenTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

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

  describe "login with external go= redirects back with bonfire_embed_token" do
    test "redirect includes bonfire_embed_token when go is an allowed external origin", %{
      account: account,
      user: user
    } do
      conn =
        conn()
        |> Plug.Conn.fetch_session()
        |> Plug.Conn.put_session(:go, @media_uri)

      params = %{
        "login_fields" => %{
          "email_or_username" => user.character.username,
          "password" => account.credential.password
        }
      }

      conn = post(conn, "/login", params)

      redirect = redirected_to(conn, 303)
      assert redirect =~ @media_uri
      assert redirect =~ "bonfire_embed_token="

      # Token round-trip: use it to authenticate a CommentsLive and confirm the reply
      # composer appears (which only renders for signed-in users)
      token = URI.decode_query(URI.parse(redirect).query)["bonfire_embed_token"]

      {:ok, post} =
        Bonfire.Posts.publish(
          current_user: user,
          post_attrs: %{post_content: %{html_body: "test post"}},
          boundary: "public"
        )

      {:ok, view, _html} =
        live(conn(), "/comments/embed/#{post.id}?bonfire_embed_token=#{token}")

      assert has_element?(view, "#inline-reply-portal")
    end

    test "redirect does NOT include bonfire_embed_token when go is an internal path", %{
      account: account,
      user: user
    } do
      conn =
        conn()
        |> Plug.Conn.fetch_session()
        |> Plug.Conn.put_session(:go, "/feed")

      params = %{
        "login_fields" => %{
          "email_or_username" => user.character.username,
          "password" => account.credential.password
        }
      }

      conn = post(conn, "/login", params)

      redirect = redirected_to(conn, 303)
      refute redirect =~ "bonfire_embed_token="
    end

    test "redirect goes to external go URL from form param even when not an allowed embed origin",
         %{account: account, user: user} do
      # Override to a different allowed origin so @media_uri host is NOT allowed
      System.put_env("IFRAME_ALLOWED_ORIGINS", "https://other.example.com")
      # go comes as a form param (not session) — this is the real-world path from the login form
      conn = conn()

      params = %{
        "go" => @media_uri,
        "login_fields" => %{
          "email_or_username" => user.character.username,
          "password" => account.credential.password
        }
      }

      conn = post(conn, "/login", params)

      redirect = redirected_to(conn, 303)
      assert redirect =~ @media_uri
      refute redirect =~ "bonfire_embed_token="
    end

    test "redirect does NOT include bonfire_embed_token when go host is not in IFRAME_ALLOWED_ORIGINS",
         %{account: account, user: user} do
      System.put_env("IFRAME_ALLOWED_ORIGINS", "https://other.example.com")

      conn =
        conn()
        |> Plug.Conn.fetch_session()
        |> Plug.Conn.put_session(:go, @media_uri)

      params = %{
        "login_fields" => %{
          "email_or_username" => user.character.username,
          "password" => account.credential.password
        }
      }

      conn = post(conn, "/login", params)

      redirect = redirected_to(conn, 303)
      # should still redirect to the external URL, just without a token
      assert redirect =~ @media_uri
      refute redirect =~ "bonfire_embed_token="
    end
  end

  describe "login via RemoteInteractionLive redirects to external go" do
    test "login form on /remote_interaction page redirects to external go URL with token",
         %{account: account, user: user} do
      # go comes as a form param (the hidden input rendered by LoginViewLive)
      conn = conn()

      params = %{
        "go" => @media_uri,
        "login_fields" => %{
          "email_or_username" => user.character.username,
          "password" => account.credential.password
        }
      }

      conn = post(conn, "/login", params)

      redirect = redirected_to(conn, 303)
      assert redirect =~ @media_uri
      assert redirect =~ "bonfire_embed_token="
    end
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
