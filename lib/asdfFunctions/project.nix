let

  scripts_ = import ./scripts.nix;

  mkInstallAgentSkills_ = import ./install-agent-skills.nix;

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

  mkPackage_ = {
    pkgs,
    project,
    packageAttrs,
    installAgentSkillsCapability,
  } : pkgs.stdenvNoCC.mkDerivation (
    pkgs.lib.mergeAttrsList [
      packageAttrs
      installAgentSkillsCapability.derivationAttrs

      {
        pname = project.pname;
        version = project.version;
        src = project.source;

        nativeBuildInputs = builtins.concatLists [
          [ project.lisp ]
          installAgentSkillsCapability.nativeBuildInputs
          (packageAttrs.nativeBuildInputs or [ ])
        ];

        ASDF_OUTPUT_TRANSLATIONS = "/:/";

        dontConfigure = true;
        dontStrip = true;

        buildPhase = builtins.concatStringsSep "\n" ([
          "runHook preBuild"
          "export CL_SOURCE_REGISTRY=\"$PWD${pkgs.lib.optionalString
            (project.lispRegistry != "")
            ":${project.lispRegistry}"
          }\""
          "${pkgs.lib.getExe project.lisp} --script ${project.buildScript}"
        ] ++ installAgentSkillsCapability.buildCommands ++ [
          "runHook postBuild"
        ]);

        installPhase = builtins.concatStringsSep "\n" ([
          "runHook preInstall"
          "mkdir -p \"$out/bin\""
          "install -m755 ${project.program} \"$out/bin/${project.program}\""
        ] ++ installAgentSkillsCapability.installCommands ++ [
          "runHook postInstall"
        ]);

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
    installAgentSkills ? true,
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
      asdName = asdName_;

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

      buildScript = scripts_.mkAsdfOperationScript {
        inherit pkgs;
        name = "${pname_}-build.lisp";
        asdName = asdName_;
        operation = "asdf:program-op";
      };

      checkScript = scripts_.mkAsdfOperationScript {
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

    installAgentSkillsCapability_ = if installAgentSkills then mkInstallAgentSkills_ {
      inherit pkgs;
      project = project_;
      mkAsdfScript = scripts_.mkAsdfScript;
    } else {
      nativeBuildInputs = [ ];
      derivationAttrs = { };
      buildCommands = [ ];
      installCommands = [ ];
    };

  in {

    package = pkgs.lib.makeOverridable
      (arguments_ : mkPackage_ {
        inherit pkgs;
        project = project_;
        installAgentSkillsCapability = installAgentSkillsCapability_;
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
          installAgentSkillsCapability = installAgentSkillsCapability_;
          packageAttrs = attrs_.package or { };
        };

        checkAttrs = attrs_.check or { };
      })
      { };

  };

}
