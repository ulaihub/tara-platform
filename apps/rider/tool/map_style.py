"""Génère les styles MapLibre de l'app livreur (assets/map/tara-{dark,light}.json).

Schéma de tuiles OpenMapTiles (tuiles Tara auto-hébergées, ou OpenFreeMap en développement).
Priorité au terrain : noms de rues, quartiers, commerces et lieux utiles, numéros, et zones
interdites aux motos bien visibles. `{{TILES_URL}}` et `{{GLYPHS_URL}}` sont remplacés par
l'app au chargement.

    python3 tool/map_style.py
"""
import json
import pathlib

FONT = ["Noto Sans Regular"]
FONT_BOLD = ["Noto Sans Bold"]

THEMES = {
    "dark": {
        "ground": "#11131A", "residential": "#151821", "park": "#14261F", "water": "#0E2433",
        "waterLabel": "#6FA3C7", "building": "#1E222D", "buildingLine": "#262B38",
        "major": "#5A6378", "majorCase": "#11131A", "secondary": "#454D60", "minor": "#323847",
        "path": "#3A4152", "rail": "#3A3F4D", "text": "#E8EAF0", "textMuted": "#A9AFBD",
        "halo": "#0B0D12", "place": "#FFFFFF", "neighbourhood": "#FFC283",
        "shop": "#FF8A3D", "food": "#FFB000", "health": "#FF5A66", "money": "#4FA3FF",
        "fuel": "#C792EA", "school": "#7FD4A0", "worship": "#B9B9C9", "transport": "#5FC9D8",
        "house": "#7F8798",
    },
    "light": {
        "ground": "#F3EFE9", "residential": "#EEE9E2", "park": "#DCEBD8", "water": "#B9D7E6",
        "waterLabel": "#2F6B8F", "building": "#E3DCD2", "buildingLine": "#D3CABE",
        "major": "#FFFFFF", "majorCase": "#C9BEB0", "secondary": "#FFFFFF", "minor": "#FFFFFF",
        "path": "#CFC6BA", "rail": "#B9AFA2", "text": "#1F1A15", "textMuted": "#5E554C",
        "halo": "#FFFFFF", "place": "#16120E", "neighbourhood": "#9A3412",
        "shop": "#E8590C", "food": "#C77700", "health": "#D6202E", "money": "#1D6FD8",
        "fuel": "#8E44AD", "school": "#1E8E5A", "worship": "#6B6B7B", "transport": "#0E8FA3",
        "house": "#7D7368",
    },
}

def interp(*stops):
    return ["interpolate", ["exponential", 1.5], ["zoom"], *[v for pair in stops for v in pair]]

def road_filter(classes):
    return ["all", ["==", ["geometry-type"], "LineString"], ["in", ["get", "class"], ["literal", classes]]]

POI_GROUPS = [
    ("shop", ["shop", "grocery", "clothing_store", "hardware", "furniture", "electronics", "mobile_phone",
              "jewelry", "florist", "bakery", "butcher", "beer", "alcohol_shop", "convenience", "marketplace",
              "supermarket", "department_store", "car", "bicycle", "laundry", "hairdresser", "optician"]),
    ("food", ["restaurant", "fast_food", "cafe", "bar", "pub", "ice_cream", "food_court"]),
    ("health", ["hospital", "pharmacy", "doctors", "dentist", "clinic", "veterinary"]),
    ("money", ["bank", "atm", "money_transfer", "post", "bureau_de_change"]),
    ("fuel", ["fuel", "car_repair", "parking"]),
    ("school", ["school", "college", "university", "kindergarten", "library"]),
    ("worship", ["place_of_worship", "religion"]),
    ("transport", ["bus", "railway", "ferry_terminal", "airport", "harbor"]),
]

def style(name, t):
    layers = [
        {"id": "background", "type": "background", "paint": {"background-color": t["ground"]}},
        {"id": "landuse-residential", "type": "fill", "source": "openmaptiles", "source-layer": "landuse",
         "filter": ["in", ["get", "class"], ["literal", ["residential", "suburb", "neighbourhood"]]],
         "paint": {"fill-color": t["residential"]}},
        {"id": "park", "type": "fill", "source": "openmaptiles", "source-layer": "landcover",
         "filter": ["in", ["get", "class"], ["literal", ["grass", "wood", "wetland"]]],
         "paint": {"fill-color": t["park"], "fill-opacity": 0.8}},
        {"id": "water", "type": "fill", "source": "openmaptiles", "source-layer": "water",
         "paint": {"fill-color": t["water"]}},
        {"id": "waterway", "type": "line", "source": "openmaptiles", "source-layer": "waterway",
         "paint": {"line-color": t["water"], "line-width": interp((10, 1), (17, 6))}},
        {"id": "building", "type": "fill", "source": "openmaptiles", "source-layer": "building", "minzoom": 14,
         "paint": {"fill-color": t["building"], "fill-outline-color": t["buildingLine"]}},
        {"id": "rail", "type": "line", "source": "openmaptiles", "source-layer": "transportation",
         "filter": road_filter(["rail", "transit"]),
         "paint": {"line-color": t["rail"], "line-width": 1.5, "line-dasharray": [3, 3]}},
        {"id": "path", "type": "line", "source": "openmaptiles", "source-layer": "transportation", "minzoom": 14,
         "filter": road_filter(["path", "track"]),
         "paint": {"line-color": t["path"], "line-width": interp((14, 1), (18, 3)), "line-dasharray": [2, 1.5]}},
    ]
    # Routes : bordure puis remplissage, des petites aux grandes (les grandes passent dessus).
    roads = [
        ("minor", ["minor", "service", "living_street", "residential"], t["minor"], (13, 0.8), (18, 14)),
        ("secondary", ["secondary", "tertiary"], t["secondary"], (10, 1), (18, 20)),
        ("major", ["motorway", "trunk", "primary"], t["major"], (8, 1.2), (18, 26)),
    ]
    for rid, classes, color, low, high in roads:
        layers.append({"id": f"road-{rid}-case", "type": "line", "source": "openmaptiles",
                       "source-layer": "transportation", "filter": road_filter(classes),
                       "layout": {"line-cap": "round", "line-join": "round"},
                       "paint": {"line-color": t["majorCase"], "line-width": interp((low[0], low[1] + 1), (high[0], high[1] + 3))}})
        layers.append({"id": f"road-{rid}", "type": "line", "source": "openmaptiles",
                       "source-layer": "transportation", "filter": road_filter(classes),
                       "layout": {"line-cap": "round", "line-join": "round"},
                       "paint": {"line-color": color, "line-width": interp(low, high)}})
    # Zones Tara : remplies par l'app (source GeoJSON « tara-zones »).
    layers += [
        {"id": "tara-service-area", "type": "line", "source": "tara-zones",
         "filter": ["==", ["get", "kind"], "SERVICE_AREA"],
         "paint": {"line-color": "#FF8A3D", "line-width": 2, "line-opacity": 0.6, "line-dasharray": [4, 3]}},
        {"id": "tara-no-moto-fill", "type": "fill", "source": "tara-zones",
         "filter": ["==", ["get", "kind"], "NO_MOTORBIKE"],
         "paint": {"fill-color": "#E52535", "fill-opacity": 0.22 if name == "dark" else 0.16}},
        {"id": "tara-no-moto-line", "type": "line", "source": "tara-zones",
         "filter": ["==", ["get", "kind"], "NO_MOTORBIKE"],
         "paint": {"line-color": "#FF4D5A" if name == "dark" else "#C81E2C", "line-width": 2.5, "line-dasharray": [2, 1.5]}},
    ]
    # Textes : rues, numéros, lieux, quartiers.
    text = lambda size, color=t["text"], halo=1.6: {"text-color": color, "text-halo-color": t["halo"], "text-halo-width": halo}
    layers += [
        {"id": "road-name-minor", "type": "symbol", "source": "openmaptiles", "source-layer": "transportation_name",
         "minzoom": 15, "filter": ["in", ["get", "class"], ["literal", ["minor", "service", "residential", "tertiary"]]],
         "layout": {"symbol-placement": "line", "text-field": ["get", "name"], "text-font": FONT,
                    "text-size": interp((15, 11), (18, 14))}, "paint": text(11, t["textMuted"])},
        {"id": "road-name-major", "type": "symbol", "source": "openmaptiles", "source-layer": "transportation_name",
         "minzoom": 12, "filter": ["in", ["get", "class"], ["literal", ["motorway", "trunk", "primary", "secondary"]]],
         "layout": {"symbol-placement": "line", "text-field": ["get", "name"], "text-font": FONT_BOLD,
                    "text-size": interp((12, 11), (18, 15))}, "paint": text(12)},
        {"id": "water-name", "type": "symbol", "source": "openmaptiles", "source-layer": "water_name",
         "layout": {"text-field": ["get", "name"], "text-font": ["Noto Sans Italic"], "text-size": 13},
         "paint": text(13, t["waterLabel"])},
        {"id": "housenumber", "type": "symbol", "source": "openmaptiles", "source-layer": "housenumber",
         "minzoom": 17, "layout": {"text-field": ["get", "housenumber"], "text-font": FONT, "text-size": 10},
         "paint": text(10, t["house"], 1.2)},
        {"id": "tara-no-moto-label", "type": "symbol", "source": "tara-zones", "minzoom": 13,
         "filter": ["==", ["get", "kind"], "NO_MOTORBIKE"],
         "layout": {"text-field": ["get", "label"], "text-font": FONT_BOLD, "text-size": 12, "symbol-placement": "point"},
         "paint": text(12, "#FF4D5A" if name == "dark" else "#B3121F")},
    ]
    # Commerces et lieux : point coloré par famille dès z15, nom dès z16.
    for group, classes in POI_GROUPS:
        poi_filter = ["in", ["get", "class"], ["literal", classes]]
        layers.append({"id": f"poi-{group}-dot", "type": "circle", "source": "openmaptiles", "source-layer": "poi",
                       "minzoom": 15, "filter": poi_filter,
                       "paint": {"circle-color": t[group], "circle-radius": interp((15, 3), (18, 6)),
                                 "circle-stroke-color": t["halo"], "circle-stroke-width": 1.2}})
        layers.append({"id": f"poi-{group}-name", "type": "symbol", "source": "openmaptiles", "source-layer": "poi",
                       "minzoom": 16, "filter": poi_filter,
                       "layout": {"text-field": ["get", "name"], "text-font": FONT, "text-size": 11,
                                  "text-anchor": "left", "text-offset": [0.7, 0], "text-max-width": 9,
                                  "text-optional": True},
                       "paint": text(11, t[group], 1.4)})
    layers += [
        {"id": "place-neighbourhood", "type": "symbol", "source": "openmaptiles", "source-layer": "place",
         "minzoom": 12, "maxzoom": 17, "filter": ["in", ["get", "class"], ["literal", ["suburb", "neighbourhood", "quarter"]]],
         "layout": {"text-field": ["get", "name"], "text-font": FONT_BOLD, "text-transform": "uppercase",
                    "text-letter-spacing": 0.08, "text-size": interp((12, 11), (16, 14))},
         "paint": text(12, t["neighbourhood"], 1.8)},
        {"id": "place-city", "type": "symbol", "source": "openmaptiles", "source-layer": "place",
         "maxzoom": 13, "filter": ["in", ["get", "class"], ["literal", ["city", "town"]]],
         "layout": {"text-field": ["get", "name"], "text-font": FONT_BOLD, "text-size": interp((8, 13), (13, 20))},
         "paint": text(16, t["place"], 2)},
    ]
    # Position du livreur, au-dessus de tout : halo puis point (mise à jour par l'app).
    layers += [
        {"id": "tara-rider-halo", "type": "circle", "source": "tara-rider",
         "paint": {"circle-color": "#FF6A00", "circle-opacity": 0.22, "circle-radius": 22}},
        {"id": "tara-rider-dot", "type": "circle", "source": "tara-rider",
         "paint": {"circle-color": "#FF6A00", "circle-radius": 8,
                   "circle-stroke-color": "#FFFFFF", "circle-stroke-width": 3}},
    ]
    return {
        "version": 8,
        "name": f"Tara {name}",
        "glyphs": "{{GLYPHS_URL}}",
        "sources": {
            "openmaptiles": {"type": "vector", "url": "{{TILES_URL}}",
                             "attribution": "© OpenStreetMap contributors · OpenMapTiles"},
            "tara-zones": {"type": "geojson", "data": {"type": "FeatureCollection", "features": []}},
            "tara-rider": {"type": "geojson", "data": {"type": "FeatureCollection", "features": []}},
        },
        "layers": layers,
    }

out = pathlib.Path(__file__).resolve().parent.parent / "assets" / "map"
out.mkdir(parents=True, exist_ok=True)
for name, theme in THEMES.items():
    (out / f"tara-{name}.json").write_text(json.dumps(style(name, theme), ensure_ascii=False, separators=(",", ":")) + "\n")
    print("écrit", out / f"tara-{name}.json")
