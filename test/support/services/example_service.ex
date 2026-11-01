defmodule Francy.Services.ExampleService do
  @moduledoc """
  A `Francy.Services.Service` implementation used in tests.

  Mirrors the example in the `Francy.Services.Service` moduledoc.
  """

  use Francy.Services.Service

  alias Francy.Services.{HealthResult, Service}

  @impl true
  def name, do: "Example"

  @impl true
  def status_page_url, do: "https://status.example.com"

  @impl true
  def configured?, do: token() not in [nil, ""]

  @impl true
  def check_interval, do: :timer.minutes(5)

  @impl true
  def check_health do
    if configured?() do
      {response, latency_ms} =
        Service.timed(fn ->
          Req.get(Service.req(__MODULE__, auth: {:bearer, token()}),
            url: "https://api.example.com/health"
          )
        end)

      case response do
        {:ok, %Req.Response{status: 200}} ->
          HealthResult.up(:example_service, latency_ms: latency_ms)

        {:ok, %Req.Response{status: status}} ->
          HealthResult.degraded(:example_service, "Unexpected status #{status}",
            latency_ms: latency_ms
          )

        {:error, _exception} ->
          HealthResult.down(:example_service, "Example API is unreachable")
      end
    else
      HealthResult.unconfigured(:example_service, "EXAMPLE_TOKEN is not set")
    end
  end

  defp token, do: Application.get_env(:francy, __MODULE__, [])[:token]
end
