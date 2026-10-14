{
  description = "OpenDeck - Stream Deck software for Linux and macOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      overlays.default = final: _prev: {
        opendeck = final.callPackage ./package.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          opendeck = pkgs.callPackage ./package.nix { };
          default = opendeck;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          app-test = pkgs.runCommand "opendeck-app-test" {
            nativeBuildInputs = [
              pkgs.xvfb-run
              pkgs.coreutils
            ];
          } ''
            code=0
            xvfb-run -a timeout --preserve-status 2 ${self.packages.${system}.opendeck}/bin/opendeck || code=$?
            if [ "$code" -eq 143 ] || [ "$code" -eq 124 ]; then
              echo "Opendeck started successfully and was terminated by timeout (code $code)"
              touch $out
            else
              echo "Opendeck failed with exit code $code"
              exit 1
            fi
          '';
        }
      );

      darwinModules.default =
        { pkgs, ... }:
        {
          environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.opendeck ];
        };
    };
}
