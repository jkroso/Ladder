# The names that a window gives the code of its pages, like `page_theme()` and `page_theme!("Night")`

@use "./sheet" units
@use "./update" => Update
@use "./news" => News
@use Colors: @colorant_str
@use "./base" exports...
@use "./live_view" USUAL share! reads! default_app!
@use "./terminal_view" TERM_BELLS term_setting! term_choice
@use "./agent/kinds" AGENT_KINDS agent_listed! listed_agents
@use "./news_page" NEWS_PRUNED
@use "./markdown_app" app_path
@use "./commands" BUNDLES KeyList PAGE_NAMES bundle!
@use "./app_updates" update_act! extensions_news extensions_act! update_news
@use "./settings" Setting SETTINGS HIDINGS
@use "./bar_hides" hiding_name

export page_getter, page_setter

# --- the names of a page's code ---------------------------------------------------------
#
# The code of a page reads and changes the settings by name, with no line that
# loads the names. The settings page is such a page: its live blocks call
# `page_theme()` to show the colours, and `page_theme!("Night")` when you
# choose others. A setting's two names are in its row of SETTINGS, in
# settings.jl. The names that are no setting's two are in `sandbox`.

"""
What the code of a page of `e` calls to read the setting `s`: a function that
gives the setting as a page's code has it. It notes that the live block that's
running read the setting, so that the block runs again when the setting changes.
"""
page_getter(e, s::Setting) = () -> (foreach(name -> reads!(e, name), s.reads); s.shown(e))

"What the code of a page of `e` calls to change the setting `s`: a function of the new value, as a page's code has it"
page_setter(e, s::Setting) = x -> s.set(e, s.takes(x))

"""
The names that the window gives the code of its pages, with no line that
loads them, in a module of the window. No code runs in this module. Each
page's module has its names (see `usual_module`), and a name that acts on a
window, like `page_theme!`, acts on this window when it calls this module's.
"""
sandbox(e) = begin
  made = window_modules(e).sandbox
  made === nothing || return made
  m = Module(Symbol("⭒window"))
  # Kip by the module that's loaded here, not by name. A built app can't find a package by name.
  Core.eval(m, :(const Kip = $Kip))
  Core.eval(m, :(using .Kip))
  foreach(path -> share!(m, path), USUAL)
  include_string(m, "@use \"github.com/jkroso/URI.jl/FSPath\" FSPath @fs_str")
  Core.eval(m, :(const $(Symbol("@colorant_str")) = $(var"@colorant_str")))
  # A live block can read and set each setting that has a name for a page's code: `page_theme()` gives "Sepia",
  # "Paper" or "Night", and `page_theme!("Night")` sets it. The rows of SETTINGS say what each name is and gives.
  for s in SETTINGS
    s.page === :none && continue
    Core.eval(m, :(const $(s.page) = $(page_getter(e, s))))
    Core.eval(m, :(const $(Symbol(s.page, :!)) = $(page_setter(e, s))))
  end
  # ... and the weights that the font of the page's text has, by name, like "Light" and "Regular"
  Core.eval(m, :(const page_weights = $(() -> (reads!(e, :font); [w.label for w in text_weights(e.font)]))))
  # ... and when the top bar can hide, by the names that the settings page gives each choice
  Core.eval(m, :(const bar_hidings = $(() -> [hiding_name(how) for how in HIDINGS])))
  # ... and the names that the agent can be
  Core.eval(m, :(const agent_names = $(() -> (reads!(e, :agents); reads!(e, :ai); listed_agents(e)))))
  # ... and every agent that Ladder can start, and whether each is in the lists that you choose an agent from
  Core.eval(m, :(const every_agent = $(() -> [k.name for k in AGENT_KINDS])))
  Core.eval(m, :(const agent_listed = $(name -> (reads!(e, :agents); reads!(e, :ai); String(name) in listed_agents(e)))))
  Core.eval(m, :(const agent_listed! = $((name, on) -> agent_listed!(e, String(name), Bool(on)))))
  # ... and the fonts that code can have, by name. `code_family(name)` gives the font's own name, to draw the name in.
  Core.eval(m, :(const code_fonts = $(() -> font_label.(unique([code_fonts(); e.code_font])))))
  Core.eval(m, :(const code_family = $(name -> font_family(String(name)))))
  # ... and the weights that the font of code has, by name
  Core.eval(m, :(const code_weights = $(() -> (reads!(e, :code_font); [w.label for w in text_weights(e.code_font)]))))
  # ... and the terminal's: the caret's shape, "block", "bar" or "underline", and whether it blinks; whether what the
  # mouse selects is copied; whether ⌥ is a Meta key; what a program's bell does, "flash", "sound" or "none"; and
  # how many lines of the past a terminal keeps; and whether a program that said how to start again does so when
  # Ladder opens again. See "a terminal's file".
  Core.eval(m, :(const term_caret = $(() -> (reads!(e, :terminal); String(TERM_SETTINGS.caret)))))
  Core.eval(m, :(const term_caret! = $(name -> term_setting!(e, :caret, term_choice(TERM_CARETS, name)))))
  Core.eval(m, :(const term_blink = $(() -> (reads!(e, :terminal); TERM_SETTINGS.blink))))
  Core.eval(m, :(const term_blink! = $(on -> term_setting!(e, :blink, Bool(on)))))
  Core.eval(m, :(const term_copies = $(() -> (reads!(e, :terminal); TERM_SETTINGS.copies))))
  Core.eval(m, :(const term_copies! = $(on -> term_setting!(e, :copies, Bool(on)))))
  Core.eval(m, :(const term_meta = $(() -> (reads!(e, :terminal); TERM_SETTINGS.meta))))
  Core.eval(m, :(const term_meta! = $(on -> term_setting!(e, :meta, Bool(on)))))
  Core.eval(m, :(const term_bell = $(() -> (reads!(e, :terminal); String(TERM_SETTINGS.bell)))))
  Core.eval(m, :(const term_bell! = $(name -> term_setting!(e, :bell, term_choice(TERM_BELLS, name)))))
  Core.eval(m, :(const term_lines = $(() -> (reads!(e, :terminal); TERM_SETTINGS.most))))
  Core.eval(m, :(const term_lines! = $(n -> term_setting!(e, :most, term_choice(TERM_PASTS, Int(n))))))
  Core.eval(m, :(const term_again = $(() -> (reads!(e, :terminal); TERM_SETTINGS.again))))
  Core.eval(m, :(const term_again! = $(on -> term_setting!(e, :again, Bool(on)))))
  # ... and the key bindings. `key_bundles()` gives the names of the bundles, and `key_bundle()` the one that's chosen.
  # `key_list()` shows each command with its keys, and a click on one changes them. `keys_changed()` is true when a
  # command has other keys than the bundle's, and `key_reset!()` gives every command the bundle's keys again.
  Core.eval(m, :(const key_bundles = $(() -> String[first(b) for b in BUNDLES])))
  Core.eval(m, :(const key_list = $(() -> own!(e, KeyList()))))
  Core.eval(m, :(const keys_changed = $(() -> (reads!(e, :bundle); reads!(e, :rebound); !isempty(e.rebound)))))
  Core.eval(m, :(const key_reset! = $(() -> bundle!(e, e.bundle))))
  # ... and the app that opens Markdown files: `markdown_app()` gives its name, like "Ladder", or "" when macOS can't say.
  # `default_app!()` asks macOS to make that app Ladder. It gives false when the Ladder app isn't installed.
  # `app_installed()` is true when the Ladder app is on this Mac.
  Core.eval(m, :(const markdown_app = $(() -> (reads!(e, :app); app_name(markdown_app())))))
  Core.eval(m, :(const app_installed = $(() -> (reads!(e, :app); !isempty(app_path())))))
  Core.eval(m, :(const default_app! = $(() -> default_app!(e))))
  # ... and the app's own updates. `app_updates()` is true when the app gets a newer version without being asked.
  # `update_news()` says how far an update has got. `update_offer()` is what a button can do about it now, like
  # "Check now", or "" for nothing. `update!()` does that.
  Core.eval(m, :(const update_news = $(() -> update_news(e))))
  Core.eval(m, :(const update_offer = $(() -> (reads!(e, :updates); reads!(e, :update); Update.label(Update.own())))))
  Core.eval(m, :(const update! = $(() -> update_act!(e))))
  # ... and the extensions' new code from GitHub, the same way: `extension_news()`, `extension_offer()`, like
  # "Restart Ladder", and `update_extensions!()`.
  Core.eval(m, :(const extension_news = $(() -> extensions_news(e))))
  Core.eval(m, :(const extension_offer = $(() -> (reads!(e, :updates); reads!(e, :extensions); Update.label(Update.extensions())))))
  Core.eval(m, :(const update_extensions! = $(() -> extensions_act!(e))))
  # ... and the news: `news_days()` is how many days Ladder keeps an article, 0 for ever, and `news_agents()` is
  # when Ladder's own agents get the news: "daily", "asked" or "off". See "a folder of news".
  Core.eval(m, :(const news_days = $(() -> (reads!(e, :news); News.keep_days()))))
  Core.eval(m, :(const news_days! = $(n -> (News.keep_days!(Int(n)); empty!(NEWS_PRUNED); nothing))))
  Core.eval(m, :(const news_agents = $(() -> (reads!(e, :news); String(News.agents())))))
  Core.eval(m, :(const news_agents! = $(when -> (News.agents!(Symbol(when)); nothing))))
  Core.eval(m, :(const news_companion = $(() -> (reads!(e, :news); News.companion()))))
  Core.eval(m, :(const news_companion! = $(on -> (News.companion!(Bool(on)); nothing))))
  # ... and the names that code from the startup page adds
  foreach(f -> f(m, e), values(PAGE_NAMES))
  # The units that a sheet has, from Units.jl, so that code can work with lengths, times and so on: 12m * 2.4m.
  # They come in with `using`, so a name that a block makes or loads for itself wins over a unit with that name.
  Core.eval(m, :(const SheetUnits = $(units())))
  Core.eval(m, :(using .SheetUnits))
  window_modules(e).sandbox = m
end
