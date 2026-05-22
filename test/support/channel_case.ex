defmodule BetterHermesWeb.ChannelCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint BetterHermesWeb.Endpoint

      import Phoenix.ChannelTest
      import BetterHermesWeb.ChannelCase
    end
  end
end
