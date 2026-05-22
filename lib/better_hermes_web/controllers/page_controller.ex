defmodule BetterHermesWeb.PageController do
  use BetterHermesWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
