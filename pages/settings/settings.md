# Settings

Ladder keeps these choices, and uses them the next time it opens. Each one changes every window as you choose it. Press ⌘W to close this window.

Three more pages have the rest of the settings. Hold ⌘ and click a link to go there. To come back, press ⌘⌥←.

- [Code editor](code-editor.md) has how code shows.
- [Key bindings](key-bindings.md) has the keys of each command.
- [Startup](startup.md) is the page that Ladder opens first, and the code that it runs when it starts.

These pages show what a page can do:

- [Welcome](../welcome.md) has an example of everything that Ladder does.
- [Components](../components.md) has the buttons, menus, sliders and other parts that a block can show.
- [Julia](../julia.md) runs code where it is.
- [Schedule](../schedule.md) plans a job, with the days of each task.
- [Counter](../counter.md) makes a new kind of block.

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

This is the agent that Ladder starts when you ask for a change to a part of the window, or ask about it. Its logo is the button on the line round a part that you ⌘⌥-click. Its command must be on this Mac: `claude` for Claude, `codex` for Codex, `gemini` for Gemini and `grok` for Grok.

When an agent shares the page with you, Ladder asks that agent instead, and the button shows its logo.

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

---

This page is a Markdown file, like any other in Ladder. To see the code of a setting, hold ⌥ and click it.
