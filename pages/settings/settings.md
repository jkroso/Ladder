# Settings

Ladder keeps these choices, and uses them the next time it opens. Each one changes every window as you choose it. Press ⌘W to close this window.

Five more pages have the rest of the settings. Hold ⌘ and click a link to go there. To come back, press ⌘⌥←.

- [Code editor](code-editor.md) has how code shows.
- [Terminal](terminal.md) has a terminal's caret, what selecting copies, the ⌥ key and the bell.
- [Key bindings](key-bindings.md) has the keys of each command.
- [Ignored files](ignored-files.md) lists the files and folders that Ladder leaves out.
- [Startup](startup.md) is the page that Ladder opens the first time, and the code that it runs when it starts. After that, Ladder opens where you were when you quit.

These pages show what a page can do:

- [Welcome](../welcome.md) has an example of everything that Ladder does.
- [Components](../components.md) has the buttons, menus, sliders and other parts that a block can show.
- [Julia](../julia.md) runs code where it is.
- [Schedule](../schedule.md) plans a job, with the days of each task.
- [Counter](../counter.md) makes a new kind of block.
- [Data centres in space](../space-data-centres.md) is an explanation that you explore by dragging its numbers.

## Colours

```ui
names = ["Sepia", "Paper", "Night"]
RadioGroup(labels=names, selected=findfirst(==(page_theme()), names),
           onchange=group -> page_theme!(names[group.selected]))
```

## Font

```ui
fonts = unique([page_font(), "Charter", "Helvetica Neue", "Georgia", "Palatino", "Lucida Grande", "Menlo"])
Box(width(240px), Dropdown(options=fonts, families=fonts, selected=1, onchange=dropdown -> page_font!(fonts[dropdown.selected])))
```

## Font weight

```ui
weights = page_weights()
length(weights) < 2 ? Text("$(page_font()) has one weight for text: $(page_weight()).", size=page_text_size() * 1px) :
  Box(width(240px), Dropdown(options=weights, selected=something(findfirst(==(page_weight()), weights), 1),
                             onchange=dropdown -> page_weight!(weights[dropdown.selected])))
```

The list has the weights that the font has, up to Semibold, by the names that the font gives them. Bold text and headings are heavier than the rest. Most of the fonts above have one weight for text. Helvetica Neue has five, from UltraLight to Medium.

If you choose a font that doesn't have your weight, the text shows the font's nearest weight. Ladder keeps your choice for the next font that has it.

## Text size

```ui
Slider(value=page_text_size(), min=11, max=40, step=1, format=size -> round(Int, size),
       onchange=slider -> page_text_size!(slider.value))
```

The number is the height of the text in pixels. ⌘+ and ⌘- change it by one, and ⌘0 puts it back to 17.

## Page width

```ui
Slider(value=page_width(), min=400, max=1200, step=20, format=width -> round(Int, width),
       onchange=slider -> page_width!(slider.value))
```

The number is the width of the page in pixels, while the text is 17 pixels tall. Bigger text gets a wider page, so a line holds as many words as before. A window that is too narrow for the page shows it as wide as it can.

## Top bar

```ui
say(text) = Text(text, size=page_text_size() * 1px)
names = bar_hidings()
Row(Alignment.Center, child_gap=12px, say("Hide the top bar"),
    Box(width(200px), Dropdown(options=names, selected=something(findfirst(==(page_bar_hides()), names), length(names)),
                               onchange=dropdown -> page_bar_hides!(names[dropdown.selected]))))
```

These are the choices that a Mac gives for its menu bar. With Always, the top bar hides in every window. With In full screen only, it hides while a window fills the screen, after you click the green button at the top left of the window.

While the bar hides, the page goes up to the top of the window. Rest the mouse at the top edge of the window, and the top bar slides down over the page, with the window's close, minimise and zoom buttons. The bar slides back up when you move the mouse off it. It stays while a list or a menu of the bar is open. ⌘F shows the bar too, because the search opens under it.

## Spelling

```ui
Checkbox(label="Check spelling", checked=page_spelling(), onchange=box -> page_spelling!(box.checked))
```

With this on, a word that the Mac's dictionary doesn't have gets a line of red dots under it. Right-click the word to see the words it may have been meant to be, or to teach the dictionary the word. Code isn't checked.

## Links

```ui
Checkbox(label="Show a page when I hold ⌘ over its link", checked=page_peeks(), onchange=box -> page_peeks!(box.checked))
```

With this on, hold ⌘ and rest the mouse on a link to a page. A card under the link shows the start of that page. A link to a heading shows the part under that heading. With this off, the card says only where the link goes.

## Agent

```ui
names = agent_names()
Box(width(240px), Dropdown(options=names, selected=something(findfirst(==(page_agent()), names), 1),
                           onchange=dropdown -> page_agent!(names[dropdown.selected])))
```

This is the agent that Ladder starts when you ask for a change to a part of the window, or ask about it. Its logo is the button on the line round a part that you ⌘⌥-click. Its command must be on this Mac: `claude` for Claude, `agy` for Antigravity, `codex` for Codex and `grok` for Grok.

When an agent shares the page with you, Ladder asks that agent instead, and the button shows its logo.

```ui
Row(Alignment.Center, child_gap=18px,
    [Checkbox(label=name, checked=agent_listed(name), onchange=box -> agent_listed!(name, box.checked)) for name in every_agent()]...)
```

These boxes say which agents Ladder lists for you to choose from: in the menu above, in the menu of the agent's name in agent mode, and for the command Switch Agent. Take the tick from an agent that you don't use, like one that isn't on this Mac. The agent that's chosen now is always listed.

## News

```ui
say(text) = Text(text, size=page_text_size() * 1px)
days = [1, 3, 7, 14, 30, 0]
names = ["A day", "3 days", "A week", "2 weeks", "30 days", "For ever"]
Row(Alignment.Center, child_gap=12px, say("Keep each article for"),
    Box(width(160px), Dropdown(options=names, selected=something(findfirst(==(news_days()), days), 3),
                               onchange=dropdown -> news_days!(days[dropdown.selected]))))
```

```ui
say(text) = Text(text, size=page_text_size() * 1px)
whens = ["daily", "asked", "off"]
Row(Alignment.Center, child_gap=12px, say("Ladder's agent gets the news"),
    RadioGroup(labels=["Once a day", "When I ask", "Never"], selected=something(findfirst(==(news_agents()), whens), 1),
               onchange=group -> news_agents!(whens[group.selected])))
```

A folder of news is a newspaper that agents write for you. Its page `Interests.md` says the kinds of news that you want, in your own words, with a heading for each. Ladder deletes each article when it's older than the time in the list. Choose For ever to keep every article.

With Once a day, the agent above reads each section of `Interests.md` the first time that you open the folder each day. It searches the web and writes the articles. With When I ask, it does that only when you click the round arrow at the right of the top bar of the front page.

Choose Never when an agent of your own writes the articles, like one that runs on a server. Ladder then starts no agent, and has no button that gets the news unless the folder has feeds. It still shows each article that the other agent writes, and deletes it when it's too old. Ladder keeps a file called `AGENTS.md` in each folder of news, which tells the other agent what to write and where. The [Welcome](../welcome.md) page has an example of an article, and says how to add feeds and mark the articles that you like.

```ui
Checkbox(label="Start Grok to talk with about the news when I open it", checked=news_companion(), onchange=box -> news_companion!(box.checked))
```

With the box on, Ladder starts Grok in a terminal of its own, behind the page, when you open a folder of news. It's your reading companion: on any article, select words, right-click and choose Ask Grok…, and its answer shows under them. It's one session for all your reading, so it remembers what you talked about. The terminal's file, `Talk with Grok.vt` in the folder of today's articles, keeps the talk: open it to read it, or to talk with Grok there. It goes when that day's articles go. Grok ends when you close the tab of the news, and Ladder starts another the next time that you open it.

To start, press ⌘⇧P and choose Open News. Ladder makes the folder News in your home folder, and shows it.

## Caret

```ui
Checkbox(label="Move the caret smoothly", checked=page_glide(), onchange=box -> page_glide!(box.checked))
```

With this on, the caret doesn't jump to its new place as you type or press an arrow key. It moves there in a short time. A click still puts it there at once, and so does a key that goes to the end of a line.

## Saving

```ui
Checkbox(label="Save a page when I leave its window", checked=page_autosave(), onchange=box -> page_autosave!(box.checked))
```

Ladder writes a page to its file when you press ⌘S. With this on, it also writes the pages of a window when you click another window or change to another app. A page that has no file yet stays as it is.

## Default app

```ui
app = markdown_app()
say(text) = Text(text, size=page_text_size() * 1px)
app == "Ladder" ? say("Ladder opens the Markdown files on this Mac.") :
!app_installed() ? say("Put the Ladder app in your Applications folder, then come back to this page.") :
  Column(Alignment.Start, child_gap=12px,
         say(isempty(app) ? "No app is set to open Markdown files." : "$app opens the Markdown files on this Mac now."),
         Button(label="Make Ladder the default app", onclick=button -> default_app!()))
```

The default app is the one that opens a Markdown file when you double-click it in the Finder. macOS asks you to confirm the change.

## Ignored files

To ignore a file or a folder that you never look at, right-click it in the sidebar and choose Ignore. Ladder then leaves it out, as it leaves out the files whose names start with a dot. The sidebar, the folder pages and the searches don't show it. Ladder doesn't change the file, so the Finder still shows it. To see the files that you ignore, press ⌘⇧. as you do for hidden files.

The page [Ignored files](ignored-files.md) lists them. To show a file again, delete its line on that page and save the page.

## Updates

```ui
Checkbox(label="Update Ladder automatically", checked=app_updates(), onchange=box -> app_updates!(box.checked))
```

```ui
say(text) = Text(text, size=page_text_size() * 1px)
offer = update_offer()
isempty(offer) ? say(update_news()) :
  Column(Alignment.Start, child_gap=12px, say(update_news()), Button(label=offer, onclick=button -> update!()))
```

With this on, Ladder looks for a newer version when it opens, and once a day after that. It gets the new version while you work. The new version takes the place of this one when you quit Ladder. To look for one, Ladder asks GitHub which version is the newest. It sends nothing about you or your files.

```ui
say(text) = Text(text, size=page_text_size() * 1px)
offer = extension_offer()
isempty(offer) ? say(extension_news()) :
  Column(Alignment.Start, child_gap=12px, say(extension_news()), Button(label=offer, onclick=button -> update_extensions!()))
```

The box gets the new code of your extensions too: each kind of folder or block that Ladder got from GitHub, like `github.com/jkroso/Media.lad`. Ladder gets the new code while you work, and it loads the next time that Ladder opens. Ladder doesn't change an extension that's a link to a folder on this Mac, or one that has changes of your own.

---

This page is a Markdown file, like any other in Ladder. To see the code of a setting, hold ⌥ and click it.
