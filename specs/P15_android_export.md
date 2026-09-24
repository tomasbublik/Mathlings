# P15 — Android Export + Podpis

**Tier:** Sonnet 4.6 · **Wave:** 4 (polish) · **Deps:** Všechny ostatní.

## Scope

Příprava finálního sestavení aplikace pro Android. Konfigurace ikon, úvodní obrazovky (splash screen) a exportních profilů. Zahrnuje nastavení keystoru, manifestu a oprávnění tak, aby výstupní APK / AAB splňovalo základní požadavky na distribuci.

## Files to create / modify

- `.godot/export_credentials.cfg` (ignorováno Gitem, jen vytvořit jako instrukce)
- `export_presets.cfg` — Godot export profily (Android).
- **Úprava:** `project.godot` — přidání ikon a splash screen konfigurace.
- `android/build/` — Volitelně custom Android build template (jen v případě, že je nutné specifické API, které základní exporter nepodporuje; pravděpodobně není potřeba).

## Požadavky

1. **Ikony a Splash:** Nastavit `icon.svg` a případné další verze ikon pro aplikaci v Androidu v záložce Application > Config. Nastavit splash obrazovku aplikace (barva pozadí stejná jako v hlavním menu, vycentrovat logo).
2. **Exportní šablony:** Nakonfigurovat `export_presets.cfg` pro Android s architekturami `arm64-v8a` a volitelně `armeabi-v7a`. Unikátní balíček (např. `com.example.mathlings`), verze (`1.0.0`), a minimální verze SDK (API 29+ dle `DESIGN.md`).
3. **Permissions:** Omezit vyžadovaná oprávnění v Android exportu pouze na ty nezbytná (aplikace by neměla potřebovat nic specifického kromě `VIBRATE` pro haptiku). Určitě vyškrtnout "Internet", protože app běží 100% offline (dle DESIGN.md).
4. **Keystore:** Přidat dokumentaci do sekce "Implementation log" popisující, jak vygenerovat a zadat debug a release keystore pomocí nástroje `keytool`.
5. **Orientace:** Ujistit se, že aplikace uzamkne Landscape orientaci obrazovky (`sensor_landscape`).

## Definition of Done

1. Je přítomen funkční `export_presets.cfg` s Android profilem připraveným pro export AAB nebo APK.
2. V `project.godot` jsou korektně natavené ikony a splash obrazovka, omezená oprávnění (žádný internet).
3. Popsán postup generování certifikátů pro podpis release verze.

## Otevřené otázky

- _Zatím žádné._
