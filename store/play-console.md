# Play Console answers – Mathlings (first release)

Ready-to-use answers for every Play Console declaration needed before the first release of
`com.mathlings.app`. Items that need the owner's choice are marked **DECISION NEEDED**.
Everything else is based on facts verified in the code (see [Verified facts](#verified-facts) at the end).

Listing texts: `store/listing/<locale>/`. Privacy policy: `docs/privacy-policy.html`.

---

## 1. App details (Create app / Main store listing)

| Field | Answer |
|---|---|
| App name | `Mathlings` (localized titles in `store/listing/*/title.txt`) |
| Default language | English (United States) – `en-US` |
| App or game | **Game** |
| Free or paid | **Free** (no in-app purchases). Note: a free app can never be switched to paid later. |
| Category | **Games → Educational** |
| Tags (pick up to 5 in *Store settings → Tags*) | Educational, Math, Casual, Arcade, Kids (choose the closest matches Play offers) |
| Contact email | `tomas.bublik@gmail.com` – **DECISION NEEDED** (shown publicly on the listing) |
| Website | GitHub Pages landing page `docs/index.html` (optional) |
| Phone | leave empty |
| Privacy policy URL | GitHub Pages URL of `docs/privacy-policy.html` – **DECISION NEEDED**: enable Pages (`main` / `docs`) and replace `Tomáš Bublík` / `tomas.bublik@gmail.com` first |

## 2. App access

**All functionality is available without special access.** No login, no account, no paywall.
(The parent gate scene exists but is not used – `scenes/main_menu/main_menu.gd:8-9`.)

## 3. Ads

**No, my app does not contain ads.** No ad SDK, no network permission.

## 4. Content rating (IARC questionnaire)

- Email for the certificate: `tomas.bublik@gmail.com`
- Category: **Game** (IARC category "Game"; not "Reference, News or Educational", which is meant for non-game apps)

| Question group | Answer | Why |
|---|---|---|
| Violence (any, cartoon/fantasy/realistic) | **No** | Correct answers burst the falling object (fruit juice splash, meteor/rocket spark, popped balloon) – particle effects on objects, no characters are harmed (`scenes/game/vfx/*`) |
| Blood / gore | No | |
| Fear / horror | No | Friendly purple mascot, bright themes |
| Sexuality / nudity | No | |
| Language (profanity, crude humour) | No | |
| Controlled substances (drugs, alcohol, tobacco) | No | |
| Gambling (real or simulated) | No | Points and stars are awarded for correct answers only; no chance-based rewards, no loot boxes |
| Miscellaneous – users can interact / communicate | **No** | No chat, no multiplayer, no network |
| Shares user's current physical location | No | No location permission |
| Allows purchase of digital goods | No | No IAP |
| Unrestricted internet / web browser | No | No INTERNET permission, no links out of the app |
| Is the app a web browser or search engine | No | |
| Is the app primarily news or educational (non-game) | No (it is an educational *game*) | |

Expected result: **PEGI 3 / ESRB Everyone / USK 0 / IARC 3+ / ClassInd L** with no content descriptors.

## 5. Target audience and content

| Question | Answer |
|---|---|
| Target age groups | **Ages 6–8** and **Ages 9–12** – **DECISION NEEDED** (see below) |
| Could the app unintentionally appeal to children? | N/A – it targets children |
| Store listing appeals to children? | Yes |

**DECISION NEEDED – age groups.** The game is built for school years 1–3 (≈ 6–9). Recommended: tick
**6–8** and **9–12** (9-year-olds are in the second group; content tops out at ×10 / ÷ within 100, so
older children in the 9–12 band are at the upper edge). Do **not** tick "5 & under" (reading the
problems requires early-reader skills) and do **not** tick 13+ (would make the app mixed-audience
without benefit). Adding "5 & under" would be defensible for strong pre-schoolers but invites extra
review scrutiny of the UI (e.g. text-heavy settings).

**Implications** (because a target group is under 13, the app falls under the
[Families policy](https://support.google.com/googleplay/android-developer/answer/9893335)):

- Must have a privacy policy – done (`docs/privacy-policy.html`).
- Ads only from Families-certified ad SDKs – N/A, no ads.
- Must not transmit device identifiers (AAID, Android ID, IMEI…) from children – compliant, no network.
- Must not request location permission – compliant.
- Content and store graphics must be appropriate for children – screenshots must not contain real
  children's names.
- Any third-party SDK must be a Families Self-Certified SDK – N/A, none included.
- Data safety form must be completed accurately (below).
- The app becomes eligible for the **Kids** tab and, optionally, the **Teacher Approved** programme
  (automatic evaluation, no application needed; cannot be requested).

## 6. Data safety form

Data stays in the app's private storage (`user://` → `/data/data/com.mathlings.app/files/`), is
never transmitted, and is excluded from Android cloud backup. Under Google's definitions, data
processed only on the device and never sent off it is **not "collected"**.

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | *Not shown* (only asked when you collect data). If asked: N/A – no data leaves the device |
| Do you provide a way for users to request that their data is deleted? | *Not shown* when nothing is collected. If asked: data can be deleted in-app (*Players → Delete*) or by uninstalling / *Clear data* |
| Account creation | **My app does not allow users to create an account** (local "players" are nicknames on the device, no login) |
| Data deletion URL (only if accounts exist) | N/A |
| Has the app's data safety been independently validated (MASA)? | No (optional) |
| Committed to Play Families Policy | Yes |

Resulting listing badge: **"No data collected" · "No data shared with third parties"**.

## 7. Other App content declarations

| Declaration | Answer |
|---|---|
| Government app | No |
| Financial features | **My app doesn't provide any financial features** |
| Health apps | **My app does not have any health features** |
| News app | **No** |
| COVID-19 contact tracing / status app | **No** (if still listed in your console) |
| Photo & video permissions / Foreground service / Exact alarm / Full-screen intent | Not applicable – none of these permissions are requested |
| Advertising ID | **No** – the app does not use the advertising ID (and must not declare `AD_ID`; verify the final AAB manifest does not merge it in) |
| Data safety | See section 6 |
| Target audience | See section 5 |

## 8. Families policy checklist

- [x] Privacy policy linked in Play Console **and** reachable from the listing (URL field).
- [x] No ads; no ad SDKs; no advertising ID.
- [x] No in-app purchases, no links out of the app, no social features → a parent gate is not required.
- [x] No location, camera, microphone, contacts or storage permissions; only `VIBRATE` and `WAKE_LOCK`.
- [x] No collection or transmission of personal data (child-entered names stay on device).
- [x] No third-party SDKs (only Godot engine; `addons/gut` is a test framework).
- [x] Content suitable for 6–12: no violence, no scary content, positive feedback, wrong answers cost no points.
- [x] Store listing is honest (every listed feature exists in the build) and free of "best/#1/free" claims.
- [ ] Store graphics and screenshots reviewed for age-appropriateness and no personal data (graphics workstream).
- [ ] Target API level meets the current Play requirement for new apps – **verify with the build team**
      (`gradle_build/target_sdk` is empty in `export_presets.cfg:30`, so Godot's default applies).
- [ ] Final AAB manifest inspected (`bundletool dump manifest`) to confirm only `VIBRATE` and `WAKE_LOCK`
      are declared – release exports must not have `INTERNET` merged in.

## 9. Closed testing requirement (new personal developer accounts)

Personal developer accounts created after 13 November 2023 must run a **closed test with at least
12 testers who stay opted in for at least 14 consecutive days** before they can apply for
production access. **DECISION NEEDED:** confirm whether the Play developer account is *personal*
(requirement applies) or *organization* (requirement does not apply; D-U-N-S number needed).

Plan (≈ 3 weeks):

1. **Day 0 – prepare.** Complete sections 1–8, upload the first signed AAB to the *Closed testing*
   track (create a track "Family testers"), add a tester list (Google Group or email list) with
   **15–20 adults** so dropouts don't take you below 12. Testers are parents/relatives; children
   play on the parents' devices – testers themselves must be adults with Google accounts.
2. **Day 0–1 – opt in.** Send the opt-in link; ask each tester to accept *and install*. Check
   *Testing → Closed testing → Testers* shows ≥ 12 opted in. The 14-day clock only counts days with
   ≥ 12 opted-in testers.
3. **Days 1–14 – engage.** Ask testers to play a few rounds on several days (Play looks at
   engagement), try different languages, players, round lengths and themes, and send feedback via
   the private feedback channel or a short form. Ship at least one update (e.g. fixes from
   feedback) during the test – Play asks about this on the production application.
4. **Day 15+ – apply for production.** *Dashboard → Apply for production*; answer the questions
   about the test (how testers were recruited, feedback received, changes made, readiness).
   Review typically takes up to 7 days.
5. **Release.** Staged rollout (e.g. 20 % → 100 %) in the chosen countries.

**DECISION NEEDED:** countries/regions for release (suggested: all countries where the 12 listing
languages are relevant; review local children's-app rules if in doubt).

## 10. Release notes (first release, en-US)

```
First release of Mathlings – a colourful maths arcade game with an adaptive tutor.
```
(Localize per locale when uploading, ≤ 500 characters.)

---

## Verified facts

Checked against the code at commit `de8c6a3`.

| Claim | Status | Evidence |
|---|---|---|
| Only `VIBRATE` and `WAKE_LOCK` permissions | ✔ | `export_presets.cfg:197-198` true; `:129` `permissions/internet=false`; `:63` no custom permissions; all other permissions false |
| No network code | ✔ | No `HTTPRequest`, `HTTPClient`, `StreamPeerTCP`, `WebSocket`, `PacketPeerUDP`, `ENet`, `OS.shell_open` in `scripts/`, `scenes/` |
| No analytics / ads / third-party SDKs | ✔ | `addons/` contains only `gut` (tests); no `.aar`/`.jar`/`.gdextension`; no `Engine.get_singleton`/`JavaClassWrapper` |
| Data only in app-private storage | ✔ | `user://` paths: `scripts/persistence/progress_store.gd` (`user://progress`), `scripts/autoload/profile_service.gd:26,31,35,39`, `scripts/persistence/session_stats_store.gd:134`, `scripts/autoload/settings_store.gd:4` |
| Excluded from Android backup | ✔ | `export_presets.cfg:58` `user_data_backup/allow=false` |
| Deleted on uninstall | ✔ | `export_presets.cfg:41` `package/retain_data_on_uninstall=false` |
| In-app player deletion | ✔ | `scripts/autoload/profile_service.gd:128-140` (removes profile, per-profile dir with settings + stats, and the progress file); UI `scenes/profiles/profile_manager.gd:144` |
| Up to 5 players | ✔ | `scripts/autoload/profile_service.gd:22` |
| Round length 30 s – 5 min | ✔ | `scenes/settings/settings.gd:10` `[30, 60, 120, 180, 300]` |
| Speed Slow / Normal / Fast / Auto | ✔ | `assets/translations/strings.csv` `SETTINGS_SPEED_*`; DESIGN.md §6.3 |
| Skills (add/sub to 10/20/100, ×2–×10, ÷ to 100) | ✔ | DESIGN.md §6.2; `strings.csv` `SKILL_*` |
| 3 themes (Fruits, Space, Party), all available from the start | ✔ | `scripts/autoload/theme_manager.gd:36,66,68,94,96,105` |
| Stars on results, badges ("New reward!") | ✔ | `scenes/results/results.gd:12,29,198`; `scripts/game/unlock_system.gd` |
| Mathling mascot | ✔ | `scenes/shared/mascot.gd:4` |
| Pause / quit round | ✔ | `scenes/game/pause_overlay.*`, DESIGN.md §9 |
| 12 languages | ✔ | `assets/translations/strings.csv` header; `project.godot` `locale/translations` |
| Sound / music / vibration toggles | ✔ | `strings.csv` `SETTINGS_SFX_TOGGLE`, `SETTINGS_MUSIC_TOGGLE`, `SETTINGS_HAPTICS_TOGGLE`; `scripts/autoload/haptics_manager.gd:43` |

### Discrepancies found (not papered over)

1. ~~**SQLite addon is missing – long-term per-skill progress is not persisted.**~~ **Resolved:**
   SQLite was dropped; per-skill ratings, badges/unlocks, round history and recent attempts are now
   stored per player in `user://progress/profile_<id>.json` (`scripts/persistence/progress_store.gd`,
   DESIGN.md §6.1). The "10 rounds" / "addition master" badges and the per-skill part of
   *My progress* work across restarts.
2. ~~**Latent bug if the SQLite addon is installed:** deleting a player could leave rows behind.~~
   **Resolved:** no database any more; `ProfileService.delete` removes the profile entry, its
   settings/stats directory and its progress file (incl. backups).
3. **Orientation:** README says "locked to `sensor_landscape`", but `project.godot:46` is
   `"sensor"` and `export_presets.cfg:52` `screen/orientation=6` (sensor) – the app rotates to portrait
   too. Not a listing problem; screenshots can be landscape or portrait.
4. **Engine version:** brief says Godot 4.7; `project.godot:21` feature tag says `"4.6"`
   (README/DESIGN say 4.3+). Informational only.
5. **Min/target SDK:** README says min SDK 29, but `export_presets.cfg:29-30` leaves
   `gradle_build/min_sdk`/`target_sdk` empty and Gradle build is off, so Godot's defaults apply.
   Verify the target API level satisfies the current Play requirement.
6. **Ages:** DESIGN.md §1 says 6–10, the brief says 6–9. Listings say 6–9.
7. `project.godot` `config/description` still reads "Math learning arcade for kids (Czech)" – not
   user-visible on Play, cosmetic only.
