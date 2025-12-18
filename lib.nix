lib: let
  inherit (lib) types;

  # Utilities
  utils = {
    get = obj: attr: obj.${attr};
    pipe' = lib.flip lib.pipe;
    evalWith = arg: f: f arg;
    majorMinorVersion = utils.pipe' [
      builtins.splitVersion
      (lib.sublist 0 2)
      (builtins.concatStringsSep ".")
      (builtins.replaceStrings ["."] [""])
    ];
    ifElse = condition: yes: no:
      if condition
      then yes
      else no;
  };

  # Vals
  vals = {
    sops.custom = config: file: attr: "ref+sops://${config.canivete.sops.directory}/${file}${attr}+";
    sops.default = config: attr: "ref+sops://${config.canivete.sops.default}#/${attr}+";
    tfstate = config: workspace: attr:
      builtins.concatStringsSep "/" [
        "ref+tfstate:/"
        config.canivete.opentofu.directory
        workspace
        "terraform.tfstate.dec"
        "${attr}+"
      ];
  };

  # Attrsets
  sets = {
    mapNames = f: lib.mapAttrs' (name: lib.nameValuePair (f name));
    prefixNames = utils.pipe' [lib.prefix lib.mapNames];
  };

  # String manipulation
  strings = {
    first = builtins.substring 0 1;
    rest = str: builtins.substring 1 (builtins.stringLength str - 1) str;
    prefix = pre: str: lib.concatStrings [pre str];
    prefixJoin = pre: sep: lib.concatMapStringsSep sep (option: pre + option);
    pascalToCamel = str: lib.toLower (strings.first str) + strings.rest str;
    camelToPascal = str: lib.toUpper (strings.first str) + strings.rest str;
    # NOTE taken from https://gist.github.com/manveru/74eb41d850bc146b7e78c4cb059507e2
    toBase64 = text: let
      convertTripletInt = let
        lookup = lib.stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        pows = [(64 * 64 * 64) (64 * 64) 64 1];
        intSextets = i: map (j: lib.mod (i / j) 64) pows;
      in
        utils.pipe' [intSextets (lib.concatMapStrings (builtins.elemAt lookup))];
      sliceToInt = builtins.foldl' (acc: val: acc * 256 + val) 0;
      nFullSlices = (builtins.stringLength text) / 3;
      tripletAt = let
        sliceN = size: list: n: lib.sublist (n * size) size list;
        bytes = map lib.strings.charToInt (lib.stringToCharacters text);
      in
        sliceN 3 bytes;

      head = let
        convertTriplet = utils.pipe' [sliceToInt convertTripletInt];
      in
        builtins.genList (utils.pipe' [tripletAt convertTriplet]) nFullSlices;
      tail = let
        convertLastSlice = slice: let
          len = builtins.length slice;
        in
          if len == 1
          then (builtins.substring 0 2 (convertTripletInt ((sliceToInt slice) * 256 * 256))) + "=="
          else if len == 2
          then (builtins.substring 0 3 (convertTripletInt ((sliceToInt slice) * 256))) + "="
          else "";
      in
        convertLastSlice (tripletAt nFullSlices);
    in
      builtins.concatStringsSep "" (head ++ [tail]);
  };

  # Fileset collectors
  filesets = rec {
    # List absolute path of files in <root> that satisfy <f>
    filter = f: root:
      lib.pipe root [
        builtins.readDir
        (lib.filterAttrs f)
        builtins.attrNames
        (map (file: root + "/${file}"))
      ];
    # List directories in <root>
    dirs = filter (_: type: type == "directory");
    # List files in <root> that satisfy <f>
    files = f: filter (name: type: type == "regular" && f name type);
    # Recursively list all files in <_dirs> that satisfy <f>
    everything = f: let
      filesAndDirs = root:
        (files f root) ++ (builtins.concatMap (everything f) (dirs root));
    in
      lib.flip lib.pipe [
        lib.toList
        (map filesAndDirs)
        lib.flatten
      ];
    # Filter out <exclude> paths from "everything" in <roots>
    everythingBut = f: roots: exclude:
      filter (_path: builtins.all (prefix: ! lib.path.hasPrefix prefix _path) exclude) (everything f roots);
    nix = {
      filter = name: _: (builtins.match ".+\\.nix$" name != null) && (builtins.match ".*flake\\.nix$" name == null);
      files = files nix.filter;
      everything = everything nix.filter;
      everythingBut = everythingBut nix.filter;
    };
  };

  # Options
  wrapped = wrapper: nested: more: let
    option = type: description: more: lib.mkOption ({inherit type description;} // more);
    overlayDefault = _: _: {};
    # Fixes nested option wrapping
    wrapOptions = value:
      if lib.isFunction value
      then arg: wrapOptions (value arg)
      else if builtins.isList value
      then builtins.map wrapOptions value
      else if builtins.isAttrs value
      then
        if (value._type or null) == "option" && (value ? type)
        then value // {type = wrapper value.type;}
        else builtins.mapAttrs (_: wrapOptions) value
      else value;
  in
    lib.pipe [
      "anything"
      "bool"
      "int"
      "package"
      "path"
      "raw"
      "str"
      "pathInStore"
    ] [
      (_types: lib.genAttrs _types lib.id)
      (lib.mergeAttrs {
        module = "deferredModule";
      })
      (builtins.mapAttrs (_: utils.get types))
      (lib.mergeAttrs {
        overlay = types.mkOptionType {
          name = "overlays";
          description = "nixpkgs overlay";
          inherit (types.functionTo (types.functionTo (types.attrsOf types.anything))) check;
          merge = _: defs: builtins.foldl' (acc: f: x: acc (f x)) overlayDefault (map (x: x.value) defs);
        };
        subdomain = types.strMatching "^[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]$";
        domain = types.strMatching "^([a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.)+[a-z]{2,10}$";
        email = types.strMatching "^[a-zA-Z0-9][a-zA-Z0-9_.%+\-]{0,61}[a-zA-Z0-9]@([a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,10}$";
      })
      (builtins.mapAttrs (_: wrapper))
      (builtins.mapAttrs (_: option))
      # TODO write these overrides more ergonomically!
      (builtins.mapAttrs (_: _option: description: _more: _option description (more // _more)))
      (old: let
        submoduleWith = args: module:
          types.submoduleWith {
            modules = [module];
            shorthandOnlyDefinesConfig = true;
            specialArgs = args // {inherit can;};
          };
        mkOpt = type: defaults: description: _more:
          option (wrapper type) description (defaults // more // _more);
      in
        lib.mergeAttrs old {
          option = type: mkOpt type {};
          yaml = {
            option = pkgs: mkOpt (pkgs.formats.yaml {}).type {default = {};};
            generate = pkgs: (pkgs.formats.yaml {}).generate;
          };
          toml = {
            option = pkgs: mkOpt (pkgs.formats.toml {}).type {default = {};};
            generate = pkgs: (pkgs.formats.toml {}).generate;
          };
          # TODO should I do a check for _flake type?
          flake = inputs: name: mkOpt (types.nullOr types.raw) {default = inputs.${name} or null;} name;
          overlay = description: _more: old.overlay description ({default = overlayDefault;} // more // _more);
          enum = values: mkOpt (types.enum values) {};
          enable = mkOpt types.bool {default = false;};
          submodule = description: module: mkOpt (submoduleWith {} module) {default = {};} description {};
          submoduleWith = description: args: module: mkOpt (submoduleWith args module) {default = {};} description {};
          withSubmodule = module: lib.mkOption {type = wrapper (types.submodule module);};
        })
      (lib.mergeAttrs (builtins.mapAttrs (_: utils.pipe' [(utils.evalWith more) wrapOptions]) nested))
    ];
  opt = wrapped types.nullOr {inherit attrs function list;};
  attrs = wrapped types.attrsOf {inherit attrs function list opt;};
  list = wrapped types.listOf {inherit attrs function list opt;};
  function = wrapped types.functionTo {inherit attrs function list opt;};
  options =
    (wrapped lib.id {} {})
    // {
      attrs = attrs {default = {};};
      function = function {};
      list = list {default = [];};
      opt = opt {default = null;};
    };

  can = lib.mergeAttrsList [
    options
    sets
    strings
    {inherit vals filesets;}
  ];
in
  can
