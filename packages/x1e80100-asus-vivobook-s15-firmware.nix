{
  stdenv,
  writeShellScript,
  curl,
  cacert,
  jq,
  p7zip,
}:

let
  version = "1.318.7800.0";
  rev = "43699";
  fix = "_1"; # hot-fix, should empty if not have
  filename = "SOCPackage_forWebSite_Qualcomm_Z_V${version}_${rev}${fix}.exe";
  hash = "sha256-fY+nV4D+Ki/ZCIKsfE3MohFSujzU6zMYO/pscvTyCAE=";

  # @see https://github.com/NixOS/nixpkgs/pull/91254/files
  src = stdenv.mkDerivation {
    name = filename;

    nativeBuildInputs = [
      curl
      cacert
      jq
    ];

    builder = writeShellScript "builder.sh" ''
      source $stdenv/setup

      set -x
      shopt -s lastpipe

      # fetched from devtools:
      curl 'https://cdnta.asus.com/api/v1/TokenHQ?filePath=https:%2F%2Fdlcdnta.asus.com%2Fpub%2FASUS%2Fnb%2FImage%2FDriver%2FDriverPackage%2F${rev}%2F${filename}%3Fmodel%3DS5507QA&systemCode=asus' \
        -X 'POST' \
        -H 'accept: application/json, text/plain, */*' \
        -H 'accept-language: zh-CN,zh;q=0.7' \
        -H 'content-length: 0' \
        -H 'dnt: 1' \
        -H 'origin: https://www.asus.com' \
        -H 'priority: u=1, i' \
        -H 'referer: https://www.asus.com/' \
        -H 'sec-ch-ua: "Brave";v="137", "Chromium";v="137", "Not/A)Brand";v="24"' \
        -H 'sec-ch-ua-mobile: ?0' \
        -H 'sec-ch-ua-platform: "Linux"' \
        -H 'sec-fetch-dest: empty' \
        -H 'sec-fetch-mode: cors' \
        -H 'sec-fetch-site: same-site' \
        -H 'sec-gpc: 1' \
        -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36' | \
      jq -r '.result | [.expires, .signature, .keyPairId] | @tsv' | \
      read -r expires signature pair

      # downloads
      curl "https://dlcdnta.asus.com/pub/ASUS/nb/Image/Driver/DriverPackage/${rev}/${filename}?model=S5507QA&Signature=$signature&Expires=$expires&Key-Pair-Id=$pair" \
        --insecure \
        -o $out
    '';

    outputHashAlgo = "sha256";
    outputHash = hash;
  };
in
stdenv.mkDerivation {
  pname = "x1e80100-asus-vivobook-s15-firmware";
  version = rev;
  inherit src;

  nativeBuildInputs = [ p7zip ];

  # 7z will fail some files, doesn't matter
  unpackPhase = ''
    runHook preUnpack
    mkdir $out
    cd $out
    7z x $src || true
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;
  dontStrip = true;

  # linux/arch/arm64/boot/dts/qcom/x1e80100-asus-vivobook-s15.dts firmware-name
  installPhase = ''
    runHook preInstall
    declare -A COPIES=(
      ["qcom/x1e80100/ASUSTeK/vivobook-s15/qcadsp8380.mbn"]="Driver/QualcommBSP/Subsystem/qcsubsys_ext_adsp8380_0324_Signed/qcadsp8380.mbn"
      ["qcom/x1e80100/ASUSTeK/vivobook-s15/adsp_dtbs.elf"]="Driver/QualcommBSP/Subsystem/qcsubsys_ext_adsp8380_0324_Signed/adsp_dtbs.elf"
      ["qcom/x1e80100/ASUSTeK/vivobook-s15/qccdsp8380.mbn"]="Driver/QualcommBSP/NPU/qcnspmcdm_ext_cdsp8380/qccdsp8380.mbn"
      ["qcom/x1e80100/ASUSTeK/vivobook-s15/cdsp_dtbs.elf"]="Driver/QualcommBSP/NPU/qcnspmcdm_ext_cdsp8380/cdsp_dtbs.elf"
      ["qcom/x1e80100/ASUSTeK/vivobook-s15/qcdxkmsuc8380.mbn"]="Driver/QualcommBSP/GFX/qcdx8380/qcdxkmsuc8380.mbn"
    )
    mkdir -p $out/lib/firmware
    for target in "''${!COPIES[@]}"; do
      source="''${COPIES[$target]}"
      mkdir -p "$(dirname "$out/lib/firmware/$target")"
      cp "$source" "$out/lib/firmware/$target"
    done
    runHook postInstall
  '';
}
