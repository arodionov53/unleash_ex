defmodule Unleash.ClientTest do
  use ExUnit.Case

  import Mox

  alias Unleash.Client
  alias Unleash.Config

  setup :set_mox_from_context

  setup do
    http_client = Application.get_env(:unleas, :http_client)

    Application.put_env(:unleash, :http_client, SimpleHttpMock)

    on_exit(fn ->
      Application.put_env(:unleash, :http_client, http_client)
    end)

    :ok
  end

  describe "features/1" do
    test "returns features on success" do
      SimpleHttpMock
      |> expect(:get, fn _url, _headers ->
        {:ok,
         %SimpleHttp.Response{
           body: ~S({"version": "2", "features":[]}),
           headers: [{"etag", "x"}],
           status: 200
         }}
      end)
      |> expect(:status_code!, fn _ -> 200 end)
      |> expect(:response_body!, fn _ -> ~S({"version": "2", "features":[]}) end)
      |> expect(:response_headers!, fn _ -> [{"etag", "x"}] end)

      assert {:ok, %{etag: "x", features: %Unleash.Features{}}} = Client.features()
    end

    test "returns error on 4xx response" do
      SimpleHttpMock
      |> expect(:get, fn _url, _headers ->
        {:error, %SimpleHttp.Response{}}
      end)
      |> expect(:status_code!, fn _ -> 404 end)
      |> expect(:response_body!, fn _ -> ~S({"version": "2", "features":[]}) end)

      assert {:error, "{\"version\": \"2\", \"features\":[]}"} = Client.features()
    end

    test "raises on exception" do
      SimpleHttpMock
      |> expect(:get, fn _url, _headers ->
        raise "Unexpected error"
      end)

      assert_raise RuntimeError, fn -> Client.features() end
    end
  end

  describe "register_client/0" do
    test "returns decoded body on success" do
      SimpleHttpMock
      |> expect(:post, fn _url, _headers, _body ->
        {:ok, %SimpleHttp.Response{status: 200}}
      end)
      |> expect(:status_code!, fn _ -> 200 end)
      |> expect(:response_body!, fn _ -> ~S({"version": "2", "features":[]}) end)

      assert {:ok, %{"features" => [], "version" => "2"}} = Client.register_client()
    end

    test "returns error on non-2xx response" do
      SimpleHttpMock
      |> expect(:post, fn _url, _headers, _body ->
        {:error, %SimpleHttp.Response{status: 503}}
      end)
      |> expect(:status_code!, fn _ -> 503 end)
      |> expect(:response_body!, fn _ -> ~S() end)

      assert {:error, ""} = Client.register_client()
    end

    test "raises on exception" do
      SimpleHttpMock
      |> expect(:post, fn _url, _headers, _body ->
        raise "Unexpected error"
      end)

      assert_raise RuntimeError, fn -> Client.register_client() end
    end
  end

  describe "metrics/1" do
    test "returns response on success" do
      SimpleHttpMock
      |> expect(:post, fn _url, _headers, _body ->
        {:ok, %SimpleHttp.Response{status: 200}}
      end)

      assert {:ok, %SimpleHttp.Response{}} = Client.metrics(%{})
    end

    test "returns error response on failure" do
      SimpleHttpMock
      |> expect(:post, fn _url, _headers, _body ->
        {:error, %SimpleHttp.Response{status: 503}}
      end)

      assert {:error, %SimpleHttp.Response{status: 503}} = Client.metrics(%{})
    end

    test "raises on exception" do
      SimpleHttpMock
      |> expect(:post, fn _url, _headers, _body ->
        raise "Unexpected error"
      end)

      assert_raise RuntimeError, fn -> Client.metrics(%{}) end
    end
  end

  describe "telemetry_metadata/1" do
    test "includes appname and instance_id" do
      metadata = Client.telemetry_metadata(%{foo: :bar})

      assert metadata[:appname] == Config.appname()
      assert metadata[:instance_id] == Config.instance_id()
      assert metadata[:foo] == :bar
    end
  end
end
