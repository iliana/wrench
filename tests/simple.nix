system: inputs:
import ../generate.nix inputs {
  packages = system: callPackage: {
    hello = callPackage ({pkgs, ...}:
      pkgs.writeShellApplication {
        name = "hello";
        text = ''
          echo 'Hello, world!'
        '';
      }) {};
  };

  nixosConfigurations.${system}.ghost = {myPkgs, ...}: {
    environment.systemPackages = [myPkgs.hello];
    system.stateVersion = "22.11";
  };

  checks.${system}.simple-hello = {
    runTest,
    ghost,
    ...
  }:
    runTest {
      nodes = {
        inherit ghost;
      };

      testScript = ''
        stdout = ghost.succeed("hello")
        assert stdout.strip() == 'Hello, world!'
      '';
    };
}
