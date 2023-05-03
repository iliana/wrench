# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
{
  flake-utils,
  nixpkgs,
  ...
}: {
  checks ? {},
  ciPackage ? null,
  eachSystem ? (system: {}),
  nixosConfigurations ? {},
  nixosImports ? [],
  nixosSpecialArgs ? (system: {}),
  packages ? (system: callPackage: {}),
  setHostName ? true,
  systems ? flake-utils.lib.defaultSystems,
  testModule ? ({...}: {}),
}: let
  lib = nixpkgs.lib;
  genSystems = lib.attrsets.genAttrs systems;

  pkgs = nixpkgs.legacyPackages;
  myPkgs = genSystems (system: packages system pkgs.${system}.callPackage);

  mySystems =
    lib.concatMapAttrs
    (system: systems:
      builtins.mapAttrs
      (name: config: {
        inherit system;
        modules =
          lib.lists.optionals setHostName [
            ({...}: {
              networking.hostName = name;
            })
          ]
          ++ nixosImports
          ++ [config];
      })
      systems)
    nixosConfigurations;
  specialArgs = genSystems (system:
    nixosSpecialArgs system
    // {
      myPkgs = myPkgs.${system};
    });

  myNixosConfigs =
    builtins.mapAttrs
    (name: attrs:
      lib.nixosSystem {
        inherit (attrs) system;
        modules = attrs.modules;
        specialArgs = specialArgs.${attrs.system};
      })
    mySystems;

  myChecks = let
    args = name: system:
      (builtins.mapAttrs
        (name: attrs: ({...}: {
          imports = attrs.modules ++ [testModule];
        }))
        mySystems)
      // {
        pkgs = pkgs.${system};
        runTest = (
          args:
            lib.nixos.runTest
            (lib.attrsets.recursiveUpdate
              {
                inherit name;
                hostPkgs = pkgs.${system};
                node.specialArgs = specialArgs.${system};
              }
              args)
        );
      };
  in
    builtins.mapAttrs
    (system: checks:
      builtins.mapAttrs (name: check:
        (
          if builtins.isPath check
          then import check
          else check
        ) (args name system))
      checks)
    checks;
in
  lib.attrsets.recursiveUpdate
  (flake-utils.lib.eachSystem systems eachSystem)
  {
    packages = genSystems (system:
      myPkgs.${system}
      // (
        if (ciPackage != null)
        then {
          ${ciPackage} = pkgs.${system}.linkFarm ciPackage (lib.lists.flatten [
            (lib.attrsets.mapAttrsToList
              (name: drv: {
                name = "packages/${name}";
                path = drv;
              })
              myPkgs.${system})
            (lib.attrsets.mapAttrsToList
              (name: drv: {
                name = "systems/${name}";
                path = drv.config.system.build.toplevel;
              })
              (lib.attrsets.filterAttrs
                (name: _: mySystems.${name}.system == system)
                myNixosConfigs))
            (lib.attrsets.mapAttrsToList
              (name: drv: {
                name = "checks/${name}";
                path = drv;
              })
              myChecks.${system})
          ]);
        }
        else {}
      ));
    nixosConfigurations = myNixosConfigs;
    checks = myChecks;
  }
