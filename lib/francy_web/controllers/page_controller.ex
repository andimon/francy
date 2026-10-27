defmodule FrancyWeb.PageController do
  use FrancyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
