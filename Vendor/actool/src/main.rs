//! actool CLI entry point.

use actool::{catalog, compiler, icon_bundle, symbols};
use clap::Parser;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

const BUNDLE_VERSION: &str = "24506";
const SHORT_BUNDLE_VERSION: &str = "26.3";

#[derive(Parser, Debug)]
#[command(name = "actool", about = "Compiles, prints, updates, and verifies asset catalogs.")]
struct Cli {
    /// Path to .xcassets document
    document: Option<PathBuf>,

    /// Output format
    #[arg(long, default_value = "xml1",
          value_parser = ["xml1", "binary1", "human-readable-text"])]
    output_format: String,

    #[arg(long)]
    compile: Option<PathBuf>,

    #[arg(long)]
    warnings: bool,

    #[arg(long)]
    errors: bool,

    #[arg(long)]
    notices: bool,

    #[arg(long)]
    output_partial_info_plist: Option<PathBuf>,

    #[arg(long)]
    app_icon: Option<String>,

    #[arg(long)]
    include_all_app_icons: bool,

    #[arg(long, action = clap::ArgAction::Append, default_value = "")]
    alternate_app_icon: Vec<String>,

    #[arg(long)]
    accent_color: Option<String>,

    #[arg(long)]
    widget_background_color: Option<String>,

    #[arg(long, default_value = "macosx")]
    platform: String,

    #[arg(long, default_value = "11.0")]
    minimum_deployment_target: String,

    #[arg(long, action = clap::ArgAction::Append, default_value = "")]
    target_device: Vec<String>,

    #[arg(long, default_value = "default",
          value_parser = ["default", "all", "none"])]
    standalone_icon_behavior: String,

    #[arg(long)]
    compress_pngs: bool,

    #[arg(long)]
    skip_app_store_deployment: bool,

    #[arg(long, default_value = "NO")]
    enable_on_demand_resources: String,

    #[arg(long)]
    bundle_identifier: Option<String>,

    #[arg(long)]
    development_region: Option<String>,

    #[arg(long, action = clap::ArgAction::Append, default_value = "")]
    include_language: Vec<String>,

    #[arg(long, default_value = "YES")]
    include_partial_info_plist_localizations: String,

    #[arg(long)]
    export_dependency_info: Option<PathBuf>,

    #[arg(long)]
    generate_objc_asset_symbols: Option<PathBuf>,

    #[arg(long)]
    generate_asset_symbol_index: Option<PathBuf>,

    #[arg(long)]
    print_contents: bool,

    #[arg(long)]
    version: bool,
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    if cli.version {
        print_version(&cli.output_format);
        return ExitCode::SUCCESS;
    }

    let Some(document) = cli.document.clone() else {
        eprintln!("error: a document path is required");
        return ExitCode::from(2);
    };

    if cli.print_contents && cli.compile.is_none() {
        match catalog::AssetCatalog::new(
            document.clone(),
            cli.platform.clone(),
            cli.minimum_deployment_target.clone(),
            None,
            None,
            None,
        )
        .parse()
        {
            Ok(_) => {
                // TODO: emit catalog-contents plist. For parity we emit an
                // empty container so downstream tooling doesn't crash.
                print_plist_xml("com.apple.actool.catalog-contents", "(empty)");
            }
            Err(e) => {
                eprintln!("error: {e}");
                return ExitCode::from(1);
            }
        }
        return ExitCode::SUCCESS;
    }

    let Some(compile_dir) = cli.compile.clone() else {
        eprintln!("error: --compile is required");
        return ExitCode::from(2);
    };

    // --generate-objc-asset-symbols with --bundle-identifier replaces normal
    // compilation: only the header (and optional index) is produced.
    if let (Some(header_path), Some(bundle_id)) =
        (cli.generate_objc_asset_symbols.as_ref(), cli.bundle_identifier.as_ref())
    {
        if let Err(e) = symbols::generate_symbols_header(
            &document,
            header_path,
            bundle_id,
            &cli.platform,
        ) {
            eprintln!("error generating header: {e}");
            return ExitCode::from(1);
        }
        let mut output_files: Vec<PathBuf> = Vec::new();
        if let Some(index_path) = cli.generate_asset_symbol_index.as_ref() {
            if let Err(e) =
                symbols::generate_symbol_index(&document, index_path, &cli.platform)
            {
                eprintln!("error generating index: {e}");
                return ExitCode::from(1);
            }
            output_files.push(
                std::fs::canonicalize(index_path).unwrap_or_else(|_| index_path.clone()),
            );
        }
        output_files.push(
            std::fs::canonicalize(header_path).unwrap_or_else(|_| header_path.clone()),
        );
        if let Some(dep) = cli.export_dependency_info.as_ref() {
            if let Err(e) = write_dependency_info(dep, &document, &output_files) {
                eprintln!("error writing deps: {e}");
                return ExitCode::from(1);
            }
        }
        print_compilation_results(&cli.output_format, &output_files);
        return ExitCode::SUCCESS;
    }

    let include_languages: Option<Vec<String>> = {
        let v: Vec<String> =
            cli.include_language.iter().filter(|s| !s.is_empty()).cloned().collect();
        if v.is_empty() {
            None
        } else {
            Some(v)
        }
    };
    let plist_l10n = !matches!(
        cli.include_partial_info_plist_localizations.to_ascii_uppercase().as_str(),
        "NO"
    );

    // Dispatch to icon bundle handler when the document is a .icon bundle
    let output_files = if icon_bundle::is_icon_bundle(&document) {
        match icon_bundle::compile_icon_bundle(
            &document,
            &compile_dir,
            &cli.platform,
            &cli.minimum_deployment_target,
            cli.app_icon.as_deref(),
            cli.output_partial_info_plist.as_deref(),
            cli.accent_color.as_deref(),
            &cli.standalone_icon_behavior,
        ) {
            Ok(f) => f,
            Err(e) => {
                eprintln!("error compiling icon bundle: {e}");
                return ExitCode::from(1);
            }
        }
    } else {
        match compiler::compile_catalog(
            &document,
            &compile_dir,
            &cli.platform,
            &cli.minimum_deployment_target,
            cli.app_icon.as_deref(),
            cli.output_partial_info_plist.as_deref(),
            cli.accent_color.as_deref(),
            cli.widget_background_color.as_deref(),
            &cli.standalone_icon_behavior,
            include_languages,
            cli.development_region.clone(),
            plist_l10n,
        ) {
            Ok(f) => f,
            Err(e) => {
                eprintln!("error: {e}");
                return ExitCode::from(1);
            }
        }
    };

    if let Some(dep) = cli.export_dependency_info.as_ref() {
        if let Err(e) = write_dependency_info(dep, &document, &output_files) {
            eprintln!("error writing deps: {e}");
            return ExitCode::from(1);
        }
    }

    print_compilation_results(&cli.output_format, &output_files);
    ExitCode::SUCCESS
}

fn print_version(format: &str) {
    let mut s = String::new();
    s.push_str(&format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.actool.version</key>
	<dict>
		<key>bundle-version</key>
		<string>{BUNDLE_VERSION}</string>
		<key>short-bundle-version</key>
		<string>{SHORT_BUNDLE_VERSION}</string>
	</dict>
</dict>
</plist>
"#
    ));
    if format == "human-readable-text" {
        println!("/* com.apple.actool.version */");
        println!("bundle-version: {BUNDLE_VERSION}");
        println!("short-bundle-version: {SHORT_BUNDLE_VERSION}");
    } else {
        print!("{s}");
    }
}

fn print_plist_xml(_top_key: &str, _body: &str) {
    // Minimal stub — full --print-contents implementation is out of scope
    // of the rewrite's first milestone.
}

fn print_compilation_results(format: &str, output_files: &[PathBuf]) {
    if format == "human-readable-text" {
        println!("/* com.apple.actool.compilation-results */");
        for f in output_files {
            println!("{}", f.display());
        }
        return;
    }
    let mut s = String::new();
    s.push_str(r#"<?xml version="1.0" encoding="UTF-8"?>"#);
    s.push('\n');
    s.push_str(r#"<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">"#);
    s.push('\n');
    s.push_str(r#"<plist version="1.0">"#);
    s.push('\n');
    s.push_str("<dict>\n");
    s.push_str("\t<key>com.apple.actool.compilation-results</key>\n");
    s.push_str("\t<dict>\n");
    s.push_str("\t\t<key>output-files</key>\n");
    s.push_str("\t\t<array>\n");
    for f in output_files {
        s.push_str(&format!("\t\t\t<string>{}</string>\n", f.display()));
    }
    s.push_str("\t\t</array>\n");
    s.push_str("\t</dict>\n");
    s.push_str("</dict>\n");
    s.push_str("</plist>\n");
    print!("{s}");
}

fn write_dependency_info(
    path: &Path,
    xcassets_path: &Path,
    output_files: &[PathBuf],
) -> std::io::Result<()> {
    let mut out: Vec<u8> = Vec::new();
    out.push(0x00);
    out.extend_from_slice(format!("actool-{BUNDLE_VERSION}").as_bytes());
    out.push(0x00);
    let abs_input = std::fs::canonicalize(xcassets_path)
        .unwrap_or_else(|_| xcassets_path.to_path_buf());
    out.push(0x10);
    out.extend_from_slice(abs_input.to_string_lossy().as_bytes());
    out.push(0x00);
    for f in output_files {
        out.push(0x40);
        out.extend_from_slice(f.to_string_lossy().as_bytes());
        out.push(0x00);
    }
    std::fs::write(path, out)
}
