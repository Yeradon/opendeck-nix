{
  description = "OpenDeck - Stream Deck software for Linux and macOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    version = "2.9.1";

    sources = {
      x86_64-linux = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/opendeck_${version}_amd64.deb";
        sha256 = "109ecfd3969dfbaf169bfae8692552ea45a9ddcdaa7fc89f8cd5cabf0b5dbec6";
      };
      aarch64-linux = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/opendeck_${version}_arm64.deb";
        sha256 = "fdfe7731938f6e27183118da7d18eb2a3fc6c3d57cc94117f0904681acd04e46";
      };
      x86_64-darwin = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/OpenDeck_x64.app.tar.gz";
        sha256 = "2b468bdc61273709e04cef103ceec45891a00ad026f8906c791c363cf12bc108";
      };
      aarch64-darwin = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/OpenDeck_aarch64.app.tar.gz";
        sha256 = "b5b0b8b8dba26c141767dad41623e0adae26e9854fc5e3865cbf9679b01e600c";
      };
    };

    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    packages = forAllSystems (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      source = sources.${system};
    in {
      default = self.packages.${system}.opendeck;

      opendeck = if pkgs.stdenv.isLinux then
        pkgs.stdenv.mkDerivation {
          pname = "opendeck";
          inherit version;

          src = pkgs.fetchurl {
            inherit (source) url sha256;
          };

          nativeBuildInputs = with pkgs; [
            dpkg
            autoPatchelfHook
            wrapGAppsHook3
          ];

          buildInputs = with pkgs; [
            webkitgtk_4_1
            gtk3
            glib
            libsoup_3
            cairo
            gdk-pixbuf
            pango
            openssl
            systemdMinimal
            hidapi
            libayatana-appindicator
          ];

          # Libraries loaded via dlopen at runtime (not caught by autoPatchelfHook)
          runtimeDependencies = with pkgs; [
            libayatana-appindicator
          ];

          unpackPhase = ''
            dpkg-deb -x $src .
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out
            cp -r usr/* $out/

            # Install udev rules
            if [ -d etc/udev ]; then
              mkdir -p $out/lib/udev/rules.d
              cp etc/udev/rules.d/* $out/lib/udev/rules.d/
            fi

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Linux software for the Stream Deck with support for original Elgato Stream Deck plugins";
            homepage = "https://github.com/nekename/OpenDeck";
            license = licenses.gpl3Plus;
            platforms = [ "x86_64-linux" "aarch64-linux" ];
            mainProgram = "opendeck";
          };
        }
      else
        pkgs.stdenv.mkDerivation {
          pname = "opendeck";
          inherit version;

          src = pkgs.fetchurl {
            inherit (source) url sha256;
          };

          sourceRoot = ".";

          installPhase = ''
            runHook preInstall
            mkdir -p $out/Applications
            cp -r OpenDeck.app $out/Applications/
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Linux software for the Stream Deck with support for original Elgato Stream Deck plugins";
            homepage = "https://github.com/nekename/OpenDeck";
            license = licenses.gpl3Plus;
            platforms = [ "x86_64-darwin" "aarch64-darwin" ];
            mainProgram = "opendeck";
          };
        };
    });
  };
}
