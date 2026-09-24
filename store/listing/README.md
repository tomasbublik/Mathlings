# Google Play store listing – Mathlings

Store listing texts in the [fastlane `supply`](https://docs.fastlane.tools/actions/supply/) metadata
layout, so they can be uploaded with `fastlane supply` or copy-pasted into Play Console
(**Grow → Store presence → Main store listing**, then *Manage translations*).

```
store/
├── .gdignore                  ← keeps Godot from importing anything in store/
├── play-console.md            ← answers for every Play Console form (Data safety, IARC, …)
├── listing/
│   ├── README.md              ← this file
│   ├── check_lengths.py       ← validates limits, emoji/U+FE0F, HTML, title wording
│   └── <play-locale>/
│       ├── title.txt              ≤ 30 characters, one line
│       ├── short_description.txt  ≤ 80 characters, one line
│       └── full_description.txt   ≤ 4000 characters, plain text, "•" bullets
└── graphics/                  ← made separately (see below)
```

Files are UTF-8 without a trailing newline. Play counts **characters** (Unicode code points), not
bytes – `check_lengths.py` uses Python `len()` on the decoded text.

## Locales

| Play locale | Language | Notes |
|---|---|---|
| `en-US` | English (US) | Default listing. "math", "color", "grades 1–3" |
| `en-GB` | English (UK) | "maths", "colour", "practise", "Years 1 to 3", "adverts" |
| `cs-CZ` | Czech | Czech quotation marks „…“; in-game terms (Můj pokrok, Hráči, Automaticky) |
| `zh-CN` | Chinese (Simplified) | Full-width punctuation （）：，。“” |
| `hi-IN` | Hindi | Danda । ; "पहाड़े" for times tables, as in-game |
| `es-ES` | Spanish (Spain) | «…» quotes, "mates", "1.º a 3.º de Primaria", "Ajustes" |
| `es-419` | Spanish (Latin America) | "…" quotes, "grado", "Configuración", "app" |
| `fr-FR` | French | No-break space before `:` and « », narrow no-break space before `; ! ?`; "du CP au CE2" |
| `ar` | Arabic | Brand kept in Latin script, separated by an en dash (bidi-safe in RTL) |
| `bn-BD` | Bengali | Western digits, matching in-game strings |
| `pt-BR` | Portuguese (Brazil) | "rodada", "tabuada", "1º ao 3º ano do ensino fundamental" |
| `pt-PT` | Portuguese (Portugal) | "ronda", "ecrã", "miúdos", «…» quotes |
| `ru-RU` | Russian | «…» quotes, "ё" used consistently |
| `ur` | Urdu | Full stop ۔ ; brand in Latin script separated by an en dash |
| `id` | Indonesian | "Kemajuanku", "beruntun", as in-game |

All terminology for in-game screens, themes and settings (e.g. *My progress*, *Players*, *Auto*,
*Fruits / Space / Party*) is taken from `assets/translations/strings.csv`, so the listing matches what
the child sees after installing.

## Character counts

Generated with `python3 store/listing/check_lengths.py --markdown` (limit shown after the slash):

| Locale | Title | Short description | Full description |
|---|---:|---:|---:|
| `en-US` | 29/30 | 78/80 | 2150/4000 |
| `en-GB` | 30/30 | 77/80 | 2152/4000 |
| `cs-CZ` | 26/30 | 78/80 | 2131/4000 |
| `zh-CN` | 16/30 | 31/80 | 871/4000 |
| `hi-IN` | 29/30 | 77/80 | 2158/4000 |
| `es-ES` | 27/30 | 79/80 | 2365/4000 |
| `es-419` | 30/30 | 74/80 | 2380/4000 |
| `fr-FR` | 30/30 | 76/80 | 2434/4000 |
| `ar` | 27/30 | 76/80 | 1988/4000 |
| `bn-BD` | 28/30 | 72/80 | 2051/4000 |
| `pt-BR` | 30/30 | 74/80 | 2307/4000 |
| `pt-PT` | 29/30 | 77/80 | 2367/4000 |
| `ru-RU` | 27/30 | 76/80 | 2234/4000 |
| `ur` | 30/30 | 72/80 | 2198/4000 |
| `id` | 26/30 | 79/80 | 2377/4000 |

Run the script again after any edit – it exits non-zero if a limit is exceeded, a file is missing, or
a title contains "best / #1 / free / top / new" or an ALL-CAPS word (Play metadata policy).

## Writing rules used

- Title = brand + short keyword phrase; no emoji, no ALL CAPS, no ranking/price claims.
- Descriptions are parent-facing: benefit → how it adapts → feature bullets → safety bullets → closing line.
- Only features that exist in the build are described (checked against the code; see
  `store/play-console.md` → *Verified facts*). If a feature changes, update every locale.
- No emoji and no U+FE0F variation selectors anywhere (they render as tofu on some Android devices).
- The list of 12 languages is written in each language's own name/script in every locale.

## Graphics (produced separately)

Expected file names – referenced by the upload tooling, created by the graphics workstream:

| File | Size / notes |
|---|---|
| `store/graphics/icon_512.png` | 512 × 512 PNG, 32-bit, ≤ 1 MB (an earlier copy exists at `assets/store/icon_512.png`) |
| `store/graphics/feature_graphic_1024x500.png` | 1024 × 500 PNG/JPEG, no alpha |
| `store/graphics/phone/*.png` | 2–8 phone screenshots, 16:9 or 9:16, 320–3840 px per side |
| `store/graphics/tablet7/*.png` | 7-inch tablet screenshots (recommended, up to 8) |
| `store/graphics/tablet10/*.png` | 10-inch tablet screenshots (recommended, up to 8) |

Screenshots should use landscape gameplay (the game supports both orientations) and must not show
real children's names – use names like "Alex" or "Mia".

For fastlane, copy/symlink them into
`listing/<locale>/images/{icon.png,featureGraphic.png,phoneScreenshots/,sevenInchScreenshots/,tenInchScreenshots/}`
or upload them once in Play Console (graphics can be shared across all languages).

## Privacy policy URL

The policy lives in `docs/privacy-policy.html` (English + Czech) and is intended for GitHub Pages
(`Settings → Pages → Deploy from branch → main /docs`). Replace `{{DEVELOPER_NAME}}` and
`{{CONTACT_EMAIL}}` in `docs/*.html` before publishing, then paste the resulting URL
(e.g. `https://<user>.github.io/<repo>/privacy-policy.html`) into Play Console → *App content →
Privacy policy*.
