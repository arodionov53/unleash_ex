defmodule Unleash.RepoTest do
  use ExUnit.Case

  setup do
    Application.put_env(:unleash, :client, Unleash.ClientMock)
    stop_supervised(Unleash.Repo)

    state = get_initial_state()

    {:ok, _pid} = start_supervised({Unleash.Repo, state})

    :ok
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
