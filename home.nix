{ config, pkgs, ... }:
{
  programs.home-manager.enable = true;
  
  home = {
    stateVersion = "23.05";
    username = "arwn";
    homeDirectory = /Users/arwn;

    packages = with pkgs; [
      fish
      jujutsu
    ];
  };
  programs.fish.enable = true;
  programs.fish.shellAliases.e = "echo eeeeeeee!";
}
