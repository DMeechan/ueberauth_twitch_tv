defmodule Ueberauth.Strategy.TwitchTv.OAuth do
  @moduledoc """
  An implementation of OAuth2 for Twitch.tv.

  To add your `client_id` and `client_secret` include these values in your configuration.

      config :ueberauth, Ueberauth.Strategy.TwitchTv.OAuth,
        client_id: System.get_env("TWITCH_TV_CLIENT_ID"),
        client_secret: System.get_env("TWITCH_TV_CLIENT_SECRET")
  """
  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://id.twitch.tv",
    authorize_url: "https://id.twitch.tv/oauth2/authorize",
    token_url: "https://id.twitch.tv/oauth2/token"
  ]

  @doc """
  Construct a client for requests to Twitch.tv.

  Optionally include any OAuth2 options here to be merged with the defaults.

      Ueberauth.Strategy.TwitchTv.OAuth.client(redirect_uri: "http://localhost:4000/auth/twitchtv/callback")

  This will be setup automatically for you in `Ueberauth.Strategy.TwitchTv`.
  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])
    opts = @defaults |> Keyword.merge(opts) |> Keyword.merge(config)
    json_library = Ueberauth.json_library()

    OAuth2.Client.new(opts)
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth. No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> OAuth2.Client.authorize_url!(params)
  end

  def get(token, url, headers \\ [], options \\ []) do
    client()
    |> put_param("client_secret", client().client_secret)
    |> put_header("Authorization", "Bearer #{token.access_token}")
    |> OAuth2.Client.get(url, headers, options)
  end

  def get_access_token(params \\ [], opts \\ []) do
    case opts |> client |> OAuth2.Client.get_token(params) do
      {:error, %{body: %{"error" => error, "error_description" => description}}} ->
        {:error, {error, description}}

      {:ok, %{token: %{access_token: nil} = token}} ->
        %{"error" => error, "error_description" => description} = token.other_params
        {:error, {error, description}}

      {:ok, %{token: token}} ->
        {:ok, token}
    end
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_param("client_secret", client.client_secret)
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end
