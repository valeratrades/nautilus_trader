{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv/v1.6.1";
    v_flakes.url = "github:valeratrades/v_flakes?ref=v1.6";
  };

  outputs = inputs@{ self, nixpkgs, rust-overlay, flake-parts, devenv, v_flakes }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devenv.flakeModule
      ];

      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem = { config, self', inputs', system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import rust-overlay) ];
          };
          rust = pkgs.rust-bin.stable."1.91.0".default.override {
            extensions = [ "rust-src" "rust-analyzer" ];
          };
          pname = "nautilus_trader";
          files = v_flakes.files;
          github = v_flakes.github {
            inherit pkgs pname;
            syncFork = true;
          };
        in
        {
          _module.args.pkgs = pkgs;

          devenv.shells.default = {
            packages = [
              rust
              pkgs.mold-wrapped
              pkgs.pkg-config
              pkgs.openssl
              pkgs.cmake
              pkgs.clang
            ] ++ github.enabledPackages;

            languages.python = {
              enable = true;
              package = pkgs.python312;
              uv = {
                enable = true;
                sync.enable = false;
              };
            };

            scripts = {
              uv_sync.exec = "uv sync --all-extras --dev --prerelease=allow";
            };

            env = {
              RUST_BACKTRACE = 1;
              RUST_LIB_BACKTRACE = 0;
            };

            enterShell = v_flakes.utils.unwrapShellHook github.shellHook + ''
              cp -f ${(files.gitattributes) { inherit pkgs; lfs = false; }} ./.gitattributes
            '';
          };
        };
    };
}
