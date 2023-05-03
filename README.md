# :wrench: wrench

wrench is a Nix flake for quickly declaring NixOS configurations with custom packages, and tests to test those configurations.

I haven't written reference documentation yet but you can refer to [iliana/nixos-configs](https://github.com/iliana/nixos-configs) for more in-depth usage.

## Example

flake.nix:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    wrench.url = "github:iliana/wrench";
    wrench.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {wrench, ...}:
    wrench.lib.generate {
      packages = system: callPackage: {
        hello = callPackage ./hello.nix {};
      };

      nixosConfigurations.x86_64-linux.ghost = {myPkgs, ...}: {
        environment.systemPackages = [myPkgs.hello];
        system.stateVersion = "22.11";
      };

      checks.x86_64-linux.hello = {
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
    };
}
```

<details><summary>hello.nix (for completeness)</summary>

```nix
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "hello";
  text = ''
    echo 'Hello, world!'
  '';
}
```

</details>