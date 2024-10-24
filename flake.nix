{
  description = "Example Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      nix-homebrew,
      determinate,
      home-manager,
    }:
    let
      configuration =
        { pkgs, config, ... }:
        {
          # List packages installed in system profile. To search by name, run:
          # $ nix-env -qaP | grep wget
          environment.systemPackages = [
            pkgs.fish

            pkgs.mkalias # for making gui applications work
          ];

          environment.variables.HOMEBREW_NO_ANALYTICS = "1";
          homebrew = {
            enable = true;
            casks = [
              "firefox"
              "logseq"
            ];
          };

          fonts.packages = with pkgs; [ commit-mono iosevka ];

          system = {
            defaults = {
              dock.autohide = true;
              dock.persistent-apps = [ ];
              finder.ShowPathbar = true;
              finder.ShowStatusBar = true;
              finder.FXPreferredViewStyle = "clmn";
            };
            keyboard = {
              enableKeyMapping = true;
              remapCapsLockToControl = true;
            };
          };

          networking.hostName = "hoatzin";

          # make gui applications exist in finder
          # https://gist.github.com/elliottminns/211ef645ebd484eb9a5228570bb60ec3
          # https://github.com/nix-community/home-manager/issues/1341#issuecomment-2049723843
          # https://github.com/LnL7/nix-darwin/issues/214#issuecomment-2048491929
          system.activationScripts.applications.text =
            let
              env = pkgs.buildEnv {
                name = "system-applications";
                paths = config.environment.systemPackages;
                pathsToLink = "/Applications";
              };
            in
            pkgs.lib.mkForce ''
              # Set up applications.
              echo "setting up /Applications..." >&2
              rm -rf /Applications/Nix\ Apps
              mkdir -p /Applications/Nix\ Apps
              find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
              while read src; do
                app_name=$(basename "$src")
                echo "copying $src" >&2
                ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
              done
            '';

          # Auto upgrade nix package and the daemon service.
          services.nix-daemon.enable = true;
          # nix.package = pkgs.nix;

          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

          # Create /etc/zshrc that loads the nix-darwin environment.
          # programs.zsh.enable = true; # default shell on catalina
          programs.fish.enable = true;

          # Set Git commit hash for darwin-version.
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Used for backwards compatibility, please read the changelog before changing.
          # $ darwin-rebuild changelog
          system.stateVersion = 5;

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = "aarch64-darwin";
        };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#hoatzin
      darwinConfigurations."hoatzin" = nix-darwin.lib.darwinSystem {
        modules = [
          configuration
          determinate.darwinModules.default
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = "arwn";
            };
          }
          home-manager.darwinModules.home-manager 
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            users.users.arwn.home = /Users/arwn;
            users.users.arwn.name = "arwn";
            home-manager.users.arwn = import ./home.nix;
            # Optionally, use home-manager.extraSpecialArgs to pass
            # arguments to home.nix
          }
        ];
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."hoatzin".pkgs;
    };
}
