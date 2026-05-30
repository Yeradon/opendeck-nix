{
  description = "OpenDeck - Stream Deck software for Linux and macOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    version = "2.12.1";

    sources = {
      x86_64-linux = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/opendeck_${version}_amd64.deb";
        sha256 = "1bnxgm4yjf4b811sgmaq3hg1fm4pi5qmx8f7axglgbdc1fsp8av7";
      };
      aarch64-linux = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/opendeck_${version}_arm64.deb";
        sha256 = "0brz1y5b5qvz0mxrnj2rkwfvy24bk1zxna1qxk7d6hfcxslinkjd";
      };
      x86_64-darwin = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/OpenDeck_x64.app.tar.gz";
        sha256 = "03znvlq9qaz1m6wn7br6qvm1g98vd1q3iv218abgr8ff9l6wnzzm";
      };
      aarch64-darwin = {
        url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/OpenDeck_aarch64.app.tar.gz";
        sha256 = "1a2z3d06sm4gf54vlhwrvna33bycg9x23062gv4kf2m46292b70n";
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
        let
          unwrapped = pkgs.stdenv.mkDerivation {
            pname = "opendeck-unwrapped";
            inherit version;
            src = pkgs.fetchurl {
              inherit (source) url sha256;
            };
            nativeBuildInputs = [ pkgs.dpkg ];
            unpackPhase = ''
              dpkg-deb -x $src .
            '';
            installPhase = ''
              mkdir -p $out
              cp -r usr/* $out/
              if [ -d etc/udev ]; then
                mkdir -p $out/lib/udev/rules.d
                cp etc/udev/rules.d/* $out/lib/udev/rules.d/
              fi
            '';
          };

          fhs = pkgs.buildFHSEnv {
            name = "opendeck";
            targetPkgs = pkgs: with pkgs; [
              unwrapped
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
              glib-networking
              xdg-utils
              nodejs
              # Common libraries needed by GUI apps in FHS
              fontconfig
              freetype
              dbus
              zlib
              libx11
              libxcursor
              libxrandr
              libxi
              libxext
              libxdamage
              libxfixes
              libxcomposite
              libxrender
              libxtst
              libxscrnsaver
              libxinerama
              libxkbcommon
              wayland
              mesa
              libGL
              libxcb
              libxau
              libxdmcp
              cacert
            ];
            runScript = "opendeck";
            profile = ''
              export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
              export GIO_EXTRA_MODULES=/usr/lib/gio/modules
              export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
            '';
          };
        in
        pkgs.stdenv.mkDerivation {
          pname = "opendeck";
          inherit version;

          phases = [ "installPhase" ];

          installPhase = ''
            mkdir -p $out/bin $out/share $out/lib

            # Link the FHS wrapper
            ln -s ${fhs}/bin/opendeck $out/bin/opendeck

            # Copy icons and desktop files from unwrapped
            cp -r ${unwrapped}/share/icons $out/share/
            cp -r ${unwrapped}/share/applications $out/share/

            # Copy udev rules
            if [ -d ${unwrapped}/lib/udev ]; then
              cp -r ${unwrapped}/lib/udev $out/lib/
            fi

            # Fix desktop file: absolute path + StartupWMClass for Wayland icon matching
            substituteInPlace $out/share/applications/*.desktop \
              --replace-fail "Exec=opendeck" "Exec=$out/bin/opendeck"
            echo "StartupWMClass=opendeck" >> $out/share/applications/opendeck.desktop
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
