#!/usr/bin/env python3
"""
Construit une sauvegarde TTS « X-Wing United (dev) » à partir du mod Workshop
X-Wing Unified (2486128992) et des sources de ce dépôt.

Le mod d'origine n'est jamais modifié : le script le lit, remplace dans les
scripts embarqués (« bundles » luabundle) les modules listés ci-dessous par
les fichiers de TTS_xwing/src, ajoute les nouveaux modules, met à jour l'UI
XML du vaisseau modèle, puis écrit une NOUVELLE sauvegarde dans Saves/.

Avant cela, les données X-Wing United (ships, pilots, upgrades, leaders,
chassis) sont téléchargées depuis GitHub (lecture seule), décodées ici et
converties en module Lua (UnitedDataEmbedded.lua) intégré au mod : TTS n'a
plus de JSON à décoder au chargement.

Usage :  python3 tools/build_save.py            (données à jour depuis GitHub)
         python3 tools/build_save.py --local    (données du dossier ./xwunited)
Ensuite, dans TTS : Créer > Sauvegardes > « X-Wing United (dev) »
(ou recharger la partie si elle est déjà ouverte).
"""

import datetime
import json
import os
import re
import sys
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "TTS_xwing", "src")

TTS_DIR = os.path.expanduser("~/snap/steam/common/.local/share/Tabletop Simulator")
WORKSHOP_SAVE = os.path.join(TTS_DIR, "Mods", "Workshop", "2486128992.json")
OUTPUT_SAVE = os.path.join(TTS_DIR, "Saves", "XWing_United_dev.json")
SAVE_NAME = "X-Wing United (dev)"

DATA_URL = "https://raw.githubusercontent.com/Immelman51/xwunited/main/{}.json"
DATA_LOCAL_DIR = os.path.join(REPO, "xwunited")
DATA_MODULE = os.path.join(SRC, "Game", "Component", "Spawner", "United", "UnitedDataEmbedded.lua")

# Champs conservés (les autres ne servent pas au mod). Les champs dont le nom
# commence par un des préfixes sont aussi gardés (versions FRA / ENG).
DATA_FIELDS = {
    "ships": (["name", "id", "chassis", "attack", "agility", "hull", "shields", "actions", "maneuvers", "base"], []),
    "pilots": (["id", "faction", "ship", "shipId", "skill", "points", "charge", "force", "max_per_squad"],
               ["name", "ability"]),
    "upgrades": (["id", "slot", "charge", "force", "add_Data"], ["name", "effect"]),
    "leaders": (["leaderid", "leaderfaction", "charge", "logistic"], ["leadername", "leaderability"]),
    "chassis": (["id"], ["name", "effect"]),
}

# Modules à injecter : nom du module -> GUID de l'objet qui le porte
# ("Global" pour le script global). Les modules absents du bundle y sont
# ajoutés, les autres sont remplacés.
MODULES = {
    "Global": [
        "Game.Component.Spawner.Spawner",
        "Game.Component.Spawner.United.UnitedFicheScript",
    ],
    "a4dbbf": [  # DataPad
        "Game.Component.Spawner.DataPad",
        "Game.Component.Spawner.United.UnitedMapping",
        "Game.Component.Spawner.United.UnitedData",
        "Game.Component.Spawner.United.UnitedSquad",
        "Game.Component.Spawner.United.UnitedDataEmbedded",
    ],
    "8c3322": [  # vaisseau modèle (CompositeBase)
        "Ship.CompositeBase",
    ],
    "251205": [  # carte de manœuvres
        "Game.Mechanic.Movement.ManeuverCard",
    ],
}

# Fichiers XML inclus (<!-- include X --> ... <!-- include X -->)
XML_INCLUDES = {
    "8c3322": ["Ship/CompositeBase.xml"],
}

# Fichiers XML ajoutés à la fin de l'UI globale (absents du mod d'origine)
GLOBAL_XML_APPENDS = [
    "Game/Component/Spawner/United/UnitedDetail.xml",
]

HEADER = 'function(require, _LOADED, __bundle_register, __bundle_modules)\n'
REGISTER = re.compile(
    r'__bundle_register\("(?P<name>[^"]+)", function\(require, _LOADED, __bundle_register, __bundle_modules\)\n'
    r'(?P<body>.*?)\nend\)\n(?=__bundle_register\(|return __bundle_require)',
    re.S,
)


def read_source(module):
    path = os.path.join(SRC, *module.split(".")) + ".lua"
    if not os.path.exists(path):
        sys.exit(f"Fichier source introuvable pour {module} : {path}")
    with open(path, encoding="utf-8") as f:
        return f.read().replace("\r\n", "\n").rstrip("\n")


def register_block(module, body):
    return f'__bundle_register("{module}", {HEADER}{body}\nend)\n'


def patch_bundle(script, modules, label):
    if "Bundled by luabundle" not in script:
        sys.exit(f"{label} : le script n'est pas un bundle luabundle, abandon.")
    existing = {m.group("name"): m for m in REGISTER.finditer(script)}
    for module in modules:
        body = read_source(module)
        if module in existing:
            match = existing[module]
            # Remplacement par position (pas de re.sub : le code contient des \)
            start, end = match.span()
            script = script[:start] + register_block(module, body) + script[end:]
            existing = {m.group("name"): m for m in REGISTER.finditer(script)}
            print(f"  {label} : module remplacé  {module}")
        else:
            anchor = script.rfind("return __bundle_require(")
            if anchor < 0:
                sys.exit(f"{label} : fin de bundle introuvable.")
            script = script[:anchor] + register_block(module, body) + script[anchor:]
            existing = {m.group("name"): m for m in REGISTER.finditer(script)}
            print(f"  {label} : module ajouté    {module}")
    return script


def patch_xml(xml, includes, label):
    for include in includes:
        marker = f"<!-- include {include} -->"
        first = xml.find(marker)
        second = xml.find(marker, first + len(marker))
        if first < 0 or second < 0:
            sys.exit(f"{label} : balises d'inclusion {include} introuvables.")
        with open(os.path.join(SRC, *include.split("/")), encoding="utf-8") as f:
            content = f.read().replace("\r\n", "\n").strip("\n")
        xml = xml[:first + len(marker)] + "\n" + content + "\n\n" + xml[second:]
        print(f"  {label} : XML mis à jour   {include}")
    return xml


def append_global_xml(xml, files):
    for path in files:
        marker = f"<!-- united {path} -->"
        with open(os.path.join(SRC, *path.split("/")), encoding="utf-8") as f:
            content = f.read().replace("\r\n", "\n").strip("\n")
        first = xml.find(marker)
        if first >= 0:
            second = xml.find(marker, first + len(marker))
            xml = xml[:first] + xml[second + len(marker):] if second >= 0 else xml[:first]
        xml = xml.rstrip("\n") + f"\n\n{marker}\n{content}\n{marker}\n"
        print(f"  Global : XML ajouté      {path}")
    return xml


def lua_value(value):
    if value is None:
        return "false"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        escaped = (value.replace("\\", "\\\\").replace('"', '\\"')
                   .replace("\r", "").replace("\n", "\\n"))
        return '"' + escaped + '"'
    if isinstance(value, list):
        return "{" + ", ".join(lua_value(v) for v in value) + "}"
    if isinstance(value, dict):
        parts = []
        for key, v in value.items():
            if v is None:
                continue
            if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key):
                parts.append(f"{key} = {lua_value(v)}")
            else:
                parts.append(f"[{lua_value(key)}] = {lua_value(v)}")
        return "{ " + ", ".join(parts) + " }"
    raise TypeError(f"type non géré : {type(value)}")


def keep_fields(record, fields, prefixes):
    return {k: v for k, v in record.items()
            if k in fields or any(k.startswith(p) for p in prefixes)}


def generate_data_module(use_local):
    """Télécharge (ou lit) les JSON du builder et écrit UnitedDataEmbedded.lua."""
    raw = {}
    for name in DATA_FIELDS:
        if use_local:
            with open(os.path.join(DATA_LOCAL_DIR, name + ".json"), encoding="utf-8") as f:
                raw[name] = json.load(f)
        else:
            with urllib.request.urlopen(DATA_URL.format(name), timeout=60) as response:
                raw[name] = json.loads(response.read().decode("utf-8"))
    source = DATA_LOCAL_DIR if use_local else DATA_URL.format("*")
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    lines = [
        "-- X-Wing United : données du squad builder intégrées au mod.",
        "-- FICHIER GÉNÉRÉ AUTOMATIQUEMENT par tools/build_save.py : ne pas modifier à la main.",
        f"-- Source : {source}",
        f"-- Généré le : {stamp}",
        "",
        "local D = { ships = {}, pilots = {}, upgrades = {}, leaders = {}, chassis = {} }",
        f"D.generated = {lua_value(stamp)}",
        "",
    ]
    for name, (fields, prefixes) in DATA_FIELDS.items():
        for index, record in enumerate(raw[name], start=1):
            lines.append(f"D.{name}[{index}] = {lua_value(keep_fields(record, fields, prefixes))}")
        lines.append("")
    lines.append("return D")
    with open(DATA_MODULE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    counts = ", ".join(f"{len(raw[n])} {n}" for n in DATA_FIELDS)
    print(f"Données X-Wing United : {counts}")
    print(f"  -> {os.path.relpath(DATA_MODULE, REPO)} ({os.path.getsize(DATA_MODULE) // 1024} Ko)")


# Les assets (modèles, textures, socles...) sont servis par ce dépôt et non
# plus par celui de JohnnyCheese : toutes les URL de la sauvegarde sont
# réécrites (objets de la table comme scripts embarqués).
ASSET_URL_RE = re.compile(r"JohnnyCheese/TTS_X-Wing2\.0/(blob/|raw/)?(?:master|[0-9a-f]{40})/")
ASSET_URL_NEW = r"Immelman51/XW-UNITED-TTS/\1main/"


def rewrite_asset_urls(value):
    if isinstance(value, str):
        return ASSET_URL_RE.sub(ASSET_URL_NEW, value)
    if isinstance(value, list):
        return [rewrite_asset_urls(v) for v in value]
    if isinstance(value, dict):
        return {k: rewrite_asset_urls(v) for k, v in value.items()}
    return value


def walk(objects):
    for obj in objects:
        yield obj
        yield from walk(obj.get("ContainedObjects") or [])


def main():
    generate_data_module("--local" in sys.argv[1:])

    if not os.path.exists(WORKSHOP_SAVE):
        sys.exit(f"Mod Workshop introuvable : {WORKSHOP_SAVE}\n"
                 "Abonnez-vous au mod dans Steam et lancez-le une fois dans TTS.")
    with open(WORKSHOP_SAVE, encoding="utf-8") as f:
        save = json.load(f)
    print(f"Base : {save.get('SaveName')} ({save.get('Date')})")

    found = set()
    if "Global" in MODULES:
        save["LuaScript"] = patch_bundle(save["LuaScript"], MODULES["Global"], "Global")
        found.add("Global")
    save["XmlUI"] = append_global_xml(save.get("XmlUI") or "", GLOBAL_XML_APPENDS)
    for obj in walk(save["ObjectStates"]):
        guid = obj.get("GUID")
        if guid in MODULES and guid != "Global":
            obj["LuaScript"] = patch_bundle(obj.get("LuaScript") or "", MODULES[guid], guid)
            found.add(guid)
        if guid in XML_INCLUDES:
            obj["XmlUI"] = patch_xml(obj.get("XmlUI") or "", XML_INCLUDES[guid], guid)
    missing = set(MODULES) - found
    if missing:
        sys.exit(f"Objets introuvables dans le mod : {', '.join(sorted(missing))}")

    save = rewrite_asset_urls(save)
    save["SaveName"] = SAVE_NAME
    with open(OUTPUT_SAVE, "w", encoding="utf-8") as f:
        json.dump(save, f, ensure_ascii=False, indent=2)
    print(f"\nSauvegarde écrite : {OUTPUT_SAVE}")


if __name__ == "__main__":
    main()
