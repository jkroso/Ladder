# Components

Each block on this page is a `ui` code block. Its code makes one of the components in `Interface/Semantic`, and the page shows it. Try them: each one keeps what you do to it until its code changes.

To see the code of a block, hold ⌥ and click the block. A block can use each component by its name, with no line that loads it. A block can make a layout too, like a `Column` with components in it.

## A component in a line of text

A component can go in a line of text too. Write a `!` and then its code between backticks: here is a switch !`Toggle(on=true)` and the folder of this page, !`fs"."`. The page [welcome.md](welcome.md#sums-in-a-line-of-text) has sums in a line of text.

## Checkboxes and switches

```ui
Column(Checkbox(label="Check the spelling", checked=true),
       Checkbox(label="Use smart quotes"),
       Checkbox(label="Wrap long lines", checked=true))
```

```ui
switch(name, on) = Row(child_gap=12px, Toggle(on=on), Text(name, size=17px))
Column(Alignment.Start, child_gap=8px, switch("Wi-Fi", true), switch("Bluetooth", false))
```

## Choices

```ui
names = ["Sepia", "Paper", "Night"]
RadioGroup(labels=names, selected=findfirst(==(page_theme()), names),
           onchange=group -> page_theme!(names[group.selected]))
```

These choices set the colours of the page. `page_theme()` gives the name of the colours in use, and `page_theme!("Night")` changes them.

Click the box to open its menu. The font you pick becomes the font of the page's text.

```ui
fonts = ["Charter", "Helvetica Neue", "Menlo", "Lucida Grande"]
Box(width(240px), Dropdown(options=fonts, families=fonts, selected=something(findfirst(==(page_font()), fonts), 1),
                           onchange=dropdown -> page_font!(fonts[dropdown.selected])))
```

## Numbers and colours

Drag the slider, or click it and press ← and →. It sets the size of the page's text, and shows the size as a number.

```ui
Slider(value=page_text_size(), min=11, max=40, step=1, format=size -> round(Int, size),
       onchange=slider -> page_text_size!(slider.value))
```

```ui
ColorPicker()
```

## 3D models

The viewer shows the model in an STL file or a 3MF file, the kinds of file that a 3D printer's program reads. Drag the model to turn it. Hold ⌘ and scroll to make it bigger or smaller. Click it twice to put it back as it was.

```ui
STLViewer("knot.stl")
```

Under the model are its number of triangles and its width, depth and height, in the units of its file. The path can start from the folder of this page, as `knot.stl` does. Give the viewer a `height` or a `color` to change how it looks.

## Sound and video

A player plays a sound file. Click its round button to play the file and to stop it. The bars beside the button are tall where the sound is loud. Click a bar, or drag along the bars, to go to that part of the file. This one plays a sound that every Mac has.

```ui
AudioPlayer("/System/Library/Sounds/Glass.aiff")
```

A second player plays a video. Its picture is over the button, and a click on the picture plays the video and stops it too. This video shows the model from the section above as it turns.

```ui
VideoPlayer("knot.mp4")
```

While the mouse is over a player, or while its file plays, a small circle shows on the player's bottom edge. It says how fast the file plays. 1× is as fast as it was recorded. Click the circle to play at 1½×, then 2×, then ½×, then 1× again. Voices keep their own pitch at each speed.

Once you've clicked a player, these keys work:

- The space bar plays and stops.
- ← and → go back and on by 5 seconds.
- < and > play slower and faster, by a quarter at a time, from ½× to 2×.

One file plays at a time, and it plays on while you scroll the page. Give the video player a `height` to make its picture bigger or smaller. macOS plays the files, so the players take what QuickTime takes: MP3, M4A, WAV, AIFF and FLAC sound, and MP4 and MOV video.

A recorder records from the microphone into a file. Click its red button to start, and click it again to stop. While it records, the bars show how loud the sound is. Then it's a player for what it recorded. This one records into `memo.m4a`, beside this page. If that file is there already, the recorder is a player from the start, so delete the file to record again.

```ui
AudioRecorder("memo.m4a")
```

The first time a recorder starts, macOS asks whether the app may use the microphone. The recording goes on until you stop it, even if you go to another page.

## Diagrams

`Mermaid` draws a diagram from a few lines of text. The first line says what kind of diagram it is, and the lines after it say what's in it. This one shows who says what to whom, from the top down.

```ui
Mermaid("""
  sequenceDiagram
    actor You
    participant Page
    You->>Page: Type a line
    Page-->>You: Show the diagram
  """)
```

It draws nine kinds: `flowchart`, `sequenceDiagram`, `stateDiagram-v2`, `classDiagram`, `pie`, `mindmap`, `erDiagram`, `gantt` and `timeline`. A diagram takes the page's font and colours. A page needs no `ui` block for a diagram, because a code block in the language `mermaid` shows one too. The page [welcome.md](welcome.md) has an example.

## Shadows

A container can cast a shadow. `shadow(x, y, blur)` moves it right and down, then blurs it. You can give it a colour, and `spread` makes it bigger. Change a number in the code to see what it does.

```ui
card(name, cast) = Box(width(150px), height(90px), padding(16px), radius(10px), background("white"), cast,
                       Text(name, size=15px, color=rgb(40, 40, 40)))
Row(padding(22px, 28px), child_gap=40px,
    card("Soft", shadow(0, 6, 18)),
    card("Hard", shadow(6, 6, 0, "gray")),
    card("Glow", shadow(0, 0, 14, "dodgerblue", spread=2px)))
```

The editor uses a shadow under each thing that floats over the page: the file finder that ⌘O opens, the list of names under a sheet and the bar of buttons over a table.

## Text

Click the box and type. Press Escape to go back to the page.

```ui
Box(width(320px), TextInput(placeholder="Type your name"))
```

```ui
Row(child_gap=24px, KeyCombo(:S, :cmd), KeyCombo(:Z, :cmd, :shift), KeyCombo(:P, :cmd), KeyCombo(:ArrowUp, :opt))
```

Move the mouse over the box to see its tooltip.

```ui
Tooltip("Move the mouse here", "A tooltip can hold any node", placement=:right)
```

## Trees

Click a name with an arrow to open it. Use the arrow keys to move through the tree. A tree and a menu each have an `Item`, so the block has a line that loads the tree's.

```ui
@use "github.com/jkroso/UI.jl/Interface/Semantic/ListTree" Item
Box(width(320px), ListTree(
  ItemGroup("examples",
    ItemGroup("markdown_editor",
      Item("components.md"),
      Item("welcome.md"),
      Item("widgets.jl")),
    Item("26_finder.jl"),
    Item("28_markdown_editor.jl")),
  ItemGroup("Interface",
    ItemGroup("Semantic",
      Item("Checkbox.jl"),
      Item("Slider.jl")),
    Item("draw.jl"))))
```

The inspector shows what's in a Julia value. Click a value to change it.

```ui
settings = Dict{String,Any}("font" => "Charter", "size" => 17, "spelling" => true,
                            "recent" => ["welcome.md", "components.md"])
Box(width(420px), Inspector(inspect(settings, label="settings")))
```
