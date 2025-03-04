{ lib
, stdenvNoCC }:

let
  escapedList = with lib; concatMapStringsSep " " (s: "'${escape [ "'" ] s}'");
  fileName = pathStr: lib.last (lib.splitString "/" pathStr);
  scriptsDir = "$out/share/mpv/scripts";

  # similar to `lib.extends`, but with inverted precedence and recursive update
  extendedBy = args: orig: self:
    let super = args self;
    in lib.recursiveUpdate (orig super) super
  ;
in

lib.makeOverridable (args: stdenvNoCC.mkDerivation (extendedBy
  (if lib.isFunction args then args else (_: args)) (
  { pname
  , extraScripts ? []
  , ... }@args:
  let
    strippedName = with builtins;
      let groups = match "mpv[-_](.*)" pname; in
      if groups != null
      then head groups
      else pname
    ;
    # either passthru.scriptName, inferred from scriptPath, or from pname
    scriptName = (args.passthru or {}).scriptName or (
      if args ? scriptPath
      then fileName args.scriptPath
      else "${strippedName}.lua"
    );
    scriptPath = args.scriptPath or "./${scriptName}";
  in {
    dontBuild = true;
    preferLocalBuild = true;

    outputHashMode = "recursive";
    installPhase = ''
      runHook preInstall

      if [ -d "${scriptPath}" ]; then
        [ -f "${scriptPath}/main.lua" ] || {
          echo "Script directory '${scriptPath}' does not contain 'main.lua'" >&2
          exit 1
        }
        [ ${with builtins; toString (length extraScripts)} -eq 0 ] || {
          echo "mpvScripts.buildLua does not support 'extraScripts'" \
               "when 'scriptPath' is a directory"
          exit 1
        }
        mkdir -p "${scriptsDir}"
        cp -a "${scriptPath}" "${scriptsDir}/${lib.removeSuffix ".lua" scriptName}"
      else
        install -m644 -Dt "${scriptsDir}" \
          ${escapedList ([ scriptPath ] ++ extraScripts)}
      fi

      runHook postInstall
    '';

    passthru = { inherit scriptName; };
    meta.platforms = lib.platforms.all;
  })
))
