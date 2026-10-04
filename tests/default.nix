{ pkgs, llib }:

{
  lib-asdfFunctions-skills = import ./lib.asdfFunctions {
    inherit pkgs llib;
  };
}
