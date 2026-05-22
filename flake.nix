{
  description = "Better Hermes hackathon development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      beam = pkgs.beam.packages.erlang_28;
    in {
      default = pkgs.mkShell {
        packages = [
          beam.elixir_1_19
          pkgs.nodejs_22
          pkgs.git
          pkgs.curl
          pkgs.openssl
          pkgs.pkg-config
          pkgs.inotify-tools
          pkgs.watchman
          pkgs.playwright-driver
          pkgs.playwright-driver.browsers
        ];

        shellHook = ''
          export MIX_HOME="$PWD/.nix-mix"
          export HEX_HOME="$PWD/.nix-hex"
          export PATH="$MIX_HOME/bin:$HEX_HOME/bin:$PATH"
          export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
          export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
          export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true

          echo "Better Hermes dev shell"
          echo "  mix setup"
          echo "  npm install --prefix assets"
          echo "  mix phx.server"
        '';
      };
    });
  };
}
