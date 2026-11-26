# Ladder Architecture Review — Simplification & Deepening Opportunities

This document records architectural simplification opportunities found across Ladder (~114k lines across `main.jl`, 56 top-level `.jl` files, `web/`, `cad/`, `term/`, and `app/`, plus ~52k lines across 218 test files).

Vocabulary used throughout:
- **Module**: anything with an interface and an implementation.
- **Interface**: everything a caller (or test) must know to use a module (types, invariants, ordering, error modes, configuration).
- **Depth**: leverage at the interface — a lot of behaviour behind a small interface (**deep** = high leverage, **shallow** = interface nearly as complex as the implementation).
- **Seam**: where an interface lives — a place behaviour can be altered without editing in place.
- **Adapter**: a concrete thing satisfying an interface at a seam.
- **Leverage** / **Locality**: what callers and maintainers gain from depth.

---

## 1. Unify and deepen the fenced Block seam

- **Files**: `main.jl` (L2894–L4298, L8149–L25417, L26458–L26710, L27855–L28030, L33416, L33899–L33961, L35374–L35410, L36800–L36862, L41242–L41254, L43164–L43167, L44900–L44938, L46248), `find.jl` (L54–L92), and the 22 block model files (`takeoff.jl`, `schedule.jl`, `canvas.jl`, `sketch.jl`, `board.jl`, `calendar.jl`, `timelog.jl`, `signature.jl`, `save.jl`, `day.jl`, `ask.jl`, `changes.jl`, `chart.jl`, `columns.jl`, `contact.jl`, `filter.jl`, `forms.jl`, `gallery.jl`, `map.jl`, `sheet.jl`, `spreadsheet.jl`, `find.jl`).
- **Problem**: `BLOCKS` (`main.jl:12861`) is a shallow seam. Nine legacy block kinds (`sheet`, `spreadsheet`, `ui`, `mermaid`, `math`, `takeoff`, `schedule`, YAML/TOML front matter) predate it and bypass it completely. Even for registered blocks, `BlockKind` only carries four fields (`name`, `icon`, `view`, `html`), so adding or changing any block requires touching **14+ parallel dispatch sites** scattered across 45,000 lines of `main.jl`:
  - Caret step-over (`solid`)
  - Page layout (`keep_plain!` / `layout!`)
  - Sidebar outline (`outline`)
  - Search icon lookup (`block_icon`)
  - HTML export (`page_html`)
  - Insert menu (`INSERTS`)
  - Known/autocomplete language lists (`known_lang`, `NO_NAMES`, `shared_lang`)
  - Foreign-page / reply allowlists (`SHOWN_BLOCKS`, `REPLY_BLOCKS`)
  - Table data-source integration (`page_tables`, `table_kind`)
  - Named values / sum reactivity (`block_names`, `given_and_sums`)
  - Two separate fullscreen mechanisms (`ZoomView`/`Fillable` vs `can_fill`/`takeoff_over`/`full_block`/`full!`)
  - Whole-part keyboard entry (`keyboard_part`, `enter_part!`)
  - Per-frame ticking (`describe_window`'s 36 `*_tick!` calls)
  - Hardcoded 27-language list in `find.jl` (`WHATS`)
  Meanwhile, every block is split horizontally across a headless model file and a 1x–4x larger view/state/HTML-export section in `main.jl`, leaking drawing geometry (`signature.jl`, `sketch.jl`, `canvas.jl`), validation (`save.jl`), and duplicated `key: value` / `in: folder` parsing across the seam.
- **Solution**: Use Julia multiple dispatch on block types (matching Ladder's `AbstractDirectory` folder dispatch) rather than a function table. Map each fence language in `BLOCKS` to its block type (its view type, or a tag type for stateless/grid blocks), and dispatch `block_name`, `block_icon`, `block_insert`, `block_is_whole`, `block_is_code`, `block_safe`, `block_reply`, `block_outline`, `block_layout`, `block_html`, `block_tables!`, `block_table_kind`, `block_names`, `block_places`, `block_tick!`, `before_save!`, and `full!` with sensible defaults so each block only writes methods where it differs. Fold the legacy block kinds and the two fullscreen mechanisms into that dispatch seam, keeping `BlockKind` only as a thin compatibility adapter for extensions.
- **Benefits**: Strong **locality** (a block's behaviour lives in methods on its own type instead of 10–15 clusters across a 61k-line file) and high **leverage** (`main.jl`'s layout, outline, search, insert menu, fullscreen, and tick loops stop needing per-block edits, and extensions override behaviour with ordinary methods). Tests can exercise a block's parsing, interaction, and export through one seam.

---

## 2. Retire `webpage.jl` pass-throughs and consolidate the web / HTML / fetch stack

- **Files**: `webpage.jl`, `webpage.swift`, `web/view.jl`, `web/browser.jl`, `web/live.jl`, `web/context.jl`, `web/dom.jl`, `web/entities.jl`, `web/css.jl`, `web/files.jl`, `mime.jl`, `eml.jl`, `linkcard.jl`, `feeds.jl`, `remote.jl`, `main.jl` (L39390–L39690, L44299–L44715).
- **Problem**:
  - `webpage.jl` is a legacy WebKit renderer kept as a test oracle, yet `SentEmail`/`SentPage` in `main.jl:44427` renders via `web/` and constructs a dummy empty-strip `Webpages.Shot` solely to call seven one-line pass-throughs (`webpage.jl:170-176`) forwarding straight back to `web/select.jl`.
  - `web/view.jl` has no production caller except `web/browser.jl`, which never places `View` in the UI tree, pokes 12 of its fields, reimplements `draw`/`cursor`/`onkey`/`point`/`link` (accidentally dropping `<video controls>` click-to-toggle), double-parses HTML on load (`needs` then `Live.live`), and triple-throttles frames (`Live`, `View`, `Browser`). Meanwhile `SentPage` duplicates `Browser`'s multi-click/drag text selection state machine.
  - Across the repo: 4 HTML tokenizers/parsers (`web/dom.jl`, verbatim copy in `mime.jl`, regex parsers in `linkcard.jl` and `feeds.jl`), 4 HTML entity decoders, 3 Windows-1252 charset decoders, 5+ async `curl` fetchers (`web/files.jl`, `remote.jl`, `linkcard.jl`, `main.jl:fetches`, media downloads), and 5 URL helpers (with general URL `resolve` stranded inside `web/css.jl`). `eml.jl` is a thin wrapper over `mime.jl`.
- **Solution**: Remove `webpage.jl` from production paths (demoting `webpage.swift` to a test-only oracle if needed); collapse `web/view.jl` and shared page text selection into one deep rendered-page module shared by `Browser`, `HTMLBlock`, and `SentEmail`; merge `eml.jl` into `mime.jl`; consolidate HTML tokenization/entities, URL resolution, and async `curl` fetching into single deep modules.
- **Benefits**: Deleting pass-through layers and 3–5 copies of parsing/fetching code removes complexity outright (**leverage**). Encoding, CORS/retry, URL, and selection fixes happen once (**locality**).

---

## 3. Split `Editor` into a lightweight text-editing module and a Window shell, and move Folder / Agent adapters out of `main.jl`

- **Files**: `main.jl` (L1296–L1364, L32083–L32183, L44872–L60590), plus folder domain modules (`git.jl`, `news.jl`, `feeds.jl`, `podcasts.jl`, `blog.jl`, `desktop.jl`, `macfolders.jl`, `folders.jl`, `notes.jl`, `sites.jl`, `zip.jl`).
- **Problem**: `Editor` is a 67-field god-struct combining buffer editing, sidebar/navigation, window chrome, 29 duplicated preference fields (`SHARED`), and an untyped `e.nodes::Dict{Any,Any}` shadow-struct with 239 distinct key patterns (509 call sites). `Editor()` is instantiated in 8 embedded roles (main window, CSV cell editor, transclusion, agent prompt, agent reply, inline ask box, CAD field, CAD sheet), forcing `onkey(e::Editor, ...)` into a 100-line waterfall checking 5 host roles and 6 modal layers. Meanwhile, 13 built-in `AbstractDirectory` folder adapters (7,842 lines) and Agent mode (4,689 lines) remain inlined in `main.jl` alongside ~200 global mutable containers and 19 nearly identical `*Button` structs.
- **Solution**: Separate the lightweight text/page editor from the Window/Workspace container (replacing untyped `e.nodes` keys with explicit typed state and replacing the 5 host-role branches in `onkey` with a host adapter), move built-in Folder adapters out of `main.jl` alongside their domain modules (folding single-caller `podcasts.jl` into news/feeds), move Agent mode into its own module, and collapse the 19 boilerplate button structs into one parameterized button module.
- **Benefits**: Dramatic **locality** — `main.jl` shrinks by tens of thousands of lines and each folder kind becomes self-contained behind `AbstractDirectory`. Embedded editors become independently testable without booting a full window.

---

## 4. Consolidate duplicated platform, parsing, and macOS FFI primitives

- **Files**: `cad/gl.jl`, `web/gl.jl`, `cad/json.jl`, `centient.jl`, `main.jl` (L5608–L5795), `transcribe.jl`, `map.jl`, `webpage.jl`, `desktop.jl`, `macfolders.jl`, `blog.jl`, `kate.jl`, `chart.jl`, `csv.jl`, `filter.jl`, `forms.jl`.
- **Problem**:
  - Offscreen macOS OpenGL 4.1 (`CGL`) setup is duplicated in `cad/gl.jl` and `web/gl.jl`; `cad/gl.jl:274` calls `CGLDestroyContext` inside a GC finalizer (unsafe), whereas `web/gl.jl:87-100` already fixed this with a `SpinLock` deferred-free queue.
  - Swift helper compilation & caching is copied 3 times (`transcribe.jl`, `map.jl`, `webpage.jl`), and `webpage.jl` imports `map.jl` just for `kept!`.
  - JSON parsing/serialization is hand-written 3 times (`main.jl`, `cad/json.jl`, `centient.jl`, plus a mini parser in `web/embed.jl`).
  - macOS `NSURL` metadata is duplicated in `desktop.jl` and `macfolders.jl` (with a 3rd `made(path)` in `blog.jl` reading raw `uv_stat_t` bytes), while `macfolders.jl` mixes 5 unrelated concerns (NSURL dates, `kMDItemWhereFroms`, screencapture prefs, `.DS_Store`/Trash, Vision OCR).
  - Misplaced utilities create tangled imports: `kate.jl` owns the generic XML parser (forcing `feeds.jl` to load ~180 syntax-highlighting XML files), `chart.jl` owns `number()` (imported by `csv.jl`, `filter.jl`, `forms.jl`), `save.jl` owns `host`/`isurl` (imported by `LoadView`), `git.jl` owns `ago()` (imported by Notes/Folders). Front-matter parsing (4 copies), date parsing (4+ copies), CSV quoting/splitting (2 copies), and natural sorting (3 copies) are also duplicated.
- **Solution**: Extract a small set of deep, dependency-free foundation modules (offscreen CGL surface, JSON, XML, Swift helper runner, macOS file metadata, tabular/date/front-matter parsing) and remove cross-feature utility imports.
- **Benefits**: Fixes real hazards once (**locality**), eliminates accidental load-time costs (**leverage**), and enables fast isolated unit tests.

---

## 5. Deepen the test & runtime configuration seam

- **Files**: `test/hot.jl`, `test/hot`, `app/app.jl` (L223–L442), `main.jl` (global `Ref` hooks & `settings_file()`), and 166 `test/*_test.jl` files.
- **Problem**:
  - 78 of 218 test files redefine `K.settings_file()` via `@eval K settings_file() = ...`.
  - 49 test files mutate ~20 global production `Ref` hooks (`RUN_WAIT`, `AGENT_COMMAND`, `BROWSER`, `WALLPAPER`, etc.), often without restoring them.
  - 112 test files poke private `e.nodes[...]` cache keys directly.
  - 161 headless-window tests (plus `app/app.jl`) each copy-paste 10–25 line `click`/`press`/`type*`/`frame` helpers.
  - Under `test/hot all` (one shared `main.jl` module), these `@eval` patches and globals leak across tests.
- **Solution**: Pass an explicit environment/configuration adapter when opening a window/workspace (settings path, clock, runners/fetchers) so production drops global test `Ref`s and tests never `@eval`-patch `main.jl`. Extract one shared headless test-driver module used by both `test/` and `app/app.jl`.
- **Benefits**: Restores **the interface as the test surface**, deletes ~2,000+ lines of duplicated test-harness glue (**leverage**), and makes `test/hot all` deterministic.

---

## 6. Narrow the `cad/view.jl` ↔ `main.jl` seam and clean up internal `cad/` duplication

- **Files**: `cad/view.jl`, `cad/sketch.jl`, `cad/pieces.jl`, `main.jl` (L53228–L53800), `test/design_test.jl`.
- **Problem**: `cad/view.jl` (4,393 lines) communicates with `main.jl` via 3 global `Ref` hooks (`FIELD`, `CODE_LOOK`, `SHEET`) and a 17-method duck-typed protocol that `main.jl` monkey-patches with 25+ method extensions while reaching into `cad/` internals (`Designs.Designs.save!`, `Designs.field_look(t)[2:end]`, `Designs.Press`, `Designs.Ink`). Inside `cad/`, `cad/view.jl` reimplements menu/card/button widgets, reaches into MiniFB's private `gpus` dict (with an FBO leak at `cad/view.jl:3569`), and `cad/` keeps two sketch region solvers (640×640 raster flood-fill in `cad/sketch.jl` vs exact planar curve arrangement in `cad/pieces.jl`). `test/design_test.jl` (1,820 lines) imports all of `main.jl` even for pure `cad/` unit checks.
- **Solution**: Replace the 3 `Ref`s and 25 monkey-patched methods with one explicit host adapter passed into `DesignView`; organize `cad/view.jl` internally without widening its interface; evaluate retiring the raster flood-fill in favor of `cad/pieces.jl`; split pure `cad/` tests from `main.jl` integration tests.
- **Benefits**: Turns a brittle bidirectional monkey-patch contract into a clean one-way seam (**locality**) and speeds up `cad/` tests.

---

## 7. Prune dead app-bundling code and tighten the `app/` + `release.jl` seam

- **Files**: `app/record.jl`, `app/start.jl`, `app/bundle.jl`, `app/build.jl`, `app/app.jl`, `release.jl`, `update.jl`.
- **Problem**: `app/record.jl` (351 lines of Julia 1.13 compiler-internal trimming overrides and GLFW wrappers) is dead code for Ladder (`app/build.jl:9-10` notes `APP_TRIM` must stay `no`, and `app/app.jl:535` never passes a `record` callback), yet `app/start.jl:145` unconditionally includes it into every build. `release.jl` couples to `bundle.jl` and `build.jl` via implicit top-level `include()` variable leaks (`app`, `version`, `out`, `uncommitted`), and app identity/paths/asset lists are duplicated across 2–3 files.
- **Solution**: Delete `app/record.jl` and its hook in `app/start.jl`; connect `bundle.jl`, `build.jl`, and `release.jl` via explicit function calls; centralize app metadata/paths/asset lists in one place.
- **Benefits**: Removes 351 lines of fragile compiler-internal overrides from every shipped build and makes the build/release pipeline predictable (**locality**).
