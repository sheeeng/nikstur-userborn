use userborn::Config;

fn main() {
    let schema = schemars::schema_for!(Config);
    println!(
        "{}",
        serde_json::to_string_pretty(&schema).expect("Failed to generate jsonschema.")
    );
}
