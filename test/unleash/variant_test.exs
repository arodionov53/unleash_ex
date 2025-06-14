defmodule Unleash.VariantTest do
  use ExUnit.Case

  @variant_get_start_event [:unleash, :variant, :get, :start]
  @variant_get_stop_event [:unleash, :variant, :get, :stop]

  setup :start_repo

  test "return a disabled variant if the flag is disabled" do
    assert %{
             enabled: false,
             name: "disabled"
           } == Unleash.get_variant(:disabled_variant)
  end

  test "returns a disabled variant for nonexistent flag" do
    assert %{
             enabled: false,
             name: "disabled"
           } == Unleash.get_variant(:nonexistent_flag)
  end

  test "returns a disabled variant for a flag without variants" do
    assert %{
             enabled: false,
             name: "disabled"
           } == Unleash.get_variant(:flag_without_variants)
  end

  describe "get_variant telemetry" do
    test "emits telemetry on start" do
      MetricsHandler.attach_telemetry_event(@variant_get_start_event)

      Unleash.get_variant(:disabled_variant)

      assert_received {:telemetry_metadata, metadata}
      assert_received {:telemetry_measurements, measurements}

      assert metadata.variant === :disabled_variant

      assert is_number(measurements[:system_time])
      assert is_number(measurements[:monotonic_time])
    end

    test "emits telemetry with reason (flag without variants) on stop" do
      MetricsHandler.attach_telemetry_event(@variant_get_stop_event)

      Unleash.get_variant(:flag_without_variants)

      assert_received {:telemetry_metadata, metadata}
      assert_received {:telemetry_measurements, measurements}

      assert metadata.variant === :flag_without_variants
      assert metadata.reason === :feature_has_no_variants

      assert is_number(measurements[:duration])
      assert is_number(measurements[:monotonic_time])
    end

    test "emits telemetry with reason (inexistent featureflag) on stop" do
      MetricsHandler.attach_telemetry_event(@variant_get_stop_event)

      Unleash.get_variant(:inexistent_feature_flag)

      assert_received {:telemetry_metadata, metadata}
      assert_received {:telemetry_measurements, measurements}

      assert metadata.variant === :inexistent_feature_flag
      assert metadata.reason === :feature_not_found

      assert is_number(measurements[:duration])
      assert is_number(measurements[:monotonic_time])
    end

    test "emits telemetry with reason (disabled_variant) on stop" do
      MetricsHandler.attach_telemetry_event(@variant_get_stop_event)

      Unleash.get_variant(:disabled_variant)

      assert_received {:telemetry_metadata, metadata}
      assert_received {:telemetry_measurements, measurements}

      assert metadata.variant === :disabled_variant
      assert metadata.reason === :feature_disabled

      assert is_number(measurements[:duration])
      assert is_number(measurements[:monotonic_time])
    end

    test "emits weight selection reason on stop when applicable" do
      MetricsHandler.attach_telemetry_event(@variant_get_stop_event)

      Unleash.get_variant(:weight_test)

      assert_received {:telemetry_metadata, metadata}
      assert_received {:telemetry_measurements, measurements}

      assert metadata.variant === :weight_test
      assert metadata.reason === :variant_selected

      assert is_number(measurements[:duration])
      assert is_number(measurements[:monotonic_time])
    end

    test "emits override selection reason on stop when applicable" do
      MetricsHandler.attach_telemetry_event(@variant_get_stop_event)

      Unleash.get_variant(:override_test, %{user_id: "420"})

      assert_received {:telemetry_metadata, metadata}
      assert_received {:telemetry_measurements, measurements}

      assert metadata.variant === :override_test
      assert metadata.reason === :override_found

      assert is_number(measurements[:duration])
      assert is_number(measurements[:monotonic_time])
    end

    test "returns seed and variants on stop" do
      MetricsHandler.attach_telemetry_event(@variant_get_stop_event)

      Unleash.get_variant(:weight_test)

      assert_received {:telemetry_metadata, metadata}
      assert_received {:telemetry_measurements, measurements}

      refute is_nil(metadata.seed)
      assert metadata.variants === [{"variant1", 99}, {"variant2", 1}]

      assert is_number(measurements[:duration])
      assert is_number(measurements[:monotonic_time])
    end
  end

  defp start_repo(_) do
    stop_supervised(Unleash.Repo)

    state = Unleash.Features.from_map!(state())

    {:ok, _pid} = start_supervised({Unleash.Repo, state})
    :ok
  end

  defp state,
    do: %{
      "version" => 1,
      "features" => [
        %{
          "name" => "override_test",
          "description" => "override testing",
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
              "weight" => 50,
              "payload" => %{"type" => "string", "value" => "val1"},
              "overrides" => [
                %{
                  "contextName" => "userId",
                  "values" => ["420"]
                }
              ]
            },
            %{
              "name" => "variant2",
              "weight" => 50,
              "payload" => %{"type" => "string", "value" => "val1"}
            }
          ]
        },
        %{
          "name" => "weight_test",
          "description" => "weight selection testing fixture",
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
              "weight" => 99,
              "payload" => %{"type" => "string", "value" => "val1"}
            },
            %{
              "name" => "variant2",
              "weight" => 1,
              "payload" => %{"type" => "string", "value" => "val1"}
            }
          ]
        },
        %{
          "name" => "disabled_variant",
          "description" => "variant with enabled set to false",
          "enabled" => false,
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
        },
        %{
          "name" => "flag_without_variants",
          "description" => "a flag with empty variants",
          "enabled" => true,
          "strategies" => [
            %{
              "name" => "default",
              "parameters" => %{}
            }
          ],
          "variants" => []
        }
      ]
    }
end
