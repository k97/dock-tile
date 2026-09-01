//! Parser for the `icon.json` manifest inside a `.icon` bundle
//! (Apple's IconComposer / "liquid glass" format introduced in macOS 26).
//!
//! Only the subset needed to drive catalog compilation is typed; fields we
//! don't yet act on are kept as `serde_json::Value` so unknown keys never
//! cause parse failures.

use serde::Deserialize;
use std::path::Path;

#[derive(Debug, Clone, Deserialize)]
pub struct IconJson {
    #[serde(default)]
    pub fill: Option<Fill>,
    #[serde(default)]
    pub groups: Vec<Group>,
    #[serde(default, rename = "supported-platforms")]
    pub supported_platforms: Option<SupportedPlatforms>,
    #[serde(default, rename = "color-space-for-untagged-svg-colors")]
    pub color_space_for_untagged_svg_colors: Option<String>,
    /// Top-level `fill-specializations` — list of appearance-keyed fill
    /// variants. When present, Apple's actool emits an alternate set of
    /// pre-rendered sized renditions (attr 24 = 1) alongside the primary
    /// set, plus an alternate atlas (gamut=1) for the small sizes.
    #[serde(default, rename = "fill-specializations")]
    pub fill_specializations: Option<Vec<serde_json::Value>>,
}

/// `fill` may be the string "automatic", a `{linear-gradient: [...]}`,
/// `{automatic-gradient: "..."}`, or a solid color spec — all valid.
#[derive(Debug, Clone, Deserialize)]
#[serde(untagged)]
pub enum Fill {
    Keyword(String),
    Structured(serde_json::Value),
}

#[derive(Debug, Clone, Deserialize)]
pub struct Group {
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub hidden: Option<bool>,
    #[serde(default)]
    pub position: Option<Position>,
    #[serde(default)]
    pub layers: Vec<Layer>,
    #[serde(default)]
    pub shadow: Option<Shadow>,
    #[serde(default, rename = "shadow-specializations")]
    pub shadow_specializations: Option<Vec<serde_json::Value>>,
    #[serde(default)]
    pub translucency: Option<Translucency>,
    #[serde(default, rename = "translucency-specializations")]
    pub translucency_specializations: Option<Vec<serde_json::Value>>,
    #[serde(default)]
    pub specular: Option<bool>,
    #[serde(default, rename = "specular-specializations")]
    pub specular_specializations: Option<Vec<serde_json::Value>>,
    #[serde(default, rename = "blur-material")]
    pub blur_material: Option<serde_json::Value>,
    #[serde(default, rename = "blur-material-specializations")]
    pub blur_material_specializations: Option<Vec<serde_json::Value>>,
    #[serde(default, rename = "lighting-specializations")]
    pub lighting_specializations: Option<Vec<serde_json::Value>>,
    #[serde(default, rename = "blend-mode-specializations")]
    pub blend_mode_specializations: Option<Vec<serde_json::Value>>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Layer {
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default, rename = "image-name")]
    pub image_name: Option<String>,
    #[serde(default)]
    pub glass: Option<bool>,
    #[serde(default)]
    pub hidden: Option<bool>,
    #[serde(default)]
    pub position: Option<Position>,
    #[serde(default, rename = "blend-mode-specializations")]
    pub blend_mode_specializations: Option<Vec<serde_json::Value>>,
    #[serde(default, rename = "hidden-specializations")]
    pub hidden_specializations: Option<Vec<serde_json::Value>>,
    #[serde(default, rename = "glass-specializations")]
    pub glass_specializations: Option<Vec<serde_json::Value>>,
    #[serde(default, rename = "opacity-specializations")]
    pub opacity_specializations: Option<Vec<serde_json::Value>>,
    #[serde(default, rename = "fill-specializations")]
    pub fill_specializations: Option<Vec<serde_json::Value>>,
    /// Per-layer fill (e.g. `{"solid": "extended-gray:0.84536,1.0"}` in
    /// KYA's Logo layer). When the icon-level fill is a keyword like
    /// "system-dark" Apple still appends a Color rendition derived from
    /// each layer's structured fill.
    #[serde(default)]
    pub fill: Option<Fill>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Position {
    #[serde(default)]
    pub scale: Option<f32>,
    #[serde(default, rename = "translation-in-points")]
    pub translation_in_points: Option<[f32; 2]>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Shadow {
    pub kind: String,
    #[serde(default)]
    pub opacity: Option<f32>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Translucency {
    #[serde(default)]
    pub enabled: Option<bool>,
    #[serde(default)]
    pub value: Option<f32>,
}

/// `supported-platforms` can list explicit platform names OR the keyword
/// "shared" — both are valid icon.json (the second appears in
/// KeepingYouAwake's AppIcon.icon and tagspaces's icon.icon).
#[derive(Debug, Clone, Deserialize)]
#[serde(untagged)]
pub enum PlatformList {
    Shared(String),
    Explicit(Vec<String>),
}

impl PlatformList {
    pub fn as_slice(&self) -> &[String] {
        match self {
            PlatformList::Shared(_) => &[],
            PlatformList::Explicit(v) => v,
        }
    }

    pub fn is_shared(&self) -> bool {
        matches!(self, PlatformList::Shared(s) if s == "shared")
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct SupportedPlatforms {
    #[serde(default)]
    pub squares: Option<PlatformList>,
    #[serde(default)]
    pub circles: Option<PlatformList>,
}

impl IconJson {
    pub fn parse(text: &str) -> serde_json::Result<Self> {
        serde_json::from_str(text)
    }

    pub fn parse_file(path: &Path) -> std::io::Result<Self> {
        let text = std::fs::read_to_string(path)?;
        Self::parse(&text).map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))
    }

    /// Iterate (group, layer) for every defined layer in document order.
    pub fn iter_layers(&self) -> impl Iterator<Item = (&Group, &Layer)> {
        self.groups
            .iter()
            .flat_map(|g| g.layers.iter().map(move |l| (g, l)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_element_web_style() {
        let s = r#"{
            "fill": "automatic",
            "groups": [{
                "name": "Figma",
                "layers": [{"glass": false, "image-name": "element.png", "name": "element"}],
                "shadow": {"kind": "none", "opacity": 0.5},
                "specular": false,
                "translucency": {"enabled": false, "value": 0.5}
            }],
            "supported-platforms": {"squares": ["macOS"]}
        }"#;
        let j = IconJson::parse(s).unwrap();
        assert_eq!(j.groups.len(), 1);
        assert_eq!(j.groups[0].name.as_deref(), Some("Figma"));
        assert_eq!(j.groups[0].layers.len(), 1);
        assert_eq!(
            j.groups[0].layers[0].image_name.as_deref(),
            Some("element.png")
        );
        assert_eq!(j.groups[0].layers[0].glass, Some(false));
        assert_eq!(j.groups[0].shadow.as_ref().unwrap().kind, "none");
        let sp = j.supported_platforms.unwrap();
        assert_eq!(sp.squares.unwrap().as_slice(), &["macOS".to_string()]);
    }

    #[test]
    fn parses_supported_platforms_shared_string() {
        // KeepingYouAwake's AppIcon.icon and tagspaces' icon.icon use the
        // keyword "shared" instead of an explicit platform list.
        let s = r#"{
            "groups": [],
            "supported-platforms": {"squares": "shared", "circles": ["watchOS"]}
        }"#;
        let j = IconJson::parse(s).unwrap();
        let sp = j.supported_platforms.unwrap();
        let sq = sp.squares.unwrap();
        assert!(sq.is_shared());
        assert!(sq.as_slice().is_empty());
        let circ = sp.circles.unwrap();
        assert_eq!(circ.as_slice(), &["watchOS".to_string()]);
    }

    #[test]
    fn parses_gradient_fill_and_specializations() {
        let s = r#"{
            "fill": {"linear-gradient": ["srgb:1,0,0,1", "srgb:0,0,1,1"]},
            "groups": [{
                "layers": [{
                    "glass": true,
                    "image-name": "Overlay.svg",
                    "name": "Overlay",
                    "fill-specializations": [
                        {"appearance": "tinted", "value": {"linear-gradient": ["gray:0.9,1", "extended-gray:0.75,1"]}}
                    ]
                }],
                "shadow": {"kind": "layer-color"},
                "translucency": {"enabled": true, "value": 0.2}
            }]
        }"#;
        let j = IconJson::parse(s).unwrap();
        assert!(matches!(j.fill, Some(Fill::Structured(_))));
        let layer = &j.groups[0].layers[0];
        assert_eq!(layer.glass, Some(true));
        assert!(layer.fill_specializations.is_some());
    }

    #[test]
    fn unknown_fields_are_ignored() {
        let s = r#"{"future-field": 42, "groups": []}"#;
        let j = IconJson::parse(s).unwrap();
        assert!(j.groups.is_empty());
    }

    #[test]
    fn iter_layers_visits_each_layer() {
        let s = r#"{
            "groups": [
                {"layers": [{"name": "a"}, {"name": "b"}]},
                {"layers": [{"name": "c"}]}
            ]
        }"#;
        let j = IconJson::parse(s).unwrap();
        let names: Vec<_> = j
            .iter_layers()
            .map(|(_, l)| l.name.clone().unwrap())
            .collect();
        assert_eq!(names, vec!["a", "b", "c"]);
    }
}
