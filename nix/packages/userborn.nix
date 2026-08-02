{
  lib,
  rustPlatform,
  libxcrypt,
  withJsonschema ? true,
}:

let
  cargoToml = builtins.fromTOML (builtins.readFile ../../rust/userborn/Cargo.toml);
in
rustPlatform.buildRustPackage {
  pname = cargoToml.package.name;
  inherit (cargoToml.package) version;

  src = lib.sourceFilesBySuffices ../../rust/userborn [
    ".rs"
    ".toml"
    ".lock"
  ];

  outputs = [
    "out"
  ]
  ++ lib.optionals withJsonschema [
    "dev"
  ];

  cargoLock = {
    lockFile = ../../rust/userborn/Cargo.lock;
  };

  nativeBuildInputs = [
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    libxcrypt
  ];

  buildFeatures = lib.optionals withJsonschema [ "jsonschema" ];

  postInstall = lib.optionalString withJsonschema ''
    mkdir -p $dev
    $out/bin/jsonschema > $dev/userborn.schema.json
    rm $out/bin/jsonschema
  '';

  stripAllList = [ "bin" ];

  meta = with lib; {
    homepage = "https://github.com/nikstur/userborn";
    license = licenses.mit;
    maintainers = with lib.maintainers; [ nikstur ];
    mainProgram = "userborn";
  };
}
