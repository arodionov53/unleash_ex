defmodule Unleash.Client do
  @moduledoc false
  require Logger

  @callback features(String.t()) :: {:ok, map()} | :cached
  @callback register_client() :: {:ok, map()} | :cached
  @callback metrics(map()) :: {:ok, map()} | :cached

  alias Unleash.Config
  alias Unleash.Features
  @appname "UNLEASH-APPNAME"
  @instance_id "UNLEASH-INSTANCEID"
  @authorization "Authorization"
  @if_none_match "If-None-Match"
  @sdk_version "unleash_ex:#{Mix.Project.config()[:version]}"
  @accept {"Accept", "application/json"}

  def features(etag \\ nil) do
    headers = headers(etag)
    url = "#{Config.url()}/client/features"

    Config.http_client().get(url, headers)
    |> handle_feature_response()
  end

  def register_client,
    do:
      register(%{
        sdkVersion: @sdk_version,
        strategies: Config.strategy_names(),
        started:
          DateTime.utc_now()
          |> DateTime.to_iso8601(),
        interval: Config.metrics_period()
      })

  def register(client) do
    url = "#{Config.url()}/client/register"

    result = send_data(url, client)

    case Config.http_client().status_code!(result) do
      # following go implementaion
      sc when sc >= 200 and sc < 300 ->
        {:ok,
         result
         |> Config.http_client().response_body!()
         |> jdecode()}

      _ ->
        {:error, Config.http_client().response_body!(result)}
    end
  end

  def metrics(met) do
    url = "#{Config.url()}/client/metrics"
    send_data(url, met)
  end

  defp handle_feature_response(response) do
    case Config.http_client().status_code!(response) do
      304 ->
        :cached

      200 ->
        if :persistent_term.get(Config.persisten_term_key(), false) == false do
          :persistent_term.put(Config.persisten_term_key(), true)
          Logger.info("unleash client is ready")
        end

        features =
          response
          |> Config.http_client().response_body!()
          |> Jason.decode!()
          |> Features.from_map!()

        etag =
          response
          |> Config.http_client().response_headers!()
          |> Map.new()
          |> Map.get("etag", :ok)

        {:ok, %{etag: etag, features: features}}

      i when i >= 400 ->
        {:error, Config.http_client().response_body!(response)}

      _status ->
        {:ok, :cached}
    end
  end

  defp send_data(url, data) do
    data
    |> tag_data()
    |> Jason.encode!()
    |> then(&Config.http_client().post(url, headers(), &1))
  end

  defp headers(nil), do: headers()

  defp headers(etag) when is_atom(etag),
    do: headers(Atom.to_string(etag))

  defp headers(etag),
    do: headers() ++ [{@if_none_match, etag}]

  defp headers do
    cust_headers = Config.custom_headers()
    token = Config.auth_token()

    ((token && [{@authorization, token} | cust_headers]) || cust_headers) ++
      [
        {@appname, Config.appname()},
        {@instance_id, Config.instance_id()},
        @accept
      ]
  end

  defp tag_data(data) do
    data
    |> maybe_add(:appName, Config.appname())
    |> maybe_add(:instanceId, Config.instance_id())
  end

  defp maybe_add(data, _key, v) when is_nil(v) or v == "", do: data
  defp maybe_add(data, key, v), do: Map.put(data, key, v)

  def telemetry_metadata(metadata \\ %{}) do
    Config.telemetry_metadata() |> Map.merge(metadata)
  end

  defp jdecode(str) do
    case Jason.decode(str) do
      {:ok, dec} -> dec
      _ -> ""
    end
  end
end
