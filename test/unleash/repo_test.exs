defmodule Unleash.RepoTest do
  use ExUnit.Case

  import Mox

  @features_update_event [:unleash, :repo, :features_update]
  @disable_polling_event [:unleash, :repo, :disable_polling]
  @schedule_event [:unleash, :repo, :schedule]

  setup do
    Application.put_env(:unleash, :client, Unleash.ClientMock)
    stop_supervised(Unleash.Repo)

    state = get_initial_state()

    {:ok, pid} = start_supervised({Unleash.Repo, state})

    %{repo_pid: pid}
  end

  describe "handle_info/2" do
    test "executes telemetry when no retries remaining", %{repo_pid: repo_pid} do
      attach_telemetry_event(@disable_polling_event)

      Process.send(repo_pid, {:initialize, nil, 0}, [])

      assert_receive {:telemetry_metadata, _metadata}, 100
    end

    test "executes telemetry when scheduling a features poll", %{repo_pid: repo_pid} do
      Unleash.ClientMock
      |> allow(self(), repo_pid)
      |> stub(:features, fn _ -> {:ok, %{etag: "test_etag", features: get_initial_state()}} end)

      attach_telemetry_event(@schedule_event)

      Process.send(repo_pid, {:initialize, nil, 3}, [])

      assert_receive {:telemetry_metadata, metadata}, 100
      assert metadata.etag == "test_etag"
    end

    test "executes telemetry when reading features from remote", %{repo_pid: repo_pid} do
      Unleash.ClientMock
      |> allow(self(), repo_pid)
      |> stub(:features, fn _ -> {:ok, %{etag: "test_etag", features: get_initial_state()}} end)

      attach_telemetry_event(@features_update_event)

      Process.send(repo_pid, {:initialize, nil, 3}, [])

      assert_receive {:telemetry_metadata, metadata}, 100
      assert metadata.source == :remote
    end

    test "executes telemetry when reading features from cache", %{repo_pid: repo_pid} do
      Unleash.ClientMock
      |> allow(self(), repo_pid)
      |> stub(:features, fn _ -> :cached end)

      attach_telemetry_event(@features_update_event)

      Process.send(repo_pid, {:initialize, nil, 3}, [])

      assert_receive {:telemetry_metadata, metadata}, 100
      assert metadata.source == :cache
    end


  end

  defp attach_telemetry_event(event) do
    test_pid = self()

    :telemetry.attach(
      make_ref(),
      event,
      fn
        ^event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_measurements, measurements})
          send(test_pid, {:telemetry_metadata, metadata})
      end,
      []
    )
  end

  defp get_initial_state do
    Unleash.Features.from_map!(%{
      "version" => 2,
      "features" => [
        %{
          "name" => "test1",
          "description" => "Enabled toggle",
          "enabled" => true
        }
      ]
    })
  end


end
