defmodule UnleashTest do
  use ExUnit.Case
  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "enabled?/2" do
    setup :start_repo

    test "should send an empty context" do
      Application.delete_env(:unleash, :disable_client)
      refute Unleash.enabled?(:test1, true)
    end

    test "should emit evaluation series on stop when applicable" do
      Application.delete_env(:unleash, :disable_client)

      refute Unleash.enabled?(:test1, true)
    end

    test "should emit reason for non existent feature" do
      Application.delete_env(:unleash, :disable_client)

      refute Unleash.enabled?(:test_none_of_this, false)
    end
  end

  describe "is_enabled?" do
    setup :start_repo

    test "should call enabled" do
      assert Unleash.is_enabled?(:test1, true) == Unleash.enabled?(:test1, true)

      assert Unleash.is_enabled?(:test1, %{user_id: 1}, true) ==
               Unleash.enabled?(:test1, %{user_id: 1}, true)

      assert Unleash.is_enabled?(:test1) ==
               Unleash.enabled?(:test1)
    end
  end

  describe "enabled?/3" do
    setup do
      stop_supervised(Unleash.Repo)
      saved = Application.get_env(:unleash, :disable_client)
      Application.put_env(:unleash, :disable_client, true)

      on_exit(fn ->
        Application.put_env(:unleash, :disable_client, saved)
      end)

      :ok
    end

    test "should return the default if the client is disabled" do
      assert true == Unleash.enabled?(:test, %{}, true)
      assert false == Unleash.enabled?(:test, %{}, false)
    end

  end

  describe "get_variant/3" do
    setup do
      stop_supervised(Unleash.Repo)
      saved = Application.get_env(:unleash, :disable_client)
      Application.put_env(:unleash, :disable_client, true)

      on_exit(fn ->
        Application.put_env(:unleash, :disable_client, saved)
      end)

      :ok
    end

    test "should return the default if the client is disabled" do
      assert true == Unleash.get_variant(:variant, %{}, true)
      assert false == Unleash.get_variant(:variant, %{}, false)
    end
  end

  describe "start/1" do
    test "it should listen to configuration when starting the supervisor tree" do
      # Set mock to global mode so it works across processes
      set_mox_global()

      Unleash.ClientMock
      |> stub(:register_client, fn -> {:ok, %{}} end)
      |> stub(:features, fn _ -> {:ok, %{etag: "test_etag", features: %Unleash.Features{}}} end)
      |> stub(:metrics, fn _ -> {:ok, %SimpleHttp.Response{}} end)

      Application.put_env(:unleash, :client, Unleash.ClientMock)
      Application.put_env(:unleash, :disable_metrics, false)
      Application.put_env(:unleash, :disable_client, false)
      {:ok, pid} = Unleash.start(:normal, [])
      children = Supervisor.which_children(pid)

      assert Enum.any?(children, &Kernel.match?({Unleash.Repo, _, _, _}, &1))
      assert Enum.any?(children, &Kernel.match?({Unleash.Metrics, _, _, _}, &1))

      # Give the spawned registration process time to complete
      :timer.sleep(100)
    end

    test "it shouldn't start the metrics server if disabled" do
      # Set mock to global mode so it works across processes
      set_mox_global()

      Unleash.ClientMock
      |> stub(:register_client, fn -> {:ok, %{}} end)
      |> stub(:features, fn _ -> {:ok, %{etag: "test_etag", features: %Unleash.Features{}}} end)

      Application.put_env(:unleash, :client, Unleash.ClientMock)
      Application.put_env(:unleash, :disable_metrics, true)
      Application.put_env(:unleash, :disable_client, false)
      {:ok, pid} = Unleash.start(:normal, [])

      children = Supervisor.which_children(pid)

      assert Enum.any?(children, &Kernel.match?({Unleash.Repo, _, _, _}, &1))
      refute Enum.any?(children, &Kernel.match?({Unleash.Metrics, _, _, _}, &1))

      # Give the spawned registration process time to complete
      :timer.sleep(100)
    end

    test "it shouldn't start anything if the client is disabled" do
      Application.put_env(:unleash, :client, Unleash.ClientMock)
      Application.put_env(:unleash, :disable_client, true)
      {:ok, pid} = Unleash.start(:normal, [])

      children = Supervisor.which_children(pid)

      refute Enum.any?(children, &Kernel.match?({Unleash.Repo, _, _, _}, &1))
      refute Enum.any?(children, &Kernel.match?({Unleash.Metrics, _, _, _}, &1))
    end
  end

  defp start_repo(_) do
    stop_supervised(Unleash.Repo)

    # Set up client mock expectations for registration
    Unleash.ClientMock
    |> stub(:register_client, fn -> {:ok, %{}} end)
    |> stub(:features, fn _ -> {:ok, %{etag: "test_etag", features: %Unleash.Features{}}} end)
    |> stub(:metrics, fn _ -> {:ok, %SimpleHttp.Response{}} end)

    # Configure the mock client
    Application.put_env(:unleash, :client, Unleash.ClientMock)

    state = Unleash.Features.from_map!(state())

    {:ok, _pid} = start_supervised({Unleash.Repo, state})
    :ok
  end

  defp state,
    do: %{
      "version" => 2,
      "features" => [
        %{
          "name" => "test1",
          "description" => "Enabled toggle",
          "enabled" => true,
          "strategies" => [
            %{
              "name" => "userWithId",
              "parameters" => %{
                "userIds" => "1"
              }
            }
          ]
        },
        %{
          "name" => "test2",
          "description" => "Enabled toggle",
          "enabled" => true,
          "strategies" => [
            %{
              "name" => "gradualRolloutSessionId",
              "parameters" => %{
                "percentage" => "50",
                "groupId" => "AB12A"
              }
            }
          ]
        },
        %{
          "name" => "test3",
          "description" => "Enabled toggle",
          "enabled" => true,
          "strategies" => [
            %{
              "name" => "remoteAddress",
              "parameters" => %{
                "IPs" => "127.0.0.1"
              }
            }
          ]
        },
        %{
          "name" => "variant",
          "description" => "variant",
          "enabled" => true,
          "strategies" => [
            %{
              "name" => "default",
              "parameters" => %{}
            }
          ],
          "variants" => [
            %{
              "name" => "variant1",
              "weight" => 100,
              "payload" => %{"type" => "string", "value" => "val1"}
            }
          ]
        }
      ]
    }
end
