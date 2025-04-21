{
  description = "reticulate";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11-small";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            shellHook = ''
              PS1='\u@\h  :\w; '
            '';
            buildInputs = with pkgs; [
              perlPackages.PerlTidy
              perlPackages.PerlLanguageServer
            ];
            nativeBuildInputs = with pkgs; [ rex ];
          };
        });
    };
}
