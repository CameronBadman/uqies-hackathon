defmodule BetterHermesWeb.Router do
  use BetterHermesWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BetterHermesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BetterHermesWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/demo/browser-target", BrowserDemoController, :show
    get "/auth/google/start", GoogleAuthController, :start
    get "/auth/google/callback", GoogleAuthController, :callback
  end

  # Other scopes may use custom stacks.
  # scope "/api", BetterHermesWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:better_hermes, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BetterHermesWeb.Telemetry
    end
  end
end
