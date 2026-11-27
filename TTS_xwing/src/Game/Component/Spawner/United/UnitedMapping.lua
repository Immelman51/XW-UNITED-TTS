-- X-Wing United : tables de correspondance entre les données du squad builder
-- (https://github.com/Immelman51/xwunited) et les éléments du mod TTS.
--
-- Ce fichier est fait pour être édité à la main : ajouter un modèle 3D,
-- changer la couleur de socle d'une faction, etc.

local UnitedMapping = {}

-- Emplacement des fichiers JSON du squad builder (lecture seule).
UnitedMapping.DATA_BASE_URL = "https://raw.githubusercontent.com/Immelman51/xwunited/main/"
UnitedMapping.DATA_FILES = { "ships", "pilots", "upgrades", "leaders", "chassis" }

-- Faction X-Wing United -> faction "classique" du mod.
-- Sert uniquement à l'habillage : texture du socle, skin du cadran,
-- indicateur d'arc de tourelle. Aucune incidence sur les règles.
-- Clés possibles : rebelalliance, galacticempire, scumandvillainy,
-- resistance, firstorder, galacticrepublic, separatistalliance
UnitedMapping.FACTION_SKIN = {
    Rebel_Alliance           = "rebelalliance",
    Phoenix_Cell             = "rebelalliance",
    Partisans                = "rebelalliance",
    New_Republic_Patrol      = "resistance",
    Heroes_of_the_Resistance = "resistance",
    Colossus                 = "resistance",
    Imperial_Academy         = "galacticempire",
    Imperial_Elite_Squadrons = "galacticempire",
    Imperial_Remnants        = "galacticempire",
    ISB                      = "galacticempire",
    First_Order_Vanguard     = "firstorder",
    First_Order_Specialists  = "firstorder",
    Clone_Army               = "galacticrepublic",
    Jedi_Order               = "galacticrepublic",
    Naboo_Defense_Force      = "galacticrepublic",
    Separatist_Government    = "separatistalliance",
    Trade_Federation         = "separatistalliance",
    Hutt_Cartel              = "scumandvillainy",
    Pirates_and_Smugglers    = "scumandvillainy",
    Crime_Syndicates         = "scumandvillainy",
    Black_Sun                = "scumandvillainy",
    Bounty_Hunters_Guild     = "scumandvillainy",
    Mandalorian_Clans        = "scumandvillainy",
    Agents_of_Chaos          = "scumandvillainy",
}
UnitedMapping.DEFAULT_FACTION_SKIN = "scumandvillainy"

-- Nom du vaisseau dans ships.json -> clé du modèle 3D dans ShipDb.lua.
-- false = aucun modèle : le vaisseau apparaît sous forme de socle seul
-- (avec son nom). Pour lui donner un modèle, remplacer false par une clé
-- de ShipDb.lua (ex. 'z95af4headhunter').
UnitedMapping.SHIP_MODEL = {
    ["T-65 X-wing"]                               = 't65xwing',
    ["BTL-A4 Y-wing"]                             = 'btla4ywing',
    ["RZ-1 A-wing"]                               = 'rz1awing',
    ["YT-1300 Light Freighter"]                   = 'modifiedyt1300lightfreighter',
    ["TIE/ln Fighter"]                            = 'tielnfighter',
    ["TIE Advanced x1"]                           = 'tieadvancedx1',
    ["TIE/in Interceptor"]                        = 'tieininterceptor',
    ["Firespray-class Patrol Craft"]              = 'firesprayclasspatrolcraft',
    ["HWK-290 Light Freighter"]                   = 'hwk290lightfreighter',
    ["Lambda-class T-4a Shuttle"]                 = 'lambdaclasst4ashuttle',
    ["A/SF-01 B-wing"]                            = 'asf01bwing',
    ["TIE/sa Bomber"]                             = 'tiesabomber',
    ["Z-95-AF4 Headhunter"]                       = 'z95af4headhunter',
    ["TIE/d Defender"]                            = 'tiededefender',
    ["E-wing"]                                    = 'ewing',
    ["TIE/ph Phantom"]                            = 'tiephphantom',
    ["YT-2400 Light Freighter"]                   = 'yt2400lightfreighter',
    ["VT-49 Decimator"]                           = 'vt49decimator',
    ["StarViper-class Attack Platform"]           = 'starviperclassattackplatform',
    ["M3-A Interceptor"]                          = 'm3ainterceptor',
    ["Aggressor Assault Fighter"]                 = 'aggressorassaultfighter',
    ["YV-666 Light Freighter"]                    = 'yv666lightfreighter',
    ["Kihraxz Fighter"]                           = 'kihraxzfighter',
    ["BTL-S8 K-wing"]                             = 'btls8kwing',
    ["TIE/ca Punisher"]                           = 'tiecapunisher',
    ["VCX-100 Light Freighter"]                   = 'vcx100lightfreighter',
    ["Attack Shuttle"]                            = 'attackshuttle',
    ["TIE Advanced v1"]                           = 'tieadvancedv1',
    ["G-1A Starfighter"]                          = 'g1astarfighter',
    ["JumpMaster 5000"]                           = 'jumpmaster5000',
    ["ARC-170 Starfighter"]                       = 'arc170starfighter',
    ["Fang Fighter"]                              = 'fangfighter',
    ["Lancer-Class Pursuit Craft"]                = 'lancerclasspursuitcraft',
    ["Quadrijet Transfer Spacetug"]               = 'quadrijettransferspacetug',
    ["UT-60D U-wing"]                             = 'ut60duwing',
    ["TIE/sk Striker"]                            = 'tieskstriker',
    ["Auzituck Gunship"]                          = 'auzituckgunship',
    ["Scurrg H-6 Bomber"]                         = 'scurrgh6bomber',
    ["TIE/ag Aggressor"]                          = 'tieagaggressor',
    ["Alpha-Class Star Wing"]                     = 'alphaclassstarwing',
    ["M12-L Kimogila Fighter"]                    = 'm12lkimogilafighter',
    ["Sheathipede-Class Shuttle"]                 = 'sheathipedeclassshuttle',
    ["TIE Reaper"]                                = 'tierereaper',
    ["Escape Craft"]                              = 'escapecraft',
    ["T-70 X-wing"]                               = 't70xwing',
    ["RZ-2 A-wing"]                               = 'rz2awing',
    ["TIE/fo Fighter"]                            = 'tiefofighter',
    ["TIE/vn Silencer"]                           = 'tievnsilencer',
    ["TIE/sf Fighter"]                            = 'tiesffighter',
    ["Upsilon-Class Command Shuttle"]             = 'upsilonclasscommandshuttle',
    ["MG-100 StarFortress"]                       = 'mg100starfortress',
    ["Modified TIE/ln Fighter"]                   = 'modifiedtielnfighter',
    ["V-19 Torrent Starfighter"]                  = 'v19torrentstarfighter',
    ["Delta-7 Aethersprite"]                      = 'delta7aethersprite',
    ["Delta-7b Aethersprite"]                     = 'delta7baethersprite',
    ["Sith Infiltrator"]                          = 'sithinfiltrator',
    ["Vulture-class Droid Fighter"]               = 'vultureclassdroidfighter',
    ["Belbullab-22 Starfighter"]                  = 'belbulab22starfighter',
    ["Naboo Royal N-1 Starfighter"]               = 'nabooroyaln1starfighter',
    ["Hyena-class Droid Bomber"]                  = 'hyenaclassdroidbomber',
    ["Resistance Transport Pod"]                  = 'resistancetransportpod',
    ["Resistance Transport"]                      = 'resistancetransport',
    ["Nantex-Class Starfighter"]                  = 'nantexclassstarfighter',
    ["BTL-B Y-wing"]                              = 'btlbywing',
    ["Fireball"]                                  = 'fireball',
    ["TIE/ba Interceptor"]                        = 'tiebainterceptor',
    ["Xi-class Light Shuttle"]                    = 'xiclasslightshuttle',
    ["HMP Droid Gunship"]                         = 'hmpdroidgunship',
    ["LAAT/i Gunship"]                            = 'laatigunship',
    ["TIE/rb Heavy"]                              = 'tierbheavy',
    ["Droid Tri-fighter"]                         = 'droidtrifighter',
    ["Nimbus-class V-wing"]                       = 'nimbusclassvwing',
    ["Eta-2 Actis"]                               = 'eta2actis',
    ["Syliure-class Hyperspace Ring"]             = false, -- pas de modèle 3D (small)
    ["BTA-NR2 Y-wing"]                            = 'btanr2ywing',
    ["TIE/wi Whisper Modified Interceptor"]       = 'tiewiwhispermodifiedinterceptor',
    ["TIE/se Bomber"]                             = 'tiesebomber',
    ["Gauntlet Fighter"]                          = 'gauntletfighter',
    ["ST-70 Assault Ship"]                        = 'st70assaultship',
    ["Clone Z-95 Headhunter"]                     = 'clonez95headhunter',
    ["Rogue-class Starfighter"]                   = 'rogueclassstarfighter',
    ["Commando Team"]                             = 'commandoteam',
    ["T-6 Shuttle"]                               = false, -- pas de modèle 3D (medium)
    ["Supa Starfighter"]                          = false, -- pas de modèle 3D (medium)
    ["Crimson Starfighter"]                       = false, -- pas de modèle 3D (small)
    ["Sarissa-Class Gunship"]                     = false, -- pas de modèle 3D (medium)
    ["Rihkxyrk Attack Ship"]                      = false, -- pas de modèle 3D (medium)
    ["Blue Ace"]                                  = false, -- pas de modèle 3D (small)
    ["Red Ace"]                                   = false, -- pas de modèle 3D (small)
    ["Yellow Ace"]                                = false, -- pas de modèle 3D (small)
    ["Green Ace"]                                 = false, -- pas de modèle 3D (small)
    ["Black Ace"]                                 = false, -- pas de modèle 3D (small)
    ["Ginivex-class Fanblade Starfighter"]        = false, -- pas de modèle 3D (small)
    ["TIE/es Echelon"]                            = 'tieesechelon',
    ["Oubliette Class Transport"]                 = false, -- pas de modèle 3D (large)
    ["Omicron Class Shuttle"]                     = false, -- pas de modèle 3D (large)
    ["RP82 Fighter"]                              = false, -- pas de modèle 3D (small)
    ["Laat/Le Patrol Gunship"]                    = false, -- pas de modèle 3D (small)
    ["ETA Class Shuttle"]                         = 'etaclassshuttle',
    ["J-Type Star Skiff"]                         = 'jtypestarskiff',
    ["NB-1H Royal Bomber"]                        = 'nb1hroyalbomber',
    ["CloakShape Fighter"]                        = 'cloakshapefighter',
    ["Scarab-Class Droid Fighter"]                = false, -- pas de modèle 3D (small)
    ["Zenuas 33 Umbaran Starfighter"]             = 'zenuas33umbaranstarfighter',
    ["Droch-class Boarding Ship"]                 = 'drochclassboardingship',
    ["G9 Rigger Freighter"]                       = 'g9riggerfreighter',
    ["HH-87 Starhopper"]                          = 'hh87starhopper',
    ["BTA-NR2-W Y-wing"]                          = 'btanr2ywing-wartime',
    ["S-161 'Stinger' XL"]                        = 's161stingerxl',
    ["Logistic Supply"]                           = false, -- pas de modèle 3D (small)
    ["YV-865 Aurore-Class Freighter"]             = 'yv865auroreclassfreighter',
    ["Mankvim-814 Light Interceptor"]             = 'mankvim814lightinterceptor',
}

-- Actions X-Wing United ("Fo W" -> "Fo") -> codes d'action du mod.
-- Seules les actions qui déclenchent un déplacement ou un marqueur
-- spécifique ont besoin d'un code ; les autres sont simplement ignorées.
UnitedMapping.ACTIONS = {
    Fo = "F",   -- Concentration
    Lo = "TL",  -- Verrouillage
    Ev = "E",   -- Évasion
    Br = "BR",  -- Tonneau
    Bo = "B",   -- Accélération
    Re = "R",   -- Renforcement
    Ra = "Rot", -- Rotation de tourelle
    Ck = "CL",  -- Occultation
    Cc = "C",   -- Calcul
}

-- Colonnes de la matrice "maneuvers" de ships.json (voir README du builder) :
-- [L-Turn, L-Bank, Straight, R-Bank, R-Turn, K-Turn, S-Loop L, S-Loop R,
--  T-Roll L, T-Roll R, L-Reverse, Straight Reverse, R-Reverse]
-- Chaque entrée donne le préfixe et le suffixe du code de manœuvre du mod.
UnitedMapping.MANEUVER_COLUMNS = {
    { "tl", "" },  -- virage serré gauche
    { "bl", "" },  -- virage léger gauche
    { "s",  "" },  -- tout droit
    { "br", "" },  -- virage léger droit
    { "tr", "" },  -- virage serré droit
    { "k",  "" },  -- Koiogran
    { "bl", "s" }, -- boucle de Segnor gauche
    { "br", "s" }, -- boucle de Segnor droite
    { "tl", "t" }, -- tonneau de Tallon gauche
    { "tr", "t" }, -- tonneau de Tallon droit
    { "bl", "r" }, -- marche arrière gauche
    { "s",  "r" }, -- marche arrière tout droit
    { "br", "r" }, -- marche arrière droite
}
-- Valeur de la matrice -> couleur de la manœuvre
UnitedMapping.MANEUVER_COLORS = { [1] = "b", [2] = "w", [3] = "r", [4] = "p" }

-- Arcs de tir X-Wing United ("attack") -> arcs du mod, utilisés uniquement
-- pour les vaisseaux SANS modèle 3D (les autres gardent les arcs du mod).
UnitedMapping.FIXED_ARCS = {
    F    = "front",
    B    = "back",
    ["180"] = "fullfront",
    BULL = "bullseye",
}
UnitedMapping.TURRET_ARCS = {
    T  = "singleturret",
    DT = "doubleturret",
}

-- Pictogrammes utilisés dans les textes du builder (<img src='img/xxx.png'>)
-- -> texte affiché dans TTS. Les images absentes de cette liste sont
-- affichées sous la forme [nom du fichier].
UnitedMapping.TEXT_ICONS = {
    ["charge.png"]      = { FRA = "[Charge]", ENG = "[Charge]" },
    ["chargeplus.png"]  = { FRA = "[Charge+]", ENG = "[Charge+]" },
    ["chargestat.png"]  = { FRA = "[Charge]", ENG = "[Charge]" },
    ["chargestatRed.png"] = { FRA = "[Charge]", ENG = "[Charge]" },
    ["forcestat.png"]   = { FRA = "[Force]", ENG = "[Force]" },
    ["hit.png"]         = { FRA = "[Touche]", ENG = "[Hit]" },
    ["crit.png"]        = { FRA = "[Critique]", ENG = "[Crit]" },
    ["fo.png"]          = { FRA = "[Concentration]", ENG = "[Focus]" },
    ["Fo W.png"]        = { FRA = "[Concentration]", ENG = "[Focus]" },
    ["Lo W.png"]        = { FRA = "[Verrouillage]", ENG = "[Lock]" },
    ["Ev W.png"]        = { FRA = "[Évasion]", ENG = "[Evade]" },
    ["Br W.png"]        = { FRA = "[Tonneau]", ENG = "[Barrel Roll]" },
    ["Bo W.png"]        = { FRA = "[Accélération]", ENG = "[Boost]" },
    ["Cc W.png"]        = { FRA = "[Calcul]", ENG = "[Calculate]" },
    ["Co W.png"]        = { FRA = "[Coordination]", ENG = "[Coordinate]" },
    ["Ja W.png"]        = { FRA = "[Brouillage]", ENG = "[Jam]" },
    ["Sl W.png"]        = { FRA = "[SLAM]", ENG = "[SLAM]" },
    ["Ra W.png"]        = { FRA = "[Rotation]", ENG = "[Rotate]" },
    ["UN W.png"]        = { FRA = "[Déchargement]", ENG = "[Unload]" },
    ["fleche.png"]      = { FRA = "→", ENG = "→" },
    ["bulls.png"]       = { FRA = "[Bullseye]", ENG = "[Bullseye]" },
    ["attackF.png"]     = { FRA = "[Arc avant]", ENG = "[Front Arc]" },
    ["attackB.png"]     = { FRA = "[Arc arrière]", ENG = "[Rear Arc]" },
    ["attack180.png"]   = { FRA = "[Arc 180°]", ENG = "[Full Front Arc]" },
    ["Tarc.png"]        = { FRA = "[Tourelle]", ENG = "[Turret]" },
    ["Farc.png"]        = { FRA = "[Arc avant]", ENG = "[Front Arc]" },
    ["Larc.png"]        = { FRA = "[Arc gauche]", ENG = "[Left Arc]" },
    ["Rarc.png"]        = { FRA = "[Arc droit]", ENG = "[Right Arc]" },
}

-- Images du squad builder (dépôt xwunited), chargées par TTS depuis GitHub
UnitedMapping.IMG_BASE = "https://raw.githubusercontent.com/Immelman51/xwunited/main/img/"

-- Images d'action disponibles dans img/ ("Fo W" -> "Fo W.png")
UnitedMapping.ACTION_IMAGES = {
    ["Bo R"] = true,
    ["Bo W"] = true,
    ["Br R"] = true,
    ["Br W"] = true,
    ["Cc R"] = true,
    ["Cc W"] = true,
    ["Ck R"] = true,
    ["Ck W"] = true,
    ["Co F"] = true,
    ["Co R"] = true,
    ["Co W"] = true,
    ["Ev F"] = true,
    ["Ev R"] = true,
    ["Ev W"] = true,
    ["Fo R"] = true,
    ["Fo W"] = true,
    ["Ja R"] = true,
    ["Ja W"] = true,
    ["Lo R"] = true,
    ["Lo W"] = true,
    ["Ra P"] = true,
    ["Ra R"] = true,
    ["Ra W"] = true,
    ["Re R"] = true,
    ["Re W"] = true,
    ["Sl W"] = true,
    ["Un P"] = true,
    ["Un R"] = true,
    ["Un W"] = true,
}

-- Image de chaque type d'attaque, et texte de secours
UnitedMapping.ATTACK_IMAGES = {
    F = "attackF.png", B = "attackB.png", T = "attackT.png", DT = "attackDT.png",
    BULL = "attackBULL.png", ["180"] = "attack180.png",
}
UnitedMapping.ATTACK_LABELS = {
    F = "F", B = "B", T = "Tur", DT = "DTur", BULL = "Bull", ["180"] = "180",
}

-- Images des autres caractéristiques
UnitedMapping.STAT_IMAGES = {
    agility = "agility.png",
    hull = "hull.png",
    shields = "shield.png",
    force = "forcestat.png",
}

return UnitedMapping
