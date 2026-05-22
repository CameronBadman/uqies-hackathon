defmodule BetterHermesWeb.PageControllerTest do
  use BetterHermesWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Personal assistant agent runtime"
  end
end
