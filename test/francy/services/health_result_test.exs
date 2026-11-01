defmodule Francy.Services.HealthResultTest do
  use ExUnit.Case, async: true

  alias Francy.Services.HealthResult

  describe "constructors" do
    test "up/2 builds an :up result with options" do
      result = HealthResult.up(:example_service, latency_ms: 120, details: %{auth: :ok})

      assert %HealthResult{
               service: :example_service,
               status: :up,
               message: nil,
               latency_ms: 120,
               details: %{auth: :ok},
               checked_at: %DateTime{}
             } = result
    end

    test "degraded/3 builds a :degraded result with a message" do
      assert %HealthResult{status: :degraded, message: "slow", latency_ms: 900} =
               HealthResult.degraded(:example_service, "slow", latency_ms: 900)
    end

    test "down/3 builds a :down result with a message" do
      assert %HealthResult{status: :down, message: "unreachable", latency_ms: nil, details: %{}} =
               HealthResult.down(:example_service, "unreachable")
    end

    test "unconfigured/2 builds an :unconfigured result" do
      assert %HealthResult{status: :unconfigured, message: "EXAMPLE_TOKEN is not set"} =
               HealthResult.unconfigured(:example_service, "EXAMPLE_TOKEN is not set")
    end
  end

  test "predicates match only their own status" do
    results = %{
      up: HealthResult.up(:s),
      degraded: HealthResult.degraded(:s, "m"),
      down: HealthResult.down(:s, "m"),
      unconfigured: HealthResult.unconfigured(:s, "m")
    }

    for {status, result} <- results do
      assert HealthResult.up?(result) == (status == :up)
      assert HealthResult.degraded?(result) == (status == :degraded)
      assert HealthResult.down?(result) == (status == :down)
      assert HealthResult.unconfigured?(result) == (status == :unconfigured)
    end
  end
end
