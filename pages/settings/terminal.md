# Terminal

These settings are for a terminal: a file whose name ends in `.vt`, which runs a shell. Each one changes every terminal as you choose it.

The other settings are on the [Settings](settings.md) page. A terminal has the font and the size of code, which are on the [Code editor](code-editor.md) page.

## Caret

```ui
shapes = ["block", "bar", "underline"]
RadioGroup(labels=["Block", "Bar", "Underline"], selected=something(findfirst(==(term_caret()), shapes), 1),
           onchange=group -> term_caret!(shapes[group.selected]))
```

```ui
Checkbox(label="Blink the caret", checked=term_blink(), onchange=box -> term_blink!(box.checked))
```

The caret shows where the next character that you type goes. A block covers the whole character, a bar stands before it, and an underline goes under it. A caret that blinks stays lit while you type, and blinks when you stop.

A program can ask for a caret of its own, as vim and Neovim can for each of their modes. Its caret then shows in place of yours, until the program asks for yours again.

While the terminal doesn't have the keyboard, a block shows as an outline, and no caret blinks.

## Selecting

```ui
Checkbox(label="Copy text when I select it", checked=term_copies(), onchange=box -> term_copies!(box.checked))
```

With this on, the text that you select with the mouse goes to the clipboard when you let go of the button, so you don't have to press ⌘C. It's the same for two clicks, which select a word, and for three, which select a line. ⌘A selects everything, but doesn't copy it.

## ⌥ key

```ui
Checkbox(label="Use ⌥ as the Meta key", checked=term_meta(), onchange=box -> term_meta!(box.checked))
```

With this off, ⌥ types the characters that it types everywhere on a Mac, like ∫ for ⌥B. With this on, ⌥ and a key send Esc and then the key, as the Meta key of other computers does. The shell then goes back a word for ⌥B, goes on a word for ⌥F, and deletes the next word for ⌥D. Emacs uses ⌥ for many of its commands in this way.

⌥← and ⌥→ move by words, and ⌥⌫ deletes a word, with this on or off.

## Bell

```ui
whats = ["flash", "sound", "none"]
RadioGroup(labels=["Flash the terminal", "Play the alert sound", "Nothing"], selected=something(findfirst(==(term_bell()), whats), 1),
           onchange=group -> term_bell!(whats[group.selected]))
```

A program rings the bell to get your attention, as the shell does when Tab finds nothing to complete. The alert sound is the one that you chose in the Sound settings of your Mac. A terminal that you can't see plays the sound too, but it can't flash.

## Lines kept

```ui
counts = [1000, 10000, 50000]
RadioGroup(labels=["1,000", "10,000", "50,000"], selected=something(findfirst(==(term_lines()), counts), 2),
           onchange=group -> term_lines!(counts[group.selected]))
```

This is how many lines a terminal keeps after they go off the top. Scroll up, or press ⇧PageUp, to read them again. When the terminal has more, it forgets the oldest. The terminal's file keeps the same lines, so they're there when you open the file again.

In a wide window each line takes about 2 KB of memory, so 50,000 lines can take 100 MB for each terminal.
