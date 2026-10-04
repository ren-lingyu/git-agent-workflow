let

  mkAsdfScript_ = {
    pkgs,
    name,
    asdName,
    body,
  } : pkgs.replaceVarsWith {
    src = ./asdf-script.lisp;

    replacements = {
      asdName = builtins.toJSON asdName;
      inherit body;
    };

    inherit name;
  };

in {

  mkAsdfScript = mkAsdfScript_;

  mkAsdfOperationScript = {
    pkgs,
    name,
    asdName,
    operation,
  } : mkAsdfScript_ {
    inherit
      pkgs
      name
      asdName
      ;

    body = builtins.concatStringsSep "\n" [
      "(asdf:operate"
      " '${operation}"
      " system)"
    ];
  };

}
