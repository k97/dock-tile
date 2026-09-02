#!/usr/bin/env python3
"""Emit the Dock Tile makeover artboards (.dc.html) + canvas.json — light and dark.

Every window artboard shares the same chrome (sidebar, header band, cards) so the
screens can't drift from each other. Values are lifted from the app source:
  - TintColor presets (ConfigurationModels.swift colorTop/colorBottom)
  - squircle radius 22.5% (IconGenerator), form row 40pt, card radius 12pt
  - window width 768 (DockTileConfigurationView), sidebar ideal 240
  - popover metrics: Medium tile 56 (grid) / 24 (list), Comfortable gap 14
Theme tokens are CSS custom properties set per artboard (`THEMES`), so the dark
page is the same markup under a different token set.
"""
import json, os

OUT = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- tokens
TINT = {
    "red":    ("#FF6B6B", "#FF3B30"),
    "orange": ("#FFA94D", "#FF9500"),
    "green":  ("#6BCF7F", "#34C759"),
    "blue":   ("#4DABF7", "#007AFF"),
    "purple": ("#B197FC", "#AF52DE"),
    "pink":   ("#FF6B9D", "#FF2D55"),
    "gray":   ("#ADB5BD", "#8E8E93"),
    "indigo": ("#8E97EE", "#5856D6"),
}
ACCENT = "#007AFF"

THEMES = {
    "light": {
        "stage": "#D9DADD", "bg": "#EEEFF1", "sb": "#E3E5E8", "sbline": "rgba(0,0,0,.1)",
        "text": "rgba(0,0,0,.85)", "sec": "rgba(0,0,0,.5)", "ter": "rgba(0,0,0,.32)", "ic": "rgba(0,0,0,.65)",
        "sel": "rgba(0,0,0,.09)", "hov": "rgba(0,0,0,.07)",
        "card": "#FFFFFF", "hair": "rgba(0,0,0,.09)", "sep": "rgba(0,0,0,.09)",
        "btn": "#FFFFFF", "btnsh": "0 .5px 1.5px rgba(0,0,0,.18),inset 0 0 0 .5px rgba(0,0,0,.06)",
        "subtle": "rgba(0,0,0,.05)", "seg": "rgba(0,0,0,.06)", "segon": "#FFFFFF", "segsh": "0 .5px 2px rgba(0,0,0,.2),0 0 0 .5px rgba(0,0,0,.04)",
        "swoff": "rgba(0,0,0,.13)", "chip": "rgba(0,0,0,.06)", "field": "#FFFFFF", "fieldline": "rgba(0,0,0,.14)",
        "canvas": "linear-gradient(150deg,#C8D2E3 0%,#D8D1DF 55%,#E5DCD6 100%)", "canvasline": "rgba(0,0,0,.1)",
        "pop": "rgba(247,247,249,.9)", "popline": "rgba(255,255,255,.7)", "poptext": "#1d1d1f", "popsub": "rgba(0,0,0,.4)",
        "cellhov": "rgba(0,0,0,.055)", "dash": "rgba(0,0,0,.32)", "badge": "#5A5A60",
        "sheet": "#F5F5F7", "sheetcard": "#FBFBFC", "sheetline": "rgba(0,0,0,.1)", "dim": "rgba(0,0,0,.22)",
        "winsh": "0 24px 60px -18px rgba(0,0,0,.38),0 0 0 .5px rgba(0,0,0,.2)",
        "dockbar": "rgba(255,255,255,.42)", "dockline": "rgba(255,255,255,.6)",
        "banner": "rgba(0,122,255,.1)", "bannerline": "rgba(0,122,255,.22)",
    },
    "dark": {
        "stage": "#1C1C1E", "bg": "#323234", "sb": "#2C2C2E", "sbline": "rgba(255,255,255,.08)",
        "text": "rgba(255,255,255,.92)", "sec": "rgba(255,255,255,.55)", "ter": "rgba(255,255,255,.35)", "ic": "rgba(255,255,255,.72)",
        "sel": "rgba(255,255,255,.11)", "hov": "rgba(255,255,255,.08)",
        "card": "#3C3C3F", "hair": "rgba(255,255,255,.09)", "sep": "rgba(255,255,255,.08)",
        "btn": "#525255", "btnsh": "0 .5px 1.5px rgba(0,0,0,.4),inset 0 .5px 0 rgba(255,255,255,.08)",
        "subtle": "rgba(255,255,255,.08)", "seg": "rgba(0,0,0,.28)", "segon": "#5E5E62", "segsh": "0 .5px 2px rgba(0,0,0,.4),inset 0 .5px 0 rgba(255,255,255,.08)",
        "swoff": "rgba(255,255,255,.18)", "chip": "rgba(255,255,255,.1)", "field": "rgba(0,0,0,.22)", "fieldline": "rgba(255,255,255,.12)",
        "canvas": "linear-gradient(150deg,#2E3A5F 0%,#3D3356 55%,#4B3D3B 100%)", "canvasline": "rgba(255,255,255,.08)",
        "pop": "rgba(48,48,53,.92)", "popline": "rgba(255,255,255,.14)", "poptext": "rgba(255,255,255,.92)", "popsub": "rgba(255,255,255,.45)",
        "cellhov": "rgba(255,255,255,.09)", "dash": "rgba(255,255,255,.35)", "badge": "#8A8A90",
        "sheet": "#2E2E31", "sheetcard": "#3A3A3D", "sheetline": "rgba(255,255,255,.1)", "dim": "rgba(0,0,0,.45)",
        "winsh": "0 24px 60px -18px rgba(0,0,0,.7),0 0 0 .5px rgba(255,255,255,.12)",
        "dockbar": "rgba(255,255,255,.14)", "dockline": "rgba(255,255,255,.22)",
        "banner": "rgba(10,132,255,.16)", "bannerline": "rgba(10,132,255,.32)",
    },
}

CSS = """
body{margin:0;background:var(--stage);font-family:-apple-system,"SF Pro Text","Helvetica Neue",system-ui,sans-serif;font-size:13px;line-height:1.25;color:var(--text);-webkit-font-smoothing:antialiased}
a{color:#007AFF}a:hover{color:#0060D0}
.stage{padding:24px;display:flex;justify-content:center}
.win{width:768px;height:640px;display:flex;border-radius:11px;overflow:hidden;background:var(--bg);box-shadow:var(--winsh);position:relative}
.sb{width:240px;flex:none;background:var(--sb);box-shadow:inset -.5px 0 0 var(--sbline);display:flex;flex-direction:column;padding:0 10px 12px}
.band{height:52px;flex:none;display:flex;align-items:center;gap:8px;padding:0 4px 0 10px}
.tl{display:flex;gap:8px}.tl i{width:12px;height:12px;border-radius:6px;display:block;box-shadow:inset 0 0 0 .5px rgba(0,0,0,.14)}
.ib{width:26px;height:24px;border-radius:6px;display:flex;align-items:center;justify-content:center;color:var(--ic)}
.ib.hov{background:var(--hov)}
.sbh{font-size:11px;font-weight:700;color:var(--sec);padding:8px 8px 4px}
.sbr{display:flex;align-items:center;gap:9px;height:30px;padding:0 8px;border-radius:6px;font-size:13px;color:var(--text)}
.sbr.sel{background:var(--sel)}
.sbr .lbl{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.content{flex:1;min-width:0;display:flex;flex-direction:column;position:relative}
.hdr{height:52px;flex:none;display:flex;align-items:center;gap:9px;padding:0 16px 0 20px}
.title{font-size:16px;font-weight:600;letter-spacing:-.1px;color:var(--text)}
.body{flex:1;min-height:0;overflow-y:auto;padding:0 20px 24px;display:flex;flex-direction:column;gap:18px}
.card{background:var(--card);border-radius:12px;box-shadow:inset 0 0 0 .5px var(--hair);overflow:hidden}
.row{display:flex;align-items:center;gap:12px;min-height:40px;padding:0 14px}
.sep{height:.5px;background:var(--sep);margin-left:14px}
.sec{display:flex;align-items:center;gap:10px;padding:0 4px}
.sec .t{font-size:13px;font-weight:600}
.sub{font-size:11px;color:var(--sec)}
.ter{font-size:11px;color:var(--ter)}
.sw{width:38px;height:22px;border-radius:11px;background:#007AFF;position:relative;flex:none}
.sw i{position:absolute;top:2px;left:18px;width:18px;height:18px;border-radius:9px;background:#fff;box-shadow:0 1px 2px rgba(0,0,0,.28);display:block}
.sw.off{background:var(--swoff)}.sw.off i{left:2px}
.seg{display:inline-flex;height:22px;padding:2px;border-radius:7px;background:var(--seg);gap:1px;font-size:12px;flex:none;color:var(--text)}
.seg span{padding:0 10px;display:flex;align-items:center;border-radius:5px;white-space:nowrap}
.seg span.on{background:var(--segon);box-shadow:var(--segsh);font-weight:500}
.btn{height:22px;padding:0 10px;border-radius:6px;background:var(--btn);box-shadow:var(--btnsh);display:inline-flex;align-items:center;gap:5px;font-size:13px;white-space:nowrap;flex:none;color:var(--text)}
.btn.prom{background:#007AFF;color:#fff;box-shadow:0 .5px 1.5px rgba(0,80,200,.4),inset 0 .5px 0 rgba(255,255,255,.25);font-weight:500}
.btn.dis{opacity:.42}
.btn.subtle{background:var(--subtle);box-shadow:none;height:24px;justify-content:center;font-size:12px}
.chip{display:inline-flex;align-items:center;gap:4px;background:var(--chip);border-radius:9px;padding:2px 8px;font-size:10.5px;font-weight:500;color:var(--sec);white-space:nowrap}
.canvas{border-radius:12px;background:var(--canvas);box-shadow:inset 0 0 0 .5px var(--canvasline);padding:22px;display:flex;justify-content:center}
.pop{background:var(--pop);border-radius:14px;box-shadow:0 14px 34px -12px rgba(0,0,20,.45),inset 0 0 0 .5px var(--popline);padding:0 14px 12px;color:var(--poptext)}
.pophdr{height:36px;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:500}
.cell{position:relative;display:flex;flex-direction:column;align-items:center;gap:6px;padding:8px 6px 6px;border-radius:10px;width:72px;box-sizing:border-box}
.cell .nm{font-size:11px;max-width:64px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.badge{position:absolute;top:1px;left:5px;width:18px;height:18px;border-radius:9px;background:var(--badge);box-shadow:0 1px 3px rgba(0,0,0,.3),inset 0 0 0 .5px rgba(255,255,255,.25);display:flex;align-items:center;justify-content:center}
.note{font-size:11px;color:var(--sec)}
.field{display:flex;align-items:center;gap:6px;height:22px;padding:0 8px;border-radius:6px;background:var(--field);box-shadow:inset 0 0 0 .5px var(--fieldline);font-size:13px;color:var(--ter)}
.sw-dot{width:24px;height:24px;border-radius:12px;box-shadow:inset 0 0 0 .5px rgba(0,0,0,.12)}
.dock{display:flex;align-items:center;gap:10px;padding:8px 12px;border-radius:16px;background:var(--dockbar);box-shadow:inset 0 0 0 .5px var(--dockline),0 10px 30px -12px rgba(0,0,0,.45)}
"""

# ---------------------------------------------------------------- svg icons (24 grid, stroke)
def svg(paths, size=16, stroke="currentColor", sw=1.8, fill="none"):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{paths}</svg>')

def fsvg(paths, size=16, fill="#fff"):
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="{fill}">{paths}</svg>'

P = {
    "plus": '<path d="M12 5v14M5 12h14"></path>',
    "xmark": '<path d="M6 6l12 12M18 6L6 18"></path>',
    "chevL": '<path d="M14 6l-6 6 6 6"></path>',
    "updown": '<path d="M8 10l4-4 4 4M8 14l4 4 4-4"></path>',
    "trash": '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"></path>',
    "gear": '<circle cx="12" cy="12" r="3.2"></circle><path d="M12 2.8v2.6M12 18.6v2.6M21.2 12h-2.6M5.4 12H2.8M18.5 5.5l-1.8 1.8M7.3 16.7l-1.8 1.8M18.5 18.5l-1.8-1.8M7.3 7.3L5.5 5.5"></path>',
    "popover": '<rect x="3" y="4.5" width="18" height="13" rx="2"></rect><path d="M3 9h18M10 17.5l2 3 2-3"></path>',
    "display": '<rect x="3" y="4" width="18" height="12" rx="2"></rect><path d="M9 20h6M12 16v4"></path>',
    "lockdisplay": '<rect x="3" y="4" width="18" height="12" rx="2"></rect><path d="M9 20h6M12 16v4"></path><rect x="9.5" y="9" width="5" height="4" rx="1" fill="currentColor" stroke="none"></rect><path d="M10.5 9V8a1.5 1.5 0 0 1 3 0v1"></path>',
    "lock": '<rect x="5" y="10.5" width="14" height="10" rx="2"></rect><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"></path>',
    "search": '<circle cx="10.5" cy="10.5" r="6"></circle><path d="M15.5 15.5L20 20"></path>',
    "reset": '<path d="M4 12a8 8 0 1 0 2.3-5.7"></path><path d="M4 4v5h5"></path>',
    "update": '<path d="M20 12a8 8 0 1 1-2.3-5.7"></path><path d="M20 4v5h-5"></path>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7"></path>',
    "warn": '<path d="M12 3.5L2.5 20h19z" fill="#FF9F0A" stroke="#FF9F0A"></path><path d="M12 9v5" stroke="#fff"></path><circle cx="12" cy="17" r=".9" fill="#fff" stroke="none"></circle>',
    "spark": '<path d="M12 3l1.9 5.6L19.5 10.5l-5.6 1.9L12 18l-1.9-5.6L4.5 10.5l5.6-1.9z"></path><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"></path>',
    "stack": '<path d="M12 3l9 4.5-9 4.5-9-4.5z"></path><path d="M3 12l9 4.5 9-4.5M3 16.5L12 21l9-4.5"></path>',
    "grid": '<rect x="4" y="4" width="6.5" height="6.5" rx="1.5"></rect><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.5"></rect><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.5"></rect><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.5"></rect>',
    "clock": '<circle cx="12" cy="12" r="8.5"></circle><path d="M12 7.5V12l3 2"></path>',
    "link": '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1.2 1.2"></path><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1.2-1.2"></path>',
    "question": '<path d="M9.5 9.5a2.5 2.5 0 1 1 3.6 2.2c-.8.4-1.1.9-1.1 1.8"></path><circle cx="12" cy="17" r=".9" fill="currentColor" stroke="none"></circle>',
    "info": '<circle cx="12" cy="12" r="8.5"></circle><path d="M12 11v5"></path><circle cx="12" cy="8" r=".9" fill="currentColor" stroke="none"></circle>',
    "infofill": '<circle cx="12" cy="12" r="9.5" fill="#fff" stroke="none"></circle><path d="M12 11v5.5" stroke="#8E8E93" stroke-width="2.2"></path><circle cx="12" cy="7.8" r="1.1" fill="#8E8E93" stroke="none"></circle>',
    "mail": '<rect x="3" y="5" width="18" height="14" rx="2"></rect><path d="M3 7l9 6 9-6"></path>',
    "doc": '<path d="M7 3h7l5 5v13H7z"></path><path d="M14 3v5h5M9.5 13h5M9.5 16.5h5"></path>',
    "globe": '<circle cx="12" cy="12" r="8.5"></circle><path d="M3.5 12h17M12 3.5c2.6 2.6 2.6 14.4 0 17M12 3.5c-2.6 2.6-2.6 14.4 0 17"></path>',
    "spade": '<path d="M12 3.5c-3 3.6-7 6.2-7 9.6a4 4 0 0 0 6.2 3.3L10 20h4l-1.2-3.6A4 4 0 0 0 19 13.1c0-3.4-4-6-7-9.6z" fill="currentColor" stroke="none"></path>',
    "happy": '<rect x="4" y="5" width="16" height="14" rx="4"></rect><circle cx="9.5" cy="11" r="1" fill="currentColor" stroke="none"></circle><circle cx="14.5" cy="11" r="1" fill="currentColor" stroke="none"></circle><path d="M9 14.5c1.6 1.4 4.4 1.4 6 0"></path><path d="M12 5V3"></path>',
    "arrow": '<path d="M7 17L17 7M9 7h8v8"></path>',
}
G = {  # filled glyphs for tile faces (SF-symbol-like)
    "folder": '<path d="M3 7.6a2 2 0 0 1 2-2h3.1l1.6 2H19a2 2 0 0 1 2 2v6.8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path>',
    "star": '<path d="M12 3.4l2.6 5.8 6.3.7-4.7 4.2 1.3 6.2L12 17.2l-5.5 3.1 1.3-6.2L3.1 9.9l6.3-.7z"></path>',
    "play": '<path d="M8 6.5v11l9-5.5z"></path>',
    "plus": '<path d="M11 5h2v6h6v2h-6v6h-2v-6H5v-2h6z"></path>',
    "globe": '<path d="M12 2.5a9.5 9.5 0 1 0 0 19 9.5 9.5 0 0 0 0-19zm0 2c1.1 0 2.4 2.8 2.7 6.5H9.3C9.6 7.3 10.9 4.5 12 4.5zm-3.4 1.2C7.9 7.1 7.5 9 7.3 11H4.6a7.6 7.6 0 0 1 4-5.3zM4.6 13h2.7c.2 2 .6 3.9 1.3 5.3a7.6 7.6 0 0 1-4-5.3zm4.7 0h5.4c-.3 3.7-1.6 6.5-2.7 6.5s-2.4-2.8-2.7-6.5zm6.1 5.3c.7-1.4 1.1-3.3 1.3-5.3h2.7a7.6 7.6 0 0 1-4 5.3zM16.7 11c-.2-2-.6-3.9-1.3-5.3a7.6 7.6 0 0 1 4 5.3z"></path>',
    "code": '<path d="M9.4 7.4L4.8 12l4.6 4.6 1.4-1.4L7.6 12l3.2-3.2zM14.6 7.4l-1.4 1.4 3.2 3.2-3.2 3.2 1.4 1.4 4.6-4.6z"></path>',
}

def tile(size, tint, glyph, glyph_ratio=0.5, extra_style=""):
    top, bot = TINT[tint]
    r = round(size * 0.225, 1)
    return (f'<div style="width:{size}px;height:{size}px;border-radius:{r}px;flex:none;'
            f'background:linear-gradient(180deg,{top},{bot});box-shadow:inset 0 0 0 .5px rgba(255,255,255,.5);'
            f'display:flex;align-items:center;justify-content:center;{extra_style}">{fsvg(G[glyph], round(size * glyph_ratio))}</div>')

def tile_placeholder(size):
    """Draft tile: grey squircle with a plus glyph (the 'not designed yet' placeholder)."""
    return tile(size, "gray", "plus", 0.55)

def app_letter(size, letter, c1, c2, fs=None):
    fs = fs or round(size * 0.36)
    return (f'<div style="width:{size}px;height:{size}px;border-radius:{round(size*0.225,1)}px;flex:none;background:linear-gradient(180deg,{c1},{c2});'
            f'box-shadow:inset 0 0 0 .5px rgba(255,255,255,.5);display:flex;align-items:center;justify-content:center;'
            f'color:#fff;font-weight:600;font-size:{fs}px;letter-spacing:-.3px">{letter}</div>')

def app_folder(size):
    return (f'<div style="width:{size}px;height:{size}px;flex:none;display:flex;align-items:center;justify-content:center">'
            f'<svg width="{size}" height="{size}" viewBox="0 0 24 24"><path d="M3 6.5a1.5 1.5 0 0 1 1.5-1.5h4.2l1.8 1.8H19.5A1.5 1.5 0 0 1 21 8.3v9.2a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5z" fill="#3F9BF0"></path>'
            f'<path d="M3 9.5h18v8a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5z" fill="#6FB8F7"></path></svg></div>')

def app_missing(size, glyph="question"):
    return (f'<div style="width:{size}px;height:{size}px;border-radius:{round(size*0.225,1)}px;flex:none;'
            f'border:1.5px dashed var(--dash);box-sizing:border-box;display:flex;align-items:center;justify-content:center;color:var(--popsub)">'
            f'{svg(P[glyph], round(size*0.45), sw=2.2)}</div>')

APPS = [  # placeholder app identities (letters stand in for real icons)
    ("Mail", "M", "#6EA8FF", "#2E5BFF"),
    ("Slack", "S", "#B197FC", "#7B4DE3"),
    ("Calendar", "C", "#FF8A8A", "#FF3B30"),
    ("Notes", "N", "#FFD666", "#FF9F0A"),
    ("Xcode", "X", "#4DABF7", "#007AFF"),
    ("Figma", "F", "#FF6482", "#FF2D55"),
    ("Terminal", "T", "#48484A", "#1C1C1E"),
    ("Finder", "Fi", "#5AC8FA", "#0A84FF"),
]

# ---------------------------------------------------------------- chrome
def traffic():
    return ('<div class="tl"><i style="background:#FF5F57"></i><i style="background:#FEBC2E"></i>'
            '<i style="background:#28C840"></i></div>')

TILES = [("Work", "blue", "folder"), ("Creative", "purple", "star"), ("Watch", "pink", "play")]

def squircle_icon(tint, icon_svg, size=24):
    top, bot = TINT[tint]
    return (f'<div style="width:{size}px;height:{size}px;border-radius:{round(size*0.225,1)}px;flex:none;background:linear-gradient(180deg,{top},{bot});'
            f'box-shadow:inset 0 0 0 .5px rgba(255,255,255,.5);display:flex;align-items:center;justify-content:center">{icon_svg}</div>')

def sidebar(selected, draft=True, empty=False, plus_disabled=False):
    rows = []
    if empty:
        rows.append(f'<div class="sbr {"sel" if selected=="empty" else ""}" style="color:var(--sec)"><span class="lbl">No tiles yet</span></div>')
    else:
        for name, tint, glyph in TILES:
            sel = "sel" if selected == name.lower() else ""
            rows.append(f'<div class="sbr {sel}">{tile(24, tint, glyph)}<span class="lbl">{name}</span></div>')
        if draft:
            sel = "sel" if selected == "draft" else ""
            rows.append(f'<div class="sbr {sel}">{tile_placeholder(24)}<span class="lbl">New Tile</span></div>')
    def srow(name, tint, icon):
        sel = "sel" if selected == name.lower() else ""
        return f'<div class="sbr {sel}">{squircle_icon(tint, icon)}<span class="lbl">{name}</span></div>'
    settings = (srow("General", "gray", svg(P["gear"], 13, "#fff", 2))
                + srow("Popover", "indigo", svg(P["popover"], 13, "#fff", 2))
                + srow("Dock Lock", "blue", svg(P["lockdisplay"], 13, "#fff", 1.9)))
    about = srow("About", "gray", svg(P["infofill"], 14, "none", 1))
    plus_style = "opacity:.35" if plus_disabled else ""
    return f'''
    <div class="sb">
      <div class="band">{traffic()}<div style="flex:1"></div><div class="ib" style="{plus_style}" title="Add a Tile">{svg(P["plus"], 15, "currentColor", 2)}</div></div>
      <div class="sbh">Tiles</div>
      <div style="display:flex;flex-direction:column;gap:2px">{"".join(rows)}</div>
      <div class="sbh" style="padding-top:16px">Settings</div>
      <div style="display:flex;flex-direction:column;gap:2px">{settings}</div>
      <div class="sbh" style="padding-top:16px">Dock Tile</div>
      <div style="display:flex;flex-direction:column;gap:2px">{about}</div>
    </div>'''

def header(title, trailing="", leading=""):
    """Title band. Settings panes keep their squircle (Klack-style); tile pages carry none — the
    hero icon right below would make it redundant."""
    return f'<div class="hdr">{leading}<span class="title">{title}</span><div style="flex:1"></div>{trailing}</div>'

def pane_header(tint, icon_svg, title, trailing=""):
    # 2026-08-30: no icon in the title band on any pane (removed from the canvas by Karthik).
    return header(title, trailing)

def window(sidebar_html, content_html, overlay=""):
    return f'<div class="stage"><div class="win">{sidebar_html}<div class="content">{content_html}</div>{overlay}</div></div>'

def doc(body_html, theme):
    vars_ = "".join(f"--{k}:{v};" for k, v in THEMES[theme].items())
    scheme = "dark" if theme == "dark" else "light"
    return f'''<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <style>:root{{{vars_}color-scheme:{scheme}}}{CSS}</style>
</helmet>
{body_html}
</x-dc>
</body>
</html>
'''

def switch(on=True):
    return f'<div class="sw {"" if on else "off"}"><i></i></div>'

def seg(options, on):
    return '<div class="seg">' + "".join(f'<span class="{"on" if o == on else ""}">{o}</span>' for o in options) + '</div>'

def popup(label, width=None):
    w = f"min-width:{width}px;" if width else ""
    return f'<div class="btn" style="{w}justify-content:space-between;gap:10px"><span>{label}</span><span style="color:var(--sec);display:flex">{svg(P["updown"], 11, "currentColor", 2.2)}</span></div>'

def row(left, right="", sub=None, first=False):
    sepx = "" if first else '<div class="sep"></div>'
    l = f'<div style="display:flex;flex-direction:column;gap:2px"><span>{left}</span><span class="sub">{sub}</span></div>' if sub else f'<span>{left}</span>'
    return f'{sepx}<div class="row">{l}<div style="flex:1"></div>{right}</div>'

def ic(paths, size, sw=1.8, tone="ic"):
    """A UI icon in a theme tone (wrapped so currentColor resolves to the token)."""
    return f'<span style="display:flex;color:var(--{tone})">{svg(paths, size, "currentColor", sw)}</span>'

# ---------------------------------------------------------------- popover preview (grid, Medium/Comfortable)
def grid_cell(icon_html, name, hover=False, missing=False, focus=False, remove_badge=False):
    bg = "var(--cellhov)" if hover else "transparent"
    ring = f"box-shadow:0 0 0 2px {ACCENT} inset;" if focus else ""
    badge = f'<div class="badge">{svg(P["xmark"], 9, "#fff", 3.4)}</div>' if remove_badge else ""
    nm_style = "color:var(--popsub)" if missing else ""
    cap = '<div style="font-size:10px;color:var(--popsub);margin-top:-3px">Not installed</div>' if missing else ""
    return f'<div class="cell" style="background:{bg};{ring}">{badge}{icon_html}<div class="nm" style="{nm_style}">{name}</div>{cap}</div>'

def preview_grid(cells, cols=5, title="Work", gap=14):
    return (f'<div class="pop"><div class="pophdr">{title}</div>'
            f'<div style="display:grid;grid-template-columns:repeat({cols}, minmax(0, 1fr));gap:{gap}px">{"".join(cells)}</div></div>')

def preview_list(items, title="Work"):
    rows = []
    for icon_html, name, hover in items:
        bg = "var(--cellhov)" if hover else "transparent"
        rows.append(f'<div style="display:flex;align-items:center;gap:9px;padding:4px 8px;border-radius:6px;background:{bg};min-height:28px">{icon_html}<span style="flex:1;font-size:13px">{name}</span></div>')
    return (f'<div class="pop" style="padding:0 6px 8px;width:236px;box-sizing:border-box"><div class="pophdr" style="justify-content:flex-start;padding:0 8px">{title}</div>'
            f'<div style="display:flex;flex-direction:column;gap:1px">{"".join(rows)}</div></div>')

# ---------------------------------------------------------------- screens
def action_button(kind):
    if kind == "add":     return f'<div class="btn prom">{svg(P["plus"], 11, "#fff", 2.6)}Add to Dock</div>'
    if kind == "update":  return f'<div class="btn prom">{svg(P["update"], 11, "#fff", 2.2)}Update</div>'
    if kind == "remove":  return '<div class="btn">Remove from Dock</div>'
    if kind == "done":    return '<div class="btn dis">Done</div>'
    if kind == "busy":    return ('<div class="btn prom" style="opacity:.75"><span style="width:11px;height:11px;border-radius:6px;border:2px solid rgba(255,255,255,.35);border-top-color:#fff;display:block"></span>Adding…</div>')
    return ""

def trash_button():
    return f'<div class="ib" title="Delete Tile">{svg(P["trash"], 15, "currentColor", 1.6)}</div>'

def banner_html():
    return (f'<div style="display:flex;align-items:flex-start;gap:10px;padding:10px 14px;border-radius:12px;background:var(--banner);box-shadow:inset 0 0 0 1px var(--bannerline)">'
            f'{svg(P["spark"], 14, ACCENT, 1.8)}<span class="sub" style="flex:1;color:var(--text);opacity:.75">Suggested from your recent apps. Rename it, restyle it and change the apps — nothing is in the Dock until you add it.</span>'
            f'{ic(P["xmark"], 10, 3, "sec")}</div>')

def tile_detail(name="Work", tint="blue", glyph="folder", draft=False, layout="grid"):
    hero_icon = tile_placeholder(96) if draft else tile(96, tint, glyph)
    hdr = header(name, trash_button() + action_button("add"))
    form = ('<div class="card" style="flex:1;min-width:0">'
            + row("Tile Name", f'<span style="font-size:13px">{name}</span>', first=True)
            + row("Show Tile", switch(True))
            + row("Show in App Switcher", switch(False))
            + '</div>')
    hero = (f'<div style="display:flex;align-items:center;gap:14px">'
            f'<div style="display:flex;flex-direction:column;align-items:center;gap:8px">{hero_icon}<div class="btn subtle" style="width:96px;box-sizing:border-box">Customise</div></div>{form}</div>')
    sec = (f'<div class="sec"><div style="display:flex;flex-direction:column;gap:1px"><span class="t">In This Tile</span><span class="ter">Hover to remove · Drag to reorder</span></div>'
           f'<div style="flex:1"></div>{seg(["Grid","List"], "Grid" if layout=="grid" else "List")}<div class="btn">{svg(P["plus"], 10, "currentColor", 2.6)}Add</div></div>')
    if draft:
        inner = (f'<div class="pop" style="width:250px;box-sizing:border-box"><div class="pophdr">{name}</div>'
                 f'<div style="display:flex;flex-direction:column;align-items:center;gap:9px;padding:10px 8px 14px">{app_missing(44, "plus")}'
                 f'<div style="font-size:12px;text-align:center;line-height:1.4;max-width:210px;opacity:.85">No apps yet. Use <strong>Add</strong> to choose what opens from this tile.</div></div></div>')
    elif layout == "grid":
        cells = [
            grid_cell(app_letter(56, *APPS[0][1:]), APPS[0][0]),
            grid_cell(app_letter(56, *APPS[1][1:]), APPS[1][0], hover=True, remove_badge=True),
            grid_cell(app_letter(56, *APPS[2][1:]), APPS[2][0]),
            grid_cell(app_letter(56, *APPS[3][1:]), APPS[3][0]),
            grid_cell(app_folder(56), "Projects"),
            grid_cell(app_missing(56), "Sketch", missing=True),
        ]
        inner = preview_grid(cells, cols=5, title=name)
    else:
        items = [(app_letter(24, *a[1:], fs=10), a[0], i == 1) for i, a in enumerate(APPS[:4])]
        items.append((app_folder(24), "Projects", False))
        inner = preview_list(items, title=name)
    body = f'<div class="body">{hero}<div style="display:flex;flex-direction:column;gap:8px">{sec}<div class="canvas">{inner}</div></div></div>'
    return hdr + body

def general():
    hdr = pane_header("gray", svg(P["gear"], 14, "#fff", 2), "General")
    # Software Update lives on About only (it used to repeat here).
    card1 = ('<div class="card">' + row("Start tiles at login", switch(True), first=True)
             + row("Missing Apps", '<div class="btn">Scan…</div>', sub="Check tiles for apps that moved or were uninstalled")
             + row("Share anonymous usage data", switch(True)) + '</div>')
    card2 = ('<div class="card">' + row("Suggest tiles from my apps", switch(True), sub="Learned on your Mac. Never leaves your device.", first=True)
             + row('<span style="color:#0A84FF">Add a Tile…</span>', "") + '</div>')
    body = (f'<div class="body">{card1}<div style="display:flex;flex-direction:column;gap:8px"><div class="sec"><span class="t">Adding Tiles</span></div>{card2}</div></div>')
    return hdr + body

def popover_pane(save_model):
    trailing = ""
    if save_model == "A":
        trailing = (f'<div class="btn" title="Reset to Defaults">{svg(P["reset"], 13, "currentColor", 2)}</div>'
                    f'<div class="btn prom">Save</div>')
    hdr = pane_header("indigo", svg(P["popover"], 14, "#fff", 2), "Popover", trailing)
    cells = [grid_cell(app_letter(56, *a[1:]), a[0]) for a in APPS[:5]]
    canvas = f'<div class="canvas" style="padding:16px 22px">{preview_grid(cells, cols=5)}</div>'
    sec = (f'<div class="sec"><div style="display:flex;flex-direction:column;gap:1px"><span class="t">Configure</span><span class="ter">Each layout is saved independently</span></div>'
           f'<div style="flex:1"></div>{seg(["Grid","List"], "Grid")}</div>')
    card = ('<div class="card">'
            + row("Popover Size", seg(["Small","Medium","Large"], "Medium"), first=True)
            + row("Tile Size", seg(["Small","Medium","Large"], "Medium"))
            + row("Animation", seg(["None","Default","Fast"], "Default"))
            + row("Spacing", seg(["Compact","Comfortable","Spacious"], "Comfortable"))
            + row("Show Labels", switch(True))
            + row("Highlight on Hover", switch(True))
            + '</div>')
    if save_model == "A":
        foot = '<div class="note" style="padding:0 4px">These settings apply to every tile\'s popover. List view always shows labels.</div>'
    else:
        foot = ('<div style="display:flex;align-items:flex-start;gap:12px;padding:0 4px"><div class="note" style="flex:1">These settings apply to every tile\'s popover and take effect the next time one opens. List view always shows labels.</div>'
                '<div class="btn">Reset to Defaults</div></div>')
    body = f'<div class="body" style="gap:14px">{canvas}<div style="display:flex;flex-direction:column;gap:8px">{sec}{card}</div>{foot}</div>'
    return hdr + body

def dock_lock():
    hdr = pane_header("blue", svg(P["lockdisplay"], 14, "#fff", 1.9), "Dock Lock")
    card1 = ('<div class="card">' + row("Lock Dock to one display", switch(True),
             sub="Stop the Dock from jumping between screens. It stays on the display you choose.", first=True) + '</div>')
    status = (f'<div class="row" style="min-height:36px">{svg(P["lock"], 13, "#30D158", 2.2)}<span class="sub" style="color:var(--text);opacity:.75">Dock is locked to Studio Display</span></div>')
    card2 = ('<div class="card">' + row("Keep Dock on", popup("Studio Display (Main)", 190), first=True)
             + '<div class="sep"></div>' + status + '</div>')
    foot = '<div class="note" style="padding:0 4px">Works with the Dock at the bottom, left, or right. Keeping it on a screen reserves a few pixels at that edge on your other displays.</div>'
    body = (f'<div class="body">{card1}<div style="display:flex;flex-direction:column;gap:8px"><div class="sec"><span class="t">Display</span></div>{card2}{foot}</div></div>')
    return hdr + body

def about():
    hdr = pane_header("gray", svg(P["infofill"], 16, "none", 1), "About")
    # Hero: the product in context — a Dock strip carrying three tiles, on the wallpaper canvas.
    dock = (f'<div class="dock">{tile(48, "blue", "folder")}{tile(48, "purple", "star")}{tile(48, "pink", "play")}'
            f'<div style="width:.5px;height:40px;background:var(--dockline);margin:0 2px"></div>{app_folder(48)}</div>')
    hero = f'<div class="canvas" style="padding:24px 22px">{dock}</div>'
    card1 = ('<div class="card">' + row("Dock Tile", '<div class="btn">Check for Updates…</div>', sub="Version 1.8.8", first=True)
             + row("Website", '<span style="color:#0A84FF">docktile.rkarthik.co</span>') + '</div>')
    card2 = (f'<div class="card"><div style="padding:11px 14px 9px;display:flex;flex-direction:column;gap:3px"><span>Found a bug or have an idea?</span>'
             f'<span class="sub">Feedback goes straight to the developer. Diagnostics attach a log of what the app and its tiles did — nothing personal.</span></div>'
             f'<div class="sep" style="margin:0"></div>'
             f'<div style="display:flex;gap:8px;padding:9px 14px 11px"><div class="btn" style="flex:1;justify-content:center">{ic(P["mail"], 12, 2, "text")}Send Feedback…</div>'
             f'<div class="btn" style="flex:1;justify-content:center">{ic(P["doc"], 12, 2, "text")}Copy Diagnostics</div></div></div>')
    # The studio plug: who makes this, and the sibling product — same row grammar as the rest of the pane.
    hm_mark = f'<div style="width:28px;height:28px;border-radius:7px;flex:none;background:linear-gradient(180deg,#FFD166,#F4A300);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.5);display:flex;align-items:center;justify-content:center;color:#3A2A00">{svg(P["happy"], 17, "currentColor", 1.8)}</div>'
    sp_mark = f'<div style="width:28px;height:28px;border-radius:7px;flex:none;background:linear-gradient(180deg,#3A3A3F,#141416);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.25);display:flex;align-items:center;justify-content:center;color:#fff">{svg(P["spade"], 16)}</div>'
    card3 = ('<div class="card">'
             + f'<div class="row" style="min-height:48px">{hm_mark}<div style="display:flex;flex-direction:column;gap:2px"><span>Made by Happy Machines Company</span><span class="sub">A tiny product studio building nifty Mac apps that each fix one thing well.</span></div><div style="flex:1"></div><span style="color:#0A84FF;white-space:nowrap">happymachines.company</span></div>'
             + '<div class="sep"></div>'
             + f'<div class="row" style="min-height:48px">{sp_mark}<div style="display:flex;flex-direction:column;gap:2px"><span>Spades Audio</span><span class="sub">Per-app volume, EQ and output control for your Mac, from the menu bar.</span></div><div style="flex:1"></div><div class="btn">Learn More…</div></div>'
             + '</div>')
    foot = '<div class="ter" style="padding:0 4px;text-align:center">© 2026 Happy Machines Company</div>'
    body = (f'<div class="body" style="gap:12px">{hero}{card1}{card2}'
            f'<div style="display:flex;flex-direction:column;gap:8px"><div class="sec"><span class="t">Also from Happy Machines</span></div>{card3}</div>{foot}</div>')
    return hdr + body

def empty_state():
    # One entry point: the Add a Tile dialog — its blank-first row is the New Tile path.
    hdr = '<div class="hdr"></div>'
    body = (f'<div class="body" style="align-items:center;justify-content:center;gap:10px">'
            f'{ic(P["stack"], 52, 1.4, "ter")}'
            f'<div style="font-size:17px;font-weight:600;margin-top:6px">Create your first tile</div>'
            f'<div style="font-size:13px;color:var(--sec);text-align:center;max-width:320px">Group apps and folders behind one Dock icon. Start blank, or from a tile suggested from the apps you use.</div>'
            f'<div class="btn prom" style="margin-top:8px">{svg(P["plus"], 11, "#fff", 2.6)}Add a Tile…</div></div>')
    return hdr + body

def suggestion_card(tint, glyph, name, reason_icon, reason, apps, plus=None, prominent=False, dashed=False, blank=False):
    if dashed:
        border = "box-shadow:inset 0 0 0 1.5px var(--dash);background:transparent;"
    else:
        border = "box-shadow:inset 0 0 0 .5px var(--sheetline);background:var(--sheetcard);"
    face = tile_placeholder(58) if blank else tile(58, tint, glyph, 0.5, extra_style="box-shadow:inset 0 0 0 .5px rgba(255,255,255,.5),0 3px 8px -2px rgba(0,0,0,.3)")
    if blank:
        middle = '<div class="chip">Start from scratch</div><div class="ter" style="height:22px;display:flex;align-items:center">Name, icon and apps are yours</div>'
        btn_label = "Create"
    else:
        members = "".join(app_letter(22, *a[1:], fs=9) for a in apps)
        if plus:
            members += f'<div style="width:22px;height:22px;border-radius:5px;background:var(--chip);display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:600;color:var(--sec)">+{plus}</div>'
        middle = f'<div class="chip">{reason_icon}{reason}</div><div style="display:flex;gap:5px">{members}</div>'
        btn_label = "Use This Tile"
    btn = f'<div class="btn {"prom" if prominent else ""}" style="width:100%;justify-content:center;box-sizing:border-box;margin-top:2px">{btn_label}</div>'
    return (f'<div style="flex:1;min-width:0;border-radius:11px;{border}padding:14px 10px;display:flex;flex-direction:column;align-items:center;gap:8px">'
            f'{face}<div style="font-size:13.5px;font-weight:600">{name}</div>{middle}{btn}</div>')

SUGGESTIONS = [
    ("blue", "globe", "Browse", "grid", "By category", APPS[:4], 2),
    ("pink", "play", "Watch", "clock", "Most used this week", APPS[4:8], None),
    ("indigo", "code", "Ship", "link", "Opened together", APPS[1:4], None),
]

def sheet_shell(width, body_html, footer_html):
    """The locked sheet chrome: title + close only (no badge, no subtitle) — the blank-first row carries the explanation."""
    return (f'<div style="position:absolute;inset:0;z-index:5"><div style="position:absolute;inset:0;background:var(--dim)"></div>'
            f'<div style="position:absolute;inset:0;display:flex;align-items:flex-start;justify-content:center;padding-top:28px">'
            f'<div style="width:{width}px;background:var(--sheet);border-radius:12px;box-shadow:0 22px 60px -12px rgba(0,0,0,.5),inset 0 0 0 .5px var(--sheetline);overflow:hidden">'
            f'<div style="display:flex;align-items:center;gap:12px;padding:14px 18px 12px"><div style="font-size:15px;font-weight:700;flex:1">Add a Tile</div>'
            f'<div style="width:22px;height:22px;border-radius:11px;background:var(--chip);display:flex;align-items:center;justify-content:center">{ic(P["xmark"], 10, 3, "sec")}</div></div>'
            f'<div class="sep" style="margin:0"></div>{body_html}<div class="sep" style="margin:0"></div>{footer_html}</div></div></div>')

def privacy(extra=""):
    return (f'<div style="display:flex;align-items:center;gap:8px;padding:11px 18px">{ic(P["lock"], 11, 2, "ter")}<span class="ter">Learned on your Mac. Never leaves your device.</span><div style="flex:1"></div>{extra}</div>')

def blank_row():
    return (f'<div style="display:flex;align-items:center;gap:12px;padding:14px 18px">{tile_placeholder(44)}'
            f'<div style="display:flex;flex-direction:column;gap:2px;flex:1"><span style="font-weight:600">Create a blank tile</span><span class="sub">Name it, pick an icon and add apps yourself.</span></div>'
            f'<div class="btn prom">{svg(P["plus"], 11, "#fff", 2.6)}Create New Tile</div></div>')

def add_tile_sheet():
    """Locked design (B, blank first): the blank row on top, then the suggestions under an 'or' rule."""
    rule = (f'<div style="display:flex;align-items:center;gap:10px;padding:2px 18px 10px"><div style="flex:1;height:.5px;background:var(--sep)"></div>'
            f'<span class="ter">or start from what you use</span><div style="flex:1;height:.5px;background:var(--sep)"></div></div>')
    cards = "".join(suggestion_card(t, g, n, svg(P[i], 9, "currentColor", 2), r, a, plus=p) for t, g, n, i, r, a, p in SUGGESTIONS)
    body = f'{blank_row()}{rule}<div style="display:flex;gap:12px;padding:0 18px 16px">{cards}</div>'
    return tile_detail(), sheet_shell(588, body, privacy())

def add_tile_sheet_empty():
    """Same sheet when the engine has nothing to suggest (Smart Add off, or nothing learned yet)."""
    note = (f'<div style="display:flex;align-items:center;gap:8px;padding:0 18px 14px">{ic(P["spark"], 12, 1.8, "ter")}'
            f'<span class="ter">No suggestions yet — Dock Tile learns from the apps you open. You can turn this off in General.</span></div>')
    return f'<div style="width:588px;background:var(--sheet);border-radius:12px;box-shadow:inset 0 0 0 .5px var(--sheetline);overflow:hidden">' \
           f'<div style="display:flex;align-items:center;gap:12px;padding:14px 18px 12px"><div style="font-size:15px;font-weight:700;flex:1">Add a Tile</div>' \
           f'<div style="width:22px;height:22px;border-radius:11px;background:var(--chip);display:flex;align-items:center;justify-content:center">{ic(P["xmark"], 10, 3, "sec")}</div></div>' \
           f'<div class="sep" style="margin:0"></div>{blank_row()}{note}</div>'

def states_sheet():
    def label(t): return f'<div style="font-size:11px;font-weight:700;color:var(--sec);letter-spacing:.2px">{t}</div>'
    def cap(t): return f'<div class="ter" style="text-align:center;max-width:120px">{t}</div>'
    def col(html, c): return f'<div style="display:flex;flex-direction:column;align-items:center;gap:6px">{html}{cap(c)}</div>'
    btns = (f'<div style="display:flex;gap:22px;align-items:flex-start">'
            + col(action_button("add"), "visible · not pinned")
            + col(action_button("update"), "visible · pinned (re-renders helper)")
            + col(action_button("remove"), "hidden · still pinned")
            + col(action_button("done"), "hidden · not pinned · disabled until edited")
            + col(action_button("busy"), "in progress · spinner inside")
            + '</div>')
    cells = (f'<div class="pop" style="padding:8px 10px 10px"><div style="display:grid;grid-template-columns:repeat(5, minmax(0, 1fr));gap:12px">'
             + grid_cell(app_letter(56, *APPS[0][1:]), "Mail")
             + grid_cell(app_letter(56, *APPS[1][1:]), "Slack", hover=True, remove_badge=True)
             + grid_cell(app_letter(56, *APPS[2][1:]), "Calendar", focus=True)
             + grid_cell(app_folder(56), "Projects")
             + grid_cell(app_missing(56), "Sketch", missing=True)
             + '</div></div>')
    cellcaps = ('<div style="display:grid;grid-template-columns:repeat(5, minmax(0, 1fr));gap:12px;width:412px;margin-left:10px">'
                + "".join(cap(t) for t in ["default", "hover → remove badge", "keyboard focus (Delete removes)", "folder item", "missing app — Remove / Keep only via alert"]) + '</div>')
    dl = ('<div class="card">'
          + f'<div class="row" style="min-height:44px">{svg(P["warn"], 16, "none", 1)}<div style="display:flex;flex-direction:column;gap:2px"><span style="font-weight:500">Accessibility access required</span><span class="sub">Dock Tile needs Accessibility access to keep the Dock in place.</span></div><div style="flex:1"></div><div class="btn">Continue</div><div class="btn">Open System Settings…</div></div>'
          + '<div class="sep"></div>'
          + f'<div class="row">{ic(P["display"], 15, 1.8, "sec")}<span class="sub">Connect a second display to use Dock Lock. With one screen the Dock stays exactly where macOS puts it.</span></div>'
          + '<div class="sep"></div>'
          + '<div class="row"><span style="width:13px;height:13px;border-radius:7px;border:2px solid var(--hair);border-top-color:var(--sec);display:block"></span><span class="sub">Moving Dock to Studio Display…</span></div>'
          + '<div class="sep"></div>'
          + f'<div class="row">{svg(P["warn"].replace("#FF9F0A","#FF453A"), 15, "none", 1)}<span class="sub" style="flex:1">Couldn\'t move the Dock to Studio Display. Make sure that display isn\'t mirrored, then try again.</span><div class="btn">Try Again</div></div>'
          + '</div>')
    gen = ('<div class="card">' + row("Start tiles at login", switch(True), first=True)
           + f'<div class="sep"></div><div class="row" style="min-height:34px"><span class="sub">Approve Dock Tile in Login Items to finish enabling this.</span><div style="flex:1"></div><div class="btn" style="height:20px;font-size:11px">Open Login Items…</div></div></div>')
    body = (f'<div style="width:768px;height:1040px;box-sizing:border-box;padding:24px 28px;background:var(--bg);border-radius:11px;box-shadow:var(--winsh);display:flex;flex-direction:column;gap:22px">'
            f'{label("HEADER ACTION — resolveDockAction states")}{btns}'
            f'{label("PREVIEW EDITOR — cell states")}<div style="display:flex;flex-direction:column;gap:8px">{cells}{cellcaps}</div>'
            f'{label("DOCK LOCK — conditional rows")}{dl}'
            f'{label("GENERAL — login item held for approval")}{gen}'
            f'{label("TILE DETAIL — Smart Add provenance banner")}{banner_html()}'
            f'{label("ADD A TILE — no suggestions yet (Smart Add off, or nothing learned)")}{add_tile_sheet_empty()}</div>')
    return f'<div class="stage">{body}</div>'

# ---------------------------------------------------------------- emit
def screens():
    base, sheet = add_tile_sheet()
    return {
        "Main":         window(sidebar("work"), tile_detail()),
        "TileList":     window(sidebar("work"), tile_detail(layout="list")),
        "TileDraft":    window(sidebar("draft", plus_disabled=True), tile_detail("New Tile", draft=True)),
        "EmptyState":   window(sidebar("empty", empty=True), empty_state()),
        "AddTileSheet": window(sidebar("work"), base, overlay=sheet),
        "General":      window(sidebar("general"), general()),
        "Popover":      window(sidebar("popover"), popover_pane("A")),
        "DockLock":     window(sidebar("dock lock"), dock_lock()),
        "About":        window(sidebar("about"), about()),
        "States":       states_sheet(),
    }

TITLES = {
    "Main": "Tile Detail — Grid", "TileList": "Tile Detail — List", "TileDraft": "Tile Detail — New Tile draft",
    "EmptyState": "Zero tiles", "AddTileSheet": "Add a Tile",
    "General": "Settings — General", "Popover": "Settings — Popover", "DockLock": "Settings — Dock Lock", "About": "About",
    "States": "States sheet",
}
GRID = [  # (name, col, row)
    ("Main", 0, 0), ("TileList", 1, 0), ("TileDraft", 2, 0), ("EmptyState", 3, 0),
    ("AddTileSheet", 0, 1), ("General", 1, 1), ("Popover", 2, 1), ("DockLock", 3, 1),
    ("About", 0, 2), ("States", 1, 2),
]
W, H, GX, GY = 816, 690, 80, 320
NOTE_DY = H + 28
def pos(col, rowi): return {"x": col * (W + GX), "y": rowi * (H + GY)}

artboards, count = [], 0
for theme, suffix, page in (("light", "", "light"), ("dark", "Dark", "dark")):
    html_by_name = screens()
    for name, col, rowi in GRID:
        fname = f"{name}{suffix}.dc.html"
        with open(os.path.join(OUT, fname), "w") as f:
            f.write(doc(html_by_name[name], theme))
        count += 1
        artboards.append({"file": fname, "title": TITLES[name] + (" — dark" if suffix else ""),
                          "w": W, "h": 1090 if name == "States" else H, "page": page, **pos(col, rowi)})

def note(id_, col, rowi, text, w=760, page="light", h_override=None):
    y = rowi * (H + GY) + ((h_override or H) + 28)
    return {"id": id_, "x": col * (W + GX), "y": y, "w": w, "text": text, "page": page}

canvas = {
    "pages": [{"id": "light", "name": "Light"}, {"id": "dark", "name": "Dark"}],
    "artboards": artboards,
    "annotations": [
        {"id": "surface", "x": 0, "y": -290, "w": 760, "page": "light",
         "text": "Surface: Klack's one-tone window + grouped white cards, native macOS sizing everywhere else — 13pt sidebar rows, 24pt icons, 40pt form rows, 12pt card radius, system blue, SF Pro. The page header lives in the 52pt title band and carries no icon on any pane. Customise Tile stays as it is in the app today and is not on this canvas."},
        note("gaps-main", 0, 0, "Gap fixes visible here: the app list is the live popover preview and the editor (hover → remove badge, drag to reorder); a FOLDER item and a MISSING app render the way the real popover draws them; Layout moved to the section header as Grid/List; delete is the header trash (the old bottom card was mislabelled 'Remove from Dock')."),
        note("draft", 2, 0, "New Tile draft: grey + placeholder icon until the user picks one; sidebar + is disabled while an unedited draft is selected (canCreateNewTile). Action reads 'Add to Dock' because a draft is visible-but-unpinned."),
        note("empty", 3, 0, "Zero tiles: one entry point, Add a Tile… — it opens the dialog, whose blank-first row is the New Tile path. The sidebar + stays enabled."),
        note("sheet", 0, 1, "LOCKED: Add a Tile, blank first. Header is title + close only. Rule: every Add/New entry point (sidebar +, the General row, the zero-tiles button) opens this dialog — even when there is nothing to suggest (see the no-suggestions state on the States sheet). ⌘N New Dock Tile stays the direct blank shortcut for keyboard users; confirm if you'd rather it open the dialog too."),
        note("popover", 2, 1, "Option A chosen: explicit Save (⌘S) + icon-only Reset in the title band, draft/dirty behaviour as today, then the one-time 'Apply to your Dock tiles?' prompt after Save."),
        note("docklock", 3, 1, "The reference's Dock Lock copy described a feature that doesn't exist. This is the real one — lock to a display, Accessibility permission, Keep Dock on picker, status. Conditional rows are on the States sheet."),
        note("about", 0, 2, "About moves into the sidebar (Klack-style 'Dock Tile' section) and is the only home of Software Update (removed from General). Rows: version + Check for Updates…, website; feedback with Send Feedback… and Copy Diagnostics; 'Also from Happy Machines' — the studio line + Spades Audio. Marks are placeholders for the real logos; copyright placeholder for NSHumanReadableCopyright."),
        note("states", 1, 2, "Everything the main frames have no state for: the four resolveDockAction button variants + busy; preview cell states incl. keyboard focus; Dock Lock permission / single-display / moving / failed rows; login held for approval; Smart Add banner; the Add a Tile dialog with nothing to suggest.", h_override=1090),
        {"id": "dark-tokens", "x": 0, "y": -290, "w": 760, "page": "dark",
         "text": "Dark mode, Klack-style charcoal rather than pure-black: sidebar #2C2C2E, window #323234, cards #3C3C3F with a 9% white hairline, text 92% white, secondary 55%, sidebar selection 11% white, buttons #525255. Accent stays system blue; tile faces, app icons and the wallpaper canvas keep their colour (canvas darkened). In the app these are system colours, so it follows the appearance for free."},
    ],
    "launch": {"view": "canvas", "page": "light"},
}
with open(os.path.join(OUT, "canvas.json"), "w") as f:
    json.dump(canvas, f, indent=2, ensure_ascii=False)
print("wrote", count, "artboards + canvas.json to", OUT)
