defmodule Unleash.MetricsFastTest do
  use ExUnit.Case
  use ExUnitProperties

  import Mox

  alias Unleash.Config
  alias Unleash.Feature
  alias Unleash.MetricsFast

  setup do
    stop_supervised(MetricsFast)

    original_metrics_period = Config.metrics_period()
    Application.put_env(:unleash, :metrics_period, 60_000_000_000)
    {:ok, metrics} = start_supervised(MetricsFast)

    on_exit(fn ->
      Application.put_env(:unleash, :metrics_period, original_metrics_period)
    end)

    %{metrics: metrics}
  end

  describe "add_metric/1" do
    test "records a feature never passed through register_features/1 (cold path)" do
      MetricsFast.add_metric({%Feature{name: "cold_feature"}, true})
      MetricsFast.add_metric({%Feature{name: "cold_feature"}, true})
      MetricsFast.add_metric({%Feature{name: "cold_feature"}, false})

      {:ok, %{bucket: %{toggles: toggles}}} = MetricsFast.get_metrics()
      assert Map.get(toggles, "cold_feature") == %{yes: 2, no: 1}
    end

    test "records a feature pre-registered via register_features/1 (warm path)" do
      :ok = MetricsFast.register_features([%Feature{name: "warm_feature"}])

      MetricsFast.add_metric({%Feature{name: "warm_feature"}, true})
      MetricsFast.add_metric({%Feature{name: "warm_feature"}, false})
      MetricsFast.add_metric({%Feature{name: "warm_feature"}, false})

      {:ok, %{bucket: %{toggles: toggles}}} = MetricsFast.get_metrics()
      assert Map.get(toggles, "warm_feature") == %{yes: 1, no: 2}
    end

    test "does not crash for a non-Feature value" do
      assert MetricsFast.add_metric({:unrecorded_feature_toggle, false}) == false
      assert Process.alive?(Process.whereis(MetricsFast))
    end

    property "tallies yes/no counts correctly for arbitrary features", %{metrics: metrics} do
      Unleash.ClientMock
      |> allow(self(), metrics)
      |> stub(:metrics, fn _ -> {:ok, %SimpleHttp.Response{}} end)

      Application.put_env(:unleash, :client, Unleash.ClientMock)

      check all enabled <- positive_integer(),
                disabled <- positive_integer(),
                feature <- string(:alphanumeric, min_length: 1) do
        assert :ok == GenServer.call(metrics, :send_metrics)

        for _ <- 1..enabled do
          MetricsFast.add_metric({%Feature{name: feature}, true})
        end

        for _ <- 1..disabled do
          MetricsFast.add_metric({%Feature{name: feature}, false})
        end

        {:ok, %{bucket: %{toggles: toggles}}} = MetricsFast.get_metrics()
        assert Map.get(toggles, feature) == %{yes: enabled, no: disabled}
      end
    end
  end

  describe "add_variant_metric/1" do
    test "records a variant never passed through register_features/1 (cold path)" do
      feature = %Feature{name: "cold_variant_feature", enabled: true}

      MetricsFast.add_variant_metric({feature, %{name: "v1"}})
      MetricsFast.add_variant_metric({feature, %{name: "v1"}})
      MetricsFast.add_variant_metric({feature, %{name: "v2"}})

      {:ok, %{bucket: %{toggles: toggles}}} = MetricsFast.get_metrics()
      entry = Map.get(toggles, "cold_variant_feature")

      assert entry.yes == 3
      assert entry.variants == %{"v1" => 2, "v2" => 1}
    end

    test "records a variant pre-registered via register_features/1 (warm path)" do
      :ok =
        MetricsFast.register_features([
          %Feature{name: "warm_variant_feature", variants: [%{name: "v1"}]}
        ])

      feature = %Feature{name: "warm_variant_feature", enabled: true}
      MetricsFast.add_variant_metric({feature, %{name: "v1"}})

      {:ok, %{bucket: %{toggles: toggles}}} = MetricsFast.get_metrics()
      entry = Map.get(toggles, "warm_variant_feature")

      assert entry.yes == 1
      assert entry.variants == %{"v1" => 1}
    end

    test "does not crash for a non-Feature value" do
      variant = %{name: "v1"}
      assert MetricsFast.add_variant_metric({:unrecorded, variant}) == variant
      assert Process.alive?(Process.whereis(MetricsFast))
    end
  end

  describe "register_features/1" do
    test "is idempotent - re-registering the same features doesn't reset counts" do
      feature = %Feature{name: "idempotent_feature", variants: [%{name: "v1"}]}

      :ok = MetricsFast.register_features([feature])
      MetricsFast.add_metric({%Feature{name: "idempotent_feature"}, true})

      :ok = MetricsFast.register_features([feature])
      MetricsFast.add_metric({%Feature{name: "idempotent_feature"}, true})

      {:ok, %{bucket: %{toggles: toggles}}} = MetricsFast.get_metrics()
      assert Map.get(toggles, "idempotent_feature") == %{yes: 2, no: 0, variants: %{"v1" => 0}}
    end

    test "registering many features preserves each feature's own counts (exercises growth)" do
      features = for i <- 1..50, do: %Feature{name: "feature_#{i}"}
      :ok = MetricsFast.register_features(features)

      for i <- 1..50 do
        MetricsFast.add_metric({%Feature{name: "feature_#{i}"}, rem(i, 2) == 0})
      end

      {:ok, %{bucket: %{toggles: toggles}}} = MetricsFast.get_metrics()

      for i <- 1..50 do
        expected = if rem(i, 2) == 0, do: %{yes: 1, no: 0}, else: %{yes: 0, no: 1}
        assert Map.get(toggles, "feature_#{i}") == expected
      end
    end
  end

  describe "get_metrics/0 and do_send_metrics/0" do
    setup :verify_on_exit!

    test "sends the metrics bucket to the client and resets counts", %{metrics: metrics} do
      Unleash.ClientMock
      |> allow(self(), metrics)
      |> expect(:metrics, fn %{bucket: %{toggles: toggles}} ->
        assert toggles == %{"reset_feature" => %{yes: 1, no: 0}}
        {:ok, %SimpleHttp.Response{}}
      end)

      Application.put_env(:unleash, :client, Unleash.ClientMock)

      MetricsFast.add_metric({%Feature{name: "reset_feature"}, true})

      assert :ok == MetricsFast.do_send_metrics()

      {:ok, %{bucket: %{toggles: toggles}}} = MetricsFast.get_metrics()
      assert Map.get(toggles, "reset_feature") == %{yes: 0, no: 0}
    end
  end
end
