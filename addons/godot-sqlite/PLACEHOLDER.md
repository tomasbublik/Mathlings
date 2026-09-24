# godot-sqlite addon — PLACEHOLDER

Tento adresář je prázdný, protože při generování kódu nebyl dostupný internet.

## Jak nainstalovat addon ručně

1. Stáhni nejnovější stable release kompatibilní s Godot 4.3 z:
   https://github.com/2shady4u/godot-sqlite/releases

   Hledej release označený jako kompatibilní s Godot 4.x (např. `v3.x.x` pro Godot 4).
   Stáhni ZIP archiv (typicky `godot-sqlite-v*.zip`).

2. Rozbal ZIP archiv. Uvnitř najdeš složku `addons/godot-sqlite/` obsahující:
   - `gdsqlite.gdextension` — deklarace rozšíření
   - `libgdsqlite.macos.framework/` nebo `libgdsqlite.macos.dylib` — macOS dylib
   - `libgdsqlite.windows.dll` — Windows
   - `libgdsqlite.linux.so` — Linux
   - `libgdsqlite.android.so` — Android (arm64-v8a a x86_64)
   - `gdsqlite.gd` — GDScript wrapper (třída `SQLite`)

3. Zkopíruj obsah `addons/godot-sqlite/` z ZIP do tohoto adresáře
   (`addons/godot-sqlite/` v projektu).

4. V Godot editoru: Project → Project Settings → Plugins → aktivuj **godot-sqlite**.

5. Ověř, že třída `SQLite` je dostupná: v GDScript `var db := SQLite.new()` bez chyb.

## Minimální verze

- godot-sqlite **v3.8.0** nebo novější (Godot 4.3+ kompatibilní).
- Odkaz na konkrétní release: https://github.com/2shady4u/godot-sqlite/releases/tag/v3.8.0

## Poznámka pro CI/CD

Pokud build probíhá v CI bez GUI, lze addon nainstalovat scriptem:

```bash
VERSION=v3.8.0
curl -L "https://github.com/2shady4u/godot-sqlite/releases/download/${VERSION}/godot-sqlite-${VERSION}.zip" -o /tmp/gdsqlite.zip
unzip -o /tmp/gdsqlite.zip -d .
```
