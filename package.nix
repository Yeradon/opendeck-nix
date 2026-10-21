{
  lib,
  stdenv,
  fetchurl,
  buildFHSEnv,
  # Linux dependencies
  dpkg,
  webkitgtk_4_1,
  gtk3,
  glib,
  libsoup_3,
  cairo,
  gdk-pixbuf,
  pango,
  openssl,
  systemdMinimal,
  hidapi,
  libayatana-appindicator,
  hicolor-icon-theme,
  glib-networking,
  xdg-utils,
  nodejs,
  fontconfig,
  freetype,
  dbus,
  zlib,
  libx11,
  libxcursor,
  libxrandr,
  libxi,
  libxext,
  libxdamage,
  libxfixes,
  libxcomposite,
  libxrender,
  libxtst,
  libxscrnsaver,
  libxinerama,
  libxkbcommon,
  wayland,
  mesa,
  libGL,
  libxcb,
  libxau,
  libxdmcp,
  cacert,
  # Darwin dependencies
  runtimeShell,
}:

let
  version = "2.14.2";

  sources = {
    x86_64-linux = {
      url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/opendeck_${version}_amd64.deb";
      sha256 = "01i4qynpjlvr42njjjb5rca1cglwddkr3lmvawdrvxn64bdfv8hb";
    };
    aarch64-linux = {
      url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/opendeck_${version}_arm64.deb";
      sha256 = "0i48f86gzyvfmqm5s7bwbf0aza377qms0zmg34vzz551hpmkpxzi";
    };
    x86_64-darwin = {
      url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/OpenDeck_x64.app.tar.gz";
      sha256 = "1cllwh0wpd8ysk34ddjvwrf4yfl3xaf0lp85skb305mnz25r9ik1";
    };
    aarch64-darwin = {
      url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/OpenDeck_aarch64.app.tar.gz";
      sha256 = "16wkl8j3abpzb55akcm8v5dfhrxzv5f38n6wjwv1ha3skvg9mpz1";
    };
  };

  system = stdenv.hostPlatform.system;
  source = sources.${system} or (throw "Unsupported platform: ${system}");
in
if stdenv.hostPlatform.isLinux then
  let
    unwrapped = stdenv.mkDerivation {
      pname = "opendeck-unwrapped";
      inherit version;
      src = fetchurl {
        inherit (source) url sha256;
      };
      nativeBuildInputs = [ dpkg ];
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

    fhs = buildFHSEnv {
      name = "opendeck";
      targetPkgs = pkgs: [
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
        export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
      '';
    };
  in
  stdenv.mkDerivation {
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

    meta = with lib; {
      description = "Linux software for the Stream Deck with support for original Elgato Stream Deck plugins";
      homepage = "https://github.com/nekename/OpenDeck";
      license = licenses.gpl3Plus;
      platforms = [ "x86_64-linux" "aarch64-linux" ];
      mainProgram = "opendeck";
    };
  }
else
  stdenv.mkDerivation {
    pname = "opendeck";
    inherit version;

    src = fetchurl {
      inherit (source) url sha256;
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/Applications $out/bin
      cp -r OpenDeck.app $out/Applications/
      cat > $out/bin/opendeck <<EOF
      #!${runtimeShell}
      exec "$out/Applications/OpenDeck.app/Contents/MacOS/OpenDeck" "\$@"
      EOF
      chmod +x $out/bin/opendeck
      runHook postInstall
    '';

    meta = with lib; {
      description = "Linux software for the Stream Deck with support for original Elgato Stream Deck plugins";
      homepage = "https://github.com/nekename/OpenDeck";
      license = licenses.gpl3Plus;
      platforms = [ "x86_64-darwin" "aarch64-darwin" ];
      mainProgram = "opendeck";
    };
  }
