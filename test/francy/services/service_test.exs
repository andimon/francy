defmodule Francy.Services.ServiceTest do
  # Not async: ExampleService reads its token from the application env.
  use ExUnit.Case, async: false

  alias Francy.Services.{ExampleService, HealthResult, Service}

  setup do
    Application.put_env(:francy, ExampleService, token: "test-token")
    on_exit(fn -> Application.delete_env(:francy, ExampleService) end)
  end

  describe "use Francy.Services.Service" do
    test "declares the behaviour" do
      behaviours = Keyword.get_values(ExampleService.module_info(:attributes), :behaviour)
      assert Service in List.flatten(behaviours)
    end

    test "provides a default timeout/0" do
      assert ExampleService.timeout() == :timer.seconds(5)
    end

    test "allows overriding check_interval/0" do
      assert ExampleService.check_interval() == :timer.minutes(5)
    end
  end

  describe "check_health/0" do
    test "is :up when the API responds with 200" do
      Req.Test.stub(Francy.Services, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
        Plug.Conn.send_resp(conn, 200, "ok")
      end)

      assert %HealthResult{status: :up, service: :example_service, latency_ms: latency_ms} =
               ExampleService.check_health()

      assert is_integer(latency_ms)
    end

    test "is :degraded when the API responds with an unexpected status" do
      Req.Test.stub(Francy.Services, &Plug.Conn.send_resp(&1, 503, "unavailable"))

      assert %HealthResult{status: :degraded, message: "Unexpected status 503"} =
               ExampleService.check_health()
    end

    test "is :down when the API is unreachable" do
      Req.Test.stub(Francy.Services, &Req.Test.transport_error(&1, :econnrefused))

      assert %HealthResult{status: :down} = ExampleService.check_health()
    end

    test "is :unconfigured without a token and makes no request" do
      Application.put_env(:francy, ExampleService, token: nil)
      Req.Test.stub(Francy.Services, fn _conn -> flunk("no request expected") end)

      refute ExampleService.configured?()
      assert %HealthResult{status: :unconfigured} = ExampleService.check_health()
    end
  end

  describe "req/2" do
    test "applies the service timeout and disables retries" do
      req = Service.req(ExampleService)

      assert req.options.receive_timeout == ExampleService.timeout()
      assert req.options.retry == false
    end

    test "lets caller options override the defaults" do
      req = Service.req(ExampleService, receive_timeout: 100)
      assert req.options.receive_timeout == 100
    end
  end

  test "timed/1 returns the result and elapsed milliseconds" do
    assert {:result, elapsed_ms} = Service.timed(fn -> :result end)
    assert is_integer(elapsed_ms) and elapsed_ms >= 0
  end
end
