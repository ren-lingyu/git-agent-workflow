let

  mkClosureEntry_ = dependency_ : {
    key = builtins.unsafeDiscardStringContext (toString dependency_);
    dependency = dependency_;
  };

  lispDependencyClosure_ = dependencies_ : builtins.map
    (entry_ : entry_.dependency)
    (builtins.genericClosure {
      startSet = builtins.map mkClosureEntry_ dependencies_;

      operator = entry_ : builtins.map
        mkClosureEntry_
        (entry_.dependency.propagatedBuildInputs or [ ]);
    });

  mkLispRegistry_ = dependencies_ : builtins.concatStringsSep ":" (
    builtins.map
      (dependency_ : "${dependency_}//")
      (lispDependencyClosure_ dependencies_)
  );

  mkAsdfScript_ = {
    pkgs,
    name,
    asdName,
    operation,
  } : pkgs.replaceVarsWith {
    src = ./asdf-script.lisp;

    replacements = {
      asdName = builtins.toJSON asdName;
      inherit operation;
    };

    inherit name;
  };

  mkPackage_ = {
    pkgs,
    project,
    packageAttrs,
  } : pkgs.stdenvNoCC.mkDerivation (
    pkgs.lib.mergeAttrsList [
      packageAttrs

      {
        pname = project.pname;
        version = project.version;
        src = project.source;

        nativeBuildInputs = builtins.concatLists [
          [
            project.lisp
          ]
          (packageAttrs.nativeBuildInputs or [ ])
        ];

        ASDF_OUTPUT_TRANSLATIONS = "/:/";

        dontConfigure = true;
        dontStrip = true;

        buildPhase = builtins.concatStringsSep "\n" [
          "runHook preBuild"
          "export CL_SOURCE_REGISTRY=\"$PWD${pkgs.lib.optionalString
            (project.lispRegistry != "")
            ":${project.lispRegistry}"
          }\""
          "${pkgs.lib.getExe project.lisp} --script ${project.buildScript}"
          "runHook postBuild"
        ];

        installPhase = builtins.concatStringsSep "\n" [
          "runHook preInstall"
          "mkdir -p \"$out/bin\""
          "install -m755 ${project.program} \"$out/bin/${project.program}\""
          "runHook postInstall"
        ];

        meta = pkgs.lib.mergeAttrsList [
          {
            mainProgram = project.program;
          }
          project.meta
        ];
      }
    ]
  );

  mkCheck_ = {
    pkgs,
    project,
    package,
    checkAttrs,
  } : pkgs.stdenvNoCC.mkDerivation (
    pkgs.lib.mergeAttrsList [
      checkAttrs

      {
        pname = "${project.pname}-test";
        version = project.version;
        src = project.source;

        nativeBuildInputs = builtins.concatLists [
          [
            project.lisp
            package
          ]
          (checkAttrs.nativeBuildInputs or [ ])
        ];

        ASDF_OUTPUT_TRANSLATIONS = "/:/";

        dontConfigure = true;

        buildPhase = builtins.concatStringsSep "\n" [
          "runHook preBuild"
          "export CL_SOURCE_REGISTRY=\"$PWD${pkgs.lib.optionalString
            (project.lispRegistry != "")
            ":${project.lispRegistry}"
          }\""
          "${pkgs.lib.getExe project.lisp} --script ${project.checkScript}"
          "runHook postBuild"
        ];

        installPhase = "mkdir -p \"$out\"";
      }
    ]
  );

in {

  mkProject = {
    pkgs,
    asdFile,
    pname ? null,
    program,
    lispDependencies ? (_ : [ ]),
    derivationAttrs ? ({ } : {
      package = { };
      check = { };
    }),
    meta ? { },
  } : let

    root_ = builtins.dirOf (toString asdFile);

    asdName_ = builtins.baseNameOf (toString asdFile);

    pname_ = (
      if pname == null
      then program
      else pname
    );

    project_ = {
      pname = pname_;

      version = pkgs.lib.removeSuffix "\n" (
        builtins.readFile "${root_}/VERSION"
      );

      source = builtins.path {
        path = root_;
        name = "${pname_}-source";
      };

      lisp = pkgs.sbcl;

      lispRegistry = mkLispRegistry_ (
        lispDependencies pkgs.sbcl.pkgs
      );

      buildScript = mkAsdfScript_ {
        inherit pkgs;
        name = "${pname_}-build.lisp";
        asdName = asdName_;
        operation = "asdf:program-op";
      };

      checkScript = mkAsdfScript_ {
        inherit pkgs;
        name = "${pname_}-check.lisp";
        asdName = asdName_;
        operation = "asdf:test-op";
      };

      inherit
        program
        meta
        ;
    };

  in {

    package = pkgs.lib.makeOverridable
      (arguments_ : mkPackage_ {
        inherit pkgs;
        project = project_;
        packageAttrs = (derivationAttrs arguments_).package or { };
      })
      { };

    check = pkgs.lib.makeOverridable
      (arguments_ : let
        attrs_ = derivationAttrs arguments_;
      in mkCheck_ {
        inherit pkgs;
        project = project_;

        package = mkPackage_ {
          inherit pkgs;
          project = project_;
          packageAttrs = attrs_.package or { };
        };

        checkAttrs = attrs_.check or { };
      })
      { };

  };

}
