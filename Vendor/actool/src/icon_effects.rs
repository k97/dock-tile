//! Resolve a `.icon` group/layer's appearance-keyed effect specializations
//! into concrete, typed parameters the icon renderer can consume.
//!
//! Every visual effect in `icon.json` appears in one of two forms:
//!   * a plain field — `"shadow": {"kind": "neutral", "opacity": 1}`
//!   * an appearance-keyed list — `"shadow-specializations": [{"value": …},
//!     {"appearance": "dark", "value": …}, {"appearance": "tinted", …}]`
//! The list, when present, supersedes the plain field; an entry with no
//! `appearance` is the default (light) value and the fallback for any
//! appearance lacking its own entry.
//!
//! This module only *resolves parameters* — it does not render. The constants
//! at the bottom record the icon-frame geometry measured from `/usr/bin/actool`
//! output (`tools/extract_pixels`) so the eventual CoreGraphics pass has the
//! numbers it needs. See `docs/icon-shading.md`.

use crate::icon_json::{Group, Layer};
use serde_json::Value;

/// The three rendering appearances a `.icon` is built for. `Light` is the
/// default (no-appearance) value; `Dark`/`Tinted` override per their entries.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Appearance {
    Light,
    Dark,
    Tinted,
}

impl Appearance {
    fn json_name(self) -> &'static str {
        match self {
            Appearance::Light => "light",
            Appearance::Dark => "dark",
            Appearance::Tinted => "tinted",
        }
    }
}

/// How the icon's drop shadow is coloured.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShadowKind {
    /// No shadow.
    None,
    /// Neutral black/grey shadow.
    Neutral,
    /// Shadow tinted by the layer's own colour.
    LayerColor,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ShadowSpec {
    pub kind: ShadowKind,
    pub opacity: f32,
}

/// Group lighting model.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Lighting {
    Individual,
    Combined,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Translucency {
    pub enabled: bool,
    pub value: f32,
}

/// Per-layer shading inputs resolved for one appearance.
#[derive(Debug, Clone)]
pub struct LayerEffects {
    pub glass: bool,
    pub opacity: f32,
    /// Compositing blend mode (`normal`, `soft-light`, …).
    pub blend_mode: String,
    pub hidden: bool,
}

/// All shading inputs for an icon group, resolved for a single appearance.
#[derive(Debug, Clone)]
pub struct IconEffects {
    pub shadow: ShadowSpec,
    pub specular: bool,
    pub translucency: Translucency,
    /// Blur-material strength (frosted-glass behind the layer), 0..1, if set.
    pub blur_material: Option<f32>,
    pub lighting: Lighting,
    pub blend_mode: String,
    pub layers: Vec<LayerEffects>,
}

/// Pick the `value` of the specialization entry that applies to `appearance`:
/// an exact appearance match, else the default (no-appearance) entry.
fn spec_value<'a>(specs: &'a [Value], appearance: Appearance) -> Option<&'a Value> {
    let exact = specs.iter().find(|s| {
        s.get("appearance").and_then(|a| a.as_str()) == Some(appearance.json_name())
    });
    exact
        .or_else(|| specs.iter().find(|s| s.get("appearance").is_none()))
        .and_then(|s| s.get("value"))
}

/// Resolve an effect from its optional specialization list (preferred) or a
/// plain fallback `Value`, then map it with `f`.
fn resolve<'a, T>(
    specs: Option<&'a Vec<Value>>,
    plain: Option<&'a Value>,
    appearance: Appearance,
    f: impl Fn(&Value) -> Option<T>,
) -> Option<T> {
    let v = specs
        .and_then(|s| spec_value(s, appearance))
        .or(plain);
    v.and_then(f)
}

fn parse_shadow(v: &Value) -> Option<ShadowSpec> {
    // The value may be a string ("none") or an object {kind, opacity}.
    if let Some(s) = v.as_str() {
        return Some(ShadowSpec {
            kind: if s == "none" { ShadowKind::None } else { ShadowKind::Neutral },
            opacity: 1.0,
        });
    }
    let kind = match v.get("kind").and_then(|k| k.as_str()) {
        Some("none") => ShadowKind::None,
        Some("layer-color") => ShadowKind::LayerColor,
        Some("neutral") | Some(_) => ShadowKind::Neutral,
        None => ShadowKind::Neutral,
    };
    let opacity = v.get("opacity").and_then(|o| o.as_f64()).unwrap_or(1.0) as f32;
    Some(ShadowSpec { kind, opacity })
}

fn parse_translucency(v: &Value) -> Option<Translucency> {
    Some(Translucency {
        enabled: v.get("enabled").and_then(|e| e.as_bool()).unwrap_or(false),
        value: v.get("value").and_then(|x| x.as_f64()).unwrap_or(0.0) as f32,
    })
}

/// `blur-material` may be a bare number or `{value: <num>}`; `null` disables it.
fn parse_blur(v: &Value) -> Option<f32> {
    if v.is_null() {
        return None;
    }
    if let Some(n) = v.as_f64() {
        return Some(n as f32);
    }
    v.get("value").and_then(|x| x.as_f64()).map(|x| x as f32)
}

fn resolve_layer(layer: &Layer, appearance: Appearance) -> LayerEffects {
    let glass = resolve(
        layer.glass_specializations.as_ref(),
        layer.glass.map(Value::from).as_ref(),
        appearance,
        |v| v.as_bool(),
    )
    .unwrap_or(false);
    let opacity = resolve(
        layer.opacity_specializations.as_ref(),
        None,
        appearance,
        |v| v.as_f64().map(|x| x as f32),
    )
    .unwrap_or(1.0);
    let blend_mode = resolve(
        layer.blend_mode_specializations.as_ref(),
        None,
        appearance,
        |v| v.as_str().map(str::to_string),
    )
    .unwrap_or_else(|| "normal".to_string());
    let hidden = resolve(
        layer.hidden_specializations.as_ref(),
        layer.hidden.map(Value::from).as_ref(),
        appearance,
        |v| v.as_bool(),
    )
    .unwrap_or(false);
    LayerEffects { glass, opacity, blend_mode, hidden }
}

/// Resolve every shading input for `group` at `appearance`.
pub fn resolve_icon_effects(group: &Group, appearance: Appearance) -> IconEffects {
    let plain_shadow = group
        .shadow
        .as_ref()
        .map(|s| serde_json::json!({"kind": s.kind, "opacity": s.opacity}));
    let shadow = resolve(
        group.shadow_specializations.as_ref(),
        plain_shadow.as_ref(),
        appearance,
        parse_shadow,
    )
    .unwrap_or(ShadowSpec { kind: ShadowKind::None, opacity: 1.0 });

    let specular = resolve(
        group.specular_specializations.as_ref(),
        group.specular.map(Value::from).as_ref(),
        appearance,
        |v| v.as_bool(),
    )
    .unwrap_or(false);

    let plain_trans = group.translucency.as_ref().map(|t| {
        serde_json::json!({"enabled": t.enabled.unwrap_or(false), "value": t.value.unwrap_or(0.0)})
    });
    let translucency = resolve(
        group.translucency_specializations.as_ref(),
        plain_trans.as_ref(),
        appearance,
        parse_translucency,
    )
    .unwrap_or(Translucency { enabled: false, value: 0.0 });

    let blur_material = resolve(
        group.blur_material_specializations.as_ref(),
        group.blur_material.as_ref(),
        appearance,
        parse_blur,
    );

    let lighting = match resolve(
        group.lighting_specializations.as_ref(),
        None,
        appearance,
        |v| v.as_str().map(str::to_string),
    )
    .as_deref()
    {
        Some("combined") => Lighting::Combined,
        _ => Lighting::Individual,
    };

    let blend_mode = resolve(
        group.blend_mode_specializations.as_ref(),
        None,
        appearance,
        |v| v.as_str().map(str::to_string),
    )
    .unwrap_or_else(|| "normal".to_string());

    let layers = group
        .layers
        .iter()
        .map(|l| resolve_layer(l, appearance))
        .collect();

    IconEffects {
        shadow,
        specular,
        translucency,
        blur_material,
        lighting,
        blend_mode,
        layers,
    }
}

/// Icon-frame drop-shadow geometry, as a fraction of the canvas edge. The icon
/// tile always casts this constant halo (a blurred black copy of the squircle,
/// nudged downward) regardless of the group `shadow` kind — Apple's halo is the
/// same for `shadow: none`, absent, or `layer-color`. Tuned to Apple's measured
/// α profile (`tools/probe_margin_shadow.py`): top 16/11/6, bottom 37/31/22/12
/// at 4/8/14/22 px out.
pub mod shadow_geometry {
    /// `CGContextSetShadowWithColor` blur radius. Tuned so the rendered halo's
    /// falloff matches Apple's (reaching ~45px out, top/bottom α profile).
    pub const BLUR_RATIO: f64 = 34.0 / 1024.0;
    /// Downward offset (the bottom halo is heavier than the top).
    pub const OFFSET_Y_RATIO: f64 = 9.0 / 1024.0;
    /// Shadow-colour alpha at `opacity = 1`; blurs down to the measured edge
    /// peaks (bottom α ≈37, top ≈16 at opacity 0.5).
    pub const PEAK_ALPHA: f64 = 0.245;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::icon_json::IconJson;

    fn group0(json: &str) -> Group {
        IconJson::parse(json).unwrap().groups.into_iter().next().unwrap()
    }

    #[test]
    fn feishin_resolves_per_appearance() {
        // feishin group: shadow neutral/1 (light) vs layer-color/0.5 (dark);
        // specular false (light) / true (tinted); translucency on@0.29 (light)
        // off (dark); one glass layer.
        let g = group0(
            r#"{"groups":[{"layers":[{"image-name":"f.svg","name":"f",
                "glass-specializations":[{"value":true},{"appearance":"dark","value":true}]}],
              "shadow-specializations":[{"value":{"kind":"neutral","opacity":1}},
                {"appearance":"dark","value":{"kind":"layer-color","opacity":0.5}}],
              "specular-specializations":[{"value":false},{"appearance":"tinted","value":true}],
              "translucency-specializations":[{"value":{"enabled":true,"value":0.29}},
                {"appearance":"dark","value":{"enabled":false,"value":0.29}}],
              "blur-material-specializations":[{"value":0.7},{"appearance":"tinted","value":null}],
              "lighting-specializations":[{"value":"individual"},{"appearance":"tinted","value":"combined"}]
            }]}"#,
        );
        let light = resolve_icon_effects(&g, Appearance::Light);
        assert_eq!(light.shadow.kind, ShadowKind::Neutral);
        assert_eq!(light.shadow.opacity, 1.0);
        assert!(!light.specular);
        assert!(light.translucency.enabled);
        assert_eq!(light.blur_material, Some(0.7));
        assert_eq!(light.lighting, Lighting::Individual);
        assert!(light.layers[0].glass);

        let dark = resolve_icon_effects(&g, Appearance::Dark);
        assert_eq!(dark.shadow.kind, ShadowKind::LayerColor);
        assert_eq!(dark.shadow.opacity, 0.5);
        assert!(!dark.translucency.enabled);

        let tinted = resolve_icon_effects(&g, Appearance::Tinted);
        assert!(tinted.specular, "tinted overrides specular to true");
        assert_eq!(tinted.blur_material, None, "tinted disables blur (null)");
        assert_eq!(tinted.lighting, Lighting::Combined);
    }

    #[test]
    fn plain_fields_resolve_without_specializations() {
        // element-web: everything disabled via plain fields.
        let g = group0(
            r#"{"groups":[{"layers":[{"image-name":"e.png","name":"e","glass":false}],
              "shadow":{"kind":"none","opacity":0.5},"specular":false,
              "translucency":{"enabled":false,"value":0.5}}]}"#,
        );
        let e = resolve_icon_effects(&g, Appearance::Light);
        assert_eq!(e.shadow.kind, ShadowKind::None);
        assert!(!e.specular);
        assert!(!e.translucency.enabled);
        assert!(!e.layers[0].glass);
        // No dark entries → dark falls back to the same plain values.
        let d = resolve_icon_effects(&g, Appearance::Dark);
        assert_eq!(d.shadow.kind, ShadowKind::None);
    }
}
