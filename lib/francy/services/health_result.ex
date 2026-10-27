defmodule Francy.Services.HealthResult do
  @moduledoc """
  The result of a health check performed by a `Francy.Services.Service` implementation.

  See `t:status/0` for what each status means.

  Build results with the constructor matching the status, which also sets `checked_at`:

      HealthResult.up(:example_service, latency_ms: 120)
      HealthResult.degraded(:example_service, "Unexpected status 503", latency_ms: 950)
      HealthResult.down(:example_service, "Connection refused")
      HealthResult.unconfigured(:example_service, "EXAMPLE_TOKEN is not set")

  `latency_ms` and `details` are accepted as options. Keep `message` and `details`
  free of tokens and raw requests/responses, as they are shown in the UI.
  """

  @typedoc """
  Whether the service can be used right now.

    * `:up` - works normally: requests succeed in reasonable time and credentials
      are accepted.
    * `:degraded` - usable but impaired: the provider reports a minor incident,
      responses are slow, or the API answers with an unexpected status (e.g. 5xx, 429).
    * `:down` - unusable: requests fail (connection error, timeout), the provider
      reports a major outage, or our credentials are rejected (401/403).
    * `:unconfigured` - not checked because credentials are missing, so a missing
      token is not reported as an outage.
  """
  @type status :: :up | :degraded | :down | :unconfigured

  @type t :: %__MODULE__{
          service: atom() | String.t(),
          status: status(),
          message: String.t() | nil,
          latency_ms: non_neg_integer() | nil,
          checked_at: DateTime.t(),
          details: map()
        }

  @typedoc "Options accepted by the constructors."
  @type opt :: {:latency_ms, non_neg_integer()} | {:details, map()}

  @enforce_keys [:service, :status, :checked_at]
  defstruct [:service, :status, :message, :latency_ms, :checked_at, details: %{}]

  @doc "Builds an `:up` result."
  @spec up(atom() | String.t(), [opt]) :: t()
  def up(service, opts \\ []), do: build(service, :up, nil, opts)

  @doc "Builds a `:degraded` result explaining what is impaired."
  @spec degraded(atom() | String.t(), String.t(), [opt]) :: t()
  def degraded(service, message, opts \\ []), do: build(service, :degraded, message, opts)

  @doc "Builds a `:down` result explaining why the service is unusable."
  @spec down(atom() | String.t(), String.t(), [opt]) :: t()
  def down(service, message, opts \\ []), do: build(service, :down, message, opts)

  @doc "Builds an `:unconfigured` result explaining what configuration is missing."
  @spec unconfigured(atom() | String.t(), String.t()) :: t()
  def unconfigured(service, message), do: build(service, :unconfigured, message, [])

  @doc "Returns `true` if the result is `:up`."
  @spec up?(t()) :: boolean()
  def up?(%__MODULE__{status: status}), do: status == :up

  @doc "Returns `true` if the result is `:degraded`."
  @spec degraded?(t()) :: boolean()
  def degraded?(%__MODULE__{status: status}), do: status == :degraded

  @doc "Returns `true` if the result is `:down`."
  @spec down?(t()) :: boolean()
  def down?(%__MODULE__{status: status}), do: status == :down

  @doc "Returns `true` if the result is `:unconfigured`."
  @spec unconfigured?(t()) :: boolean()
  def unconfigured?(%__MODULE__{status: status}), do: status == :unconfigured

  defp build(service, status, message, opts) do
    %__MODULE__{
      service: service,
      status: status,
      message: message,
      latency_ms: Keyword.get(opts, :latency_ms),
      details: Keyword.get(opts, :details, %{}),
      checked_at: DateTime.utc_now()
    }
  end
end
