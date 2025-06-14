defmodule MetricsHandler do
  def attach_telemetry_event(event) do
    testPid = self()
    :telemetry.attach(
      make_ref(),
      event,
      fn ^event, measurements, metadata, _config ->
        send(testPid, {:telemetry_measurements, measurements})
        send(testPid, {:telemetry_metadata, metadata})
      end,
      []
    )
  end
end
