defmodule Ueberauth.Strategy.TwitchTv do
  @moduledoc """
  Provides an Ueberauth strategy for authenticating with Twitch.tv.

  ### Setup

  Create an application in Twitch.tv for you to use.

  Register a new application at: [your Twitch.tv developer page](https://www.twitch.tv/kraken/oauth2/clients/new) and get the `client_id` and `client_secret`.

  Include the provider in your configuration for Ueberauth

      config :ueberauth, Ueberauth,
        providers: [
          twitchtv: { Ueberauth.Strategy.TwitchtTv, [] }
        ]

  Then include the configuration for twitchtv.

      config :ueberauth, Ueberauth.Strategy.TwitchTv.OAuth,
        client_id: System.get_env("TWITCH_TV_CLIENT_ID"),
        client_secret: System.get_env("TWITCH_TV_CLIENT_SECRET")

  If you haven't already, create a pipeline and setup routes for your callback handler

      pipeline :auth do
        Ueberauth.plug "/auth"
      end

      scope "/auth" do
        pipe_through [:browser, :auth]

        get "/:provider/callback", AuthController, :callback
      end


  Create an endpoint for the callback where you will handle the `Ueberauth.Auth` struct

      defmodule MyApp.AuthController do
        use MyApp.Web, :controller

        def callback_phase(%{ assigns: %{ ueberauth_failure: fails } } = conn, _params) do
          # do things with the failure
        end

        def callback_phase(%{ assigns: %{ ueberauth_auth: auth } } = conn, params) do
          # do things with the auth
        end
      end

  You can edit the behaviour of the Strategy by including some options when you register your provider.

  To set the `uid_field`

      config :ueberauth, Ueberauth,
        providers: [
          twitchtv: { Ueberauth.Strategy.TwitchtTv, [uid_field: :email] }
        ]

  Default is `:login`

  To set the default 'scopes' (permissions):

      config :ueberauth, Ueberauth,
        providers: [
          twitchtv: { Ueberauth.Strategy.TwitchtTv, [default_scope: "user:read:email"] }
        ]

  Deafult is "user,public_repo"
  """
  use Ueberauth.Strategy,
    uid_field: :login,
    default_scope: "user:read:email",
    oauth2_module: Ueberauth.Strategy.TwitchTv.OAuth

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles the initial redirect to the twitch.tv authentication page.

  To customize the scope (permissions) that are requested by Twitch.Tv include them as part of your url:

      "/auth/twitchtv?scope=user,public_repo,gist"

  You can also include a `state` param that TwitchTv will return to you.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    params =
      [scope: scopes]
      |> with_param(:state, conn)

    opts = oauth_client_options_from_conn(conn)
    redirect!(conn, __MODULE__.OAuth.authorize_url!(params, opts))
  end

  @doc """
  Handles the callback from TwitchTv. When there is a failure from TwitchTv the failure is included in the
  `ueberauth_failure` struct. Otherwise the information returned from TwitchTv is returned in the `Ueberauth.Auth` struct.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    params = [code: code]
    opts = oauth_client_options_from_conn(conn)

    case __MODULE__.OAuth.get_access_token(params, opts) do
      {:ok, token} ->
        fetch_user(conn, token)

      {:error, {error_code, error_description}} ->
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw TwitchTv response around during the callback.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:twitch_tv_user, nil)
    |> put_private(:twitch_tv_token, nil)
  end

  @doc """
  Fetches the uid field from the twitch tv response. This defaults to the option `uid_field` which in-turn defaults to `login`
  """
  def uid(conn) do
    conn.private.twitch_tv_user[option(conn, :uid_field) |> to_string]
  end

  @doc """
  Includes the credentials from the twitch tv response.
  """
  def credentials(conn) do
    token = conn.private.twitch_tv_token
    # scopes = (token.other_params["scope"] || "")
    # |> String.split(",")

    %Credentials{
      token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      expires: !!token.expires_at
      # scopes: scopes
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.twitch_tv_user

    %Info{
      name: user["display_name"],
      image: user["profile_image_url"],
      first_name: nil,
      last_name: nil,
      nickname: nil,
      email: user["email"],
      location: nil,
      description: user["description"],
      phone: nil,
      urls: %{
        self: user["self"]
      }
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the Twitch Tv callback.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.twitch_tv_token,
        user: conn.private.twitch_tv_user,
        is_partnered: conn.private.twitch_tv_user["partnered"]
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :twitch_tv_token, token)
    path = "https://api.twitch.tv/helix/users"
    headers = [Authorization: "OAuth #{token.access_token}"]
    resp = Ueberauth.Strategy.TwitchTv.OAuth.get(token, path, headers)

    case resp do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: %{"data" => data}}}
      when status_code in 200..399 ->
        put_private(conn, :twitch_tv_user, List.first(data))

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp with_param(opts, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(opts, key, value), else: opts
  end

  defp with_optional(opts, key, conn) do
    if option(conn, key), do: Keyword.put(opts, key, option(conn, key)), else: opts
  end

  defp oauth_client_options_from_conn(conn) do
    base_options = [redirect_uri: callback_url(conn)]
    request_options = conn.private[:ueberauth_request_options].options

    case {request_options[:client_id], request_options[:client_secret]} do
      {nil, _} -> base_options
      {_, nil} -> base_options
      {id, secret} -> [client_id: id, client_secret: secret] ++ base_options
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
