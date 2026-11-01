defmodule Francy.Services.Service do
  @moduledoc """
  A behaviour module that defines a basis for services to be added.

  Implementations must return a `Francy.Services.HealthResult` from `check_health/0`.
  See `t:Francy.Services.HealthResult.status/0` for when to report each status, and
  build results with its constructors (`Francy.Services.HealthResult.up/2`,
  `Francy.Services.HealthResult.degraded/3`, `Francy.Services.HealthResult.down/3`,
  `Francy.Services.HealthResult.unconfigured/2`).

  `use Francy.Services.Service` sets the behaviour and provides overridable defaults
  for `timeout/0` and `check_interval/0`.

  ## Example

      defmodule Francy.Services.ExampleService do
        use Francy.Services.Service

        alias Francy.Services.{HealthResult, Service}

        @impl true
        def name, do: "Example"

        @impl true
        def status_page_url, do: "https://status.example.com"

        @impl true
        def configured?, do: token() not in [nil, ""]

        # Optional: override the defaults provided by `use`
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
                HealthResult.degraded(:example_service, "Unexpected status \#{status}",
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
  """

  alias Francy.Services.HealthResult

  @doc "Human readable name shown in the UI."
  @callback name() :: String.t()

  @doc "Whether the credentials needed to check the service are present."
  @callback configured?() :: boolean()

  @doc "URL of the provider's public status page, if any."
  @callback status_page_url() :: String.t() | nil

  @doc "Performs the health check."
  @callback check_health() :: HealthResult.t()

  @doc "Maximum time in milliseconds a single request may take."
  @callback timeout() :: pos_integer()

  @doc "How often in milliseconds the service should be checked."
  @callback check_interval() :: pos_integer()

  defmacro __using__(_opts) do
    quote do
      @behaviour Francy.Services.Service

      @impl true
      def timeout, do: :timer.seconds(5)

      @impl true
      def check_interval, do: :timer.minutes(2)

      defoverridable timeout: 0, check_interval: 0
    end
  end

  @doc """
  Builds a `Req` request for `service`, applying its `timeout/0` and disabling retries
  so a failing service is reported quickly.

  Extra options can be injected via the `:services_req_options` app env (used by tests).
  """
  @spec req(module(), keyword()) :: Req.Request.t()
  def req(service, opts \\ []) do
    [receive_timeout: service.timeout(), retry: false]
    |> Keyword.merge(Application.get_env(:francy, :services_req_options, []))
    |> Keyword.merge(opts)
    |> Req.new()
  end

  @doc "Runs `fun` and returns `{result, elapsed_ms}`."
  @spec timed((-> result)) :: {result, non_neg_integer()} when result: var
  def timed(fun) do
    {micros, result} = :timer.tc(fun)
    {result, div(micros, 1000)}
  end
end
