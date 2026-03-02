{
  description = "dexie_web - self-contained Dexie.js wrapper for Flutter Web";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        isLinux = pkgs.stdenv.isLinux;
        linuxChromeExecutable = if isLinux then "${pkgs.chromium}/bin/chromium" else "";
        chromiumDisplayVersion = if isLinux then pkgs.chromium.version else "Playwright bundled Chromium";
      in
      {
        devShells.default = pkgs.mkShell {
          name = "dexie_web-dev";

          buildInputs = [
            pkgs.flutter
            pkgs.dart
            pkgs.nodejs_24
            pkgs.just
            pkgs.playwright
            pkgs.playwright-driver.browsers
            pkgs.git
            pkgs.coreutils
          ] ++ pkgs.lib.optionals isLinux [
            pkgs.chromium
            pkgs.libGL
            pkgs.libnotify
            pkgs.gtk3
            pkgs.nss
            pkgs.nspr
            pkgs.atk
            pkgs."at-spi2-atk"
            pkgs.cups
            pkgs.dbus
            pkgs.libdrm
            pkgs.xorg.libX11
            pkgs.xorg.libXcomposite
            pkgs.xorg.libXdamage
            pkgs.xorg.libXext
            pkgs.xorg.libXfixes
            pkgs.xorg.libXrandr
            pkgs.xorg.libxcb
            pkgs.mesa
            pkgs.xorg.libxkbfile
            pkgs.xorg.libXcursor
            pkgs.xorg.libXi
            pkgs.xorg.libXScrnSaver
            pkgs."alsa-lib"
          ];

          FLUTTER_WEB_BROWSER = "chromium";
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

          shellHook = ''
            export PATH="$HOME/.pub-cache/bin:$PATH"
            if [[ "${if isLinux then "1" else "0"}" == "1" ]]; then
              export CHROME_EXECUTABLE="${linuxChromeExecutable}"
            else
              export CHROME_EXECUTABLE="$(find /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome || true)"
            fi

            echo "dexie_web dev shell (Nix) loaded"
            echo "Platform: ${if isLinux then "Linux/WSL2" else "macOS"}"
            echo "Flutter: $(flutter --version | head -n1)"
            echo "Dart: $(dart --version 2>&1 | head -n1)"
            echo "Node: $(node --version)"
            echo "Chromium: ${chromiumDisplayVersion}"
            echo "CHROME_EXECUTABLE: ${"$"}{CHROME_EXECUTABLE:-not-found}"

            if ! command -v patrol >/dev/null 2>&1; then
              echo "First-time activation of patrol_cli..."
              dart pub global activate patrol_cli
            fi

            echo ""
            echo "Available commands:"
            echo "  just bootstrap"
            echo "  just e2e"
            echo "  just test-web"
            echo "  just ci-local"
          '';
        };
      });
}
