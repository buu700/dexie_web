{
  description = "dexie_web - self-contained Dexie.js wrapper for Flutter Web";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        isLinux = pkgs.stdenv.isLinux;
        linuxChromeExecutable = if isLinux then "${pkgs.chromium}/bin/chromium" else "";
        chromiumDisplayVersion =
          if isLinux then pkgs.chromium.version else "host Chrome (must match Nix ChromeDriver)";
      in
      {
        # Service entry and probes need the matching driver, not Flutter's SDK
        # startup commands or its shared tool lock.
        devShells.services = pkgs.mkShellNoCC {
          packages = [
            pkgs.chromedriver
            pkgs.curl
          ];
        };

        devShells.default = pkgs.mkShell {
          name = "dexie_web-dev";

          buildInputs = [
            pkgs.flutter
            pkgs.nodejs_24
            pkgs.just
            pkgs.lefthook
            pkgs.openssl
            pkgs.chromedriver
            pkgs.curl
            pkgs.git
            pkgs.coreutils
          ]
          ++ pkgs.lib.optionals isLinux [ pkgs.chromium ];

          # dart run must resolve Flutter SDK dependencies against this same SDK.
          FLUTTER_ROOT = "${pkgs.flutter}";
          FLUTTER_WEB_BROWSER = "chromium";
          shellHook = ''
            if [[ "${if isLinux then "1" else "0"}" == "1" ]]; then
              export CHROME_EXECUTABLE="''${CHROME_EXECUTABLE:-${linuxChromeExecutable}}"
            else
              export CHROME_EXECUTABLE="''${CHROME_EXECUTABLE:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
            fi

            echo "dexie_web dev shell (Nix) loaded"
            echo "Platform: ${if isLinux then "Linux/WSL2" else "macOS"}"
            echo "Flutter: $(flutter --version | head -n1)"
            echo "Dart: $(dart --version 2>&1 | head -n1)"
            echo "Node: $(node --version)"
            echo "Chromium: ${chromiumDisplayVersion}"
            echo "CHROME_EXECUTABLE: ${"$"}{CHROME_EXECUTABLE:-not-found}"

            echo ""
            echo "Available commands:"
            echo "  just setup"
            echo "  just e2e"
            echo "  just test-web"
            echo "  just verify"
          '';
        };
      }
    );
}
