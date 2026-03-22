{
  description = "OpenDeck - Stream Deck software for Linux and macOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    version = "2.10.1";

    sources = {
      x86_64-linux = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/opendeck_${version}_amd64.deb";
        sha256 = "1yjc5hwm9d35zb7fhpgcs861f2389lpw6plgd0kvv1v99ip1qwn2";
      };
      aarch64-linux = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/opendeck_${version}_arm64.deb";
        sha256 = "0y293nsvg2v1hcaj0gm5f74hsx57ggiwvszsml0vcvzxvl4dzzb2";
      };
      x86_64-darwin = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/OpenDeck_x64.app.tar.gz";
        sha256 = "0yn8j8s20xniczx1jb7jxwhm7gjlcdpwx932qzwlcysd2l0h062z";
      };
      aarch64-darwin = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/OpenDeck_aarch64.app.tar.gz";
        sha256 = "0s4yxhxqghqpk0nan49krsvi00c5q9b7f615qsm094p5ii11xdbi";
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
            gtk3 # for gtk-update-icon-cache
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
            hicolor-icon-theme
            glib-networking # TLS backend for GIO (needed for HTTPS in WebKitGTK)
          ];

          # Libraries loaded via dlopen at runtime (not caught by autoPatchelfHook)
          runtimeDependencies = with pkgs; [
            libayatana-appindicator
          ];

          # Ensure xdg-open and node are available for plugins and URL opening
          # Also disable WebKit's bubblewrap sandbox — it strips GIO_EXTRA_MODULES
          # from WebKitNetworkProcess, breaking TLS. Standard workaround on NixOS.
          preFixup = ''
            gappsWrapperArgs+=(
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.xdg-utils pkgs.nodejs ]}
              --set WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS 1
            )
          '';

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

            # Fix desktop file: absolute path + StartupWMClass for Wayland icon matching
            substituteInPlace $out/share/applications/*.desktop \
              --replace-fail "Exec=opendeck" "Exec=$out/bin/opendeck"
            echo "StartupWMClass=opendeck" >> $out/share/applications/opendeck.desktop

            # Generate icon theme cache
            cp ${pkgs.hicolor-icon-theme}/share/icons/hicolor/index.theme $out/share/icons/hicolor/
            gtk-update-icon-cache $out/share/icons/hicolor

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
            mkdir -p $out/Applications $out/bin
            cp -r OpenDeck.app $out/Applications/
            cat > $out/bin/opendeck <<EOF
            #!${pkgs.runtimeShell}
            exec "$out/Applications/OpenDeck.app/Contents/MacOS/OpenDeck" "\$@"
            EOF
            chmod +x $out/bin/opendeck
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

    overlays.default = final: _prev: {
      opendeck = self.packages.${final.system}.opendeck;
    };

    darwinModules.default = { pkgs, ... }: {
      environment.systemPackages = [ self.packages.${pkgs.system}.opendeck ];
    };
  };
}
