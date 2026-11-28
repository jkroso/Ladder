# Ladder
#
# A Markdown editor made with UI.jl, modelled on Constly. You type Markdown, and each line is drawn
# the way it will read: headings are big, **bold** is bold, tables are tables.
# A line keeps that look while you type in it. ⌘E, or the switch in the top bar, shows the
# markup characters of the part that the caret is in, so you can change them. A table stays a table while you type in its cells. It opens the real files on your disk, and ⌘S writes your changes
# to the file. It never writes anything until you press ⌘S. A Julia file opens as one block of
# code that you change the same way: ⌘Return runs the expression that the caret is in.
#
# Give it a Markdown file or a folder, or it opens its own welcome page:
#
#     julia --project=. main.jl ~/notes/todo.md
#
# Things to try:
#   - Type. Return carries a list on. Tab and shift-Tab indent a list item.
#   - Click a cell of a table and type. Tab and shift-Tab go to the next and the
#     last cell, and Return goes down a row. Both add a row at the end.
#   - Click a cell of the sheet and type. Each row has a name and a Julia
#     expression, and shows what it comes to. ⌥-click shows the sheet as code.
#   - Click a cell of the spreadsheet and type. A cell that starts with = is a
#     formula, like = B2 * C2 or = sum(D2:D4), and shows what it comes to.
#   - Write a code block in the language `mermaid` to show a diagram: a
#     flowchart, a sequence diagram and so on. ⌥-click shows it as code.
#   - Write a formula in TeX between dollar signs, like $x^2$, to show it
#     in a line of text. Between a line of $$ and another, the formula is on
#     lines of its own, in the middle of the page. ⌥-click shows it as code.
#   - Move the mouse over a diagram, a picture, a page of a PDF file, a model or
#     a video, and click the button beside its top right corner to make it fill the window.
#     Pinch, or scroll with ⌘ held, to zoom it there, and drag it to move it.
#   - Write a code block in the language `takeoff` to measure from a plan: drop
#     a PDF file on it, count fittings, measure lengths and areas, say what
#     each measure is or choose its item from Centient's catalogue, and make a
#     quote in Centient. Corners snap to the plan's lines, and a shape can be
#     cut out of an area.
#   - Write a code block in the language `schedule` to plan the page's to-do
#     items: each one is a bar on a line of days. Drag a bar's end to say how
#     long the task takes, and drag from the circle at its end to the task that
#     waits for it. The mouse over a to-do item shows the task's days.
#   - Write a code block in the language `chart` under a table, a spreadsheet
#     or a sheet to draw its numbers as bars, as lines or as a pie.
#   - Write a code block in the language `board` to see the page's to-do
#     items as cards in columns. Drag a card to the last column to tick its item.
#     With a line like `in: jobs` in it, the board shows the items of every
#     page of that folder, and a card that's moved ticks its item in its own page.
#   - Write a code block in the language `gallery` to show the pictures of a
#     folder as a grid of small squares. Click one to make it fill the window,
#     and press ← and → there to see the others.
#   - Write a code block in the language `calendar` to see a month, with the
#     page's tasks, its to-do items that have a day like 2026-11-25 in their
#     text, and events of its own. Drag a thing to another day to move it.
#     With a line like `in: jobs` in it, the to-do items are those of every
#     page of that folder, and a tick or a new day goes into the item's own page.
#   - Write a code block in the language `columns` with a number in it, like 3,
#     to show the next three blocks of the page side by side. You type in a
#     column as you type anywhere. A heading takes the blocks under it into its column.
#   - Write a code block in the language `sketch` to draw: by hand, lines,
#     arrows, boxes, ovals and words. Its tools are over it, and you draw
#     where it is. The button beside its top right corner makes it fill the
#     window.
#   - Write a code block in the language `canvas` for a board of cards that
#     you put anywhere, as in the app Muse: notes, words, pictures, pages and
#     web pages, with lines between them. Tab adds a joined note, as in a
#     mind map. You change it where it is, or with the button beside its top
#     right corner in the whole window.
#   - Write a code block in the language `signature` for a place to sign:
#     press in its box and drag to draw. The file holds each stroke.
#   - Write a code block in the language `contact` for the card of a person
#     or a company. Click a row to use it: an email address starts an email.
#     Click words twice to change them. Drop a vCard file on the page to
#     make one.
#   - Write a code block in the language `map` with an address in it to show
#     the map of that place. The + and the − on the map show less and more
#     of what's round it. Drag the map to move it, and click it to put the
#     pin where you clicked.
#   - Write a code block in the language `view` with the name of a file in
#     it, or the address of a page of the web, to show it as it is: a page,
#     a picture, a PDF file, a model, a table. Click, drag and type in a page
#     where it is. The button beside its top right corner goes to the file.
#   - Write a code block in the language `result` with Julia code in it, or
#     the name of a Julia file, to show what the code comes to: a 3D model, a
#     node, or a value as text. The code has the names of the page's sums, and
#     it runs again when they change, so a model follows a number you drag.
#   - Write a code block in the language `find` to list the to-do items
#     that aren't ticked in every page of the folder. At its top, type words
#     to keep only the lines that have them, and choose the kind of line and
#     the folder from two menus.
#   - Write a code block in the language `email` to list the emails with a
#     person, once Ladder has your email account.
#   - Write a code block in the language `timelog` to keep the hours of a
#     job. Type a task and click Start, and click Stop when you stop. The
#     block adds up the hours of each task.
#   - An agent writes a code block in the language `ask` to ask you a
#     question with answers to click, and one in the language `changes` to
#     show you a diff, with a button on each change that accepts or rejects it.
#     Accept makes the change in its file, and Reject takes it out again.
#     The diff has the colours of its code, and a mark on the words that are
#     different. Two buttons put the new lines under the old or beside them.
#     Click a line of the diff to say something about it to the agent.
#   - Type in a line and it keeps its look: that's rich text. Press ⌘E, or
#     click the ladder in the top bar, to go down a level: the part that the
#     caret is in shows its markup, and a snake takes the ladder's place. ⌘E
#     again, or a click on the snake, goes back up. While the mouse is over
#     the ladder, it opens into a slider with the snake at one end and the
#     ladder at the other, and a stop for each level that the window can show at.
#     The levels are those of the part that the caret is in. In a `julia` code
#     block, they're the value of what you run, its inferred code, its LLVM
#     code and its assembly.
#   - Move the caret down the page onto a form, a diagram or a picture. A
#     line goes round it. Return gives it the keyboard, ⌫ takes it away, and
#     ↑ and ↓ go on to the lines beside it. A click on such a part puts the
#     caret on it too, unless the click was on a piece of it that takes clicks,
#     like a button. ⌥-click shows the part as it's written.
#   - ⌘B and ⌘I make the selection bold or italic. ⌘Z and ⌘⇧Z undo and redo.
#   - Double-click selects a word, triple-click a line. ⌘-click opens a link. In a page
#     that's read-only, like an email, a click opens it with no key held.
#   - ⌘F shows the search under the › after the file's name in the top bar. In a
#     file with no such ›, like a file of code, it opens a bar that finds text.
#   - Write ![name](picture.png) on a line of its own to show a picture, or drop
#     a file on the page from the Finder. ⌘V pastes a file that you copied in
#     the Finder the same way, and a picture that you copied, like a screenshot.
#   - Write ![Prices](prices.csv) on a line of its own to show a CSV file as a
#     table. A `chart` block under the line draws the file's numbers.
#   - Write the address of a web page as a picture's, like
#     ![Julia](https://julialang.org), on a line of its own to show a card with
#     the page's title, its description and its picture. ⌘-click the card to
#     open the page.
#   - Write [^1] in a line and [^1]: on another line to make a footnote.
#   - Write [[Ideas]] to link to the page Ideas.md, wherever it is in the
#     project, as in Obsidian. [[Ideas|my ideas]] shows other words, and
#     [[Ideas#Plans]] goes to a heading. A page that isn't there yet opens empty.
#     After [[, a list shows the pages whose names fit what you type.
#   - Write ![[Ideas#Plans]] on a line of its own to show a part of the page
#     Ideas: the heading Plans and the lines under it. ![[Ideas#table 2]] shows
#     its second table, and ![[Ideas#^prices]] the block named ^prices. Type in
#     the part, and the page Ideas changes too. ⌘S saves both pages. See "a
#     part of another page". Copy a whole block and paste it in another page,
#     and the paste is such a part. ⌘⇧V pastes a copy of its lines.
#   - Right-click a word with red dots under it to put its spelling right.
#   - The button at the top left, or ⌘\, shows the other files in the folder.
#     Drag the right edge of that list to make it wider or narrower.
#     ⌘O finds a Markdown file by name.
#   - ⌘⇧P opens the command palette, which is Ladder's command line. It
#     works as the omnibar of Centient does. A bar slides up from the bottom
#     of the window. Type some letters of a command's name, like sideb for
#     Sidebar, and press Return to run it. The list has the commands that
#     have a use where you are: Bold on a page of Markdown, Comment in a
#     line of code, and Rename, Duplicate and Move To Trash for the file
#     that shows, with its name in the row. Some commands ask for something
#     first: Theme asks for the colours, Go To for a heading or a line's
#     number, Insert for a kind of block. Each thing has a chip beside the
#     command's name. Choose it from the list over the chip or type it,
#     press Return, and press Return again on Run. Such a command is a
#     Julia function, and code from the startup page can add its own with
#     `add_command!`.
#   - ⌘⌥← goes back to the file that showed before, and ⌘⌥→ goes forward
#     again. The two arrows at the top right of that list do the same, and so
#     do the two buttons at the side of a mouse that has them.
#   - Click a file in that list that isn't Markdown to see it. Ladder shows it
#     and doesn't change it: the text of a file of code, a picture, a model, a
#     sound, a video, a PDF file, a table. A file that it has no way to show is
#     a binary file, and a button shows its bytes in hexadecimal. The button at
#     the top right opens the file in the app that the Mac uses for it.
#   - Click the icon beside a file in that list to see the file's headings and
#     components, and click one to go to it. ⌘⇧\ gives that list the keyboard: ↑ and ↓
#     move through it, → and ← show and hide what's under an item, Return
#     opens the item and esc goes back to the text.
#   - Click the eye beside the button that shows that list, or press ⌘⇧., to
#     list the hidden files and folders too: the ones whose names start with a
#     dot, and the ones that you chose to ignore.
#   - Right-click a file or a folder that you never look at, like ~/Movies, and
#     choose Ignore. Ladder leaves it out from then on, as it leaves out a
#     hidden one, and remembers it the next time it opens. The Settings page
#     lists what you ignore, with a button that shows each one again.
#   - Right-click a file or a folder in that list, or the file's name in the
#     top bar, to rename it, duplicate it, copy its path, show it in the Finder
#     or move it to the Trash. A folder goes to the Trash with everything in it.
#     A folder's menu makes a new page or a new folder in it. A file's menu
#     opens it in a new window or in the Mac's app for it, and copies a wiki
#     link to it. Right-click under the list for a new page or folder there.
#     A file or folder that gets a new name, or moves, takes the links to it
#     in the project's other pages along: [[Ideas]] becomes [[Thoughts]].
#   - Right-click the page to cut, copy and paste, and to insert a new block
#     where you clicked: a heading, a list, a to-do item, a table, a sheet, a
#     spreadsheet, a code block, a live block, a takeoff, a schedule, a chart, a
#     board, a calendar, a list of what's found, a sketch, a canvas, a signature, a contact, a map, a list of emails, a link card, a recording or a divider.
#   - A line that holds only a sound file, like ![Recording](memo.m4a), shows
#     a player. Insert › Recording records one from the microphone. A button
#     under the player writes down what's said, in a paragraph under it.
#   - A file that a page makes, like a recording or a picture that's pasted,
#     goes in a hidden folder called .media beside the page.
#   - Start a list item with `- [ ]` to make a to-do item. Click its box to
#     tick it.
#   - Write a code block in the language `julia`, put the caret in a line of
#     it and press ⌘Return. The page runs the line and shows what it comes to
#     in a box after the line. ⇧Return runs the line and goes to the next one.
#     Click a box that has an arrow to see the rest of its value. The code
#     of a file runs in one module. To start again with nothing that the code
#     made, press ⌘⇧P and choose Reset Module.
#   - Type the start of a name in a code block. A list under the caret shows
#     the page's names that start the same way. ↑ and ↓ choose one, and Return
#     or Tab types the rest of it.
#   - Write !`code` in a line of text. The page runs the code and shows what
#     it makes in the line: a node like a switch or a file path, or a value
#     as text. Press ⌘E and click the line to see the code again.
#   - Start a file with front matter: lines like `title: Notes` between two
#     lines of ---, or lines like `title = "Notes"` between two lines of +++.
#     It shows as a block of its own.
#   - Let an agent like Claude Code show you a page (see agent/waiters.jl and the plugin
#     folder). While it waits, a button at the top right sends it the lines that
#     you changed. ⌘Return does the same. The agent can change the file while
#     you type, and the page keeps both. A bar shows for a few seconds beside
#     each line that the agent changed. While the file's changes since the
#     last commit show, a button with an eye in the top bar shows those bars
#     again. The list of files has a dot beside
#     a page that an agent waits for. While the list is hidden, the dot is
#     beside the button that shows it.
#   - The command Word Count says how many words the page has, how many
#     characters, and how long it takes to read.
#   - ⌘+ and ⌘- change the text size by a pixel. ⌘0 puts it back.
#   - ⌘P prints the page, or saves it as a PDF. ⌘⇧E saves it as a page of HTML.
#   - ⌃⌘⇧P shows the page as slides, one at a time, for when you show a plan to
#     someone. A slide starts at each heading of level 1 or 2, and at each line
#     across the page. → and ← go on and back, and esc shows the page again.
#   - ⌘, opens the settings in a window of their own, where you choose the
#     colours, the font and its weight, the text size and the width of the
#     page. A button there makes
#     Ladder the app that opens Markdown files. Links at the top of that
#     page go to the other pages of the settings: Code editor, for how code
#     shows, and Key bindings, for the keys of each command. ⌘, again
#     closes that window.
#   - As you type or press an arrow key, the caret doesn't jump to its new
#     place. It moves there in a short time. A click still puts it there at
#     once. A box in the settings turns the move off.
#   - An .eml file, which holds one email as a server sends it, opens as a
#     page that's read and not changed. eml.jl says how. The email shows as
#     it was sent, with its sender's colours, layout and buttons. ⌘E goes
#     down a level, to its words as a page, and up again. It asks the web
#     for nothing until you click Load pictures. Each email from the same
#     sender then loads its pictures too. Ladder gets no email and
#     sends none: that's the work of code that the startup page loads.
#     Click the top of the email, with its subject and sender, and a line
#     goes round it. ⌘E or the ladder then shows every field of its header,
#     and goes back up again. Esc gives the keyboard back to the page.
#   - The Ladder app updates itself. It gets a newer version while you work,
#     and the new version takes its place when you quit. A box in the settings
#     turns that off. update.jl says how it works.
#   - Ladder opens your startup page when you start it without a file, and
#     runs the Julia code of that page each time it starts. Code there can
#     add to Ladder: buttons, commands, kinds of block, a list for the
#     sidebar, work in each frame. See "the startup page" below, and the
#     tables before it.
#   - On the Key bindings page, choose the keys of VS Code, Sublime Text or
#     Emacs, or click a command and press the keys you want for it.
#   - ⌘D selects the word that the caret is in. ⌘D again selects the next
#     place that has that word as well, and what you type then goes in at
#     each of them. Escape leaves the selection that you started with.
#   - A word that's selected has a line round each other place on the page
#     that has it. Those are the places that ⌘D goes to.
#   - ⌘/ makes a comment of a line of code. ⌘⇧L selects a line, ⌘⇧D copies it
#     to the line under it, ⌘⇧K deletes it, and ⌘⌥[ and ⌘⌥] move it up and down.
#   - ⌘N opens a new window on the folder that you're in, with the folder in
#     its page.
#   - ⌘W closes the file, and the window stays open with no file. ⌘W in a
#     window with no file closes it. Ladder quits when its last window closes.
#   - ⌘⌥I opens the layout inspector. The app that's built leaves it out.
#   - Press ⌘⇧P and choose Show Folder As to show the folder of the file as
#     a kind of folder: a desktop, notes, a grid of pictures, or a kind that
#     a repository on GitHub has, like github.com/jkroso/Media.lad. Ladder
#     writes the folder's own page, the file `.ladder`. Plain takes it away.
#   - Show a folder as a Blog, and its own page lists its pages as posts.
#     Publish there makes each a page of HTML in the folder `docs`, with a
#     first page that lists them, and pushes that folder to GitHub, where
#     GitHub Pages serves it. See "a folder that's a blog".
#   - Hold ⌘ and ⌥ and click anything in the window: a block, a button, a
#     row of the sidebar. Buttons show on the blue line round it. Show Code
#     opens a window beside this one with the function that draws that
#     thing. Change the function there and press ⌘Return in it, and the
#     thing is drawn the new way at once. Change asks an agent to
#     change the thing, in words that you type, and Explain asks it a
#     question. Show Code in the command
#     palette does the same for the next thing that you click. See "the code
#     of a thing".
#   - Open a long file of code, like this one. It opens whole, and a typed
#     letter takes no longer there than in a short file. See "the lines of a
#     long file".
#   - In a file of code, press ⌘⇧P and run Go To for a list of the file's
#     functions and sections. Hold ⌘ and click a name to go to where it's
#     defined, or rest the mouse on it to see a card of it. See "where a name
#     is defined" and "a card of what a name is". Rename In Code gives a name
#     another name: see "give a name another name". ⌘-click a name where the
#     code makes it, or run Find Uses, to list each place that uses it: see
#     "where a name is used". In a git folder, Rename In Code changes a name
#     of the whole file in the folder's other Julia files too.
#   - Write `# check: share("70%") == 0.7` above a function in a file of
#     Julia code. A dot at the end of the line says whether it's true, and the
#     top bar says how many pass. Add Check writes one for the call at the
#     caret. See "checks in a file of Julia code".
#   - Press ⌘⇧P, run Theme, Text Size or Go To, and press ↓: the window shows
#     each choice at once, and Esc puts it back. See "a look before you choose".
#   - Click the number of a line, in a file that git keeps, to see the commit
#     that last changed the line. See "when a line last changed".
#   - Run the command Ask Agent, choose a block of the file's code or a part
#     of the window, and say what you want in words. An agent changes the
#     code, or its answer to a question shows in a card beside the thing, with
#     a button to ask more. ⌥↑ makes the thing bigger, and ⇧ and a click add
#     another. Show Change lists each change that an agent made, and Undo
#     Change takes back the newest. Keep This Change keeps a function of
#     Ladder's own for each start. While an agent works, the label says what
#     it's doing. See "ask for a change to a thing", "ask an agent", "the card
#     of an answer" and "what the agents changed".
#   - A function that a page's code makes is a command of the palette. See "a
#     page's own commands".
#   - Write a code block in the language `check`, with a line of Julia for
#     each thing that must be true. It shows a green or a red dot for each
#     line, and a click on it shows each line with a tick or a cross. See
#     "checks of the page's code".
#   - Run the command Show As App to open the page in a window with only the
#     page: no sidebar, no caret, and nothing in the top bar, which still
#     moves the window. See "a page as an app".
#
# It uses these UI.jl features: a `Scroll` that only builds the lines
# on screen, a `draw` method that adds the caret and selection over a node,
# italic and bold fonts by name, a colour for each part of a line of code, a
# `Stack` to float the file finder over the page, and
# `hide_titlebar!` for a window without a title bar, with
# `place_window_buttons!` to line its close, minimise and zoom buttons up with the top bar.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl/skia" measure_text rectangle rounded_rectangle sk_color fontmgr
@use Skia
@use GLFW
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/Specific" skia_cap_height
@use "github.com/jkroso/UI.jl/Interface/abstract" tabstop tabbed! USUAL_PX
@use "github.com/jkroso/UI.jl/Interface/draw" scene
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI GeometricUI WrapMode Theme with_theme adopt_theme! light describe describe! reuse! detach! add_child! window_of focus handled carry! inputs version onblur
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor open_url viewport show_tooltip! hide_tooltip! hittest show_menu! hide_menu! redraw_in! rect popup! close_popup! MouseScroll Pinch onpinch Changed onchanged placed! with_clip with_round_clip clipboard!
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring jstring with_pool send
@use "github.com/jkroso/UI.jl/Interface/fonts" skia_font register_font weight_of weight_name isitalic installed_faces
@use "github.com/jkroso/UI.jl/Interface/image" image_aspect image_source has_image
"""
True while Ladder is built into an app (see app/bundle.jl). Kip then loads
each file as it's built, and never compiles a copy of it to keep.
"""
const BUILDING_APP = haskey(ENV, "KIP_FROZEN") && ccall(:jl_generating_output, Cint, ()) == 1
# The layout inspector is a tool for working on Ladder's layout, so the app
# that's built leaves it out. Its @use line stays on a line of its own, where Kip finds it.
if !BUILDING_APP
  @use "github.com/jkroso/UI.jl/Interface/inspector" toggle_inspector!
end
@use "github.com/jkroso/UI.jl/Interface/window" hide_titlebar! place_window_buttons! fade_window_buttons! drag_window! set_dark! nswindow system_menu fills_screen fill_screen! dark_mode
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon icon_cache load_icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/SVG" SVGPath render_svg
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" => TextInputs
@use "github.com/jkroso/UI.jl/Interface/Semantic/Link" Link
@use "github.com/jkroso/UI.jl/Interface/Semantic/RadioGroup" RadioGroup
@use "github.com/jkroso/UI.jl/Interface/Semantic/Slider" Slider
@use "github.com/jkroso/UI.jl/Interface/Semantic/ColorPicker" ColorPicker
@use "github.com/jkroso/UI.jl/Interface/Semantic/ListTree" => Tree
@use "github.com/jkroso/UI.jl/Interface/Semantic/STLViewer" STLViewer Mesh load! show!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" AudioPlayer VideoPlayer pause! card_bottom controls_show
@use "github.com/jkroso/UI.jl/Interface/Semantic/Recorder" AudioRecorder record! stop! plays
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" Mermaid problem
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" => Diagrams
@use "github.com/jkroso/UI.jl/Interface/media" silence! recording picture_size
@use "github.com/jkroso/UI.jl/Interface/Semantic/ThreeMF" => ThreeMF
@use "./pictures" picture natural thumbnail finder_icon pdf_pages pdf_page pdf_size pdf_part pdf_lines forget_picture photo_place
@use "./spelling" misspelt guesses learn!
@use "./transcribe" Transcription check! finished phrases words_between
@use "./html" html footnotes NOTE escape
@use "./markdown" Kind Line Span Cell classify spans tablecells isdivider words isdone front_matter after_matter MATTER TOML_MATTER MATH CALLOUTS callout opens_callout wikitarget block_id only_id
@use "./markdown" COMMENT
@use "./highlight" tokens left_open
@use "./sheet" SHEET Result Given sheetcells parts uses tally known units shown number_at nudged name_values ident cases folded RUN_ROW
@use "github.com/jkroso/Units.jl" => Units
@use "github.com/jkroso/Units.jl/Money" => Cash
@use "./spreadsheet" SPREADSHEET Value spreadcells spreadtexts isformula letters answers moved
@use "./merge" changes combine follow unified
@use "./agent/waiters" => Agent
@use "./for_agents" => Offer
@use "./for_agents" on_main
@use "./repl" => Repls
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./pasteboard" => Pasteboard
@use "./takeoff" => Plans
@use "./schedule" => Schedules
@use "./chart" => Charts
@use "./csv" => Csvs
@use "./filter" => Filters
@use "./save" => Saves
@use "./forms" => Forms
@use "./math" => Maths
@use "./ask" => Asks
@use "./changes" => Diffs
@use "./board" => Boards
@use "./gallery" => Galleries
@use "./calendar" => Calendars
@use "./linkcard" => Cards
@use "./columns" => Columns
@use "./repeats" => Repeats
@use "./find" => Searches
@use "./sketch" => Sketches
@use "./canvas" => Canvases
@use "./signature" => Signatures
@use "./contact" => Contacts
@use "./map" => Maps
@use "./timelog" => Timelogs
@use "./day" => Days
@use "./dates" => DatesRead
@use "./centient" => Centient
@use "./update" => Update
@use "./mime" => Mime
@use "github.com/jkroso/JSON.jl" JSONObject JSONNumber json_value write_json
@use "./eml" => Eml
@use "./webpage" => Webpages
@use "./web" => Web
@use "./web/select" => WebSelect
@use "./web/browser" => Browsers
@use "./web/files" => Webfiles
@use "./web/fetch" => Webfetch
@use "./web/source" => Sources
@use "./remote" => Remote
@use "./guard" => Guard
Guard.LADDER[] = @__MODULE__
@use "./slides" => Slides
@use "./desktop" => Desks
@use "./term/view" => Terms
@use "./git" => Git
@use "./cad/view" => Designs
@use "./cad/agent" => DesignTools
@use "./notes" => Notes
@use "./zip" => Zips
@use "./macfile" => MacFiles
@use "./trash" => Trash
@use "./app/facts" APP_ID   # the Ladder app's name for macOS
@use "./folders" => Folders
@use "./blog" => Blogs
@use "./news" => News
@use "./sites" => Sites
@use "./feeds" => Feeds
@use "github.com/jkroso/UI.jl/Interface/draw" Bubble
@use "github.com/jkroso/UI.jl/Interface/draw" popups sync_mouse! popup_at tab!
@use "github.com/jkroso/UI.jl/Interface/draw" set_tool! window_tool draw_tool draw_tool_under tool_input tool_cursor invalidate_layout!
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use "github.com/jkroso/URI.jl" URI
@use Colors: @colorant_str, RGBA, RGB, HSV, Colorant
@use InteractiveUtils: clipboard
@use InteractiveUtils: code_native, code_llvm
@use Dates: Dates, Date, Day
@use Base64: base64encode

# --- look --------------------------------------------------------------------
#
# The colours, the fonts and the measures of the page are in look.jl. The
# files under main.jl have the rest of the page that every part of the window
# uses: a line laid out (flow.jl), the document (buffer.jl), what a window
# holds (editor_type.jl), the faces of the text (faces.jl), rich text and
# tables (rich.jl), what the page asks of a block (blocks.jl), and the lines and
# the shapes that a block draws on a canvas (strokes.jl). shared.jl names the
# functions that several files give methods to.
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./git_marks" exports...
@use "./notes_page" => NotesPages NotesDirectory
@use "./zip_page" => ZipPages
@use "./macfolders_page" => MacPages DownloadsDirectory TrashDirectory PicturesDirectory ScreenshotsDirectory mac_kind
@use "./ask_view" exports...
@use "./linkcard_view" exports...
@use "./changes_view" exports...
@use "./sketch_view" exports...
@use "./math_view" exports...
@use "./takeoff_view" exports...
@use "./julia_levels" exports...
@use "./csv_view" exports...
@use "./json_view" exports...
@use "./map_view" exports...
@use "./fill_view" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./columns_view" exports...
@use "./live_view" exports...
@use "./long_file" exports...
@use "./schedule_view" exports...
@use "./board_view" exports...
@use "./calendar_view" exports...
@use "./gallery_view" exports...
@use "./timelog_view" exports...
@use "./check_view" exports...
@use "./canvas_view" exports...
@use "./find_view" exports...
@use "./load_view" exports...
@use "./contact_view" exports...
@use "./signature_view" exports...
@use "./webpage_view" exports...
@use "./terminal_view" exports...
@use "./view_block" exports...
@use "./result_block" exports...
@use "./slides_view" exports...
@use "./cover_view" exports...
@use "./email_view" exports...
@use "./email_head" exports...
@use "./desktop_page" exports...
@use "./folder_table" exports...
@use "./blog_page" exports...
@use "./git_page" exports...
@use "./run_code" exports...
@use "./module_view" exports...
@use "./code_names" exports...
@use "./code_nav" exports...
@use "./design_view" exports...
@use "./media_view" exports...
@use "./page_extras" exports...
@use "./levels_view" exports...
@use "./rows_from" exports...
@use "./chart_view" exports...
@use "./filter_view" exports...
@use "./save_view" exports...
@use "./form_view" exports...
@use "./agent/kinds" exports...
@use "./agent/session" exports...
@use "./agent/window" exports...
@use "./agent/page" exports...
@use "./agent/pane" exports...
@use "./code_thing" exports...
@use "./agent/ask" exports...
@use "./check_fails" exports...
@use "./code_picker" exports...
@use "./news_page" exports...
@use "./folder_kinds" exports...
@use "./remote_page" exports...
@use "./sandbox" exports...

# --- the app -------------------------------------------------------------------------

editor(node) = begin
  while !(node isa Editor)
    node = node.parent
  end
  node
end

"""
A part of the page joins the children of the document, so one part can find
another by a walk of the tree: up to the document, then through its children.
`layout!` empties that list and gives the document each part of the page that
shows, so the children are the parts of this page, in the order of their lines.
The paragraphs, the headings and the other blocks that are made for the lines
on screen follow them.
"""
own!(d::Document, node) = begin
  parent = getfield(node, :parent)
  (parent === nothing || (parent === d && !listed(d, node))) && add_child!(d, node)
  node
end

"True if `node` is in the list of the children of `d`"
listed(d::Document, node) = getfield(node, :prevsibling) !== nothing || getfield(d, :firstchild) === node

"""
Take every child out of the document's list. Each one keeps the document as
its parent, so a node that an earlier frame made can still reach the editor.
"""
unlist!(d::Document) = begin
  child = getfield(d, :firstchild)
  while child !== nothing
    next = getfield(child, :nextsibling)
    setfield!(child, :prevsibling, nothing)
    setfield!(child, :nextsibling, nothing)
    child = next
  end
  setfield!(d, :firstchild, nothing)
  d
end

"Open the editor on a file, or on the first Markdown file in a folder"
build_editor(path) = begin
  # An address on the web is asked for once the window is on the screen: see "a page from a web server".
  # A name like `my.notes/new.md` is a file when the folder `my.notes` is there.
  Remote.typed(path) === nothing || ispath(expanduser(path)) || isdir(dirname(abspath(expanduser(path)))) ||
    return navigate!(blank_editor(), path)
  path = abspath(expanduser(path))
  e = blank_editor()
  isdir(path) ? open_on_folder!(e, path) : open!(e, path)
  e
end

"An editor that shows no file yet"
blank_editor() = begin
  e = Editor()
  load_sheet_font()
  load_omni_font()
  load_site_font()
  e.nodes[:input] = own!(e, TextInput(placeholder="Find a file", font_family=SANS, font_size=15px,
                                      look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text)))
  e
end

"""
Show the folder at `path` in a window that's opened on it: its first Markdown
file, or the folder's own page when it has no Markdown file. A folder of a
kind that shows in the page, like a desktop, shows there: see `show_opened!`.
The sidebar lists the folder, and it stays closed until you open it.
"""
open_on_folder!(e, path) = begin
  e.folder = path
  list_files!(e)
  isempty(e.files) ? show_beside!(e, path) : open!(e, e.files[1])
  e.nodes[:opened_on] = (path, e.buf.path)
  show_opened!(e)
  e
end

"""
Show the folder that the window was opened on in the page, when it's of a kind
that shows there, as a desktop is. A folder whose own page says its kind is
plain until that page has run, so the window asks again then. A window that
shows another file by then keeps that file.
"""
show_opened!(e) = begin
  on = get(e.nodes, :opened_on, nothing)
  on === nothing && return
  path, was = on
  (e.folder == path && e.buf.path == was) || return (delete!(e.nodes, :opened_on); nothing)
  d = directory(e)
  (d isa AbstractDirectory && !(d isa FS.Directory) && page_first(e, d) && page_view(e, d) !== nothing) || return
  delete!(e.nodes, :opened_on)
  open!(e, d)
  nothing
end

# The sidebar's folder, and each folder and file in it, is an object of the
# file system (FS.jl): a `File`, a `Directory`, or a kind of directory, which
# is a type under `AbstractDirectory`. Each directory makes the objects of what
# it holds, from the directory at `/` down. The sidebar asks the folder's
# object what to list and how to list it, and asks each object in the list for
# its icon, for what follows its name and for what a click on it does:
# `entries`, `folder_view`, `entry_icon`, `entry_marks` and `open!`. So code
# from the startup page gives a kind of folder its own way in the sidebar with
# a method for the folder's type, as it does for a component of a page. The
# page asks too: `page_view` gives what it shows for a file or a folder of a
# kind, `page_fills` says whether that's as wide as the window,
# `page_covers` says whether it covers the page's whole space, as a desktop does,
# and `crumb_in_page` whether it goes up to the window's top with the file's path in it.
# And the window asks: `window_view` makes all of it, `side_menu` a side menu
# in the sidebar's place and `bread_crumb` the middle of the top bar. See "the whole window".
#
#     @def struct NotesDirectory <: Ladder.AbstractDirectory end
#     Ladder.FS.kinds[fs"/Users/jake/Notes"] = NotesDirectory
#     Ladder.entry_icon(::NotesDirectory) = "box"
#
# A folder gets its kind from `FS.kinds`, by its path, or from a page of its
# own, the file `.ladder` in it: see "a folder's own page".

"""
Read the sidebar's folder again: what it lists, and the object of each one.
The objects are new each time, so a folder that code gave a kind since the
last time has that kind now.
"""
list_files!(e) = begin
  empty!(e.entries)
  d = isdir(e.folder) ? FS.get(FSPath(e.folder)) : nothing
  found = d isa AbstractDirectory ? entries(e, d) : FSObject[]
  d isa AbstractDirectory && (e.entries[e.folder] = d)
  e.listed = String[joinpath(e.folder, o.path.name) for o in found]
  foreach((path, o) -> e.entries[path] = o, e.listed, found)
  # The file finder lists the Markdown files
  e.files = String[path for (path, o) in zip(e.listed, found) if isfile(o) && ismarkdown(path)]
end

"""
What the sidebar lists of the directory `d`: its folders, then its files, each
in the order of their names. A name that starts with a dot is hidden, as it is
in the Finder, and so is a file or a folder that you ignore, unless the sidebar
shows those. .DS_Store is the Finder's own file, and never shows. What's
neither a folder nor a file isn't listed. The home folder lists the Mac's
Trash, whose folder is hidden, since the Finder has it in the Dock and Ladder
has no other place for it.
"""
entries(e, d::AbstractDirectory) = begin
  dir = string(d.path)
  trash = Sys.isapple() && dir == homedir() ? basename(Trash.trash()) : ""
  ignored = Folders.ignored()
  shows(n) = e.hidden ? n != ".DS_Store" : !left_out(joinpath(dir, n), ignored) || n == trash
  found = FSObject[]
  # macOS doesn't let Ladder read some folders, like the Trash without Full Disk Access. Those list nothing.
  names = try readdir(dir) catch; String[] end
  for name in sort!(names, by=lowercase)
    shows(name) || continue
    # A link that leads nowhere, a socket, and a file that left since the folder was read have no object to list
    o = try FS.child(d, name) catch; nothing end
    o === nothing || push!(found, o)
  end
  [filter(isdir, found); filter(isfile, found)]
end

"The object of the sidebar's folder, or nothing when no folder is there"
directory(e) = get(e.entries, e.folder, nothing)

"The object of the folder or the file at `path`: the one that the sidebar lists, or else a new one. Nothing when nothing is there."
object(e, path) = get(() -> ispath(path) ? FS.get(FSPath(path)) : nothing, e.entries, path)

"The name that `o` has in the sidebar: its own name, unless its kind has a better one, as the Trash has"
entry_name(o::FSObject) = basename(rstrip(string(o.path), '/'))

"The icon that `o` has in the sidebar"
entry_icon(o::AbstractDirectory) = "folder"
entry_icon(o::FSObject) = file_icon(string(o.path))

"""
What follows the name of `o` in its row of the sidebar, like how many emails of
a folder aren't read: nodes, or `()`. A kind of folder has a method with three
arguments to say it for each thing that it holds: `entry_marks(e, d, o)`,
where `d` is the directory that holds `o`.
"""
entry_marks(e, o::FSObject) = entry_marks(e, o.parent, o)
entry_marks(e, d, o) = ()

"""
How the sidebar lists the directory `d`: `(list=..., bar=...)`. `list` is a
node that shows in place of the tree of what `entries` gives, or nothing to
leave the tree. `bar` is a node for a line over the list, or nothing. `d` is
nothing when the sidebar's folder isn't there.
"""
folder_view(e, d) = (list=nothing, bar=nothing)

"""
What the page shows for `o`, a file or a folder, in place of Ladder's own
viewer: a node, or nothing to leave Ladder's viewer. A kind of folder has a
method of this to show itself in the page, as a folder of films shows their
posters, or to show a file that it holds its own way. A folder shows in the
page after `open!(e, path)` with the folder's path.
"""
page_view(e, o) = nothing

"True when what `page_view` gives for `o` is as wide as the window has room for, as a table is, and not as wide as a page's text"
page_fills(e, o) = false

"""
True when a window that's opened on the folder `d` shows what `page_view`
gives for it. It's false for a kind of folder whose first page of text is the
better start, as a folder that git keeps is: its Readme shows.
"""
page_first(e, d) = true

"""
The object of the file or the folder that the page shows in a viewer, or
nothing when it isn't there. One that the sidebar doesn't list is found again
after a second, and not in each frame.
"""
page_object(e) = begin
  path = e.buf.path
  (e.buf.view == :file && !isempty(path)) || return nothing
  haskey(e.entries, path) && return e.entries[path]
  kept = get(e.nodes, :page_object, nothing)
  kept !== nothing && kept[1] == path && time() - kept[2] < 1 && return kept[3]
  o = try object(e, path) catch; nothing end
  e.nodes[:page_object] = (path, time(), o)
  o
end

"""
True when what `page_view` gives for `o` covers the page's whole space in the
window: from the sidebar to the window's right edge, and from the top bar to
the bottom. It has no space round it, and the page doesn't scroll. A desktop
covers the page so, with its wallpaper.
"""
page_covers(e, o) = false

"""
True when what `page_view` gives for `o` runs up to the top of the window, and
shows the file's path itself, as a SolidCraft design does in its toolbar. The
top bar then has only its left end, with its buttons, over the sidebar. The
page has the rest of the bar's room, and shows the path that the bar would
have with `page_crumb`. Only a page that covers the page's space has it: see
`page_covers`.
"""
crumb_in_page(e, o) = false

"True when what `page_view` gives for `o` has changes that aren't in its file. The name of the file says \"— edited\" then."
page_edited(e, o) = false

"""
What shows in a panel at the right of the window, beside what `page_view`
gives for `o`: a node, or nothing for no panel. The page of a repository has
git's panel there. The panel runs from the top of the window to the bottom, as
the sidebar does, and the top bar's button at its right end hides it. It's for
a page that covers the page's space (see `page_covers`), which leaves it room.
"""
page_side(e, o) = nothing

"""
Take a step back in what `page_view` gives for `o`, before the window shows the
file that showed before: true when it took one. The page of a repository goes
from a commit back to the repository's files.
"""
page_back!(e, o) = false

"""
What shows under the text of the page `o`, which the directory `d` holds: a
node, or nothing. A kind of folder has a method of this to add to each page
that it holds, as a folder of notes lists the pages that link to the page.
It's as wide as the page's text, `e.width`, and it scrolls with the text.
"""
page_foot(e, d, o) = nothing

"""
What shows in place of the card of the front matter of the page `o`, which the
directory `d` holds, while the caret isn't in it: a node, nothing for the
card, or `false` for nothing at all. A kind of folder has a method of this to
show the front matter of the pages that it holds its own way, as a blog shows
a book review's title and stars, and shows none on a folder's own page.
`rows` are the front matter's keys, each as its line, the key and what it's
set to, as it's written.
"""
matter_view(e, d, o, rows) = nothing

"""
What shows in place of the table in lines `from` to `to` of the page `o`,
which the directory `d` holds, while the caret isn't in it: a node, or
nothing for the table. A kind of folder has a method of this to show a table
of its pages its own way, as a blog on a web server shows the table of a
folder's files as the list that the folder has on the Mac.
"""
table_view(e, d, o, from, to) = nothing

"""
The object of the page of text that shows, or nothing. One that the sidebar
doesn't list is found again after a second, and not in each frame. A page
from a web server is a `WebPage`, in the web folders that it's in.
"""
text_object(e) = begin
  path = e.buf.path
  (at = web_address(path); isempty(at)) || return web_page(at)
  haskey(e.entries, path) && return e.entries[path]
  kept = get(e.nodes, :text_object, nothing)
  kept !== nothing && kept[1] == path && time() - kept[2] < 1 && return kept[3]
  o = try object(e, path) catch; nothing end
  e.nodes[:text_object] = (path, time(), o)
  o
end

"What shows under the text of the page, or nothing: see `page_foot(e, d, o)`. Only a page of Markdown that shows whole has it."
page_foot(e) = begin
  b = e.buf
  (b.view == :markdown && !isempty(b.path) && !filled(e) && slideshow(e) === nothing) || return nothing
  o = text_object(e)
  o === nothing ? nothing : with_theme(() -> page_foot(e, o.parent, o), component_theme(e.zoom))
end

"True when a kind of folder or of file shows the page its own way, as wide as the window has room for"
own_page(e) = (o = page_object(e); o !== nothing && page_fills(e, o))

"True when the folder or the file that shows covers the page's whole space with a view of its own"
page_covered(e) = (o = page_object(e); o !== nothing && page_covers(e, o))

"What covers the page's whole space, when the folder or the file that shows is of a kind that covers it, or nothing"
page_cover(e) = begin
  o = page_object(e)
  (o !== nothing && page_covers(e, o)) || return nothing
  # The Box is made inside the theme too. A node that `page_view` gives, like a SolidCraft design's
  # editor, is described when it's put in the Box, and it takes the theme of that moment.
  with_theme(component_theme(e.zoom)) do
    own = page_view(e, o)
    own === nothing ? nothing : Box(width(grow=grow), height(grow=grow), Alignment.Start, own)
  end
end

"True when the page that shows runs up to the top of the window, with the file's path in it: see `crumb_in_page(e, o)`"
crumb_in_page(e) = (o = page_object(e); o !== nothing && !filled(e) && page_covers(e, o) && crumb_in_page(e, o))

"""
How much room the page leaves at its top for the top bar. A page that shows
the file's path itself leaves none: it starts at the top of the window, or in
agent mode at the top of the page's card.
"""
under_bar(e) = crumb_in_page(e) ? (agent_shows(e) ? PAGE_CARD_GAP : 0px) : above_page(e)

"""
The path of the file, for a page that shows the path itself (see
`crumb_in_page`): what `bread_crumb` gives, which is the file's name that
opens into its path, as the top bar has it. It has `room` at most, and it lies
on the colour `ground`, which a pinned path has under it too.
"""
page_crumb(e, room, ground) = begin
  e.nodes[:title_room] = room
  e.nodes[:title_ground] = ground
  bread_crumb(e, window_object(e))
end

"""
How far past the sidebar's edge the left end of the top bar reaches over the
page: the room of the Mac's close, minimise and zoom buttons and of the bar's
own buttons, while the sidebar is too narrow for them. A page that shows the
path itself leaves this room at its top left. A bar that hides takes none.
"""
bar_corner(e) = hides_bar(e) ? 0px : get(e.nodes, :bar_past_side, 0px)

"True when the page that shows has changes that aren't in its file: see `page_edited(e, o)`"
page_edited(e) = (o = page_object(e); o !== nothing && page_edited(e, o))

"How wide and how tall the page's space in the window is: beside the sidebar, and under the top bar"
page_room(e) = begin
  w, h = window_size(e)
  # In agent mode, the page is on a card between the two panes
  agent_shows(e) && return (page_span(e)[2], max(h - under_bar(e) - PAGE_CARD_GAP, 1px))
  side = lowered(e) === nothing ? side_w(e) : 0px
  (max(w - side, 1px), max(h - under_bar(e), 1px))
end

"""
Where the page's space is across the window: its left edge, and how wide it
is. It's beside the sidebar. In agent mode it's the page's card, between the
agent's pane and the outline.
"""
page_span(e) = begin
  agent_shows(e) && return page_card_span(e)
  w, _ = window_size(e)
  side = lowered(e) === nothing ? side_w(e) : 0px
  (side, w - side)
end

"""
Show the file at `path`. A file that's already open keeps its changes. The
file that leaves goes on the list that `go_back!` reads, unless `record` is false.
A folder shows too, when its kind has a method of `page_view`. The sidebar
then lists the folder itself, as a click on it in the sidebar does, so the
sidebar's path and the top bar's end with the same folder, as going back to it
shows too. For a file, the sidebar lists the folder that it's in. A file that shows
gets a tab in the sidebar, if it hasn't one: see "the files that are open, as tabs".
"""
open!(e, path; record=true) = begin
  # A link in a part of another page opens its page in the window, not in the part
  hosted(e) === nothing || return open!(top_editor(e), path; record)
  # A page from a web server that isn't here yet is asked for, and shows when it has come
  isremote(path) && !haskey(e.buffers, path) && return get_page!(e, path; record)
  leave_page!(e, path; record)
  e.buf = get!(e.buffers, path) do
    isfile(path) ? (in_browser(path) ? web_buffer(path) : load(path)) : isdir(path) ? Buffer(path=path, view=:file) : Buffer(path=path)
  end
  add_tab!(e)   # the file stays open as a tab in the sidebar until ⌘W closes it
  delete!(e.nodes, :new_tab)   # a file that shows in a new tab takes the tab's place
  # The sidebar lists a folder that shows, so its path ends where the top bar's does, and the folder that a file is in. It goes on
  # listing the folder that it lists while a page from a web server shows, or a view's copy of a file from one.
  at = isdir(path) ? path : dirname(path)
  if e.folder != at && isempty(web_address(path))
    e.folder = at
    list_files!(e)
  end
  e.scroll.offset = e.buf.offset
  e.popup = :none
  e.goal = nothing
  w = window_of(e)
  w === nothing || focus(e)
  e
end

"""
Get the window ready to show the page at `path`, or no page when `path` is "".
The page that leaves keeps what its blocks hold and where it was scrolled to.
It goes on the list that `go_back!` reads, unless `record` is false.
"""
leave_page!(e, path; record=true) = begin
  # A sound that the last page was playing stops. A new window has no last page, and another window's sound plays on.
  isempty(e.buffers) || silence!()
  write_blocks!(e)   # the page that leaves keeps what its blocks hold
  e.buf.offset = e.scroll.offset
  from = e.buf.path
  from == path || forget_ticked!(e)   # an item that was ticked in a list of what's found leaves that list
  from == path || delete!(e.nodes, (:html, from))   # the page of an HTML file ends, with its scripts
  from == path || leave_design!(e, from)            # and a design with no changes gives up SolidCraft's program
  # A new file ends the list of files to go forward to, as a new address does in a web browser
  record && !isempty(from) && from != path && (push!(e.back, from); empty!(e.ahead))
  e
end

# --- closing a file ----------------------------------------------------------------------
#
# ⌘W closes the file that the window shows, and its tab in the sidebar. The
# tab under it shows, or the one above when it was the last tab. ⌘W on the
# last tab shows the folder that its file is in, as a click on that folder in
# the sidebar's trail does, but it opens no file: a blog's folder shows only
# its list, not its Readme. ⌘W on a folder's page shows the tab that showed
# last, and with no tabs open it closes the folder, and the window stays open
# with no file in it. ⌘W in a window that shows no file closes the window, and
# Ladder quits when its last window closes. So three presses of ⌘W close the
# window of a file that's the only tab: the file, its folder, then the window.
# The settings window closes at once while it shows a page of the settings. A
# file that closes keeps its changes, and ⌘⌥← shows it again, in a new tab.

"True when the window shows no file, because ⌘W closed the page that it showed"
nofile(e) = isempty(e.buf.path) && e.buf.fixed

"""
The folder that the window shows when ⌘W closes its file, or nothing. A
folder's own page, a page that isn't a file on the Mac, and a file in a
folder that the Finder shows as one file, like an app, have none.
"""
closes_to(e) = begin
  path = e.buf.path
  (isabspath(path) && !isdir(path)) || return nothing
  folder = dirname(path)
  isdir(folder) && !ispackage(folder) ? folder : nothing
end

"""
Close the file that the window shows, and its tab, and show the tab under it.
With no other tab open, show the folder that the file is in. A page with no
such folder closes to no file. The page keeps its changes, and goes on the
list that `go_back!` reads.
"""
close_file!(e) = begin
  delete!(e.nodes, :new_tab)   # a new tab closes too
  next = tab_after_close!(e)
  next === nothing || return show_tab_page!(e, next)
  folder = closes_to(e)
  # The folder shows its list, not a file of its own like a blog's Readme, or ⌘W on that Readme would show it again
  folder === nothing || return open_folder!(e, folder, own=false)
  show_no_file!(e)
end

"Show no file in the window: an empty page that nothing can be typed in"
show_no_file!(e) = begin
  leave_page!(e, "")
  e.buf = Buffer(fixed=true)
  e.scroll.offset = 0px
  e.popup = :none
  e.goal = nothing
  e
end

"""
What ⌘W does: close the file that the window shows, or the window when it
shows a page of the settings, or no file and no tab is open.
"""
close_file_or_window!(e, w) = (issettings(e) || (nofile(e) && isempty(tabs(e)) && !new_tab(e))) ? (closes!(e, w) && close(w)) : close_file!(e)

# --- the files that showed before --------------------------------------------------------
#
# Each window keeps the files that it showed, in the order that it showed them.
# ⌘⌥← goes back to the file that showed before the one that shows now, as the
# back button of a web browser does. ⌘⌥→ goes forward again, to the file that
# going back left. While the sidebar is open, two arrows at its top do the
# same. They are in the top bar, at the right of the part that's over the
# sidebar, and they aren't there while the sidebar is closed, or while
# something fills the window (see `filled`). An arrow is
# faint when it has no file to go to, and its tooltip names the file that it
# goes to. The two buttons at the side of a mouse go back and forward as well,
# if the mouse has them. Any way of showing a file adds to the list: a link, the
# list of files, the file finder, a line of a `find` block. A file shows from
# the place that it was scrolled to, because its buffer keeps that. A link to
# a heading of the page that shows adds nothing, because the file is the same.

"True when the window can show the file at `path` again: it's on the disk, or it's a new page that has no file yet, or a folder that showed in the page"
showable(e, path) = haskey(e.buffers, path) || isfile(path)

"""
The file that `go_back!` would show, or nothing when no file showed before the
one that shows now. With `e.ahead` as the `list`, it's the file that
`go_forward!` would show.
"""
last_shown(e, list=e.back) = (i = findlast(p -> p != e.buf.path && showable(e, p), list); i === nothing ? nothing : list[i])

"What the arrow that goes back (or forward, with `e.ahead` as `list`) goes to, in words: a line of the file that shows, or a file. It's nothing when there's neither."
step_words(e, list=e.back) = begin
  j = jump_list(e)
  p = place_back(e, list === e.back ? j.back : j.ahead, list)
  p !== nothing && return "line $(p.caret[1])"
  to = last_shown(e, list)
  to === nothing ? nothing : basename(to)
end

# A jump to another line of the same file, as Go To, Go To Definition, Find
# Uses and Show Steps make, is a step too. ⌘⌥← goes back to the line that the
# jump left, with the caret and the scroll as they were, before it goes back
# to another file. ⌘⌥→ goes to the jump's line again.

"""
The places of the files that showed that the window of `e` jumped from: `back`
for ⌘⌥←, and `ahead` for ⌘⌥→. Each has the file's path, where the caret and
the scroll were, and how many files the list of files to go back to (or
forward to) had then: a place comes before the files that the list got
after it.
"""
jump_list(e) = get!(() -> (back=Any[], ahead=Any[]), e.nodes, :jumps)

"Where the window of `e` is: its file, its caret, its anchor and how far it's scrolled"
place_now(e) = begin
  # While the palette showed a row of its list, the window scrolled to it. The place is where it was before that.
  was = get(e.nodes, :unpreviewed, nothing)
  (path=e.buf.path, caret=e.buf.caret, anchor=e.buf.anchor, offset=was isa typeof(e.scroll.offset) ? was : e.scroll.offset)
end

"Note where the window of `e` is, before it jumps to another line of the file, so ⌘⌥← comes back to it. A new jump ends what ⌘⌥→ would go to."
note_place!(e) = begin
  isempty(e.buf.path) && return nothing
  j = jump_list(e)
  push!(j.back, (; place_now(e)..., depth=length(e.back)))
  empty!(j.ahead)
  empty!(e.ahead)
  nothing
end

"The place of the file that shows that a step from the list of files `files` goes to first, from the places `places`, or nothing"
place_back(e, places, files) = !isempty(places) && last(places).depth == length(files) && last(places).path == e.buf.path ? last(places) : nothing

"Put the window of `e` where it was at the place `p`: its caret, its anchor and its scroll"
go_place!(e, p) = begin
  b = e.buf
  fit(c) = (n = clamp(c[1], 1, length(b.lines)); (n, clamp(c[2], 0, length(b.lines[n]))))
  b.caret, b.anchor = fit(p.caret), fit(p.anchor)
  e.scroll.offset = p.offset
  delete!(e.nodes, :hold)
  focus(e)
  redraw_in!(e, 0)
  nothing
end

"""
Show the last file of `from` that's still there, and put the file that leaves
on `to`. A file that was renamed is there under its new name. One that went to
the Trash is passed over. It's true when there was a file to show. A jump in
the file that shows comes first: see `jump_list`.
"""
step_back!(e, from, to) = begin
  j = jump_list(e)
  mine, theirs = from === e.back ? (j.back, j.ahead) : (j.ahead, j.back)
  p = place_back(e, mine, from)
  if p !== nothing
    pop!(mine)
    push!(theirs, (; place_now(e)..., depth=length(to)))
    go_place!(e, p)
    return true
  end
  while !isempty(from)
    path = pop!(from)
    (path == e.buf.path || !showable(e, path)) && continue
    isempty(e.buf.path) || push!(to, e.buf.path)
    open!(e, path, record=false)
    return true
  end
  false
end

"""
Show the file that showed before the one that shows now. It's false when no
file showed before. A folder's own page can take a step back of its own first,
as the page of a repository goes from a commit back to its files: see `page_back!`.
"""
go_back!(e) = (o = page_object(e); o !== nothing && page_back!(e, o)) || step_back!(e, e.back, e.ahead)

"Show the file that `go_back!` left. It's false when there is none, or when another file was opened since."
go_forward!(e) = step_back!(e, e.ahead, e.back)

"""
True when a list shows the file or the folder at `path` only because it shows
the hidden files too: you chose to ignore it. Its row is faint, as a hidden
one's is.
"""
ignored_shown(e, path) = e.hidden && Folders.isignored(path)

"Make the sidebar list the hidden files and folders too, and the ones that you ignore, or leave them out again"
hidden!(e, on::Bool) = (e.hidden = on; list_files!(e); save_settings!(e); e)

"""
Leave the file or the folder at `path` out of Ladder's lists, as a hidden one
is, or with `on` false, show it again. Ladder remembers it. Every window lists
its folder again at once.
"""
ignore!(e, path, on::Bool=true) = begin
  on ? Folders.ignore!(path) : Folders.unignore!(path)
  ignored_changed!(e)
end

"List the folder of every window again, after the list of what you ignore changed"
ignored_changed!(e) = begin
  for o in unique([editors; e])
    list_files!(o)
    o.nodes[:ignored_at] = Folders.changed()
    w = window_of(o)
    w === nothing || stale!(w)
  end
  nothing
end

"""
Notice a change to the list of what you ignore that came from its page: you
deleted a line and saved the page, or another app changed it. Every window
lists its folder again.
"""
ignored_tick!(e) = begin
  at = Folders.changed()
  get!(e.nodes, :ignored_at, at) < at && ignored_changed!(e)
  nothing
end

# The page that lists what you ignore is a page of the settings. Its path is
# asked for each time, since the built app moves the pages when it starts.
__init__() = (Folders.PAGE[] = () -> settings_page("ignored-files.md"); nothing)

"What a click on `o` in the sidebar does: a folder shows in the sidebar, and a file shows in the page"
open!(e, d::AbstractDirectory; record=true) = go_folder!(e, string(d.path))
open!(e, o::FSObject; record=true) = open!(e, string(o.path); record)

"Show the folders and files of `folder` in the sidebar. The document that's showing stays."
go_folder!(e, folder) = begin
  e.folder = folder
  list_files!(e)
  e.files_scroll.offset = 0px
  e
end
input(e) = e.nodes[:input]::TextInput

"The takeoff of the page that fills the window, or nothing"
full_takeoff(e) = (v = full_block(e); v isa TakeoffView ? v : nothing)

"The block that fills the window, over the page and the sidebar and under the top bar"
takeoff_over(e) = begin
  v = full_block(e)
  v === nothing ? () : (Box(width(grow=grow), height(grow=grow), padding(above_page(e), 0px, 0px, 0px), background(colours.bg), geometry(v)),)
end

# --- the page's layout ---------------------------------------------------------------

"""
The names that the window gives the code of its pages, with no line that
loads them, in a module of the window. No code runs in this module. Each
page's module has its names (see `usual_module`), and a name that acts on a
window, like `page_theme!`, acts on this window when it calls this module's.
"""
sandbox(e) = get!(e.nodes, :sandbox) do
  m = Module(Symbol("⭒window"))
  # Kip by the module that's loaded here, not by name. A built app can't find a package by name.
  Core.eval(m, :(const Kip = $Kip))
  Core.eval(m, :(using .Kip))
  foreach(path -> share!(m, path), USUAL)
  include_string(m, "@use \"github.com/jkroso/URI.jl/FSPath\" FSPath @fs_str")
  Core.eval(m, :(const $(Symbol("@colorant_str")) = $(var"@colorant_str")))
  # A live block can read and set the page's colours: `page_theme()` gives "Sepia", "Paper" or "Night"
  Core.eval(m, :(const page_theme = $(() -> (reads!(e, :theme); titlecase(string(e.theme))))))
  Core.eval(m, :(const page_theme! = $(name -> theme!(e, Symbol(lowercase(string(name)))))))
  # ... and the size of the page's text, in pixels
  Core.eval(m, :(const page_text_size = $(() -> (reads!(e, :zoom); TEXT_SIZE.value * e.zoom))))
  Core.eval(m, :(const page_text_size! = $(size -> text_size!(e, size))))
  # ... and the font of the page's text, by name
  Core.eval(m, :(const page_font = $(() -> (reads!(e, :font); e.font))))
  Core.eval(m, :(const page_font! = $(name -> font!(e, String(name)))))
  # ... and its weight, by name: `page_weights()` gives the weights that the font has, like "Light" and "Regular",
  # and `page_weight()` the one that the text is drawn in
  Core.eval(m, :(const page_weights = $(() -> (reads!(e, :font); [w.label for w in text_weights(e.font)]))))
  Core.eval(m, :(const page_weight = $(() -> (reads!(e, :font); reads!(e, :weight); nearest_weight(e.font, e.weight).label))))
  Core.eval(m, :(const page_weight! = $(name -> weight!(e, String(name)))))
  # ... and the width of the page, in pixels
  Core.eval(m, :(const page_width = $(() -> e.widest.value)))
  Core.eval(m, :(const page_width! = $(width -> page_width!(e, width))))
  # ... and whether the page checks its spelling
  Core.eval(m, :(const page_spelling = $(() -> (reads!(e, :spelling); e.spelling))))
  Core.eval(m, :(const page_spelling! = $(on -> spelling!(e, Bool(on)))))
  # ... and whether a page is written to its file when its window stops being the front window
  Core.eval(m, :(const page_autosave = $(() -> (reads!(e, :autosave); e.autosave))))
  Core.eval(m, :(const page_autosave! = $(on -> autosave!(e, Bool(on)))))
  # ... and whether the caret moves to a new place in a short time, and doesn't jump there
  Core.eval(m, :(const page_glide = $(() -> (reads!(e, :glide); e.glide))))
  Core.eval(m, :(const page_glide! = $(on -> glide!(e, Bool(on)))))
  # ... and when the top bar hides until the mouse is at the top of the window, by the names that the settings page gives each choice
  Core.eval(m, :(const bar_hidings = $(() -> collect(last.(BAR_HIDINGS)))))
  Core.eval(m, :(const page_bar_hides = $(() -> (reads!(e, :hide_bar); hiding_name(e.hide_bar)))))
  Core.eval(m, :(const page_bar_hides! = $(name -> hide_bar!(e, hiding_named(String(name))))))
  # ... and whether the card of a link to a page shows the start of the page, while ⌘ is held
  Core.eval(m, :(const page_peeks = $(() -> (reads!(e, :peeks); e.peeks))))
  Core.eval(m, :(const page_peeks! = $(on -> peeks!(e, Bool(on)))))
  # ... and the agent that Ladder starts for a change or a question, by its name, and the names that it can be
  Core.eval(m, :(const page_agent = $(() -> (reads!(e, :ai); e.ai))))
  Core.eval(m, :(const page_agent! = $(name -> preferred_agent!(e, String(name)))))
  Core.eval(m, :(const agent_names = $(() -> (reads!(e, :agents); reads!(e, :ai); listed_agents(e)))))
  # ... and every agent that Ladder can start, and whether each is in the lists that you choose an agent from
  Core.eval(m, :(const every_agent = $(() -> [k.name for k in AGENT_KINDS])))
  Core.eval(m, :(const agent_listed = $(name -> (reads!(e, :agents); reads!(e, :ai); String(name) in listed_agents(e)))))
  Core.eval(m, :(const agent_listed! = $((name, on) -> agent_listed!(e, String(name), Bool(on)))))
  # ... and whether a line of a file of code that's too long for the window goes on under itself
  Core.eval(m, :(const code_wrap = $(() -> (reads!(e, :wrap); e.wrap))))
  Core.eval(m, :(const code_wrap! = $(on -> wrap!(e, Bool(on)))))
  # ... and whether it shows the number of each line, and shades the line that the caret is on
  Core.eval(m, :(const code_numbers = $(() -> (reads!(e, :numbers); e.numbers))))
  Core.eval(m, :(const code_numbers! = $(on -> numbers!(e, Bool(on)))))
  Core.eval(m, :(const code_shade = $(() -> (reads!(e, :shade); e.shade))))
  Core.eval(m, :(const code_shade! = $(on -> shade!(e, Bool(on)))))
  # ... and how many spaces one step of indentation is in code: 2 or 4
  Core.eval(m, :(const code_indent = $(() -> (reads!(e, :indent); e.indent))))
  Core.eval(m, :(const code_indent! = $(n -> indent_width!(e, Int(n)))))
  # ... and how big code is, in pixels. It grows and shrinks with the page's text.
  Core.eval(m, :(const code_text_size = $(() -> (reads!(e, :code_scale); reads!(e, :zoom); code_size(e).value))))
  Core.eval(m, :(const code_text_size! = $(size -> code_size!(e, size))))
  # ... and the font of code, by the name in the list of `code_fonts()`. `code_family(name)` gives the font's own name, to draw the name in.
  Core.eval(m, :(const code_fonts = $(() -> font_label.(unique([code_fonts(); e.code_font])))))
  Core.eval(m, :(const code_family = $(name -> font_family(String(name)))))
  Core.eval(m, :(const code_font = $(() -> (reads!(e, :code_font); font_label(e.code_font)))))
  Core.eval(m, :(const code_font! = $(name -> code_font!(e, font_family(String(name))))))
  # ... and its weight, by name: `code_weights()` gives the weights that the font has, and `code_weight()` the one that code is drawn in
  Core.eval(m, :(const code_weights = $(() -> (reads!(e, :code_font); [w.label for w in text_weights(e.code_font)]))))
  Core.eval(m, :(const code_weight = $(() -> (reads!(e, :code_font); reads!(e, :code_weight); nearest_weight(e.code_font, e.code_weight).label))))
  Core.eval(m, :(const code_weight! = $(name -> code_weight!(e, String(name)))))
  # ... and after how many characters a faint line goes down a file of code. 0 is no line.
  Core.eval(m, :(const code_guide = $(() -> (reads!(e, :guide); e.guide))))
  Core.eval(m, :(const code_guide! = $(n -> guide!(e, Int(n)))))
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
  # ... and the key bindings. `key_bundles()` gives the names of the bundles, and `key_bundle()` the one that's chosen.
  # `key_list()` shows each command with its keys, and a click on one changes them. `keys_changed()` is true when a
  # command has other keys than the bundle's, and `key_reset!()` gives every command the bundle's keys again.
  Core.eval(m, :(const key_bundles = $(() -> String[first(b) for b in BUNDLES])))
  Core.eval(m, :(const key_bundle = $(() -> (reads!(e, :bundle); e.bundle))))
  Core.eval(m, :(const key_bundle! = $(name -> bundle!(e, String(name)))))
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
  Core.eval(m, :(const app_updates = $(() -> (reads!(e, :updates); e.updates))))
  Core.eval(m, :(const app_updates! = $(on -> updates!(e, Bool(on)))))
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
  m
end

# --- one thing in many parts of the page -------------------------------------------------------
#
  Core.eval(m, :(const term_again = $(() -> (reads!(e, :terminal); TERM_SETTINGS.again))))
  Core.eval(m, :(const term_again! = $(on -> term_setting!(e, :again, Bool(on)))))
# One thing can show in many parts of a page. A to-do item is a line of the
# text, a card of a board, a bar of a schedule, a thing of a calendar's day
# and the rows of a time log. A row of a table is a bar of a chart. While the
# mouse is on a thing in one part, each other part marks the same thing, so
# you see where it is in all of them.
#
# A thing is known by its name: the words of a to-do item, the task of a row
# of a log, the first cell of a row of a table. No part sends another a
# message. `pointed(part)` is the name of what the mouse is on in a part, and
# `marked(part, name)` is true while the mouse is on a thing of that name
# anywhere in the page. A kind of block joins in with a method of `pointed`,
# and a call of `marked` where it draws a thing.

"A name as two parts of the page compare it. Capital letters, and the space round it, make no other name."
plain_name(name::AbstractString) = lowercase(strip(name))

"The colour `back` with the accent colour over it, as strong as a mark is: what's behind a thing that's marked"
mark_colour(back) = begin
  a, b = convert(RGBA{Float64}, back), convert(RGBA{Float64}, colours.accent)
  RGBA(a.r + (b.r - a.r) * MARK_FILL, a.g + (b.g - a.g) * MARK_FILL, a.b + (b.b - a.b) * MARK_FILL, 1.0)
end

"The name of the thing that the mouse is on in `part`, or nothing. A kind of block that shows things by name has a method."
pointed(part) = nothing

"What tells a thing of a calendar from the others for the rest of the page: the name of its task or its to-do item, or the words of an event"
thing_name(t::Calendars.Thing) = t.kind == :event ? t.words : t.key

pointed(v::BoardView) = begin
  v.grab === nothing || return nothing
  for card in values(v.parts)
    card isa BoardCard && ishovered(card) && return card.key
  end
  nothing
end

pointed(v::CalendarView) = begin
  v.grab === nothing || return nothing
  for c in values(v.parts)
    c isa CalendarThing && c.thing !== nothing && ishovered(c) && return thing_name(c.thing)
  end
  nothing
end

pointed(v::ScheduleView) = (i = v.grab === nothing ? hot_row(v) : 0; i == 0 ? nothing : v.tasks[i].todo.key)

pointed(v::TimelogView) = begin
  s = Timelogs.stretch(v.data, hot_stretch(v))
  s === nothing || isempty(s.task) ? nothing : s.task
end

pointed(v::ChartView) = begin
  a = get(v.parts, :area, nothing)
  (a === nothing || !ishovered(a) || v.shown === nothing) && return nothing
  m, labels = chart_hit(v), v.shown[2].labels
  m !== nothing && 1 <= m.label <= length(labels) ? labels[m.label] : nothing
end

"Each part of the page that shows: the children of the document, in the order of their lines"
shown_parts(e) = begin
  out = Any[]
  child = getfield(node!(Document, e, :document), :firstchild)
  while child !== nothing
    push!(out, child)
    child = getfield(child, :nextsibling)
  end
  out
end

"The table of the page that the item `it` shows, as `page_tables` gives it, or nothing"
item_table(e, it::Item) = (ts = page_tables(e); k = findfirst(t -> t.first == it.first, ts); k === nothing ? nothing : ts[k])

"The name of row `r` of a table of the page: its first cell that holds something. The row of the columns' names has none."
row_name(table, r::Int) = begin
  (1 <= r <= length(table.rows) && !(r == 1 && table.headed)) || return nothing
  k = findfirst(!isempty, table.rows[r])
  k === nothing ? nothing : table.rows[r][k]
end

"""
The rows of the table or the sheet that the item `it` shows, each with its
name, how far its top is from the top of the item, and how tall it is. A row
with no name is left out.
"""
named_rows(e, it::Item) = begin
  out = Tuple{String,px,px}[]
  g = it.content
  g isa Union{Grid,Sheet} || return out
  table = item_table(e, it)
  (table === nothing || table.ranged) && return out   # the rows of a sheet over a range are its values, and not its own rows
  y = g isa Grid ? TABLE_GAP + g.head : 0px
  for r in eachindex(g.rows)
    top, high = g isa Grid ? (y, g.heights[r] + 1px) : (row_top(g, r), g.heights[r])
    y += high
    name = row_name(table, r)
    name === nothing || push!(out, (name, top, high))
  end
  out
end

"""
The line of the page's text that the mouse is on, and the name of the thing
on it: a to-do item, or a row of a table, of a spreadsheet or of a sheet. It's
nothing when the mouse is on no such line.
"""
pointed_line(e) = begin
  (zooming(e) === nothing && full_block(e) === nothing && e.popup == :none) || return nothing
  win = window_of(e)
  (win === nothing || isempty(e.layout) || held(e, Keys.mouse_left) || !ishovered(node!(Document, e, :document))) && return nothing
  x, y = num(win.mouse[1]), num(win.mouse[2])
  line = todo_line(e, x, y)
  if line !== nothing
    k = findfirst(t -> t.line == line, page_todos(e))
    return k === nothing ? nothing : (line, page_todos(e)[k].key)
  end
  dx, dy = px(x) - e.origin[1], px(y) - e.origin[2]
  (0px <= dx < e.width && y >= num(above_page(e)) && dy >= 0px) || return nothing
  it = e.layout[item_under(e, dx, dy)]
  for (r, (name, top, high)) in enumerate(named_rows(e, it))
    it.top + top <= dy < it.top + top + high && return (it.first + r, name)
  end
  nothing
end

"""
Find the thing that the mouse is on, before the page is laid out: in the
page's text, or else in the first part of the page that says so. `pointed(e)`
gives its name until the next frame.
"""
point_tick!(e) = begin
  found = pointed_line(e)
  if found === nothing
    for part in shown_parts(e)
      name = pointed(part)
      name === nothing || (found = (0, name); break)
    end
  end
  e.nodes[:pointed] = found === nothing ? nothing : (found[1], plain_name(found[2]))
  e
end

"The name of the thing that the mouse is on, in any part of the page that shows, or nothing"
pointed(e::Editor) = (p = get(e.nodes, :pointed, nothing); p === nothing ? nothing : p[2])

"True while the mouse is on a thing called `name`, in any part of the page"
marked(e::Editor, name::AbstractString) = (p = pointed(e); p !== nothing && p == plain_name(name))
marked(part, name::AbstractString) = marked(editor(part), name)

"""
Mark the thing that the mouse is on where the page's text has it too: a soft
box behind each to-do item and each row of a table that has its name. The line
that the mouse is on has none. The page's text is at `ui`.
"""
mark_pointed(ctx, e, ui) = begin
  p = get(e.nodes, :pointed, nothing)
  p === nothing && return
  from, name = p
  fill = tint(colours.accent, MARK_FILL)
  todos = nothing
  for it in e.layout[e.shown]
    across, wide = item_room(e, it)
    left, top = num(ui.left + across), num(ui.top + it.top)
    f = it.content
    if shows_box(f) && it.first != from
      todos === nothing && (todos = page_todos(e))
      k = findfirst(t -> t.line == it.first, todos)
      k !== nothing && plain_name(todos[k].key) == name && round_box(ctx, left - 6, top, num(wide) + 12, num(it.tall), 5; fill)
    elseif f isa Union{Grid,Sheet}
      long = f isa Grid ? num(f.left + sum(f.widths, init=0px) + 1px * (length(f.widths) + 1)) : num(wide)
      for (r, (row, y, high)) in enumerate(named_rows(e, it))
        plain_name(row) == name && it.first + r != from && round_box(ctx, left, top + num(y), long, num(high), 0; fill)
      end
    end
  end
end

# --- the day that the page shows ---------------------------------------------------------------
#
# A page shows itself as it stands on one day: today, until the page has a
# code block in the language `day`. day.jl says how that block is written. It
# shows a line of days with a slider on it. Drag the slider, click a day, or
# press ← and →, and the page's day changes while the mouse moves. When the
# mouse lets go, the day goes into the block's line. Today takes the line
# away, so the page follows the real day again.
#
# No part of the page is told. Each part that would ask for today asks
# `page_day(e)`:
#
#   - A schedule draws its line of today on that day. A task that the plan
#     finishes before that day shows as done.
#   - The box of each to-do item that the schedule has a task for shows the
#     same: a tick when the plan has the task finished by then. A past day
#     that git keeps the page for has git's ticks instead.
#   - A board puts each card where the schedule's plan has its task on that
#     day: to do, doing or done. Its cards stay where they are while it does.
#   - A calendar shows the month of that day, with a circle round the day.
#   - A time log adds up the hours to that day, when the day is past. A chart
#     of the log draws those hours.
#   - The text shows what git has of the page for that day, when the day is
#     past and git keeps the page: see "the page's text on its day".
#
# The slider goes from the first to the last day of the things of the page.
# `page_days` finds those: it asks the schedule for its tasks, and reads the
# days of the to-do items, the events and the rows of the logs.

const DAY_BLOCK = Days.DAY
const DAY_TRACK = 50px    # how tall the line of days is
const DAY_PAD = 20.0      # px from each end of that line to the edge of the block
const DAY_KNOB = 7.0      # the radius of the slider
push!(BLOCK_ICONS, "calendar-day")

"What a `day` block shows: a line of days with a slider on it, which sets the day that the page shows"
@def mutable struct DayView <: SemanticUI
  n::Int = 0                               # its place among the page's blocks of this kind
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  day::Union{Nothing,Date} = nothing       # the day that its lines say, or nothing for today
  lines::Vector{String} = String[]         # the lines that `day` was read from
  at::Union{Nothing,Date} = nothing        # the day that the slider is on while the mouse drags it
  grab::Bool = false                       # the mouse holds the slider
  days::Vector{Date} = Date[]              # the days that the line shows
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the line of days was last drawn in the window
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its buttons and its line of days, kept between frames
end

"The line of days of a `day` block, with the slider on it"
@def mutable struct DayTrack <: SemanticUI
  of::Any = nothing
end

reread!(v::DayView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.day = Days.day(lines)
  v
end

"The lines that open and close the page's first `day` block, or nothing. They're found again when the page has changed."
day_block(e) = (b = e.buf; get!(() -> block_lines(b, DAY_BLOCK, 1), e.flows, (:day_block, b.path, b.version)))

"""
The day that the page shows itself on: today, unless the page has a `day`
block that says another. Each part of the page that shows what's done, what's
running or what's to come asks for this day.
"""
page_day(e) = begin
  today = calendar_today()
  span = day_block(e)
  span === nothing && return today
  v = block_view(e, DAY_BLOCK, 1)
  reread!(v, e.buf.lines[span[1]+1:span[2]-1])
  something(v.at, v.day, today)
end

"True when the page shows a day that isn't today"
another_day(e) = page_day(e) != calendar_today()

"""
How the task `t` of a schedule stands on the page's day: `:done`, `:doing` or
`:todo`. On another day than today, a task that repeats isn't done while its
next run is still to come: it's `:doing` on the days of a run. One with a limit,
like `every day for 3 days`, is done after the last day of its last run.
"""
standing(e, t::Schedules.Planned) = begin
  d, today = page_day(e), calendar_today()
  if d != today && Schedules.repeats(t.todo) !== nothing
    weekends = calendar_tasks(e)[2]
    z = Schedules.last_day(t, weekends)
    z !== nothing && d > z && return Days.stands(t.start, z, t.todo.done, d, today)
    return Schedules.running(t, d, weekends) ? :doing : :todo
  end
  Days.stands(t.start, t.finish, t.todo.done, d, today)
end

"True when the task `t` shows as done: it's ticked, or on another day than today, the plan has it finished by then"
finished(e, t::Schedules.Planned) = another_day(e) ? standing(e, t) == :done : t.todo.done

"The tasks of the page's schedule, when the page shows another day than today. On the real day, and with no schedule, there are none: the page shows what's ticked."
planned_tasks(e) = another_day(e) ? calendar_tasks(e)[1] : Schedules.Planned[]

"""
The days of the things of the page: the days of its schedule's tasks, of its
to-do items that have a day, of its calendars' events and of the rows of its
time logs. They're found again when the page has changed.
"""
page_days(e) = begin
  b = e.buf
  get!(e.flows, (:page_days, b.path, b.version, calendar_today())) do
    out = Date[]
    foreach(t -> push!(out, t.start, t.finish), calendar_tasks(e)[1])
    for t in page_todos(e)
      d = Calendars.stamp(t.name)
      d === nothing || push!(out, d)
    end
    for (i, k) in enumerate(kinds(b))
      (k.kind == Kind.code && k.lang in (CALENDAR, TIMELOG)) || continue
      d = Days.day((b.lines[i],))
      d === nothing || push!(out, d)
    end
    # The slider goes back to the page's first commit, when git keeps the page: see "the page's text on its day"
    h = !isempty(b.path) && isfile(b.path) ? page_history(page_key(b.path)) : nothing
    h === nothing || push!(out, h.commits[end][2])
    out
  end
end

"Make `d` the page's day, and write it into the block's line. Today takes the line away."
set_day!(v::DayView, d::Date) = begin
  v.at = nothing
  write_block!(v, DAY_BLOCK, Days.written(v.lines, d == calendar_today() ? nothing : d))
  handled
end

act!(v::DayView, action, w) = begin
  e = editor(v)
  action == :today ? set_day!(v, calendar_today()) : set_day!(v, page_day(e) + Day(action == :back ? -1 : 1))
end

"How far across the window the middle of the day at place `i` of the line is"
day_spot(v::DayView, i::Real) = v.box[1] + DAY_PAD + (i - 0.5) * (v.box[3] - 2DAY_PAD) / max(length(v.days), 1)

"The day of the line that's nearest to `x` across the window"
day_near(v::DayView, x::Real) = begin
  n = length(v.days)
  n == 0 && return calendar_today()
  v.days[clamp(floor(Int, (x - v.box[1] - DAY_PAD) / max((v.box[3] - 2DAY_PAD) / n, 1e-6)) + 1, 1, n)]
end

"What happens to a `day` block in each frame, before the page is laid out: the slider follows the mouse that holds it, and its day is written down when the mouse lets go"
block_tick!(v::DayView) = begin
  v.grab || return v
  w = window_of(v)
  w === nothing && return (v.grab = false; v)
  if held(v, Keys.mouse_left)
    v.at = day_near(v, num(w.mouse[1]))
  else
    v.grab = false
    v.at === nothing || set_day!(v, v.at)
  end
  v
end

describe(v::DayView) = begin
  e = editor(v)
  today, d = calendar_today(), page_day(e)
  v.days = collect(Days.span(page_days(e), today, d))
  with_theme(component_theme(e.zoom)) do
    off = readonly(e.buf)
    bar = block_bar(
      block_button!(v, :back, :back, icon="chevron-left", tip="The day before", off=off),
      block_button!(v, :on, :on, icon="chevron-right", tip="The day after", off=off),
      Box(width(6px)),
      Box(label("$(Dates.dayname(d)) $(Schedules.long(d))", 13px, weight="Semibold")),
      Box(width(8px)),
      # The row is as tall as the bar, so that it doesn't cut the tails of its letters off
      Row(width(grow=grow), height(grow=grow), clip=true, Alignment.Center,
          Box(label(d == today ? "Today" : uppercasefirst(Days.away(d, today)) * (isempty(then_words(e)) ? "" : ", and " * then_words(e)), 12px, color=colours.dim)), Box(width(grow=grow))),
      block_button!(v, :today, :today, words="Today", tip="Show the page as it is today", off=off || (d == today && v.day === nothing)))
    Column(block_look()..., clip=true, name="Day", bar, block_part!(() -> DayTrack(of=v), v, :track))
  end
end

describe(::DayTrack) = Box(width(grow=grow), height(DAY_TRACK))

draw(ctx, size, ui::ConcreteRect, t::DayTrack) = begin
  v = t.of
  v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  n = length(v.days)
  (v.box[3] > 2DAY_PAD && n > 0) || return
  e = editor(v)
  left, top = v.box[1], v.box[2]
  today, d = calendar_today(), page_day(e)
  step = (v.box[3] - 2DAY_PAD) / n
  line = top + 30
  small = Face(SANS, "", 11px, colours.dim, false)
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    round_box(ctx, left + DAY_PAD, line - 2, v.box[3] - 2DAY_PAD, 4, 2; fill=RGBA(colours.ink, 0.1))
    # The names of the days go over the line: each Monday, or the first day of each month when the days are narrow
    weekly = 7step >= 50
    for (i, day) in enumerate(v.days)
      x = day_spot(v, i)
      monday, first = Dates.dayofweek(day) == 1, Dates.day(day) == 1
      step >= 7 && trace(ctx, [(x, line - 6), (x, line - 3)], RGBA(colours.ink, monday ? 0.35 : 0.15), 1.0)
      (weekly ? monday : first) || continue
      words = weekly ? "$(Dates.day(day)) $(Dates.monthabbr(day))" : Dates.monthabbr(day)
      write_ink(ctx, words, x - num(measure(small, words)) / 2, top + 16, small)
    end
    # The line is coloured from today to the page's day, and today has its name under it
    a, b = findfirst(==(today), v.days), findfirst(==(d), v.days)
    if a !== nothing
      x = day_spot(v, a)
      b === nothing || a == b || round_box(ctx, min(x, day_spot(v, b)), line - 2, abs(day_spot(v, b) - x), 4, 2; fill=RGBA(colours.accent, 0.45))
      disc(ctx, x, line, 3.5, colours.ink)
      words = "Today"
      write_ink(ctx, words, clamp(x - num(measure(small, words)) / 2, left + 4, left + v.box[3] - num(measure(small, words)) - 4), line + 16, small)
    end
    if b !== nothing
      x = day_spot(v, b)
      disc(ctx, x, line, DAY_KNOB + 2, takeoff_back())
      disc(ctx, x, line, DAY_KNOB, colours.accent)
    end
  end
end

cursor(::DayTrack) = :hand
cursor(::DayView) = :arrow

onkey(t::DayTrack, ev::KeyPress{Keys.mouse_left}) = begin
  v = t.of
  readonly(editor(v).buf) && return handled
  focus(t)
  v.grab = true
  v.at = day_near(v, num(ev.window.mouse[1]))
  handled
end
onkey(t::DayTrack, ev::KeyPress{Keys.left}) = unmodified(ev) ? act!(t.of, :back, nothing) : nothing
onkey(t::DayTrack, ev::KeyPress{Keys.right}) = unmodified(ev) ? act!(t.of, :on, nothing) : nothing
onkey(t::DayTrack, ev::KeyPress{Keys.escape}) = unmodified(ev) ? (focus(editor(t.of)); handled) : nothing
# A click beside a button is the block's, and doesn't move the caret
onkey(::DayView, ::KeyPress{Keys.mouse_left}) = handled
# A drag is the slider's, so the page's text doesn't select
onmouse(v::DayView, ::MouseMove) = v.grab ? handled : nothing

"The block as HTML: the day that the page shows"
day_html(e, v::DayView) = (d = something(v.day, calendar_today()); "<p><strong>$(Dates.dayname(d)) $(Schedules.long(d))</strong></p>")

BLOCKS[DAY_BLOCK] = DayView
block_name(::Type{DayView}) = "Day"
block_icon(::Type{DayView}) = "calendar-day"
block_insert(::Type{DayView}) = ("Day", ["```$DAY_BLOCK", "```", "", ""], (4, 0))
block_html(e, v::DayView) = day_html(e, v)

# --- the page's text on its day ------------------------------------------------------------------
#
# A page in a folder that git keeps has its past. On a day before today, the
# text shows that past too: Ladder asks git for the page as its last commit
# of that day had it, and compares it with the page as it is now.
#
#   - The box of a to-do item shows a tick only if the item was ticked then.
#     A click on a box does nothing until the page shows today again.
#   - A line that wasn't on the page then, or that read another way, is
#     fainter, with a grey bar beside it. A tick alone is no other way to read.
#   - A board with no schedule to plan from puts each card where its item
#     was then.
#
# The slider of a `day` block goes back to the day of the page's first
# commit. A page that git doesn't keep, and a day with nothing to compare,
# shows as it is.

"How many seconds the commits of a page stay good, before git is asked for them again"
const HISTORY_FRESH = 30.0
"The commits of each page that was asked for, by the page's real path: when git was asked, the top folder of the page's repository, the page's place in it, and the commits, newest first, each as its hash and its day"
const PAGE_HISTORY = Dict{String,Any}()
"The lines of a page in a commit, by the repository's folder, the commit's hash and the page's place. A commit never changes, so they're kept."
const COMMIT_LINES = Dict{Tuple{String,String,String},Vector{String}}()

"""
What git has of the page at `path`: the top folder of its repository, its
place in that folder, and its commits, the newest first, each as its hash and
its day. It's nothing for a page that no repository holds, or that has no
commit yet.
"""
page_history(path::AbstractString) = begin
  kept = get(PAGE_HISTORY, path, nothing)
  kept !== nothing && time() - kept.at < HISTORY_FRESH && return kept.found
  found = try
    root = Git.top(path)
    if isempty(root)
      nothing
    else
      rel = relpath(path, realpath(root))
      commits = [(hash, DatesRead.day(at)) for (hash, at) in Git.history(root, rel)]
      isempty(commits) ? nothing : (root=root, rel=rel, commits=commits)
    end
  catch
    nothing   # no git on this Mac, or a folder that macOS doesn't let Ladder read
  end
  length(PAGE_HISTORY) > 500 && empty!(PAGE_HISTORY)
  PAGE_HISTORY[path] = (at=time(), found=found)
  found
end

"The lines of the page at `rel` in the commit `hash` of the repository at `root`, or none when the commit hasn't got the page"
commit_lines(root, hash, rel) = begin
  length(COMMIT_LINES) > 200 && empty!(COMMIT_LINES)
  get!(COMMIT_LINES, (root, hash, rel)) do
    text = Git.at_commit(root, hash, rel)
    text === nothing ? String[] : String.(split(chomp(text), '\n'))
  end
end

"The line `text` with the box of a to-do item empty, so that a tick alone doesn't make two lines differ"
unticked(text::AbstractString) = replace(text, r"^(\s*[-*+] \[)[xX](\])" => s"\1 \2")

"""
The page as git has it for the page's day, when that day is before today:

  - `lines`: its lines in the last commit of that day or before it. There
    are none when its first commit came later.
  - `later`: for each line of the page as it is now, true when the line
    wasn't there then, or read another way.
  - `ticks`: for the line of each to-do item of the page now, true when the
    item was ticked then.

It's nothing when the page shows today, and for a page that git doesn't keep.
"""
page_then(e) = begin
  b = e.buf
  (b.view == :markdown && !isempty(b.path)) || return nothing
  d = page_day(e)
  d < calendar_today() || return nothing
  # Each to-do item of the page asks in each frame, so what was found is good for a second without a look at the disk
  kept = get(e.flows, (:page_then_at, b.path, b.version, d), nothing)
  kept !== nothing && time() - kept[1] < 1 && return kept[2]
  found = page_then(e, d)
  e.flows[(:page_then_at, b.path, b.version, d)] = (time(), found)
  found
end

"The page as git has it for the day `d`, as `page_then(e)` gives it for the page's day. It looks at the disk, for whether the page's file is there."
page_then(e, d::Date) = begin
  b = e.buf
  h = isfile(b.path) ? page_history(page_key(b.path)) : nothing
  h === nothing && return nothing
  k = findfirst(c -> c[2] <= d, h.commits)
  hash = k === nothing ? "" : h.commits[k][1]
  get!(e.flows, (:page_then, b.path, b.version, hash)) do
    lines = k === nothing ? String[] : commit_lines(h.root, hash, h.rel)
    later = falses(length(b.lines))
    for (_, new) in changes(unticked.(lines), unticked.(b.lines)), i in new
      later[i] = true
    end
    was = Dict(t.key => t.done for t in Schedules.todos(lines))
    ticks = Dict{Int,Bool}(t.line => get(was, t.key, false) for t in page_todos(e))
    (lines=lines, later=later, ticks=ticks)
  end
end

"""
True or false when the box of the to-do item on line `i` shows how the item
stands on the page's day, ticked or not. On a day before today that git has
the page for, it's git's tick of that day. On any other day than today, it's
the schedule's plan: a task that the plan has finished by then has a tick.
It's nothing when the page shows today, and for an item that neither says
anything about, and so the box shows the line's own tick.
"""
ticked_then(e, i::Int) = begin
  i > 0 || return nothing
  then = page_then(e)
  then === nothing || return get(then.ticks, i, nothing)
  get(planned_ticks(e), i, nothing)
end

"For the line of each to-do item that the page's schedule has a task for, true when the plan has that task finished by the page's day. There are none on the real day, and on a page with no schedule."
planned_ticks(e) = begin
  another_day(e) || return Dict{Int,Bool}()
  b = e.buf
  get!(e.flows, (:planned_ticks, b.path, b.version, page_day(e), calendar_today())) do
    Dict{Int,Bool}(t.todo.line => finished(e, t) for t in planned_tasks(e))
  end
end

"The to-do items of the page as they stand on the page's day: each is done if git has it ticked then. On the real day, and for a page that git doesn't keep, they're the page's own."
todos_then(e) = begin
  then = page_then(e)
  then === nothing && return page_todos(e)
  b = e.buf
  get!(e.flows, (:todos_then, b.path, b.version, objectid(then))) do
    [Schedules.Todo(t.line, t.name, t.key, t.level, get(then.ticks, t.line, false)) for t in page_todos(e)]
  end
end

"How strongly the page's own colour covers a line that wasn't on the page on its day"
const LATER_VEIL = 0.62

"Make each line of text that wasn't on the page on its day fainter, and draw a grey bar in the margin beside it. The text is drawn already."
veil_later(ctx, e, ui) = begin
  then = page_then(e)
  (then === nothing || slideshow(e) !== nothing) && return
  left = ui.left + sideways(e)
  n = length(then.later)
  for it in e.layout[e.shown]
    (it.content isa Flow && it.first <= n && all(i -> then.later[i], it.first:min(it.last, n))) || continue
    isempty(strip(e.buf.lines[it.first])) && it.first == it.last && continue   # an empty line has nothing to make fainter
    rectangle(ctx, ui.left, ui.top + it.top, ui.width, it.tall, background=RGBA(colours.bg, LATER_VEIL), border=0px)
    rectangle(ctx, left - 16px, ui.top + it.top, 3px, it.tall, background=RGBA(colours.ink, 0.22), border=0px)
  end
end

"What a `day` block says of the page's text on a day before today: that it shows as git has it, or that git has none so early. It's \"\" when the text shows as it is."
then_words(e) = begin
  then = page_then(e)
  then === nothing && return ""
  isempty(then.lines) && return "before this page's first commit"
  n = count(i -> then.later[i] && !isempty(strip(e.buf.lines[i])), eachindex(then.later))   # an empty line is no line to read
  n == 0 ? "the text is as it was" : "$n line$(n == 1 ? "" : "s") came later"
end

# --- a number that a drag changes ---------------------------------------------------------------
#
# A sum in a line of text that is one number, like !`l = 16m`, shows what it
# comes to: 16m. So does a row of a sheet that is one number. A drag on that
# value, to the right or to the left, makes the number bigger or smaller. Each
# step of the drag writes the new number into the page's text, so every other
# part that reads it follows while the mouse moves: the rows of the sheet
# under that row, a chart of the sheet, and the sums in a line that use the
# sum's name. ⇧ makes each step ten times as big. A click that doesn't move
# puts the caret where a click puts it anywhere else.
#
# A sum in a line of text keeps what it made, so that it runs once. When a
# sum of the page changes, `inline_tick!` forgets what the sums after it made,
# and they run again from the top down.

const SCRUB_STEP = 5.0         # px that the mouse moves for one step of a number, near where the drag started
const SCRUB_SPEEDUP = 200.0    # px: each this much further from there, the steps come e times as fast

"""
How many steps of a number a drag of `dx` px from where it started makes. Near
the start it's one step for each `SCRUB_STEP` px, so a small change is easy to
make. Further away, the steps come faster and faster: 100px makes 26 steps, and
1000px makes 5,897, which is more than 200 times as many.
"""
scrub_steps(dx) = (k = SCRUB_SPEEDUP / SCRUB_STEP; round(Int, sign(dx) * k * expm1(abs(dx) / SCRUB_SPEEDUP)))

"""
The number at the place `pos` of the window that a drag can change: its line,
and the columns that it runs from and to. It's the number of a sum in a line
of text, under what the sum shows, or the number of a row of a sheet, under
what the row comes to. Nothing when the place has no such number.
"""
scrub_at(e, pos) = begin
  b = e.buf
  (isempty(e.layout) || readonly(b) || b.fixed || b.view != :markdown) && return nothing
  dx, dy = pos[1] - e.origin[1], pos[2] - e.origin[2]
  (dy >= 0px && pos[2] >= above_page(e)) || return nothing
  it = e.layout[item_under(e, dx, dy)]
  # Until the next frame, the layout is of the page that showed before, which can have more lines than this one
  it.last <= length(b.lines) || return nothing
  y = dy - it.top
  c = it.content
  if c isa Flow
    (!c.raw && 0px <= y < tall(c)) || return nothing
    chars = collect(b.lines[it.first])
    for seg in c.lines[line_at(c, y)].segs
      (seg.atomic && seg.node === nothing && seg.x <= dx < seg.x + seg.w) || continue
      # The piece stands for the code of !`code`
      (seg.col >= 2 && seg.col + seg.n <= length(chars) && chars[seg.col-1] == '!' && chars[seg.col] == '`') || continue
      at = number_at(String(chars[seg.col+1:seg.col+seg.n]))
      return at === nothing ? nothing : (it.first, seg.col + at[1], seg.col + at[2])
    end
  elseif c isa Sheet
    across, wide = item_room(e, it)
    r = rowunder(c, y)
    res = c.results[r]
    (res.failed || isempty(res.text) || !(row_top(c, r) <= y < row_top(c, r) + c.heights[r])) && return nothing
    # What the row comes to is at the right end of the row
    w = chip_w(Face(SHEET_FONT, SHEET_WEIGHT, c.size, colours.ink, false), res)
    (wide - SHEET_X - w <= dx - across < wide - SHEET_X) || return nothing
    cell = c.cells[r][end]
    at = number_at(rest(head(b.lines[c.rows[r]], cell.hi), cell.lo))
    return at === nothing ? nothing : (c.rows[r], cell.lo + at[1], cell.lo + at[2])
  end
  nothing
end

"""
Draw a line of dashes under each sum in a line of text that a drag can change,
so that it reads as a number to take hold of. The page's text is at `ui`.
"""
underline_scrubs(ctx, e, ui) = begin
  b = e.buf
  (readonly(b) || b.fixed || b.view != :markdown) && return
  for it in e.layout[e.shown]
    f = it.content
    (f isa Flow && !f.raw && occursin(INLINE, b.lines[it.first])) || continue
    chars = collect(b.lines[it.first])
    for vl in f.lines, seg in vl.segs
      (seg.atomic && seg.node === nothing && seg.col >= 2 && seg.col + seg.n <= length(chars) && chars[seg.col-1] == '!' && chars[seg.col] == '`') || continue
      number_at(String(chars[seg.col+1:seg.col+seg.n])) === nothing && continue
      y = num(ui.top + it.top + f.above + vl.top + vl.high / 2) + num(f.size) * 0.62
      trace(ctx, [(num(ui.left + seg.x), y), (num(ui.left + seg.x + seg.w), y)], tint(colours.accent, 0.75), 1.0, dashed=true)
    end
  end
end

# --- where the value of a name comes from ---------------------------------------------------------------
#
# A sum in a line of text that is only a name, like !`energy`, shows the value
# of that name. Another part of the page gives the name its value: a sum like
# !`energy = convert(TWh, …)`, a row of a sheet like "Energy = …", or the code
# of a `julia` block. Over that value the mouse is a hand. A click on it goes
# to the part that gives the name its value, and selects it there. A cell of a
# table works the same way. ⌘⌥← comes back to where the click was.
#
# A name can get a value in more than one place. The sums run from the top of
# the page down, so the click goes to the last place over the value. When no
# place is over it, the click goes to the first place under it.

"""
The sum in a line of text whose value is drawn at the point `pos` of the
window, when the sum's code is only a name, like !`energy`: the name, and the
line and the column where the sum's code starts. It's nothing anywhere else,
and where the line shows its code.
"""
value_name_at(e, pos) = begin
  b = e.buf
  (isempty(e.layout) || b.view != :markdown || !runs_sums(e) || slideshow(e) !== nothing) && return nothing
  dx, dy = pos[1] - e.origin[1], pos[2] - e.origin[2]
  (dy >= 0px && pos[2] >= above_page(e)) || return nothing
  it = e.layout[item_under(e, dx, dy)]
  # Until the next frame, the layout is of the page that showed before, which can have more lines than this one
  it.last <= length(b.lines) || return nothing
  dx -= item_room(e, it)[1]   # a column of a group starts at its own left edge
  dy -= it.top
  c = it.content
  c isa Flow && return value_name(b, it.first, c, dx, dy)
  c isa Grid || return nothing
  # Each cell of a table has its own lines of text. Their columns are the columns of the row's line.
  for r in eachindex(c.rows), k in eachindex(c.flows[r])
    cx, cy = cell_origin(c, r, k)
    found = value_name(b, c.rows[r], c.flows[r][k], dx - cx, dy - cy)
    found === nothing || return found
  end
  nothing
end

"`value_name_at` for the text `f` of line `i`, at `dx` across and `dy` down from its top left"
value_name(b::Buffer, i::Int, f::Flow, dx::px, dy::px) = begin
  f.raw && return nothing
  k = findfirst(vl -> f.above + vl.top <= dy < f.above + vl.top + vl.high, f.lines)
  k === nothing && return nothing
  hit = findfirst(seg -> seg.x <= dx < seg.x + seg.w, f.lines[k].segs)
  hit === nothing && return nothing
  seg = f.lines[k].segs[hit]
  (seg.atomic && seg.node === nothing && 1 <= i <= length(b.lines)) || return nothing
  line = b.lines[i]
  for m in eachmatch(r"!`([^`]+)`", line)
    from = length(line, 1, m.offset) + 1   # the column where the code starts, after the ! and the `
    n = length(m[1])
    # The first word of a value stands for all of its code. The words after it are at the code's end: see `wrap`.
    (later_word(seg) ? seg.col == from + n : seg.col == from && seg.n == n) || continue
    name = strip(m[1])
    return Base.isidentifier(name) ? (name=String(name), line=i, col=from) : nothing
  end
  nothing
end

"""
The places of the page that give the name `name` a value, from the top of the
page down. Each is the first and the last place of the part that gives it: a
sum in a line of text, like !`energy = …`, a row of a block, like a sheet's
"Energy = …", or a name that a `julia` block makes outside of a function.
"""
givers(e, name::AbstractString) = get(name_givers(e), name, NO_GIVERS)

const NO_GIVERS = Tuple{Pos,Pos}[]

"`givers` for each name of the page. They're found again when the page has changed."
name_givers(e) = begin
  b = e.buf
  get!(e.flows, (:name_givers, b.path, b.version)) do
    out = Dict{String,Vector{Tuple{Pos,Pos}}}()
    give!(name, from, to) = push!(get!(() -> Tuple{Pos,Pos}[], out, name), (from, to))
    ks = kinds(b)
    i = 1
    while i <= length(ks)
      k = ks[i]
      if k.kind == Kind.fence && k.level == 0
        t = codeblock(b, i)[2]
        if t > i && ks[t].kind == Kind.fence && ks[t].level == 1
          haskey(BLOCKS, k.lang) && block_givers!(give!, e, k.lang, i, t)
          i = t
        end
      elseif !(k.kind in (Kind.fence, Kind.code))
        # From the ! to the ` that ends the sum
        for (_, _, code, col) in get!(() -> named_sums(b.lines[i]), e.flows, (:named_sums, b.lines[i]))
          give!(String(sum_name(code)), (i, col - 2), (i, col + length(code) + 1))
        end
      end
      i += 1
    end
    for m in page_bounds(e)
      # A line that brings a name in from another file, like `using Dates`, doesn't give it a value here
      (m.span === nothing && !occursin(r"^\s*(@use|using|import)\b", b.lines[m.at[1]])) || continue
      give!(m.name, m.at, (m.at[1], m.at[2] + length(m.name)))
    end
    foreach(sort!, values(out))
    out
  end
end

"""
Give `give!` the place of each name that the block in the language `lang`, from
line `i` to line `t`, gives. A sum uses the name of a row as Julia knows it:
\"Wall length\" is `wall_length`. The place is the start of the first line
of the block that starts with the name, or else has it, or else the block's first line.
"""
block_givers!(give!, e, lang, i::Int, t::Int) = begin
  lines = e.buf.lines[i+1:t-1]
  isempty(lines) && return
  for (name, _) in get!(() -> block_names(BLOCKS[lang], lines), e.flows, (:block_names, lang, lines))
    id = ident(name)
    isempty(id) && continue
    low = lowercase(strip(name))
    j = something(findfirst(l -> startswith(lowercase(lstrip(l)), low), lines), findfirst(l -> occursin(low, lowercase(l)), lines), 1)
    at = (i + j, length(lines[j]) - length(lstrip(lines[j])))
    give!(id, at, at)
  end
end

"""
Where the value that the name `name` has at the column `col` of line `i` comes
from, as a place that `givers` gives: the last place over it, or else the
first place under it. Nothing when no part of the page gives the name a value.
"""
giver(e, name::AbstractString, i::Int, col::Int) = begin
  places = givers(e, name)
  isempty(places) && return nothing
  places[something(findlast(p -> p[1] < (i, col), places), 1)]
end

"The place that gives a value to the name whose value is at the point `pos` of the window, as `giver` gives it, or nothing"
giver_at(e, pos) = begin
  found = value_name_at(e, pos)
  found === nothing ? nothing : giver(e, found.name, found.line, found.col)
end

"How far the place `p` of the page is under the page's top, and how far the end of its line on screen is"
place_span(e, p::Pos) = begin
  it = item(e, p[1])
  c = it.content
  if c isa Flow
    k = spot(c, p[2])[1]
    top = it.top + line_top(c, k)
    return (top, top + c.lines[k].high)
  elseif c isa Sheet && !isempty(c.rows)
    r = clamp(p[1] - it.first, 1, length(c.rows))
    top = it.top + row_top(c, r)
    return (top, top + c.heights[r])
  end
  (it.top, it.top + it.tall)
end

"""
Go to the part of the page from `from` to `to`, which gives a name its value,
and select it. A part that's on screen stays where it is. Another comes a
third of the way down the window. ⌘⌥← comes back.
"""
go_to_giver!(e, (from, to)) = begin
  note_place!(e)
  b = e.buf
  b.anchor, b.caret = from, to
  e.popup = :none
  # The mouse is still down. A move must not select from here to the mouse: see `drag!`.
  e.clicked = (time(), (from[1], 0), 0)
  focus(e)
  s = e.scroll
  top, bottom = place_span(e, from)[1], place_span(e, to)[2]
  (s.offset <= PAGE_TOP + top - 30px && PAGE_TOP + bottom + 40px <= s.offset + s.viewport) ||
    (s.offset = max(0px, PAGE_TOP + top - s.viewport / 3))
  touch!(e)
  e
end

"""
The words that a click with ⌘ at the point `pos` acts on, as the line and the
columns where they start and end: a link, or a name of Julia code that has a
place where it's defined. It's nothing where a click with ⌘ does neither.
`cursor(::Document)` and `press!` find the same.
"""
cmd_words(e, pos) = begin
  line, col = locate(e, pos)
  it = item(e, line)
  it.content isa Flow || return nothing
  segs = [seg for vl in it.content.lines for seg in vl.segs]
  k = findfirst(s -> s.col <= col < s.col + s.n && !isempty(s.link), segs)
  if k !== nothing
    # A link's words can be in several runs of text, as where part of them is bold
    a = z = k
    while a > 1 && segs[a-1].link == segs[k].link; a -= 1 end
    while z < length(segs) && segs[z+1].link == segs[k].link; z += 1 end
    return (line, segs[a].col, segs[z].col + segs[z].n)
  end
  found = name_at(e.buf, (line, col))
  (found === nothing || Base.invokelatest(definition, e, (line, col)) === nothing) && return nothing
  (line, found.col, found.col + length(found.name))
end

"""
While ⌘ is held by itself, mark the words under the mouse that a click would
act on: a soft box behind them and a line under them, as the mouse is a hand
there. The page's text is at `ui`.
"""
mark_clickable(ctx, e, ui) = begin
  w = window_of(e)
  if !(w !== nothing && only_held(w, Keys.cmd) && e.popup == :none && e.buf.view != :file && slideshow(e) === nothing)
    # The card of a name goes when ⌘ comes up
    w === nothing || pop!(e.nodes, :peek, nothing) === nothing || hide_tooltip!(w)
    delete!(e.nodes, :cmd_mouse)
    return
  end
  redraw_in!(e, 1/30)   # the mark follows the mouse, and goes when ⌘ comes up
  found = cmd_words(e, w.mouse)
  peek!(e, w, found)
  found === nothing && return
  line, lo, hi = found
  it = item(e, line)
  f = it.content::Flow
  k1, x1 = spot(f, lo)
  k2, x2 = spot(f, hi)
  # Words that wrap onto a second line are marked on each line that they're on
  for k in k1:k2
    vl = f.lines[k]
    isempty(vl.segs) && continue
    left = k == k1 ? x1 : first(vl.segs).x
    right = k == k2 ? x2 : last(vl.segs).x + last(vl.segs).w
    right > left || continue
    top = ui.top + it.top + line_top(f, k)
    round_box(ctx, num(ui.left + left) - 1, num(top), num(right - left) + 2, num(vl.high), 3; fill=tint(colours.accent, MARK_FILL))
    y = num(top + vl.high / 2) + num(f.size) * 0.62
    trace(ctx, [(num(ui.left + left), y), (num(ui.left + right), y)], colours.accent, 1.0)
  end
end

# --- a card of what a name is ---
#
# While ⌘ is held, a name that has a place where it's defined is marked. When
# the mouse rests on it for a moment, a card under it shows that place: the
# name's documentation and the first lines of its code, from the page or from
# another file. A link's card has where it goes. The card goes when the mouse
# moves, and comes again when the mouse rests.
#
# No card shows until the mouse moves after ⌘ goes down. ⌘ is often pressed
# for a key like ⌘S, and what is under a mouse that didn't move is chance.

const PEEK_WAIT = 0.6   # seconds that the mouse rests on a name before its card shows
const PEEK_LINES = 8    # the most lines of code that a card shows

"""
The lines of `lines` that a card shows for the definition on line `at`: its
documentation above it, and the lines of its code, as many as `most`, up to
the line `last`.
"""
peek_lines(lines, at::Int, last::Int, most=PEEK_LINES) = begin
  from = peek_from(lines, at)
  stop = min(last, at + most - 1)
  while stop > at && isempty(strip(lines[stop])); stop -= 1 end
  [length(l) > 100 ? first(l, 99) * "…" : l for l in lines[from:stop]]
end

"The first line that a card shows for the definition on line `at` of `lines`: the first of the documentation above it that shows"
peek_from(lines, at::Int) = begin
  from = at
  above = at > 1 ? strip(lines[at-1]) : ""
  if startswith(above, '"') && endswith(above, '"')
    # One line of documentation, like "Words" or """Words"""
    from = at - 1
    # Documentation of several lines ends with three quotes, and starts on the line that starts with three quotes
    if endswith(above, "\"\"\"") && !(startswith(above, "\"\"\"") && length(above) >= 6)
      from = something(findprev(l -> startswith(strip(l), "\"\"\""), lines, at - 2), at - 1)
    end
  elseif endswith(above, "\"\"\"")
    from = something(findprev(l -> startswith(strip(l), "\"\"\""), lines, at - 2), at)
  end
  max(from, at - 6)   # long documentation shows its last lines, next to the code
end

"""
What the card of the words `found`, which `cmd_words` gave, shows: where a
link goes, or where a name is defined, with the lines there. It's nothing
when there's nothing to show.
"""
peek_card(e, found) = begin
  line, lo, hi = found
  b = e.buf
  it = item(e, line)
  segs = it.content isa Flow ? [s for vl in it.content.lines for s in vl.segs] : []
  k = findfirst(s -> s.col <= lo < s.col + s.n && !isempty(s.link), segs)
  # Each line has a set height: a Text alone in a box can be less tall than its line, and the lines then overlap
  said(text; family=SANS, color=TIP_INK) = Box(height(17px), Text(text, size=12px, family=family, color=color, wrap=WrapMode.none))
  faint = RGBA(TIP_INK.r, TIP_INK.g, TIP_INK.b, 0.65)
  if k !== nothing
    # A link to a page shows the start of the page, unless the setting is off. Any other link says where it goes.
    page = e.peeks ? linked_page(e, segs[k].link) : nothing
    card = page === nothing ? nothing : page_peek(e, page...)
    return something(card, Box(padding(10px, 7px), said(segs[k].link)))
  end
  place = Base.invokelatest(definition, e, (line, lo))
  place === nothing && return nothing
  # `open` says if the first line that shows is inside a docstring, when long documentation shows only its last lines
  head, lines, lang, open = if place isa Method
    spot = code_place(place)
    spot === nothing && return nothing
    file, at = spot
    _, all, starts = file_parts(file)
    at = settled_line(place, all, at)
    j = max(1, searchsortedlast(starts, at))
    last = j == length(starts) ? length(all) : starts[j+1] - 1
    open = foldl((q, l) -> left_open(l, "julia", q), view(all, 1:peek_from(all, at)-1), init='\0')
    ("$(basename(file)):$at", peek_lines(all, at, last), "julia", open)
  else
    at = place[1]
    # A name of a function, like a variable in it, is one line. A name of the whole page shows its code.
    local_name = any(m -> m.at == place && m.span !== nothing, page_bounds(e))
    j = local_name ? nothing : findfirst(c -> c.first <= at <= c.last, code_blocks(e))
    last = local_name ? at : j === nothing ? at + PEEK_LINES - 1 : code_blocks(e)[j].last
    l = kinds(b)[at]
    ("line $at", peek_lines(b.lines, at, min(last, length(b.lines))), l.kind == Kind.code ? shared_lang(l.lang) : "julia",
     string_opens(b)[peek_from(b.lines, at)])
  end
  # The code has the colours that it has in the page
  Box(padding(10px, 8px), Column(Alignment.Start, child_gap=1px, said(head, color=faint), tip_code(lines, lang; open)...))
end

"""
Show the card of the words `found` when the mouse has rested on them for a
moment while ⌘ is held, and take it away when the mouse is on other words.
The mouse must move after ⌘ goes down before a card shows.
"""
peek!(e, w, found) = begin
  # Where the mouse was when ⌘ went down, or :moved once it has moved from there
  still = get!(e.nodes, :cmd_mouse, w.mouse)
  still === :moved || w.mouse == still || (e.nodes[:cmd_mouse] = still = :moved)
  was = get(e.nodes, :peek, nothing)
  if found === nothing || was === nothing || was.words != found
    was === nothing || !was.shown || hide_tooltip!(w)
    found === nothing ? delete!(e.nodes, :peek) : (e.nodes[:peek] = (words=found, since=time(), shown=false))
    return
  end
  # A mouse move took the card away. It comes again when the mouse rests.
  if was.shown
    any(p -> p.key == :tooltip, popups(w)) || (e.nodes[:peek] = (words=found, since=time(), shown=false))
    return
  end
  # The moment of rest starts when the mouse first moves
  still === :moved || (e.nodes[:peek] = (words=found, since=time(), shown=false); return)
  time() - was.since < PEEK_WAIT && return
  card = peek_card(e, found)
  e.nodes[:peek] = (words=found, since=was.since, shown=true)
  card === nothing && return
  line, lo, hi = found
  it = item(e, line)
  f = it.content::Flow
  k, x = spot(f, lo)
  _, x2 = spot(f, hi)
  top = e.origin[2] + it.top + line_top(f, k)
  # The start of a page is a card of the page's own colours, and not a dark box. It goes as a tooltip does, when the mouse moves.
  card isa PagePeek && return popup!(w, card.layout, anchor=(e.origin[1] + x, top, max(x2 - x, 4px), f.lines[k].high),
                                     placement=:below, gap=4px, key=:tooltip, input=false)
  show_tooltip!(w, card, e.origin[1] + x, top, max(x2 - x, 4px), f.lines[k].high; placement=:bottom, gap=4px)
end

# --- the start of a page in a link's card ---
#
# While ⌘ is held, the card of a link to a page shows the start of that page,
# as the page reads, so you can read it without leaving your own page. A link
# to a heading, like [[Ideas#Plans]], shows the page from that heading to the
# next heading that's as big. A page that's open shows as it is now, with what
# isn't saved yet. The setting "Show a page when I hold ⌘ over its link" turns
# this off, and the card then says where the link goes, as for any other link.

const PEEK_PAGE_W = 440px      # how wide the card of a page is
const PEEK_PAGE_HIGH = 280px   # the most of the page that shows. A longer page is cut there.

"The start of a page, for the card of a link to it: what shows, kept apart from other cards so that it isn't put in a dark box"
struct PagePeek
  layout::Any
  flows::Vector{Flow}   # the lines of the page that it shows, laid out
end

"""
The page that the link `url` goes to, and the heading of the page that it
names, or "" for none. It's nothing for a link that doesn't go to a Markdown
page that's there: a web address, a footnote, a file of another kind, or a
wiki link to a page that isn't made yet.
"""
linked_page(e, url::AbstractString) = begin
  startswith(url, '^') && return nothing   # a footnote
  in_browser(e.buf.path) && return nothing   # a page from a web server links to no page of the Mac
  target = wikitarget(url)
  path, heading = if target !== nothing
    name, mark = occursin('#', target) ? String.(split(target, '#', limit=2)) : (String(target), "")
    name = String(strip(name))
    (isempty(name) ? e.buf.path : wiki_path(e, name), mark)
  else
    # A link to anything but a file, like an https: or a mailto: address, isn't a page
    to = linked_file(e, url)
    to === nothing && return nothing
    (to[1], unescaped(to[2]))
  end
  (ismarkdown(path) && (isfile(path) || path == e.buf.path && !isempty(e.buf.lines))) || return nothing
  (path, String(strip(heading)))
end

"""
The lines of the page at `path`, their kinds, and the lines of them that the
card of a link shows: from the heading `heading` to the next heading that's as
big, or from the top, after the page's front matter. A page that's open gives
its lines as they are now. It's nothing when the file can't be read as text.
"""
peek_page_lines(e, path, heading) = begin
  b = path == e.buf.path ? e.buf : get(e.buffers, path, nothing)
  lines = if b !== nothing
    b.lines
  else
    found = reading(path, tidy=false)
    found === nothing && return nothing
    found[1]
  end
  isempty(lines) && return nothing
  ks = classify(lines)
  from, to = front_matter(lines) + 1, length(lines)
  if !isempty(heading)
    slug = heading_slug(heading)
    i = findfirst(i -> ks[i].kind == Kind.heading && heading_slug(rest(lines[i], ks[i].prefix)) == slug, eachindex(ks))
    if i !== nothing
      from = i
      next = findnext(j -> ks[j].kind == Kind.heading && ks[j].level <= ks[i].level, eachindex(ks), i + 1)
      next === nothing || (to = next - 1)
    end
  end
  while from < to && isempty(strip(lines[from])); from += 1 end
  while to > from && isempty(strip(lines[to])); to -= 1 end
  (lines, ks, from:to)
end

"""
The card of a link to the page at `path`: the page's name, with the heading
`heading` after it, over the start of the page as it reads, a little smaller
than the page's own text. Only as many lines are laid out as the card shows.
It's nothing when the page has nothing to show.
"""
page_peek(e, path, heading) = begin
  found = peek_page_lines(e, path, heading)
  found === nothing && return nothing
  lines, ks, shown = found
  wide = PEEK_PAGE_W - 2 * 6px - 2 * 14px   # the card has 6px of room on each side, and the page 14px inside that
  zoom = e.zoom
  e.zoom = zoom * PAGE_ZOOM
  flows = Flow[]
  # -1 says that the line isn't one of the document's, so its inline code isn't run
  try
    total = 0px
    for i in shown
      push!(flows, laid(e, lines[i], ks[i], false, -1, wide))
      total += tall(flows[end])
      total > PEEK_PAGE_HIGH && break
    end
  finally
    e.zoom = zoom
  end
  isempty(flows) && return nothing
  total = sum(tall, flows)
  name = splitext(basename(path))[1]
  title = isempty(heading) ? name : "$name  ›  $heading"
  PagePeek(Column(fixed(PEEK_PAGE_W), Alignment.Start, padding(6px), radius(8px), background(colours.block),
                  border(1px, :solid, colours.line), lifted, child_gap=4px,
    Row(width(grow=grow), height(22px), padding(8px, 0px), child_gap=6px, clip=true,
      Icon("file-earmark-text", size=12px, color=colours.dim), label(title, 12px, color=colours.dim)),
    Box(width(grow=grow), height(min(total, PEEK_PAGE_HIGH) + 2TEXT_PAD), padding(14px, 0px), radius(5px), background(colours.bg), clip=true,
      Column(width(grow=grow), Alignment.Start, spacer(TEXT_PAD),
        [describe(e, Item(0, 0, 0px, tall(f), f), f) for f in flows]...))), flows)
end

"Turn on or off whether the card of a link to a page shows the start of the page, while ⌘ is held"
peeks!(e, on::Bool) = (e.peeks = on; save_settings!(e); rerun!(e, :peeks); e)

"Make the agent called `name` the one that Ladder starts for a change or a question: see \"the agents that Ladder can start\""
preferred_agent!(e, name::String) = begin
  any(k -> k.name == name, AGENT_KINDS) || error("Ladder can't start an agent called $name.")
  e.ai = name
  save_settings!(e)
  rerun!(e, :ai)
  redraw_windows!()   # the logo on the line round a thing shows the new agent
  e
end

"Take hold of the number at `found`, which `scrub_at` gave, with the mouse at `pos`"
scrub!(e, found, pos) = begin
  i, lo, hi = found
  b = e.buf
  e.nodes[:scrub] = (line=i, lo=lo, hi=hi, x=num(pos[1]), text=rest(head(b.lines[i], hi), lo), steps=0, moved=false)
  b.typed = 0.0   # the drag is taken back by itself, and not with what was typed before it
  e.popup = :none
  e.clicked = (time(), (i, 0), 0)
  took(e) || focus(e)
  e
end

"Give the number that the mouse holds the value for where the mouse is now, and write it into its line. The caret stays with its text."
scrub_to!(e, pos) = begin
  s = e.nodes[:scrub]
  b = e.buf
  steps = scrub_steps(num(pos[1]) - s.x) * (only_held(e, Keys.shft) ? 10 : 1)
  (steps == s.steps || !(1 <= s.line <= length(b.lines))) && return e
  new = nudged(s.text, steps)
  caret, anchor = b.caret, b.anchor
  edit!(b, (s.line, s.lo), (s.line, s.hi), new, typing=true)
  by = length(new) - (s.hi - s.lo)
  kept(p) = p[1] == s.line && p[2] >= s.hi ? (p[1], p[2] + by) : p
  b.caret, b.anchor = kept(caret), kept(anchor)
  e.nodes[:scrub] = (; s..., hi=s.lo + length(new), steps, moved=true)
  e
end

"What happens in each frame to a number that the mouse holds: when the mouse lets go, the drag ends. A press that never moved was a click, and puts the caret there."
scrub_tick!(e) = begin
  s = get(e.nodes, :scrub, nothing)
  (s === nothing || held(e, Keys.mouse_left)) && return e
  delete!(e.nodes, :scrub)
  b = e.buf
  b.typed = 0.0
  w = window_of(e)
  if !s.moved && w !== nothing
    b.caret = b.anchor = settle(b, locate(e, w.mouse))
    touch!(e)
  end
  e
end

"The code of each sum in a line of text of the page, in the order of the page"
inline_codes(e, b::Buffer) = get!(e.flows, (:inline_codes, b.path, b.version)) do
  String[m[1] for i in inline_lines(e, b) for m in eachmatch(r"!`([^`]+)`", b.lines[i])]
end

"""
Run again the sums in a line of text that come after a sum that changed, so
that a sum which uses a name follows the sum that gives the name its value.
What a sum made is forgotten, and the sum runs when its line is next laid
out. A sum that made a node, like a switch, keeps its node, so the switch
stays on. A node made from names that the page's sums and sheets give, like
!`ProgressBar(value=done / jobs)`, is made again, so it follows the numbers.
`also` is what else the sums read, as `inline_given!` gives it: when that
changes, every sum runs again.
"""
inline_tick!(e) = begin
  b = e.buf
  b.view == :markdown || return e
  key = (:inline_seen, b.path)
  seen = get(e.nodes, key, nothing)
  seen !== nothing && seen[1] == b.version && return e
  codes = inline_codes(e, b)
  also = inline_given!(e)
  e.nodes[key] = (b.version, codes, also)
  seen === nothing && return e
  also == seen[3] || (CODE_RUNS[] += 1)   # a row of a sheet has a new value, so the page's `check` blocks run again
  (codes == seen[2] && also == seen[3]) && return e
  from = also == seen[3] ? something(findfirst(i -> i > length(seen[2]) || seen[2][i] != codes[i], eachindex(codes)), length(codes) + 1) : 1
  counts = Dict{String,Int}()
  # The names that the page's sums and sheets give
  names = Set{Symbol}(Iterators.flatten((filter(!isnothing, sum_name.(codes)), (Symbol(ident(name)) for (name, _) in page_given(e)))))
  for (i, code) in enumerate(codes)
    n = counts[code] = get(counts, code, 0) + 1
    i >= from || continue
    was = get(e.nodes, (:inline, b.path, code, n), nothing)
    (was isa Tuple || (was isa Shown && follows(code, names))) && delete!(e.nodes, (:inline, b.path, code, n))
  end
  # A sum that the page no longer has is forgotten too, so that it runs if it comes back
  for k in collect(keys(e.nodes))
    (k isa Tuple && length(k) == 4 && k[1] == :inline && k[2] == b.path && e.nodes[k] isa Tuple) || continue
    get(counts, k[3], 0) < k[4] && delete!(e.nodes, k)
  end
  e
end

pointed(v::ContactView) = begin
  # A to-do item under a contact's details is the item, and not the contact
  for r in values(v.parts)
    r isa ContactWork && ishovered(r) || continue
    m = work_of(r)
    return m === nothing ? nothing : m.text
  end
  for card in values(v.parts)
    card isa ContactCard && ishovered(card) || continue
    c = contact_of(v, card.k)
    return c === nothing || isempty(Contacts.title(c)) ? nothing : Contacts.title(c)
  end
  nothing
end

# --- the clock of a to-do item -----------------------------------------------------------------
#
# On a page with a time log, the mouse over a to-do item shows a small
# button at the end of the item's line, with the hours that the log has for
# the item. A click starts the log's clock on the item: the log gets a new
# line for now, with the item's words as its task. While the clock runs on
# the item, the button stops it. A tick in the item's box stops it too.
#
# The item and the log send each other nothing. The button calls the log's
# own `Timelogs.start!` and `Timelogs.stop!` on the log's view, and writes
# the log's block. The schedule asks `worked` for the hours of each task, and
# shows them beside the task's name.

push!(BLOCK_ICONS, "play-fill", "stop-fill")

"The view of the page's first time log, read again from the lines of its block, or nothing when the page has none or can't be changed"
page_log(e) = begin
  b = e.buf
  (readonly(b) || b.fixed) && return nothing
  span = get!(() -> block_lines(b, TIMELOG, 1), e.flows, (:log_block, b.path, b.version))
  span === nothing && return nothing
  v = block_view(e, TIMELOG, 1)
  v.first, v.last = span
  reread!(v, b.lines[span[1]+1:span[2]-1])
end

"""
The minutes that the page's time logs have for each task, by the task's name
as `plain_name` gives it. A row that runs counts up to now, so they're worked
out again each minute, and when the page has changed.
"""
page_minutes(e) = begin
  b = e.buf
  at = Timelogs.now()
  get!(e.flows, (:minutes, b.path, b.version, Dates.format(at, "yyyymmddHHMM"))) do
    out = Dict{String,Int}()
    ks = kinds(b)
    for (i, k) in enumerate(ks)
      (k.kind == Kind.fence && k.level == 0 && k.lang == TIMELOG) || continue
      t = codeblock(b, i)[2]
      (t > i && ks[t].kind == Kind.fence && ks[t].level == 1) || continue
      for (task, minutes) in Timelogs.tasks(Timelogs.timelog(b.lines[i+1:t-1]), at)
        out[plain_name(task)] = get(out, plain_name(task), 0) + minutes
      end
    end
    out
  end
end

"The minutes that the page's time logs have for the task called `name`"
worked(e, name::AbstractString) = get(page_minutes(e), plain_name(name), 0)

"The to-do item of the page that a schedule calls `key`, or nothing"
todo_called(e, key) = (items = page_todos(e); k = findfirst(t -> t.key == key, items); k === nothing ? nothing : items[k])

"True when the clock of the log `log` runs on the task called `name`"
clocked(log::TimelogView, name::AbstractString) = begin
  run = Timelogs.running(log.data)
  run !== nothing && plain_name(log.data.rows[run].task) == plain_name(name)
end

describe(c::ItemClock) = begin
  e = editor(c)
  log, t = page_log(e), todo_called(e, c.key)
  (log === nothing || t === nothing) && return Box(width(0px), height(18px))
  on = clocked(log, t.name)
  on && redraw_in!(c, 1.0)   # the hours count up
  minutes = worked(e, t.name)
  words = on ? Timelogs.elapsed(Timelogs.seconds(log.data, Timelogs.running(log.data), Timelogs.now())) : minutes > 0 ? Timelogs.hours(minutes) : ""
  Row(height(18px), child_gap=4px, Alignment.Center, name="Clock",
    Box(width(18px), height(18px), radius(4px), Alignment.Center, justify=Alignment.Center,
        background(on ? colours.active : ishovered(c) ? colours.hover : clear),
      Icon(on ? "stop-fill" : "play-fill", size=12px, color=on ? colours.accent : colours.dim)),
    (isempty(words) ? () : (Box(label(words, 12px, color=on ? colours.accent : colours.dim)),))...)
end

cursor(::ItemClock) = :hand
draw(ctx, size, ui::ConcreteRect, c::ItemClock) = (c.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(c::ItemClock, ev::MouseMove) = begin
  e = editor(c)
  log, t = page_log(e), todo_called(e, c.key)
  (log === nothing || t === nothing) && return handled
  show_tooltip!(ev.window, tip_label(clocked(log, t.name) ? "Stop the clock" : "Start the clock on this item"), c.rect..., placement=:top, gap=6px)
  handled
end

onkey(c::ItemClock, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(c)
  log, t = page_log(e), todo_called(e, c.key)
  hide_tooltip!(ev.window)
  (log === nothing || t === nothing) && return handled
  at = Timelogs.now()
  clocked(log, t.name) ? Timelogs.stop!(log.data, at) : Timelogs.start!(log.data, t.name, at)
  write_log!(log)
  handled
end

"""
Stop the clock of the page's time log, when it runs on the to-do item of line
`i` and the item has just been ticked. The stop is taken back with the tick.
"""
stop_clock!(e, i::Int) = begin
  b = e.buf
  (1 <= i <= length(b.lines) && isdone(b.lines[i])) || return e
  log = page_log(e)
  log === nothing && return e
  k = findfirst(t -> t.line == i, page_todos(e))
  (k !== nothing && clocked(log, page_todos(e)[k].name)) || return e
  Timelogs.stop!(log.data, Timelogs.now())
  b.typed = time()   # the tick and the log's line change together, so one ⌘Z takes both back
  write_block!(log, TIMELOG, Timelogs.written(log.data), typing=true)
  b.typed = 0.0
  e
end

# --- names that one part of the page has from another -------------------------------------------
#
# A row of a sheet can use a name from a part of the page over it, the way
# it uses the name of a row above it: a measure of a takeoff, a task of a
# time log, and a row of another sheet. So "Tiles = kitchen floor tiles /
# 0.36m^2" follows the outline that's drawn on the plan. A sum in a line of
# text can use the same names, and the names of every sheet of the page, as
# Julia knows them: !`wall_length` for the row "Wall length". The code of the
# page's `julia` blocks can use them too.
#
# No part sends its values anywhere. `block_names(lang, lines)` says what the
# block of one kind gives: each name with an expression for its value, as a
# row of a sheet has. A sheet asks for the names of the blocks over it with
# `page_given`, and works them out as rows over its first row.

"""
What a block in the language `lang` gives the rest of its page: names, each
with an expression for its value, as a row of a sheet has. `lines` are the
lines of the block. A sheet gives its rows, a takeoff gives each measure with
its amount, and a time log gives each task with its hours.
"""
block_names(lang::AbstractString, lines) =
  haskey(BLOCKS, lang) ? block_names(BLOCKS[lang], lines) : Tuple{String,String}[]

"""
The names that the sums in a line of text give, each with the code of its
value: !`farm = 2GW` gives ("farm", "2GW"). A sum that gives no name, like
!`farm * 2`, gives nothing. A `_` of a name is a space, so a row of a sheet
can use !`farm_cost = …` as "farm cost", the way a sum uses the row "Farm
cost" as `farm_cost`.
"""
sum_names(text::AbstractString) = [(name, expr) for (name, expr, _, _) in named_sums(text)]

"What `sum_names` gives, with the code of each sum and the column where its code starts in `text`"
named_sums(text::AbstractString) = begin
  out = Tuple{String,String,String,Int}[]
  occursin(INLINE, text) || return out
  for m in eachmatch(r"!`([^`]+)`", text)
    code = String(m[1])
    name = sum_name(code)
    name === nothing && continue
    # The name has no =, so the first = is the one after it
    push!(out, (replace(String(name), '_' => ' '), String(strip(code[nextind(code, findfirst('=', code)):end])), code, length(text, 1, m.offset) + 1))
  end
  out
end

"The name that the code of a sum gives, like `:farm` for `farm = 2GW`, or nothing"
sum_name(code::AbstractString) = begin
  ex = try Meta.parse(code, raise=false) catch; nothing end
  ex isa Expr && ex.head == :(=) && length(ex.args) == 2 && ex.args[1] isa Symbol ? ex.args[1] : nothing
end

"""
True when the code of a sum uses one of `names` for its value. The name that
the sum gives doesn't count, nor does the name of a keyword: in
`p = ProgressBar(value=x)` only `x` counts.
"""
follows(code::AbstractString, names) = begin
  ex = try Meta.parse(code, raise=false) catch; return false end
  sum_name(code) === nothing || (ex = ex.args[2])
  found = false
  look(x) = if x isa Symbol
    x in names && (found = true)
  elseif x isa Expr
    foreach(look, x.head in (:kw, :(=)) && x.args[1] isa Symbol ? x.args[2:end] : x.args)
  end
  look(ex)
  found
end

"""
The names that the parts of the page over line `upto` give, each with an
expression for its value. With no line, it's the names of the whole page.
With `sums`, the sums in the lines of text give their names too, so a sheet
can use !`farm = 2GW` as `farm`. They're found again when the page has changed.
"""
page_given(e, upto::Int=typemax(Int); sums::Bool=false) = given_and_sums(e, upto, sums)[1]

"""
`page_given`, and where each name that a sum gives is: its place in that
list, and the code and the ordinal that `made` keeps the sum by.
"""
given_and_sums(e, upto::Int, sums::Bool) = begin
  b = e.buf
  get!(e.flows, (:given_sums, b.path, b.version, upto, sums)) do
    out = Tuple{String,String}[]
    spots = Tuple{Int,String,Int}[]
    ks = kinds(b)
    i = 1
    while i <= length(ks) && i < upto
      k = ks[i]
      if k.kind == Kind.fence && k.level == 0
        t = codeblock(b, i)[2]
        if t > i && ks[t].kind == Kind.fence && ks[t].level == 1
          if t < upto && haskey(BLOCKS, k.lang)
            got = get!(() -> block_names(BLOCKS[k.lang], b.lines[i+1:t-1]), e.flows, (:block_names, k.lang, b.lines[i+1:t-1]))
            isempty(got) || append!(out, got)
          end
          i = t
        end
      elseif sums && !(k.kind in (Kind.fence, Kind.code))
        for (name, expr, code, col) in get!(() -> named_sums(b.lines[i]), e.flows, (:named_sums, b.lines[i]))
          push!(out, (name, expr))
          push!(spots, (length(out), code, ordinal(e, i, col, code)))
        end
      end
      i += 1
    end
    (out, spots)
  end
end

"""
What the sheet whose block opens on line `upto` has from the parts of the
page over it: what `page_given` gives with `sums`, but a sum that didn't go
wrong gives what it came to, as a `Given`, in place of its code. The sheet
takes that value as it is. So a sum that takes long, like one that adds up
thousands of numbers, runs once for its line, and not again for each sheet
under it.

A sum over the sheet that hasn't run since the page changed runs here, as it
would when its line is laid out, from the top down. A chart near the top of
the page asks for every table of the page before the sums under it are laid
out, and the sheet then has the same values for it as for the rest of the frame.

A sheet that's on no page has the names that the part that shows it gives:
the sheet of a SolidCraft design's parameters has the design's.
"""
sheet_given(e, upto::Int) = begin
  outside = get(e.nodes, :sheet_names, nothing)
  outside === nothing || return outside
  b = e.buf
  given, spots = given_and_sums(e, upto, true)
  foreach(((_, code, n),) -> made(e, code, n), spots)
  get!(e.flows, (:sheet_given, b.path, b.version, upto, sums_run[])) do
    values = get(e.nodes, (:sum_values, b.path), nothing)
    out = Tuple{String,Any}[given...]
    values === nothing && return out
    for (k, code, n) in spots
      made = get(e.nodes, (:inline, b.path, code, n), nothing)
      (made isa Tuple && !made[2] && haskey(values, (code, n))) || continue
      out[k] = (given[k][1], Given(values[(code, n)]))
    end
    out
  end
end

"""
Keep what the `n`th sum `code` of the page came to, when it gives a name and
didn't go wrong, so that `sheet_given` can give it to the sheets under it.
"""
keep_value!(e, code::String, n::Int, failed::Bool) = begin
  values = get!(() -> Dict{Tuple{String,Int},Any}(), e.nodes, (:sum_values, e.buf.path))
  delete!(values, (code, n))
  name = sum_name(code)
  (failed || name === nothing) && return
  # A drag makes a new sum on each step, so the values of sums that the page no longer has are forgotten
  length(values) > 400 && filter!(((k, _),) -> haskey(e.nodes, (:inline, e.buf.path, k...)), values)
  try
    values[(code, n)] = Base.invokelatest(getglobal, workspace(e), name)
  catch
  end
end

"""
Give the page's code the names of the page's sheets, takeoffs and time logs,
with their values, and say what they came to. A sum in a line of text, and
the code of a `julia` block, can then use a row called "Wall length" as
`wall_length`. A name that the page's code already has, like `sum`, stays as
it is. `inline_tick!` runs the page's sums again when what this gives changes.
"""
inline_given!(e) = begin
  given = page_given(e)
  isempty(given) && return nothing
  values = get!(() -> name_values(given), e.flows, (:name_values, given))
  m = workspace(e)
  ours = get!(() -> Set{Symbol}(), e.nodes, (:given_names, e.buf.path))
  for (id, value) in values
    name = Symbol(id)
    (name in ours || !Base.invokelatest(isdefined, m, name)) || continue
    try
      Core.eval(m, Expr(:(=), name, QuoteNode(value)))
      push!(ours, name)
    catch
    end
  end
  hash(given)
end

# --- blocks that a file defines --------------------------------------------------------------
#
# A page can have kinds of block that Ladder doesn't know. A code block in a
# language that isn't one of Ladder's own, like `progress`, is such a block
# when a file defines the language. The file is `progress.jl` in the page's
# folder, or the file or the GitHub repository that the line that opens the
# block names after the language:
#
#     ```progress                             progress.jl, beside the page
#     ```progress ./widgets.jl                a file that has another name
#     ```progress github.com/sam/blocks       a repository on GitHub
#     ```progress github.com/sam/blocks@v2    one branch of it
#
# The file can be a Markdown page too: `progress.md` beside the page, when
# there's no `progress.jl`, or a path that ends in `.md`. Ladder runs the code
# of the page's `julia` blocks, from the top, in one module, and that module
# defines the kind of block as a Julia file's module does. So the page can say
# in words what its code does, and can hold a block of its own kind to try.
#
# A file beside the page only counts if its text defines a function with the
# language's name that takes one thing. So a page in a folder of Julia code
# doesn't run `json.jl` because it has a block of JSON.
#
# The file has a function with the language's name. Ladder gives it the lines
# of the block, and shows what it makes, as a `ui` block shows what its code
# makes: a node draws itself, and any other value shows as text. If the file
# also has a function called `written`, it gives the lines of what was made,
# and Ladder writes them into the block. So what you do to the block is in
# the page's file.
#
#     progress(lines)          makes a Progress from the lines of the block
#     describe(p::Progress)    draws it
#     written(p::Progress)     the lines of its block now
#
# There are three times that Ladder writes a block's lines:
#
#   - Before something reads the page's text: ⌘S, the caret going into the
#     block, a copy, a page of HTML, another page taking the window. The file
#     does nothing for this.
#   - When the component asks, with UI.jl's `changed!(p)`. Ladder writes in
#     the next frame that the mouse isn't held in. Changes that come one soon
#     after another are one step for ⌘Z.
#   - At once, when the component says `changed!(p, now=true)`.
#
# A change that's written only by the first of these doesn't mark the page as
# edited until then, and ⌘Z can't take it back. So a component asks for a
# write after each change that you'd want to take back.
#
# What was made is kept until the block's lines change some other way: you
# type in them, or ⌘Z puts back older ones. Then the function makes it again.
#
# Ladder asks you before it runs the code of a GitHub repository for the
# first time, and keeps the repositories that you allow in a file.
#
# A file on this Mac is loaded again when it's saved, so a kind of block
# changes as you write it. Each block that the file defines is then made again.

"The file or the repository that follows the language on the line that opens a code block"
const SOURCE = r"^\s*(?:`{3,}|~{3,})\s*[^\s`]+[ \t]+((?:\.{1,2}/|~?/|github\.com/)\S+)\s*$"

"True when Ladder itself says what a code block in the language `lang` shows"
known_lang(lang) = lang in (MATTER, TOML_MATTER, MATH, HEX, BITS, COMMENT, "julia") || haskey(BLOCKS, lang)

"What was found in each file that could define a kind of block: when the file was saved, and whether its text defines the function"
const DEFINES = Dict{Tuple{String,String},Tuple{Float64,Bool}}()

"""
True when the text of `file` defines a function called `name` that takes one
thing, like `progress(lines) = ...` or `function progress(lines)`. The file
is read again only when it's saved.
"""
defines(file::AbstractString, name::AbstractString) = begin
  at = mtime(file)
  at == 0 && return false
  kept = get(DEFINES, (file, name), nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  code = ismarkdown(file) ? join(last.(page_code(file)), "\n") : read(file, String)
  found = occursin(Regex("^(?:function[ \\t]+)?\\Q$name\\E\\([^,;)]+[;)]", "m"), code)
  DEFINES[(file, name)] = (at, found)
  found
end

"""
Where the function of a block in the language `lang` comes from, as Kip names
it: a file or a GitHub repository. `text` is the line that opens the block, and
`folder` is the folder of its page. It's nothing when no file defines the language.
"""
block_source(text::AbstractString, lang::AbstractString, folder::AbstractString) = begin
  (Base.isidentifier(lang) && !known_lang(lang)) || return nothing
  m = match(SOURCE, text)
  m === nothing || return String(m[1])
  isempty(folder) && return nothing
  # A Julia file comes before a Markdown page with the same name
  k = findfirst(ext -> defines(joinpath(folder, lang * ext), lang), (".jl", ".md"))
  k === nothing ? nothing : "./$lang$((".jl", ".md")[k])"
end

"The pages whose code has all run in their module, by path, as the kinds of block that a page defines need"
const PAGES_RUN = Set{String}()

"The name of the module of the page at `path`: its path, with ~ for your home folder, and a ⭒ in front, as Kip's modules have"
page_module_name(path::AbstractString) = Symbol("⭒", Base.Filesystem.contractuser(page_key(path)))

"The code of each `julia` block of the Markdown page at `path`, with the line of the page that it starts on. `lines` are the page's lines."
page_code(path::AbstractString, lines=text(path)) = begin
  ks = classify(lines)
  out = Tuple{Int,String}[]
  for (i, k) in enumerate(ks)
    (k.kind == Kind.fence && k.level == 0 && k.lang == "julia") || continue
    t = something(findnext(c -> c.kind == Kind.fence, ks, i + 1), length(lines) + 1)
    push!(out, (i + 1, join(lines[i+1:t-1], "\n")))
  end
  out
end

"""
Run the code of the Markdown page at `path` in the module `m`: each of its
`julia` blocks, from the top. An error names the line of the page that it's on.
"""
run_page!(m::Module, path::AbstractString) = (page_value(m, path); m)

"""
Run the code of the Markdown page at `path` in the module `m`, as `run_page!`
does. It gives the value of the last `julia` block, or nothing when the page
has none. `lines` are the page's lines, as a page from a web server gives them.
"""
page_value(m::Module, path::AbstractString, lines=text(path)) = begin
  value = nothing
  for (line, code) in page_code(path, lines)
    try
      # Empty lines before the code give each line of it the number that it has in the page
      value = run_in(m, "\n"^(line - 1) * code, path)
    catch err
      error("Line $(err isa LoadError ? err.line : line) of $(basename(path)): $(trouble(err))")
    end
  end
  value
end

"""
Run the code `code` of the page at `path` in the page's module `m`, as
`include_string` does, and give the value that it comes to. A function that
the code defines with the name of a unit, like `bar(p) = …`, is a new function
of the page. Julia gives a unit that new method instead: a unit is a type, and
a page has the units with `using`, so Julia takes the code as a new way to make
the unit. A name that the page loads or makes itself is as Julia has it.
"""
run_in(m::Module, code::AbstractString, path::AbstractString) = begin
  # The code of a page from a site that you don't trust runs in the sandbox: see "the sandbox" in sandbox.jl
  c = sandbox_of(m, path)
  c === nothing ? include_string(ex -> own_units(m, ex), m, code, path) : Guard.run_code(c, code, path; map=ex -> own_units(m, ex))
end

# --- a sum that makes a function --------------------------------------------------------------
#
# Julia compiles code that makes a function each time the code runs, like
# the generator of !`years = sum(exp(-fade * t) for t in 0:0.05:2000)` or the
# `t -> …` of a findfirst. That takes far longer than the sum itself, and a
# drag on a number that the sum reads runs it again on each step. So such a
# sum is made into a function with no arguments the first time, and that
# function runs each time after. It reads the page's names as it runs, so it
# follows them, and Julia compiles it only once.
#
# Only code that means the same in a function does this: code that gives no
# name a value, except inside a `let`, a function or a generator, where the
# name is the code's own. Any other sum runs as the code of a file does.

"""
Run the code of a sum in a line of text in the module `m`, as `run_in` does.
A sum that makes a function runs as a function that's made once: see "a sum
that makes a function".
"""
run_sum(m::Module, code::AbstractString, path::AbstractString) = begin
  f = sum_function(m, code, sandbox_of(m, path))
  f === nothing && return run_in(m, code, path)
  value = Base.invokelatest(f)
  name = sum_name(code)
  name === nothing || Core.eval(m, Expr(:(=), name, QuoteNode(value)))
  value
end

const SUM_FUNCTIONS = Dict{Tuple{Module,String},Any}()   # by the module and the code of a sum

"The function that the code of a sum in the module `m` runs as, or nothing when the code runs as code. With a `sandbox`, the function is made in it."
sum_function(m::Module, code::AbstractString, sandbox=nothing) = begin
  key = (m, String(code))
  haskey(SUM_FUNCTIONS, key) && return SUM_FUNCTIONS[key]
  ex = try Meta.parse(code, raise=false) catch; nothing end
  sum_name(code) === nothing || (ex = ex.args[2])
  made = Expr(:->, Expr(:tuple), Expr(:block, ex))
  f = makes_function(ex) && in_function(ex, true) ? (sandbox === nothing ? Core.eval(m, made) : Guard.run(sandbox, made)) : nothing
  # Typing makes a new sum with each key, so the functions of old sums are forgotten now and then
  length(SUM_FUNCTIONS) >= 500 && empty!(SUM_FUNCTIONS)
  SUM_FUNCTIONS[key] = f
end

"True when the code `ex` makes a function as it runs, or has a loop, which Julia compiles too"
makes_function(ex) = ex isa Expr && (ex.head in (:generator, :comprehension, :typed_comprehension, :->, :do, :function, :for, :while) || any(makes_function, ex.args))

"""
True when the code `ex` means the same in a function as it does on its own.
`top` is true outside a `let`, a function or a generator: there, code that gives
a name a value would give the page's name a value, and in a function it
wouldn't. Code that declares or loads anything, or has a macro, doesn't either.
"""
in_function(ex, top::Bool) = begin
  ex isa Expr || return true
  h = ex.head
  h in (:global, :const, :local, :using, :import, :export, :module, :struct, :abstract, :primitive, :toplevel, :macrocall, :quote) && return false
  # The names in a let, a function or a generator are their own
  h in (:let, :->, :do, :generator, :comprehension, :typed_comprehension) && return all(x -> in_function(x, false), ex.args)
  if h == :function
    # A function with a name gives that name a value
    sig = ex.args[1]
    top && !(sig isa Expr && sig.head == :tuple) && return false
    return all(x -> in_function(x, false), ex.args)
  end
  # The names of a named tuple, and of the keywords of a call, aren't names that get a value
  h in (:tuple, :parameters) && return all(x -> Meta.isexpr(x, :(=)) ? in_function(x.args[2], top) : in_function(x, top), ex.args)
  h == :kw && return in_function(ex.args[2], top)
  top && (h == :(=) || (endswith(string(h), "=") && !(h in (:(==), :(!=), :(<=), :(>=), :(===), :(!==))))) && return false
  all(x -> in_function(x, top), ex.args)
end

"The expression `ex` of a page's code, with `function bar end` before it for each unit, like `bar`, that it defines a function of. See `run_in`."
own_units(m::Module, ex) = begin
  found = filter(n -> unit_of(m, n), defined_names!(Symbol[], ex))
  isempty(found) ? ex : Expr(:toplevel, (Expr(:function, n) for n in unique(found))..., ex)
end

"The names of the functions that the expression `ex` defines, like `f` for `f(x) = x`, added to `out`. A definition can be inside a `begin` block, and have documentation or a macro before it."
defined_names!(out::Vector{Symbol}, ex) = begin
  if Meta.isexpr(ex, (:block, :toplevel))
    foreach(x -> defined_names!(out, x), ex.args)
  elseif Meta.isexpr(ex, :macrocall) && length(ex.args) > 2
    defined_names!(out, last(ex.args))
  elseif is_definition(ex)
    lhs = ex.args[1]
    while Meta.isexpr(lhs, (:where, :(::))) && !isempty(lhs.args)
      lhs = lhs.args[1]
    end
    Meta.isexpr(lhs, :call) && lhs.args[1] isa Symbol && push!(out, lhs.args[1])
  end
  out
end

"True when the name `n` in the module `m` is a unit of a sheet that `m` has with `using`, and not a name of its own or one that it loaded"
unit_of(m::Module, n::Symbol) = begin
  sheet = units()
  Base.invokelatest(isdefined, sheet, n) && Base.invokelatest(isdefined, m, n) || return false
  # The names that `m` has made, and the ones that it loaded by name, like `@use "…/Units.jl" bar`
  n in Base.invokelatest(names, m; all=true, imported=true) && return false
  Base.invokelatest(getglobal, m, n) === Base.invokelatest(getglobal, sheet, n)
end

"""
The module of the page at `path`, which the window `e` asks for. A file of
code that Ladder loaded has the module that Kip made from it, so code that
runs in its window changes what's loaded: see "the code of a thing". The
module of any other page is made the first time, and kept by the page's real
path. It has what a Julia file that Kip loads has, like `@use`, and more
names by the kind of page:

  - The startup page and a folder's page have `Ladder`, as they have when
    Ladder runs their code. Each time Ladder runs one, the page has a new
    module: see `code_module!`.
  - Any other page has the names that its window gives a page's code, like
    UI.jl's components, and each unit of a sheet: see `usual_module`.

The module's name is the page's path. So a page called `stars` can define a
function called `stars`, and two pages with the same name have two modules.
"""
page_module(e, path::AbstractString) = begin
  key = page_key(path)
  # A file of code that Ladder loaded has the module that the file made, so code that runs there changes what's loaded
  loaded = loaded_module(key)
  loaded === nothing || return loaded
  get!(PAGE_WINDOWS, key, e)
  m = get!(() -> ladder_runs(key) ? code_module(key) : usual_module(e, page_module_name(key), key), PAGE_MODULES, key)
  # A window that's newer than the module can give a page's code more names. It gives them once.
  get!(() -> Base.invokelatest(isdefined, m, :Usual) && window_names!(m, e, key), e.nodes, (:page_names, key))
  m
end

"The module of the page at `path`, as `page_module` gives it, with all of the page's code run in it, as a kind of block that the page defines needs"
page_run(e, path::AbstractString) = begin
  m = page_module(e, path)
  key = page_key(path)
  key in PAGES_RUN || (run_page!(m, path); push!(PAGES_RUN, key))
  m
end

"""
Give the file that the window `e` shows a new, empty module for its code, in
place of the one it had. The names, the methods and the files that its code
made or loaded are gone. The new module is made when code next runs on the
file, as it is the first time: see `page_module`. Each window that shows the
file runs its live blocks and its inline code again, in the new module. What
⌘Return showed under the code stays as it was.
"""
reset_module!(e) = begin
  path = e.buf.path
  isempty(path) && delete!(e.nodes, :workspace)
  key = isempty(path) ? "" : page_key(path)
  isempty(key) || (delete!(PAGE_MODULES, key); delete!(PAGES_RUN, key))
  for w in unique!(Any[e; editors])
    w === e || (!isempty(w.buf.path) && page_key(w.buf.path) == key) || continue
    delete!(w.nodes, (:page_names, key))
    # What the page's code made goes, so that it runs again in the new module
    p = w.buf.path
    gone(k) = k isa Tuple && length(k) >= 2 &&
              ((k[1] in (:live, :inline, :given_names, :inline_seen) && k[2] == p) ||
               (k[1] == :replaced && k[2] isa Tuple && k[2][1] == :live && k[2][2] == p))
    foreach(k -> delete!(w.nodes, k), filter(gone, collect(keys(w.nodes))))
    empty!(w.flows)
  end
  nothing
end

"""
The file on this Mac that the source `source` names inside a repository, like
`github.com/sam/blocks/progress.md`. Kip gets the repository if it isn't here.
"""
repository_file(source::AbstractString) = begin
  user, repo, tag, inside = match(Kip.gh_shorthand, source).captures
  folder = Base.invokelatest(Kip.checkout, Base.invokelatest(Kip.getrepo, user, repo), user, repo, tag)
  joinpath(folder, something(inside, ""))
end

"Where the function of the block that opens on line `s` of `b` comes from, or nothing when no file defines its language"
block_source(b::Buffer, s::Int) = foreign(b.path) || sandboxed(b.path) ? nothing : block_source(b.lines[s], kinds(b)[s].lang, isempty(b.path) ? "" : dirname(b.path))

"The `user/repo` of a source that's a GitHub repository, or nothing for a file on this Mac"
repository(source::AbstractString) = (m = match(r"^github\.com/([\w\-.]+)/([\w\-.]+)", source); m === nothing ? nothing : "$(m[1])/$(m[2])")

"The GitHub repositories whose code you let a block run, since Ladder opened"
const ALLOWED = Set{String}()

"The file that keeps the repositories you allowed, one on each line"
allowed_file() = joinpath(dirname(settings_file()), "repositories")

"True when you have let a block run the code of the GitHub repository `repo`"
allowed(e, repo::AbstractString) = repo in ALLOWED || (e.remember && isfile(allowed_file()) && repo in eachline(allowed_file()))

"Let a block run the code of the GitHub repository `repo`, now and when Ladder next opens"
allow!(e, repo::AbstractString) = begin
  allowed(e, repo) && return
  push!(ALLOWED, repo)
  e.remember || return
  try
    mkpath(dirname(allowed_file()))
    open(io -> println(io, repo), allowed_file(), "a")
  catch
    # A file that can't be written only means Ladder asks again the next time it opens
  end
  nothing
end

cursor(::FileBlock) = :arrow

"The view of the `n`th block of the page in the language `lang`, which the file or the repository `source` defines"
file_block(e, lang, source, n) = begin
  v = get!(() -> FileBlock(n=n, lang=lang), e.nodes, (:block, lang, e.buf.path, n))
  own!(node!(Document, e, :document), v)
  v.source == source || (v.source = source; v.from = nothing; v.file = ""; v.state = :new)
  v
end

"What the block in the language `lang` from line `i` to line `t` shows. A file or a repository, `source`, defines the language."
file_block_item(e, lang, source, i, t, n) = begin
  v = file_block(e, lang, source, n)
  v.first, v.last = i, t
  reread!(v, e.buf.lines[i+1:t-1])
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(v)), (e.width, 9999px))
  Live(v, concrete.height + 2LIVE_GAP)
end

reread!(v::FileBlock, lines) = begin
  (lines == v.lines && v.state != :new) && return v
  v.lines = lines
  make!(v)
end

"True when Kip has the GitHub repository `repo` on this Mac, so that nothing has to come from GitHub"
here(repo::AbstractString) = isdir(joinpath(Kip.repos, repo))

"The module of the file or the repository `source`. A path like `./progress.jl` starts from the folder of the page."
source_module(e, source::AbstractString) = begin
  folder = isdir(docdir(e)) ? docdir(e) : pwd()
  # A Markdown page isn't Julia code, so Kip doesn't load it: the page's `julia` blocks make its module
  if ismarkdown(source)
    file = repository(source) === nothing ? source_file(e, source) : repository_file(source)
    isfile(file) || error("Ladder can't find the page $source.")
    return cd(() -> Base.invokelatest(page_run, e, realpath(file)), folder)
  end
  cd(() -> Base.invokelatest(Kip.require, source, folder), folder)
end

"True when `source` names a file or a folder that's on this Mac, as Kip looks for it: the path as it is, or with `.jl` after it"
source_found(e, source::AbstractString) = begin
  path = startswith(source, "~/") ? homedir() * source[2:end] : normpath(joinpath(docdir(e), source))
  ispath(path) || isfile(path * ".jl")
end

"The file on this Mac that `source` names, or \"\" when it names a folder, or a file that isn't there"
source_file(e, source::AbstractString) = begin
  path = startswith(source, "~/") ? homedir() * source[2:end] : normpath(joinpath(docdir(e), source))
  isfile(path) || (path *= ".jl")
  isfile(path) ? realpath(path) : ""
end

"When each file that defines a kind of block was last loaded: the time that the disk gave for it then"
const LOADED = Dict{String,Float64}()

"The files that define a kind of block and didn't load, with what went wrong"
const BROKEN = Dict{String,String}()

"""
Load the file of the block of `v` again if it was saved since it was loaded,
so that a kind of block changes as you write it. Each block that the file
defines is then made again from its lines.
"""
reload!(v::FileBlock) = begin
  isempty(v.file) && return v
  at = mtime(v.file)
  at == 0 && return v   # the file is gone, so the block stays as it is
  if at != get(LOADED, v.file, at)
    write_blocks!(editor(v))   # what the blocks hold goes into their lines first, since they're made again from those
    LOADED[v.file] = at
    delete!(BROKEN, v.file)
    m = get(Kip.modules, v.file, get(PAGE_MODULES, page_key(v.file), nothing))
    try
      # The file's new code goes into the module that it has. A file that didn't load the first time has none yet.
      m === nothing || (ismarkdown(v.file) ? Base.invokelatest(run_page!, m, v.file) : Base.include(m, v.file))
    catch err
      BROKEN[v.file] = trouble(err)
    end
  end
  v.read == get(LOADED, v.file, v.read) || (v.state = :new)
  v
end

"""
The lines of the block of `v` as what the block made writes them now. It's
nothing when the file has no function `written` for what was made.
"""
lines_now(v::FileBlock) = begin
  w = named(v.from, :written)
  (w === nothing || !Base.invokelatest(applicable, w, v.value)) && return nothing
  out = Base.invokelatest(w, v.value)
  String[String(l) for l in (out isa AbstractString ? split(out, '\n') : out)]
end

"""
The Shown that draws what the block of `v` made: its node, or its words when
it has no node. Words show as they are, and any other value as Julia prints it.
"""
shown(v::FileBlock) = begin
  node = Base.invokelatest(present, v.value)
  words = node !== nothing ? "" : v.value isa AbstractString ? v.value : Base.invokelatest(repr, "text/plain", v.value)
  s = own!(v, Shown(value=node === nothing ? note(words, colours.ink) : node))
  s.value isa SemanticUI && own!(s, s.value)
  s
end

"Note that the block of `v` can't show, and why"
fault!(v::FileBlock, why) = begin
  v.state, v.fault = :fault, String(why)
  push!(problems, v.fault)
  v
end

"""
Make what the block of `v` shows from its lines: load its file, and give the
lines to the function that has the language's name. A repository that you
haven't allowed isn't loaded: the block asks first. With `now`, a repository
that has to come from GitHub comes now. Without it, the block first says that
it's coming, because the window stops while it comes.
"""
make!(v::FileBlock; now=false) = begin
  e = editor(v)
  old = v.shown
  v.value = v.shown = v.said = nothing
  repo = repository(v.source)
  if v.from === nothing && repo !== nothing
    allowed(e, repo) || (v.state = :ask; return v)
    (now || here(repo)) || (v.state = :wait; return v)
  end
  v.from === nothing && repo === nothing && !source_found(e, v.source) &&
    return fault!(v, "Ladder can't find the file $(v.source). The line that opens this block names it.")
  repo === nothing && isempty(v.file) && (v.file = source_file(e, v.source))
  if !isempty(v.file)
    v.read = get!(() -> mtime(v.file), LOADED, v.file)
    haskey(BROKEN, v.file) && return fault!(v, BROKEN[v.file])
  end
  try
    v.from === nothing && (v.from = source_module(e, v.source))
    f = named(v.from, Symbol(v.lang))
    f === nothing && return fault!(v, "$(v.source) has no function called $(v.lang). A block in the language $(v.lang) shows what that function makes of the block's lines.")
    v.value = Base.invokelatest(f, copy(v.lines))
    v.shown = shown(v)
    # What a new value shows can carry on from what the last one showed, like a bar that slides to its new length
    old isa Shown && v.shown.value isa SemanticUI && typeof(old.value) === typeof(v.shown.value) && Base.invokelatest(carry!, v.shown.value, old.value)
    v.said = lines_now(v)
    v.state = :made
  catch err
    # A file that didn't load is tried again when it's saved
    v.from === nothing && !isempty(v.file) && (BROKEN[v.file] = trouble(err))
    fault!(v, trouble(err))
  end
  v
end

"""
Write the lines of what the block of `v` made into the block, if they aren't
the lines that it has. With `typing`, writes that come one soon after another
are one step for ⌘Z. Nothing is written when the block's lines in the page
aren't the ones that this was made from: then it's made again from those.
"""
write!(v::FileBlock; typing=false) = begin
  v.wants = false
  (v.state == :made && v.said !== nothing) || return v
  b = editor(v).buf
  span = block_lines(b, v.lang, v.n)
  (span !== nothing && b.lines[span[1]+1:span[2]-1] == v.lines) || return v
  now = try
    lines_now(v)
  catch err
    return fault!(v, trouble(err))
  end
  (now === nothing || now == v.said) && return v
  v.said = v.lines = now
  # A value that shows as words has new words now
  Base.invokelatest(present, v.value) === nothing && (v.shown = shown(v))
  write_block!(v, v.lang, now; typing)
end

"The views of the blocks of the page of `e` that a file defines"
file_blocks(e) = FileBlock[node for (key, node) in e.nodes if node isa FileBlock && key[3] == e.buf.path]

"""
Write the lines of every block of the page that a file defines. Whatever
reads the page's text calls this first: a save, a copy, a page of HTML,
another page that takes the window.
"""
write_blocks!(e) = (foreach(write!, file_blocks(e)); e)

# What was made asks for its lines to be written, with UI.jl's `changed!`
onchanged(v::FileBlock, ev::Changed) = begin
  ev.now ? write!(v) : (v.wants = true; redraw_in!(v, 0))
  handled
end

block_tick!(v::FileBlock) = begin
  v.state == :get && return make!(v, now=true)
  # A repository that another block of the page asked about, and that you allowed there
  v.state == :ask && repository(v.source) in ALLOWED && return make!(v)
  reload!(v)
  v.state == :made || return v
  # The page shows the block's lines while the caret is in them, so they're written as the caret goes in
  b = editor(v).buf
  span = block_lines(b, v.lang, v.n)
  inside = span !== nothing && incode(b, span[1])
  inside && !v.inside && write!(v)
  v.inside = inside
  # A write that was asked for waits until the mouse lets go, so that ⌘Z takes back a whole drag
  v.wants && !held(v, Keys.mouse_left) && write!(v, typing=true)
  v
end

act!(v::FileBlock, action, w) = begin
  allow!(editor(v), repository(v.source))
  v.state = :wait
  make!(v)
  handled
end

describe(v::FileBlock) = begin
  v.state == :made && return Column(width(grow=grow), Alignment.Start, v.shown)
  repo = something(repository(v.source), v.source)
  if v.state == :ask
    return Column(block_look()...,
      Row(width(grow=grow), padding(12px, 16px), child_gap=12px, Alignment.Center,
        Box(width(grow=grow), Alignment.Start,
          Text("This block runs code from github.com/$repo. Run it only if you trust who wrote it.", size=13px, family=SANS, color=colours.dim, wrap=WrapMode.words)),
        block_button!(v, :allow, :allow, words="Run the code", bold=true)))
  end
  if v.state in (:wait, :get)
    # The words are drawn in one frame, and the repository comes in the next
    v.state = :get
    redraw_in!(v, 0)
    return Column(block_look()..., block_note("Getting github.com/$repo…"))
  end
  note(v.fault, colours.accent)
end

# --- the top of an email -----------------------------------------------------------
#
# email_head.jl has the top of an email, which shows its subject, who sent it
# and when, and who it's to, and every field of its header a level down. It
# also says when the top of a page has the ladder in the top bar.

# --- the page's lines, laid out ----------------------------------------------------
#
# How far under the top bar the page starts, how wide its text is, and where
# its left edge is. `layout!` makes an item for each line and block of the
# page, and `reveal!` scrolls the page so that the caret shows.

"True when the page shows a CSV file as a table"
sheet_page(b::Buffer) = b.view == :file && lowercase(splitext(b.path)[2]) in TABLES

"How far under the top bar the page starts. A CSV file's table and a JSON file's tree start nearer than the text of a page does, and a kind of folder can say how near its own page starts."
page_top(e) = begin
  own = page_top(e, page_object(e))
  own !== nothing ? own : sheet_page(e.buf) || (e.buf.view == :file && json_page(e.buf)) ? SHEET_ABOVE : PAGE_TOP
end

"""
How far under the top bar the page of `o` starts, for a file or a folder that's
shown its own way, or nothing for the room that a page of text has. What the
page shows is `LIVE_GAP` further down. A kind of folder has a method of this,
and of `page_margin`, for a page like a table, which wants less room round it.
"""
page_top(e, o) = nothing

"How much room the page of `o` has at each side, for a file or a folder that's shown its own way, or nothing for the room that a page of text has"
page_margin(e, o) = nothing

"How much room the page has at each side: the least beside a page's text, or what the kind of the file or folder that shows says"
page_x(e) = something(page_margin(e, page_object(e)), PAGE_X)

"How wide the page's text is in the window"
text_width(e) = begin
  w, _ = window_size(e)
  # While the sidebar slides, the text keeps the width it has beside the
  # sidebar, so it doesn't wrap again on each frame
  # The numbers of a file's lines have room on the left of the text
  # The lines of a block that fill the window have no sidebar beside them
  alone = lowered(e) !== nothing
  # A side menu's compact form keeps its width beside the text while the sidebar is closed
  beside = alone ? 0px : e.panel || sliding(e) ? panel_w(e) : side_least(e)
  # In agent mode, the text is on the page's card, which keeps its width while a pane slides
  room = (agent_shows(e) ? page_card_wide(e) : w - beside) - 2page_x(e) - gutter(e)
  # A file of code or of text takes all the room that the window has, and so do a CSV file's table and
  # the lines of a block that fill the window. A page is no wider than the settings say. A page of a blog is
  # as wide as its site's text, for as many words to a line. A page with comments leaves room for them at its right.
  numbered(e.buf) || alone || json_page(e.buf) || bytes_page(e.buf) || sheet_page(e.buf) || own_page(e) ? max(room, 240px) :
    clamp(room - comment_room(e), 240px, e.look == :site ? SITE_MEASURE * TEXT_SIZE * e.zoom :
                                         e.look == :news ? NEWS_MEASURE * TEXT_SIZE * e.zoom : e.widest * e.zoom)
end

"""
How far the left edge of the page's text is from the left edge of the window.
A page's text is in the middle of the space beside the file panel. A file with
numbered lines starts at the left of that space, after its numbers, unless it's
scrolled to the right.
"""
text_left(e) = begin
  side, space = page_span(e)
  # The lines of a file's bytes start at the left too, and scroll to the right as numbered lines do
  numbered(e.buf) || bytes_page(e.buf) ? side + PAGE_X + gutter(e) - sideways(e) : side + text_inset(e, space)
end

"""
How far the left edge of a page's text is from the left edge of `space`, the
room beside the file panel. The text is in the middle of it. When the page's
comments at its right don't fit in the margin there, the text and the comments
are in the middle together, so the text is to the left of the middle.
"""
text_inset(e, space) = begin
  extra = comment_room(e)
  extra == 0px && return max(page_x(e), (space - e.width) / 2)
  before = comment_balance(e, space)
  max(page_x(e), (space - e.width - extra - before) / 2) + before
end

# A page of Markdown is laid out again in each frame, since what a block shows
# can change with no change to the text. A line of plain text is different: it
# only changes when its text does. So each such line is kept by its number,
# with what it was laid out from, and the next frame takes it as it is when
# the line still has that text and is still the same kind of line. A long
# page then costs little more in a frame than a short one. The lines are kept
# with the other layouts, in `e.flows`, so what empties those empties them too.

"The kinds of line that are laid out from their own text alone. A to-do item is left out: on a day before today its box shows that day's tick."
const PLAIN_KINDS = (Kind.blank, Kind.paragraph, Kind.heading, Kind.bullet, Kind.ordered, Kind.blockquote, Kind.code, Kind.rule)

"Keep line `i` as it was laid out in this frame, for the next frame, when its layout came from its text alone"
keep_plain!(kept::Vector{Union{Nothing,PlainLine}}, b::Buffer, i::Int, line::Line, flow::Flow, tall::px) = begin
  text = b.lines[i]
  # A picture, what inline code made, and a footnote's number each come from more than the line's text
  # ... and a line with a comment can take no room, which isn't a layout of its own
  # ... and a line that shows the markup of one of its runs goes with where the caret is in it
  plain = line.kind in PLAIN_KINDS && !occursin("![", text) && !occursin(INLINE, text) && !occursin("[^", text) && !occursin("%%", text) &&
          raw_part(b, i) === nothing
  kept[i] = plain ? PlainLine(text, line, flow.raw, flow, tall) : nothing
end

"Work out what the page shows and how tall each part is, for text that's `width` wide"
layout!(e, width=text_width(e)) = begin
  b = e.buf
  unlist!(node!(Document, e, :document))   # the document's children are the parts that this layout gives it
  # The page is written as rich text or as plain text, as the switch in the top bar says. After a
  # change, the caret's place is looked at afresh.
  shows = e.plain && b.view == :markdown
  b.plain == shows || (b.plain = shows; b.stood = nothing)
  stand!(b)
  ks = kinds(b)
  width == e.width || (e.width = width; empty!(e.flows))
  columns = page_columns!(e)   # the blocks that show side by side after a `columns` block, or nothing when the page has none
  # A file that's only shown is one viewer, or lines of text that are laid out once and kept
  b.view == :file && return e.layout = [file_item(e, b)]
  # The text of a CSV file is lines of text too, which a key can change
  (readonly(b) || b.view == :text) && return e.layout = file_lines(e, b)
  # A file of code is lines of text too, which a key can change
  b.view == :code && columns === nothing && lowered(e) === nothing && return e.layout = slide_items(e, file_lines(e, b))
  items = Item[]
  # These three have their types written out. What a block or a table gives has no type that Julia knows before it
  # runs, and without these the loop below would look up the type of each of them for every line of the page.
  top::px = 0px
  i::Int = 1
  n::Int = length(b.lines)
  # The lines of a block that went down a level from the window it filled show by themselves, and so do
  # the lines of a part of this page that another page shows
  span = hosted(e) === nothing ? lowered(e) : e.nodes[:span]
  span === nothing || ((i, n) = span)
  # The email as it was sent, with the lines that it stands for, or nothing when the page shows its lines
  sent = span === nothing ? sent_email(e) : nothing
  sent === nothing || (lines = sent_lines(e); sent = lines === nothing ? nothing : (sent, lines))
  parts = 0   # how many lines that show a part of another page
  seen = Dict{String,Int}()   # and how many blocks in each of the languages of `BLOCKS`
  # The lines of plain text as the frame before laid them out: see `PlainLine`. A page in columns, an email as it
  # was sent, and a page of emails have lines that are laid out another way.
  kept = columns === nothing && sent === nothing && !Eml.isemail(b.path) ?
    get!(() -> Union{Nothing,PlainLine}[], e.flows, (:plain, b.path))::Vector{Union{Nothing,PlainLine}} : nothing
  # A page that has more lines than it had has nothing kept for the new ones
  kept === nothing || length(kept) == length(b.lines) || (had = length(kept); resize!(kept, length(b.lines)); fill!(view(kept, had+1:length(kept)), nothing))
  # The last line, while it leaves room at its end for a button, is laid out afresh and not kept: see `end_room`
  room_at_end = end_room(e) > 0px
  while i <= n
    # In a column, the page's text is as wide as the column, and each column starts level with the first
    columns === nothing || (top = column_turn!(columns, e, items, i, top))
    if kept !== nothing && !(room_at_end && i == length(b.lines))
      was = kept[i]
      if was !== nothing && pointer(was.text) == pointer(b.lines[i]) && was.line === ks[i] && was.raw == israw(b, i) && raw_part(b, i) === nothing &&
         html_runs(b)[i][1] == 0
        push!(items, Item(i, i, top, was.tall, was.flow))
        top += was.tall
        i += 1
        continue
      end
    end
    j = i
    if ks[i].kind == Kind.table
      while j < n && ks[j+1].kind == Kind.table
        j += 1
      end
    end
    # Front matter shows as a card, unless the caret is in it
    if i == 1 && ks[1].kind == Kind.fence && ks[1].lang in (MATTER, TOML_MATTER) && !incode(b, 1)
      t = front_matter(b.lines)
      if t > 1
        content = matter_card(e, t)
        if content === nothing
          push!(items, flat(e, Item(1, t, top, 0px, nothing)))
        else
          push!(items, Item(1, t, top, content.tall, content))
          top += content.tall
        end
        i = t + 1
        continue
      end
    end
    # A comment on lines of its own takes no room, unless the caret is in it. Nor do the empty lines after it that
    # `comment_fold` counts, unless the caret is on one of them, which then shows.
    if ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang == COMMENT && !incode(b, i)
      t = codeblock(b, i)[2]
      fold = comment_fold(b, i)[2]
      (caretless(b) || !(t < b.caret[1] <= fold || t < b.anchor[1] <= fold)) && (t = fold)
      push!(items, flat(e, Item(i, t, top, 0px, nothing)))
      i = t + 1
      continue
    end
    # An email shows as it was sent, in place of the lines that were made of it, once its pictures are there
    if sent !== nothing && i == sent[2][1]
      content = sent_item(e, sent[1])
      push!(items, Item(i, sent[2][2], top, content.tall, content))
      top += content.tall
      i = sent[2][2] + 1
      continue
    end
    # A block in one of the languages of `BLOCKS` shows as its component, grid or view
    if ks[i].kind == Kind.fence && ks[i].level == 0 && haskey(BLOCKS, ks[i].lang)
      lang = ks[i].lang
      seen[lang] = get(seen, lang, 0) + 1   # each one keeps its view by its place among the page's blocks in its language
      laid = block_layout(BLOCKS[lang], e, lang, i, seen[lang])
      if laid !== nothing
        t, content = laid
        push!(items, Item(i, t, top, tall(content), content))
        top += tall(content)
        i = t + 1
        continue
      end
    end
    # A block in a language that a file defines shows what the file's function makes of it, unless the caret is in it
    if ks[i].kind == Kind.fence && ks[i].level == 0 && !isempty(ks[i].lang) && !known_lang(ks[i].lang)
      lang = ks[i].lang
      seen[lang] = get(seen, lang, 0) + 1   # every block in the language counts, as `block_lines` counts them
      source = block_source(b, i)
      t = codeblock(b, i)[2]
      if source !== nothing && !incode(b, i) && t > i && ks[t].kind == Kind.fence && ks[t].level == 1
        content = file_block_item(e, lang, source, i, t, seen[lang])
        push!(items, Item(i, t, top, content.tall, content))
        top += content.tall
        i = t + 1
        continue
      end
    end
    # A formula between two lines of $$, or in a `math` code block, shows as it's set, unless the caret is in it
    if ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang == MATH && !incode(b, i)
      t = codeblock(b, i)[2]
      content = t > i && ks[t].kind == Kind.fence && ks[t].level == 1 ? equation_item(e, join(b.lines[i+1:t-1], "\n")) : nothing
      if content !== nothing
        push!(items, Item(i, t, top, content.tall, content))
        top += content.tall
        i = t + 1
        continue
      end
    end
    # A line that holds only a formula between $$ and $$ shows the formula, unless the caret is in the line
    if ks[i].kind == Kind.paragraph && !israw(b, i) && maths_line(b, i)
      content = equation_item(e, maths_text(b.lines[i]))
      if content !== nothing
        push!(items, Item(i, i, top, content.tall, content))
        top += content.tall
        i += 1
        continue
      end
    end
    # The links at the end of an email to the files that came with it show as file icons, at both of its levels
    if ks[i].kind == Kind.paragraph && !israw(b, i) && Eml.isemail(b.path)
      content = attached_item(e, i)
      if content !== nothing
        push!(items, Item(i, content.node.to, top, content.tall, content))
        top += content.tall
        i = content.node.to + 1
        continue
      end
    end
    # A line that holds only a link like ![[Ideas#Plans]] shows that part of the other page, unless the caret is in the line
    if ks[i].kind == Kind.paragraph && !israw(b, i) && transcludes(b, i)
      parts += 1   # each one keeps its view by its place among the page's lines like it
      content = transclusion_item(e, i, parts)
      push!(items, Item(i, i, top, content.tall, content))
      top += content.tall
      i += 1
      continue
    end
    # A line that holds only a comment takes no room either, unless the caret is on it
    if ks[i].kind == Kind.paragraph && !alone(b, i) && comment_only(b.lines[i])
      t = something(comment_fold(b, i), (i, i))[2]
      (caretless(b) || !(i < b.caret[1] <= t || i < b.anchor[1] <= t)) || (t = i)
      push!(items, flat(e, Item(i, t, top, 0px, nothing)))
      i = t + 1
      continue
    end
    # Lines of HTML show as a browser draws them, unless the caret is in them: see "HTML in a page"
    if ks[i].kind == Kind.paragraph && (tags = html_block(b, i)) !== nothing && tags[1] == i && !html_typed(b, tags...)
      content = html_item(e, tags...)
      if content !== nothing
        push!(items, Item(i, tags[2], top, content.tall, content))
        top += content.tall
        i = tags[2] + 1
        continue
      end
    end
    # A line that holds only a picture shows the picture, unless the caret is on the line
    if ks[i].kind == Kind.paragraph && !israw(b, i) && occursin("![", b.lines[i])
      content = picture_item(e, i)
      if content !== nothing
        push!(items, Item(i, i, top, content.tall, content))
        top += content.tall
        i += 1
        continue
      end
    end
    # A kind of folder can show a table its own way, unless the caret is in the table: see `table_view`. A page
    # that you can't change has a caret on its first line, which doesn't count.
    if j > i && isdivider(b.lines[i+1]) && (caretless(b) || !(i <= b.caret[1] <= j))
      content = table_item(e, i, j)
      if content !== nothing
        push!(items, Item(i, j, top, content.tall, content))
        top += content.tall
        i = j + 1
        continue
      end
    end
    # A table needs its line of dashes. It shows as plain lines while the caret is on that line.
    if j > i && isdivider(b.lines[i+1]) && !israw(b, i + 1)
      content = grid(e, i, j)
      push!(items, Item(i, j, top, tall(content), content))
      top += tall(content)
      i = j + 1
    else
      content = flow(e, i)::Flow
      high = tall(content)
      push!(items, Item(i, i, top, high, content))
      kept === nothing || (room_at_end && i == length(b.lines)) || keep_plain!(kept, b, i, ks[i], content, high)
      top += high
      i += 1
    end
  end
  columns === nothing || column_turn!(columns, e, items, n + 1, top)   # the page ends in a column
  e.layout = slide_items(e, items)   # while the page shows as slides, only the items of one slide
end

"Scroll so the caret is on screen"
reveal!(e) = begin
  e.buf.view == :file && return   # a viewer has no caret
  it = item(e, e.buf.caret[1])
  top, bottom = it.top, it.top + it.tall
  if it.content isa Flow
    k, x = spot(it.content, e.buf.caret[2])
    top = it.top + line_top(it.content, k)
    bottom = top + it.content.lines[k].high
    # A long line that doesn't wrap scrolls sideways to show the caret, with a little of the line on each side of it
    if !wraps(e)
      b = e.buf
      x < b.across + SIDE_ROOM && (b.across = x - SIDE_ROOM)
      x > b.across + e.width - SIDE_ROOM && (b.across = x - e.width + SIDE_ROOM)
      scroll_sideways!(e, 0px)
    end
  elseif it.content isa Sheet
    r = clamp(e.buf.caret[1] - it.first, 1, length(it.content.rows))
    top = it.top + row_top(it.content, r)
    bottom = top + it.content.heights[r]
  end
  scroll_into_view!(e.scroll, PAGE_TOP + top - 30px, PAGE_TOP + bottom + 40px)
end

# --- drawing the text -----------------------------------------------------------------

"The box of a to-do item: empty, or filled and ticked when the item is done"
todo_box(seg::Seg) = begin
  side = px(round(num(seg.face.size) * 0.82))
  box = seg.text == TODO_DONE ?
    Box(fixed(side), height(side), radius(side * 0.22), Alignment.Center, justify=Alignment.Center, background(colours.accent),
        Icon("check", size=side * 0.9, color=colours.bg)) :
    Box(fixed(side), height(side), radius(side * 0.22), border(1.5px, :solid, colours.marker))
  Box(fixed(seg.w), Alignment.Start, box)
end

describe(seg::Seg) = begin
  # What inline code made is drawn in place of the code
  seg.node === nothing || return Box(fixed(seg.w), Alignment.Start, geometry(seg.node.node))
  isbox(seg) && return todo_box(seg)
  f = seg.face
  # A character that the font lacks, like the raised minus of yr⁻¹ in Charter, is in a font that has it
  t = hasall(f, seg.text) ? Text(seg.text, size=f.size, family=f.family, subfamily=f.style, color=f.color, wrap=WrapMode.none) :
                            Row(Alignment.Start, spared(seg.text, f)...)
  # The number of a footnote is at the top of a box as tall as the text beside it, so it sits high in the line
  seg.atomic && startswith(seg.link, '^') && !endswith(seg.text, ' ') && return Box(fixed(seg.w), height(f.size * 1.9), Alignment.Start, t)
  # ==Words== have a highlighter's colour behind them
  f.highlit && !f.chip && return Box(fixed(seg.w), Alignment.Start, radius(2px), background(highlighter()), t)
  # A Text on its own would take a share of the spare room in its row
  f.chip || return Box(fixed(seg.w), Alignment.Start, t)
  isempty(f.lang) || (t = Row(Alignment.Start, [part for tok in tokens(seg.text, f.lang) for part in coloured(tok, f)]...))
  Box(fixed(seg.w), height(f.size * 1.5), padding(CHIP_X, 0px), radius(4px), background(colours.chip), border(1px, :solid, colours.chip_line), t)
end

"""
One part of a line of code in a chip, in the colour of its kind, as the parts
of a row. Each is as wide as its text measures, so the caret lines up with it.
"""
coloured(tok, f::Face) =
  spared(tok.text, Face(f, color=tok.kind == :plain ? f.color : getfield(colours, tok.kind), style=tok.kind == :comment ? codeslant() : f.style))

"The lines of a Flow, as rows of text. `edge` is the width of a border on its left."
rows(f::Flow, edge=0px) =
  [Row(width(grow=grow), height(vl.high), padding(0px, 0px, 0px, vl.x - edge), clip=true, map(describe, vl.segs)...) for vl in f.lines]

describe(e::Editor, it::Item) = gone_under(e, it, describe(e, it, it.content))

describe(e::Editor, it::Item, f::Flow) = begin
  f = in_colour(e, it, f)   # a line of a file gets the colours of its code here
  k = f.kind
  if k == Kind.rule && !f.raw
    return Box(width(grow=grow), height(tall(f)), Box(width(grow=grow), height(1px), background(colours.line)))
  end
  edge = k == Kind.blockquote ? 3px : 0px
  col = Column(width(grow=grow), Alignment.Start, padding(f.above, 0px, f.below, 0px), rows(f, edge)...)
  if (k == Kind.code || k == Kind.fence) && !(1 <= it.first <= length(e.buf.lines) && kinds(e.buf)[it.first].lang == COMMENT)
    col.background = background(colours.block)
  elseif k == Kind.blockquote
    # A callout has its kind's colour down its left, and a little of that colour behind it
    kind = 1 <= it.first <= length(e.buf.lines) ? callout(kinds(e.buf)[it.first]) : ""
    col.border = border(edge, :solid, isempty(kind) ? colours.line : callout_colour(kind))[:left]
    isempty(kind) || (col.background = background(callout_tint(kind)))
  end
  col
end

describe(e::Editor, it::Item, g::Grid) = begin
  isspread(g) && return spreadsheet(e, it, g)
  line = border(1px, :solid, colours.line; between=true)
  # Its corners are round, as a chart's are
  table = Column(width(grow=grow), Alignment.Start, line, radius(BLOCK_ROUND), name="Table",
    [Row(width(grow=grow), height(g.heights[r]), Alignment.Start, line[:between], inner_round(r, length(g.rows)),
         background(r == 1 ? colours.head : iseven(r) ? colours.bg : colours.stripe),
       [Column(fixed(g.widths[c]), height(grow=grow), Alignment.Start, justify=Alignment.Center, rows(g.flows[r][c])...)
        for c in eachindex(g.widths)]...)
     for r in eachindex(g.rows)]...)
  Box(width(grow=grow), padding(0px, TABLE_GAP), table)
end

describe(e::Editor, it::Item, l::Live) = begin
  # In a part of this page that another page shows, a live block is only shown: a cover over it takes its clicks.
  # What an agent says is shown by the window's page too, but its blocks take the mouse as a page's do: a chart shows its
  # buttons while the mouse is on it.
  inner = hosted(e) === nothing || l.node isa Transclusion || is_reply(e.buf.path) ? geometry(l.node) :
    Stack(width(grow=grow), Alignment.Start, geometry(l.node), live_cover(e, it))
  Box(width(grow=grow), height(l.tall), Alignment.Start, padding(0px, LIVE_GAP), inner)
end

"The kind of block that an item is part of, or nothing for a blank line"
blocktype(it::Item) = begin
  c = it.content
  c isa Grid && return Table
  c isa Sheet && return SheetBlock
  c isa Live ? LiveBlock : blocktype(c.kind)
end

blocktype(k::Kind) =
  k == Kind.paragraph ? Paragraph : k == Kind.heading ? Heading : k in (Kind.bullet, Kind.ordered, Kind.todo) ? List :
  k == Kind.blockquote ? Quote : k in (Kind.code, Kind.fence) ? CodeBlock : k == Kind.table ? Table :
  k == Kind.rule ? Rule : nothing

"The kind of block that line `i` is in. The keys that edit the text do different things in different blocks."
block(b::Buffer, i::Int) = blocktype(kinds(b)[i].kind)

"The items as the nodes of the document: one for each paragraph, list, table and so on"
blocks(d::Document, items) = begin
  ks = kinds(editor(d).buf)
  out, group, T = Any[], Item[], nothing
  close() = begin
    isempty(group) && return
    T === nothing ? append!(out, group) : push!(out, own!(d, T(first=group[1].first, last=group[end].last, items=copy(group))))
    empty!(group)
  end
  for it in items
    U = blocktype(it)
    # A heading, a rule, a table and a live block each stand alone, and a ``` line that opens a block starts a new one
    alone = U in (Heading, Rule, LiveBlock, SheetBlock) || it.content isa Grid || (U === CodeBlock && ks[it.first].kind == Kind.fence && ks[it.first].level == 0)
    (U !== T || alone) && close()
    T = U
    push!(group, it)
  end
  close()
  out
end

describe(b::Block) = Column(width(grow=grow), Alignment.Start, [describe(editor(b), it) for it in b.items]...)

describe(d::Document) = begin
  e = editor(d)
  items = e.layout
  total = isempty(items) ? 0px : lowest(e, items)
  _, h = window_size(e)
  # Only the lines on screen, and a few either side, are built
  from, to = e.scroll.offset - PAGE_TOP - 200px, e.scroll.offset + h + 200px
  lo = something(findfirst(it -> it.top + it.tall >= from, items), length(items))
  hi = something(findlast(it -> it.top <= to, items), lo)
  # A part of this page that another page shows is built whole. That page's own scroll says what's on screen.
  hosted(e) === nothing || ((lo, hi) = (1, length(items)))
  lo, hi = whole_groups(e, items, lo, hi)   # a group of columns is built whole
  e.shown = lo:hi
  # Each row of text cuts off what's past its end, so long lines that don't wrap need a page as wide as the longest
  Column(fixed(wraps(e) ? e.width : max(e.width, e.reach + SIDE_ROOM)), Alignment.Start, name="Document",
    gone_over(e, items, lo)...,
    page_parts(d, e, items[lo:hi])...,
    spacer(total - lowest(e, view(items, lo:hi))))
end

# With ⌘ and no other key held, a click on a link opens it, so the mouse shows a hand there. In a page
# that's never changed, a click on a link opens it with no key held.
cursor(d::Document) = begin
  e = editor(d)
  e.buf.view == :file && return :arrow   # a viewer has no text to select
  slideshow(e) === nothing || return slide_cursor(e)   # nor has a slide
  w = window_of(e)
  w === nothing && return :ibeam
  # A click on a to-do item's box ticks it
  todo_at(e, w.mouse) === nothing || return :hand
  # A drag on what a number comes to changes the number
  (haskey(e.nodes, :scrub) || scrub_at(e, w.mouse) !== nothing) && return :resize_x
  # A click on the value of a name goes to where the page gives the name its value
  unmodified(w) && giver_at(e, w.mouse) !== nothing && return :hand
  # With ⌘ held, a click on a name of Julia code goes to where the name is defined. Julia compiles definition only when ⌘ is first held.
  # ⌘ with another key held, like ⇧ or ⌃, does neither, so the mouse isn't a hand.
  cmd = only_held(w, Keys.cmd)
  cmd && link_at(e, w.mouse) === nothing && Base.invokelatest(definition, e, locate(e, w.mouse)) !== nothing && return :hand
  (cmd && link_at(e, w.mouse) !== nothing) || (follows_links(e.buf) && unmodified(w) && link_on(e, w.mouse) !== nothing) ? :hand : :ibeam
end

"""
The room under the last line of the page. A code file scrolls on until its last
lines are at the top of the window, so a box that opens under them has room to
show. A kind of folder whose own page has no text to type at its end can have
less: see `page_bottom(e, o)`.
"""
page_bottom(e) = numbered(e.buf) ? max(PAGE_BOTTOM, e.scroll.viewport - CODE_END) : something(page_bottom(e, page_object(e)), PAGE_BOTTOM)

"The room under the page that `page_view` gives for `o`, or nothing for a page's own room"
page_bottom(e, o) = nothing

describe(p::Page) = begin
  e = editor(p)
  nofile(e) && return nofile_view(e)
  # A kind of folder or of file can cover the page's whole space, as a desktop does with its wallpaper
  cover = page_cover(e)
  cover === nothing || return cover
  # An HTML file at its highest level covers it with the page that its HTML makes, as a browser's window would show it
  html_shown(e) && return Box(width(grow=grow), height(grow=grow), Alignment.Start, html_part(e))
  # A terminal's file covers it with the terminal
  term_shown(e) && return Box(width(grow=grow), height(grow=grow), Alignment.Start, term_part(e))
  # A session's file covers it with what you and the agent said
  chat_shown(e) && return Box(width(grow=grow), height(grow=grow), Alignment.Start, chat_part(e))
  # A model's file covers it with the model, which is a component, so it gets a live block's colours and text size
  model = model_part(e)
  model === nothing || return with_theme(() -> Box(width(grow=grow), height(grow=grow), Alignment.Start, model), component_theme(e.zoom))
  # A picture and a PDF file fit it, and can be made bigger and moved
  shown = file_zoom(e)
  shown === nothing || return Box(width(grow=grow), height(grow=grow), Alignment.Start, shown)
  # A video has all of it, with black round its picture and its controls over the foot of the picture, as when it fills a
  # screen. While it does fill the screen, it's there and not here.
  video = video_part(e)
  if video !== nothing
    zoomed_node(e, video) && return Box(width(grow=grow), height(grow=grow), background(RGBA(0, 0, 0, 1)))
    video.screen, video.height = true, page_room(e)[2]
    return with_theme(() -> Box(width(grow=grow), height(grow=grow), Alignment.Start, background(RGBA(0, 0, 0, 1)), video), component_theme(e.zoom))
  end
  # Long lines that don't wrap go on to the right edge of the window. The text moves left as the page
  # scrolls sideways. None of it shows past the edges of the page, and the numbers of the lines go over it.
  # A kind of folder can show something under the text of each page that it holds
  foot = page_foot(e)
  page = wraps(e) ?
    Row(width(grow=grow), Alignment.Start, justify=numbered(e.buf) ? Alignment.Start : Alignment.Center,
        padding(page_top(e), page_x(e), page_bottom(e), page_x(e) + gutter(e)),
      with_comments(e, foot === nothing ? node!(Document, e, :document) : Column(Alignment.Start, node!(Document, e, :document), foot))) :
    Row(width(grow=grow), Alignment.Start, padding(page_top(e), 0px, page_bottom(e), PAGE_X + gutter(e)), clip_x=true,
      Box(Alignment.Start, offset_x=-sideways(e), node!(Document, e, :document)))
  reuse!(e.scroll, guide_under(e, page))
end

"What the page shows in a window with no file: the keys that open a file and that close the window, or the tab while a tab is open"
nofile_view(e) = begin
  open_keys, close_keys = strip(hint(e, :open)), strip(hint(e, :close))
  Box(width(grow=grow), height(grow=grow),
    Column(child_gap=8px,
      Box(label("No file is open", 15px, color=colours.dim)),
      (isempty(open_keys) ? () : (Box(label("$open_keys finds a file", 13px, color=colours.faint)),))...,
      (isempty(close_keys) ? () : (Box(label("$close_keys closes the $(new_tab(e) || !isempty(tabs(e)) ? "tab" : "window")", 13px, color=colours.faint)),))...))
end

"""
Put a faint line down a file of code, under the text of `page`, after the
number of characters that the settings page chooses. It moves with the text
when the page scrolls sideways.
"""
guide_under(e, page) = begin
  (e.guide > 0 && numbered(e.buf)) || return page
  x = PAGE_X + gutter(e) + measure(face(e, Line(Kind.code, 0, 0, "")), "0") * e.guide - sideways(e)
  Stack(width(grow=grow), Alignment.Start,
    Box(fixed(1px), height(grow=grow), background(colours.line), offset_x=x),
    page)
end

"The part of line `i` that's selected, as columns, and whether the selection goes on past it"
selected(b::Buffer, i::Int) = begin
  lo, hi = selection(b)
  (lo[1] <= i <= hi[1] && lo != hi) || return nothing
  (i == lo[1] ? lo[2] : 0, i == hi[1] ? hi[2] : length(b.lines[i]), i < hi[1])
end

"""
The boxes that cover the selected part of each line of `f`, whose top left
corner is at (x, y). The first and last boxes take in the space above and below
the lines, so the boxes of one line of the document meet those of the next.
With `margin`, a box that starts at the start of its line also takes in the
space to the left of the text, like the inset of a code block. That's for a
line that the selection came into from the line above: it keeps the left edge
of the selection straight from one kind of line to the next. The line that the
selection starts in has no `margin`, so its box starts where its text does. A
selection that's all in one code block has no `margin` on any line. See `within_code`.
"""
marks(f::Flow, x, y, (from, to, more); margin=true, edge=0px) = begin
  out = Rect[]
  n = length(f.lines)
  for (k, vl) in enumerate(f.lines)
    (from <= vl.to && to >= vl.from) || continue
    # `edge` is the left edge of the line's column of the page, where the space to the left of its text starts
    # A selection from the end of inline code starts after its last words, which can start the line
    starts = from > vl.from || (from == vl.from && !isempty(vl.segs) && later_word(first(vl.segs)))
    x1 = starts ? xcol(vl, from) : margin ? edge : vl.x
    x2 = xcol(vl, min(to, vl.to))
    # A little extra shows that the end of the line is selected too
    (to > vl.to || (more && k == n)) && (x2 += 7px)
    # A line with none of its text selected has no box, not even over its margin
    x2 > max(x1, vl.x) || continue
    top = k == 1 ? 0px : line_top(f, k)
    bottom = line_top(f, k) + vl.high + (k == n ? f.below : 0px)
    push!(out, (num(x + x1), num(y + top), num(x + x2), num(y + bottom)))
  end
  out
end

const SELECTION_RADIUS = 4.0

"""
Fill the selection. Boxes that sit on top of each other are joined into one
shape, and every corner of that shape is rounded, the ones that point in as
well as the ones that point out.
"""
fill_selection(ctx, rects::Vector{Rect}) = begin
  isempty(rects) && return
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  Skia.sk_paint_set_color(paint, sk_color(colours.select))
  from = 1
  for i in 2:length(rects)+1
    # A box joins the one above it when they touch and share some width
    joined = i <= length(rects) && abs(rects[i][2] - rects[i-1][4]) < 1 &&
             rects[i][1] < rects[i-1][3] && rects[i][3] > rects[i-1][1]
    joined && continue
    outline = rounded(corners(rects[from:i-1]), SELECTION_RADIUS)
    Skia.sk_canvas_draw_path(ctx, outline, paint)
    Skia.sk_path_delete(outline)
    from = i
  end
  Skia.sk_paint_delete(paint)
end

"The corners of the shape made by a stack of boxes: down its right side, then back up its left"
corners(rects) = begin
  points = NTuple{2,Float64}[]
  add(p) = (isempty(points) || points[end] != p) && push!(points, p)
  top = rects[1][2]
  for (l, t, r, b) in rects
    add((r, top)); add((r, b))
    top = b
  end
  for (i, (l, t, r, b)) in Iterators.reverse(enumerate(rects))
    add((l, b)); add((l, i == 1 ? t : rects[i-1][4]))
  end
  points
end

"A Skia path around `points`, with each corner rounded by up to `radius`"
rounded(points, radius) = begin
  path = Skia.sk_path_new()
  n = length(points)
  for i in 1:n
    before, corner, after = points[mod1(i - 1, n)], points[i], points[mod1(i + 1, n)]
    d1, d2 = hypot((before .- corner)...), hypot((after .- corner)...)
    # A short edge has room for less of a curve at each end
    r = min(radius, d1 / 2, d2 / 2)
    a = corner .+ (before .- corner) .* (r / max(d1, 1e-6))
    b = corner .+ (after .- corner) .* (r / max(d2, 1e-6))
    i == 1 ? Skia.sk_path_move_to(path, Float32(a[1]), Float32(a[2])) : Skia.sk_path_line_to(path, Float32(a[1]), Float32(a[2]))
    # A conic with this weight is a quarter of a circle
    Skia.sk_path_conic_to(path, Float32(corner[1]), Float32(corner[2]), Float32(b[1]), Float32(b[2]), Float32(sqrt(0.5)))
  end
  Skia.sk_path_close(path)
  path
end

# --- the caret's glide ------------------------------------------------------------------
#
# When you type, or press a key that takes the caret a step, the caret doesn't
# jump to its new place. It moves there in a short time, fast at first and then
# slower, and its height changes on the way. A caret that's sent somewhere else
# before it arrives goes on from where it is. A step is a character, a word or
# a line: what the arrow keys do, with ⌥ or without.
#
# Anything else that moves the caret puts it at its new place at once: a click,
# a drag, a key that goes to the end of the line or of the page, a link to a
# heading. So does a page that's laid out again, because the window changed
# its width, say, and a page that has just opened. The settings page turns the
# glide off.

const GLIDE_TIME = 0.07   # seconds the caret takes to get to a new place

"Where a caret is at the time `now`: its left, its top and its height"
glided(g::Glide, now) = begin
  t = clamp((now - g.left_at) / GLIDE_TIME, 0.0, 1.0)
  g.from .+ (g.to .- g.from) .* (1 - (1 - t)^3)   # fast at first, then slower
end

"True while a caret of the page is on its way to a new place"
gliding(e, now=time()) = any(g -> g.from != g.to && now - g.left_at < GLIDE_TIME, values(e.glides))

"""
Where to draw the caret numbered `slot` at the time `now`, when its place in
the text is at `to` on the page. A caret that a step or a change to the text
gave a new place sets off for it from where it's drawn now.
"""
glide_to!(e, slot, to, now=time()) = begin
  b = e.buf
  key = (b.caret, b.version)
  g = get(e.glides, slot, nothing)
  if g !== nothing && e.glide && g.buf == objectid(b)
    if g.key == key
      # The same place in the text, at the same place on the page: it goes on with its move
      maximum(abs, g.to .- to) < 0.01 && return glided(g, now)
    elseif e.by_step || g.key[2] != b.version
      g.from, g.to, g.left_at, g.key = glided(g, now), to, now, key
      return g.from
    end
  end
  e.glides[slot] = Glide(to, to, now, objectid(b), key)
  to
end

"Turn the caret's glide on or off"
glide!(e, on::Bool) = (e.glide = on; save_settings!(e); rerun!(e, :glide); e)

"Draw the caret at column `col` of `f`, whose top left corner is at (x, y)"
caret(ctx, e, f::Flow, x, y, col) = begin
  w = window_of(e)
  (w !== nothing && w.focus === e) || return
  k, cx = spot(f, col)
  high = f.size * 1.25
  left, top = e.origin
  at = glide_to!(e, e.gliding, (num(x + cx - left), num(y + line_top(f, k) + (f.lines[k].high - high)/2 - top), num(high)))
  g = e.glides[e.gliding]
  moving = g.from != g.to && time() - g.left_at < GLIDE_TIME
  # The window draws each frame as soon as it can until the caret arrives
  moving && (w.animating = true)
  # A caret that's moving doesn't blink
  since = time() - e.blink
  (moving || since < 0.5 || mod(since - 0.5, 1.0) >= 0.5) || return
  rectangle(ctx, left + px(at[1]) - 0.75px, top + px(at[2]), 1.5px, px(at[3]), background=colours.ink, border=0px)
end

# The caret and the selection are drawn over the text, once it has been placed
draw(ctx, size, ui::ConcreteRect, d::Document) = begin
  e = editor(d)
  b = e.buf
  e.origin = (ui.left, ui.top)
  tint_new(ctx, e, ui)
  fill_selection(ctx, selection_boxes(ctx, e, ui))
  with_others(() -> fill_selection(ctx, selection_boxes(ctx, e, ui)), b)
  outline_same_word(ctx, e, ui)
  mark_pointed(ctx, e, ui)
  underline_scrubs(ctx, e, ui)
  mark_clickable(ctx, e, ui)
  note_peek!(e)   # the card of a footnote whose number the mouse is on
  mark_checks(ctx, e, ui)
  mark_steps(ctx, e, ui)
  ring_part(ctx, e, ui)
  annotate(ctx, e, ui)
  mark_commented(ctx, e, ui)
  glow_bracket_pair(ctx, e, ui)
  # A file that's only shown has a selection and no caret. So has a page that's never changed.
  if !(caretless(b) || readonly(b))
    # Each caret has a number, so that it moves from its own last place. When there are more carets or fewer, the others start again.
    n = 1 + length(others(b))
    n == e.carets || (filter!(kv -> kv.first == 1, e.glides); e.carets = n)
    e.gliding = 1
    carets(ctx, e, ui)
    with_others(() -> (e.gliding += 1; carets(ctx, e, ui)), b)
    e.gliding = 1
  end
  e.by_step = false   # the step has been drawn. What moves the caret next may be a click.
  veil_later(ctx, e, ui)
  margin(ctx, e, ui)
end

"""
True when the selection is all in one code block, or in a file of code. The
space to the left of the code is the block's padding. There's no line outside
the block for the selection to line up with, so that space gets no colour.
"""
within_code(b::Buffer) = begin
  lo, hi = selection(b)
  kinds(b)[lo[1]].kind in (Kind.code, Kind.fence) && hi[1] <= codeblock(b, lo[1])[2]
end

"""
The boxes that cover the selection on the page, whose text is at `ui`. The
part of it that's in the cells of a table is filled here, a cell at a time.
"""
selection_boxes(ctx, e, ui) = begin
  b = e.buf
  # A line takes in the space left of its text only when the selection came into it from the line above
  margins = !within_code(b)
  # The selection goes under the caret, as one shape for each run of lines that touch
  rects = Rect[]
  for it in e.layout[e.shown]
    top = ui.top + it.top
    across, wide = item_room(e, it)   # an item in a column of the page starts at the column's left edge, and is as wide as the column
    left = ui.left + across
    if it.content isa Grid
      g = it.content
      if b.caret[1] != b.anchor[1]
        # A selection that covers several lines takes each row whole
        lo, hi = selection(b)
        y = top + TABLE_GAP
        lo[1] < it.first && hi[1] >= it.first && push!(rects, (num(left), num(top), num(left + 7px), num(y)))
        y += g.head   # a spreadsheet's row of letters isn't part of the text, so it's never selected
        for (r, i) in enumerate(g.rows)
          h = g.heights[r] + (r == length(g.rows) ? 2px : 1px)
          lo[1] <= i <= hi[1] && push!(rects, (num(left), num(y), num(left + wide), num(y + h)))
          y += h
        end
        lo[1] <= it.last && hi[1] > it.last && push!(rects, (num(left), num(y), num(left + 7px), num(y + TABLE_GAP)))
        continue
      end
      for (r, i) in enumerate(g.rows), (c, cell) in enumerate(g.cells[r])
        sel = selected(b, i)
        (sel !== nothing && sel[1] < cell.limit && sel[2] > cell.lo) || continue
        x, y = cell_origin(g, r, c)
        fill_selection(ctx, marks(g.flows[r][c], ui.left + x, top + y, (max(sel[1], cell.lo), min(sel[2], cell.limit), false), margin=false))
      end
    elseif it.content isa Sheet
      append!(rects, marks(e, it, it.content, left, top))
    elseif it.content isa Live
      # A live block is selected whole
      lo, hi = selection(b)
      selecting(b) && lo[1] <= it.first && hi[1] >= it.last &&
        push!(rects, (num(left), num(top), num(left + wide), num(top + it.tall)))
    else
      sel = selected(b, it.first)
      sel === nothing || append!(rects, marks(it.content, ui.left, top, sel, margin=margins && selection(b)[1][1] < it.first, edge=across))
    end
  end
  rects
end

"""
Draw the numbers of the lines, and the bars beside the lines that just changed,
in the room on the left of the text. The text of a page that's scrolled to the
right goes under that room, so the room is filled with the page's colour first.
"""
margin(ctx, e, ui) = begin
  across = sideways(e)
  left = ui.left + across   # where the text starts when it isn't scrolled
  room = PAGE_X + gutter(e)
  across > 0px && rectangle(ctx, left - room, ui.top, room, ui.height, background=colours.bg, border=0px)
  shade_line(ctx, e, left - room, ui.top)
  draw_numbers(ctx, e, left, ui.top)
  draw_fresh(ctx, e, left, ui.top)
  draw_diff_bars(ctx, e, left, ui.top)
end

const SHADE = 0.05   # how much of the colour of the text the shade of the caret's line has

"""
Shade the line that the caret is on, from `x` to the right edge of the window,
in a file of code whose settings ask for it. The shade is faint, so the text
shows through it. There's none while text is selected.
"""
shade_line(ctx, e, x, top) = begin
  b = e.buf
  (e.shade && numbered(b) && !caretless(b) && !readonly(b) && !selecting(b) && !isempty(e.layout)) || return
  it = item(e, b.caret[1])
  w, _ = window_size(e)
  rectangle(ctx, x, top + it.top, w - x, it.tall, background=RGBA(colours.ink, SHADE), border=0px)
end

"Draw the caret on the page, whose text is at `ui`"
carets(ctx, e, ui) = begin
  b = e.buf
  picked(b) === nothing || return   # a line round the part shows where the caret is
  for it in e.layout[e.shown]
    top = ui.top + it.top
    if it.content isa Grid
      g = it.content
      at = gridcell(g, b.caret)
      isspread(g) && at !== nothing && b.caret[1] == b.anchor[1] && ring(ctx, g, at, ui.left, top)
      for (r, i) in enumerate(g.rows), (c, cell) in enumerate(g.cells[r])
        x, y = cell_origin(g, r, c)
        at == (r, c) && caret(ctx, e, g.flows[r][c], ui.left + x, top + y, b.caret[2])
      end
      continue
    end
    it.content isa Sheet && caret(ctx, e, it.content, ui.left + item_room(e, it)[1], top)
    it.first == b.caret[1] && it.content isa Flow && caret(ctx, e, it.content, ui.left, top, b.caret[2])
  end
end

# --- the mouse on the page --------------------------------------------------------------

"The place in the document under a point in the window"
locate(e, (x, y)) = begin
  # On a page that's scrolled sideways, a point on the numbers of the lines is on the first part of the line that shows
  dx, dy = max(x - e.origin[1], sideways(e)), y - e.origin[2]
  items = e.layout
  isempty(items) && return e.buf.caret
  it = items[item_under(e, dx, dy)]
  # Until the next frame, the layout can be of the page that showed before, as when a click opened another
  # file and the mouse moved with its button still down. That page can have more lines than this one.
  it.last <= length(e.buf.lines) || return e.buf.caret
  if it.content isa Grid
    g = it.content
    # The row and the column under the point
    r = something(findfirst(r -> dy < it.top + cell_origin(g, r, 1)[2] + g.heights[r], eachindex(g.rows)), length(g.rows))
    c = something(findlast(c -> dx >= cell_origin(g, r, c)[1], eachindex(g.widths)), 1)
    cells = g.cells[r]
    isempty(cells) && return line_end(e.buf, g.rows[r])
    # A row can have fewer cells than the table has columns
    c = min(c, length(cells))
    f = g.flows[r][c]
    x, y = cell_origin(g, r, c)
    k = line_at(f, dy - it.top - y)
    return (g.rows[r], cellcol(f, k, dx - x, cells[c]))
  end
  it.content isa Sheet && return locate(e, it, it.content, dx - item_room(e, it)[1], dy - it.top)
  if it.content isa Live
    # A point on a live block counts as the end of the line above it or the start of the line below
    above = dy < it.top + it.tall/2 ? it.first > 1 : it.last == length(e.buf.lines)
    return above && it.first > 1 ? line_end(e.buf, it.first - 1) : it.last < length(e.buf.lines) ? (it.last + 1, 0) : (it.first, 0)
  end
  f = it.content::Flow
  # A line of the page before can be longer than this page's line of the same number
  (it.first, min(colat(f, line_at(f, dy - it.top), dx), length(e.buf.lines[it.first])))
end

"The link under a point in the window, or nothing. A link in a cell of a table counts too."
link_at(e, pos) = begin
  line, col = locate(e, pos)
  it = item(e, line)
  c = it.content
  # Each cell of a table has its own lines of text. Their columns are the columns of the row's line.
  r = c isa Grid ? findfirst(==(line), c.rows) : nothing
  flows = c isa Flow ? [c] : r === nothing ? Flow[] : c.flows[r]
  for f in flows, vl in f.lines, seg in vl.segs
    seg.col <= col < seg.col + seg.n && !isempty(seg.link) && return seg.link
  end
  nothing
end

"""
The link that's drawn under a point in the window, or nothing. `link_at` gives
the link nearest to a point, which is right for a click with ⌘ held. A point
beside a line, or between two lines, is on no link here, so a click with no
key held opens a link only when the click is on its words. A link in a cell
of a table counts too.
"""
link_on(e, (x, y)) = begin
  dx, dy = x - e.origin[1], y - e.origin[2]
  (dy >= 0px && !isempty(e.layout)) || return nothing
  it = e.layout[item_under(e, dx, dy)]
  c = it.content
  c isa Flow && return link_on(c, dx, dy - it.top)
  c isa Grid || return nothing
  # Each cell of a table has its own lines of text, from the top left of the cell
  for r in eachindex(c.rows), col in eachindex(c.flows[r])
    cx, cy = cell_origin(c, r, col)
    found = link_on(c.flows[r][col], dx - cx, dy - it.top - cy)
    found === nothing || return found
  end
  nothing
end

"The link that's drawn at `dx` across and `dy` down from the top left of `f`, or nothing"
link_on(f::Flow, dx::px, dy::px) = begin
  for vl in f.lines
    top = f.above + vl.top
    top <= dy < top + vl.high || continue
    for seg in vl.segs
      !isempty(seg.link) && seg.x <= dx < seg.x + seg.w && return seg.link
    end
  end
  nothing
end

isword(c::Char) = isletter(c) || isdigit(c) || c == '_' || c == '\''

"The columns of the word around column `col` of `line`"
word_at(line::String, col::Int) = begin
  chars = collect(line)
  lo = hi = clamp(col, 0, length(chars))
  while lo > 0 && isword(chars[lo]); lo -= 1 end
  while hi < length(chars) && isword(chars[hi+1]); hi += 1 end
  (lo, hi)
end

"The caret moved or the text changed, so show the caret"
touch!(e; keep_goal=false) = begin
  e.buf.reading = false
  e.blink = time()
  e.reveal = true
  keep_goal || (e.goal = nothing)
  confine!(e)
end

"The line of the to-do item whose box is under a point in the window, or nothing"
todo_at(e, (x, y)) = begin
  isempty(e.layout) && return nothing
  dx, dy = x - e.origin[1], y - e.origin[2]
  it = e.layout[item_under(e, dx, dy)]
  f = it.content
  shows_box(f) || return nothing
  # The box is on the item's first line
  it.top + f.above <= dy < it.top + f.above + first(f.lines).high || return nothing
  for seg in first(f.lines).segs
    isbox(seg) && return seg.x <= dx < seg.x + seg.w ? it.first : nothing
  end
  nothing
end

"What inline code made that's under a point in the window: its Inline, or nothing"
inline_at(e, (x, y)) = begin
  isempty(e.layout) && return nothing
  dx, dy = x - e.origin[1], y - e.origin[2]
  it = e.layout[item_under(e, dx, dy)]
  c = it.content
  if c isa Grid
    for r in eachindex(c.rows), col in eachindex(c.flows[r])
      cx, cy = cell_origin(c, r, col)
      found = inline_at(c.flows[r][col], dx - cx, dy - it.top - cy)
      found === nothing || return found
    end
    return nothing
  end
  c isa Flow ? inline_at(c, dx, dy - it.top) : nothing
end

inline_at(f::Flow, dx::px, dy::px) = begin
  (0px <= dy < tall(f)) || return nothing
  for seg in f.lines[line_at(f, dy)].segs
    seg.node !== nothing && seg.x <= dx < seg.x + seg.w && return seg.node
  end
  nothing
end

"""
Tick the box of the to-do item on line `i`, or take its tick away. The caret
stays where it is. A tick of an item that repeats, like one that ends with
"every week", adds the next one under it: see repeats.jl.
"""
tick!(e, i::Int) = begin
  # On another day than today, the box shows how the item stands then, which a click can't change
  ticked_then(e, i) === nothing || return e
  tick_item!(e.buf, i, !isdone(e.buf.lines[i]))
  stop_clock!(e, i)   # a tick stops the clock of a time log that runs on the item
  e
end

"""
Tick the to-do item on line `i` of `b` when `done`, or take its tick away, in
one edit, so one ⌘Z takes it back. The item that a tick of a repeating item
adds goes in the same edit. The caret and the other end of the selection stay
with their text.
"""
tick_item!(b::Buffer, i::Int, done::Bool) = begin
  new, z = Repeats.tick(b.lines, i, done; today=calendar_today())
  caret, anchor = b.caret, b.anchor
  edit!(b, (i, 0), line_end(b, z), join(new, "\n"))
  grow = length(new) - (z - i + 1)
  # A line after the item moves down or up with the line that went in or out. One that went takes it to the item's last line.
  keep((l, c)) = l > z ? (l + grow, c) : l < i + length(new) ? (l, min(c, length(b.lines[l]))) : line_end(b, i + length(new) - 1)
  b.caret, b.anchor = keep(caret), keep(anchor)
  b
end

press!(e, pos) = begin
  slideshow(e) === nothing || return slide_press!(e, pos)   # a click on a slide goes to the next one, or back
  # ⌥-click on a part of another page shows the link that names the part, as ⌥-click on any part shows its lines
  (hosted(e) !== nothing && only_held(e, Keys.opt)) && return press!(hosted(e), pos)
  empty!(e.glides)   # a click puts the caret at its new place at once, even a click that changes the text
  b = e.buf
  # A click on the number of a line asks git when the line last changed. The click puts the caret on the line too.
  # Julia compiles line_history! and definition! when they're first used, not with this function, so a first click doesn't wait for them.
  numbered = number_at(e, pos)
  numbered === nothing || Base.invokelatest(line_history!, e, numbered)
  box = only_held(e, Keys.opt) ? nothing : todo_at(e, pos)
  if box !== nothing
    # A click on a to-do item's box ticks it, and doesn't move the caret
    focus(e)
    e.popup = :none
    e.clicked = (time(), (box, 0), 0)
    return tick!(e, box)
  end
  # A press on what a number comes to takes hold of the number: a drag then changes it
  found = unmodified(e) ? scrub_at(e, pos) : nothing
  found === nothing || return scrub!(e, found, pos)
  # A click on the value of a name, like !`energy`, goes to where the page gives the name its value
  given = unmodified(e) ? giver_at(e, pos) : nothing
  given === nothing || return go_to_giver!(e, given)
  it = e.layout[item_under(e, pos[1] - e.origin[1], pos[2] - e.origin[2])]
  made = only_held(e, Keys.opt) ? nothing : inline_at(e, pos)
  # A click on a formula in a line of text puts the caret beside it, as a click on a word does
  if made !== nothing && !(made.node isa Equation)
    # What inline code made takes its own clicks, as a live block does. A click with ⌥ held shows the code.
    e.popup = :none
    e.clicked = (time(), (it.first, 0), 0)
    took(e) || focus(e)
    return
  end
  if it.content isa Live && !only_held(e, Keys.opt)
    # A live block takes its own clicks. A part of it that took the keyboard, like a text field, keeps it.
    e.popup = :none
    e.clicked = (time(), (it.first, 0), 0)
    took(e) || focus(e)
    pick_clicked!(e, it)
    return
  end
  focus(e)
  e.popup = :none
  # ⌘ with another key held, like ⇧ or ⌃, opens no link
  if only_held(e, Keys.cmd)
    url = link_at(e, pos)
    url === nothing || return follow!(e, url)
    # In Julia code, a click on a name goes to where the name is defined
    it.content isa Flow && Base.invokelatest(definition!, e, locate(e, pos)) === true && return
  elseif follows_links(b) && only_held(e, Keys(0))
    # A page that's never changed has no caret for a click to place, so a click with no key held on a link opens it.
    # So does one in a page from a web server, as in a browser. A click anywhere else puts the caret there.
    url = link_on(e, pos)
    url === nothing || return follow!(e, url)
  end
  if it.content isa Live
    # A click with ⌥ held shows the block's code. A part of one line, like a picture, shows its line, with the caret at the end.
    e.clicked = (time(), (it.first, 0), 0)
    b.caret = b.anchor = it.last > it.first ? (it.first + 1, 0) : line_end(b, it.first)
    return touch!(e)
  end
  it.content isa Sheet && press!(e, it, it.content, pos) && return touch!(e)
  if it.content isa Grid && isspread(it.content) && only_held(e, Keys.opt)
    # A click on a spreadsheet with ⌥ held shows it as lines of code
    b.caret = b.anchor = line_end(b, it.first)
    return touch!(e)
  end
  at = settle(b, locate(e, pos))
  t, before, count = e.clicked
  count = time() - t < 0.4 && before == at ? count % 3 + 1 : 1
  e.clicked = (time(), at, count)
  if count == 2
    lo, hi = word_at(b.lines[at[1]], at[2])
    b.anchor, b.caret = (at[1], lo), (at[1], hi)
  elseif count == 3
    # Three clicks select the line, or in a table the cell
    cell = cellat(b, at)
    lo, hi = cell === nothing ? (0, length(b.lines[at[1]])) : (cell.lo, cell.hi)
    b.anchor, b.caret = (at[1], lo), (at[1], hi)
  else
    b.caret = at
    only_held(e, Keys.shft) || (b.anchor = at)
  end
  touch!(e)
end

"""
After a click on the live block that `it` shows, put the caret on the block as a
whole, as ↑ and ↓ do, so that it has the line round it. A click that a part of
the block takes for itself, like a click on a button, never comes here. A click
that a part uses and lets go on to the page, like a stroke of a pen or a click
in a field, puts the caret on the block too, unless the part moved the caret.
A click with a key like ⌘ or ⇧ held leaves the caret where it is. The page
doesn't scroll, because the block is under the mouse.
"""
pick_clicked!(e, it::Item) = begin
  b = e.buf
  (unmodified(e) && rich(b) && !b.fixed && b.caret == b.stood) || return
  # A part of the block that changed its lines leaves the caret where it is
  part(b, it.first) == (it.first, it.last) || return
  b.caret = b.anchor = (it.first, 0)
  touch!(e)
  e.reveal = false
end

"""
Give a click on `node` to the page, as a click on its text is given. A part of
the page like a picture, a table from a CSV file or the front matter has no use
for a click of its own, so the page puts the caret on the part as a whole, or
with ⌥ held shows its lines as they're written. Such a part's node hangs from
the editor, not from the page's text, so the click doesn't get there by itself.
"""
click_page!(node, ev) = (press!(editor(node), ev.window.mouse); handled)

"""
How far a key scrolls the page while it's read, or nothing for a key that doesn't
scroll it. `command` is the command that the key runs while the page isn't read.
The keys that move the caret up and down scroll a little. The keys that move it
a screen, and Space, scroll a screen less a little, so a line or two stays in
sight. Home, End and the keys that move the caret to the top or the bottom of
the page scroll that far.
"""
read_step(e, K, command, down) = begin
  screen = e.scroll.viewport - 40px
  # Home, End and Space with no command scroll only by themselves, with no key of ⌃, ⌘, ⌥ and ⇧ held. Space with ⇧ goes back.
  plain = down == Keys(0)
  command == :up ? -50px :
  command == :down ? 50px :
  command == :page_up ? -screen :
  command == :page_down ? screen :
  command == :doc_start || (K == Keys.home && (command == :line_start || (command === nothing && plain))) ? px(-Inf) :
  command == :doc_end || (K == Keys._end && (command == :line_end || (command === nothing && plain))) ? px(Inf) :
  command === nothing && K == Keys.space && (plain || down == Keys.shft) ? (plain ? screen : -screen) : nothing
end

"Scroll the page by `by`, as far as it goes"
scroll_page!(e, by) = begin
  s = e.scroll
  s.offset = clamp(s.offset + by, 0px, max(0px, s.content_height - s.viewport))
  e
end

"True when `a` is `b` or holds it"
holds(a, b) = begin
  while b !== nothing
    b === a && return true
    b = b.parent
  end
  false
end

"""
True when the node that has the keyboard is something other than the text, and
the click that is happening now is on that node, or on a part of it, or on a
node that holds it. A click on a list in a live block gives the list the
keyboard, and the click goes on to the page after the list has taken it.
"""
took(e) = begin
  w = window_of(e)
  w === nothing && return false
  f, under = w.focus, hittest(w)
  (f === nothing || f === e || f === input(e) || under === nothing) && return false
  holds(f, under) || holds(under, f)
end

"A heading as a link names it: its letters and digits in lower case, with a - where anything else is. `Live blocks` is `live-blocks`."
heading_slug(words) = String(strip(replace(lowercase(plain_cell(words)), r"[^\p{L}\p{N}]+" => "-"), '-'))

"""
Follow a link that names a heading of a page: `welcome.md#tables`, or `#tables`
for a heading of the page that shows. The page opens, and the heading goes to
the top of the window. It's true when the link names a page. It's false for any
other link with a # in it, like the address of a web page.
"""
follow_heading!(e, url) = begin
  to = linked_file(e, url)
  (to !== nothing && occursin('#', url) && ismarkdown(to[1]) && isfile(to[1])) || return false
  go_heading!(e, to[1], unescaped(to[2]))
end

"Show the page at `path` with its heading `name` near the top of the window. A page with no such heading shows from where it was. It's true."
go_heading!(e, path, name) = begin
  hosted(e) === nothing || return go_heading!(top_editor(e), path, name)   # a link in a part of another page goes there in the window
  path == e.buf.path || open!(e, path)
  b = e.buf
  ks = kinds(b)
  slug = heading_slug(name)
  i = findfirst(i -> ks[i].kind == Kind.heading && heading_slug(rest(b.lines[i], ks[i].prefix)) == slug, eachindex(ks))
  i === nothing && return true
  show_line!(e, i)
  # Its line goes near the top of the window. The next frame does it, once it has laid out the page.
  e.nodes[:hold] = (i, 24px - PAGE_TOP)
  true
end

"""
The file:// address of the page of `e`, which its links are read from. A page
with no file is read from its folder. A reply of the agent is read from the
folder that the agent works in, as its page is there.
"""
page_uri(e) = URI{:file}(path=FSPath(isempty(e.buf.path) ? joinpath(e.folder, "Untitled") : e.buf.path))

"""
The file of the Mac that the link `url` in the page of `e` names, with what
follows its # as it's written, or nothing for a link to anything else, like a
web page or an email address. URI.jl reads the link as one in the page's own
file, so `plan.md#tables` is beside the page, `#tables` is in the page, and
`file:///Users/sam/plan.md#L12`, as an agent like Antigravity writes one, is
where it says. A path from ~, like `~/Mail`, is from the home folder.
"""
linked_file(e, url::AbstractString) = begin
  to = URI(url, page_uri(e))
  to isa URI{:file} || return nothing
  (string(to.path), to.fragment)
end

"""
Follow a link to lines of a file, as an agent writes one: `plan.md#L12`, or
`plan.md#L12-L20` for lines 12 to 20. The file shows in the window, with the
caret on the first of the lines and that line near the top of the window, as
a click on a heading in the outline does. A number past the end of the file
is its last line. It's false for a link that names no lines of a file that's
there.
"""
go_lines!(e, url) = begin
  to = linked_file(e, url)
  to === nothing && return false
  path, mark = to
  m = match(r"^L(\d+)(?:-L?\d+)?$", mark)
  (m !== nothing && isfile(path)) || return false
  e = top_editor(e)   # a link in a reply of the agent, or in a part of another page, shows in the window
  path == e.buf.path ? note_place!(e) : open!(e, path)   # ⌘⌥← comes back here
  # A file that shows as a picture, or a page that HTML makes, has no lines to go to
  (e.buf.path == path && !html_shown(e) && !isempty(e.buf.lines)) || return true
  line = clamp(parse(Int, m[1]), 1, length(e.buf.lines))
  show_line!(e, line)
  # The next frame puts the line near the top of the window, once it has laid out the file
  e.nodes[:hold] = (line, 24px - PAGE_TOP)
  true
end

# --- wiki links ---------------------------------------------------------------------------
#
# A wiki link, like [[Ideas]], names a page and not its file, as in Obsidian. The
# page can be anywhere in the project, so a link stays good when a page moves to
# another folder. See markdown.jl for how one is written.

"The folder names that mark the top folder of a project"
const PROJECT_MARKS = (".git", ".obsidian")

"""
The top folder of the project that the folder `dir` is in: the nearest folder,
from `dir` up, that has a `.git` or an `.obsidian` folder in it. It's `dir`
when there's none below the home folder.
"""
project_root(dir) = begin
  d = dir
  while d != homedir() && d != dirname(d)
    any(m -> ispath(joinpath(d, m)), PROJECT_MARKS) && return d
    d = dirname(d)
  end
  dir
end

"""
The file under `root` whose path ends with one of `names`, like `Ideas.md` or
`notes/Ideas.md`, in any case, or nothing. A file in a folder near the top
comes before one in a folder deeper down. Hidden folders, the ones that you
ignore and `node_modules` are left out, and the look stops after a part of a
second, as the `find` block's does.
"""
find_named(root, names; budget=FIND_BUDGET) = begin
  ends = ["/" * lowercase(n) for n in names]
  started = time()
  level = [root]
  ignored = Folders.ignored()
  while !isempty(level) && time() - started < budget
    deeper = String[]
    for dir in level
      found = try sort!(readdir(dir), by=lowercase) catch; String[] end
      for name in found
        path = joinpath(dir, name)
        left_out(path, ignored) && continue
        if isdir(path)
          name == "node_modules" || push!(deeper, path)
        elseif any(t -> endswith(lowercase(path), t), ends)
          return path
        end
      end
    end
    level = deeper
  end
  nothing
end

"The file that the wiki link to `name`, in a page in the folder `dir`, names, as `wiki_path` finds it, or nothing when no file has the name"
wiki_file(dir, name) = begin
  names = ismarkdown(name) ? [name] : [name * ".md", name]
  root = project_root(dir)
  for top in unique([dir, root]), n in names
    path = abspath(top, expanduser(n))
    isfile(path) && return path
  end
  find_named(root, names)
end

"""
The file that the wiki link to `name` names. `name` is a page's name, like
`Ideas`, and its file is `Ideas.md`. A name with a file's extension, like
`plan.pdf`, can be that file too. A name can have folders in it, like
`notes/Ideas`. Ladder looks in the page's own folder, then from the top of its
project (see `project_root`), then through the whole project. When no file
has the name, it's the path of a new page in the page's own folder.
"""
wiki_path(e, name) = begin
  dir = docdir(e)
  found = wiki_file(dir, name)
  found === nothing || return found
  names = ismarkdown(name) ? [name] : [name * ".md", name]
  new = abspath(dir, names[1])
  # A name with folders that aren't there yet makes its page in the page's own folder
  isdir(dirname(new)) ? new : joinpath(dir, basename(new))
end

"""
Follow a wiki link to `target`: show the page that it names. `Ideas#Plans` goes
to the heading Plans of the page Ideas, and `#Plans` to a heading of the page
that shows. A page that isn't anywhere opens as a new page with no text, in the
page's own folder. Its file is made when you write in it.
"""
follow_wiki!(e, target) = begin
  name, heading = occursin('#', target) ? String.(split(target, '#', limit=2)) : (target, "")
  name = String(strip(name))
  isempty(name) && return (go_heading!(e, e.buf.path, heading); e)
  path = wiki_path(e, name)
  if !isempty(heading) && ismarkdown(path) && isfile(path)
    go_heading!(e, path, heading)
    return e
  end
  isfile(path) ? show_path!(e, path) : open!(e, path)
end

# While you type the name in a wiki link, the list of names under the caret
# shows the pages of the project whose names fit what's typed. Right after the
# [[, it shows them all, the pages beside this one first. Each page's folder,
# from the top of the project, is at the right of its row. Return or Tab types
# the rest of the name and the ]] that ends the link. Two pages with the same
# name are each written with their folders, like notes/Ideas.

"""
The pages that the name being typed in a wiki link could be: the line, the
column where the name starts, and the names. Nothing when the caret isn't in
the name of a wiki link just after a character was typed, or no page fits.
"""
wiki_offered(e) = begin
  b = e.buf
  i, col = b.caret
  key = (b.path, b.version, b.caret)
  get(e.nodes, :typed_at, nothing) == key || return nothing
  kept = get(e.nodes, :wiki_offered, nothing)
  kept !== nothing && kept[1] == key && return kept[2]
  found = wiki_names(e, i, col)
  e.nodes[:wiki_offered] = (key, found)
  found
end

"The name being typed in a wiki link at column `col` of line `i`, and the pages that fit it, as `wiki_offered` gives them"
wiki_names(e, i, col) = begin
  b = e.buf
  kinds(b)[i].kind in (Kind.code, Kind.fence, Kind.table) && return nothing
  chars = collect(b.lines[i])
  # The name starts after the [[ before the caret. A | or a # ends it, and a bracket isn't part of one.
  start = col
  while start > 0 && !(chars[start] in ('[', ']', '|', '#')); start -= 1 end
  (start >= 2 && chars[start] == '[' && chars[start-1] == '[') || return nothing
  col - start <= 80 || return nothing
  typed = lowercase(String(chars[start+1:col]))
  dir = docdir(e)
  root = project_root(dir)
  pages = [p for (p, _) in folder_pages(root).pages if p != b.path]
  name(p) = splitext(basename(p))[1]
  many = Dict{String,Int}()
  foreach(p -> many[lowercase(name(p))] = get(many, lowercase(name(p)), 0) + 1, pages)
  notes = Dict{String,String}()
  found = Tuple{Int,Bool,Int,String,String}[]   # how well it fits, whether it's in another folder, how deep it is, its name in lower case, and its name
  for p in pages
    folder = relpath(dirname(p), root)
    folder == "." && (folder = "")
    # Two pages with the same name are told apart by their folders
    shown = many[lowercase(name(p))] > 1 && !isempty(folder) ? joinpath(folder, name(p)) : name(p)
    low = lowercase(shown)
    fit = low == typed ? 0 : startswith(low, typed) ? 1 : any(w -> startswith(w, typed), split(low, r"[\s_/-]+", keepempty=false)) ? 2 : occursin(typed, low) ? 3 : 4
    fit < 4 || continue
    shown == name(p) && (notes[shown] = folder)
    push!(found, (fit, dirname(p) != dir, count(==('/'), folder), low, shown))
  end
  isempty(found) && return nothing
  e.nodes[:wiki_notes] = notes
  (i, start, unique([n for (_, _, _, _, n) in first(sort!(found), NAMES_SHOWN)]))
end

"""
Type `name` in place of the text from column `start` of line `i` to the caret,
as the list of names does. In a wiki link, the ]] that ends the link comes too,
unless the link has its end already. The caret goes past a ]] that's just after the name.
"""
complete!(e, i, start, name) = begin
  b = e.buf
  edit!(b, (i, start), b.caret, name)
  kinds(b)[i].kind == Kind.code && return
  after = rest(b.lines[i], b.caret[2])
  ends, opens = findfirst("]]", after), findfirst("[[", after)
  if ends === nothing || (opens !== nothing && first(opens) < first(ends))
    edit!(b, b.caret, b.caret, "]]")
  elseif startswith(after, "]]")
    b.caret = b.anchor = (i, b.caret[2] + 2)
  end
end

# --- a part of another page ----------------------------------------------------------------
#
# A line that holds only a link like ![[Ideas#Plans]] shows that part of the
# page Ideas in this page. Ted Nelson called that a transclusion, and Notion
# calls it a synced block. The part isn't a copy. It's the other page's own
# lines: type in it here and the other page changes, and a change there shows
# here at once. ⌘S saves both pages. What comes after the # names the part:
#
#   - ![[Ideas]] is the whole page, without its front matter.
#   - ![[Ideas#Plans]] is the heading Plans and the lines under it, up to the
#     next heading that's as big as it or bigger.
#   - ![[Ideas#^prices]] is the block that has the name prices, as Obsidian
#     names one: see `block_id` in markdown.jl. The command Copy Link To Block
#     names the block at the caret, and copies the link that shows it.
#   - ![[Ideas#table 2]] is the second table of the page. A kind is one of
#     paragraph, heading, list, quote, table, code and picture, or the
#     language of a code block, like board, canvas or julia. Without a number,
#     it's the first one. Code counts the code blocks that show as code.
#
# A heading with the name comes first, so a heading called "Table 2" wins over
# the second table. The page is found as a wiki link finds it: see `wiki_path`.
#
# An editor of its own shows the part. It edits the other page's lines, and
# shows only the lines of the part. Ladder's keys work in it as they do in any
# page. A click in its text puts its caret there, and Return gives it the
# keyboard while the caret is on the part as a whole. ↑ on its first line, ↓
# on its last line and esc go back to this page. A key for the window, like
# ⌘W, is this page's. A live block of the other page, like a board or a chart,
# shows there what it shows in its own page, but a click on it does nothing.

"A line that holds only a link to a part of another page. The name of the part is after the [[."
const TRANSCLUSION = r"^\s*!\[\[([^\]|]+)(?:\|[^\]]*)?\]\]\s*$"

"True when line `i` holds only a link that shows a part of another page"
transcludes(b::Buffer, i::Int) = (line = b.lines[i]; occursin("![[", line) && occursin(TRANSCLUSION, line) && !in_browser(b.path))

"How many parts of other pages can show inside each other: a part of a page that shows a part of a page that…"
const DEEPEST_PART = 3

"How tall the line is that shows in place of a part that isn't there"
const PART_NOTE_H = 28px

"""
The room over the text of a part of another page. The button that opens the
other page sits there, on the line round the part. A click goes only to what's
inside its parent's box, so the button can't be over the line above the part.
"""
const PART_TAB = 15px

"A part of another page, as a line of this page shows it"
@def mutable struct Transclusion <: SemanticUI
  line::Int = 0            # the line of this page that names the part
  target::String = ""      # what the line names, like "Ideas#Plans"
  path::String = ""        # the other page's file
  sub::Any = nothing       # the editor of the other page's lines
  note::String = ""        # what shows in place of a part that isn't there
  tall::px = 0px
end

"What covers a live block in a part of another page, so that a click on the block does nothing"
@def mutable struct LiveCover <: SemanticUI
  tall::px = 0px
end

"The button over a part of another page that opens that page"
@def mutable struct PartSource <: SemanticUI
  of::Any = nothing   # the Transclusion
end

"The files of `e`'s page, of the page that shows a part of it, and so on up to the window's page"
host_paths(e) = (h = hosted(e); h === nothing ? [e.buf.path] : [e.buf.path; host_paths(h)])

"The views of the parts of other pages that `e`'s page shows"
transclusions(e) = [v for (k, v) in e.nodes if v isa Transclusion && k[2] == e.buf.path]

"The pages whose lines the parts on `e`'s page edit, with the pages that parts of those edit, and so on"
shown_buffers(e) = begin
  out = Buffer[]
  for v in transclusions(e)
    v.sub === nothing && continue
    any(b -> b === v.sub.buf, out) || push!(out, v.sub.buf)
    foreach(b -> any(c -> c === b, out) || push!(out, b), shown_buffers(v.sub))
  end
  out
end

"""
The blocks of the page that `b` holds, in order, as the kind of each, the
language of a code block, and its first and last line. The front matter and a
line that only names the block above it aren't blocks.
"""
transclusion_blocks(b::Buffer) = begin
  ks, lines = kinds(b), b.lines
  n = length(lines)
  out = Tuple{String,String,Int,Int}[]
  i = front_matter(lines) + 1
  lists = (Kind.bullet, Kind.ordered, Kind.todo)
  # The lines after `i` that go on in the block of line `i`
  run(more) = (t = i; while t < n && more(t + 1); t += 1 end; t)
  while i <= n
    k = ks[i]
    if k.kind == Kind.blank || only_id(lines[i])
      i += 1
      continue
    end
    kind, lang, t = if k.kind in (Kind.fence, Kind.code)
      s, t = codeblock(b, i)
      # A block that shows as what it makes, like a board, isn't code
      (solid(b, i) == (s, t) ? "block" : "code", k.lang, t)
    elseif k.kind == Kind.heading
      ("heading", "", i)
    elseif k.kind == Kind.rule
      ("rule", "", i)
    elseif k.kind == Kind.table
      ("table", "", run(j -> ks[j].kind == Kind.table))
    elseif k.kind in lists
      # A list goes on through the lines that are indented under its items
      ("list", "", run(j -> ks[j].kind in lists || (ks[j].kind == Kind.paragraph && ks[j].level > 0)))
    elseif k.kind == Kind.blockquote
      ("quote", "", run(j -> ks[j].kind == Kind.blockquote))
    elseif pictured(b, i) || transcludes(b, i)
      ("picture", "", i)
    else
      ("paragraph", "", run(j -> ks[j].kind == Kind.paragraph && !only_id(lines[j]) && !pictured(b, j) && !transcludes(b, j)))
    end
    push!(out, (kind, lang, i, t))
    i = t + 1
  end
  out
end

"""
The first and last line of the part of the page in `b` that `part` names, as
what comes after the # of a link like ![[Ideas#Plans]] names one, or nothing
when the page has no such part. "" names the whole page.
"""
transclusion_lines(b::Buffer, part::AbstractString) = begin
  lines, ks = b.lines, kinds(b)
  n = length(lines)
  part = String(strip(part))
  trimmed((s, t)) = (while t > s && isempty(strip(lines[t])); t -= 1 end; s <= t ? (s, t) : nothing)
  isempty(part) && return trimmed((min(front_matter(lines) + 1, n), n))
  found = transclusion_blocks(b)
  if startswith(part, '^')
    # The block whose last line ends with the name, or the block over a line that holds only the name
    name = part[2:end]
    i = findfirst(l -> block_id(l) == name, lines)
    i === nothing && return nothing
    if only_id(lines[i])
      above = findlast(x -> x[4] < i, found)
      return above === nothing ? nothing : found[above][3:4]
    end
    at = findfirst(x -> x[3] <= i <= x[4], found)
    at === nothing && return nothing
    kind, _, s, t = found[at]
    kind == "heading" && return heading_lines(b, i)
    # In a list, the name is on one item, and the part is that item with the lines indented under it
    if kind == "list"
      last = t
      t = i
      while t < last && ks[t+1].level > ks[i].level; t += 1 end
      return (i, t)
    end
    return (s, t)
  end
  # A heading with the name
  slug = heading_slug(part)
  i = findfirst(j -> ks[j].kind == Kind.heading && heading_slug(heading_words(b, j)) == slug, 1:n)
  i === nothing || return heading_lines(b, i)
  # A kind and a number, like table 2
  m = match(r"^(\p{L}[\p{L}\p{N}_+-]*)\s*(\d*)$", part)
  m === nothing && return nothing
  want, nth = lowercase(m[1]), isempty(m[2]) ? 1 : parse(Int, m[2])
  want = get(Dict("paragraphs" => "paragraph", "headings" => "heading", "lists" => "list", "quotes" => "quote",
                  "tables" => "table", "pictures" => "picture", "image" => "picture"), want, want)
  fits = [(s, t) for (kind, lang, s, t) in found if kind == want || (kind in ("code", "block") && lowercase(lang) == want)]
  1 <= nth <= length(fits) ? fits[nth] : nothing
end

"The words of the heading on line `i`, without its #s and without the name of its block"
heading_words(b::Buffer, i::Int) = begin
  text = rest(b.lines[i], kinds(b)[i].prefix)
  block_id(text) === nothing ? text : rstrip(text[1:prevind(text, findlast(==('^'), text))])
end

"The heading on line `i` and the lines under it, up to the next heading that's as big or bigger, without the empty lines at the end"
heading_lines(b::Buffer, i::Int) = begin
  ks, n = kinds(b), length(b.lines)
  t = i
  while t < n && !(ks[t+1].kind == Kind.heading && ks[t+1].level <= ks[i].level); t += 1 end
  while t > i && isempty(strip(b.lines[t])); t -= 1 end
  (i, t)
end

"What line `i` shows when it holds a link to a part of another page. It's the `n`th such line of the page."
transclusion_item(e, i, n) = begin
  v = get!(Transclusion, e.nodes, (:part, e.buf.path, n))
  own!(node!(Document, e, :document), v)
  v.line = i
  show_part!(v, e, String(strip(match(TRANSCLUSION, e.buf.lines[i])[1])))
  Live(v, part_tall(v) + 2LIVE_GAP)
end

"How tall a part of another page is on the page that shows it, with the room over it for its button"
part_tall(v::Transclusion) = isempty(v.note) ? PART_TAB + v.tall : v.tall

"""
Find the part that `target`, like "Ideas#Plans", names, and lay out its lines
for the page of `e`. While the part's editor has the keyboard, the part keeps
the lines that it has, with the lines that typing adds, so a heading that's
being renamed doesn't make it go.
"""
show_part!(v::Transclusion, e, target::String) = begin
  v.target = target
  name, part = occursin('#', target) ? String.(split(target, '#', limit=2)) : (target, "")
  name = String(strip(name))
  path = isempty(name) ? e.buf.path : wiki_path(e, name)
  shown = isempty(name) ? title(path) : name
  note(words) = (v.note = words; v.tall = PART_NOTE_H; v)
  isfile(path) || return note("There's no page called $shown")
  ismarkdown(path) || return note("Only a page of Markdown can show a part of itself here")
  path in host_paths(e) && return note("A page can't show a part of itself")
  length(host_paths(e)) >= DEEPEST_PART && return note("Parts of pages show inside each other too deeply to show $shown here")
  if v.sub === nothing || v.path != path
    v.sub = part_editor(e, path)
    setfield!(v.sub, :parent, v)
  end
  v.path = path
  sub = v.sub
  b = sub.buf
  refresh!(b)   # a change that something else made to the other page's file shows here too
  w = window_of(e)
  typing = w !== nothing && w.focus === sub
  kept = get(sub.nodes, :kept, nothing)
  span = if typing && kept !== nothing
    # Every change while it types is in the part, so its last line moves down as lines are added
    (s, t), had = kept
    s <= length(b.lines) ? (s, clamp(t + length(b.lines) - had, s, length(b.lines))) : nothing
  else
    transclusion_lines(b, part)
  end
  span === nothing && return note("$shown has no $(isempty(part) ? "lines" : part)")
  v.note = ""
  sub.nodes[:span] = span
  sub.nodes[:kept] = (span, length(b.lines))
  # While no part of this page has the other page's caret, every line of the part shows as it reads
  (w !== nothing && w.focus isa Editor && w.focus.buf === b) || (b.reading = true; sub.plain = false)
  follow_host!(sub, e)
  layout!(sub, e.width)
  v.tall = isempty(sub.layout) ? 0px : lowest(sub, sub.layout)
  typing && sub.reveal && keep_shown!(v, e)
  v
end

"An editor of the page at `path`, for a part of it that the page of `e` shows. It edits the lines that the window has open for that page."
part_editor(e, path) = begin
  sub = Editor()
  sub.buffers = e.buffers
  sub.buf = get!(() -> load(path), e.buffers, path)
  sub.nodes[:input] = own!(sub, TextInput())
  sub.nodes[:host] = e
  sub
end

"Give the editor of a part the choices of the editor of the page that shows it: its colours, font, text size and keys"
follow_host!(sub, e) = begin
  for f in (:theme, :look, :font, :weight, :zoom, :code_scale, :code_font, :code_weight, :indent, :wrap, :spelling,
            :glide, :bundle, :rebound, :widest, :size, :autosave)
    setfield!(sub, f, getfield(e, f))
  end
  # Text that was laid out in another font or at another size is laid out again
  key = (e.theme, e.look, e.font, e.weight, e.zoom, e.code_scale, e.code_font, e.code_weight)
  get(sub.nodes, :style, nothing) == key || (sub.nodes[:style] = key; empty!(sub.flows))
  sub
end

"Scroll the page of `e` so that the caret of the part that `v` shows is in the window"
keep_shown!(v::Transclusion, e) = begin
  sub = v.sub
  sub.reveal = false
  b = sub.buf
  it = item(sub, b.caret[1])
  top, high = it.top, it.tall
  if it.content isa Flow
    k, _ = spot(it.content, b.caret[2])
    top, high = it.top + line_top(it.content, k), it.content.lines[k].high
  end
  # The page's own layout isn't done, so the place of the part on it is found after it is
  e.nodes[:show_part] = (v.line, top, high)
end

"Scroll the window's page to the caret of a part of another page that it shows, once the page is laid out"
reveal_part!(e) = begin
  kept = pop!(e.nodes, :show_part, nothing)
  (kept === nothing || isempty(e.layout)) && return
  line, top, high = kept
  at = item(e, line).top + LIVE_GAP + PART_TAB + top
  scroll_into_view!(e.scroll, PAGE_TOP + at - 30px, PAGE_TOP + at + high + 40px)
end

describe(v::Transclusion) = begin
  isempty(v.note) || return Row(width(grow=grow), height(v.tall), Alignment.Center, child_gap=6px,
    Icon("link-45deg", size=14px, color=colours.faint), Box(label(v.note, 13px, color=colours.dim)))
  doc = node!(Document, v.sub, :document)
  w = window_of(v)
  page = Box(width(grow=grow), height(part_tall(v)), Alignment.Start, padding(PART_TAB, 0px, 0px, 0px), doc)
  # The name of the page that the part comes from shows at its top right while the mouse is over it or it has the keyboard
  on = ishovered(v) || (w !== nothing && w.focus === v.sub)
  on || return page
  source = node!(() -> PartSource(of=v), v.sub, :source)
  Stack(width(grow=grow), height(part_tall(v)), Alignment.Start, page,
    Row(width(grow=grow), Alignment.Start, justify=Alignment.End, padding(0px, 6px, 0px, 0px), source))
end

"Draw a line round a part of another page while the mouse is over it or it has the keyboard"
draw(ctx, size, ui::ConcreteRect, v::Transclusion) = begin
  isempty(v.note) || return
  w = window_of(v)
  on = w !== nothing && w.focus === v.sub
  (on || ishovered(v)) || return
  top, high = num(ui.top) + num(PART_TAB), num(ui.height) - num(PART_TAB)
  round_box(ctx, num(ui.left) - RING_OUT, top - num(LIVE_GAP) + 2, num(ui.width) + 2RING_OUT, high + 2num(LIVE_GAP) - 4, 8.0,
            line=on ? tint(colours.accent, 0.75) : colours.line, wide=on ? 1.5 : 1.0)
  # The button that opens the other page sits on the line, so it's drawn again over the line
  for row in ui.children
    row isa ConcreteRect || continue
    for chip in row.children
      chip isa ConcreteRect && chip.from.from isa PartSource && draw(ctx, chip.size, chip)
    end
  end
end

# A click in the part's text is for its editor, which puts the caret there. A click that the part's editor didn't take,
# like one on the room round its text, puts this page's caret on the part as a whole.
onkey(v::Transclusion, ev::KeyPress{Keys.mouse_left}) =
  (w = ev.window; v.sub !== nothing && (w.focus === v.sub || only_held(w, Keys.opt)) ? handled : click_page!(v, ev))
# A key that the part's editor had is done with: it isn't for this page too
onkey(::Transclusion, ::KeyPress) = handled
onmouse(::Transclusion, ::MouseMove) = handled

describe(c::LiveCover) = Box(width(grow=grow), height(c.tall))
onkey(::LiveCover, ::KeyPress{Keys.mouse_left}) = handled
onmouse(::LiveCover, ::MouseMove) = handled
cursor(::LiveCover) = :arrow

"What covers the live block that `it` shows in the part of another page that `e` edits"
live_cover(e, it::Item) = (c = node!(LiveCover, e, (:cover, it.first)); c.tall = it.content.tall - 2LIVE_GAP; c)

describe(s::PartSource) = begin
  v = s.of
  Row(height(18px), padding(7px, 0px), child_gap=4px, radius(9px), Alignment.Center,
      background(ishovered(s) ? colours.active : colours.bg), border(1px, :solid, colours.line),
    Box(label(splitext(basename(v.path))[1], 11px, color=colours.dim)), Icon("box-arrow-up-right", size=10px, color=colours.dim))
end
cursor(::PartSource) = :hand
onkey(s::PartSource, ::KeyPress{Keys.mouse_left}) = (open_part!(s.of); handled)
onmouse(::PartSource, ::MouseMove) = handled

"Show the page that `v` shows a part of, with the part's first line near the top of the window"
open_part!(v::Transclusion) = begin
  top = top_editor(editor(v))
  s = v.sub === nothing ? 1 : get(v.sub.nodes, :span, (1, 1))[1]
  open!(top, v.path)
  show_line!(top, s)
  top.nodes[:hold] = (s, 24px - PAGE_TOP)
  top
end

"""
Give the keyboard to the part that `v` shows, with its caret at the start of
the part's first line, or at `at` in the other page's lines.
"""
enter_shown!(v::Transclusion, at=nothing) = begin
  sub = v.sub
  (sub === nothing || !isempty(v.note)) && return nothing
  b = sub.buf
  s, t = sub.nodes[:span]
  b.reading = false
  b.caret = b.anchor = settle(b, something(at, (s, 0)), 1)
  confine!(sub)
  focus(sub)
  touch!(sub)
  sub
end

"""
Give the keyboard back to the page that shows the part that `e` edits. Its
caret goes onto the part as a whole, or with `by` of -1 or 1 on to the line
over the part or under it.
"""
leave_part!(e, by::Int=0) = begin
  host = hosted(e)
  v = getfield(e, :parent)
  e.buf.reading = true
  e.plain = false
  hb = host.buf
  hb.caret = hb.anchor = (v.line, 0)
  focus(host)
  touch!(host)
  w = window_of(host)
  by == 0 || w === nothing || run!(host, w, by < 0 ? :up : :down)
  host
end

"Commands for the window that leave the keyboard in the part of another page that has it"
const KEEP_PART = (:save, :bigger, :smaller, :usual_size, :inspector, :sidebar, :hidden_files, :settings, :commands)

"""
What a key does in a part of another page before the part's editor does what
it does with a key. True when the key is done with. A command for the window
runs in the window's own page. ⌘E shows the part's lines as they're written.
"""
part_key!(e, w, K, command, select) = begin
  b = e.buf
  s, t = e.nodes[:span]
  kind = command === nothing ? :none : COMMANDS[command].kind
  K == Keys.escape && unmodified(w) && return (leave_part!(e); true)
  if command == :plain
    e.plain = !e.plain
    return true
  end
  if kind == :window || command in (:find, :find_next, :find_last)
    if !(command in KEEP_PART)
      f = e
      while hosted(f) !== nothing; f = leave_part!(f) end
    end
    run!(top_editor(e), w, command, select)
    return true
  end
  # ↑ on the first line and ↓ on the last go on to the page that shows the part
  if command in (:up, :down) && !select && isempty(others(b))
    by = command == :up ? -1 : 1
    p = vertical(e, by)
    (p[1] < s || p[1] > t || p == b.caret) && return (leave_part!(e, by); true)
  end
  # A key that would join the part's first line to the line over it, or its last line to the line under it, does nothing
  if !selecting(b) && ((command in (:erase_back, :erase_word_back, :erase_line_start) && b.caret == (s, 0)) ||
                       (command in (:erase, :erase_word) && b.caret == line_end(b, t)))
    return true
  end
  # A live block in the part is only shown: the caret can be on it as a whole, and nothing changes it
  picked(b) !== nothing && (K == Keys.enter || kind in (:edit, :type))
end

"""
Copy a link that shows the block at the caret in another page, like
![[Ideas#^prices]]. A block without a name gets one from its first words: at
the end of its last line, or on a line under a list, a table or a code block.
"""
copy_link_to_block!(e) = begin
  link = block_link!(e)
  link === nothing && return nothing
  clipboard(link)
  e.nodes[:result] = ("Copied $link", time())
  redraw_in!(e, 0)
  link
end
works_here(e, ::Val{:copy_link_to_block}) = e.buf.view == :markdown && !readonly(e.buf)

"The link that shows the block at the caret in another page, as `copy_link_to_block!` makes it, or nothing. The block gets a name if it has none."
block_link!(e) = begin
  b = e.buf
  (b.view == :markdown && !readonly(b) && !b.fixed && isfile(b.path)) || return nothing
  i = b.caret[1]
  found = transclusion_blocks(b)
  at = findfirst(x -> x[3] <= i <= x[4], found)
  at === nothing && return nothing
  _, _, s, t = found[at]
  # A heading's link shows the lines under it too
  kinds(b)[s].kind == Kind.heading && ((s, t) = heading_lines(b, s))
  name = node_name!(b, s, t)
  touch!(e)
  "![[$(title(b.path))#^$name]]"
end

"""
The block of `b` that lines `s` to `t` are the whole of, or nothing: a block
of the page, a heading with the lines under it, or an item of a list with the
lines indented under it. The front matter isn't one, and nor is a line that
already shows a part of another page.
"""
whole_node(b::Buffer, s::Int, t::Int) = begin
  (b.view == :markdown && front_matter(b.lines) < s <= t <= length(b.lines)) || return nothing
  ks = kinds(b)
  ks[s].kind == Kind.heading && return heading_lines(b, s) == (s, t) ? (s, t) : nothing
  found = transclusion_blocks(b)
  at = findfirst(x -> x[3] <= s <= x[4], found)
  at === nothing && return nothing
  kind, _, from, to = found[at]
  (kind == "picture" && transcludes(b, s)) && return nothing
  from == s && to == t && return (s, t)
  kind == "list" || return nothing
  last = s
  while last < to && ks[last+1].level > ks[s].level; last += 1 end
  last == t ? (s, t) : nothing
end

"""
The name of the block of `b` from line `s` to line `t`, which a link from
another page uses, like `prices` in ![[costs#^prices]]. A block without one
gets one from the first words of its first line: at the end of the line of a heading or an item
of a list, at the end of a paragraph's last line, or on a line under anything
else. The caret stays where it was in the text.
"""
node_name!(b::Buffer, s::Int, t::Int) = begin
  ks = kinds(b)
  found = transclusion_blocks(b)
  at = findfirst(x -> x[3] == s, found)
  kind, lang = at === nothing ? ("item", "") : found[at][1:2]
  ks[s].kind == Kind.heading && (kind = "heading")
  kind == "list" && found[at][4] != t && (kind = "item")
  ends = kind in ("heading", "item") ? s : kind == "paragraph" ? t : 0
  name = ends > 0 ? block_id(b.lines[ends]) : nothing
  # A name on a line under the block names it too, but not a heading's lines or an item's: that's the name of their last block
  under = kind in ("heading", "item") || t == length(b.lines) || !only_id(b.lines[t+1]) ? nothing : block_id(b.lines[t+1])
  name = something(name, under, Some(nothing))
  name === nothing || return name
  words = kind in ("code", "block") ? [isempty(lang) ? "code" : lang] :
          kind in ("table", "picture") ? [kind] :
          first(split(lowercase(replace(b.lines[s], r"[^\p{L}\p{N}\s]" => " "))), 4)
  words = first(filter(w -> !isempty(w) && w != "x", String.(words)), 3)
  base = isempty(words) ? kind : join(words, '-')
  taken = Set(something(block_id(l), "") for l in b.lines)
  name, k = base, 1
  while name in taken; k += 1; name = "$base-$k" end
  caret, anchor = b.caret, b.anchor
  if ends > 0
    edit!(b, line_end(b, ends), line_end(b, ends), " ^" * name)
    b.caret, b.anchor = caret, anchor
  else
    edit!(b, line_end(b, t), line_end(b, t), "\n^" * name)
    moved(p) = p[1] > t ? (p[1] + 1, p[2]) : p
    b.caret, b.anchor = moved(caret), moved(anchor)
  end
  name
end

# --- a block that's copied pastes as a part of its page --------------------------------------
#
# Copy a whole block of a page and paste it into another page, and the other
# page gets a line like ![[costs#^prices]]: a part of the first page, which
# you type in, and not a copy of its lines. The block gets a name if it has
# none. A block is copied whole while the caret is on it as a whole, after a
# click with ⌘ and ⌥ down chose it, or when the selection runs from its start
# to its end. A heading with the lines under it is one block, and so is an
# item of a list with the lines indented under it. ⌘⇧V pastes the lines
# instead. A paste in the page that the block came from pastes its lines too,
# and so does a block that's cut, since a cut block leaves its page.

"The block that Ladder last copied whole: the text that it put on the clipboard, the lines of the page that the block is in, the block's lines and its first and last line"
const COPIED_BLOCK = Ref{Any}(nothing)

"Put `text` on the clipboard. A window that isn't on the screen keeps it to itself, so a test leaves the Mac's clipboard alone."
copy_text!(e, text) = (w = window_of(e); w === nothing ? clipboard(text) : clipboard!(w, text); text)

"Note what was just copied: `text`, from the selection `span` of the page of `e`. A whole block is kept, for a paste in another page."
copied!(e, span, text) = begin
  COPIED_BLOCK[] = nothing
  b = e.buf
  (span === nothing || b.view != :markdown || !isfile(b.path) || Eml.isemail(b.path)) && return nothing
  lo, hi = span
  s, t = lo[1], hi[1]
  hi[2] == 0 && t > s && (t -= 1)   # a selection that ends at the start of the next line
  # It starts no later than the first line's words start, and goes to the end of its last line
  (lo[2] <= kinds(b)[s].prefix && (hi[1] > t || hi[2] >= length(b.lines[t]))) || return nothing
  whole_node(b, s, t) === nothing && return nothing
  COPIED_BLOCK[] = (text=String(text), buf=b, lines=b.lines[s:t], first=s, last=t)
end

"""
The line that shows the block that Ladder last copied whole, when `text` is
what it copied and the page of `e` is another page, or nothing. The block
gets a name in its own page if it has none. Its page is saved then if it had
no other changes, so that a window that reads the page from its file finds the name.
"""
pasted_part(e, text) = begin
  c = COPIED_BLOCK[]
  (c !== nothing && c.text == text) || return nothing
  b, src = e.buf, c.buf
  (b.view == :markdown && !readonly(b) && !b.fixed && b.path != src.path && isfile(src.path)) || return nothing
  # The block is on the lines that it was copied from, or it's found again in its page
  s, t = c.first, c.last
  n = t - s
  if !(t <= length(src.lines) && src.lines[s:t] == c.lines)
    k = findfirst(i -> i + n <= length(src.lines) && src.lines[i:i+n] == c.lines, eachindex(src.lines))
    k === nothing && return nothing
    s, t = k, k + n
  end
  whole_node(src, s, t) === nothing && return nothing
  clean = !dirty(src)
  name = node_name!(src, s, t)
  clean && dirty(src) && save!(src)
  "![[$(page_name_for(e, src.path))#^$name]]"
end

"Put `link`, a line that shows a part of another page, on a line of its own: on the empty line that the caret is on, or under the block that it's in. The caret goes onto the part as a whole."
paste_part!(e, link) = begin
  b = e.buf
  selecting(b) && type!(e, "")
  i = b.caret[1]
  if isempty(strip(b.lines[i]))
    edit!(b, (i, 0), line_end(b, i), link)
  else
    under = block_end(b, i)
    after = under < length(b.lines) && !isempty(strip(b.lines[under+1])) ? "\n" : ""
    edit!(b, line_end(b, under), line_end(b, under), "\n\n" * link * after)
    i = under + 2
  end
  b.caret = b.anchor = (i, 0)
  focus(e)
  touch!(e)
end

"Paste what the clipboard holds as text: a block that was copied whole from another page goes in as a copy of its lines, not as a part of that page"
paste_copy!(e) = begin
  copied = COPIED_BLOCK[]
  COPIED_BLOCK[] = nothing
  try paste!(e) finally COPIED_BLOCK[] = copied end
end

"True when the Finder shows the folder at `path` as one file, as it shows an app"
ispackage(path) = with_pool() do
  ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
        msg(cls("NSWorkspace"), "sharedWorkspace"), sel("isFilePackageAtPath:"), nsstring(path))
end

"""
Open a link. A file on the Mac shows in this editor, like a page, or a file
that came with an email. A folder on the Mac shows in the page, and the
sidebar lists it. Anything else opens in the app that the Mac uses for it. A path can start at the home folder, like `~/Mail`.
"""
follow!(e, url) = begin
  startswith(url, '^') && return follow_note!(e, url[2:end])
  in_browser(e.buf.path) && return follow_remote!(e, url)   # a link of a page from a web server is from the page's address
  target = wikitarget(url)
  target === nothing || return follow_wiki!(e, target)   # a wiki link, like [[Ideas]]
  go_lines!(e, url) && return e   # lines of a file, like main.jl#L12-L20
  occursin('#', url) && follow_heading!(e, url) && return e   # a heading of a page, like welcome.md#tables
  to = linked_file(e, url)
  to !== nothing && ispath(to[1]) && return show_path!(e, to[1])
  # The address of a page of Markdown on a web server shows in the window: see "a page from a web server"
  reads_here(e, url) ? get_page!(e, url, else_browser=true) : open_url(url)
end

"""
Show the file or the folder at `path` in the window, as a link to it does.
The sidebar lists the folder, and it stays as it was: open or closed. Only
you open it. A folder that the Finder shows as one file, like an app, opens as
that file does.
"""
show_path!(e, path) = begin
  hosted(e) === nothing || return show_path!(top_editor(e), path)   # a link in a part of another page shows in the window
  isfile(path) && return open!(e, path)
  (isdir(path) && !ispackage(path)) || return open_url(path)
  path = String(rstrip(path, '/'))
  # The folder's own page says its kind, and loads the code of the kind. It runs now if it hasn't, and
  # the rest goes on with that code.
  folder_pages!(path)
  Base.invokelatest(follow_folder!, e, path)
  e
end

"""
Do what a click on the folder at `path` does in the sidebar. A kind of folder
can show a page of its own, like a blog's Readme. When the click only lists the
folder in the sidebar, the page shows the folder too, so you see it with the
sidebar closed.
"""
follow_folder!(e, path) = begin
  folder_pages_tick!(e)   # the sidebar can have listed the folder before its page ran
  was = e.buf.path
  o = try object(e, path) catch; nothing end
  o isa AbstractDirectory ? open!(e, o) : go_folder!(e, path)
  # A blog's Readme that already showed is the folder's own page, so it stays
  e.buf.path == was && !on_own_page(e, o) && show_beside!(e, path)
  e
end

"True when the page shows the folder `o`'s own page, when that's a file in it, like a blog's Readme"
on_own_page(e, o) = false

drag!(e, pos) = begin
  haskey(e.nodes, :scrub) && held(e, Keys.mouse_left) && return scrub_to!(e, pos)
  held(e, Keys.mouse_left) && e.clicked[3] == 1 || return
  at = settle(e.buf, locate(e, pos))
  at == e.buf.caret && return
  e.buf.caret = at
  touch!(e)
end

onkey(d::Document, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(d)
  done = press!(e, ev.window.mouse)
  # In what an agent said, once it's all said, the click puts the caret there. The pane under it would give the keyboard to the words that you type.
  part = agent_part_of(e)
  part !== nothing && part[2] == :reply && !e.buf.fixed ? handled : done
end
onkey(p::Page, ev::KeyPress{Keys.mouse_left}) = press!(editor(p), ev.window.mouse)
onmouse(d::Document, ev::MouseMove) = begin
  e = editor(d)
  Base.invokelatest(hover_check!, e, ev.position)
  # The window draws again as the mouse goes on to a footnote's number or off it, for its card: see `note_peek!`
  (haskey(e.nodes, :note_peek) || Base.invokelatest(note_at, e, ev.position) !== nothing) && redraw_in!(e, 0)
  drag!(e, ev.position)
end
onmouse(p::Page, ev::MouseMove) = drag!(editor(p), ev.position)

# --- editing -----------------------------------------------------------------------------

"Put `new` where the selection is, or at the caret"
type!(e, new; typing=false) = begin
  b = e.buf
  run = picked(b)
  if run !== nothing
    isempty(new) && return e
    # What's pasted or inserted while the caret is on a part as a whole goes on a line of its own under the part
    b.caret = b.anchor = line_end(b, run[2])
    new = "\n" * new
  end
  cell = cellat(b, b.caret)
  if cell !== nothing && b.caret[1] == b.anchor[1]
    # In a row of a table, typing only ever changes the cell the caret is in
    lo, hi = selection(b)
    (within(cell, lo[2]) && within(cell, hi[2])) || (b.anchor = b.caret)
    new = replace(new, '\n' => ' ')
  end
  lo, hi = selection(b)
  # A third ` that opens a code block. Inside a block it would close that block instead.
  fence = new == "`" && lo == hi && kinds(b)[lo[1]].kind != Kind.code && strip(b.lines[lo[1]]) == "``" && lo[2] == length(b.lines[lo[1]])
  if rich(b) && lo != hi
    # As rich text, the markup of text that's only partly selected stays, after what's typed
    from, to, kept = richcut(b, lo, hi, typed=!isempty(new))
    edit!(b, from, to, new * kept; typing)
    parts = split(new, '\n')
    b.caret = b.anchor = (from[1] + length(parts) - 1, length(parts) == 1 ? from[2] + length(new) : length(last(parts)))
  else
    edit!(b, lo, hi, new; typing)
  end
  if fence
    # The line that closes the block is typed too. Without it, the block would
    # take the line that opens the next block as its end, and turn every block
    # after it inside out.
    at = b.caret
    edit!(b, at, at, "\n```")
    b.caret = b.anchor = at
  end
  touch!(e)
end

"The place one character of the file before or after `p`"
neighbour(b::Buffer, (i, col)::Pos, by::Int) =
  by < 0 ? (col > 0 ? (i, col - 1) : i > 1 ? line_end(b, i - 1) : (i, col)) :
           (col < length(b.lines[i]) ? (i, col + 1) : i < length(b.lines) ? (i + 1, 0) : (i, col))

"""
The place one character before or after `p`. As rich text that's one
character that shows: the place is past any markup that's in the way, and past
the whole of something that shows as one thing, like the number of a footnote.
"""
beside(b::Buffer, p::Pos, by::Int) = begin
  rich(b) || return neighbour(b, p, by)
  run = p == b.caret ? picked(b) : nothing
  # From a part that the caret is on as a whole, it's the end of the line before the part or the start of the line after it
  run === nothing || return by < 0 ? (run[1] > 1 ? line_end(b, run[1] - 1) : p) : (run[2] < length(b.lines) ? (run[2] + 1, 0) : p)
  i, col = p
  hidden, whole = unseen(b, i), wholes(b, i)
  if by < 0
    for (a, z) in hidden
      a < col <= z && (col = a)
    end
    col <= 0 && return neighbour(b, (i, 0), by)
    k = findfirst(r -> r[2] == col, whole)
    (i, k === nothing ? col - 1 : whole[k][1])
  else
    for (a, z) in hidden
      a <= col < z && (col = z)
    end
    col >= length(b.lines[i]) && return neighbour(b, line_end(b, i), by)
    k = findfirst(r -> r[1] == col, whole)
    (i, k === nothing ? col + 1 : whole[k][2])
  end
end

"The place one word before or after `p`"
word_step(b::Buffer, p::Pos, by::Int) = begin
  i, col = p
  chars = collect(b.lines[i])
  # As rich text, a line's text can start after characters that don't show, like the # of a heading
  (by < 0 ? col <= first_stop(b, i) : col == length(chars)) && return beside(b, p, by)
  if by < 0
    while col > 0 && !isword(chars[col]); col -= 1 end
    while col > 0 && isword(chars[col]); col -= 1 end
  else
    while col < length(chars) && !isword(chars[col+1]); col += 1 end
    while col < length(chars) && isword(chars[col+1]); col += 1 end
  end
  (i, col)
end

"The place one line up or down the screen from the caret, in the order of the page's lines. `vertical` keeps it in a column of the page."
line_step(e, by::Int) = begin
  b = e.buf
  i, col = b.caret
  run = picked(b)
  if run !== nothing
    # From a part that the caret is on as a whole, ↑ goes to the line before the part and ↓ to the line after it
    j = by > 0 ? run[2] + 1 : run[1] - 1
    j < 1 && return b.caret
    if j > length(b.lines)
      # ↓ on a part at the end of the document starts a line below it, as it does under a table
      edit!(b, line_end(b, length(b.lines)), line_end(b, length(b.lines)), "\n")
      return (length(b.lines), 0)
    end
    x = e.goal = something(e.goal, 0px)
    free(b, j, 0) || return by > 0 ? (j, 0) : line_end(b, j)
    into = item(e, j)
    into.content isa Sheet && return enter(e, into, into.content, by, x)
    f = flow(e, j, false)
    return (j, colat(f, by < 0 ? length(f.lines) : 1, x))
  end
  it = item(e, i)
  at = it.content isa Grid ? gridcell(it.content, b.caret) : nothing
  at === nothing || return vertical(e, it, at, by)
  it.content isa Sheet && return vertical(e, it, it.content, by)
  f = flow(e, i)
  k, x = spot(f, col)
  x = e.goal = something(e.goal, x)
  1 <= k + by <= length(f.lines) && return (i, colat(f, k + by, x))
  j = i + by
  if rich(b)
    # As rich text, the caret steps over a line that doesn't show, like the ``` of a code block
    j = step_over(b, j, by, i)
    if j > length(b.lines) && i < length(b.lines)
      # ↓ over such a line at the end of the document starts a line below it, as it does under a table
      edit!(b, line_end(b, length(b.lines)), line_end(b, length(b.lines)), "\n")
      return (length(b.lines), 0)
    end
    # It goes onto a part that shows as one thing, like a diagram, as a whole
    1 <= j <= length(b.lines) && !free(b, j, i) && return (j, 0)
  end
  j < 1 && return (1, 0)
  j > length(b.lines) && return line_end(b, i)
  # Into a sheet, the caret goes to the cell that's under it or over it
  into = item(e, j)
  into.content isa Sheet && return enter(e, into, into.content, by, x)
  # The line is laid out as it will show with the caret on it. A line of text shows little of its markup as plain text, so it's laid out as it reads.
  f = flow(e, j, b.plain && !by_runs(b, j))
  (j, colat(f, by < 0 ? length(f.lines) : 1, x))
end

"The place one line up or down from the caret, which is in row `r`, column `c` of a table"
vertical(e, it::Item, (r, c), by::Int) = begin
  b = e.buf
  g = it.content::Grid
  f = g.flows[r][c]
  k, x = spot(f, b.caret[2])
  x = e.goal = something(e.goal, x)
  1 <= k + by <= length(f.lines) && return (b.caret[1], cellcol(f, k + by, x, g.cells[r][c]))
  r += by
  if r < 1
    return it.first > 1 ? line_end(b, it.first - 1) : b.caret
  elseif r > length(g.rows)
    # ↓ on the last row of a table at the end of the document starts a line below it
    it.last == length(b.lines) && edit!(b, line_end(b, it.last), line_end(b, it.last), "\n")
    return (it.last + 1, 0)
  end
  isempty(g.cells[r]) && return (g.rows[r], 0)
  c = min(c, length(g.cells[r]))
  f = g.flows[r][c]
  (g.rows[r], cellcol(f, by < 0 ? length(f.lines) : 1, x, g.cells[r][c]))
end

"The start or end of the line of the screen that the caret is on"
screen_edge(e, by::Int) = begin
  cell = cellat(e.buf, e.buf.caret)
  cell === nothing || return (e.buf.caret[1], by < 0 ? cell.lo : cell.hi)
  i, col = e.buf.caret
  f = flow(e, i)
  k, _ = spot(f, col)
  vl = f.lines[k]
  by < 0 ? (i, vl.from) : (i, k < length(f.lines) ? max(vl.from, vl.to - 1) : vl.to)
end

"""
Where a selection that grows to `p` ends. It steps over the ``` lines of a code
block that the selection didn't start in, and over the whole of a block that
shows as one thing, like a diagram or a contact, because those lines don't show.
"""
pass(b::Buffer, p::Pos, by::Int) = begin
  ks = kinds(b)
  i = p[1]
  ks[i].kind in (Kind.fence, Kind.code) || return p
  s, t = codeblock(b, i)
  s <= b.anchor[1] <= t && return p
  whole = solid(b, i)
  if whole !== nothing && whole[1] < whole[2]
    # Under a block that ends the document there's no line to go to, so the selection ends where the block does
    by > 0 && whole[2] == length(b.lines) && return line_end(b, whole[2])
    i = by < 0 ? whole[1] - 1 : whole[2] + 1
  elseif ks[i].kind == Kind.fence
    i += by
  else
    return p
  end
  1 <= i <= length(b.lines) || return p
  by < 0 ? line_end(b, i) : (i, 0)
end

"Move the caret to `p`, which was reached by going in the direction `by`. With `extend`, the selection grows to it."
move!(e, p::Pos, extend::Bool; keep_goal=false, by=0) = begin
  p = settle(e.buf, p, by)
  extend && by != 0 && (p = pass(e.buf, p, by))
  e.buf.caret = p
  extend || (e.buf.anchor = p)
  touch!(e; keep_goal)
end

erase!(e, to::Pos) = begin
  b = e.buf
  picked(b) === nothing || return delete_lines!(e)   # the part that the caret is on as a whole goes
  insheet(b, b.caret[1]) && !selecting(b) && erase_row!(e, to) && return
  cell = cellat(b, b.caret)
  # In a table, a cell's edges can't be deleted
  cell === nothing || selecting(b) || (to[1] == b.caret[1] && within(cell, to[2])) || return
  selecting(b) || (b.anchor = to)
  type!(e, "")
end

"Return starts a new line. What else it does depends on the block the caret is in."
newline!(e) = begin
  b = e.buf
  picked(b) === nothing || return enter_part!(e)   # Return gives the keyboard to the part that the caret is on
  insheet(b, b.caret[1]) && b.caret[1] == b.anchor[1] && return next_row!(e)
  isempty(rowcells(b, b.caret)) || return next_cell!(e, false, down=true)
  selecting(b) ? type!(e, "\n") : newline!(e, block(b, b.caret[1]))
end

newline!(e, block) = begin
  b = e.buf
  i, col = b.caret
  if rich(b) && kinds(b)[i].kind == Kind.heading && col <= first_stop(b, i) < length(b.lines[i])
    # As rich text, Return at the start of a heading's text moves the heading down a line
    edit!(b, (i, 0), (i, 0), "\n")
    b.caret = b.anchor = (i + 1, col)
    return touch!(e)
  end
  shut, opened = halves!(b)
  type!(e, shut * "\n" * opened)
end

# In a list or a quote, the new line carries it on
newline!(e, ::Type{<:Union{List,Quote,Paragraph}}) = begin
  b = e.buf
  i, col = b.caret
  text, line = b.lines[i], kinds(b)[i]
  k = line.kind
  col < line.prefix && return type!(e, "\n")
  lead = head(text, line.prefix)
  # The line after the one that names a callout is a line of the callout: it starts with the > and no more
  if opens_callout(line)
    shut, opened = halves!(b)
    return type!(e, shut * "\n> " * opened)
  end
  # Return on an empty list item ends the list
  # What starts the item goes as it's written. As rich text, a selection that's
  # deleted keeps what starts its line, so `type!` would leave the item there.
  if length(text) == line.prefix && k != Kind.paragraph
    edit!(b, (i, 0), (i, line.prefix), "")
    return touch!(e)
  end
  # As rich text, bold text that the new line cuts in two is bold on both lines
  shut, opened = halves!(b)
  type!(e, shut * "\n" * carry(lead, k) * opened)
end

"What starts the line after a list item or a quote that starts with `lead`: the next number, or a to-do box with no tick"
carry(lead, k::Kind) = begin
  k == Kind.todo && return replace(lead, r"\[[xX]\]" => "[ ]")
  m = k == Kind.ordered ? match(r"^(\s*)(\d+)(.*)$", lead) : nothing
  m === nothing ? lead : string(m[1], parse(Int, m[2]) + 1, m[3])
end

# In code, the new line starts under the text of the line before. It starts
# one step further in after a line that opens a block.
newline!(e, ::Type{CodeBlock}) = begin
  b = e.buf
  i, col = b.caret
  line = kinds(b)[i]
  if line.kind == Kind.fence && line.level == 0 && line.lang == SHEET && col == length(b.lines[i])
    # The line that opens a sheet. Its first row starts with a place for a name.
    type!(e, "\n = ")
    b.caret = b.anchor = (i + 1, 0)
    return touch!(e)
  end
  if line.kind == Kind.fence && line.level == 0 && line.lang == SPREADSHEET && col == length(b.lines[i])
    # The line that opens a spreadsheet. Its first row starts with three cells, and the caret goes to the first.
    type!(e, "\n|  |  |  |")
    b.caret = b.anchor = (i + 1, 2)
    return touch!(e)
  end
  line.kind == Kind.fence && return type!(e, "\n")
  before = head(b.lines[i], col)
  type!(e, "\n" * match(r"^ *", before).match * (opens(before, line.lang) ? indentation(e, CodeBlock) : ""))
end

const OPENERS = r"^\s*(function|if|elseif|else|for|while|let|try|catch|finally|struct|mutable struct|module|macro|quote)\b"

"True when a line of code that ends with `text` opens a block, so the next line goes further in"
opens(text::AbstractString, lang::AbstractString) = begin
  s = rstrip(text)
  isempty(s) && return false
  last(s) in "([{" && return true
  lowercase(lang) in ("python", "py") && return last(s) == ':'
  lowercase(lang) in ("julia", "jl", LIVE, RESULT) || return false
  occursin(r"\b(begin|do( [\w, ]+)?)$", s) || (occursin(OPENERS, s) && !occursin(r"\bend$", s))
end

"Where backspace deletes back to from the caret: one character, or one step of `n` of the spaces that start a line"
backstep(b::Buffer, block, n=length(STEP)) = begin
  i, col = b.caret
  indented = col > 0 && !selecting(b) && all(==(' '), head(b.lines[i], col))
  indented ? (i, col - (col - 1) % n - 1) : beside(b, b.caret, -1)
end

# In a table the spaces belong to a cell
backstep(b::Buffer, ::Type{Table}, n=0) = beside(b, b.caret, -1)

# In code, a bracket that you type comes with the bracket that closes it, and
# the caret stays between the two. A quote comes with the quote that ends the
# string. This is so in a file of code and in a code block of a page.
#
#   - The closing one only comes where it can't join a word: at the end of the
#     line, or before a space, a comma or another closing bracket.
#   - A closing bracket or a quote that you type where the same one already is
#     goes over that one. So `f(x)` typed one key after another is `f(x)`.
#   - With text selected, a bracket or a quote goes round the text, and the
#     text stays selected.
#   - A quote that's typed in a string ends the string, and comes alone. A ' after
#     a name is Julia's transpose, or the ' of a word like "don't", and comes alone too.
#   - A third quote after two makes the six quotes of a string of several lines.
#   - ⌫ between the two of a pair that has nothing in it takes both away.

const PAIRS = Dict('(' => ')', '[' => ']', '{' => '}', '"' => '"', '\'' => '\'')
const CLOSING = Set(values(PAIRS))

"True when line `i` is code that's typed as text. A row of a sheet or a spreadsheet is typed as a cell."
typed_code(b::Buffer, i::Int) = (k = kinds(b)[i]; k.kind == Kind.code && k.lang != CELL_LANG && !insheet(b, i) && !inspread(b, i))

"How many quotes in `text` start or end a string. One after a \\ is a character of its string."
quotes(text::AbstractString) = count(r"(?<!\\)\"", text)

"True when line `i` up to `before` is inside a string of several lines: an odd number of \"\"\" come before it in its code"
in_long_string(b::Buffer, i::Int, before::AbstractString) = begin
  top = b.view == :code ? 1 : codeblock(b, i)[1] + 1
  isodd(sum(l -> count("\"\"\"", l), @view(b.lines[top:i-1]), init=0) + count("\"\"\"", before))
end

"""
Type the character `c` at the caret, as code does: a bracket or a quote comes
with the one that closes it. It returns false, and types nothing, where `c` is
typed as any other character is.
"""
pair!(e, c::Char) = begin
  b = e.buf
  picked(b) === nothing || return false
  lo, hi = minmax(b.caret, b.anchor)
  all(i -> typed_code(b, i), lo[1]:hi[1]) || return false
  close = get(PAIRS, c, nothing)
  if lo != hi
    # A bracket or a quote goes round the text that's selected, and the text stays selected
    close === nothing && return false
    back = b.caret < b.anchor
    edit!(b, lo, hi, c * excerpt(b, lo, hi) * close)
    from, to = (lo[1], lo[2] + 1), (hi[1], hi[2] + (lo[1] == hi[1]))
    b.anchor, b.caret = back ? (to, from) : (from, to)
    touch!(e)
    return true
  end
  i, col = lo
  before, after = head(b.lines[i], col), rest(b.lines[i], col)
  next = isempty(after) ? nothing : first(after)
  if next == c && c in CLOSING
    # The one that closes is already here, so the caret goes over it
    b.caret = b.anchor = (i, col + 1)
    touch!(e)
    return true
  end
  close === nothing && return false
  # Before a word, the one that closes would have to be moved to the word's end by hand
  roomy = next === nothing || isspace(next) || next in ")]},;:" || (c in "([{" && next == '"')
  roomy || return false
  if c == '"' && endswith(before, "\"\"") && !endswith(before, "\"\"\"")
    # The third quote of three. It starts a string of several lines, or it ends the one that the caret is in.
    in_long_string(b, i, chop(before, tail=2)) && return false
    close = "\"\"\""
  elseif c == '"'
    isodd(quotes(before)) && return false   # this quote ends a string
  elseif c == '\'' && !isempty(before)
    prev = last(before)
    (isnamechar(prev) || prev in ")]}'") && return false
  end
  edit!(b, lo, lo, c * close, typing=true)
  b.caret = b.anchor = (i, col + 1)
  touch!(e)
  true
end

"True when the caret is in code between a bracket or a quote and the one that closes it, with nothing between them"
in_empty_pair(b::Buffer) = begin
  i, col = b.caret
  line = b.lines[i]
  (!selecting(b) && 0 < col < length(line) && typed_code(b, i)) || return false
  at = nextind(line, 0, col)
  get(PAIRS, line[at], nothing) == line[nextind(line, at)]
end

# In code, the two brackets that the caret is between glow: the nearest ( [
# or { before the caret that's still open there, and the bracket that closes
# it. The two can be on different lines. Each has a soft light in its own
# shape, in the colour of a link, and two that touch have one light.
#
#   - A bracket in a string or a comment isn't one of the code's brackets. With
#     the caret in a string or a comment, the brackets are the ones in the
#     strings or the comments of the caret's line.
#   - A bracket that's closed by another kind of bracket doesn't glow.
#   - Nothing glows while text is selected.

const PAIR_REACH = 2000   # lines. A bracket that's further from the caret than this isn't looked for.
const OPENING, ENDING = "([{", ")]}"

"What each character of line `i` is a part of: :code, :string or :comment"
parts_of(b::Buffer, i::Int) = begin
  out = Symbol[]
  for t in tokens(b.lines[i], shared_lang(kinds(b)[i].lang))
    append!(out, fill(t.kind in (:string, :comment) ? t.kind : :code, length(t.text)))
  end
  out
end

"""
The places of the two brackets that the caret is between, in code: the one that
opens and the one that closes. Nothing when the caret isn't between two.
"""
bracket_pair(b::Buffer) = begin
  i, col = b.caret
  (!selecting(b) && picked(b) === nothing && typed_code(b, i)) || return nothing
  here = parts_of(b, i)
  col = min(col, length(here))   # a caret that a change left past the end of its line is at the end
  before = col > 0 ? here[col] : :code
  after = col < length(here) ? here[col+1] : before == :comment ? :comment : :code
  # At the edge of a string, the caret is in the code
  part = before == after ? before : :code
  top, bottom = b.view == :code ? (1, length(b.lines)) : codeblock(b, i) .+ (1, -1)
  top, bottom = part == :code ? (max(top, i - PAIR_REACH), min(bottom, i + PAIR_REACH)) : (i, i)
  # The characters of line `l` that are brackets of the caret's part, or nothing when it has none
  brackets(l) = begin
    any(in("()[]{}"), b.lines[l]) || return nothing
    parts = l == i ? here : parts_of(b, l)
    [(k, c) for (k, c) in enumerate(b.lines[l]) if (c in OPENING || c in ENDING) && parts[k] == part]
  end
  open = nothing
  closed = Char[]   # the brackets between the caret and here that close one before here
  for l in i:-1:top
    found = brackets(l)
    found === nothing && continue
    for (k, c) in Iterators.reverse(found)
      l == i && k > col && continue
      if c in ENDING
        push!(closed, c)
      elseif isempty(closed)
        open = (l, k - 1, c)
        break
      elseif closed[end] == PAIRS[c]
        pop!(closed)
      end
    end
    open === nothing || break
  end
  open === nothing && return nothing
  opened = Char[]   # what closes the brackets that open between the caret and here
  for l in i:bottom
    found = brackets(l)
    found === nothing && continue
    for (k, c) in found
      l == i && k <= col && continue
      if c in OPENING
        push!(opened, PAIRS[c])
      elseif isempty(opened)
        return c == PAIRS[open[3]] ? ((open[1], open[2]), (l, k - 1)) : nothing
      elseif opened[end] == c
        pop!(opened)
      end
    end
  end
  nothing
end

"The two brackets that the caret is between. They're looked for once for each place of the caret in each version of the text."
caret_pair(e) = begin
  b = e.buf
  key = (b.path, b.version, b.caret, b.anchor)
  kept = get(e.nodes, :bracket_pair, nothing)
  kept !== nothing && kept[1] == key && return kept[2]
  found = bracket_pair(b)
  e.nodes[:bracket_pair] = (key, found)
  found
end

"""
The runs of text that glow for the two brackets at `found`: the line of each,
and its columns. Two brackets with nothing between them are one run, so they
have one light.
"""
bracket_runs((open, close)) =
  open[1] == close[1] && close[2] == open[2] + 1 ? [(open[1], open[2], open[2] + 2)] : [(i, col, col + 1) for (i, col) in (open, close)]

"""
Make the two brackets that the caret is between glow: a soft light in the shape
of each bracket, and the bracket over it in the light's colour. The page's text
is at `ui`.
"""
glow_bracket_pair(ctx, e, ui) = begin
  b = e.buf
  (caretless(b) || readonly(b)) && return
  w = window_of(e)
  (w !== nothing && w.focus === e) || return   # as the caret does, the light shows while the page has the keyboard
  found = caret_pair(e)
  found === nothing && return
  light, lit = ink(tint(colours.accent, 0.65)), ink(colours.accent)
  blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, 3f0, true)
  Skia.sk_paint_set_maskfilter(light, blur)
  for it in e.layout[e.shown], (i, from, to) in bracket_runs(found)
    f = it.content
    (f isa Flow && it.first == i) || continue
    for (k, vl) in enumerate(f.lines), seg in vl.segs
      lo, hi = max(from, seg.col), min(to, seg.col + seg.n)
      (hi > lo && seg.node === nothing && !seg.atomic) || continue
      words = String(collect(seg.text)[lo-seg.col+1:hi-seg.col])
      x = num(ui.left + seg.x + inset(seg, lo - seg.col))
      # The brackets stand on the line that the text stands on
      y = num(ui.top + it.top + line_top(f, k) + (vl.high + capital(seg.face)) / 2)
      blob = Skia.sk_textblob_make_from_string(words, skia_font(seg.face.family, seg.face.size, seg.face.style).raw, Skia.SK_TEXT_ENCODING_UTF8)
      # The light is drawn twice, since a bracket is thin
      for paint in (light, light, lit)
        Skia.sk_canvas_draw_text_blob(ctx, blob, Float32(x), Float32(y), paint)
      end
      Skia.sk_textblob_unref(blob)
    end
  end
  Skia.sk_maskfilter_unref(blur)
  Skia.sk_paint_delete(light)
  Skia.sk_paint_delete(lit)
end

"Tab moves text in, and shift-Tab moves it back out. What they move depends on the block the caret is in."
indent!(e, out::Bool) = begin
  b = e.buf
  insheet(b, b.caret[1]) && return sheet_tab!(e, out)
  isempty(rowcells(b, b.caret)) || return next_cell!(e, out)
  indent!(e, out, block(b, b.caret[1]))
end

indent!(e, out::Bool, block) = out ? nothing : type!(e, STEP)

# In code, Tab goes to the next step. With a selection, or with shift, it moves every line the selection touches.
indent!(e, out::Bool, ::Type{CodeBlock}) = begin
  b = e.buf
  tab = indentation(e, CodeBlock)   # as many spaces as the settings page says
  out || selecting(b) || return type!(e, " " ^ (length(tab) - b.caret[2] % length(tab)))
  shift_lines!(e, out, tab, ==(Kind.code))
end

"""
Move each line that the caret or the selection is on in by `step`, or with
`out` back out by as much of `step` as it starts with. Only the lines whose
kind `takes` move, and a line with nothing in it stays as it is.
"""
shift_lines!(e, out::Bool, step::AbstractString, takes) = begin
  b = e.buf
  ends = Dict(:caret => b.caret, :anchor => b.anchor)
  lo, hi = minmax(b.caret, b.anchor)
  for i in lo[1]:hi[1]
    takes(kinds(b)[i].kind) || continue
    n = out ? min(length(step), length(match(r"^ *", b.lines[i]).match)) : length(step)
    (isempty(b.lines[i]) || n == 0) && continue
    edit!(b, (i, 0), (i, out ? n : 0), out ? "" : step)
    for (name, (l, col)) in ends
      l == i && (ends[name] = (i, max(0, col + (out ? -n : n))))
    end
  end
  b.caret, b.anchor = ends[:caret], ends[:anchor]
  touch!(e)
end

"""
What ⌘] and ⌘[ do: they move the lines that the caret or the selection is on
in or out a step, wherever the caret is in the line. In code a step is the
indent that the settings page gives, and in a list it's a level of the list.
"""
indent_lines!(e, out::Bool) = begin
  b = e.buf
  t = block(b, b.caret[1])
  t === CodeBlock ? shift_lines!(e, out, indentation(e, CodeBlock), ==(Kind.code)) :
  t === List ? shift_lines!(e, out, STEP, in((Kind.bullet, Kind.ordered, Kind.todo))) : nothing
end

# ⌘] and ⌘[ have a use only on a page that you can change. On one that you can't, the keys go to another
# command that has them, if code from the startup page added one. See `command_here`.
works_here(e, ::Union{Val{:indent_line},Val{:outdent_line}}) = !readonly(e.buf) && !e.buf.fixed

# In a list, Tab moves the item in and shift-Tab moves it back out
indent!(e, out::Bool, ::Type{List}) = begin
  b = e.buf
  i, col = b.caret
  selecting(b) && return out ? nothing : type!(e, STEP)
  n = out ? min(2, kinds(b)[i].level) : 2
  edit!(b, (i, 0), (i, out ? n : 0), out ? "" : "  ")
  b.caret = b.anchor = (i, max(0, col + (out ? -n : n)))
  touch!(e)
end

"""
Go to the next cell of a table and select what's in it, or with `back` the one
before. With `down`, go to the same cell of the next row. Going on from the end
of the table adds a row.
"""
next_cell!(e, back::Bool; down=false) = begin
  b = e.buf
  i, col = b.caret
  rows = gridrows(b, i)
  r = findfirst(==(i), rows)
  cs = rowcells(b, b.caret)
  c = nearest(cs, col)
  if down
    r += 1
  elseif back
    c -= 1
    c < 1 && (r -= 1; c = 0)
  else
    c += 1
    c > length(cs) && (r += 1; c = 1)
  end
  r < 1 && return
  if r > length(rows)
    t = last(rows)
    edit!(b, line_end(b, t), line_end(b, t), "\n|" * repeat("  |", maximum(i -> length(rowcells(b, (i, 0))), rows)))
    push!(rows, t + 1)
  end
  cs = rowcells(b, (rows[r], 0))
  isempty(cs) && return move!(e, (rows[r], 0), false)
  cell = cs[c == 0 ? length(cs) : min(c, length(cs))]
  b.anchor, b.caret = (rows[r], cell.lo), (rows[r], cell.hi)
  touch!(e)
end

"Put `mark` around the selection, or take it away if it's there already"
surround!(e, mark::String) = begin
  b = e.buf
  picked(b) === nothing || return
  lo, hi = selection(b)
  lo[1] == hi[1] || return
  if rich(b)
    # As rich text, each end of a selection can be on either side of markup that doesn't show. A selection
    # of all the text that `mark` marks is that text, whichever side its ends are on.
    _, ss = richspans(b, lo[1])
    hidden = unseen(b, lo[1])
    for (o, c) in markpairs(ss)
      ss[o].text == mark || continue
      from, to = ss[o].col + length(mark), ss[c].col
      opens = findfirst(r -> r[1] <= ss[o].col && from <= r[2], hidden)
      closes = findfirst(r -> r[1] <= to && to + length(mark) <= r[2], hidden)
      (opens === nothing || closes === nothing) && continue
      hidden[opens][1] <= lo[2] <= hidden[opens][2] && hidden[closes][1] <= hi[2] <= hidden[closes][2] || continue
      lo, hi = (lo[1], from), (hi[1], to)
      break
    end
  end
  i, n = lo[1], length(mark)
  line = b.lines[i]
  inner = rest(head(line, hi[2]), lo[2])
  if lo[2] >= n && rest(head(line, lo[2]), lo[2] - n) == mark && head(rest(line, hi[2]), n) == mark
    edit!(b, (i, lo[2] - n), (i, hi[2] + n), inner)
    b.anchor, b.caret = (i, lo[2] - n), (i, hi[2] - n)
  else
    edit!(b, lo, hi, mark * inner * mark)
    b.anchor, b.caret = (i, lo[2] + n), (i, hi[2] + n)
  end
  touch!(e)
end

"""
Copy what's selected. With several selections, each one's text goes on a line
of its own, in the order of the page. With none, the part that the caret is on
as a whole, like a board or a picture, is copied as its lines. A whole block
pastes in another page as a part of this one: see "a block that's copied
pastes as a part of its page".
"""
copy_selection!(e) = begin
  b = e.buf
  run = picked(b)
  (selecting(b) || run !== nothing) && write_blocks!(e)   # a block that a file defines is copied as what it holds now
  spans = selecting(b) ? [selection(b)] : Tuple{Pos,Pos}[]
  with_others(() -> selecting(b) && push!(spans, selection(b)), b)
  isempty(spans) && run !== nothing && push!(spans, ((run[1], 0), line_end(b, run[2])))
  isempty(spans) && return false
  text = join((excerpt(b, s...) for s in sort(spans)), "\n")
  copied!(e, length(spans) == 1 ? only(spans) : nothing, text)
  copy_text!(e, text)
end

"""
Put what the clipboard holds into the text at the caret. Files that were
copied in the Finder go in the way a dropped file does: a picture shows as a
picture, and a video, a sound, a PDF or any other file as a path that shows
what's in the file. A picture that was copied as itself, like a screenshot, is
written to a file in the media folder beside the document first. So is a PDF,
a sound or a video that was copied as itself. Anything else is pasted as text.

A file in a folder for temporary files is copied to that media folder,
and the copy is what goes in. An app that takes screenshots puts its picture
on the clipboard as a file like that, and macOS removes the file later.
"""
paste!(e) = begin
  part = agent_part_of(e)
  part !== nothing && part[2] == :field && return paste_for_agent!(part[1], e)
  b = e.buf
  paths = Pasteboard.files()
  if isempty(paths)
    text = Sys.isapple() ? Pasteboard.text() : clipboard()
    # A whole block that was copied from another page goes in as a part of that page
    link = pasted_part(e, text)
    link === nothing || return paste_part!(e, link)
    # A contact that was copied in the Contacts app goes in as a block of contacts
    list = copied_contacts(e, text)
    isempty(list) || return paste_contacts!(e, list)
    # A picture that's copied from a web page comes with its address as text, and the picture is what's wanted
    found = isempty(strip(text)) || occursin(r"^\s*\w+://\S+\s*$", text) ? Pasteboard.media() : nothing
    path = found === nothing ? nothing : keep_pasted(e, found...)
    path === nothing && return each_selection!(() -> type!(e, replace(text, "\r\n" => "\n", '\r' => '\n', '\t' => "  ")), e)
    paths = [path]
  end
  paths = [passing(e, p) ? something(keep_copy(e, p), p) : p for p in paths]
  selecting(b) && type!(e, "")
  put_files!(e, paths, settle(b, b.caret))
end

"The folder for the files that the pages of the folder `dir` make. It's made if it isn't there."
page_media(dir) = begin
  media = joinpath(dir, PAGE_MEDIA)
  # A folder that can't be made leaves the file's own write to say what went wrong
  try mkpath(media) catch end
  media
end

"""
Write `bytes` that were pasted to a new file in the media folder of the
document's folder, and return its path. `ext` is the end of the file's name,
like "png". Nothing if the document has no folder yet.
"""
keep_pasted(e, ext, bytes) = begin
  dir = docdir(e)
  isdir(dir) || return nothing
  path = unused(page_media(dir), "pasted-" * Libc.strftime("%Y%m%d-%H%M%S", time()), ".$ext")
  write(path, bytes)
  list_files!(e)   # a sidebar that shows hidden files lists the media folder, or the new file in it
  path
end

"A path in `dir` that no file has yet: `stem` and `ext`, with a number after the stem if that name is taken"
unused(dir, stem, ext) = begin
  path = joinpath(dir, stem * ext)
  n = 1
  while ispath(path)
    path = joinpath(dir, "$stem-$(n += 1)$ext")
  end
  path
end

"True when the file at `path` is a temporary one, which macOS removes later. A file in the document's own folder is never one."
passing(e, path) = isfile(path) && dirname(path) != docdir(e) && any(p -> startswith(path, p), PASSING)

"""
Copy the file at `path` to the media folder of the document's folder, under
its own name, and return the copy's path. Nothing if the document has no
folder yet.
"""
keep_copy(e, path) = begin
  dir = docdir(e)
  isdir(dir) || return nothing
  copy = unused(page_media(dir), splitext(basename(path))...)
  cp(path, copy)
  list_files!(e)
  copy
end

zoom!(e, z) = (e.zoom = clamp(z, 0.6, 2.5); save_settings!(e); rerun!(e, :zoom); restyle!(e))

"The size of the page's text, to the nearest pixel"
text_size(e) = round(Int, TEXT_SIZE.value * e.zoom)
# The page's text is a whole number of pixels tall, so the settings page can show its size as a number
"The zoom that makes the page's text `size` pixels tall. Sizes are whole numbers from 11 to 42."
zoom_for(size) = clamp(round(Int, size), 11, 42) / TEXT_SIZE.value

"The one after `x` in `list`, going back to the start after the last"
after(list, x) = list[mod1(findfirst(==(x), list) + 1, length(list))]

const SLIDE_TIME = 0.25   # seconds for the sidebar to slide in or out

"""
Show the sidebar if it's hidden, or hide it. It slides from where it is now.
In agent mode it's at the left of the agent's pane, and the window grows by
its width where the screen has room: see `sidebar_room!`.
"""
toggle_panel!(e) = begin
  e.slid_from = opened(e)
  e.slid = time()
  e.panel = !e.panel
  agent_shows(e) && sidebar_room!(e)
  e.panel
end

"""
In agent mode, make the window of `e` wider by the sidebar's width as the
sidebar opens, at the window's left edge. So the agent's pane and the page's
card keep their widths, and they stay where they are on the screen, as far
as the screen allows. As the sidebar closes, the window gives back what it
grew by. The sidebar is then there or gone at once, with no slide, as the
window's new size is. A window that can't grow, like one that fills a
screen, stays as it is: there the pane and the card give the sidebar its room.
"""
sidebar_room!(e) = begin
  w = window_of(e)
  (w === nothing || e.full_screen) && return nothing
  wide, tall = w.size
  x, y = w.position
  if e.panel
    screen = w.screen
    grow = px(round(num(clamp(screen.size[1] - wide, 0px, clamp(e.side, PANEL_MIN, PANEL_MAX)))))
    grow > 0px || return nothing
    left = px(round(num(clamp(x - grow, screen.position[1], max(screen.position[1], screen.position[1] + screen.size[1] - wide - grow)))))
    e.nodes[:sidebar_grew] = (grew=grow, moved=left - x)
    w.position = typeof(w.position)(left, y)
    w.size = typeof(w.size)(wide + grow, tall)
  else
    was = pop!(e.nodes, :sidebar_grew, nothing)
    was === nothing && return nothing
    w.size = typeof(w.size)(max(wide - was.grew, 400px), tall)
    w.position = typeof(w.position)(x - was.moved, y)
  end
  e.slid = 0.0
  empty!(e.flows)   # the page's text is as wide as its new place allows
  nothing
end

sliding(e) = time() - e.slid < SLIDE_TIME

"How far a slide from `from` to `to` that started at the time `at` has gone. It takes `take` seconds."
eased(from, to, at; take=SLIDE_TIME) = begin
  t = (time() - at) / take
  t < 1 || return to
  t = t < 0.5 ? 4t^3 : 1 - (2 - 2t)^3 / 2   # slow at the start and the end
  from + (to - from) * t
end

"How far the sidebar is open, from 0 to 1"
opened(e) = eased(e.slid_from, e.panel ? 1.0 : 0.0, e.slid)

# --- the panel at the right ---------------------------------------------------------------
#
# A page of a kind that has one shows a panel at the right of the window, as
# the page of a repository shows what git says beside the repository's files:
# see `page_side`. The button at the right end of the top bar hides the panel,
# and shows it again. It slides as the sidebar does. Whether it shows is a
# setting: each window shows it or none does, and so does the next window.

const RIGHT_W = 340px   # how wide the panel at the right is, in a window that has room for it

"When the panel at the right last started to slide in or out, and how far open it was then, from 0 to 1"
right_slid(e) = get(e.nodes, :right_slid, (1.0, 0.0))

"How far the panel at the right is open, from 0 to 1"
right_opened(e) = ((from, at) = right_slid(e); eased(from, e.right ? 1.0 : 0.0, at))

right_sliding(e) = time() - right_slid(e)[2] < SLIDE_TIME

"Show or hide the panel at the right of the page, like git's panel beside a repository's files. Each window does the same."
toggle_right!(e) = (e.nodes[:right_slid] = (right_opened(e), time()); e.right = !e.right; save_settings!(e); e)

"How wide the panel at the right is when it's open. A narrow window makes it narrower, so the page keeps room beside it."
right_w(e) = begin
  w, _ = window_size(e)
  # The outline of agent mode is narrower than a panel, and a narrow window makes it narrower still
  agent_shows(e) && return px(round(num(min(OUTLINE_W, w * 0.22))))
  left = lowered(e) === nothing ? side_w(e) : 0px
  px(round(num(clamp((w - left) * 0.4, 200px, RIGHT_W))))
end

"""
What the panel at the right shows for the page, or nothing when the page has
no panel: see `page_side`. In agent mode it's the page's outline, for a page
that shows a thing that has an outline, even an empty one: see
`page_outline`. A page of another kind, like a design, has none, so the card
has the room.
"""
right_view(e) = begin
  (filled(e) || as_app(e) || nofile(e)) && return nothing
  agent_shows(e) && return page_outline(e) === nothing ? nothing : node!(OutlinePane, e, :outline_pane)
  o = page_object(e)
  o === nothing ? nothing : page_side(e, o)
end

"""
The panel at the right of the window, while the page has one. It keeps its
width as it slides in and out from the right edge, so only its left part
shows while it's partly out.
"""
right_panel(e) = begin
  shows = right_opened(e)
  shows > 0 || return ()
  own = right_view(e)
  own === nothing && return ()
  right_sliding(e) && redraw_in!(e, 0)
  wide = right_w(e)
  # In agent mode the window's glass shows behind the outline, as it does behind the agent's pane
  glassy = agent_shows(e)
  (Row(fixed(wide * shows), height(grow=grow), Alignment.Start, clip=true,
     Column(fixed(wide), height(grow=grow), Alignment.Start, background(glassy ? clear : colours.panel), name="Side",
            border(glassy ? 0px : 1px, :solid, colours.line)[:left],
       Box(width(grow=grow), height(max(above_page(e), SIDE_GAP))),   # under the top bar
       own)),)
end

"What the button that hides the panel at the right calls the panel of `o`"
side_name(e, o) = "the panel"

"The button at the right end of the top bar that hides the panel at the right and shows it, while the page has a panel"
right_part(e) = right_view(e) === nothing ? () : (button(e, :right_panel, "layout-sidebar-reverse"),)

"""
Notice when the window starts or stops filling a screen of its own, as the
green button makes it do. macOS hides the close, minimise and zoom buttons
then, so the buttons of the top bar slide left into their room. They slide
back when the window leaves full screen.
"""
screen_tick!(e) = begin
  w = window_of(e)
  # A window that isn't on the screen can't fill one. Its setting stays as it is, so a test can set it.
  (w === nothing || isempty(w.glfw)) && return
  on = fills_screen(w)
  on == e.full_screen && return
  e.screened_from = cleared(e)
  e.screened = time()
  e.full_screen = on
end

clearing(e) = time() - e.screened < SLIDE_TIME

"How far the buttons of the top bar have slid into the room of the close, minimise and zoom buttons, from 0 to 1"
cleared(e) = eased(e.screened_from, e.full_screen ? 1.0 : 0.0, e.screened)

const MAC_BUTTONS_W = 84px   # the room at the left of the top bar for the close, minimise and zoom buttons

"""
The room that the top bar leaves at its left for the close, minimise and zoom
buttons. In full screen they're hidden, and it leaves 8px, as it does after
the arrows at the right.
"""
mac_buttons_room(e) = MAC_BUTTONS_W - (MAC_BUTTONS_W - 8px) * cleared(e)

# --- a top bar that hides -------------------------------------------------------------------
#
# The top bar can hide as macOS can hide its menu bar: always, or only while
# the window fills a screen of its own. The page then runs up to the top edge
# of the window. Rest the mouse at that edge
# and the bar slides down over the page, with the Mac's close, minimise and
# zoom buttons. It slides back up a moment after the mouse leaves it, unless a
# list or a menu of the bar is open. ⌘F and a rename of the file bring it out
# too, since what they show hangs from the bar.

const BAR_EDGE = 10px    # how near the top of the window the mouse brings out a top bar that hides
const BAR_WAIT = 0.15    # seconds the mouse rests there first, so a mouse on its way out of the window doesn't bring it out
const BAR_STAYS = 0.3    # seconds the bar stays after the mouse leaves it
const BAR_BELOW = 6px    # how far under the bar the mouse can go before the bar hides
"When the top bar can hide, and the settings page's name for each: always, only while the window fills a screen of its own, or never. macOS gives its menu bar the same choices."
const BAR_HIDINGS = [:always => "Always", :full_screen => "In full screen only", :never => "Never"]

"The settings page's name for `how` the top bar hides"
hiding_name(how) = something(get(Dict(BAR_HIDINGS), how, nothing), "Never")

"How the top bar hides, from its name on the settings page"
hiding_named(name) = (i = findfirst(p -> last(p) == name, BAR_HIDINGS); i === nothing ? :never : first(BAR_HIDINGS[i]))

"""
Hide the top bar until the mouse is at the top of the window: `:always`,
`:full_screen` while the window fills a screen of its own, or `:never`. Each
window does the same.
"""
hide_bar!(e, how::Symbol) = (how in first.(BAR_HIDINGS) && (e.hide_bar = how); save_settings!(e); rerun!(e, :hide_bar); e)

"True when the top bar hides now: always, or while the window fills a screen of its own"
hides_bar(e) = e.hide_bar == :always || (e.hide_bar == :full_screen && e.full_screen)

"How much room the top bar keeps at the top of the window, over the page. A bar that hides keeps none: it shows over the page."
above_page(e) = (hides_bar(e) ? 0px : TOPBAR_H) + (agent_shows(e) ? PAGE_CARD_GAP : 0px)   # in agent mode, the page's card starts a little under the window's top

"When the top bar that hides last started to slide in or out, and how much of it showed then, from 0 to 1"
bar_slid(e) = get(e.nodes, :bar_slid, (1.0, 0.0))

"True when the top bar that hides is out, or sliding out. A new window's bar starts out, and goes when the mouse isn't on it."
bar_out(e) = get(e.nodes, :bar_out, true)

"How much of the top bar shows, from 0 to 1. A bar that doesn't hide always shows."
bar_shown(e) = hides_bar(e) ? ((from, at) = bar_slid(e); eased(from, bar_out(e) ? 1.0 : 0.0, at)) : 1.0

bar_sliding(e) = hides_bar(e) && time() - bar_slid(e)[2] < SLIDE_TIME

"Where the top bar's top is: 0 while the bar shows, and as far above the window as the bar is tall while it hides"
bar_top(e) = px(round(num((bar_shown(e) - 1) * TOPBAR_H)))

"How far down the window the top bar reaches now"
bar_bottom(e) = TOPBAR_H + bar_top(e)

"Start the top bar sliding down into the window, or with `out` false, back up out of it"
slide_bar!(e, out::Bool) = begin
  bar_out(e) == out && return e
  e.nodes[:bar_slid] = (bar_shown(e), time())
  e.nodes[:bar_out] = out
  e
end

"""
Bring out the top bar that hides, or put it away, as the mouse and what's open
ask. The Mac's close, minimise and zoom buttons go with it, and so does a path
pinned in it.
"""
bar_tick!(e) = begin
  w = window_of(e)
  w === nothing && return
  hides_bar(e) || return (fade_window_buttons!(w, 1); nothing)
  if bar_wanted(e, w)
    delete!(e.nodes, :bar_leaving)
    slide_bar!(e, true)
  elseif bar_out(e)
    since = get!(e.nodes, :bar_leaving, time())
    if time() - since >= BAR_STAYS
      delete!(e.nodes, :bar_leaving)
      slide_bar!(e, false)
    else
      redraw_in!(e, BAR_STAYS - (time() - since))
    end
  end
  shown = bar_shown(e)
  fade_window_buttons!(w, shown)
  # A path pinned in the bar shows only with the bar. It opens again once the bar shows: see `title_trail!`.
  shown == 0 && close_popup!(w, :title_trail)
  nothing
end

"""
True when the top bar that hides should show: the mouse has rested at the top
edge of the window, or is still on the bar, or something hangs from the bar.
"""
bar_wanted(e, w) = begin
  # The search that ⌘F opens hangs under the path in the bar, and the file's name is renamed where the bar shows it
  haskey(e.nodes, :search_asked) && return true
  any(p -> p.key == TS_KEY, popups(w)) && return true
  !isempty(e.buf.path) && renaming(e, :title) == e.buf.path && return true
  wide, _ = window_size(e)
  inside(x, y) = 0px <= x < wide && 0px <= y
  if bar_out(e)
    # A list, a menu or a tip that hangs from the bar keeps it. The path pinned in the bar doesn't: it shows whenever the bar does.
    any(p -> p.key != :title_trail && p.anchor[2] < TOPBAR_H, popups(w)) && return true
    # A window hears nothing when the mouse leaves it, so the bar looks where the mouse is for itself
    isempty(w.glfw) || sync_mouse!(w)
    x, y = w.mouse
    on = inside(x, y) && y < TOPBAR_H + BAR_BELOW
    on && !isempty(w.glfw) && redraw_in!(e, 0.2)
    return on
  end
  # A drag that reaches the top of the window, like one that selects lines, doesn't bring the bar out
  at_edge() = begin
    x, y = w.mouse
    inside(x, y) && y < BAR_EDGE && !(Keys.mouse_left in w.keys)
  end
  at_edge() || return (delete!(e.nodes, :bar_rest); false)
  since = get!(e.nodes, :bar_rest, time())
  time() - since < BAR_WAIT && return (redraw_in!(e, BAR_WAIT - (time() - since)); false)
  # The mouse may have gone on out of the window
  isempty(w.glfw) || sync_mouse!(w)
  delete!(e.nodes, :bar_rest)
  at_edge()
end

"""
What the top bar that hides lies on, so the page doesn't show through it: the
colours of the sidebar, the page and the panel at the right, as a bar that
doesn't hide has under it, with a line along its bottom.
"""
bar_back(e) = begin
  tint = bar_tint(e)
  hides = hides_bar(e)
  (hides || tint !== nothing) || return ()
  inpage = crumb_in_page(e)
  if agent_shows(e)
    # Under a bar that doesn't hide is the top of the page's card, which has the web page's colour: see `describe(c::PageCard)`.
    # Over a page that shows the path itself the bar has no middle, so it lies only on the agent's pane.
    (hides && !inpage) || return ()
    # In agent mode only the page's card has a colour of its own, so the bar lies on that
    left, wide = page_card_span(e)
    paper, rule = tint === nothing ? (colours.bg, colours.line) : (tint, tint_colours!(tint).line)
    return (Row(width(grow=grow), height(TOPBAR_H), Alignment.Start, offset_y=bar_top(e), padding(0px, 0px, 0px, left),
              Box(fixed(wide), height(grow=grow), background(paper), border(1px, :solid, rule)[:bottom])),)
  end
  full = filled(e)
  # A side menu that a kind of folder made has no colour of Ladder's over its top
  side = full || lowered(e) !== nothing || as_app(e) || own_side_menu(e) ? 0px : side_w(e)
  right = full || right_view(e) === nothing ? 0px : right_w(e) * right_opened(e)
  line = border(1px, :solid, colours.line)
  # Over a web page the part beside the sidebar has the page's colour. A bar that doesn't hide has no line under it
  # there, so it and the page are one piece. The sidebar and a panel at the right are under a bar that doesn't hide.
  if !hides
    return (Row(width(grow=grow), height(TOPBAR_H), Alignment.Start, offset_y=bar_top(e),
              Box(fixed(side), height(grow=grow)), Box(width(grow=grow), height(grow=grow), background(tint)), Box(fixed(right), height(grow=grow))),)
  end
  # Over a page that shows the path itself the bar is only its left end: over the sidebar, and as far past it as its buttons reach
  inpage && return (Row(fixed(side_w(e) + get(e.nodes, :bar_past_side, 0px)), height(TOPBAR_H), Alignment.Start, offset_y=bar_top(e),
                        background(colours.bg), line[:bottom],
                      (side > 0px ? (Box(fixed(side), height(grow=grow), background(colours.panel), line[:right]),) : ())...),)
  middle = tint === nothing ? () : (background(tint), border(1px, :solid, tint_colours!(tint).line)[:bottom])
  (Row(width(grow=grow), height(TOPBAR_H), Alignment.Start, offset_y=bar_top(e), background(colours.bg), line[:bottom],
     (side > 0px ? (Box(fixed(side), height(grow=grow), background(colours.panel), line[:right]),) : ())...,
     Box(width(grow=grow), height(grow=grow), middle...),
     (right > 0px ? (Box(fixed(right), height(grow=grow), background(colours.panel), line[:left]),) : ())...),)
end

# --- the top bar over a web page ------------------------------------------------------------------
#
# Over a page of HTML the top bar takes the page's colour, as a browser's bar
# does: the colour that the page's `<meta name="theme-color">` says, or else
# the one colour along the top edge of what shows, so it changes as the page
# scrolls past a header. So the bar and the page are one piece. The bar's
# buttons and the file's name have the ink of a theme that shows on that
# colour: the window's own when they show, dark on a light page and light on a
# dark one when they don't. The part of the bar over the sidebar, and over a
# panel at the right, keeps the window's colours. A page with no one colour
# along its top, like one with a picture there, leaves the bar as it was.

"""
The colour of the web page that the window shows, which the top bar takes, or
nothing: before the page shows, for a page with no one colour at its top, for
an HTML file shown as its text, and for any other file. In agent mode the
page lies on a card, and the top of the card and the middle of the bar over
it take the colour.
"""
bar_tint(e) = begin
  (html_shown(e) && !filled(e) && !page_covered(e)) || return nothing
  v = get(e.nodes, (:html, e.buf.path), nothing)
  (v isa HTMLPage && v.browser !== nothing) || return nothing
  b = v.browser
  p, s = b.view.page, Browsers.scrolled(b)
  p === nothing && return nothing
  # The bar asks more than once in each frame, so the colour is kept until the page is laid out again or scrolls
  was = get(e.nodes, :bar_tint, nothing)
  was !== nothing && was[1] === p && was[2] == s && return was[3]
  c = Browsers.tint(b)
  tint = c === nothing ? nothing : RGBA(((c >> 16) & 0xff) / 255, ((c >> 8) & 0xff) / 255, (c & 0xff) / 255, 1.0)
  e.nodes[:bar_tint] = (p, s, tint)
  tint
end

"How light the colour `c` looks, from 0 for black to 1 for white"
how_light(c) = (k = convert(RGBA{Float64}, c); 0.2126k.r + 0.7152k.g + 0.0722k.b)

"The colour `share` of the way from `a` to `b`"
blended(a, b, share) = begin
  x, y = convert(RGBA{Float64}, a), convert(RGBA{Float64}, b)
  RGBA(x.r + (y.r - x.r) * share, x.g + (y.g - x.g) * share, x.b + (y.b - x.b) * share, 1.0)
end

"The colours of the top bar over a web page: see `tint_colours!`"
const TINT_COLOURS = deepcopy(SEPIA)

"""
The colours of the top bar over a web page of the colour `c`. They're the
window's own when its ink shows on `c`, else those of the light or the dark
theme. `c` is behind them, and a button under the mouse or turned on is a
little darker than `c` on a light page and lighter on a dark one.
"""
tint_colours!(c) = begin
  own = colours_over[] === nothing ? colours : PAGE_KEPT
  dark = how_light(c) < 0.5
  base = (how_light(own.bg) < 0.5) == dark ? own : dark ? NIGHT : PAPER
  base === TINT_COLOURS || foreach(n -> setfield!(TINT_COLOURS, n, getfield(base, n)), fieldnames(Palette))
  TINT_COLOURS.bg = c
  TINT_COLOURS.panel = blended(c, base.ink, 0.04)
  TINT_COLOURS.hover = blended(c, base.ink, 0.08)
  TINT_COLOURS.active = blended(c, base.ink, 0.13)
  TINT_COLOURS.line = blended(c, base.ink, 0.15)
  TINT_COLOURS
end

"""
The colours of the top bar's three parts, its left end, its middle and its
right end: each a Palette, or nothing for the page's own. In agent mode the
two ends lie over the dark panes, and the middle over the page's card. Over a
web page the bar has the page's colours, but where an end lies over the
sidebar or a panel at the right.
"""
bar_inks(e) = begin
  tint = bar_tint(e)
  p = tint === nothing ? nothing : tint_colours!(tint)
  agent_shows(e) && return (PANE_COLOURS, p, PANE_COLOURS)
  p === nothing && return (nothing, nothing, nothing)
  (side_w(e) > 0px ? nothing : p, p, right_view(e) !== nothing && right_opened(e) > 0 ? nothing : p)
end

"""
The most of the window's width that the sidebar can have, so the page keeps
room beside it. In agent mode, the agent's pane and the page's card keep
their least widths beside it too.
"""
widest_panel(e) = begin
  wide = window_size(e)[1]
  most = min(PANEL_MAX, px(floor(num(wide) / 2)))
  agent_shows(e) && (most = min(most, wide - AGENT_MIN - PAGE_CARD_NARROWEST - outline_room(e) - 2PAGE_CARD_GAP))
  max(PANEL_MIN, most)
end

"How wide the sidebar is when it's open. A narrow window makes it narrower than you dragged it."
panel_w(e) = min(e.side, widest_panel(e))

"Make the sidebar `w` pixels wide, or as near to that as it can be, and keep the width in the settings"
side!(e, w) = begin
  w = px(round(num(clamp(w, PANEL_MIN, widest_panel(e)))))
  w == e.side && return e
  e.side = w
  save_settings!(e)
  e
end

ismouse(k) = k in (Keys.mouse_left, Keys.mouse_right, Keys.mouse_middle, Keys.mouse_back, Keys.mouse_forward)

# --- key bindings ------------------------------------------------------------------------
#
# Each thing that a key does is a command with a name, like `:save`. A shortcut
# is the keys that run a command: one key with the keys that are held with it,
# like ⌘S, or two of those pressed one after the other, like ⌃X ⌃S. A bundle
# gives every command its shortcuts. Ladder starts with the bundle called
# "Ladder". Each other bundle has the keys of another editor. The key bindings
# page of the settings chooses the bundle, and gives any one command another
# shortcut. The bundle and those changes are settings: every window has the
# same keys, and the settings file keeps them.
#
# A command's kind says where it works:
#   :window  whatever has the keyboard, and on a file that's only shown
#   :look    while the text has the keyboard, and on a file that's only shown as text
#   :edit    while the text has the keyboard. It changes the text.
#   :move    it moves the caret. With ⇧ held too, it grows the selection.
#   :type    it changes the text at the caret, like ⌫. While the page is read it does nothing.
#
# Return, esc and Space have no command. What each does depends on where the caret is.

"A key, and the keys of ⌃, ⌘, ⌥ and ⇧ that are held with it"
struct Stroke
  held::Keys
  key::Keys
end

"The keys that run a command: one stroke, or two that are pressed one after the other"
const Shortcut = Tuple{Vararg{Stroke}}

# The keys that are held with another key: the name that the settings file has for each, and the Mac's sign for it
const HOLDS = ((Keys.ctrl, "ctrl", "⌃"), (Keys.cmd, "cmd", "⌘"), (Keys.opt, "opt", "⌥"), (Keys.shft, "shift", "⇧"))
"Each key that a shortcut can have, by the name that the settings file has for it, like \"z\", \"f5\" or \"pageup\""
const KEY_NAMES = Dict{String,Keys}(lstrip(string(name), '_') => getproperty(Keys, name) for name in keys(instances(Keys))
                                    if !(name in (:shft, :cmd, :opt, :ctrl, :capslock, :fn, :mouse_left, :mouse_right, :mouse_middle, :mouse_back, :mouse_forward)))
const KEY_OF = Dict{Keys,String}(key => name for (name, key) in KEY_NAMES)

"What the key bindings page shows for a key that isn't a letter, a number or an F key"
const KEY_SIGNS = Dict{Keys,String}(
  Keys.enter => "Return", Keys.tab => "Tab", Keys.space => "Space", Keys.backspace => "⌫", Keys.delete => "⌦", Keys.escape => "esc",
  Keys.left => "←", Keys.right => "→", Keys.up => "↑", Keys.down => "↓",
  Keys.home => "Home", Keys._end => "End", Keys.pageup => "Page Up", Keys.pagedown => "Page Down",
  Keys.tilde => "`", Keys.minus => "-", Keys.equal => "=", Keys.left_bracket => "[", Keys.right_bracket => "]", Keys.semicolon => ";",
  Keys.apostrophe => "'", Keys.comma => ",", Keys.period => ".", Keys.slash => "/", Keys.backslash => "\\", Keys.plus => "+", Keys.times => "*")

const TYPING_KEYS = ("tilde", "minus", "equal", "left_bracket", "right_bracket", "semicolon", "apostrophe", "comma", "period", "slash",
                     "backslash", "times", "plus", "space")

"True when the key `K` types a character: a letter, a number or a sign. A shortcut with it needs ⌘, ⌃ or ⌥ too."
typing_key(K) = (name = get(KEY_OF, K, ""); length(name) == 1 || startswith(name, "num") || name in TYPING_KEYS)

"The stroke that `text` writes, like \"cmd+shift+z\", or nothing when it writes none"
read_stroke(text::AbstractString) = begin
  parts = split(text, '+')
  key = get(KEY_NAMES, last(parts), nothing)
  key === nothing && return nothing
  held = Keys(0)
  for part in parts[1:end-1]
    i = findfirst(h -> h[2] == part, HOLDS)
    i === nothing && return nothing
    held |= HOLDS[i][1]
  end
  Stroke(held, key)
end

"The shortcuts that `text` writes, with a comma between them, like \"cmd+z, ctrl+x u\". One that can't be read is left out."
read_shortcuts(text::AbstractString) = begin
  out = Shortcut[]
  for part in split(text, ','; keepempty=false)
    strokes = map(read_stroke, split(part))
    (isempty(strokes) || length(strokes) > 2 || any(isnothing, strokes)) && continue
    push!(out, Tuple(strokes))
  end
  out
end

"How the settings file writes a stroke, a shortcut or a command's shortcuts. `read_shortcuts` reads it back."
written(s::Stroke) = join([[name for (key, name, _) in HOLDS if key in s.held]; KEY_OF[s.key]], '+')
written(s::Shortcut) = join(map(written, s), ' ')
written(list::Vector{Shortcut}) = join(map(written, list), ", ")

"How a stroke or a shortcut reads, like ⌘⇧Z or ⌃X ⌃S"
caps(s::Stroke) = join([sign for (key, _, sign) in HOLDS if key in s.held]) * get(() -> uppercase(KEY_OF[s.key]), KEY_SIGNS, s.key)
caps(s::Shortcut) = join(map(caps, s), ' ')

"""
Something that a key does. `keys` are its shortcuts in the bundle called
Ladder. `run` gets the editor, its window, and true when ⇧ is held to grow
the selection. `call` is the function that the command palette calls, after
it asks for each thing that the function takes. It's nothing for a command
that takes nothing. See "the command palette".
"""
struct Command
  name::Symbol
  title::String   # what the key bindings page calls it
  kind::Symbol
  keys::String
  run::Function
  call::Any
end
Command(name, title, kind, keys, run) = Command(name, title, kind, keys, run, nothing)

"Move the caret one character left or right. With a selection and no ⇧, it goes to that end of the selection."
caret_step!(e, by::Int, select::Bool) = begin
  b = e.buf
  lo, hi = selection(b)
  move!(e, selecting(b) && !select ? (by < 0 ? lo : hi) : beside(b, b.caret, by), select; by)
end

"Move the caret most of a screen up or down"
caret_page!(e, by::Int, select::Bool) = foreach(_ -> move!(e, vertical(e, by), select; keep_goal=true, by), 1:20)

"What ⌫ does: it takes away a row of a table that has nothing in it, or what's before the caret"
erase_back!(e) = begin
  b = e.buf
  picked(b) === nothing || return delete_lines!(e)   # the part that the caret is on as a whole goes
  emptyrow(b) && return backrow!(e)
  erase_start!(e) && return
  if in_empty_pair(b)
    # The bracket that closes goes with the bracket that it came with
    i, col = b.caret
    b.anchor, b.caret = (i, col - 1), (i, col + 1)
    return type!(e, "")
  end
  blk = block(b, b.caret[1])
  erase!(e, backstep(b, blk, length(indentation(e, blk))))
end

"""
What ⌫ does in rich text when the caret is at the start of a line's text. It
returns true when it did it, and false when the caret is somewhere else.

- In a heading, a list item or a quote, it makes the line a paragraph. An item
  of a list inside a list goes out a step first.
- After a part that shows as one thing, like a diagram or a picture, it takes
  away a line with nothing on it. A line with text stays. Either way the caret
  goes onto the part, and ⌫ again takes the part away.
"""
erase_start!(e) = begin
  b = e.buf
  (rich(b) && !selecting(b)) || return false
  i, col = b.caret
  line = kinds(b)[i]
  hidden = unseen(b, i)
  if !isempty(hidden) && first(hidden)[1] < 0 && col <= first(hidden)[2]
    n = line.kind in (Kind.bullet, Kind.ordered, Kind.todo) && line.level >= 2 ? 2 : richspans(b, i)[1]
    edit!(b, (i, 0), (i, n), "")
    b.caret = b.anchor = (i, max(0, col - n))
    touch!(e)
    return true
  end
  at = something(findfirst(r -> r[1] < col <= r[2], hidden), 0)
  (at == 0 ? col : hidden[at][1]) == 0 && i > 1 && !free(b, i - 1, i) || return false
  if isempty(b.lines[i]) && line.kind != Kind.code
    edit!(b, line_end(b, i - 1), (i, 0), "")
    b.caret = b.anchor = settle(b, line_end(b, i - 1), -1, from=(0, 0))
  else
    return (move!(e, line_end(b, i - 1), false, by=-1); true)
  end
  touch!(e)
  true
end

"""
What ⌦ does: it takes away what's after the caret. As rich text, at the end of
a line it joins the next line's text to it, without what starts that line.
"""
erase_next!(e) = begin
  b = e.buf
  picked(b) === nothing || return delete_lines!(e)   # the part that the caret is on as a whole goes
  to = beside(b, b.caret, 1)
  if rich(b) && !selecting(b) && to[1] > b.caret[1]
    j = to[1]
    # The caret goes onto a part that comes next, and ⌦ again takes that part away. It stays before a ``` line.
    free(b, j, b.caret[1]) || return part(b, j) === nothing ? nothing : move!(e, to, false, by=1)
    to = (j, first_stop(b, j))
  end
  erase!(e, to)
end

"Take away the rest of the caret's line. At the end of a line, it joins the next line to it."
erase_line_end!(e) = (b = e.buf; at = line_end(b, b.caret[1]); at == b.caret ? erase_next!(e) : erase!(e, at))

# --- commands for whole lines ---

"The first and last line that the selection touches. A selection that ends at the start of a line doesn't touch that line."
touched(b::Buffer) = begin
  run = picked(b)
  run === nothing || return run   # all the lines of the part that the caret is on as a whole
  lo, hi = minmax(b.caret, b.anchor)
  (lo[1], hi[2] == 0 && hi[1] > lo[1] ? hi[1] - 1 : hi[1])
end

"Put the caret at `caret` and the other end of the selection at `anchor`, each `by` lines further down, after their lines moved"
follow_lines!(e, caret::Pos, anchor::Pos, by::Int) = begin
  b = e.buf
  place((i, col)) = i + by > length(b.lines) ? line_end(b, length(b.lines)) : (max(1, i + by), min(col, length(b.lines[max(1, i + by)])))
  b.caret, b.anchor = place(caret), place(anchor)
  touch!(e)
end

"Take away each line that the selection touches"
delete_lines!(e) = begin
  b = e.buf
  s, t = touched(b)
  col = b.caret[2]
  if t < length(b.lines)
    edit!(b, (s, 0), (t + 1, 0), "")
  elseif s > 1
    edit!(b, line_end(b, s - 1), line_end(b, t), "")
  else
    edit!(b, (1, 0), line_end(b, t), "")
  end
  i = min(s, length(b.lines))
  # The caret comes to the line afresh, so in rich text it isn't left on a line that doesn't show
  b.caret = b.anchor = settle(b, (i, min(col, length(b.lines[i]))), 1, from=(0, 0))
  touch!(e)
end

"Put a copy of the lines that the selection touches under them. The caret goes to the copy."
duplicate_lines!(e) = begin
  b = e.buf
  s, t = touched(b)
  caret, anchor = b.caret, b.anchor
  edit!(b, line_end(b, t), line_end(b, t), "\n" * join(b.lines[s:t], "\n"))
  follow_lines!(e, caret, anchor, t - s + 1)
end

"Move the lines that the selection touches one line up or down"
move_lines!(e, by::Int) = begin
  b = e.buf
  s, t = touched(b)
  caret, anchor = b.caret, b.anchor
  if by < 0
    s > 1 || return
    edit!(b, (s - 1, 0), line_end(b, t), join([b.lines[s:t]; b.lines[s-1]], "\n"))
  else
    t < length(b.lines) || return
    edit!(b, (s, 0), line_end(b, t + 1), join([b.lines[t+1]; b.lines[s:t]], "\n"))
  end
  follow_lines!(e, caret, anchor, by)
end

"Select the whole of the caret's line. With a selection, it grows to the end of its last line. Again, it takes the next line too."
select_lines!(e) = begin
  b = e.buf
  lo, hi = minmax(b.caret, b.anchor)
  b.anchor = (lo[1], 0)
  move!(e, hi[1] < length(b.lines) ? (hi[1] + 1, 0) : line_end(b, hi[1]), true; by=1)
end

"""
Do `f` at each selection: at the main one, then at each of the others with it
in the main one's place. An edit that one of them makes moves the ones after
it, and one ⌘Z takes back what they all did.
"""
each_selection!(f, e) = begin
  b = e.buf
  n = length(others(b))
  (n == 0 || b.many) && return f()
  undos = length(b.undo)
  b.many = true
  try
    for _ in 0:n
      f()
      # The main selection goes to the back of the queue, and the next one takes its place
      push!(b.others, (b.anchor, b.caret))
      b.anchor, b.caret = popfirst!(b.others)
    end
  finally
    b.many = false
  end
  length(b.undo) > undos + 1 && resize!(b.undo, undos + 1)
  # Two selections that came to the same place are one
  kept = Tuple{Pos,Pos}[]
  for s in b.others
    clash(s, (b.anchor, b.caret)) || any(k -> clash(s, k), kept) || push!(kept, s)
  end
  b.others = kept
  keep_others!(b)
  nothing
end

"Do `f` with each of the other selections in the main one's place, then put the main one back. It's for drawing them."
with_others(f, b::Buffer) = begin
  list = copy(others(b))
  isempty(list) && return
  main, many = (b.anchor, b.caret), b.many
  b.many = true
  try
    for s in list
      b.anchor, b.caret = s
      f()
    end
  finally
    b.anchor, b.caret = main
    b.many = many
  end
end

"The columns of each place in `line` that has `text`. With `whole`, only where it's a word by itself."
places(line::AbstractString, text::AbstractString, whole::Bool) = begin
  out = Tuple{Int,Int}[]
  at = firstindex(line)
  while (r = findnext(text, line, at)) !== nothing
    before, after = prevind(line, first(r)), nextind(line, last(r))
    if whole && ((before >= 1 && isword(line[before])) || (after <= ncodeunits(line) && isword(line[after])))
      at = nextind(line, first(r))
      continue
    end
    lo = length(line, 1, before)
    push!(out, (lo, lo + length(text)))
    at = after
  end
  out
end

"""
Select the next place that has the text of the selection as well, and go to
it. After the end of the page it looks from the top. Text that is one word is
found only where it's a word by itself. A live block's own text isn't looked at.
"""
select_next!(e) = begin
  b = e.buf
  lo, hi = selection(b)
  (lo != hi && lo[1] == hi[1]) || return
  text = excerpt(b, lo, hi)
  whole = all(isword, text)
  taken = [(b.anchor, b.caret); others(b)]
  found = [((i, from), (i, to)) for i in eachindex(b.lines) for (from, to) in places(b.lines[i], text, whole)]
  for s in [filter(s -> s[1] >= hi, found); filter(s -> s[1] < lo, found)]
    (any(t -> clash(s, t), taken) || item(e, s[1][1]).content isa Live) && continue
    push!(b.others, (b.anchor, b.caret))
    b.anchor, b.caret = s
    keep_others!(b)
    return
  end
end

"""
Select the word that the caret is in or beside. With a selection, each end of
it goes out to the edge of the word that it's in. With whole words selected
already, the next place that has the same text is selected as well, so what's
typed next goes in at each of them. With no word at the caret, nothing changes.

The selection that was there first stays first in `others`, so Escape can go
back to it.
"""
select_word!(e) = begin
  b = e.buf
  grew = Ref(false)
  each_selection!(e) do
    lo, hi = selection(b)
    from = (lo[1], word_at(b.lines[lo[1]], lo[2])[1])
    to = (hi[1], word_at(b.lines[hi[1]], hi[2])[2])
    (from, to) == (lo, hi) && return
    b.anchor, b.caret = from, to
    grew[] = true
  end
  grew[] || select_next!(e)
  touch!(e)
end

"What starts a comment in each language of code, by the language's name or the end of its file's name"
const COMMENT_MARKS = Dict{String,String}(
  (lang => "#" for lang in ("jl", "julia", "ui", "py", "python", "rb", "ruby", "sh", "bash", "zsh", "fish", "toml", "yaml", "yml", "r", "perl", "pl", "make", "dockerfile"))...,
  (lang => "//" for lang in ("js", "javascript", "jsx", "ts", "typescript", "tsx", "c", "h", "cpp", "hpp", "cc", "java", "swift", "rs", "rust", "go", "kt", "kotlin",
                             "scala", "cs", "php", "dart", "zig"))...,
  (lang => "--" for lang in ("lua", "sql", "hs", "haskell", "elm"))...,
  (lang => ";" for lang in ("lisp", "el", "clj", "clojure", "scm", "scheme"))...,
  (lang => "%" for lang in ("tex", "latex", MATH, "erl", "erlang"))..., "mermaid" => "%%")

"""
Make a comment of each line of code that the selection touches, or make code
of them again if each is a comment already. A line with nothing on it stays
as it is. Outside code, where a comment has no mark, nothing changes.
"""
toggle_comment!(e) = begin
  b = e.buf
  picked(b) === nothing || return
  s, t = touched(b)
  ks = kinds(b)
  lines = [i for i in s:t if ks[i].kind == Kind.code && !isempty(strip(b.lines[i]))]
  isempty(lines) && return
  mark = get(COMMENT_MARKS, lowercase(ks[first(lines)].lang), nothing)
  mark === nothing && return
  indent(i) = length(b.lines[i]) - length(lstrip(b.lines[i]))
  on = all(i -> startswith(lstrip(b.lines[i]), mark), lines)
  at = minimum(indent, lines)   # every mark goes at the indent of the line that's furthest out
  ends = Dict(:caret => b.caret, :anchor => b.anchor)
  new = b.lines[s:t]
  for i in lines
    line = b.lines[i]
    from = on ? indent(i) : at
    # A comment's mark has a space after it, which goes with the mark
    n = !on ? length(mark) + 1 : length(mark) + (startswith(rest(line, from + length(mark)), " ") ? 1 : 0)
    new[i-s+1] = on ? head(line, from) * rest(line, from + n) : head(line, from) * mark * " " * rest(line, from)
    for (name, (l, col)) in ends
      l == i && (ends[name] = (i, on ? (col > from ? max(from, col - n) : col) : (col >= from ? col + n : col)))
    end
  end
  # One change, so one ⌘Z puts every line back
  edit!(b, (s, 0), line_end(b, t), join(new, "\n"))
  b.caret, b.anchor = ends[:caret], ends[:anchor]
  touch!(e)
end

# ⌃↑ and ⌃↓ change the value at the caret a step. A number goes a step bigger or smaller, as a drag on a
# sum does: a step is one of its last digit. Unlike a drag, ⌃↓ takes a number under 0. true and false swap,
# with either key. Any other word goes up from small letters, to a capital at its front, to all capitals,
# and ⌃↓ takes it back down. The value can be anywhere in the text: in a sum, in a sheet, in code, in a
# date or a time. Presses one after another are taken back by one ⌘Z.

"""
Where the number is that the column `col` of `line` is in, or at either end
of: the columns that it runs from and to. Nothing when no digit touches the
column. A number has digits, and can have a dot and more digits after them,
like 2.40. Digits with a dot on each side, like the parts of 1.2.3, are each a
number of their own. A - just before the digits is the number's sign, unless a
letter, a digit or a bracket comes before it, like the - of x-1 or of 2026-11-21.
"""
caret_number(line::AbstractString, col::Int) = begin
  c = collect(line)
  n = length(c)
  digit(i) = 1 <= i <= n && isdigit(c[i])
  at = digit(col + 1) ? col + 1 : digit(col) ? col : col < n && c[col+1] == '-' && digit(col + 2) ? col + 2 : 0
  at == 0 && return nothing
  lo = hi = at                      # the first and the last of the number's characters, from 1
  while digit(lo - 1) lo -= 1 end
  while digit(hi + 1) hi += 1 end
  run = (lo, hi)
  # Digits, a dot and digits are one number
  if lo > 2 && c[lo-1] == '.' && digit(lo - 2)
    lo -= 2
    while digit(lo - 1) lo -= 1 end
  elseif hi < n - 1 && c[hi+1] == '.' && digit(hi + 2)
    hi += 2
    while digit(hi + 1) hi += 1 end
  end
  # With a dot more at either end, it's a list of numbers, like 1.2.3 or 192.168.0.1, and the caret's is one of them
  dotted(i, j) = (i >= 2 && c[i-1] == '.' && digit(i - 2)) || (j < n && c[j+1] == '.' && digit(j + 2))
  (lo, hi) != run && dotted(lo, hi) && ((lo, hi) = run)
  lo >= 2 && c[lo-1] == '-' && !(lo >= 3 && (isletter(c[lo-2]) || isdigit(c[lo-2]) || c[lo-2] in ")]}_")) && (lo -= 1)
  # The caret was before a - that isn't a sign, like the one of x|-1
  lo - 1 <= col || return nothing
  (lo - 1, hi)
end

"""
The number that `text` writes, `steps` steps on. A step is one of its last
digit: 16 goes to 17, 2.40 to 2.41, and 0 to -1 after a step back. It has as
many digits after its dot as before, and a number with a 0 at its front keeps
its width, so 09 goes to 10 and 007 to 008.
"""
number_plus(text::AbstractString, steps::Int) = begin
  neg = startswith(text, '-')
  body = neg ? text[2:end] : text
  dot = findfirst('.', body)
  places = dot === nothing ? 0 : length(body) - dot
  whole = dot === nothing ? body : body[1:dot-1]
  digits = replace(body, "." => "")
  # In whole numbers, so that 2.4 and a step of 0.01 don't make 2.4099999
  v = parse(BigInt, digits) * (neg ? -1 : 1) + steps
  wide = length(whole) > 1 && startswith(whole, '0') ? length(digits) : places + 1
  s = lpad(string(abs(v)), wide, '0')
  places > 0 && (s = s[1:end-places] * "." * s[end-places+1:end])
  v < 0 ? "-" * s : s
end

"""
Where the word is that the column `col` of `line` is in, or at either end of:
the columns that it runs from and to. A word has letters, digits and _, and an
apostrophe between two letters, like don't. Nothing when no word touches the column.
"""
caret_word(line::AbstractString, col::Int) = begin
  c = collect(line)
  n = length(c)
  inword(i) = 1 <= i <= n && (isletter(c[i]) || isdigit(c[i]) || c[i] == '_' ||
                              (c[i] in "'’" && 1 < i < n && isletter(c[i-1]) && isletter(c[i+1])))
  lo = hi = col
  while inword(lo) lo -= 1 end
  while inword(hi + 1) hi += 1 end
  lo == hi ? nothing : (lo, hi)
end

"""
The word `w` a step up, or a step down when `up` is false. It's `w` itself
when it can't go further. true and false swap, and so do True and False, and
TRUE and FALSE. Any other word goes up from small letters, to a capital at its
front, to all capitals: word, Word, WORD. A step down goes back: WORD, Word, word.
"""
word_step(w::AbstractString, up::Bool) = begin
  low = lowercase(w)
  if low in ("true", "false")
    other = low == "true" ? "false" : "true"
    return w == uppercase(w) ? uppercase(other) : isuppercase(first(w)) ? uppercasefirst(other) : other
  end
  c = collect(w)
  letters = findall(isletter, c)
  isempty(letters) && return w
  f = first(letters)
  caps = all(i -> isuppercase(c[i]), letters)
  if up
    !isuppercase(c[f]) ? (c[f] = uppercase(c[f])) : caps || (c = collect(uppercase(w)))
  else
    caps && length(letters) > 1 ? (c = collect(lowercase(w)); c[f] = uppercase(c[f])) : isuppercase(c[f]) && (c[f] = lowercase(c[f]))
  end
  String(c)
end

"""
The value at the column `col` of `line`, `steps` steps on: the columns that it
runs from and to, and its new text. It's the number that the column is in or at,
or else the word. A word with digits, like 16m or h1, is its number, so the
caret can be after the unit of 16m. Nothing when there's no value there, or
when it can't go further.
"""
caret_value(line::AbstractString, col::Int, steps::Int) = begin
  at = caret_number(line, col)
  w = caret_word(line, col)
  if at === nothing && w !== nothing
    # The digit in the word that's nearest the caret, before it or else after it
    c = collect(line)
    lo, hi = w
    before = findlast(isdigit, c[lo+1:col])
    after = findfirst(isdigit, c[col+1:hi])
    at = before !== nothing ? caret_number(line, lo + before) : after !== nothing ? caret_number(line, col + after - 1) : nothing
  end
  at === nothing || return (at..., number_plus(rest(head(line, at[2]), at[1]), steps))
  w === nothing && return nothing
  word = rest(head(line, w[2]), w[1])
  new = word_step(word, steps > 0)
  new == word ? nothing : (w..., new)
end

"Make the value at the caret `steps` steps bigger, or smaller for steps under 0. See `caret_value`. The caret and the selection stay with their text."
step_value!(e, steps::Int) = begin
  b = e.buf
  (readonly(b) || b.fixed) && return
  i, col = b.caret
  found = caret_value(b.lines[i], col, steps)
  found === nothing && return
  lo, hi, new = found
  caret, anchor = b.caret, b.anchor
  # A press right after a press, with no other change between them, is taken back with it
  b.typed = get(e.nodes, :value_stepped, -1) == b.version ? time() : 0.0
  edit!(b, (i, lo), (i, hi), new, typing=true)
  b.typed = 0.0   # and what's typed after it is taken back by itself
  e.nodes[:value_stepped] = b.version
  # A place in the number stays as far from its end as it was, so the caret at the end of 9 is at the end of 10
  by = length(new) - (hi - lo)
  kept(p) = p[1] != i || p[2] <= lo ? p : (i, max(lo, p[2] + by))
  b.caret, b.anchor = kept(caret), kept(anchor)
  touch!(e)
end

"""
Each command that `add_commands!` added, with the name of its group, in the
order that they came. A hot reload makes `COMMAND_GROUPS` again when a name
in it changes, and doesn't call `add_command!` again further down the file.
So the list takes these back in: see `with_added`.
"""
const ADDED_COMMANDS = Pair{String,Command}[]

"""
Put each of `commands` in the group of `groups` called `group`, at the end,
or in the place of the one that has its name. A group that isn't there yet
comes last.
"""
put_commands!(groups, group::AbstractString, commands) = begin
  i = findfirst(g -> first(g) == group, groups)
  i === nothing && (push!(groups, String(group) => Command[]); i = length(groups))
  list = last(groups[i])
  for c in commands
    k = findfirst(o -> o.name == c.name, list)
    k === nothing ? push!(list, c) : (list[k] = c)
  end
  groups
end

"`groups` with each command that `add_commands!` added put back in its group"
with_added(groups) = (foreach(((group, c),) -> put_commands!(groups, group, (c,)), ADDED_COMMANDS); groups)

"""
The commands, in the groups and the order that the key bindings page shows
them. Each has its shortcuts in the bundle called Ladder.
"""
const COMMAND_GROUPS = with_added([
  "Files and windows" => [
    Command(:save, "Save the file", :window, "cmd+s", (e, w, _) -> save_page!(e)),
    Command(:new_window, "Open a new window on the folder that you're in", :window, "cmd+n", (e, w, _) -> new_window!(e)),
    Command(:open, "Find a file by name", :window, "cmd+o", (e, w, _) -> open_finder!(e)),
    Command(:open_project, "Find a project by name and open it", :window, "cmd+p", (e, w, _) -> open_projects!(e)),
    Command(:home, "Open your home folder in the page", :window, "cmd+shift+h", (e, w, _) -> go_home!(e)),
    Command(:commands, "Show the command palette, to run a command by its name", :window, "cmd+shift+p", (e, w, _) -> toggle_palette!(e)),
    Command(:back, "Go back to the line or the file that showed before", :window, "cmd+opt+left", (e, w, _) -> go_back!(e)),
    Command(:forward, "Go forward again, to the line or the file that you went back from", :window, "cmd+opt+right", (e, w, _) -> go_forward!(e)),
    Command(:print, "Print the page", :window, "cmd+opt+p", (e, w, _) -> print!(e, w)),
    Command(:export, "Export the page as HTML", :window, "cmd+shift+e", (e, w, _) -> export_html!(e, w)),
    Command(:slides, "Show the page as slides, or as a page again", :window, "ctrl+cmd+shift+p", (e, w, _) -> slides!(e)),
    Command(:close, "Close the file, or the window when it shows no file", :window, "cmd+w", (e, w, _) -> close_file_or_window!(e, w)),
    Command(:settings, "Show or hide the settings", :window, "cmd+comma", (e, w, _) -> toggle_settings!(e)),
    Command(:sidebar, "Show or hide the sidebar", :window, "cmd+backslash", (e, w, _) -> toggle_panel!(e)),
    Command(:sidebar_keys, "Give the sidebar the keyboard", :window, "cmd+shift+backslash", (e, w, _) -> focus_panel!(e)),
    Command(:plain, "Go down a level in the part that the caret is in, or up again", :window, "cmd+e", (e, w, _) -> level!(e)),
    Command(:hidden_files, "Show or hide the hidden and ignored files in the sidebar", :window, "cmd+shift+period", (e, w, _) -> hidden!(e, !e.hidden)),
    Command(:bigger, "Make the text bigger", :window, "cmd+equal", (e, w, _) -> zoom!(e, zoom_for(text_size(e) + 1))),
    Command(:smaller, "Make the text smaller", :window, "cmd+minus", (e, w, _) -> zoom!(e, zoom_for(text_size(e) - 1))),
    Command(:usual_size, "Put the text back to its usual size", :window, "cmd+0", (e, w, _) -> zoom!(e, 1.0)),
    # The app that's built has no layout inspector
    (BUILDING_APP ? () : (Command(:inspector, "Show or hide the layout inspector", :window, "cmd+opt+i", (e, w, _) -> toggle_inspector!(w)),))...],
  "The text" => [
    Command(:undo, "Undo", :edit, "cmd+z", (e, w, _) -> (undo!(e.buf); touch!(e))),
    Command(:redo, "Redo", :edit, "cmd+shift+z", (e, w, _) -> (redo!(e.buf); touch!(e))),
    Command(:cut, "Cut", :edit, "cmd+x", (e, w, _) -> cut!(e)),
    Command(:copy, "Copy", :look, "cmd+c", (e, w, _) -> copy_selection!(e)),
    Command(:paste, "Paste", :edit, "cmd+v", (e, w, _) -> paste!(e)),
    Command(:select_all, "Select all", :look, "cmd+a", (e, w, _) -> select_all!(e)),
    Command(:select_word, "Select the word at the caret", :look, "cmd+d", (e, w, _) -> select_word!(e)),
    Command(:find, "Find in the page", :look, "cmd+f", (e, w, _) -> find!(e, w)),
    Command(:find_next, "Go to the next place that's found", :look, "cmd+g", (e, w, _) -> find_step!(e, 1)),
    Command(:find_last, "Go to the place that's found before", :look, "cmd+shift+g", (e, w, _) -> find_step!(e, -1)),
    Command(:bold, "Make the selection bold", :edit, "cmd+b", (e, w, _) -> e.buf.view == :markdown && surround!(e, "**")),
    Command(:italic, "Make the selection italic", :edit, "cmd+i", (e, w, _) -> e.buf.view == :markdown && surround!(e, "*")),
    Command(:value_up, "Make the number or the word at the caret a step bigger", :edit, "ctrl+up", (e, w, _) -> step_value!(e, 1)),
    Command(:value_down, "Make the number or the word at the caret a step smaller", :edit, "ctrl+down", (e, w, _) -> step_value!(e, -1)),
    # In a `julia` code block these run the code that the caret is in. Anywhere else, the first sends the page
    # to the agent that waits for it, and with no agent, each starts a new line as Return does.
    Command(:run, "Run the code at the caret, or nudge the agent", :edit, "cmd+enter",
            (e, w, _) -> run_here!(e) || (isempty(agents(e)) ? newline!(e) : send!(e))),
    Command(:run_step, "Run the code at the caret and go to the next line", :type, "shift+enter",
            (e, w, _) -> run_here!(e, step=true) || newline!(e))],
  "Lines" => [
    Command(:select_line, "Select the line", :look, "cmd+shift+l", (e, w, _) -> select_lines!(e)),
    Command(:line_up, "Move the line up", :edit, "cmd+opt+left_bracket", (e, w, _) -> move_lines!(e, -1)),
    Command(:line_down, "Move the line down", :edit, "cmd+opt+right_bracket", (e, w, _) -> move_lines!(e, 1)),
    Command(:duplicate_line, "Copy the line to the line under it", :edit, "cmd+shift+d", (e, w, _) -> duplicate_lines!(e)),
    Command(:delete_line, "Delete the line", :edit, "cmd+shift+k", (e, w, _) -> delete_lines!(e)),
    Command(:comment, "Make a line of code a comment, or code again", :edit, "cmd+slash", (e, w, _) -> toggle_comment!(e)),
    Command(:indent, "Indent, or go to the next cell of a table", :type, "tab", (e, w, _) -> indent!(e, false)),
    Command(:outdent, "Take an indent away, or go back a cell", :type, "shift+tab", (e, w, _) -> indent!(e, true)),
    Command(:indent_line, "Move the line in a step, wherever the caret is", :edit, "cmd+right_bracket", (e, w, _) -> indent_lines!(e, false)),
    Command(:outdent_line, "Move the line out a step, wherever the caret is", :edit, "cmd+left_bracket", (e, w, _) -> indent_lines!(e, true))],
  "The caret" => [
    Command(:left, "Left", :move, "left", (e, w, select) -> (e.by_step = true; caret_step!(e, -1, select))),
    Command(:right, "Right", :move, "right", (e, w, select) -> (e.by_step = true; caret_step!(e, 1, select))),
    Command(:up, "Up", :move, "up", (e, w, select) -> (e.by_step = true; move!(e, vertical(e, -1), select; keep_goal=true, by=-1))),
    Command(:down, "Down", :move, "down", (e, w, select) -> (e.by_step = true; move!(e, vertical(e, 1), select; keep_goal=true, by=1))),
    Command(:word_left, "To the word before", :move, "opt+left", (e, w, select) -> (e.by_step = true; move!(e, word_step(e.buf, e.buf.caret, -1), select; by=-1))),
    Command(:word_right, "To the next word", :move, "opt+right", (e, w, select) -> (e.by_step = true; move!(e, word_step(e.buf, e.buf.caret, 1), select; by=1))),
    Command(:line_start, "To the start of the line", :move, "cmd+left, home", (e, w, select) -> move!(e, screen_edge(e, -1), select; by=-1)),
    Command(:line_end, "To the end of the line", :move, "cmd+right, end", (e, w, select) -> move!(e, screen_edge(e, 1), select; by=1)),
    Command(:doc_start, "To the top of the page", :move, "cmd+up", (e, w, select) -> move!(e, (1, 0), select; by=-1)),
    Command(:doc_end, "To the bottom of the page", :move, "cmd+down", (e, w, select) -> move!(e, line_end(e.buf, length(e.buf.lines)), select; by=1)),
    Command(:page_up, "Up a screen", :move, "pageup", (e, w, select) -> caret_page!(e, -1, select)),
    Command(:page_down, "Down a screen", :move, "pagedown", (e, w, select) -> caret_page!(e, 1, select))],
  "Deleting" => [
    Command(:erase_back, "Delete what's before the caret", :type, "backspace", (e, w, _) -> erase_back!(e)),
    Command(:erase, "Delete what's after the caret", :type, "delete", (e, w, _) -> erase_next!(e)),
    Command(:erase_word_back, "Delete to the start of the word", :type, "opt+backspace", (e, w, _) -> erase!(e, word_step(e.buf, e.buf.caret, -1))),
    Command(:erase_word, "Delete to the end of the word", :type, "opt+delete", (e, w, _) -> erase!(e, word_step(e.buf, e.buf.caret, 1))),
    Command(:erase_line_start, "Delete to the start of the line", :type, "cmd+backspace", (e, w, _) -> erase!(e, (e.buf.caret[1], 0))),
    Command(:erase_line_end, "Delete to the end of the line", :type, "ctrl+k", (e, w, _) -> erase_line_end!(e))]])

"Each command, by its name"
const COMMANDS = Dict{Symbol,Command}(c.name => c for (_, cs) in COMMAND_GROUPS for c in cs)

"What kind of command the command `name` is: :type, :move, :edit, :look or :window"
command_kind(name::Symbol) = COMMANDS[name].kind

"Open the command palette on the command called `name`, to ask for what it takes"
open_palette!(e, name::Symbol) = open_palette!(e, COMMANDS[name])

"""
The bundles of key bindings, in the order that the key bindings page offers
them. Each lists only the commands whose shortcuts are different from the
ones in the bundle called Ladder, with the shortcuts it gives them.
"""
const BUNDLES = [
  "Ladder" => Pair{Symbol,String}[],
  # ⌘P finds a project in every bundle, so printing has another key. The slides' key, ⌃⌘⇧P, is free in every bundle.
  "VS Code" => [
    :back => "ctrl+minus", :forward => "ctrl+shift+minus",
    :line_up => "opt+up", :line_down => "opt+down", :duplicate_line => "opt+shift+down, opt+shift+up"],
  "Sublime Text" => [
    :back => "ctrl+minus", :forward => "ctrl+shift+minus",
    :sidebar => "cmd+k cmd+b, cmd+backslash", :redo => "cmd+shift+z, cmd+y",
    :line_up => "ctrl+cmd+up", :line_down => "ctrl+cmd+down", :delete_line => "ctrl+shift+k",
    :erase_line_start => "cmd+backspace, cmd+k cmd+backspace", :erase_line_end => "ctrl+k, cmd+k cmd+k"],
  # Emacs's own keys come first, and the Mac's keys still work where Emacs has no other use for them
  "Emacs" => [
    :save => "ctrl+x ctrl+s, cmd+s", :open => "ctrl+x ctrl+f, cmd+o", :close => "ctrl+x ctrl+c, cmd+w",
    :undo => "ctrl+slash, ctrl+x u, cmd+z", :cut => "ctrl+w, cmd+x", :copy => "opt+w, cmd+c", :paste => "ctrl+y, cmd+v",
    :commands => "opt+x, cmd+shift+p", :select_all => "ctrl+x h, cmd+a", :select_word => "opt+shift+2, cmd+d", :find => "ctrl+s, cmd+f", :find_last => "ctrl+r, cmd+shift+g", :comment => "opt+semicolon, cmd+slash",
    :left => "ctrl+b, left", :right => "ctrl+f, right", :up => "ctrl+p, up", :down => "ctrl+n, down",
    :word_left => "opt+b, opt+left", :word_right => "opt+f, opt+right",
    :line_start => "ctrl+a, cmd+left, home", :line_end => "ctrl+e, cmd+right, end",
    :doc_start => "opt+shift+comma, cmd+up", :doc_end => "opt+shift+period, cmd+down",
    :page_up => "opt+v, pageup", :page_down => "ctrl+v, pagedown",
    :erase => "ctrl+d, delete", :erase_word => "opt+d, opt+delete"]]

"The shortcuts that the bundle called `name` gives each command"
bundle_keys(name::AbstractString) = begin
  theirs = Dict(last(BUNDLES[something(findfirst(b -> first(b) == name, BUNDLES), 1)]))
  Dict{Symbol,Vector{Shortcut}}(c.name => read_shortcuts(get(theirs, c.name, c.keys)) for c in values(COMMANDS))
end

"""
The key bindings as they are now. `of` has the shortcuts of each command: the
bundle's, with the ones that the key bindings page changed. `commands` has the
command of each shortcut, and `starts` each stroke that starts a shortcut of two.
`also` has the other commands of a shortcut that two or more commands have.
"""
keys_now(e) = begin
  made = get(e.nodes, :keys, nothing)
  # Code from the startup page can add commands, so the bindings are made again when there are more
  made !== nothing && made.bundle == e.bundle && made.rebound === e.rebound && made.count == length(COMMANDS) && return made
  of = bundle_keys(e.bundle)
  for (name, text) in e.rebound
    haskey(of, name) && (of[name] = read_shortcuts(text))
  end
  commands = Dict{Shortcut,Symbol}()
  also = Dict{Shortcut,Vector{Symbol}}()
  # A shortcut that two commands have runs the one that the page lists first, where that one has a use: see `command_here`
  for (_, cs) in COMMAND_GROUPS, c in cs, s in of[c.name]
    haskey(commands, s) ? push!(get!(Vector{Symbol}, also, s), c.name) : (commands[s] = c.name)
  end
  starts = Set{Stroke}(first(s) for s in keys(commands) if length(s) == 2)
  e.nodes[:keys] = (bundle=e.bundle, rebound=e.rebound, of=of, commands=commands, also=also, starts=starts, count=length(COMMANDS))
end

"""
The command that the shortcut `s` runs in the window of `e`, with the key
bindings `ks`, or nothing. Of the commands that have the shortcut, it's the
first that has a use there (see `works_here`). So code from the startup page
can give a key that Ladder has a use where Ladder's command has none, like ⌘]
on a page that you can't change. When none has a use, it's the first.
"""
command_here(e, ks, s) = begin
  name = get(ks.commands, s, nothing)
  others = get(ks.also, s, nothing)
  (others === nothing || works_here(e, Val(name))) && return name
  something(findfirst_here(e, others), name)
end

"The first of the commands `names` that has a use in the window of `e`, or nothing"
findfirst_here(e, names) = (i = findfirst(n -> works_here(e, Val(n)), names); i === nothing ? nothing : names[i])

"The command that the key `K` runs by itself in window `w`, with the keys that are held there, or nothing"
command_of(e, w, K) = command_here(e, keys_now(e), (Stroke(w.keys & HELD, K),))

"""
The command that the key `K` runs in window `w`, with the keys that are held
there, and true when ⇧ is held to grow the selection. The command is `:wait`
for a key that does nothing by itself: the first key of a shortcut of two, or
a second key that ends no shortcut. It's nothing for a key with no command.
"""
command!(e, w, K) = begin
  (ismouse(K) || K in HELD || K == Keys.capslock || K == Keys.fn) && return (nothing, false)
  ks = keys_now(e)
  s = Stroke(w.keys & HELD, K)
  before = pop!(e.nodes, :stroke, nothing)
  name, select = if before !== nothing
    (something(command_here(e, ks, (before, s)), :wait), false)
  elseif haskey(ks.commands, (s,))
    (command_here(e, ks, (s,)), false)
  elseif s in ks.starts
    e.nodes[:stroke] = s
    (:wait, false)
  else
    # ⇧ with the keys of a command that moves the caret grows the selection. With a key like ⌫, it changes nothing.
    found = Keys.shft in s.held ? get(ks.commands, (Stroke(setdiff(s.held, Keys.shft), K),), nothing) : nothing
    kind = found === nothing ? :none : COMMANDS[found].kind
    kind == :move ? (found, true) : kind == :type ? (found, false) : (nothing, false)
  end
  # A key that types a character types nothing when it's the key of a command, like ⌥F in the Emacs bundle
  name !== nothing && typing_key(K) && !(Keys.cmd in s.held) && !(Keys.ctrl in s.held) && (e.nodes[:mute] = time())
  (name, select)
end

"The commands that are done at each selection when there are several: the ones that go along a line, and the ones that delete"
const AT_EACH = Set([:left, :right, :word_left, :word_right, :line_start, :line_end, :bold, :italic, :value_up, :value_down,
                     :erase_back, :erase, :erase_word_back, :erase_word, :erase_line_start, :erase_line_end])

"Run the command called `name` in the window `w` of `e`"
run!(e, w, name::Symbol, select::Bool=false) =
  name in AT_EACH ? each_selection!(() -> COMMANDS[name].run(e, w, select), e) : COMMANDS[name].run(e, w, select)

"The first shortcut of the command `name` with two spaces before it, to end a tooltip with, or nothing when the command has no keys"
hint(e, name::Symbol) = (list = keys_now(e).of[name]; isempty(list) ? "" : "  " * caps(first(list)))

"True when one of the shortcuts `a` and `b` starts with the other, so the keys of one would run the other"
clashes(a::Shortcut, b::Shortcut) = (n = min(length(a), length(b)); a[1:n] == b[1:n])

"""
Use the bundle called `bundle`, with the shortcuts in `rebound` for the commands
that have other keys than the bundle's. Every window gets them, and they're kept.
"""
keys!(e, bundle::String, rebound::Dict{Symbol,String}) = begin
  usual = bundle_keys(bundle)
  # A command that has the bundle's own shortcuts again isn't changed any more
  e.bundle, e.rebound = bundle, filter(((name, text),) -> haskey(usual, name) && read_shortcuts(text) != usual[name], rebound)
  delete!(e.nodes, :stroke)
  save_settings!(e)
  rerun!(e, :bundle)
  rerun!(e, :rebound)
  e
end

"Use the bundle of key bindings called `name`. Every command gets the bundle's keys, so the keys that were changed go back too."
bundle!(e, name::String) = begin
  any(b -> first(b) == name, BUNDLES) || error("The bundles of key bindings are $(join(first.(BUNDLES), ", ", " and ")). $name isn't one of them.")
  keys!(e, name, Dict{Symbol,String}())
end

"""
Give the command `name` the shortcut `s`, and no other. A command that had
those keys, or keys that start the same way, loses them. Returns the names
of the commands that lost a shortcut.
"""
rebind!(e, name::Symbol, s::Shortcut) = begin
  new = copy(e.rebound)
  lost = Symbol[]
  for (other, list) in keys_now(e).of
    other == name && continue
    kept = filter(o -> !clashes(o, s), list)
    length(kept) == length(list) && continue
    new[other] = written(kept)
    push!(lost, other)
  end
  new[name] = written(Shortcut[s])
  keys!(e, e.bundle, new)
  lost
end

"Give the command `name` the bundle's shortcuts again. A command that has one of them now loses it."
put_back!(e, name::Symbol) = begin
  new = copy(e.rebound)
  delete!(new, name)
  lost = Symbol[]
  for s in bundle_keys(e.bundle)[name], (other, list) in keys_now(e).of
    other == name && continue
    kept = filter(o -> !clashes(o, s), read_shortcuts(get(new, other, written(list))))
    length(kept) == length(list) && continue
    new[other] = written(kept)
    other in lost || push!(lost, other)
  end
  keys!(e, e.bundle, new)
  lost
end

# The key bindings page shows the commands in a list. Each row has the command's shortcuts at its right.
# A click on a row waits for the keys of its new shortcut.

"The list of the commands on the key bindings page"
@def mutable struct KeyList <: SemanticUI end
"A command's row in that list. A click on it waits for the command's new keys."
@def mutable struct KeyRow <: SemanticUI
  name::Symbol = :save
end
"The words in a row that give its command the bundle's keys again"
@def mutable struct KeyReset <: SemanticUI
  name::Symbol = :save
end

const KEY_ROW_H = 34px

"A shortcut as the list shows it: its keys in a box"
keycap(s::Shortcut) = Box(height(22px), padding(7px, 0px), radius(5px), background(colours.float), border(1px, :solid, colours.line),
                          label(caps(s), 12px, color=colours.ink))

"The command whose row waits for new keys, or nothing"
key_asking(e) = get(e.nodes, :key_asking, nothing)

"Stop waiting for a command's new keys, and give the keyboard back to the text"
stop_asking_keys!(e) = (delete!(e.nodes, :key_asking); focus(e); handled)

"What the list says under the row of `name`, after its new keys took the keys of the commands in `lost`"
lost_note!(e, name::Symbol, lost) = begin
  isempty(lost) && return delete!(e.nodes, :key_note)
  titles = [COMMANDS[other].title for other in lost]
  none = [other for other in lost if isempty(keys_now(e).of[other])]
  e.nodes[:key_note] = (name, "\"$(join(titles, "\", \"", "\" and \""))\" had $(length(lost) == 1 ? "this key" : "these keys") before." *
                              (isempty(none) ? "" : length(lost) == 1 ? " It has no key now." : " $(length(none)) of them have no key now."))
end

describe(l::KeyList) = begin
  e = editor(l)
  row(name) = node!(() -> KeyRow(name=name), e, (:key_row, name))
  Column(width(grow=grow), Alignment.Start, name="Key bindings",
    Iterators.flatten(((Box(width(grow=grow), height(40px), padding(10px, 0px, 6px, 10px), Alignment.End,
                            Row(width(grow=grow), label(group, 12px, color=colours.dim, weight="Semibold"))),
                        map(c -> row(c.name), cs)...) for (group, cs) in COMMAND_GROUPS))...)
end

describe(r::KeyRow) = begin
  e = editor(r)
  w = window_of(e)
  waits = key_asking(e) == r.name
  # A click somewhere else gives the keyboard to something else, and the row stops waiting
  waits && (w === nothing || w.focus !== r) && (delete!(e.nodes, :key_asking); waits = false)
  list = keys_now(e).of[r.name]
  under = get(e.nodes, :key_note, (:none, ""))
  # Words by themselves would take half of the row, so each is in a box that's as wide as the words
  right = waits ? (Box(label(get(e.nodes, :key_refused, "Press the new keys, or esc to keep these"), 12px, color=colours.accent)),) :
          isempty(list) ? (Box(label("No keys", 12px, color=colours.faint)),) : map(keycap, list)
  row = Row(width(grow=grow), height(KEY_ROW_H), padding(10px, 0px), radius(6px), child_gap=6px, name="Command",
            background(waits ? colours.active : ishovered(r) ? colours.hover : clear),
    Box(width(grow=grow), Alignment.Start, label(COMMANDS[r.name].title, 14px)),
    (haskey(e.rebound, r.name) && !waits ? (node!(() -> KeyReset(name=r.name), e, (:key_reset, r.name)),) : ())...,
    right...)
  under[1] == r.name || return row
  Column(width(grow=grow), Alignment.Start, row,
    Box(width(grow=grow), padding(10px, 0px, 8px, 10px), Alignment.Start, label(under[2], 12px, color=colours.dim)))
end

cursor(::KeyRow) = :hand

onkey(r::KeyRow, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(r)
  e.nodes[:key_asking] = r.name
  delete!(e.nodes, :key_refused)
  delete!(e.nodes, :key_note)
  focus(r)
  handled
end

# While a row waits, the next key with the keys held with it is the command's new shortcut. esc leaves the command as it was.
onkey(r::KeyRow, ev::KeyPress{K}) where K = begin
  e = editor(r)
  key_asking(e) == r.name || return nothing
  ismouse(K) && return nothing
  (K in HELD || K == Keys.capslock || K == Keys.fn) && return handled
  K == Keys.escape && return stop_asking_keys!(e)
  s = Stroke(ev.window.keys & HELD, K)
  # The text gets the keyboard back before the key types its character, like the π of ⌥P, so the character is dropped
  typing_key(K) && !(Keys.cmd in s.held) && !(Keys.ctrl in s.held) && (e.nodes[:mute] = time())
  if typing_key(K) && !(Keys.cmd in s.held) && !(Keys.ctrl in s.held) && !(Keys.opt in s.held)
    e.nodes[:key_refused] = "$(caps(s)) types a character. Hold ⌘, ⌃ or ⌥ with it."
    return handled
  elseif K == Keys.enter && s.held == Keys(0)
    e.nodes[:key_refused] = "Return starts a new line. Hold ⌘, ⌃, ⌥ or ⇧ with it."
    return handled
  end
  lost_note!(e, r.name, rebind!(e, r.name, (s,)))
  stop_asking_keys!(e)
end
ontype(r::KeyRow, ::Typed) = key_asking(editor(r)) == r.name ? handled : nothing

describe(b::KeyReset) = Box(height(22px), padding(7px, 0px), radius(5px), background(ishovered(b) ? colours.active : clear),
                            label("Put back", 12px, color=colours.dim))
cursor(::KeyReset) = :hand
onkey(b::KeyReset, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(b)
  lost_note!(e, b.name, put_back!(e, b.name))
  handled
end

# A mouse can have two buttons at its side, which go back and forward in a web browser. Here they do what
# ⌘⌥← and ⌘⌥→ do. A press of one isn't for the place that the mouse is over. It comes to the part of the
# window that has the keyboard, and from there to here.
onkey(e::Editor, ev::KeyPress{Keys.mouse_back}) = side_button!(e, ev.window, :back)
onkey(e::Editor, ev::KeyPress{Keys.mouse_forward}) = side_button!(e, ev.window, :forward)

"Run the `command` of a button at the side of the mouse: `:back` or `:forward`"
side_button!(e, w, command) = begin
  e = top_editor(e)   # in a part of another page, they go back and forward in the window's page
  # While a picture fills the window, or the file finder is open, the page under it stays, as it does for the keys
  (zooming(e) === nothing && e.popup == :none) || return nothing
  run!(e, w, command)
  nothing
end

# A press of a mouse button that nothing under the mouse took comes here. It has a method of its own, so the
# first click in a window doesn't wait for the code of the key bindings to be made ready.
onkey(e::Editor, ev::Union{KeyPress{Keys.mouse_left},KeyPress{Keys.mouse_right},KeyPress{Keys.mouse_middle}}) = begin
  pop!(e.nodes, :chose, false) && return
  # While a picture or a model fills the window, a right-click has no menu
  zooming(e) === nothing || e.popup != :none || return
  slideshow(e) === nothing || return   # nor has a right-click on a slide
  ev isa KeyPress{Keys.mouse_right} && return context_menu!(e, ev.window)
  nothing
end

"""
What a key does. The key bindings say which command it runs. Return, esc and
Space have no command: what they do depends on where the caret is.
"""
# Julia compiles a function once for each type that it's called with, and each key's press has
# a type of its own. So the press gives its key on as a value, and the long function that says
# what a key does is compiled once, for the first key that's pressed. Before that, each key
# waited at its first press: ⌘V for more than a second.
onkey(e::Editor, ev::KeyPress{K}) where K = pressed!(e, ev.window, K)

"The key `K` was pressed in the window `w` while `e` or a part of it had the keyboard"
pressed!(e::Editor, w, K) = begin
  # A key that the sidebar's tree took, like Return on a heading, comes here next. It isn't for the text.
  pop!(e.nodes, :chose, false) && return
  # The first key of a shortcut of two, like ⌃X, does nothing but wait for the second
  command, select = command!(e, w, K)
  command == :wait && return
  command == :paste || return key_does!(e, w, K, command, select)
  # The key that pastes reads the clipboard now. An app that takes dictation puts its words there, presses
  # the key, and half a second later puts back what was there before. The first paste waits longer than
  # that for Julia to compile it, and it got that older thing, like a screenshot.
  mine = Pasteboard.hold!()
  try
    key_does!(e, w, K, command, select)
  finally
    mine && Pasteboard.release!()
  end
end

"""
Do what the key `K` does in the window `w` of `e`, where `command` is the
command that the key runs, or nothing: see `command!`. It's compiled once for
a key with a command and a key with none, so the first key that's pressed
compiles it for them all.
"""
key_does!(e::Editor, w, K, @nospecialize(command), select) = begin
  # In a part of another page, a key for the window is the window's page's, and esc goes back to that page
  (hosted(e) === nothing || agent_part_of(e) !== nothing) || !part_key!(e, w, K, command, select) || return handled
  # In the text of a request in place, Return gives the request to the agent and esc takes the field away
  ask_box_of(e) === nothing || !ask_key!(e, w, K, command) || return handled
  # In the words that you type to the agent of agent mode, Return gives them to the agent. A key for the window is the window's page's.
  agent_part_of(e) === nothing || !agent_key!(e, w, K, command) || return handled
  # In a field of a SolidCraft design, Return, Esc, Tab and the window's keys are the design's and the window's. In
  # the sheet of its parameters, Return and Tab are the sheet's.
  field = design_field_of(e)
  field === nothing || (done = design_key!(field, e, w, K, command); done === :text || return done)
  # In the field of a cell of a CSV file's table, Return, Tab, ↑, ↓ and esc go from cell to cell
  cell = cell_field_of(e)
  cell === nothing || (done = cell_key!(cell, e, w, K, command); cell.took = done === :text; done === :text || return done)
  # While the command palette shows, every key is its own, whatever part of it has the keyboard
  e.popup == :commands && return (palette_key!(e, w, K, command); K == Keys.tab ? handled : nothing)
  kind = command === nothing ? :none : COMMANDS[command].kind
  # The commands that close the window and show the settings work whatever has the keyboard. A slider
  # on the settings page takes the keyboard when it's dragged, and ⌘, still closes that window.
  command in (:close, :settings) && return (run!(e, w, command); nothing)
  # While a picture or a model fills the window, the keys are its own. Esc puts the page back.
  zoomed = zooming(e)
  zoomed === nothing || e.popup != :none || zoom_key!(zoomed, K, w, command) !== handled || return
  # The picture, the PDF file or the video that covers a file's own page takes the keys that are its own
  zoomed === nothing && e.popup == :none && file_key!(e, K, w, command) === handled && return
  # While the page shows as slides, the keys go from one slide to another. Esc shows the page again.
  slideshow(e) === nothing || slide_key!(e, K, w, command) !== handled || return
  shift = only_held(w, Keys.shft)
  b = e.buf
  # While a part of a live block has the keyboard, the keys are its own and don't change the text.
  # Escape gives the keyboard back to the text. A command for the window, like the one that saves, still runs.
  if w.focus !== e && w.focus !== input(e)
    if w.focus === find_input(e)
      find_key!(e, w, K, command)
    elseif w.focus === renamer(e)
      rename_key!(e, K)
    elseif K == Keys.escape && unmodified(w)
      hide_menu!(w)
      focus(e)
    elseif command in (:sidebar, :sidebar_keys) && w.focus === file_tree(e)
      # While the sidebar has the keyboard, its two commands give the keyboard back to the text, and the first hides it too
      command == :sidebar && toggle_panel!(e)
      focus(e)
    elseif any(f -> f(e, w, K), values(FIELD_KEYS))
      # Code from the startup page took the key, like Return in a field of a form that it shows
    elseif kind == :window
      run!(e, w, command)
    end
    # Tab goes from one field of a live block to the next. In the field that finds text, and the one
    # that renames a file, it stays where it is.
    return K == Keys.tab && (w.focus === find_input(e) || w.focus === renamer(e)) ? handled : nothing
  end
  e.popup in (:finder, :projects) && return (finder_key!(e, K); K == Keys.tab ? handled : nothing)
  # The list of names under a sheet's expression takes ↑, ↓, Return, Tab and esc
  unmodified(w) && suggest_key!(e, K) && return nothing
  # Esc hides the box that lists what a function takes
  unmodified(w) && call_key!(e, K) && return nothing
  # While the page is read, there's no caret to move, so the keys that would move it scroll the
  # page. A key that would change the text at the caret does nothing. Any other command still
  # works, and one that moves the caret, like undo, puts it back.
  if caretless(b) || readonly(b)
    step = read_step(e, K, command, held_keys(w))
    step === nothing || return (scroll_page!(e, step); nothing)
    K == Keys.escape || kind in (:window, :look, :edit) || return nothing
  end
  # A file that's only shown takes the commands that don't change it. Its text can be selected, copied and searched.
  if readonly(b) && K != Keys.escape
    kind == :window || (kind == :look && b.view != :file) || return nothing
  end
  if K == Keys.escape && finding(e) && unmodified(w)
    close_find!(e)
  elseif K == Keys.escape && unmodified(w)
    # Escape closes a popup. With none open, it takes away what the page's code came to. With
    # none of that either, it hides the caret, and so every line shows as it reads.
    if e.popup != :none
      e.popup = :none
    elseif !isempty(others(b))
      # With several selections, Escape leaves the one that was there first, and the page goes back to it
      b.anchor, b.caret = first(b.others)
      empty!(b.others)
      touch!(e)
    elseif lowered(e) !== nothing
      # The lines of a block that fill the window go back among the lines of the page
      widen!(e)
    elseif !forget_outcomes!(e)
      b.anchor = b.caret
      b.reading = true
    end
  elseif command !== nothing
    run!(e, w, command, select)
  elseif K == Keys.enter && (unmodified(w) || shift)
    each_selection!(() -> newline!(e), e)
  end
  nothing
end

# What a key types comes as a character, so each keyboard types its own letters:
# ß on a German keyboard, é from ⌥E and then E, and an emoji from the Mac's
# emoji list. A key that's held with ⌘ types nothing.
ontype(e::Editor, ev::Typed) = begin
  # The key that types this just ran a command, like ⌥F in the Emacs bundle, so it types nothing
  time() - pop!(e.nodes, :mute, 0.0) < 0.5 && return handled
  # A character that a part of a live block didn't take comes here next. It isn't for the text.
  ev.window.focus === e || return nothing
  zooming(e) === nothing || return handled   # the page under a picture that fills the window doesn't change
  c = ev.char
  # macOS has characters of its own for keys like the arrows, which aren't text
  (iscntrl(c) || '\uf700' <= c <= '\uf8ff') && return nothing
  # While the page is read, a key that would change the text does nothing. A file that's only shown is never changed.
  (caretless(e.buf) || readonly(e.buf)) && return nothing
  # Nor does a character change a part that the caret is on as a whole, like a diagram
  picked(e.buf) === nothing || return nothing
  # In code, a bracket or a quote comes with the one that closes it
  each_selection!(() -> pair!(e, c) || type!(e, string(c), typing=true), e)
  # A code block offers names only just after a character is typed
  e.nodes[:typed_at] = (e.buf.path, e.buf.version, e.buf.caret)
  # The ( of a call opens the box of what the function takes, and so does a , or a ; in a call
  c in ('(', ',', ';') && call_typed!(e, c)
  handled
end

# --- files dropped on the page -----------------------------------------------------------
#
# A file that's dropped on the page from the Finder goes into the text. A
# picture goes on a line of its own under the line it's dropped on, written as
# ![name](path), so the page shows it. A CSV file goes in the same way, and
# the page shows it as a table. A Markdown file goes in where it's
# dropped as a link to it. Any other file, and a folder, goes in there as a
# path that shows as a breadcrumb: !`fs"path"`.

"`path` as a link writes it. A space or a bracket would end the link early, so each is written as its code."
escaped(path) = replace(path, ' ' => "%20", '(' => "%28", ')' => "%29")
ispicture(path) = (ext = lowercase(splitext(path)[2]); ext in PICTURES || ext in MAC_PICTURES)

"The Markdown that shows the file or the folder at `path`"
markdown_for(e, path) = begin
  name, at = splitext(basename(path))[1], named(e, path)
  ispicture(path) || istable(path) ? "![$name]($(escaped(at)))" : ismarkdown(path) ? "[$name]($(escaped(at)))" : "!`fs\"$(replace(at, '"' => "\\\""))\"`"
end

onfiledrop(e::Editor, w::Window, paths) = begin
  # What's dropped on an agent's pane goes to the agent with your words, as what's pasted there does
  pane = agent_pane_at(e, w)
  if pane !== nothing
    give_files!(pane, paths)
    focus(pane.field)
    return nothing
  end
  e.buf.view == :markdown || return nothing   # a file goes into a page as Markdown
  slideshow(e) === nothing || return nothing   # the text doesn't change while the page shows as slides
  # A PDF file or a picture that's dropped on a takeoff is its plan
  v = takeoff_at(e, w)
  plan = v === nothing ? nothing : findfirst(p -> isfile(p) && (ispdf(p) || ispicture(p)), paths)
  plan === nothing || return plan!(v, rstrip(String(paths[plan]), '/'))
  # A picture or a page that's dropped on a canvas goes on the board where it's dropped
  board = canvas_at(e, w)
  board === nothing || board.zoom <= 0 || return (put_on_board!(board, paths, board_place(board, num(w.mouse[1]), num(w.mouse[2]))); nothing)
  # A file or a folder that's dropped on a gallery goes into the gallery
  g = gallery_at(e, w)
  g !== nothing && add_files!(g, paths) && return nothing
  # A vCard file that's dropped on a block of contacts joins the block
  c = contacts_at(e, w)
  if c !== nothing
    list, paths = split_contacts(paths)
    add_contacts!(c, list)
    isempty(paths) && return nothing
  end
  put_files!(e, paths, settle(e.buf, locate(e, w.mouse)))
end

"Put the files and folders at `paths` into the text at `at`, the way a drop there does. ⌘V does this with files that were copied."
put_files!(e, paths, at::Pos) = begin
  paths = [rstrip(String(p), '/') for p in paths if ispath(p)]
  isempty(paths) && return
  b = e.buf
  b.view == :markdown || return   # only a page has text for the path to go into, as Markdown
  # A vCard file goes in as a block of its contacts
  list, paths = split_contacts(paths)
  at = put_contacts!(e, list, at)
  # A CSV file goes on a line of its own as a picture does, so the page shows it as a table
  pictures = [markdown_for(e, p) for p in paths if isfile(p) && (ispicture(p) || istable(p))]
  others = [markdown_for(e, p) for p in paths if !(isfile(p) && (ispicture(p) || istable(p)))]
  if !isempty(others)
    line = b.lines[at[1]]
    # What's dropped on a word goes after the word, not into it
    at = (at[1], word_at(line, at[2])[2])
    # A space goes between what's dropped and the words on each side of it, but not before a full stop or a comma
    before = at[2] > 0 && !isspace(line[nextind(line, 0, at[2])]) ? " " : ""
    next = at[2] < length(line) ? line[nextind(line, 0, at[2] + 1)] : ' '
    after = isspace(next) || next in ".,;:!?)]}" ? "" : " "
    new = before * join(others, " ") * after
    edit!(b, at, at, new)
    at = (at[1], at[2] + length(new))
  end
  if !isempty(pictures)
    # Under the block that it's dropped on, so that a picture doesn't go into the middle of a table
    under = block_end(b, at[1])
    empty = isempty(strip(b.lines[under]))
    edit!(b, empty ? (under, 0) : line_end(b, under), line_end(b, under), (empty ? "" : "\n\n") * join(pictures, "\n\n"))
    under += (empty ? 0 : 2) + 2(length(pictures) - 1)
    at = line_end(b, under)
  end
  b.caret = b.anchor = at
  focus(e)
  touch!(e)
end

# --- the bar over a table ----------------------------------------------------------------
#
# While the caret is in a table, a small bar floats over the table's top left
# corner. Its buttons add and remove a row or a column at the caret, and put the
# text of the caret's column on the left, in the centre or on the right.

const TABLE_ACTIONS = (:addrow => "+Row", :delrow => "−Row", :addcol => "+Col", :delcol => "−Col",
                       :left => "L", :center => "C", :right => "R")
const DASHES = (left=":---", center=":---:", right="---:")
const ALIGN_ICONS = (left="text-left", center="text-center", right="text-right")
const BAR_H = 26px

"Change the table the caret is in, then put the caret back in a cell"
tableop!(e, action::Symbol) = begin
  b = e.buf
  inspread(b, b.caret[1]) && return spreadop!(e, action)
  run = table(b, b.caret[1])
  run === nothing && return
  s, t = run
  i = b.caret[1] == s + 1 ? s : b.caret[1]
  cs = tablecells(b.lines[i])
  c = isempty(cs) ? 1 : nearest(cs, b.caret[2])
  rows = map(celltexts, b.lines[s:t])
  n = maximum(length, rows)
  rows = [[r; fill(k == 2 ? "---" : "", n - length(r))] for (k, r) in enumerate(rows)]
  k = i - s + 1   # the caret's row in `rows`, where row 2 is the line of dashes
  if action == :addrow
    k = max(k, 2) + 1
    insert!(rows, k, fill("", n))
  elseif action == :delrow
    k == 1 && return   # the heading row stays
    deleteat!(rows, k)
    k = k > length(rows) ? (length(rows) > 2 ? length(rows) : 1) : k
  elseif action == :addcol
    c += 1
    foreach((j, r) -> insert!(r, c, j == 2 ? "---" : ""), eachindex(rows), rows)
  elseif action == :delcol
    n == 1 && return
    foreach(r -> deleteat!(r, c), rows)
    c = min(c, n - 1)
  else
    rows[2][c] = getproperty(DASHES, action)
  end
  edit!(b, (s, 0), line_end(b, t), join(map(tableline, rows), "\n"))
  line = s + k - 1
  cell = tablecells(b.lines[line])[c]
  b.caret = b.anchor = (line, cell.hi)
  touch!(e)
end

# The three buttons that move a column's text show the usual picture of lines of text on that side
"True when the caret is in a row of a table, under the heading row, that has no text in any cell"
emptyrow(b::Buffer) = begin
  inspread(b, b.caret[1]) && return !selecting(b) && all(isempty, spreadtexts(b.lines[b.caret[1]]))
  run = table(b, b.caret[1])
  run !== nothing && !selecting(b) && b.caret[1] > run[1] + 1 && all(isempty, celltexts(b.lines[b.caret[1]]))
end

"Backspace in an empty row removes the row and puts the caret at the end of the row above"
backrow!(e) = begin
  b = e.buf
  inspread(b, b.caret[1]) && return droprow!(e)
  s, _ = table(b, b.caret[1])
  i = b.caret[1]
  tableop!(e, :delrow)
  above = i - 1 == s + 1 ? s : i - 1
  cs = tablecells(b.lines[above])
  isempty(cs) || (b.caret = b.anchor = (above, cs[end].hi))
  touch!(e)
end

describe(t::TableButton) =
  Box(height(BAR_H - 6px), padding(7px, 0px), radius(4px), background(ishovered(t) ? colours.hover : clear),
    haskey(ALIGN_ICONS, t.action) ? Icon(getproperty(ALIGN_ICONS, t.action), size=13px, color=colours.dim) :
                                    label(t.label, 11px, color=colours.dim))

cursor(::TableButton) = :hand
onkey(t::TableButton, ::KeyPress{Keys.mouse_left}) = (e = editor(t); tableop!(e, t.action); focus(e))

"The bar over the table the caret is in, placed in the window. Nothing when the caret isn't in a table."
tablebar(e) = begin
  b = e.buf
  (!caretless(b) && b.caret[1] == b.anchor[1] && !isempty(e.layout)) || return ()
  it = item(e, b.caret[1])
  it.content isa Grid || return ()
  top = above_page(e) + PAGE_TOP + it.top + TABLE_GAP - e.scroll.offset - BAR_H - 3px
  top >= above_page(e) || return ()
  bar = Row(height(BAR_H), padding(3px, 0px), radius(6px), background(colours.float), border(1px, :solid, colours.line), lifted,
    # A spreadsheet has no buttons that move a column's text: a number goes on the right and text on the left
    [node!(() -> TableButton(action=a, label=l), e, (:table, a)) for (a, l) in TABLE_ACTIONS[1:(isspread(it.content) ? 4 : end)]]...)
  # The page's text is in the middle of the space beside the file panel
  side, space = page_span(e)
  left = side + max(PAGE_X, (space - e.width) / 2) + item_room(e, it)[1]
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, left), bar),)
end

# --- the top bar ------------------------------------------------------------------------

describe(b::ToolButton) = begin
  e = editor(b)
  ishovered(b) || (b.quiet = false)
  on = (b.action == :panel && e.panel) || (b.action == :marks && marking(e)) || (b.action == :hidden && e.hidden) ||
       (haskey(BUTTONS, b.action) && get(BUTTONS[b.action], :on, _ -> false)(e))
  # A button whose work takes a while, like a commit while the agent writes its message, spins until it's done
  busy = haskey(BUTTONS, b.action) && get(BUTTONS[b.action], :busy, _ -> false)(e)
  # A half button, like each chevron beside the diff button, is half as tall as the others, with one over the other, and narrow
  half = haskey(BUTTONS, b.action) && get(BUTTONS[b.action], :half, false) !== false
  box = Box(width(half ? 18px : 30px), height(half ? 14px : 28px), radius(half ? 4px : 6px), Alignment.Center, name="Button",
            background(on ? colours.active : ishovered(b) && !off(b) ? colours.hover : clear),
          busy ? Spinner(size=15px) :
          Icon(b.icon, size=half ? 9px : 15px, color=off(b) ? colours.faint : haskey(BUTTONS, b.action) && BUTTONS[b.action].strong ? colours.accent : colours.dim))
  # While the sidebar is closed, a dot beside its button says that an agent waits for a page that isn't showing
  (b.action == :panel && waiting_dot(e)) || return box
  Row(Alignment.Center, child_gap=DOT_GAP, box, Box(width(DOT_W), height(DOT_W), radius(DOT_W / 2), background(colours.accent)))
end

const DOT_W = 7px     # how wide the dot beside the sidebar's button is
const DOT_GAP = 4px   # the room between the button and its dot

"True when the sidebar's button has a dot beside it: the sidebar is closed, and an agent waits for a page that isn't showing"
waiting_dot(e) = !e.panel && !isempty(elsewhere(e))

cursor(b::ToolButton) = off(b) ? :arrow : :hand

onkey(b::ToolButton, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(b)
  b.action == :panel && toggle_panel!(e)
  b.action == :outside && open_outside!(e)
  b.action == :marks && toggle_marks!(e)
  b.action == :hidden && hidden!(e, !e.hidden)
  b.action == :back && go_back!(e)
  b.action == :forward && go_forward!(e)
  b.action == :job && make_job!(e)
  b.action in BLOG_ACTIONS && blog_act!(e, b.action)
  haskey(BUTTONS, b.action) && BUTTONS[b.action].run(e)
  hush!(b)
  # A button that opened the palette, like Commit's, leaves the keyboard in it
  e.popup == :commands || focus(e)
end

# Each button in the top bar says what it does while the mouse is over it. A
# click hides what it says until the mouse leaves the button.

const Tipped = Union{ToolButton,SendButton,Mode,CheckCount,ReadOnly}
# The colours of code in a tooltip. A tooltip is dark grey in each theme, so
# they're the night theme's, with comments lighter so that they can be read.
const TIP_CODE = (comment=colorant"rgb(150,150,156)", string=NIGHT.string, number=NIGHT.number,
                  keyword=NIGHT.keyword, call=NIGHT.call, type=NIGHT.type, added=NIGHT.added, removed=NIGHT.removed)

"""
Lines of code in a tooltip, each a row `high` tall, with the colours that code
has in the page. `lang` is the code's language, like julia: text that isn't
code is all `TIP_INK`. The lines inside three quotes, like the middle of a
docstring, are all the colour of a string. `open` is the quote of one that's
open at the first line, as `string_opens` gives it, or '\\0'.
"""
tip_code(lines, lang="julia"; high=17px, open='\0') = begin
  face(kind) = Face(codefont(), kind == :comment ? codeslant() : codestyle(), 12px,
                    kind == :plain ? TIP_INK : getfield(TIP_CODE, kind), false)
  rows = Any[]
  for line in lines
    parts = tokens(line, lang, open)
    open = left_open(line, lang, open)
    push!(rows, Box(height(high), Row(Alignment.Start, [p for t in parts if !isempty(t.text) for p in spared(t.text, face(t.kind))]...)))
  end
  rows
end

"What the tooltip of a button in the top bar says"
tip(b::ToolButton) = begin
  e = editor(b)
  if b.action == :panel
    e.panel && return "Hide sidebar" * hint(e, :sidebar)
    ws = elsewhere(e)
    # The dot beside the button is for the first of these
    isempty(ws) && return "Show sidebar" * hint(e, :sidebar)
    return "$(uppercasefirst(first(ws).name)) waits for $(basename(first(ws).page))  ·  Show sidebar" * hint(e, :sidebar)
  end
  b.action == :marks && return marking(e) ? "Hide $(whose(e)) changes" : "Show $(whose(e)) changes"
  b.action == :hidden && return (e.hidden ? "Leave out hidden and ignored files" : "Show hidden and ignored files") * hint(e, :hidden_files)
  if b.action == :back
    to = step_words(e)
    return to === nothing ? "No file to go back to" : "Back to $to" * hint(e, :back)
  elseif b.action == :forward
    to = step_words(e, e.ahead)
    return to === nothing ? "No file to go forward to" : "Forward to $to" * hint(e, :forward)
  end
  b.action == :job && return job_tip(e)
  b.action in BLOG_ACTIONS && return blog_tip(e, b.action)
  haskey(BUTTONS, b.action) && return BUTTONS[b.action].tip(e)
  b.action == :outside || return ""
  "Open in $(app_name(opener(e.buf.path)))"
end
tip(s::SendButton) = begin
  e = editor(s)
  ws = agents(e)
  isempty(ws) ? "Nudged $(get(e.nodes, :agent, "the agent"))" : "Nudge $(first(ws).name) with what you changed" * hint(e, :run)
end

tip(::ReadOnly) = "Read only"

const LOCK_W = 26px   # how wide the lock is in the top bar

# UI.jl's lock is 10 wide and 14 tall, so in the top bar it looked stretched. This one is 11 wide and 13 tall, in a
# square 16 wide: a body with round corners, and a shackle over it. Each line is 1 wide, as in UI.jl's icons.
const LOCK_SHAPES = ("M4.5 7H11.5A2 2 0 0 1 13.5 9V12.5A2 2 0 0 1 11.5 14.5H4.5A2 2 0 0 1 2.5 12.5V9A2 2 0 0 1 4.5 7ZM4.5 8A1 1 0 0 0 3.5 9V12.5A1 1 0 0 0 4.5 13.5H11.5A1 1 0 0 0 12.5 12.5V9A1 1 0 0 0 11.5 8Z",
                     "M4.5 7V5A3.5 3.5 0 0 1 11.5 5V7H10.5V5A2.5 2.5 0 0 0 5.5 5V7Z")

"The name of the lock's icon. Its shapes go among UI.jl's icons the first time that it's asked for, as the snake's do."
lock_icon() = begin
  kept = get(icon_cache, "ladder-lock", nothing)
  (kept === nothing || [p.d for p in kept.paths] != collect(LOCK_SHAPES)) &&
    (icon_cache["ladder-lock"] = (paths=[SVGPath(d=LOCK_SHAPES[1], evenodd=true), SVGPath(d=LOCK_SHAPES[2])], viewbox=(0f0, 0f0, 16f0, 16f0)))
  "ladder-lock"
end

describe(::ReadOnly) = Box(width(LOCK_W), height(28px), Alignment.Center, Icon(lock_icon(), size=15px, color=colours.dim))

"The lock in the top bar of `e`"
lock_part(e) = node!(() -> ReadOnly(), e, :read_only)

"""
True when the top bar has a lock while the page shows `o`, a file or a folder
that's only shown: nothing can be typed in it. A kind of folder whose own page
takes changes its own way, as a company's books take a new invoice, has a
method of this that says false.
"""
shows_lock(e, o) = true

"""
What the right end of the top bar has for the page of `o`, a file or a folder
that's shown its own way: nodes, like a button for what the page is for. A
kind of folder has a method of this, as a company's books have New invoice.
"""
page_actions(e, o) = ()

draw(ctx, size, ui::ConcreteRect, b::Tipped) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::Tipped, ev::MouseMove) = begin
  b.quiet && return
  show_tooltip!(ev.window, tip_label(tip(b)), tip_rect(b)...,
                placement=:bottom, gap=6px)
end

"What a button's tooltip points at: the button itself, or the upper half button and the one under it, so the tooltip doesn't cover the lower one"
tip_rect(b::Tipped) = b.rect
tip_rect(b::ToolButton) = haskey(BUTTONS, b.action) && get(BUTTONS[b.action], :half, false) == :top ?
                          (b.rect[1], b.rect[2], b.rect[3], 2b.rect[4]) : b.rect

hush!(b::Tipped) = (b.quiet = true; hide_tooltip!(window_of(b)))

# --- a job in Centient from the page ------------------------------------------------------
#
# A project page is one whose front matter has a `progress` line with a web
# address. The walkthrough service keeps the page's tasks at that address. For
# a project page, the top bar has a button that makes the page's job in
# Centient: Centient reads the tasks from the address and gives each trade a
# task. Centient needn't be open, and nothing waits for it. Words under the
# button say that Centient works, and then what it made or why it couldn't.
# They stay for a few seconds, and they're the button's tooltip after that.

const JOB_SHOWS = 8   # seconds that Centient's answer stays under the button

"What Ladder asked Centient to make from a page, and what the button says of it"
mutable struct JobAsk
  path::String      # the page's file
  request::Any      # what Centient was asked, or nothing once it has answered
  said::String      # what the button says
  wrong::Bool       # true when `said` is why Centient couldn't
  at::Float64       # when Centient was asked, and then when it answered
  shows::Bool       # true while the words are under the button
end

"What the front matter of `lines` sets `key` to, without quotes around it, or nothing if it has no such key"
matter_value(lines, key) = begin
  t = front_matter(lines)
  t == 0 && return nothing
  for (_, k, v) in matter_rows(lines, t)
    k == key && return String(strip(strip(v), ['"', '\'']))
  end
  nothing
end

"The web address of the page's tasks, from the `progress` line of its front matter, or nothing if the page isn't a project page"
progress_address(e) = begin
  url = matter_value(e.buf.lines, "progress")
  url !== nothing && startswith(url, r"https?://") ? url : nothing
end

"What Centient needs to make the page's job: the progress address, the page's first # heading, the property and the purpose from the front matter, and where the page's file is, which the job keeps as its PRD"
job_args(e) = begin
  b = e.buf
  args = Dict{String,Any}("progress" => progress_address(e))
  isempty(b.path) || (args["page"] = abspath(b.path))
  headings = outline(b)
  i = findfirst(h -> h.level == 1, headings)
  i === nothing || isempty(headings[i].title) || (args["title"] = headings[i].title)
  for key in ("property", "purpose")
    value = matter_value(b.lines, key)
    value === nothing || isempty(value) || (args[key] = value)
  end
  args
end

"What Ladder asked Centient to make from the page that shows, or nothing"
job(e) = (j = get(e.nodes, :job_ask, nothing); j !== nothing && j.path == e.buf.path ? j : nothing)

"True while Centient makes a job"
making(e) = (j = get(e.nodes, :job_ask, nothing); j !== nothing && j.request !== nothing)

"""
True for a button of the top bar that does nothing now: the one that makes the
job, when the Mac has no Centient or Centient makes a job, the ones that
go back and forward, when they have no file to go to, and one that code from
the startup page added, when that code says so
"""
off(b::ToolButton) = (b.action == :job && (!Centient.available() || making(editor(b)))) ||
                     (b.action == :back && step_words(editor(b)) === nothing) ||
                     (b.action == :forward && step_words(editor(b), editor(b).ahead) === nothing) ||
                     (b.action in BLOG_ACTIONS && blog_off(editor(b), b.action)) ||
                     # A button that code from the startup page added says so itself
                     (haskey(BUTTONS, b.action) && BUTTONS[b.action].off(editor(b)))

"What the top bar shows for a project page: the button that makes the page's job in Centient"
job_part(e) = progress_address(e) === nothing ? () : (button(e, :job, "hammer"), Box(width(4px)))

"What the tooltip of the button that makes the job says: what the button does, or what happened when it did it"
job_tip(e) = begin
  Centient.available() || return "Centient isn't on this Mac"
  j = job(e)
  j === nothing ? "Make job in Centient" : j.said
end

"Ask Centient to make the page's job. Centient answers later, and `job_tick!` takes the answer."
make_job!(e) = begin
  (progress_address(e) === nothing || !Centient.available() || making(e)) && return
  e.nodes[:job_ask] = JobAsk(e.buf.path, Centient.ask("make_job_from_page", job_args(e)), "Making the job in Centient…", false, time(), false)
  nothing
end

"What to say of the job that Centient made, or that it had. `made` is Centient's answer."
job_words(made) = begin
  n(key) = (x = get(made, key, 0); x isa Real ? round(Int, x) : 0)
  some(k, thing) = "$k $thing$(k == 1 ? "" : "s")"
  title = string(something(get(made, "title", nothing), ""))
  if get(made, "existed", false) === true
    return n("added") > 0 ? "Centient added $(some(n("added"), "new task")) to the job $title." : "Centient has this job already: $title."
  end
  company = Centient.server.company
  "Centient has the job $title$(isempty(company) ? "" : " in $company"), with $(some(n("steps"), "task")) for $(some(n("tasks"), "trade"))."
end

"""
What happens to the page's job in each frame: Centient's answer is taken, and
the words about it show under the button while Centient works and for a few
seconds after it answers.
"""
job_tick!(e) = begin
  j = get(e.nodes, :job_ask, nothing)
  j === nothing && return
  r = j.request
  if r !== nothing
    Centient.check!()
    if Centient.finished(r)
      j.request, j.at = nothing, time()
      j.wrong = Centient.failed(r) || !(r.value isa AbstractDict)
      j.said = Centient.failed(r) ? r.problem : j.wrong ? "Centient gave an answer that Ladder can't read" : job_words(r.value)
    else
      redraw_in!(e, 0.1)   # while Centient works, the window looks again soon
    end
  end
  win, b = window_of(e), get(e.nodes, :job, nothing)
  (win === nothing || b === nothing) && return
  left = j.request === nothing ? JOB_SHOWS - (time() - j.at) : Inf
  if left > 0 && j.path == e.buf.path && progress_address(e) !== nothing
    # The words look as a tooltip does. They stay while the mouse moves, which a tooltip doesn't.
    popup!(win, Bubble(content=Box(padding(8px, 5px), label(j.said, 12px, color=TIP_INK)), target=b.rect),
           anchor=b.rect, placement=:bottom, gap=6px, key=:job, input=false)
    j.shows = true
    isfinite(left) && redraw_in!(e, left)   # to take them away
  elseif j.shows
    close_popup!(win, :job)
    j.shows = false
  end
  nothing
end

"""
The button beside the one that shows the sidebar. A click makes the sidebar
list the hidden files and folders too, the ones whose names start with a dot,
and another click leaves them out. Its eye has a line through it while they're
left out. It shows only while the sidebar lists files: a closed sidebar has none to
show, and nor has a list or a menu that code from the startup page shows in their place.
"""
hidden_button(e) = begin
  (e.panel && files_listed(e)) || return ()
  b = button(e, :hidden, "eye-slash")
  b.icon = e.hidden ? "eye" : "eye-slash"
  (b,)
end

"""
The buttons that go back to the file that showed before, and forward again.
They show only while the sidebar is open, at the right of the part of the top
bar that's over the sidebar.
"""
history_buttons(e) = e.panel || agent_shows(e) ? (button(e, :back, "arrow-left"), button(e, :forward, "arrow-right")) : ()   # in agent mode they're at the end of the agent's heading

"""
True when something fills the window in place of the page and the sidebar: a
takeoff, a schedule or a sketch, the lines of one as text, or a picture.
"""
filled(e) = full_block(e) !== nothing || lowered(e) !== nothing || zooming(e) !== nothing

# In agent mode the two ends of the bar lie over the dark panes, so they have the panes' colours. The middle is over the page's card.
# Over a web page the bar has the page's colours. See `bar_inks`.
describe(t::TopBar) = (inks = bar_inks(editor(t)); with_colours(() -> bar_row(t, inks), inks[3]))

bar_row(t::TopBar, inks=(nothing, nothing, nothing)) = begin
  e = editor(t)
  # While the page shows as slides or as an app, the bar is empty. It's still what you drag to move the window.
  (slideshow(e) === nothing && !as_app(e)) || return Row(width(grow=grow), height(TOPBAR_H), name="TopBar", offset_y=bar_top(e))
  b = e.buf
  # The buttons that code from the startup page adds for the page that shows, like the ones that answer an email,
  # and the ones of a page of a blog, which publish it
  more = (bar_parts(e)..., blog_part(e)...)
  checks = check_part(e)
  mode = mode_part(e)
  # A CSV file's table has the bar of a file that's only shown, with no lock: see "changing a CSV file"
  shown = readonly(b) || table_text(b)
  outside = shown ? outside_button(e) : ()
  # What a file that's only shown says of itself, like how many rows a CSV file has, can need more room than that.
  # The words move aside as the slider of the levels opens, so then they need its room too.
  grown = isempty(mode) ? 0px : slider_grown(e)
  said = shown && !isempty(b.about) ? spared_width(b.about, said_face()) + LOCK_W + 70px + grown : 0px
  side = max(isempty(more) && isempty(checks) ? 250px : 330px, said) + (isempty(mode) ? 0px : MODE_W)
  # What the page itself puts at the right end, like its buttons, has the room that it needs there, with the bar's
  # own parts. So a page's buttons never lie over the middle of the bar, which would take their clicks.
  own_ends = shown ? page_actions(e, page_object(e)) : ()
  isempty(own_ends) || (side = max(side, describe(Row(Alignment.Start, own_ends...), (9999px, 9999px)).width + 10px + said + LOCK_W +
                                         (isempty(mode) ? 0px : MODE_W) + (isempty(outside) ? 0px : 40px)))
  ended_rename!(e)
  # The two ends of the bar are as wide as each other, so the file's name is in the middle of the space beside
  # the sidebar. A window can be too narrow for that, with a wide sidebar or more buttons at its right end. Then the
  # left end gives up its room, so the right end stays in the window and the name keeps some room. With the
  # sidebar hidden, the left end keeps the room of its own two buttons. It always keeps the room that its
  # buttons need past the sidebar: while the sidebar slides open, it's narrower than its buttons.
  wide, _ = window_size(e)
  # Beside a panel at the right, the name is in the middle of the space between the sidebar and the panel. The
  # right end's buttons lie over the panel, so the right end needs room past the panel only for what the panel
  # can't hold, and then as much as the left end has.
  beside = right_view(e) === nothing ? 0px : right_w(e) * right_opened(e)
  wide -= beside
  side = max(side - beside, 0px)
  # While something fills the window, the sidebar isn't there. The bar has none of the sidebar's buttons
  # then, not the one that shows it either, and the file's name is in the middle of the window.
  full = filled(e)
  dark = agent_shows(e)
  showing = full ? 0.0 : dark ? 1.0 : opened(e)   # how far the sidebar shows, from 0 to 1. The agent's pane is always there.
  room = full ? 0px : side_w(e)      # how wide it is now. A side menu's compact form keeps some width while it's closed.
  # A side menu with a compact form is always there, so the bar's own button that shows and hides the sidebar goes.
  # The menu can have a button of its own in that place: see `side_button`.
  toggles = !full && side_least(e) == 0px
  own_button = full || toggles ? nothing : side_button(e.nodes[:side_menu])
  buttons = full ? () : ((toggles ? (button(e, :panel, "layout-sidebar"),) : own_button === nothing ? () : (own_button,))..., hidden_button(e)...)
  # The two arrows are at the sidebar's right edge, as far in as the right end of a row of its list. They
  # ride on that edge while the sidebar slides open, once it has passed the other buttons.
  arrows = full ? () : history_buttons(e)
  # Each button is 30px wide with 2px after it. The arrows have 8px after them, and so has the last
  # button when there are no arrows. The dot beside the sidebar's button has room of its own.
  need = mac_buttons_room(e) + 32px * length(buttons) + (isempty(arrows) ? 8px : 72px) + (toggles && waiting_dot(e) ? DOT_GAP + DOT_W : 0px)
  over = max(need, room)
  # Ladder's own name is in the middle of the bar, so the left end is as wide as the right. A kind of folder's own
  # path has all the room from the buttons over the sidebar, so it can start at the page's left edge.
  # A page that shows the path itself, as a SolidCraft design does in its toolbar, runs up to the window's top. The
  # bar then has only its left end, so that the page has the room of the bar's middle and its right end.
  inpage = crumb_in_page(e)
  crumb = inpage ? nothing : bread_crumb(e, window_object(e))
  own = !inpage && !(crumb isa Title)
  left = own || inpage ? max(need - room, 0px) :
                         max(150px * (1 - showing), need - room, min(side, wide - room - side - TITLE_ROOM))
  e.nodes[:bar_past_side] = left   # the page that shows the path leaves this room at its top left: see `bar_corner`
  # The slider never pushes the right end out of a narrow window, so the ladder stays under the mouse. The words
  # before the slider lose their start then: see `said_part`.
  side = min(side, max(side - grown, wide - room - left))
  beside > 0px && (side = max(side, min(left, wide - room - left)))
  inpage || (e.nodes[:title_room] = wide - room - left - side)   # the name is cut short to fit in it. In the page, the page says how much room it has.
  # The path that Ladder's own name opens into goes when a kind of folder shows something else there
  own && (w = window_of(e); w !== nothing && any(p -> p.key == :title_trail, popups(w)) && close_popup!(w, :title_trail))
  # The top bar lies over the top of the sidebar. The file's name is in the
  # middle of the space beside the sidebar, so it moves as the sidebar slides.
  # In agent mode the agent's heading is over the agent's pane. So it starts after the bar's buttons, or at the
  # sidebar's edge when that's further right, with its logo over the left edge of the talk.
  before_head = dark ? max(0px, menu_w(e) + PANE_LEFT - 7px - mac_buttons_room(e) - 32px * length(buttons)) : 0px
  # Each part is described and drawn with its own colours. With none but the page's, the bar needs no marks.
  marked = any(!isnothing, inks)
  mark(p) = marked ? (ColourMark(palette=p),) : ()
  start = with_colours(inks[1]) do
    Row(fixed(left + room), height(grow=grow),
      # The close, minimise and zoom buttons sit over the first 84px. In full screen they're hidden, and the buttons slide left.
      Row(fixed(over), height(grow=grow), padding(0px, 8px, 0px, mac_buttons_room(e)), child_gap=2px,
        buttons..., (dark ? (Box(fixed(before_head), height(grow=grow)), pane_head(agent_pane(e), e)...) : (Box(width(grow=grow)),))..., arrows...))   # in agent mode, the heading of the agent's pane
  end
  # Over a page that shows the path itself, the bar ends with its left end. The page under the rest takes the clicks there.
  inpage && return Row(fixed(left + room), height(TOPBAR_H), name="TopBar", offset_y=bar_top(e), mark(inks[1])..., start, mark(nothing)...)
  Row(width(grow=grow), height(TOPBAR_H), name="TopBar", offset_y=bar_top(e),
    mark(inks[1])...,
    start,
    mark(inks[2])...,
    with_colours(() -> Box(width(grow=grow), height(grow=grow), clip=true, crumb), inks[2]),
    mark(inks[3])...,
    Row(fixed(side + beside), height(grow=grow), justify=Alignment.End, padding(0px, 10px, 0px, 0px),
      # A file that's only shown has no words to count. The bar has a lock, after what the file says of itself. A file with levels
      # has the snake or the ladder too. It's after the words, which are longer at one level than at another,
      # so that it stays where it is, under the mouse, when a click on its slider changes the level. The
      # slider opens out to the left, and the parts before it move aside to make room.
      # The words have the room that the picture or the slider, the button after it and the edge leave them.
      # What covers the page's whole space, like a desktop, is no file that's only shown, so the bar says nothing of it.
      # Nor does it say anything when the window shows no file.
      # A folder of a blog that shows only its list has the blog's buttons in place of the words, and the
      # front page of a folder of news has its buttons: Interests and the one that gets the news
      # A page that has a panel at the right has the button that hides it, at the end
      (page_covered(e) || nofile(e) ? right_part(e) :
       readonly(b) && (page_object(e) isa BlogFolder || page_object(e) isa NewsFolder) ? (more..., mode..., outside...) :
       shown ? (own_ends..., (isempty(b.about) ? () : (said_part(b.about, side - LOCK_W - (isempty(outside) ? 0px : 40px) - (isempty(mode) ? 0px : MODE_W + grown)),))...,
                      (term_shown(e) || chat_shown(e) || !(readonly(b) || b.fixed) || !shows_lock(e, page_object(e)) ? () : (lock_part(e),))...,   # a terminal is yours to type in, and so are a session and a CSV file
                      mode...,
                      outside...) :
                     (more..., job_part(e)..., agent_part(e)..., checks..., diff_part(e)..., commit_part(e)..., mode...,
                      # A page that's never changed has a lock at the end
                      (b.fixed ? (lock_part(e),) : ())...,
                      # In agent mode, the button that hides the outline is at the end
                      (agent_shows(e) ? right_part(e) : ())...))...),
    mark(nothing)...)
end

"""
What the middle of the top bar shows while the window is about `o`: a node.
Ladder's own is the name of the file, which opens into the file's path while
the mouse is over it. A kind of folder has a method of this to show its own
path there: `bread_crumb(e, d)` for the folder, and `bread_crumb(e, d, o)`
for each thing `o` that it holds. Its room starts where the buttons over the
sidebar end, which is the sidebar's edge while the sidebar is open, and ends
at the buttons of the bar's right end. `e.nodes[:title_room]` is how wide
that was in the last frame.
"""
bread_crumb(e, o) = bread_crumb(e, o.parent, o)
bread_crumb(e, ::Nothing) = bread_crumb(e, nothing, nothing)
bread_crumb(e, d, o) = node!(Title, e, :title)

"The face of what a file that's only shown says of itself, in the top bar"
said_face() = Face(SANS, "", 12px, colours.dim, false)

"""
What a file that's only shown says of itself, for the top bar, in `room` at
most. With less room than the words need, their start is cut off. That
happens in a narrow window, when the slider of the levels takes their room as
it opens.
"""
said_part(words, room) = begin
  # A character that the font lacks is in a font that has it, like the ✳ that starts Claude Code's title
  tag = Box(height(28px), padding(8px, 0px), Row(Alignment.Center, spared(words, said_face())...))
  wide = spared_width(words, said_face()) + 16px
  wide <= room && return tag
  room = max(room, 0px)
  Row(fixed(room), height(28px), Alignment.Start, clip=true, Box(Alignment.Start, offset_x=room - wide, Row(fixed(wide), height(28px), tag)))
end

# --- the caret on a part of the page as a whole ------------------------------------------------
#
# In rich text the caret doesn't go into a part of the page that shows as one
# thing, like a form, a diagram or a picture. It goes onto the part, and a
# line goes round the part to show that. See `picked`. A click on a live block
# that no part of the block takes for itself puts the caret there too. See
# `pick_clicked!`. From there:
#
#   - Return gives the part the keyboard. A form's first field takes it, and
#     Tab goes to the next field. A plan, a schedule and a sketch take their
#     own keys. A picture, a diagram and a page of a PDF fill the window. The
#     front matter and a formula show as they're written. esc gives the
#     keyboard back to the page, with the caret still on the part.
#   - ↑ and ← go to the line before the part, and ↓ and → to the line after.
#   - ⌫ and ⌦ take the part away, and the commands that move, copy and delete
#     a line do that to all of its lines.
#   - ⌘E shows its code, with the caret in it.

const RING_OUT = 10.0   # px from the page's text to the line round a part that the caret is on

"Draw a line round the part of the page that the caret is on as a whole. The page's text is at `ui`."
ring_part(ctx, e, ui) = begin
  b = e.buf
  w = window_of(e)
  # The top of an email that has the keyboard has the line round it too
  held = w !== nothing && w.focus isa SemanticUI && head_in_charge(e) === w.focus
  run = held ? (1, 1) : picked(b)
  (run === nothing || isempty(e.layout)) && return
  # While the part has the keyboard, the field in it that takes the keys shows that itself
  (w === nothing || w.focus === e || held) || return
  it = item(e, run[1])
  it.first <= run[1] <= it.last || return
  across, wide = item_room(e, it)   # a part in a column of the page is as wide as the column
  top, high = num(ui.top + it.top) + 1, max(4.0, num(it.tall) - 2)
  # What a live block shows is LIVE_GAP under the top of its room, so the line is as far from it there as at the sides
  it.content isa Live && ((top, high) = (num(ui.top + it.top + LIVE_GAP) - RING_OUT, num(it.tall - 2LIVE_GAP) + 2RING_OUT))
  round_box(ctx, num(ui.left + across) - RING_OUT, top, num(wide) + 2RING_OUT, high, 8.0,
            fill=tint(colours.accent, 0.06), line=tint(colours.accent, 0.75), wide=1.5)
end

"The part of a component that takes the keys when the component has the keyboard, or nothing for a node that has none"
keyboard_part(node) = nothing
keyboard_part(v::TakeoffView) = part!(() -> PlanArea(of=v), v, :area)
keyboard_part(v::ScheduleView) = chart(v)
keyboard_part(v::SketchView) = sketch_area(v)

"The nodes that `pick` is true for among those that the window last drew in the part of the page that `it` shows, in the order of the layout"
nodes_in(pick, e, it::Item) = begin
  out = SemanticUI[]
  w = window_of(e)
  drawn = w === nothing ? nothing : scene(w)
  drawn === nothing && return out
  page = node!(Document, e, :document)
  top, bottom = e.origin[2] + it.top, e.origin[2] + it.top + it.tall
  left = e.origin[1] + item_room(e, it)[1]   # a part in a column of the page has other parts beside it
  right = left + item_room(e, it)[2]
  walk(ui, inpage) = begin
    ui isa ConcreteRect || return
    node = ui.from isa GeometricUI ? ui.from.from : nothing
    inpage |= node === page
    inpage && node isa SemanticUI && node !== page && top <= ui.top + ui.height / 2 < bottom && left - 1px <= ui.left + ui.width / 2 <= right + 1px && pick(node) &&
      !any(n -> n === node, out) && push!(out, node)
    foreach(child -> walk(child, inpage), ui.children)
  end
  walk(drawn, false)
  out
end

"""
What Return does while the caret is on a part of the page as a whole: it gives
the part the keyboard, in the way that suits the part. A part with nothing to
give it to, like a line across the page, stays as it is.
"""
enter_part!(e) = begin
  b = e.buf
  run = picked(b)
  (run === nothing || isempty(e.layout)) && return e
  it = item(e, run[1])
  # A part of another page has an editor of its own, with the caret at its start
  it.content isa Live && it.content.node isa Transclusion && return (enter_shown!(it.content.node); e)
  # A plan, a schedule and a sketch have keys of their own
  views = nodes_in(n -> keyboard_part(n) !== nothing, e, it)
  isempty(views) || return (focus(keyboard_part(first(views))); e)
  # A field to type in takes the keyboard, with its text selected, as Tab gives it
  fields = nodes_in(tabstop, e, it)
  isempty(fields) || return (focus(first(fields)); tabbed!(first(fields)); e)
  # A picture, a diagram or a page of a PDF fills the window
  fills = nodes_in(n -> n isa Fillable, e, it)
  isempty(fills) || return (zoom_in!(e, first(fills).what, first(fills).parent); e)
  # Front matter shows as it's written, with the caret after its first key
  if run[1] == 1 && kinds(b)[1].lang in (MATTER, TOML_MATTER)
    b.caret = b.anchor = line_end(b, min(2, run[2]))
    touch!(e)
  elseif (kinds(b)[run[1]].lang == MATH || kinds(b)[run[1]].lang in Columns.LANGS) && run[2] > run[1]
    # A formula shows its TeX, and a `columns` block its number, with the caret at the end of its first line
    b.caret = b.anchor = line_end(b, run[1] + 1)
    touch!(e)
  elseif maths_line(b, run[1])
    # The caret goes to the end of the TeX, before the $$ that closes it
    b.caret = b.anchor = (run[1], length(rstrip(b.lines[run[1]])) - 2)
    touch!(e)
  end
  e
end

# The window has no title bar, so you move it by dragging the top bar
onkey(t::TopBar, ::KeyPress{Keys.mouse_left}) = drag_window!(window_of(t))

# A right-click on the file's name shows the same menu as a right-click on the
# file in the sidebar. While the file is renamed from there, a text field with
# its name is where the name was.

describe(t::Title) = begin
  e = editor(t)
  b = e.buf
  title_trail!(e, t)   # the path shows over the bar while the mouse is over the name
  nofile(e) && return Box()   # a window with no file has no name to show
  if !isempty(b.path) && renaming(e, :title) == b.path
    # The field grows as the name gets longer
    wide = clamp(measure(Face(SANS, "", 13px, colours.ink, false), renamer(e).text) + 24px, 160px, 420px)
    return Box(width(wide), height(22px), padding(5px, 0px), radius(4px), Alignment.Start, background(colours.bg),
               border(1px, :solid, colours.accent), renamer(e))
  end
  edited = title_edited(e)
  # A name that's too long for its room in the bar ends in …, so that its start still shows
  room = get(e.nodes, :title_room, 10_000px) - (edited ? 70px : 16px)
  named = bar_name(e)
  # The headings over the caret and the component that it's on follow the name, as the path does. The name
  # stays in the middle while they change, so as much room as they take is empty before it. When there's
  # too little room, the biggest headings go first.
  parts = focus_parts(e)
  face = Face(SANS, "", 13px, colours.ink, false)
  while !isempty(parts) && measure(face, named) + 2parts_wide(parts) > room
    popfirst!(parts)
  end
  after = parts_wide(parts)
  e.nodes[:title_lead] = isempty(parts) ? 0px : after + 6px   # how far the name is from the left of the title, for the path
  Row(child_gap=6px, Alignment.Center,
    (isempty(parts) ? () : (Box(width(after)),))...,
    label(elide(named, 13px, max(room - 2after, 40px)), 13px, color=colours.dim),
    (edited ? (label("— edited", 13px, color=colours.faint),) : ())...,
    (isempty(parts) ? () : (title_parts(parts),))...)
end

"""
The headings and the component after the file's name in the top bar, each
after a ›, with the sizes that the path gives them. A heading shows only its
mark, like H2, so that the path stays short. A component's name is its kind,
like Sheet.
"""
title_parts(parts) =
  Row(Alignment.Center, name="Parts",
    # The room round each piece is a Box of its own: a label in a Row with padding is at the Row's top, not in its middle
    (Row(Alignment.Center,
       Box(width(TT_ARROW), height(16px), Alignment.Center, justify=Alignment.Center, Icon("chevron-right", size=8px, color=colours.faint)),
       Box(width(TT_PAD)),
       (x.level < 7 ? (heading_mark(x, colours.dim),) :
        (Icon(x.icon, size=11px, color=colours.faint), Box(width(4px)), label(elide(x.title, 13px, TT_PART), 13px, color=colours.dim)))...,
       Box(width(TT_PAD)))
     for x in parts)...)

"""
The name that the top bar shows: the page's title, or the name of its file.
A page from a web server has the last name of its address, like `City` or
`notes.md`, as the path shows it, and the path starts with the server's name.
"""
bar_name(e) = something(page_title(e), (at = web_address(e.buf.path); isempty(at) ? name(e.buf) : Remote.trail(at)[end][1]))

"""
True when the file's name says "— edited", in the top bar and in its path: the
file has changes that aren't saved. A page whose parts of other pages were
changed there is edited too, since ⌘S saves them with it, and so is a page of
a kind that has changes of its own, like a SolidCraft design.
"""
title_edited(e) = (b = e.buf; dirty(b) || any(dirty, shown_buffers(e)) || page_edited(e))

onkey(t::Title, ::KeyPress{Keys.mouse_right}) = begin
  e = editor(t)
  isempty(e.buf.path) || isremote(e.buf.path) || file_menu!(e, window_of(t), e.buf.path; at=:title)
  handled
end

# --- the path in the top bar -----------------------------------------------------------------
#
# Hold the mouse over the file's name in the top bar, and the name grows into
# its path: the name of each folder on the way to the file, like
# `~ › Desktop › Canon › Quotes.md`. The file's name stays where it was, and
# the folders come in to its left. The path floats over the rest of the bar,
# so nothing in the bar moves. When the window is too narrow for every name,
# the folders furthest from the file shrink to their first letter, as in the
# sidebar. The path goes when the mouse leaves it.
#
#   - A click on a folder opens it in the page: its own page, like the home
#     folder's or a desktop's, or a list of what's in it.
#   - A click on a › shows a list of what's in the folder before it, under
#     the ›. Rest the mouse on a folder in it, and a list of what's in that
#     folder opens beside it. Click a file to show it, or a folder to open it.
#     See "the list of a folder, under a › of the path".
#   - A right-click on a name shows the menu of that folder or file.
#   - A click on the file's name pins the path: it stays open when the mouse
#     leaves it, and while you open folders from it, until a second click on
#     the name. A pinned path is in the middle of the bar, where the file's
#     name is, and has no border or shadow, since it's part of the bar. Its
#     file's name isn't shaded, as no name is until the mouse is over it.
#     The pin is a setting: every window has it, and it stays the next time
#     the app opens.
#
# After the file's name come the headings over the caret, from the biggest,
# and the component that the caret is on: `welcome.md › H2 › Sheet`. A heading
# shows only its mark, so the path stays short, and a component its icon and
# the name of its kind, as the sidebar has them. When the caret is in inline
# code, a link, bold words or another run of a line that's drawn its own way,
# that run comes last, by its kind: `welcome.md › H2 › Code`. The bar shows them
# after the name all the time, and the path shows them too. A click on a
# heading of the path puts the caret on it. A page that's only read has no
# caret, and so none.
#
# A › follows the file's name and each heading of the path, as one follows
# each folder. A click on it shows a search of what's in the file, or under
# the heading: see "a search of a page's parts".
#
# So you can go anywhere from the top bar, with the sidebar hidden.

"The path of the file that the top bar shows, as names to click"
@def mutable struct TitleTrail <: SemanticUI
  path::String = ""
  steps::Vector{Tuple{String,String}} = Tuple{String,String}[]   # the name and the path of each step, as they show. "…" has no path.
  size::Any = nothing                                            # how big the window was when the path was put in place
  crumbs::Dict{String,Any} = Dict{String,Any}()                  # the TitleCrumb of each step, by its path
  arrows::Dict{String,Any} = Dict{String,Any}()                  # the TitleArrow after each folder, by the folder's path
  parts::Vector{Entry} = Entry[]                                 # the headings over the caret and the component that it's on, after the file's name
  marks::Dict{Int,Any} = Dict{Int,Any}()                         # the TitlePart of each of those
  drops::Dict{Int,Any} = Dict{Int,Any}()                         # the PartArrow after the file's name (0) and after each heading, by its place in `parts`
  centred::Bool = false                                          # true when it's in the middle of the bar, as a pinned path is
  title_at::Any = nothing                                        # where the file's name was in the bar when the path was put in place
end

"A heading over the caret, or the component that the caret is on, after the file's name in the path"
@def mutable struct TitlePart <: SemanticUI
  k::Int = 0   # which of the path's parts it is
end

"The › after the file's name, or after a heading, in the path. A click shows a search of what's in the file, or under the heading."
@def mutable struct PartArrow <: SemanticUI
  k::Int = 0   # 0 after the file's name, or the place in the path's parts of the heading that it's after
end

"One name of the path in the top bar: a folder, or the file at the end"
@def mutable struct TitleCrumb <: SemanticUI
  path::String = ""
  name::String = ""
  last::Bool = false
end

"The › after a folder's name in the top bar. A click shows a menu of what's in the folder."
@def mutable struct TitleArrow <: SemanticUI
  path::String = ""
end

const TT_H = 26px       # how tall the path is
const TT_PAD = 7px      # inside a name, on each side
const TT_ARROW = 14px   # how wide a › is
const TT_EDGE = 4px     # inside the path, at each end
const TT_WAIT = 0.15    # how many seconds the mouse is over the name before the path shows
const TT_MOST = 80      # the most things that a list of a folder shows
const TT_PART = 180px   # how wide the name of a component in the path can be
const TT_MARK = 14px    # how big a heading's mark is in the path, like H2

"""
True when a click on the file's name pinned the path open, so it stays when
the mouse leaves it. It's a setting: each window has the path pinned, and it
stays pinned the next time the app opens. A page that shows the path itself,
like a SolidCraft design in its toolbar, has little room for it, so there the
path shows only while the mouse is over the name: see `crumb_in_page`.
"""
trail_pinned(e) = e.pinned && !crumb_in_page(e)

"How wide each name of `steps` is in the top bar. The file's name is a little bolder."
title_widths(steps) = [measure(Face(SANS, i == length(steps) ? "Medium" : "", 13px, colours.ink, false), n) + 2TT_PAD
                       for (i, (n, _)) in enumerate(steps)]

"How wide the path of `steps` is, from edge to edge"
title_wide(steps) = sum(title_widths(steps)) + TT_ARROW * (length(steps) - 1) + 2TT_EDGE + 2px

"""
The mark of the heading `x` in the path, like H2. The letters of the mark sit
high in its icon, so it's 1px lower than the middle, to stand on the line of
the names beside it.
"""
heading_mark(x::Entry, color) = Box(padding(1px, 0px, 0px, 0px), Icon(x.icon, size=TT_MARK, color=color))

"How wide the heading or the component `x` is in the path: a heading's mark, or a component's icon and name"
part_width(x::Entry) = (x.level < 7 ? TT_MARK : measure(Face(SANS, "", 13px, colours.ink, false), elide(x.title, 13px, TT_PART)) + 15px) + 2TT_PAD

"How wide the headings and the component after the file's name are, with a › before each"
parts_wide(parts) = sum((part_width(x) + TT_ARROW for x in parts), init=0px)

"True when the path has a › after the file's name, to search the file: a Markdown page, of the Mac or from a web server"
searchable(e) = e.buf.view == :markdown && (isfile(e.buf.path) || isremote(e.buf.path))

"True when the path ends with a › after the name of the folder that the page shows, which lists what's in it, as each › after a folder does"
folder_arrow(e) = e.buf.view == :file && !isremote(e.buf.path) && isdir(e.buf.path)

"How wide the path's parts after the file's name are: each heading and the component, with the › before each, and the › after the last heading, or the › after a folder's name"
trail_parts_wide(e, parts) = searchable(e) ? parts_wide(parts) + (isempty(parts) || parts[end].level < 7 ? TT_ARROW : 0px) : folder_arrow(e) ? TT_ARROW : 0px

"""
The headings over the caret, from the biggest, then the component that the
caret is on, if it's on one, as the sidebar names them, then the run of text
that the caret is in, like inline code or a link (see `caret_run`). The path in
the top bar shows them after the file's name. A page with no caret has none:
one that's only read, one that Ladder only shows, and one that isn't Markdown.
"""
focus_parts(e) = begin
  b = e.buf
  (b.view == :markdown && !caretless(b)) || return Entry[]
  line = b.caret[1]
  ks = kinds(b)
  # The bar asks in every frame, and a code block in a language of its own makes `outline` look for a file, so it's kept until the text changes
  kept = get(e.nodes, :focus_outline, nothing)
  found = kept !== nothing && kept[1] === b && kept[2] == b.version ? kept[3] : (e.nodes[:focus_outline] = (b, b.version, outline(b)))[3]
  heads, on = Entry[], nothing
  for x in found
    x.line > line && break
    if x.level < 7
      # A heading takes the place of the last one of its size or smaller
      while !isempty(heads) && heads[end].level >= x.level
        pop!(heads)
      end
      push!(heads, x)
      on = nothing
    else
      # The caret is on a component from the line that opens its block to the one that closes it
      close = something(findnext(k -> k.kind == Kind.fence, ks, x.line + 1), length(b.lines))
      on = line <= close ? x : nothing
    end
  end
  on === nothing || push!(heads, on)
  run = caret_run(b)
  run === nothing ? heads : push!(heads, run)
end

"The icon of each kind of run of text in the path in the top bar, by the name that `span_kind` gives it"
const RUN_ICONS = Dict("Code" => "code", "Link" => "link-45deg", "Wiki link" => "link", "Footnote" => "superscript",
                       "Value" => "lightning-charge", "Comment" => "chat-left-text", "Highlighted" => "highlighter",
                       "Formula" => "plus-slash-minus", "Struck" => "type-strikethrough", "Bold" => "type-bold",
                       "Bold italic" => "type-bold", "Italic" => "type-italic")
push!(BLOCK_ICONS, values(RUN_ICONS)...)

"""
The run of text that the caret is in, as the last part of the path in the top
bar: inline code, a link, bold words, or another run that's drawn its own way,
as ⌘⌥ picks them. Its title is its kind, like Code, and its level is 8, deeper
than a component's. It's nothing on plain words, and on a line with no runs,
like a line of a code block. The caret is in a run from just before its first
letter to just after its last, inside its markup.
"""
caret_run(b) = begin
  line, col = b.caret
  kinds(b)[line].kind in (TEXT_KINDS..., Kind.table) || return nothing
  open = raw_part(b, line)
  for s in richspans(b, line)[2]
    (!s.markup && s.col <= col <= s.col + length(s.text)) || continue
    kind = span_kind(s.link, s, israw(b, line) || markup_shows(open, s.col, s.col + length(s.text)))
    kind === nothing || return Entry(line, 8, kind, RUN_ICONS[kind], line)
  end
  nothing
end

"""
The steps of `all` that fit in `room`. The names furthest from the file shrink
to their first letter, from the left, as the sidebar's trail does. If that
still doesn't fit, an … takes the place of names after the first, and last of
all the file's own name loses its middle.
"""
title_steps(all, room) = begin
  short = copy(all)
  initial(n) = startswith(n, '.') ? first(n, 2) : first(n, 1)
  for i in 2:length(short)-1
    title_wide(short) <= room && return short
    short[i] = (initial(short[i][1]), short[i][2])
  end
  while title_wide(short) > room && length(short) > 2 && short[2][1] != "…"
    deleteat!(short, 2)
    length(short) > 2 ? (short[2] = ("…", "")) : insert!(short, 2, ("…", ""))
  end
  while title_wide(short) > room && length(short) > 3
    deleteat!(short, 3)
  end
  name, at = short[end]
  k = length(name) ÷ 2
  while title_wide(short) > room && k > 2
    k -= 1
    short[end] = (first(name, k) * "…" * last(name, k), at)
  end
  short
end

"""
True when the path of the file can show over the top bar: the window has a
file, of the Mac or of a web server, whose name isn't being changed, and no
list like the file finder covers the page.
"""
trail_can_show(e) = begin
  path = e.buf.path
  # A page from a web server has a path too, from the server's name
  !nofile(e) && (isremote(path) || (isabspath(path) && isdir(dirname(path)))) && renaming(e, :title) != path && e.popup == :none
end

"""
Show the path of the file over the top bar while the mouse is over the file's
name, once it has been there for a moment, and take it away when the mouse
leaves the name and the path. ⌘F shows it too, with the search under the ›
after the file's name: see `find!`.
"""
title_trail!(e, t) = begin
  w = window_of(t)
  w === nothing && return
  path = e.buf.path
  open = any(p -> p.key == :title_trail, popups(w))
  # A list of a folder under a ›, or a search under one, keeps the path, until a click or Esc takes it away
  searching = any(p -> p.key == TS_KEY, popups(w))
  listing = searching || any(p -> p.content isa FolderList, popups(w))
  # A pinned path shows while the bar shows the file's name, with the mouse anywhere
  pinned = trail_pinned(e) && slideshow(e) === nothing && !as_app(e) && !screening(e)
  # ⌘F asked for the search, which opens once the path is in place
  asked = haskey(e.nodes, :search_asked)
  if !((ishovered(t) || listing || pinned || asked) && trail_can_show(e))
    delete!(e.nodes, :title_hover)
    delete!(e.nodes, :search_asked)
    listing && (close_folder_lists!(e, w); close_title_search!(e, w))
    open && close_popup!(w, :title_trail)
    return
  end
  searching && search_tick!(e, w)
  since = get!(e.nodes, :title_hover, time())
  !pinned && !asked && time() - since < TT_WAIT && return redraw_in!(e, TT_WAIT)
  kept = get(e.nodes, :title_trail, nothing)
  # The path follows the file's name when the name moves, as it does while a sidebar or git's panel slides open.
  # The name's place is from the last frame, so one more frame checks that the path is where the name is now.
  placed = open && kept isa TitleTrail && kept.path == path && kept.size == window_size(e) && kept.parts == focus_parts(e) &&
           (kept.centred || !pinned) && kept.title_at == title_place(e, t)
  placed || (show_title_trail!(e, t, w, path); redraw_in!(e, 0))
  # A top bar that hides moves the path while it slides out, and a move closes the search. So the search waits for the bar.
  asked && placed && !bar_sliding(e) && ask_search!(e, w, kept)
  # A window hears nothing when the mouse leaves it, so the path looks for itself. A pinned path stays, so it looks only while the mouse is on it.
  isempty(w.glfw) || (pinned && !ishovered(t)) || (sync_mouse!(w); redraw_in!(e, 0.2))
  nothing
end

"""
Where the file's name is in the top bar, or in a page that shows the path
itself: the left edge, the top and the width of its node, the room in it
before the name, how far the bar has slid, and whether the name says "— edited"
"""
title_place(e, t) = (r = rect(t); r === nothing ? nothing : (r.left, r.top, r.width, get(e.nodes, :title_lead, 0px), bar_top(e), title_edited(e)))

"How wide \"— edited\" is after the file's name in the path, with the room after it, or 0px when the file has no changes"
edited_wide(e) = title_edited(e) ? measure(Face(SANS, "", 13px, colours.ink, false), "— edited") + TT_PAD : 0px

"Put the path to `path` over the top bar, with the file's name where the bar shows it"
show_title_trail!(e, t, w, path) = begin
  r = rect(t)
  r === nothing && return
  # The path moves, so a list or a search under one of its › would point at nothing
  close_folder_lists!(e, w)
  any(p -> p.key == TS_KEY, popups(w)) && close_title_search!(e, w)
  wide = window_size(e)[1]
  # The Mac draws its close, minimise and zoom buttons over the window, so the path starts after them
  start = mac_buttons_room(e) + 4px
  # In a page that shows the path itself, like a design's toolbar, the path has the room that the page gives the name
  inpage = crumb_in_page(e)
  room = inpage ? min(get(e.nodes, :title_room, wide), wide - 8px - start) : wide - 8px - start
  all = trail_steps(path)
  all[end] = (bar_name(e), path)   # the file's name as the bar shows it
  parts = focus_parts(e)
  more = trail_parts_wide(e, parts) + edited_wide(e)   # what follows the file's name
  shown = title_steps(all, room - more)
  v = get!(() -> own!(t, TitleTrail()), e.nodes, :title_trail)
  v.path == path || (empty!(v.crumbs); empty!(v.arrows))
  # A pinned path is in the middle of the bar. After a click unpins it, it stays there until it closes, so the name doesn't move from under the mouse.
  v.centred = trail_pinned(e) || (v.centred && any(p -> p.key == :title_trail, popups(w)))
  v.path, v.steps, v.size, v.parts, v.title_at = path, shown, window_size(e), parts, title_place(e, t)
  widths = title_widths(shown)
  total = title_wide(shown) + more
  # How far the file's name is from the path's left edge
  before = sum(widths[1:end-1], init=0px) + TT_ARROW * (length(shown) - 1) + TT_EDGE + 1px + TT_PAD
  # The name is in the middle of its room in the bar, with the headings after it and as much room before it, so the middle of the name's node is the bar's
  x = v.centred ? r.left + r.width / 2 - total / 2 : r.left + get(e.nodes, :title_lead, 0px) - before
  # In the page, the name is in the middle of its room, and the path stays in that room, so it lies over nothing else of the page
  inpage && (lo = r.left + r.width / 2 - room / 2; x = clamp(x, lo, max(lo, lo + room - total)))
  x = clamp(x, start, max(start, wide - 8px - total))
  top = inpage ? r.top + (r.height - TT_H) / 2 : bar_top(e) + (TOPBAR_H - TT_H) / 2
  popup!(w, v, anchor=(x, top), placement=:below, gap=0px, width=total, key=:title_trail, modal=false, theme=menu_theme())
  nothing
end

# The path lies over the middle of the bar, so it has the bar's colours there: a web page's, when the bar has them
describe(v::TitleTrail) = with_colours(() -> trail_view(v), bar_inks(editor(v))[2])

trail_view(v::TitleTrail) = begin
  # The path goes when the bar stops showing the file's name: as slides, as an app, or under a video that fills the screen
  e = editor(v)
  (slideshow(e) !== nothing || as_app(e) || screening(e) || nofile(e)) && (w = window_of(v); w === nothing || close_popup!(w, :title_trail))
  arrow() = Box(width(TT_ARROW), height(grow=grow), Alignment.Center, justify=Alignment.Center,
                Icon("chevron-right", size=8px, color=colours.faint))
  parts = Any[]
  n = length(v.steps)
  for (i, (name, path)) in enumerate(v.steps)
    if i > 1
      # The › after a folder lists what's in it. The one after an … stands for folders that aren't shown, and one
      # after a folder of a web server only stands between two names, since a server doesn't say what's in a folder.
      before = v.steps[i-1][2]
      push!(parts, isempty(before) || isremote(before) ? arrow() : get!(() -> own!(v, TitleArrow(path=before)), v.arrows, before))
    end
    if isempty(path)
      push!(parts, Box(height(grow=grow), padding(TT_PAD, 0px), Alignment.Center, justify=Alignment.Center, label(name, 13px, color=colours.faint)))
    else
      c = get!(() -> own!(v, TitleCrumb(path=path)), v.crumbs, path)
      c.name, c.last = name, i == n
      push!(parts, c)
    end
  end
  # A file with changes that aren't saved says so after its name, as the name in the bar does
  title_edited(e) && push!(parts, Box(height(grow=grow), padding(0px, TT_PAD, 0px, 0px), Alignment.Center, justify=Alignment.Center,
                                      label("— edited", 13px, color=colours.faint)))
  # A folder that the page shows has a › after its name, which lists what's in it
  if folder_arrow(e) && n > 0 && !isempty(v.steps[n][2])
    at = v.steps[n][2]
    push!(parts, get!(() -> own!(v, TitleArrow(path=at)), v.arrows, at))
  end
  # The headings over the caret and the component that it's on. A › follows the file's name and each heading.
  if searchable(e)
    drop(k) = get!(() -> own!(v, PartArrow(k=k)), v.drops, k)
    push!(parts, drop(0))
    for k in eachindex(v.parts)
      push!(parts, get!(() -> own!(v, TitlePart(k=k)), v.marks, k))
      v.parts[k].level < 7 && push!(parts, drop(k))
    end
  end
  # Each name fills the height inside the border and 1px more, so its hover box has as much room above it as below.
  # A pinned path has no shadow and no border: it's part of the bar, not something that floats over the page. Its
  # border is clear, so that its names stay where they are.
  pinned = trail_pinned(e)
  Row(width(grow=grow), height(TT_H), padding(TT_EDGE, 1px), radius(7px), Alignment.Center, name="Path",
      background(trail_ground(e)), border(1px, :solid, pinned ? clear : colours.line), (pinned ? () : (lifted,))..., parts...)
end

"What the path lies on: the page's colour, as the bar has, or in a page that shows the path itself, the colour of its place there (see `page_crumb`)"
trail_ground(e) = crumb_in_page(e) ? get(e.nodes, :title_ground, colours.bg) : colours.bg

# A name is shaded only while the mouse is over it, so a pinned path doesn't look as if its file were chosen
describe(c::TitleCrumb) =
  Box(height(grow=grow), padding(TT_PAD, 0px), radius(5px), Alignment.Center, justify=Alignment.Center, name="Step",
      background(ishovered(c) ? colours.hover : clear),
    label(c.name, 13px, color=c.last ? colours.ink : colours.dim, weight=c.last ? "Medium" : ""))

describe(a::TitleArrow) = begin
  # It's shaded while its list shows under it
  w = window_of(a)
  dropped = w !== nothing && any(p -> p.content isa FolderList && p.content.arrow === a, popups(w))
  Box(width(TT_ARROW), height(grow=grow), radius(4px), Alignment.Center, justify=Alignment.Center, name="Arrow",
      background(ishovered(a) || dropped ? colours.hover : clear),
    Icon("chevron-right", size=8px, color=colours.faint))
end

describe(p::TitlePart) = begin
  v = p.parent
  p.k in eachindex(v.parts) || return Box(width(0px))
  x = v.parts[p.k]
  last = p.k == length(v.parts)
  # A heading shows only its mark, like H2, and a component its icon and its kind
  Row(height(grow=grow), padding(TT_PAD, 0px), radius(5px), child_gap=4px, Alignment.Center, name="Part",
      background(part_goes(p) && ishovered(p) ? colours.hover : clear),
    (x.level < 7 ? (heading_mark(x, last ? colours.ink : colours.dim),) :
     (Icon(x.icon, size=11px, color=colours.faint), label(elide(x.title, 13px, TT_PART), 13px, color=last ? colours.ink : colours.dim)))...)
end

describe(a::PartArrow) = begin
  # It's shaded while its search shows under it
  w = window_of(a)
  dropped = w !== nothing && any(p -> p.content isa TitleSearch && p.content.arrow === a, popups(w))
  Box(width(TT_ARROW), height(grow=grow), radius(4px), Alignment.Center, justify=Alignment.Center, name="Arrow",
      background(ishovered(a) || dropped ? colours.hover : clear),
    Icon("chevron-right", size=8px, color=colours.faint))
end

cursor(::TitleCrumb) = :hand
cursor(p::TitlePart) = part_goes(p) ? :hand : :arrow
cursor(::PartArrow) = :hand

"""
True when a click on the part `p` of the path goes somewhere. The last part is
where the caret is already, so it goes nowhere while the page shows. While a
view, a model or a block fills the window, every part goes back to the page.
"""
part_goes(p::TitlePart) = (v = p.parent; p.k in eachindex(v.parts) && (p.k < length(v.parts) || filled(editor(p))))

"""
Put the page back when something fills the window in its place: a view, a
picture or a model, a takeoff or a sketch, or the lines of a block. A click on
a heading or a component in the path in the top bar does this before it goes
to that heading or component in the page.
"""
unfill_page!(e) = begin
  v = zooming(e)
  v === nothing || zoom_out!(v, false)
  # Only this page's block: a block of another page still fills the window when Back goes to that page
  block = full_block(e)
  block === nothing || (block.full = false)
  lowered(e) === nothing || widen!(e)
  nothing
end

# A click on a heading puts the caret on it, as a click on it in the sidebar does. While something fills the window, the page comes back first.
onkey(p::TitlePart, ev::KeyPress{Keys.mouse_left}) = begin
  v = p.parent
  e = editor(p)
  part_goes(p) && (unfill_page!(e); focus(e); go_entry!(e, v.parts[p.k].line, v.parts[p.k].caret))
  handled
end
onkey(a::PartArrow, ev::KeyPress{Keys.mouse_left}) = open_title_search!(editor(a), ev.window, a)
cursor(::TitleArrow) = :hand

# A click on the file's name pins the path. In a page that shows the path itself the path is never pinned, so there it does nothing.
onkey(c::TitleCrumb, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(c)
  c.last ? (crumb_in_page(e) || pin_trail!(e)) : title_go!(e, ev.window, c.path)
  handled
end

"Pin the path in the top bar open, or let it close again when the mouse leaves it, in each window, and keep that in the settings"
pin_trail!(e) = (e.pinned = !e.pinned; save_settings!(e); nothing)
onkey(a::TitleArrow, ev::KeyPress{Keys.mouse_left}) = (open_folder_list!(editor(a), ev.window, a); handled)

# A right-click on a name shows the menu of its folder or file, as in the sidebar. Only the file's own name can be renamed in the bar.
onkey(c::TitleCrumb, ev::KeyPress{Keys.mouse_right}) = begin
  e = editor(c)
  isremote(c.path) && return handled   # a folder of a web server has no file menu, but the file of the browser folder that shows has
  c.last ? file_menu!(e, ev.window, c.path; at=:title) : file_menu!(e, ev.window, c.path; items=filter(!=("Rename"), file_menu(c.path)))
  handled
end

"""
Do what a choice of the folder or the file at `path` in the top bar does: a
file shows, and a folder opens in the page. A folder of a web server is asked
for, as a link to it is: its page shows when it has one in Markdown.
"""
title_go!(e, w, path) = (close_folder_lists!(e, w); close_popup!(w, :title_trail); isremote(path) ? get_page!(e, path) : open_folder!(e, path); nothing)

"What's in the folder `dir`, by name, its folders first, or nothing when it can't be read. Hidden ones, and the ones that you ignore, show while the sidebar shows them."
title_listing(e, dir) = begin
  names = try readdir(dir) catch; return nothing end
  ignored = Folders.ignored()
  filter!(n -> n != ".DS_Store" && (e.hidden || !left_out(joinpath(dir, n), ignored)), names)
  folder(n) = (p = joinpath(dir, n); isdir(p) && !ispackage(p))
  kinds = Dict(n => folder(n) for n in names)
  sort!(names, by=n -> (!kinds[n], lowercase(n)))
  (names, kinds)
end

# --- the list of a folder, under a › of the path ---
#
# A click on a › of the path shows what's in the folder before it, in a list
# under the ›. It looks like the other lists that float beside what they're
# for, like the list of a `find` block's kinds (see `float_list`), with a field
# at its top that has the keyboard. Its folders come first, then its files.
# What's on the way to the file that shows is in bold.
#
#   - Type in the field, and the list keeps the names that have the words typed.
#   - A click on a name, or Return, shows the file or opens the folder in the page.
#   - Rest the mouse on a folder, or press →, and a list of what's in it opens
#     beside it, as a submenu does. ← takes that list away again.
#   - The up and down arrows pick a name. Esc, a click somewhere else, or a
#     second click on the › takes every list away.
#
# The lists are popups with no parent in the window, so a key that they don't
# use goes to the field, and never on to the page.

const TT_LIST = :folder_list   # the key of the popup of the list under a ›. Each list beside it adds its level.
const TT_ROWS = 12             # the rows that a list shows before it scrolls
const TT_NARROW = 200px        # how wide a list is, at least
const TT_BROAD = 320px         # and at most
const TT_ROOM = 72px           # how much wider a list is than the longest name in it: its icon, its › and its edges
const TT_AIM = 18px            # how far the caret of the list under a › is from the list's left edge

"A list of what's in a folder, under a › of the path in the top bar, or beside a folder of such a list"
@def mutable struct FolderList <: SemanticUI
  of::Any = nothing                       # the window's Editor
  dir::String = ""
  level::Int = 1                          # 1 under a ›, 2 beside a folder of that list, and so on
  arrow::Any = nothing                    # the › that it drops from, at level 1
  all::Vector{String} = String[]          # what's in the folder, its folders first
  folders::Set{String} = Set{String}()    # which of those are folders
  names::Vector{String} = String[]        # the rows: those that have the words typed in the field, no more than TT_MOST
  more::Int = 0                           # how many more have the words typed
  unread::Bool = false                    # Ladder can't read the folder
  typed::String = ""                      # the words in the field when the rows were chosen
  pick::Int = 0                           # the row that Return takes, or 0
  shown::Int = 0                          # the row that the list last scrolled to
  rest::Tuple{Int,Float64} = (0, 0.0)     # the row that the mouse rests on, and since when
  open::String = ""                       # the folder whose list shows beside this one
  side::Symbol = :below                   # where the list is beside the ›, for its caret
  wide::Any = TT_NARROW
  parts::Dict{Any,Any} = Dict{Any,Any}()  # its field, its scroll and its rows
end

"A row of a list of a folder: one thing in the folder"
@def mutable struct FolderRow <: SemanticUI
  of::Any = nothing
  k::Int = 0
end

"The key of the popup of a list of a folder at `level`"
list_key(level) = level == 1 ? TT_LIST : Symbol(TT_LIST, "_", level)

"The lists of folders that show in the window `w`, from the one under the › on"
folder_lists(w) = sort!(FolderList[p.content for p in popups(w) if p.content isa FolderList], by=l -> l.level)

"""
Take away the lists of folders that are deeper than `level`, and with 0 every
one of them. The keyboard goes back to the page from the field of the list
under the ›.
"""
close_folder_lists!(e, w, level=0) = begin
  for l in folder_lists(w)
    l.level > level || continue
    close_popup!(w, list_key(l.level))
    l.level == 1 && left_list!(e, w, l)
  end
  foreach(l -> l.level == level && (l.open = ""), folder_lists(w))
  nothing
end

"Give the keyboard back to the page when the field of the list `l`, which has gone, has it"
left_list!(e, w, l) = (w.focus === get(l.parts, :field, nothing) && focus(e); nothing)

"Read what's in the folder of the list `l`, and make the list wide enough for its names"
read_folder!(l::FolderList) = begin
  found = title_listing(l.of, l.dir)
  l.unread = found === nothing
  names, kinds = something(found, (String[], Dict{String,Bool}()))
  l.all, l.folders = names, Set{String}(n for n in names if kinds[n])
  face = Face(SANS, "Semibold", 13px, colours.ink, false)
  l.wide = clamp(maximum((measure(face, n) for n in first(names, TT_MOST)), init=0px) + TT_ROOM, TT_NARROW, TT_BROAD)
  rows!(l, "")
end

"Make the rows of `l` the names that have every word of `typed`. Its first name that starts with them is picked."
rows!(l::FolderList, typed) = begin
  words = split(lowercase(typed))
  found = filter(n -> all(w -> occursin(w, lowercase(n)), words), l.all)
  l.typed, l.names, l.more = typed, first(found, TT_MOST), max(0, length(found) - TT_MOST)
  start = findfirst(n -> startswith(lowercase(n), lowercase(typed)), l.names)
  l.pick = isempty(l.names) ? 0 : isempty(typed) ? 1 : something(start, 1)
  l
end

"""
Show the list of what's in the folder before the › `a`, under it, with the
keyboard in its field. What's on the way to the file that shows is picked.
When the list shows already, the click on its › takes it away.
"""
open_folder_list!(e, w, a::TitleArrow) = begin
  was = [l for l in folder_lists(w) if l.level == 1]
  close_folder_lists!(e, w)
  !isempty(was) && only(was).arrow === a && return handled
  r = rect(a)
  r === nothing && return handled
  l = read_folder!(FolderList(of=e, dir=a.path, arrow=a))
  l.pick = something(findfirst(n -> inside_path(e.buf.path, joinpath(l.dir, n)), l.names), l.pick)
  field = l.parts[:field] = own!(l, TextInput(placeholder="Filter…", font_family=SANS, font_size=13px,
                                               look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text)))
  field.color = colours.ink
  # The caret at the top of the list points at the middle of the ›
  popup!(w, l, anchor=(r.left + r.width / 2 - TT_AIM, r.top, 0px, r.height), placement=:below, gap=8px, width=l.wide,
         key=TT_LIST, theme=component_theme(), onclose=() -> (close_folder_lists!(e, w); left_list!(e, w, l)))
  focus(field)
  redraw_in!(e, 0)   # the › stays shaded while its list shows
  handled
end

"""
Show what's in the folder of row `k` of the list `l` in a list beside the row,
with its first row in line with it: at the right of `l`, or at its left when
the window has no room at the right. With `keys`, as → opens it, its first
row is picked.
"""
open_beside!(l::FolderList, k; keys=false) = begin
  e, w = l.of, window_of(l)
  row = get(l.parts, (:row, k), nothing)
  (w === nothing || row === nothing || !(k in eachindex(l.names))) && return
  r, me = rect(row), rect(l)
  (r === nothing || me === nothing) && return
  close_folder_lists!(e, w, l.level)
  inner = read_folder!(FolderList(of=e, dir=joinpath(l.dir, l.names[k]), level=l.level + 1))
  keys || (inner.pick = 0)
  x = me.left + me.width + 2px
  x + inner.wide > window_size(e)[1] - 4px && (x = me.left - inner.wide - 2px)
  popup!(w, inner, anchor=(x, r.top - 7px, 0px, 0px), placement=:below, width=inner.wide, key=list_key(inner.level),
         theme=component_theme(), onclose=() -> (l.open = ""))
  l.open = inner.dir
  nothing
end

"""
After the mouse has rested on a row of `l` for a moment: a folder's list opens
beside it, or the list beside `l` goes when the row is a file's. A mouse that
only passes over rows on its way to the list beside changes nothing.
"""
rest_tick!(l::FolderList) = begin
  k, since = l.rest
  row = get(l.parts, (:row, k), nothing)
  (k in eachindex(l.names) && row !== nothing && ishovered(row)) || return
  want = l.names[k] in l.folders ? joinpath(l.dir, l.names[k]) : ""
  want == l.open && return
  wait = TT_WAIT - (time() - since)
  wait > 0 && return redraw_in!(l.of, wait + 0.01)
  w = window_of(l)
  isempty(want) ? (w === nothing || close_folder_lists!(l.of, w, l.level)) : open_beside!(l, k)
  nothing
end

describe(l::FolderList) = begin
  field = get(l.parts, :field, nothing)
  if field !== nothing
    # New words in the field choose the rows again, and the list beside goes
    typed = String(strip(field.text))
    typed == l.typed || (rows!(l, typed); w = window_of(l); w === nothing || close_folder_lists!(l.of, w, l.level))
  end
  rest_tick!(l)
  n, high = length(l.names), FLOAT_ROW
  body = if n == 0
    float_none(l.unread ? "Ladder can't read this folder" : isempty(l.all) ? "This folder is empty" : "Nothing has that name")
  else
    scroll = get!(() -> Scroll(width(grow=grow)), l.parts, :scroll)
    # Half a row at the bottom says that the list goes on
    scroll.height = height(n <= TT_ROWS ? n * high : TT_ROWS * high - high / 2)
    l.shown == l.pick || (l.shown = l.pick; l.pick > 0 && scroll_into_view!(scroll, high * (l.pick - 1), high * l.pick))
    reuse!(scroll, Column(width(grow=grow), Alignment.Start, [get!(() -> own!(l, FolderRow(of=l, k=k)), l.parts, (:row, k)) for k in 1:n]...))
  end
  more = l.more == 0 ? () : (float_none(l.level == 1 ? "$(l.more) more. Type a name to find them." : "$(l.more) more"),)
  float_list(field, Column(width(grow=grow), Alignment.Start, body, more...), name="Folder")
end

placed!(l::FolderList, side) = (l.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, l::FolderList) = l.arrow === nothing ? nothing : caret(ctx, ui, l.side, rect(l.arrow))

describe(r::FolderRow) = begin
  l = r.of
  r.k in eachindex(l.names) || return Box(height(0px))
  c = found_colours()
  name = l.names[r.k]
  path = joinpath(l.dir, name)
  folder = name in l.folders
  Row(width(grow=grow), height(FLOAT_ROW), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center, name="Thing",
      background(l.pick == r.k || l.open == path ? c.pick : c.frame),
    Icon(folder ? "folder" : file_icon(path), size=13px, color=c.dim),
    Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true,
      label(elide(name, 13px, l.wide - TT_ROOM), 13px, color=c.ink, weight=inside_path(l.of.buf.path, path) ? "Semibold" : "")),
    (folder ? (Icon("chevron-right", size=8px, color=c.dim),) : ())...)
end

cursor(::FolderRow) = :hand

# The mouse picks the row that it's over, as the arrow keys do
onmouse(r::FolderRow, ::MouseMove) = begin
  l = r.of
  l.pick = l.shown = r.k   # it's in sight already, so the list doesn't scroll to it
  l.rest[1] == r.k || (l.rest = (r.k, time()); redraw_in!(l.of, TT_WAIT + 0.01))
  handled
end

onkey(r::FolderRow, ev::KeyPress{Keys.mouse_left}) = begin
  l = r.of
  r.k in eachindex(l.names) && title_go!(l.of, ev.window, joinpath(l.dir, l.names[r.k]))
  handled
end

# The list that opened last sees a key before the field does
onkey(l::FolderList, ev::KeyPress{Keys.down}) = unmodified(ev) ? (isempty(l.names) || (l.pick = min(l.pick + 1, length(l.names))); handled) : nothing
onkey(l::FolderList, ev::KeyPress{Keys.up}) = unmodified(ev) ? (isempty(l.names) || (l.pick = max(l.pick - 1, 1)); handled) : nothing
onkey(l::FolderList, ev::KeyPress{Keys.enter}) =
  unmodified(ev) ? (l.pick in eachindex(l.names) && title_go!(l.of, ev.window, joinpath(l.dir, l.names[l.pick])); handled) : nothing
onkey(l::FolderList, ev::KeyPress{Keys.right}) =
  unmodified(ev) && l.pick in eachindex(l.names) && l.names[l.pick] in l.folders ? (open_beside!(l, l.pick; keys=true); handled) : nothing
onkey(l::FolderList, ev::KeyPress{Keys.left}) = unmodified(ev) && l.level > 1 ? (close_folder_lists!(l.of, ev.window, l.level - 1); handled) : nothing
onkey(l::FolderList, ev::KeyPress{Keys.escape}) = unmodified(ev) ? (close_folder_lists!(l.of, ev.window); handled) : nothing

# --- a search of a page's parts, from a › of the path in the top bar ---
#
# In the path in the top bar, a › follows the file's name and each heading. A
# click on it shows a search of what's in the file, or under the heading. It
# floats under the ›, as the list of a folder does under a folder's ›, and the
# path stays while it shows.
#
#   - With nothing typed and no kinds chosen, it lists the headings and the
#     components there, as the sidebar does. A click on one goes to it.
#   - The kinds are those of a `find` block (find.jl): to-do items, headings,
#     table rows, code blocks, sheets, sketches and the rest. The Kinds button
#     lists them, with a tick beside each kind that's chosen. A click on a row
#     ticks it or takes its tick away, and the list stays for more. Each kind
#     that's chosen shows in the field as a chip. A click on a chip takes it away.
#   - Kinds and words go together, and either can be left out. Kinds with no
#     words list every thing of those kinds. Words with no kinds find any line,
#     and any block that has them in its own lines.
#   - The › that was clicked says where the search looks: the whole file, or
#     under its heading. The search has no button to choose another place.
#   - The up and down arrows pick a row, and Return or a click shows it. Tab
#     opens the list of kinds. Backspace in an empty field takes the last kind
#     away. Esc, or a click somewhere else, closes the search.

const TS_KEY = :title_search          # the key of the search's popup
const TS_MENU = :title_search_menu    # and of the list of kinds that its Kinds button opens
const TS_WIDE = 480px                 # how wide the search is, at most
const TS_MOST = 200                   # the most rows that its list shows
const TS_ROWS = 12                    # the rows that show before the list scrolls

"A search of what's in a page, or under one of its headings, under a › of the path in the top bar"
@def mutable struct TitleSearch <: SemanticUI
  of::Any = nothing                     # the window's Editor
  arrow::Any = nothing                  # the › that it hangs from
  page::String = ""                     # the file that the path ends with
  under::Int = 0                        # the line of the heading that it looks under, or 0 for the whole file
  wants::Vector{Symbol} = Symbol[]      # the kinds of thing that it finds, in the order they were chosen
  wide::Any = TS_WIDE                   # how wide it is
  key::Any = nothing                    # what the rows were worked out for
  rows::Vector{Any} = Any[]             # what it shows: a thing that was found, or a heading or component that's there
  things::Int = 0                       # how many things it found
  total::Int = 0                        # how many rows its list would have with no limit
  pick::Int = 0                         # the row that Return shows
  shown::Int = 0                        # the row that the list last scrolled to
  side::Symbol = :below                 # the side of the › that it's on, for its caret
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its field, its chips, its Kinds button, its scroll and its rows
end

"A kind that the search finds, in its field. A click takes it away."
@def mutable struct SearchChip <: SemanticUI
  of::Any = nothing
  kind::Symbol = :todo
end

"The button at the right of the search's field, which chooses the kinds of thing to find"
@def mutable struct SearchButton <: SemanticUI
  of::Any = nothing
end

"A row of the search's list"
@def mutable struct SearchFound <: SemanticUI
  of::Any = nothing
  k::Int = 0
end

"The list of kinds under the search's Kinds button, with a field at its top that filters it"
@def mutable struct SearchMenu <: SemanticUI
  of::Any = nothing                       # the search
  button::Any = nothing                   # the button that it's under
  rows::Vector{Any} = Any[]               # the rows that have the words in its field
  typed::String = ""                      # the words in its field when the rows were chosen
  pick::Int = 1                           # the row that Return takes
  shown::Int = 0                          # the row that the list last scrolled to
  side::Symbol = :bottom                  # the side of the button that it's on
  parts::Dict{Any,Any} = Dict{Any,Any}()  # its field, its scroll and its rows
end

"A row of that list: a kind of thing"
@def mutable struct SearchOption <: SemanticUI
  of::Any = nothing
  k::Int = 0
end

"The field of the search, where the words go"
search_field(s::TitleSearch) = s.parts[:field]

"A text field of the search or of the list of kinds under its button"
search_box(placeholder) = begin
  f = TextInput(placeholder=placeholder, font_family=SANS, font_size=13px,
                look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
  f.color, f.placeholder_color = colours.ink, colours.faint
  f
end

"The icon of a kind of thing that the search finds. A kind of block has the icon that the sidebar shows beside such a block."
search_icon(k::Symbol) =
  k == :todo ? "square" : k == :done ? "check-square" : k == :heading ? "type-h1" :
  k == :paragraph ? "text-paragraph" : k == :bullet ? "list-ul" : k == :ordered ? "list-ol" : k == :blockquote ? "quote" :
  k == :table ? "table" : k == :link ? "link-45deg" : k == :picture ? "image" : Searches.isblock(k) ? block_icon(k) : "text-left"

"What the search calls things of the kind `k` in its list of kinds and its chips: To-do items"
search_kinds_name(k::Symbol) = Searches.title(k)

"What the search calls one thing of the kind `k`, at the right of its row: To-do item"
search_kind_name(k::Symbol) = uppercasefirst(Searches.WHATS[k].one)

"The heading that the search looks under, as the sidebar has it, or nothing"
search_heading(s::TitleSearch) = s.under == 0 ? nothing : (i = findfirst(x -> x.line == s.under, outline(s.of, s.page)); i === nothing ? nothing : outline(s.of, s.page)[i])

"The name of the page at `path` in the search: its file's name, or the last name of the address of a page from a web server"
search_file_name(path) = (at = web_address(path); isempty(at) ? basename(path) : Remote.trail(at)[end][1])

"The name of the place where the search looks: its heading, or its file"
search_place(s::TitleSearch) =
  s.under > 0 ? (h = search_heading(s); h === nothing ? search_file_name(s.page) : h.title) : search_file_name(s.page)

"The lines of the page that are under the heading on line `under`: up to the next heading as big as it or bigger. With 0, every line."
under_lines(ks, under) = begin
  (0 < under <= length(ks) && ks[under].kind == Kind.heading) || return 1:length(ks)
  stop = findnext(l -> l.kind == Kind.heading && l.level <= ks[under].level, ks, under + 1)
  under:(stop === nothing ? length(ks) : stop - 1)
end

"""
Show a search of what's in the file, or under the heading, that the › `a` of
the path follows, under the ›, with the keyboard in its field. A second click
on the › takes it away.
"""
open_title_search!(e, w, a::PartArrow) = begin
  was = [p.content for p in popups(w) if p.key == TS_KEY]
  close_title_search!(e, w)
  !isempty(was) && only(was).arrow === a && return handled
  close_folder_lists!(e, w)
  v = a.parent
  r = rect(a)
  r === nothing && return handled
  under = a.k in eachindex(v.parts) ? v.parts[a.k].line : 0
  s = TitleSearch(of=e, arrow=a, page=e.buf.path, under=under)
  s.parts[:field] = own!(s, search_box(""))
  s.wide = min(TS_WIDE, window_size(e)[1] - 16px)
  e.nodes[:title_search] = s
  # The caret at the top of the search points at the middle of the ›
  popup!(w, s, anchor=(r.left + r.width / 2 - TT_AIM, r.top, 0px, r.height), placement=:below, gap=8px, width=s.wide,
         key=TS_KEY, theme=component_theme(), onclose=() -> (close_popup!(w, TS_MENU); left_search!(e, w)))
  focus(search_field(s))
  redraw_in!(e, 0)   # the › stays shaded while its search shows
  handled
end

placed!(s::TitleSearch, side) = (s.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, s::TitleSearch) = caret(ctx, ui, s.side, rect(s.arrow))

"Take the search away, with the list under one of its buttons. The keyboard goes back to the page."
close_title_search!(e, w) = (close_popup!(w, TS_MENU); close_popup!(w, TS_KEY); left_search!(e, w))

"Give the keyboard back to the page when a field of the search, which has gone, has it"
left_search!(e, w) = begin
  s = get(e.nodes, :title_search, nothing)
  f = w.focus
  s isa TitleSearch && (f === search_field(s) || (f isa SemanticUI && f.parent isa SearchMenu)) && focus(e)
  nothing
end

"""
⌘F, and Find… in the page's menu. On a page of Markdown, the path shows over
the top bar with the search under the › after the file's name, which looks
through the whole page. What's selected goes into its field, if that's part of
one line. While the search shows, ⌘F selects the words in its field. A file
with no › to search from, like a file of code, gets the bar that finds text in
the page instead: see `open_find!`.
"""
find!(e, w=window_of(e)) = begin
  w === nothing && return open_find!(e)
  s = get(e.nodes, :title_search, nothing)
  if s isa TitleSearch && any(p -> p.key == TS_KEY, popups(w))
    f = search_field(s)
    f.anchor, f.cursor = 0, length(f.text)
    focus(f)
    return nothing
  end
  (searchable(e) && trail_can_show(e) && slideshow(e) === nothing && !as_app(e) && !screening(e)) || return open_find!(e)
  b = e.buf
  lo, hi = selection(b)
  e.nodes[:search_asked] = selecting(b) && lo[1] == hi[1] ? rest(head(b.lines[lo[1]], hi[2]), lo[2]) : ""
  redraw_in!(e, 0)
  nothing
end

"Open the search that ⌘F asked for, under the › after the file's name of the path `v`, once the › has a place"
ask_search!(e, w, v::TitleTrail) = begin
  a = get(v.drops, 0, nothing)
  (a !== nothing && rect(a) !== nothing) || return redraw_in!(e, 0)
  words = pop!(e.nodes, :search_asked)
  open_title_search!(e, w, a)
  s = get(e.nodes, :title_search, nothing)
  if s isa TitleSearch && s.arrow === a
    f = search_field(s)
    f.text = words
    f.anchor, f.cursor = 0, length(words)
  end
  nothing
end

"""
What happens to the search in each frame, before the window is laid out: the
list of kinds goes when a click somewhere else took the keyboard from the
list's field.
"""
search_tick!(e, w) = begin
  for p in popups(w)
    p.key == TS_MENU && w.focus !== p.content.parts[:field] && close_popup!(w, TS_MENU)
  end
  nothing
end

"""
Work out what the search shows, when its words or its kinds have changed, or
when a page has changed in Ladder. It looks through the page, or the part of
it under its heading.
"""
search_rows!(s::TitleSearch) = begin
  e = s.of
  words = String.(split(lowercase(search_field(s).text)))
  # ⌘Z gives a page the version that it had before, so the version of each open page is looked at, not only the newest one
  key = (s.under, copy(s.wants), words, hash([b.version for b in values(e.buffers)]))
  key == s.key && return s
  s.key = key
  rows, things, total = Any[], 0, 0
  at = isfile(s.page) ? mtime(s.page) : 0.0
  lines, ks, _ = page_text(e, s.page, at)
  span = under_lines(ks, s.under)
  if isempty(words) && isempty(s.wants)
    # Nothing asked: the headings and the components there, each in the heading over it, as the sidebar has them
    over = Int[]
    for x in outline(e, s.page)
      x.line in span && x.line != s.under || continue
      while !isempty(over) && over[end] >= x.level
        pop!(over)
      end
      push!(rows, (kind=:entry, path=s.page, x=x, depth=length(over)))
      x.level < 7 && push!(over, x.level)
    end
    total = length(rows)
  else
    for (m, as) in Searches.search(s.wants, words, s.page, lines, ks)
      m.line in span || continue
      things += 1
      length(rows) < TS_MOST && push!(rows, (kind=:thing, path=s.page, m=m, as=as))
    end
    total = things
  end
  s.rows, s.things, s.total = rows, things, total
  s.pick = isempty(rows) ? 0 : 1
  s.shown = 0
  s
end

"True when the search shows what's there, because nothing is asked"
listing_parts(s::TitleSearch) = !isempty(s.rows) && s.rows[1].kind == :entry

"What the foot of the search's list says: how many things it found, and where"
search_summary(s::TitleSearch) = begin
  place = search_place(s)
  where = s.under > 0 ? "under $place" : "in $place"
  s.things == 0 && return "Nothing found $where."
  more = s.total > length(s.rows) ? " The list shows the first $(length(s.rows)) rows." : ""
  "$(s.things == 1 ? "1 thing" : "$(s.things) things") $where." * more
end

"Show what row `k` of the search has, and close the search: a heading or a component goes to it, and a thing shows in its page"
search_go!(s::TitleSearch, w, k) = begin
  k in eachindex(s.rows) || return handled
  row = s.rows[k]
  e = s.of
  close_title_search!(e, w)
  # A view or a block that fills the window goes back in the page, so the page shows what was chosen
  row.path == e.buf.path && unfill_page!(e)
  if row.kind == :entry
    row.path == e.buf.path || open!(e, row.path)
    focus(e)
    go_entry!(e, row.x.line, row.x.caret)
  else
    visit!(e, row.path, row.m)
  end
  handled
end

describe(s::TitleSearch) = begin
  field = search_field(s)
  place = search_place(s)
  field.placeholder = s.under > 0 ? "Search under " * place : "Search " * place
  search_rows!(s)
  c = found_colours()
  chips = [get!(() -> own!(s, SearchChip(of=s, kind=k)), s.parts, (:chip, k)) for k in s.wants]
  kinds = get!(() -> own!(s, SearchButton(of=s)), s.parts, :kinds)
  top = Row(width(grow=grow), height(grow=grow), child_gap=5px, Alignment.Center,
    Icon("search", size=12px, color=c.dim), chips...,
    Box(width(grow=grow), height(grow=grow), field),
    kinds)
  float_list(top, Column(width(grow=grow), Alignment.Start, search_list(s)...), name="Search")
end

"The rows under the search's field, and the line under them that says what was found"
search_list(s::TitleSearch) = begin
  c = found_colours()
  n, high = length(s.rows), FLOAT_ROW
  if n == 0
    asked = !isempty(split(search_field(s).text)) || !isempty(s.wants)
    return (float_none(asked ? search_summary(s) : "There are no headings or components here"),)
  end
  scroll = get!(() -> Scroll(width(grow=grow)), s.parts, :scroll)
  # Half a row at the bottom says that the list goes on
  scroll.height = height(n <= TS_ROWS ? n * high : TS_ROWS * high - high / 2)
  s.shown == s.pick || (s.shown = s.pick; s.pick > 0 && scroll_into_view!(scroll, high * (s.pick - 1), high * s.pick))
  reuse!(scroll, Column(width(grow=grow), Alignment.Start, [get!(() -> own!(s, SearchFound(of=s, k=k)), s.parts, (:row, k)) for k in 1:n]...))
  listing_parts(s) && return (scroll,)
  (scroll, Box(width(grow=grow), height(1px), background(c.rule)), float_none(search_summary(s)))
end

describe(r::SearchFound) = begin
  s = r.of
  r.k in eachindex(s.rows) || return Box(height(0px))
  row = s.rows[r.k]
  c = found_colours()
  back = background(s.pick == r.k ? c.pick : c.frame)
  if row.kind == :entry
    # A heading or a component, under the heading over it, as in the sidebar
    x = row.x
    return Row(width(grow=grow), height(FLOAT_ROW), padding(0px, 8px, 0px, 8px + 14px * row.depth), radius(6px), child_gap=8px,
               Alignment.Center, name="Part", back,
      Icon(x.icon, size=12px, color=c.dim),
      Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true,
        label(elide(x.title, 13px, s.wide - 60px - 14px * row.depth), 13px, color=c.ink)))
  end
  m, as = row.m, row.as
  kind = search_kind_name(as)
  room = s.wide - 120px - measure(Face(SANS, "", 12px, c.ink, false), kind)
  Row(width(grow=grow), height(FLOAT_ROW), padding(0px, 8px, 0px, 8px), radius(6px), child_gap=8px,
      Alignment.Center, name="Thing", back,
    Icon(search_icon(as), size=12px, color=c.dim),
    Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true,
      label(elide(m.text, 13px, room), 13px, color=m.kind == :done ? c.dim : c.ink, weight=as == :heading ? "Semibold" : "")),
    Box(label(kind, 12px, color=c.dim)))
end

describe(c::SearchChip) = begin
  f = found_colours()
  Row(height(20px), padding(0px, 4px, 0px, 6px), radius(5px), child_gap=4px, Alignment.Center, name="Kind",
      background(ishovered(c) ? f.line : f.pick),
    Icon(search_icon(c.kind), size=11px, color=f.dim),
    label(search_kinds_name(c.kind), 12px, color=f.ink),
    Icon("x", size=12px, color=f.dim))
end

describe(b::SearchButton) = begin
  s = b.of
  c = found_colours()
  w = window_of(b)
  dropped = w !== nothing && any(p -> p.content isa SearchMenu && p.content.button === b, popups(w))
  Row(height(20px), padding(6px, 0px), radius(5px), child_gap=4px, Alignment.Center, name="Kinds",
      background(ishovered(b) || dropped ? c.pick : clear),
    Icon("funnel", size=11px, color=c.dim),
    label(isempty(s.wants) ? "Any kind" : "Kinds", 12px, color=c.dim),
    Icon("chevron-down", size=8px, color=c.dim))
end

cursor(::Union{SearchFound,SearchChip,SearchButton,SearchOption}) = :hand

# The mouse picks the row that it's over, as the arrow keys do. It's in sight already, so the list doesn't scroll to it.
onmouse(r::SearchFound, ::MouseMove) = (s = r.of; s.pick = s.shown = r.k; handled)
onkey(r::SearchFound, ev::KeyPress{Keys.mouse_left}) = search_go!(r.of, ev.window, r.k)
onkey(c::SearchChip, ev::KeyPress{Keys.mouse_left}) = (s = c.of; filter!(!=(c.kind), s.wants); focus(search_field(s)); handled)
onkey(b::SearchButton, ev::KeyPress{Keys.mouse_left}) = open_search_menu!(b.of, ev.window)

# The search sees a key before its field does
onkey(s::TitleSearch, ev::KeyPress{Keys.down}) = unmodified(ev) ? (isempty(s.rows) || (s.pick = min(s.pick + 1, length(s.rows))); handled) : nothing
onkey(s::TitleSearch, ev::KeyPress{Keys.up}) = unmodified(ev) ? (isempty(s.rows) || (s.pick = max(s.pick - 1, 1)); handled) : nothing
onkey(s::TitleSearch, ev::KeyPress{Keys.enter}) = unmodified(ev) ? search_go!(s, ev.window, s.pick) : nothing
onkey(s::TitleSearch, ev::KeyPress{Keys.escape}) = unmodified(ev) ? (close_title_search!(s.of, ev.window); handled) : nothing
onkey(s::TitleSearch, ev::KeyPress{Keys.tab}) = unmodified(ev) ? open_search_menu!(s, ev.window) : nothing
# Backspace in an empty field takes the last kind away
onkey(s::TitleSearch, ev::KeyPress{Keys.backspace}) =
  unmodified(ev) && isempty(search_field(s).text) && !isempty(s.wants) ? (pop!(s.wants); handled) : nothing
# The key that finds, like ⌘F, selects the words in the field. The page never sees it, since the search has no parent there.
onkey(s::TitleSearch, ev::KeyPress{K}) where K =
  get(keys_now(s.of).commands, (Stroke(ev.window.keys & HELD, K),), nothing) == :find ? (find!(s.of, ev.window); handled) : nothing

# --- the list of kinds under the search's Kinds button ---

"""
The rows of the list of kinds: any kind, then each kind of a `find` block. A
row is found by any name that a `find` block knows its kind by.
"""
kind_options() =
  Any[(key=nothing, name="Any kind", icon="asterisk", words=["any kind", "all", "every"]);
      [(key=k, name=search_kinds_name(k), icon=search_icon(k), words=[Searches.WHATS[k].names..., Searches.WHATS[k].langs...])
       for k in keys(Searches.WHATS)]]

"Make the rows of the list `m` those that have every word of `typed`. The first whose name starts with them is picked."
menu_rows!(m::SearchMenu, typed) = begin
  m.typed = typed
  m.rows = filter(r -> choice_matches(r, typed), kind_options())
  m.pick = isempty(m.rows) ? 0 : something(findfirst(r -> startswith(lowercase(r.name), lowercase(typed)), m.rows), 1)
  m
end

"""
Show the list of kinds under the search's Kinds button. The keyboard goes to
the field at its top. A second click on the button takes the list away.
"""
open_search_menu!(s::TitleSearch, w) = begin
  was = any(p -> p.key == TS_MENU, popups(w))
  close_search_menu!(s, w)
  was && return handled
  b = s.parts[:kinds]
  r = rect(b)
  r === nothing && return handled
  m = SearchMenu(of=s, button=b)
  m.parts[:field] = own!(m, search_box("Filter…"))
  menu_rows!(m, "")
  # A button in a popup is anchored by where it is: a popup anchored at a node follows it in the window's own parts, and this one isn't there
  popup!(w, m, anchor=(r.left, r.top, r.width, r.height), placement=:bottom, gap=9px, width=250px,
         key=TS_MENU, theme=component_theme(), onclose=() -> left_search!(s.of, w))
  focus(m.parts[:field])
  handled
end

"Take the list of kinds away. The keyboard goes back to the search's field."
close_search_menu!(s::TitleSearch, w) = begin
  f = w.focus
  close_popup!(w, TS_MENU)
  f isa SemanticUI && f.parent isa SearchMenu && focus(search_field(s))
  handled
end

"""
Take row `k` of the list `m`. A kind is chosen, or its choice is taken back,
and the list stays, so that more can be chosen. Any kind takes every choice
back.
"""
take_option!(m::SearchMenu, w, k) = begin
  k in eachindex(m.rows) || return handled
  s, key = m.of, m.rows[k].key
  key === nothing ? empty!(s.wants) : key in s.wants ? filter!(!=(key), s.wants) : push!(s.wants, key)
  handled
end

describe(m::SearchMenu) = begin
  f = m.parts[:field]
  typed = String(strip(f.text))
  typed == m.typed || menu_rows!(m, typed)
  n, high = length(m.rows), FLOAT_ROW
  body = if n == 0
    float_none("Nothing has that name")
  else
    scroll = get!(() -> Scroll(width(grow=grow)), m.parts, :scroll)
    # Half a row at the bottom says that the list goes on
    most = MOST_CHOICES + 3
    scroll.height = height(n <= most ? n * high : most * high - high / 2)
    m.shown == m.pick || (m.shown = m.pick; m.pick > 0 && scroll_into_view!(scroll, high * (m.pick - 1), high * m.pick))
    reuse!(scroll, Column(width(grow=grow), Alignment.Start, [get!(() -> own!(m, SearchOption(of=m, k=k)), m.parts, (:row, k)) for k in 1:n]...))
  end
  float_list(f, body, name="Kinds")
end

placed!(m::SearchMenu, side) = (m.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, m::SearchMenu) = caret(ctx, ui, m.side, rect(m.button))

describe(o::SearchOption) = begin
  m = o.of
  o.k in eachindex(m.rows) || return Box(height(0px))
  r = m.rows[o.k]
  s = m.of
  c = found_colours()
  # A kind that's chosen has a tick
  on = r.key === nothing ? isempty(s.wants) : r.key in s.wants
  Row(width(grow=grow), height(FLOAT_ROW), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center, name="Option",
      background(m.pick == o.k ? c.pick : c.frame),
    Icon(r.icon, size=13px, color=c.dim),
    Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true, label(r.name, 13px, color=c.ink, weight=on ? "Semibold" : "")),
    (on ? (Icon("check2", size=13px, color=c.ink),) : ())...)
end

onmouse(o::SearchOption, ::MouseMove) = (m = o.of; m.pick = m.shown = o.k; handled)
onkey(o::SearchOption, ev::KeyPress{Keys.mouse_left}) = take_option!(o.of, ev.window, o.k)

# The list sees a key before its field does. Return takes a row, and Esc or Tab goes back to the search's field.
onkey(m::SearchMenu, ev::KeyPress{Keys.down}) = unmodified(ev) ? (isempty(m.rows) || (m.pick = min(m.pick + 1, length(m.rows))); handled) : nothing
onkey(m::SearchMenu, ev::KeyPress{Keys.up}) = unmodified(ev) ? (isempty(m.rows) || (m.pick = max(m.pick - 1, 1)); handled) : nothing
onkey(m::SearchMenu, ev::KeyPress{Keys.enter}) = unmodified(ev) ? take_option!(m, ev.window, m.pick) : nothing
onkey(m::SearchMenu, ev::KeyPress{Keys.escape}) = unmodified(ev) ? close_search_menu!(m.of, ev.window) : nothing
onkey(m::SearchMenu, ev::KeyPress{Keys.tab}) = unmodified(ev) ? close_search_menu!(m.of, ev.window) : nothing

# --- the sidebar --------------------------------------------------------------------------

# A row of the file finder's list, or of the project picker's, looks like a row of the command palette's
describe(r::FileRow) = begin
  e = editor(r)
  c = omni(e)
  on = r.finder == e.picked
  # A line is between two rows, but not at an edge of the row that's chosen
  ruled = r.finder > 1 && !on && e.picked != r.finder - 1
  changed = haskey(e.buffers, r.path) && dirty(e.buffers[r.path])
  # The letters that were typed are in bold where the name has them
  parts = [Box(omni_label(text, 14, c.ink, weight=typed ? OMNI_MATCH : OMNI_NAME)) for (text, typed) in letter_runs(basename(r.path), input(e).text)]
  Row(width(grow=grow), height(px(OMNI_ROW_ONE)), padding(14px, 0px), child_gap=10px, name="File",
      background(on ? c.selected : c.drop), border(1px, :solid, ruled ? c.rule : clear)[:top],
    Box(width(grow=grow), Alignment.Start, clip_x=true, Row(parts...)),
    # A page with changes that aren't saved says so at the right, faint, and a project says where it is
    (changed ? (Box(omni_label("Not saved", 12, on ? c.ink2 : c.muted)),) :
     e.popup == :projects ? (Box(omni_label(project_place(r.path), 12, on ? c.ink2 : c.muted)),) : ())...)
end

cursor(::FileRow) = :hand
# The mouse over a row chooses it, as it does in the command palette
onmouse(r::FileRow, ::MouseMove) = (editor(r).picked = r.finder; handled)

onkey(r::FileRow, ::KeyPress{Keys.mouse_left}) = picker_open!(editor(r), r.path)

# The sidebar is a tree, UI.jl's ListTree. Each file of the folder is a group.
# The items in it are the file's headings and its components: the sheets and
# what its `ui` blocks show. A heading is a group too when it has smaller
# headings or components under it. The tree keeps which groups are open and
# which item the keyboard is on.
#
# Each item starts with an icon that says what it is. The tree draws no arrows.
# While the mouse is over a group, the group's icon is an arrow that shows
# whether it's open, and a click on the icon opens or closes the group.

"The icon that a file, a heading or a component starts with in the sidebar, in the place a tree has its arrow"
mark(l, icon; size=13px) = begin
  item = l.parent
  # A file that's open and has nothing under it has no arrow, since there's nothing to open or close.
  # A closed file might have headings, so it has one.
  over = item isa Tree.ItemGroup && Tree.hovered(item) && (item.collapsed || any(c -> c isa Tree.TreeItem, item.children))
  # The box never shrinks. A name too long for the sidebar would shrink it to its icon, and the
  # arrow is narrower than the icon, so the name would move left when the mouse came over it.
  Box(fixed(18px), height(grow=grow), Alignment.Center,
    (isempty(icon) ? () : (Icon(over ? (item.collapsed ? "chevron-right" : "chevron-down") : icon,
                                size=over ? 10px : size, color=colours.dim),))...)
end

describe(l::FileLabel) = begin
  e = editor(l)
  o = object(e, l.path)
  folder = o isa AbstractDirectory
  changed = haskey(e.buffers, l.path) && dirty(e.buffers[l.path])
  # While the file is renamed, a text field with its name is where the name was
  name = renaming(e, :sidebar) == l.path ?
    Box(width(grow=grow), height(22px), padding(5px, 0px), radius(4px), Alignment.Start, background(colours.bg),
        border(1px, :solid, colours.accent), renamer(e)) :
    # A hidden folder or page is fainter than the others, as it is in the Finder, and so is one that you ignore
    folder ? Box(width(grow=grow), Alignment.Start, label(entry_name(o), color=ishidden(entry_name(o)) || ignored_shown(e, l.path) ? colours.dim : colours.ink)) :
    ismarkdown(l.path) ?
    Box(width(grow=grow), Alignment.Start, label(basename(l.path), color=(ishidden(l.path) || ignored_shown(e, l.path)) && l.path != e.buf.path ? colours.dim : colours.ink,
                                                 weight=l.path == e.buf.path ? "Semibold" : "")) :
    # A file that Ladder only shows has its whole name, and it's fainter until it's the file that shows
    Box(width(grow=grow), Alignment.Start, label(basename(l.path), color=l.path == e.buf.path ? colours.ink : colours.dim,
                                                 weight=l.path == e.buf.path ? "Semibold" : ""))
  # A page that an agent waits for has a dot in the colour of the Nudge button
  awaited = ismarkdown(l.path) && !isempty(agents(e, l.path))
  Row(width(grow=grow), height(grow=grow), padding(0px, 8px, 0px, 0px), child_gap=4px, clip=true, name="File",
    mark(l, o === nothing ? file_icon(l.path) : entry_icon(o)),
    name,
    (o === nothing ? () : entry_marks(e, o))...,   # what a kind of folder or of file adds, like how many emails of a folder aren't read
    (awaited ? (Box(width(6px), height(6px), radius(3px), background(colours.accent)),) : ())...,
    (changed ? (Box(width(6px), height(6px), radius(3px), background(colours.dim)),) : ())...)
end

describe(l::EntryLabel) =
  Row(width(grow=grow), height(grow=grow), padding(0px, 8px, 0px, 0px), child_gap=4px, clip=true, name="Entry",
    mark(l, l.icon),
    Box(width(grow=grow), Alignment.Start, label(l.title, 12px, color=l.line == 0 ? colours.faint : colours.dim)),
    # A heading or a component whose lines have changes that aren't saved has a dot, as its file has
    (edited(l) ? (Box(width(5px), height(5px), radius(2.5px), background(colours.dim)),) : ())...)

# --- the parts of a page that have changes that aren't saved ----------------------------
#
# A file with changes that aren't saved has a dot beside its name in the
# sidebar. Each heading and each component of that file whose own lines
# changed has a dot too, so the sidebar shows where the changes are. A change
# belongs to the nearest thing above it in the sidebar: a line in a component's
# block belongs to the component, and any other line belongs to the heading
# that it's under. A heading whose group is closed has a dot when anything in
# the group changed. Lines that were taken away count for the line that's now
# where they were. The dots go when the page is saved.

"""
The first lines of the headings and the components of `b` that have changes
which aren't saved. It's worked out once for each version of the text.
"""
edited_entries(e, b::Buffer) = begin
  key = (:edited, b.path)
  kept = get(e.nodes, key, nothing)
  kept !== nothing && kept[1] == (b.version, b.saved) && return kept[2]::Set{Int}
  found = Set{Int}()
  if dirty(b)
    entries, ks, n = outline(b), kinds(b), length(b.lines)
    starts = [x.line for x in entries]
    # A component's lines end where its block closes. A heading's go on to the next thing in the sidebar.
    ends = [x.level == 7 ? something(findnext(k -> k.kind == Kind.fence, ks, x.line + 1), n) : n for x in entries]
    for (_, new) in changes(b.disk, b.lines)
      for i in (isempty(new) ? (clamp(first(new), 1, n):clamp(first(new), 1, n)) : new)
        at = searchsortedlast(starts, i)
        # Past the end of a component, the line belongs to the heading above the component
        while at > 0 && i > ends[at]
          at = something(findprev(k -> entries[k].level < 7, 1:at-1, at - 1), 0)
        end
        at > 0 && push!(found, starts[at])
      end
    end
  end
  e.nodes[key] = ((b.version, b.saved), found)
  found
end

"True when the lines of this heading or component have changes that aren't saved. A closed group answers for all that's in it."
edited(l::EntryLabel) = begin
  e = editor(l)
  b = get(e.buffers, l.path, nothing)
  (b === nothing || l.line == 0 || !dirty(b)) && return false
  found = edited_entries(e, b)
  isempty(found) && return false
  l.line in found && return true
  item = l.parent
  item isa Tree.ItemGroup && item.collapsed && any(inner -> inner.firstchild.line in found, items(item, hidden=true))
end

# The name that the sidebar gives each component of UI.jl, and its icon
const COMPONENTS = Dict(
  "Checkbox" => ("Checkbox", "check2-square"), "Toggle" => ("Switch", "toggle-on"),
  "RadioGroup" => ("Radio buttons", "ui-radios"), "Dropdown" => ("Menu", "menu-button-wide"), "Select" => ("Menu", "menu-button-wide"),
  "Slider" => ("Slider", "sliders"), "ColorPicker" => ("Colour picker", "palette"),
  "TextInput" => ("Text field", "input-cursor-text"), "KeyCombo" => ("Keys", "command"),
  "Tooltip" => ("Tooltip", "chat-square-text"), "ListTree" => ("Tree", "list-nested"),
  "Inspector" => ("Inspector", "braces"), "Table" => ("Table", "table"), "Button" => ("Button", "hand-index"),
  "ProgressBar" => ("Progress bar", "hr"), "STLViewer" => ("3D model", "box"),
  "AudioPlayer" => ("Sound", "music-note-beamed"), "VideoPlayer" => ("Video", "film"), "AudioRecorder" => ("Recorder", "mic"),
  "Mermaid" => ("Diagram", "diagram-3"))
const LAYOUTS = ("Box", "Row", "Column", "Stack", "Scroll", "Text", "Image")
"Every icon that the sidebar can show. The built app reads them all when it's made."
const SIDEBAR_ICONS = unique(["eye", "eye-slash", "file-earmark-text", "chevron-right", "chevron-down", "puzzle",
                              ("type-h$n" for n in 1:6)..., (icon for (_, icon) in values(COMPONENTS))...,
                              (block_icon(T) for T in values(BLOCKS) if !isempty(block_icon(T)))...])

"""
The name and the icon of what a block of `ui` code shows. It's read from the
code, so the block needn't have run: the first component of UI.jl that the
code names, or else the first thing it makes that isn't a layout.
"""
component(code) = begin
  made = String[]
  for line in code
    startswith(lstrip(line), "@use") && continue
    append!(made, (m[1] for m in eachmatch(r"\b([A-Z]\w*)\(", line)))
  end
  i = findfirst(name -> haskey(COMPONENTS, name), made)
  i === nothing || return COMPONENTS[made[i]]
  i = findfirst(name -> !(name in LAYOUTS) && !isdefined(Base, Symbol(name)), made)
  i === nothing ? ("Layout", "bounding-box") : (made[i], "puzzle")
end

"The headings and the components among `lines`, from the top. `folder` is the folder of their page, where a file can define a kind of block."
outline(lines::Vector{String}, kinds::Vector{Line}, folder::AbstractString="") = begin
  out = Entry[]
  for (i, l) in enumerate(kinds)
    if l.kind == Kind.heading
      push!(out, Entry(i, l.level, rest(lines[i], l.prefix), "type-h$(l.level)", i))
    elseif l.kind == Kind.fence && l.level == 0 && haskey(BLOCKS, l.lang)
      # The line that closes the block, or the last line when nothing closes it
      close = something(findnext(k -> k.kind == Kind.fence, kinds, i + 1), length(lines))
      entry = block_outline(BLOCKS[l.lang], lines, i, close)
      entry === nothing || push!(out, entry)
    elseif l.kind == Kind.fence && l.level == 0 && block_source(lines[i], l.lang, folder) !== nothing
      # A block that a file defines has the name of its language. The caret goes under the block.
      close = something(findnext(k -> k.kind == Kind.fence, kinds, i + 1), length(lines))
      push!(out, Entry(i, 7, uppercasefirst(replace(l.lang, '_' => ' ')), "puzzle", min(close + 1, length(lines))))
    end
  end
  out
end
outline(b::Buffer) = outline(b.lines, kinds(b), isempty(b.path) ? "" : dirname(b.path))

"""
The headings and the components of the file at `path`. A file that has been
opened gives those of its text as it is now, with the changes that aren't
saved. Any other file is read from the disk, and read again when it changes there.
"""
outline(e::Editor, path::String) = begin
  haskey(e.buffers, path) && return outline(e.buffers[path])
  isfile(path) || return Entry[]
  at = mtime(path)
  kept = get(e.nodes, (:read, path), nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  lines = text(path)
  found = outline(lines, classify(lines), dirname(path))
  e.nodes[(:read, path)] = (at, found)
  found
end

const SIDEBAR_GUIDES = true   # draw the lines that join each item in the sidebar to the item it's in

"The sidebar's tree"
file_tree(e) = node!(() -> Tree.ListTree(guides=SIDEBAR_GUIDES, frame=false, arrows=false, onchoose=item -> choose!(e, item)), e, :tree)

"The items in `parent` and in the groups in it, from the top. With `hidden`, those in a closed group too."
items(parent; hidden=false, out=Tree.TreeItem[]) = begin
  for item in parent.children
    item isa Tree.TreeItem || continue
    push!(out, item)
    item isa Tree.ItemGroup && (hidden || !item.collapsed) && items(item; hidden, out)
  end
  out
end

"""
Mark that the sidebar's tree took a key, like Return on a heading, which comes
to the editor next, so that the editor doesn't take it too. The tree keeps a
click that chose an item, so a click is never marked: the mark would stay,
and the editor would leave out the next click or key, like a right-click.
"""
chose!(e) = begin
  w = window_of(e)
  (w === nothing || !(Keys.mouse_left in w.keys)) && (e.nodes[:chose] = true)
  nothing
end

"""
A click on the name of a file shows the file in the page. A file that isn't
Markdown is only shown: the page doesn't change it. A folder shows its own folders and files. A click on a heading or a
component goes to it, and opens its file first if another file is showing.
Return does the same for the item the keyboard is on. Each gives the keyboard
to the text.
"""
choose!(e, item) = begin
  l = item.firstchild
  o = l isa FileLabel ? object(e, l.path) : nothing
  o isa AbstractDirectory && return (open!(e, o); chose!(e); nothing)
  # A group's name shows what's in the group. Only its icon hides that.
  item isa Tree.ItemGroup && (item.collapsed = false)
  l.path == e.buf.path || (o === nothing ? open!(e, l.path) : open!(e, o))
  focus(e)
  chose!(e)
  (l isa EntryLabel && l.line > 0) || return
  go_entry!(e, l.line, l.caret)
end

"""
Put the caret on line `caret` of the page that shows, for the heading or the
component that starts on `line`, with that line near the top of the window.
"""
go_entry!(e, line, caret) = begin
  b = e.buf
  b.reading = false
  at = clamp(caret, 1, length(b.lines))
  b.caret = b.anchor = settle(b, (at, length(b.lines[at])))
  # The caret stays in a `columns` block that takes no room, so that the block shows its lines
  column_fold(b, at) === nothing || (b.caret = b.anchor = b.stood = line_end(b, at))
  # Put its first line near the top of the window rather than just on screen.
  # The next frame does it, once it has laid out the file that's showing.
  e.nodes[:hold] = (clamp(line, 1, length(b.lines)), 24px - PAGE_TOP)
  e.blink = time()
end

"Put the headings and the components of a file in its group, when they aren't the ones that it has"
outline!(e, group) = begin
  path = group.firstchild.path
  found = outline(e, path)
  found == get(e.nodes, (:outline, path), nothing) && return
  e.nodes[(:outline, path)] = found
  old = items(group, hidden=true)
  labels = [item.firstchild for item in old]
  if !isempty(found) && length(labels) == length(found) &&
     all(l.level == x.level && l.title == x.title && l.icon == x.icon for (l, x) in zip(labels, found))
    # The same ones on other lines, as when a line is typed above them
    foreach((l, x) -> (l.line = x.line; l.caret = x.caret), labels, found)
    return
  end
  closed = Set((item.firstchild.level, item.firstchild.title) for item in old if item isa Tree.ItemGroup && item.collapsed)
  foreach(detach!, [item for item in group.children if item isa Tree.TreeItem])
  # A file with no headings or components has nothing under it
  isempty(found) && return
  # Each one goes in the nearest heading above it that is bigger
  above = Any[(0, group)]
  for (k, x) in enumerate(found)
    while above[end][1] >= x.level
      pop!(above)
    end
    label = EntryLabel(path=path, line=x.line, level=x.level, title=x.title, icon=x.icon, caret=x.caret)
    if k < length(found) && found[k+1].level > x.level
      item = Tree.ItemGroup(label)
      item.collapsed = (x.level, x.title) in closed
      add_child!(above[end][2], item)
      push!(above, (x.level, item))
    else
      add_child!(above[end][2], Tree.Item(label))
    end
  end
end

"The item for where the caret is: the last heading or component above it that shows, or its file"
here(e, tree) = begin
  i = findfirst(group -> group.firstchild.path == e.buf.path, collect(tree.children))
  i === nothing && return nothing
  group = collect(tree.children)[i]
  (!(group isa Tree.ItemGroup) || group.collapsed) && return group
  at = findlast(item -> 0 < item.firstchild.line <= e.buf.caret[1], items(group))
  at === nothing ? group : items(group)[at]
end

"""
Open the group of the file that shows, so the sidebar lists its headings, and
close the group of the file that showed before. It's done once each time
another file shows, and the first time the sidebar lists the file. Between
those times, a click on a file's icon opens or closes its group, and the group
stays as the click left it.
"""
show_open_file!(e, tree) = begin
  listed = collect(tree.children)
  i = findfirst(item -> item.firstchild.path == e.buf.path, listed)
  shown = i === nothing ? nothing : listed[i]
  before = get(e.nodes, :open_file, nothing)
  shown === before && return
  before isa Tree.ItemGroup && (before.collapsed = true)
  shown isa Tree.ItemGroup && (shown.collapsed = false)
  e.nodes[:open_file] = shown
end

"Make the sidebar's tree show the folder's files and the headings of each file that's open in it"
fill_tree!(e, tree) = begin
  tree.guides = SIDEBAR_GUIDES
  if [group.firstchild.path for group in tree.children] != e.listed
    kept = Dict(group.firstchild.path => group for group in tree.children)
    foreach(detach!, collect(tree.children))
    for p in e.listed
      add_child!(tree, get(kept, p) do
        delete!(e.nodes, (:outline, p))   # a new group has no headings in it yet
        # A file that isn't Markdown has no headings to list
        isfile(p) && ismarkdown(p) ? Tree.ItemGroup(FileLabel(path=p)) : Tree.Item(FileLabel(path=p))
      end)
    end
  end
  show_open_file!(e, tree)
  for group in tree.children
    group isa Tree.ItemGroup && !group.collapsed && outline!(e, group)
  end
  ended_rename!(e)
  w = window_of(e)
  shown = items(tree)
  if w === nothing || w.focus !== tree
    # While the text has the keyboard, the tree marks where the caret is
    tree.focused = here(e, tree)
  elseif !any(item -> item === tree.focused, shown)
    tree.focused = something(here(e, tree), get(shown, 1, nothing), Some(nothing))
  elseif tree.focused !== get(e.nodes, :tree_at, nothing)
    # An arrow key moved to another item. Keep it in sight.
    high = Tree.ROW_HEIGHT   # the height of a row while the theme's text has its usual size, as the sidebar's has
    row = findfirst(item -> item === tree.focused, shown)
    scroll_into_view!(e.files_scroll, high * (row - 1), high * row)
  end
  e.nodes[:tree_at] = tree.focused
  tree
end

"The colours of the sidebar's tree"
panel_theme() = Theme(size=Tree.LABEL_SIZE, surface=colours.panel, text=colours.ink, dim=colours.dim, line=colours.line,
                      hover=colours.hover, select=colours.active, family=SANS)

# --- the menu of a file ---------------------------------------------------------------------
#
# A right-click on a file or a folder in the sidebar, or on the name of the file
# that shows in the top bar, shows a menu that renames it, duplicates it,
# copies its path, shows it in the Finder or moves it to the Trash. A folder's
# menu also makes a new page or a new folder in it, and opens it in a new
# window. A file's menu also opens it in a new window or in the app that the
# Mac uses for it, and copies a wiki link to it. A right-click under the files
# shows the menu of the sidebar's own folder. It's a menu of macOS's own, so it
# looks and works like the other menus on the Mac. A window that isn't on a
# screen, like the one a test makes, gets a menu that Ladder draws.

"The menu of the sidebar's own folder, for a right-click under the files that it lists"
const FOLDER_MENU = ["New Page", "New Folder", "New Terminal", "New Agent Session", "-", "Copy Path", "Show in Finder"]

"""
Show the menu of the file or the folder at `path`. `at` is where you
right-clicked: its name in the `:sidebar` or in the `:title` of the top bar,
or its icon on a `:desktop`. Rename puts the text field there.
"""
file_menu!(e, w, path; at=:sidebar, items=file_menu(path)) = begin
  act(i) = file_act!(e, path, get(items, i, ""); at)
  # A new file that isn't saved yet isn't on the disk, so the Finder can't show it, and there's nothing to copy, to open or to ignore
  off = ispath(path) ? Int[] : findall(in(("Open in New Window", "Duplicate", "Show in Finder", "Ignore")), items)
  system_menu(w, items, act; off) || drawn_menu!(w, items, act; off)
  nothing
end

"Do to the file or the folder at `path` what the item `name` of its menu says"
file_act!(e, path, name; at=:sidebar) =
  name == "New Page" ? new_page!(e, path) :
  name == "New Folder" ? new_folder!(e, path) :
  name == "New Terminal" ? new_terminal!(e, path) :
  name == "New Agent Session" ? new_agent_session!(e, path) :
  name == "Open in New Window" ? (show_window!(page_window(path, e), window_of(e)); nothing) :
  startswith(name, "Open in ") ? open_outside(path) :
  name == "Rename" ? rename!(e, path; at) :
  name == "Duplicate" ? duplicate!(e, path) :
  name == "Copy Path" ? clipboard(path) :
  name == "Copy Link" ? clipboard(wiki_link(path)) :
  name == "Show in Finder" ? show_in_finder(path) :
  name == "Add to Favourites" ? Folders.favourite!(path) :
  name == "Remove from Favourites" ? Folders.unfavourite!(path) :
  name == "Ignore" ? ignore!(e, path) :
  name == "Stop Ignoring" ? ignore!(e, path, false) :
  name == "Move to Trash" ? trash!(e, path) : nothing

"Open a Finder window on the folder of the file at `path`, with the file selected"
show_in_finder(path) = (Sys.isapple() && ispath(path) && run(pipeline(`open -R $path`, stdout=devnull, stderr=devnull), wait=false); nothing)

"""
Show the menu of the file or the folder in the sidebar that the mouse is over,
if it's over one, or of the file of a tab. Under the files, it's the menu of
the sidebar's own folder, unless a kind of folder lists what it holds its own way.
"""
file_menu!(e, w) = begin
  e.panel || return
  # The mouse finds the item of the row that it's over, in either tree
  tab = Tree.item_under(tab_tree(e), w)
  tab !== nothing && tab.parent === tab_tree(e) && return tab_menu!(e, w, tab.firstchild.path)
  tree = file_tree(e)
  item = Tree.item_under(tree, w)
  if item === nothing
    (w.mouse[2] > bar_bottom(e) && isdir(e.folder) && ishovered(node!(Sidebar, e, :sidebar)) && files_listed(e)) || return
    return file_menu!(e, w, e.folder, items=[FOLDER_MENU; "-"; favourite_item(e.folder)])
  end
  item.firstchild isa FileLabel || return
  path = item.firstchild.path
  # The tree takes the keyboard, so the file that the menu is for stays marked
  focus(tree)
  tree.focused = item
  file_menu!(e, w, path)
end

"""
A path in the folder `dir` for something new called `base`, with the ending
`ending`, that nothing has yet: `base` itself, or else `base` with 2, 3 and so
on after it, as the Finder does. A page that's open and not saved yet has its path.
"""
free_path(e, dir, base, ending="") = begin
  taken(p) = ispath(p) || haskey(e.buffers, p)
  path = joinpath(dir, base * ending)
  n = 2
  while taken(path)
    path = joinpath(dir, "$base $n$ending")
    n += 1
  end
  path
end

"Make a new empty page in the folder `dir` and show it. Its name is a text field in the sidebar, to type the name it should have."
new_page!(e, dir) = begin
  path = free_path(e, dir, "Untitled", ".md")
  try touch(path) catch; return end   # the disk said no
  open!(e, path)
  list_files!(e)
  rename!(e, path)
  e.nodes[:renaming_new] = :page
  nothing
end

"""
Make a new terminal in the folder `dir` and show it: an empty file called
Terminal.vt, which gets a shell in that folder as soon as it shows. The file
keeps what the terminal shows: see "a terminal's file".
"""
new_terminal!(e, dir) = begin
  path = free_path(e, dir, "Terminal", ".vt")
  try touch(path) catch; return end   # the disk said no
  open!(e, path)
  list_files!(e)
  nothing
end

"Make a new empty folder in the folder `dir`, and show `dir` in the sidebar. The new folder's name is a text field, to type the name it should have."
new_folder!(e, dir) = begin
  path = free_path(e, dir, "Untitled")
  try mkdir(path) catch; return end
  dir == e.folder ? list_files!(e) : go_folder!(e, dir)
  rename!(e, path)
  e.nodes[:renaming_new] = :folder
  nothing
end

"""
Make a copy of the file or the folder at `path` beside it, with a name like
"notes copy.md", as the Finder does. A page with changes that aren't saved is
copied with them.
"""
duplicate!(e, path) = begin
  ispath(path) || return
  folder = isdir(path)
  dup = free_path(e, dirname(path), (folder ? basename(path) : title(path)) * " copy", folder ? "" : splitext(path)[2])
  try cp(path, dup) catch; return end
  b = get(e.buffers, path, nothing)
  b !== nothing && dirty(b) && writes(b) && write(dup, join(b.lines, "\n"))
  list_files!(e)
  nothing
end

"The wiki link to the file at `path`, like [[Ideas]] for a page or [[plan.pdf]] for another file"
wiki_link(path) = "[[" * (ismarkdown(path) ? title(path) : basename(path)) * "]]"

"The text field that a file's new name is typed in"
renamer(e) = node!(e, :renamer) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"""
Start to rename the file or the folder at `path`. Its name becomes a text
field, in the sidebar or in the top bar, as `at` says. Both show the whole
name, so the field has the whole name. The part of a file's name before its
ending is selected, and all of a folder's name, since a folder has no ending.
"""
rename!(e, path; at=:sidebar) = begin
  i = renamer(e)
  i.color = colours.ink
  i.text = basename(path)
  i.anchor, i.cursor = 0, length(isdir(path) ? i.text : title(path))
  e.nodes[:renaming] = path
  e.nodes[:renaming_at] = at
  focus(i)
end

"The path of the file that's being renamed in `at`, the `:sidebar` or the `:title`. It's \"\" when none is."
renaming(e, at) = get(e.nodes, :renaming_at, :sidebar) == at ? get(e.nodes, :renaming, "") : ""

"""
Take the text field away. The keyboard goes back to the sidebar, or to the
text when the field was in the top bar or was the name of a new page.
"""
stop_rename!(e) = begin
  delete!(e.nodes, :renaming)
  new = pop!(e.nodes, :renaming_new, nothing)
  at = pop!(e.nodes, :renaming_at, :sidebar)
  at == :desktop ? focus_desktop!(e) : at == :title || new == :page ? focus(e) : focus(file_tree(e))
end

"Return gives the file the name that's typed, and esc leaves it with the name it has"
rename_key!(e, K) = begin
  unmodified(e) || return nothing
  if K == Keys.escape
    stop_rename!(e)
  elseif K == Keys.enter && finish_rename!(e)
    stop_rename!(e)
  end
  nothing
end

"A click somewhere else while a file is renamed gives the file the name that's typed"
ended_rename!(e) = begin
  w = window_of(e)
  (w === nothing || !haskey(e.nodes, :renaming) || w.focus === renamer(e)) && return
  finish_rename!(e)
  delete!(e.nodes, :renaming)
  delete!(e.nodes, :renaming_at)
  delete!(e.nodes, :renaming_new)
  nothing
end

"""
Give the file or the folder that's being renamed the name in the text field.
A file keeps its ending, like .md, unless the name is typed with one: a
Markdown ending, or the ending it has. A folder has no ending, so a dot in its
name is only part of the name. It's false when another file or folder has
that name already, and then nothing changes.
"""
finish_rename!(e) = begin
  old = get(e.nodes, :renaming, "")
  name = String(strip(renamer(e).text))
  (isempty(old) || isempty(name) || occursin('/', name)) && return true
  ending = isdir(old) ? "" : splitext(old)[2]
  typed = ismarkdown(name) || lowercase(splitext(name)[2]) == lowercase(ending)
  new = joinpath(dirname(old), typed ? name : name * ending)
  new == old && return true
  # A Mac's disk takes Notes.md and notes.md to be one file, so a change of capitals isn't a clash
  ispath(new) && lowercase(new) != lowercase(old) && return false
  # A page that was made a moment ago has no links to it yet, though pages can link to its name, Untitled
  move!(e, old, new, links=!haskey(e.nodes, :renaming_new))
  true
end

"True when `p` is the path `at`, or the path of something in the folder at `at`"
inside_path(p, at) = p == at || startswith(p, at * "/")

"The path that `p` gets when what's at `old` gets the path `new`. What's in a folder moves with it."
repath(p, old, new) = inside_path(p, old) ? new * p[ncodeunits(old)+1:end] : p

"The keys of `d` that are paths of what's at `at`: `at` itself, and what's in it when it's a folder"
paths_inside(d, at) = [p for p in keys(d) if inside_path(p, at)]

"The keys of the editor's nodes that it keeps for a file by its path, for the files at `at`"
nodes_inside(e, at; kinds=(:read, :outline, :fileview)) =
  [k for k in keys(e.nodes) if k isa Tuple{Symbol,String} && k[1] in kinds && inside_path(k[2], at)]

"""
Give the file or the folder at `old` the path `new`: on the disk, and in
everything the editor keeps by path. The files in a folder go with it, so a
file of the folder that shows, or that's open with changes, keeps showing.
The links to it in the pages of its project change to match, unless `links`
is false. See "links that follow a rename".
"""
move!(e, old, new; links=true) = begin
  found = links && ispath(old) ? links_into(e, old, new) : nothing
  if ispath(old)
    try
      Base.Filesystem.rename(old, new)
    catch
      return   # the disk said no, so it keeps its name
    end
  end
  to(p) = repath(p, old, new)
  for p in paths_inside(e.buffers, old)
    b = e.buffers[to(p)] = pop!(e.buffers, p)
    b.path = to(p)
  end
  # Going back to the file still finds it, and its tab stays open
  map!(to, e.back, e.back)
  map!(to, e.ahead, e.ahead)
  map!(to, tabs(e), tabs(e))
  foreach(p -> READ[to(p)] = pop!(READ, p), paths_inside(READ, old))
  foreach(k -> e.nodes[(k[1], to(k[2]))] = pop!(e.nodes, k), nodes_inside(e, old, kinds=(:read, :outline)))
  for item in items(file_tree(e), hidden=true)
    item.firstchild.path = to(item.firstchild.path)
  end
  e.folder = to(e.folder)
  desktop_moved!(e, old, new)   # an icon of a desktop keeps its place under its new name
  found === nothing || relink!(e, found, old, new)
  list_files!(e)
end

# --- links that follow a rename ------------------------------------------------------------
#
# When a page or another file gets a new name, or moves to another folder, the
# links to it in the pages of its project change with it, as in Obsidian:
# [[Ideas]] becomes [[Thoughts]], and [see](Ideas.md) becomes [see](Thoughts.md).
# A link keeps the words after its |, the heading after its #, and its form: a
# name with folders, like [[notes/Ideas]], gets the new folders, and a path
# from the page's folder stays a path from the page's folder. A page that moves
# to another folder keeps its own links to files working too. A link in a code
# block or between backticks is code, and stays as it is. A page that's open
# changes in its window, so its changes that aren't saved stay, and its file
# changes too. The window then says how many links changed.
#
# `links_into` reads the pages before the move, while each link still finds the
# file that it names, and `relink!` changes them after the move.

"A link in a page's text to a file: its line, the columns before and after the file's name in it, the name as it's written, whether it's a wiki link, and the file that it names"
struct FileLink
  line::Int
  from::Int
  to::Int
  name::String
  wiki::Bool
  file::String
end

"The index where `delim` next starts in `chars[from:to]`, or 0, as markdown.jl looks for one"
find_chars(chars, delim::String, from, to) = begin
  n = length(delim)
  for i in from:to-n+1
    all(chars[i+k-1] == delim[k] for k in 1:n) && return i
  end
  0
end

"""
The links in `lines` that name a file: each wiki link, like [[Ideas#Plans]] or
![[plan.png]], and each Markdown link to a path, like [see](Ideas.md) or
![a plan](plan.png). Each is its line, the columns before and after the name
of the file, the name, and whether it's a wiki link. A link in a code block or
between backticks is code. A link to a web page, or to a heading of its own
page, names no file.
"""
named_links(lines) = begin
  found = Tuple{Int,Int,Int,String,Bool}[]
  ks = classify(lines)
  for (i, line) in enumerate(lines)
    (ks[i].kind in (Kind.code, Kind.fence) || !occursin('[', line)) && continue
    chars = collect(line)
    n = length(chars)
    j = 1
    while j <= n
      c, next = chars[j], j < n ? chars[j+1] : '\0'
      if c == '\\' && ispunct(next)
        j += 2
      elseif c == '`'
        k = findnext(==('`'), chars, j + 1)
        j = k !== nothing && k > j + 1 ? k + 1 : j + 1
      elseif c == '[' && next == '['
        # A wiki link: the name runs to a | or a #, and a table writes its | as \|
        k = find_chars(chars, "]]", j + 2, n)
        if k == 0 || any(x -> x == '[' || x == ']', @view chars[j+2:k-1])
          j += 1
          continue
        end
        b = something(findnext(x -> x == '|' || x == '#', chars, j + 2), k)
        b = min(b, k) - 1
        b >= j + 2 && chars[b] == '\\' && b + 1 < k && chars[b+1] == '|' && (b -= 1)
        a = j + 2
        while a <= b && isspace(chars[a]); a += 1 end
        while b >= a && isspace(chars[b]); b -= 1 end
        b >= a && push!(found, (i, a - 1, b, String(chars[a:b]), true))
        j = k + 2
      elseif c == '[' && next == '^'
        # [^name] points to a footnote
        k = findnext(==(']'), chars, j + 2)
        j = k !== nothing && k > j + 2 && !any(isspace, @view chars[j+2:k-1]) ? k + 1 : j + 1
      elseif c == '['
        k = find_chars(chars, "](", j + 1, n)
        m = k == 0 ? 0 : find_chars(chars, ")", k + 2, n)
        if k > j + 1 && m != 0
          a = k + 2
          b = something(findnext(x -> x == '#' || isspace(x), chars, a), m) - 1
          b = min(b, m - 1)
          url = String(chars[a:b])
          (b >= a && !occursin("://", url) && !startswith(url, "mailto:") && !startswith(url, '<')) && push!(found, (i, a - 1, b, url, false))
          j = m + 1
        else
          j += 1
        end
      else
        j += 1
      end
    end
  end
  found
end

"What follows `at` in the path `p`, when `p` is `at` or is in the folder `at`: \"\" or \"/notes/a.md\". Capitals don't count, as on a Mac's disk. It's nothing for any other path."
past_path(p, at) = begin
  lp, la = lowercase(p), lowercase(at)
  lp == la && return ""
  (startswith(lp, la * "/") && isvalid(p, ncodeunits(at) + 1)) || return nothing
  p[ncodeunits(at)+1:end]
end

"`new` with each of its parts, from the end, written as the same part of `old` is when the two differ only in capitals. A part that's `keep` stays as it is."
spelled_like(old, new; keep=()) = begin
  a, b = split(old, '/'), String.(split(new, '/'))
  for i in 1:min(length(a), length(b))
    x, y = a[end-i+1], b[end-i+1]
    lowercase(x) == lowercase(y) && !(y in keep) && (b[end-i+1] = x)
  end
  join(b, '/')
end

"""
The name that a wiki link written as `name`, in a page in the folder `dir`,
gives the file at `file`, in the form of `name`: the file's name, the file's
folders too when `name` has folders, or a path from the page's folder when
`name` starts with ./ or ../. A page's name has no .md, unless `name` has
one. When the name finds another file, the folders over it come too, until it
finds this one. A part of `name` that's the same but for capitals keeps its
capitals, unless it's in `keep`.
"""
wiki_name_for(dir, name, file; keep=()) = begin
  plain = lowercase(splitext(file)[2]) == ".md" && !ismarkdown(name)
  shown(p) = spelled_like(name, plain ? String(chop(p, tail=3)) : p; keep)
  if startswith(name, '/') || startswith(name, '~') || startswith(name, "./") || startswith(name, "../")
    out = startswith(name, '/') ? file : startswith(name, '~') && inside_path(file, homedir()) ? "~" * file[ncodeunits(homedir())+1:end] : relpath(file, dir)
    startswith(name, "./") && !startswith(out, "../") && (out = "./" * out)
    return shown(out)
  end
  root = project_root(dir)
  inside_path(lowercase(file), lowercase(root)) || return shown(relpath(file, dir))
  parts = split(relpath(file, root), '/')
  for k in min(count(==('/'), name) + 1, length(parts)):length(parts)
    out = shown(join(parts[end-k+1:end], '/'))
    found = wiki_file(dir, out)
    found !== nothing && lowercase(found) == lowercase(file) && return out
  end
  shown(relpath(file, dir))
end

"The path that a Markdown link written as `url`, in a page in the folder `dir`, gives the file at `file`: from the page's folder, from the top folder, or from the home folder, as `url` is"
link_path_for(dir, url, file; keep=()) = begin
  out = startswith(url, '/') ? file :
        startswith(url, '~') && inside_path(file, homedir()) ? "~" * file[ncodeunits(homedir())+1:end] :
        relpath(file, dir)
  startswith(url, "./") && !startswith(out, "../") && (out = "./" * out)
  escaped(spelled_like(unescaped(url), out; keep))
end

"The file that the Markdown link to `url`, in a page in the folder `dir`, names, as `follow!` finds it, or nothing when it isn't there"
link_file(dir, url) = (path = abspath(dir, expanduser(unescaped(url))); ispath(path) ? path : nothing)

"True when a wiki link to `name` can name what's at `at` by its parts: the file by its name, or a file in the folder when the name has the folder's name in it"
could_name(name, at, folder) = begin
  parts = lowercase.(split(name, '/'))
  folder ? lowercase(basename(at)) in parts[1:end-1] : last(parts) in (lowercase(basename(at)), lowercase(title(at)))
end

"True when a wiki link to `name` finds a file in the folder `dir` itself"
found_beside(name, dir) = any(n -> isfile(abspath(dir, expanduser(n))), ismarkdown(name) ? (name,) : (name * ".md", name))

"""
The pages of the project of the file or folder at `old` that link to it, read
before it moves to `new`. Each is its path, the open page or nothing for its
file, its lines, and its links that name `old` or a file in it. A page that
moves to another folder comes with all its links to files, since a link from
its new folder can need another name. A page that's open in a window comes
as it shows, and its file as it's on the disk.
"""
links_into(e, old, new) = begin
  root = project_root(dirname(old))
  moves = lowercase(dirname(old)) != lowercase(dirname(new))
  folder = isdir(old)
  name = folder ? basename(old) : title(old)
  needles = unique(lowercase.([name, escaped(name)]))
  # A page that moves to another project looks for its wiki links' pages in that one
  shifts = moves && project_root(dirname(new)) != root
  # The pages that are open in a window, in this one first
  shown = Dict{String,Vector{Buffer}}()
  for o in (any(o -> o === e, editors) ? editors : [e; editors]), (p, b) in o.buffers
    (b.view == :markdown && !b.fixed && !isempty(p) && inside_path(p, root)) || continue
    push!(get!(() -> Buffer[], shown, p), b)
  end
  # A look at the project takes a second at most, as a big folder, like the home folder, could take minutes
  pages, _ = pages_under(root; budget=1.0)
  known = Dict{Tuple{String,String,Bool},Union{Nothing,String}}()
  found = NamedTuple{(:path, :buffer, :lines, :links),Tuple{String,Union{Nothing,Buffer},Vector{String},Vector{FileLink}}}[]
  for p in unique([pages; collect(keys(shown))])
    mover = moves && past_path(p, old) !== nothing
    texts = Tuple{Union{Nothing,Buffer},Vector{String}}[]
    isfile(p) && !protected(p) && push!(texts, (nothing, String.(split(try read(p, String) catch; "" end, '\n'))))
    foreach(b -> push!(texts, (b, copy(b.lines))), get(shown, p, Buffer[]))
    for (b, lines) in texts
      mover || any(n -> any(l -> occursin(n, lowercase(l)), lines), needles) || continue
      links = FileLink[]
      for (i, from, to, n, wiki) in named_links(lines)
        # A wiki link to a page that isn't there costs a look through the whole project, so a name that can't be
        # the file's isn't looked for. A page that moves needs its wiki links that find a page beside it, here or there.
        mine = !wiki || could_name(n, old, folder)
        mine || (mover && (shifts || found_beside(n, dirname(p)) || (p == old && found_beside(n, dirname(new))))) || continue
        file = get!(known, (dirname(p), n, wiki)) do
          wiki ? wiki_file(dirname(p), n) : link_file(dirname(p), n)
        end
        file === nothing && continue
        (mover || past_path(file, old) !== nothing) && push!(links, FileLink(i, from, to, n, wiki, file))
      end
      isempty(links) || push!(found, (path=p, buffer=b, lines=lines, links=links))
    end
  end
  found
end

"`lines` with each name that `changes` names in it, its line and the columns around it, in place of the name that's there"
with_names(lines, changes) = begin
  out = copy(lines)
  for (i, from, to, name) in sort(changes, by=c -> (c[1], -c[2]))
    chars = collect(out[i])
    out[i] = String([chars[1:from]; collect(name); chars[to+1:end]])
  end
  out
end

"Where the place `p` of a line is after `changes` put other names in the line. A place inside a name goes to the end of the new name."
caret_after(p, changes) = begin
  i, col = p
  c = col
  for (line, from, to, name) in changes
    (line == i && from < col) || continue
    c += to <= col ? length(name) - (to - from) : from + length(name) - col
  end
  (i, c)
end

"""
Change the links that `links_into` found, now that what was at `old` is at
`new`: in the files of the pages, and in the pages that are open. An open page
keeps its caret where it was, and ⌘Z there takes the change back. The window
says how many links changed, in how many pages.
"""
relink!(e, found, old, new) = begin
  to(p) = (rest = past_path(p, old); rest === nothing ? p : new * rest)
  keep = isdir(new) ? (basename(new),) : (basename(new), title(new))
  changed = Dict{String,Int}()   # the links that changed in each page
  written = Set{String}()
  for t in found
    page = to(t.path)
    dir = dirname(page)
    changes = Tuple{Int,Int,Int,String}[]
    for l in t.links
      file = to(l.file)
      name = l.wiki ? wiki_name_for(dir, l.name, file; keep) : link_path_for(dir, l.name, file; keep)
      name == l.name || push!(changes, (l.line, l.from, l.to, name))
    end
    isempty(changes) && continue
    lines = with_names(t.lines, changes)
    b = t.buffer
    if b === nothing
      try
        write(page, join(lines, "\n"))
        push!(written, page)
      catch
        continue   # the disk said no, so the file stays as it was
      end
    elseif b.lines == t.lines
      clean = !dirty(b)
      caret, anchor = caret_after(b.caret, changes), caret_after(b.anchor, changes)
      lo, hi = extrema(first.(changes))
      edit!(b, (lo, 0), (hi, length(b.lines[hi])), join(lines[lo:hi], "\n"))
      b.caret, b.anchor = caret, anchor
      clean && (b.saved = b.version)   # the file gets the same change, so the page has nothing new to save
    else
      continue
    end
    changed[page] = max(get(changed, page, 0), length(changes))
  end
  # An open page whose file changed knows the file's new text, so it doesn't read the change in again
  for o in (any(o -> o === e, editors) ? editors : [e; editors]), b in values(o.buffers)
    b.path in written && isfile(b.path) || continue
    theirs = text(b.path)
    b.told = combine(b.disk, b.told, theirs, keep=:theirs)
    b.disk = theirs
    READ[b.path] = mtime(b.path)
  end
  n, pages = sum(values(changed), init=0), length(changed)
  n == 0 && return nothing
  place = lowercase(dirname(old)) == lowercase(dirname(new)) ? "name" : "place"
  say_result!(e, "Changed $n link$(n == 1 ? "" : "s") in $pages page$(pages == 1 ? "" : "s") to the new $place")
  nothing
end

"Move the file or the folder at `path` to the Trash. It's true when it went there."
trash(path) = begin
  Sys.isapple() || return false
  try
    with_pool() do
      url = msg(cls("NSURL"), "fileURLWithPath:", nsstring(path))
      ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
            msg(cls("NSFileManager"), "defaultManager"), sel("trashItemAtURL:resultingItemURL:error:"), url, C_NULL, C_NULL)
    end && !ispath(path)
  catch
    false
  end
end

# What moves a file to the Trash. A test puts a function of its own here, so it doesn't fill the Trash.
const trasher = Ref{Function}(trash)

"""
Move the file or the folder at `path` to the Trash and take it out of the
sidebar. A folder goes with everything in it. Changes that aren't saved are
written to their files first, so they are in the Trash too. Their tabs close.
If the file that was showing went, the tab under its tab shows, or with no
other tab open, the next file in the sidebar.
"""
trash!(e, path) = begin
  gone = paths_inside(e.buffers, path)
  foreach(p -> dirty(e.buffers[p]) && save!(e.buffers[p]), gone)
  ispath(path) && !trasher[](path) && return
  at = something(findfirst(==(path), e.files), 1)
  ts = tabs(e)
  # The tabs over the one of the file that shows, that stay open
  over = count(p -> !inside_path(p, path), ts[1:something(findfirst(==(e.buf.path), ts), length(ts) + 1)-1])
  filter!(p -> !inside_path(p, path), ts)
  foreach(p -> delete!(e.buffers, p), gone)
  foreach(p -> delete!(READ, p), paths_inside(READ, path))
  foreach(k -> delete!(e.nodes, k), nodes_inside(e, path))
  # The sidebar never lists a folder that went to the Trash
  inside_path(e.folder, path) && (e.folder = dirname(path))
  list_files!(e)
  if inside_path(e.buf.path, path)
    open!(e, !isempty(ts) ? ts[min(over + 1, end)] : isempty(e.files) ? joinpath(e.folder, "Untitled.md") : e.files[min(at, end)])
  else
    focus(e)
  end
  e
end

# --- the files that are open, as tabs -------------------------------------------------------
#
# Each file that shows in the window stays open as a tab at the top of the
# sidebar, over the folder, until ⌘W closes it. The tabs are in the order that
# their files opened, so a new one goes at the bottom. A click on a tab shows
# its file again, from where it was scrolled to, and the tab of the file that
# shows is shaded. While the mouse is over a tab, an × at its right end closes
# it, and so does a click with the middle button. A tab whose file has changes
# that aren't saved has a dot where the × shows. A tab shows what the tree
# shows of its file too: git's letter, like M for a file with changes, and a
# dot when an agent waits for the page. A terminal's tab has a ring that
# turns while its shell runs a command. A right-click shows the file's menu. A folder that shows in the page has no tab, and nor have the
# pages of the settings. When two tabs have the same name, each shows the name
# of its folder after it. When the tabs need more room than a third of the
# window, they scroll, and the tab of the file that shows stays in sight.
#
# ⌘W closes the tab of the file that shows: see "closing a file". ⌘T opens a
# new tab: the window shows no file, a tab called New Tab is at the bottom of
# the tabs, and the file finder opens. The file that you choose shows in that
# tab. ⌘W on it closes it, and the tab that showed last shows again. ⌘1 shows
# the first tab, ⌘2 the second, and so on to ⌘9. While ⌘ is held by itself,
# each of the first nine tabs shows its keys at its right end, like ⌘1. They
# show after `TAB_KEYS_WAIT`, so a quick ⌘S doesn't flash them. A file that
# gets a new name keeps its tab, and the tab of a file that goes to the Trash
# closes. Ladder keeps the front window's tabs when it quits, and opens with
# them the next time: see "where Ladder opens".

"The files that are open in the window of `e`, as tabs at the top of the sidebar, in the order that they opened"
tabs(e) = get!(() -> String[], e.nodes, :tabs)::Vector{String}

"True when the page at `path` can have a tab: a file, a new page that has no file yet, or a page from a web server. A folder can't."
tabbable(path) = !isempty(path) && (isremote(path) || !isdir(path) || news_tab(path))

"True when the folder at `path` is a folder of news, whose front page you read as a page, so it has a tab: see `news_companion!`"
news_tab(path) = isdir(path) && (try FS.get(FSPath(path)) isa NewsDirectory catch; false end)

"Show the page of the tab of `path`: its file, or the front page of a folder of news"
show_tab_page!(e, path) = isdir(path) ? open_folder!(e, path) : open!(e, path)

"Give the file that the window of `e` shows a tab at the bottom of the tabs, unless it has one. A page of the settings gets none."
add_tab!(e) = begin
  path = e.buf.path
  tabbable(path) && !issettings(e) && !(path in tabs(e)) && push!(tabs(e), path)
  e
end

"Close the tabs of files that have gone from the Mac and that the window has no page of, as when another app deleted one"
drop_gone_tabs!(e) = filter!(p -> p == e.buf.path || isremote(p) || showable(e, p) || news_tab(p), tabs(e))

"""
Take the tab of the file that shows out of the tabs, and give the tab that
shows in its place: the one that was under it, or the one above when it was
the last. On a page that has no tab, like a folder's, it's the tab that showed
last. It's nothing when no other tab is open.
"""
tab_after_close!(e) = begin
  drop_gone_tabs!(e)
  ts = tabs(e)
  i = findfirst(==(e.buf.path), ts)
  if i === nothing
    isempty(ts) && return nothing
    j = findlast(in(ts), e.back)
    return j === nothing ? ts[end] : e.back[j]
  end
  deleteat!(ts, i)
  isempty(ts) ? nothing : ts[min(i, end)]
end

"""
Close the tab of the file at `path`. When its file is the one that shows, the
file closes as ⌘W closes it, and the tab under it shows.
"""
close_tab!(e, path) = begin
  path == e.buf.path && return (close_file!(e); nothing)
  filter!(!=(path), tabs(e))
  nothing
end

"True while the window shows the new tab that ⌘T opened, with no file in it yet"
new_tab(e) = get(e.nodes, :new_tab, false) && nofile(e)

"""
Open a new tab, at the bottom of the tabs, and the file finder, to find the
file to show in it. A new tab that shows already stays. The settings window
has no tabs.
"""
new_tab!(e) = begin
  e = top_editor(e)
  issettings(e) && return e
  nofile(e) || show_no_file!(e)
  e.nodes[:new_tab] = true
  open_finder!(e)
  e
end

"Show the `n`th tab, from the top. Nothing happens when there are fewer tabs."
show_tab!(e, n) = begin
  e = top_editor(e)
  drop_gone_tabs!(e)
  n <= length(tabs(e)) && choose_tab!(e, tabs(e)[n])
  nothing
end

"The tabs' rows, by the path of each one's file: the tabs, and \"\" for a new tab that shows"
tab_rows(e) = new_tab(e) ? [tabs(e); ""] : tabs(e)

"Show the file of the tab at `path`, and give the text the keyboard. A tab whose file has gone closes."
choose_tab!(e, path) = begin
  drop_gone_tabs!(e)
  path in tabs(e) && path != e.buf.path && show_tab_page!(e, path)
  focus(e)
  nothing
end

"A file that's open, as a tab at the top of the sidebar"
@def mutable struct TabLabel <: SemanticUI
  path::String = ""
  close::Any = nothing   # its ×, made the first time the mouse is over the tab
end

"The × at the right end of a tab, while the mouse is over the tab. A click on it closes the tab."
@def mutable struct TabClose <: SemanticUI
  path::String = ""
end

"The tabs' list. It's a tree with no groups, so its rows look as the rows of the sidebar's tree of files do."
tab_tree(e) = node!(() -> Tree.ListTree(guides=true, frame=false, arrows=false, onchoose=item -> choose_tab!(e, item.firstchild.path)), e, :tab_tree)

"The name of the tab of `path`: the file's name, or the last name of the address of a page from a web server. A new tab has no file."
tab_name(path) = isempty(path) ? "New Tab" : (at = web_address(path); isempty(at) ? basename(path) : Remote.trail(at)[end][1])

"""
The name of the folder that the file of a tab is in, when another tab has the
same name, or nothing. It tells the two apart. `fill_tabs!` finds the names
that two tabs have.
"""
tab_folder(e, path) = !isempty(path) && !isremote(path) && tab_name(path) in get(e.nodes, :tab_twins, ()) ? basename(dirname(path)) : nothing

describe(l::TabLabel) = begin
  e = editor(l)
  shortcut = tab_keys(e, l.path)
  shows = l.path == e.buf.path
  over = Tree.hovered(l.parent)
  over && l.close === nothing && (l.close = own!(l, TabClose()))
  over && (l.close.path = l.path)
  closer = over && isempty(shortcut)
  folder = tab_folder(e, l.path)
  # The × has its middle where the last dot has its middle, so it shows in the dot's place: the row's end has less room while it shows
  Row(width(grow=grow), height(grow=grow), padding(0px, closer ? 8px + 3px - 9px : 8px, 0px, 0px), child_gap=4px, clip=true, name="Tab",
    # A folder with a tab is a folder of news
    mark(l, isempty(l.path) ? "plus-lg" : !isempty(web_address(l.path)) ? "globe" : isdir(l.path) ? "newspaper" : file_icon(l.path)),
    # The name loses its end, and not the × after it, when it's too long for the sidebar
    Box(width(grow=grow), Alignment.Start, clip_x=true,
      Row(Alignment.Center, child_gap=6px,
        Box(label(tab_name(l.path), color=colours.ink, weight=shows ? "Semibold" : "")),
        (folder === nothing ? () : (Box(label(folder, 11px, color=colours.faint)),))...)),
    tab_marks(e, l.path)...,
    # While ⌘ is held, the keys that show the tab take the place of the × and the dots
    (!isempty(shortcut) ? (Box(label(shortcut, 12px, color=colours.dim)),) :
     # The × takes the place of the dots as the mouse comes over the tab, and nothing moves to make room for it
     closer ? (l.close,) : tab_dots(e, l.path))...)
end

"""
The dots at the end of the tab of the file at `path`, as the sidebar's tree
has them: one in the colour of the Nudge button for a page that an agent
waits for, and a grey one for changes that aren't saved.
"""
tab_dots(e, path) = begin
  awaited = !isempty(path) && !isremote(path) && ismarkdown(path) && !isempty(agents(e, path))
  changed = haskey(e.buffers, path) && dirty(e.buffers[path])
  ((awaited ? (Box(width(6px), height(6px), radius(3px), background(colours.accent), name="Dot"),) : ())...,
   (changed ? (Box(width(6px), height(6px), radius(3px), background(colours.dim), name="Dot"),) : ())...)
end

"How long ⌘ is held by itself before the tabs show their keys, in seconds. A shortcut like ⌘S is quicker, so it doesn't flash them."
const TAB_KEYS_WAIT = 0.4

"""
True when the tabs show the keys that show them: ⌘ has been held by itself for
`TAB_KEYS_WAIT`. Until then, the window draws again when that time comes.
"""
tab_keys_shown!(e) = begin
  w = window_of(e)
  (w !== nothing && only_held(w, Keys.cmd)) || return (delete!(e.nodes, :tab_keys_since); false)
  since = get!(e.nodes, :tab_keys_since, time())
  left = TAB_KEYS_WAIT - (time() - since)
  left > 0 && (redraw_in!(e, left); return false)
  true
end

"The keys that show the tab of the file at `path`, like ⌘1, while the tabs show their keys, or \"\""
tab_keys(e, path) = begin
  get(e.nodes, :tab_keys_shown, false) || return ""
  n = findfirst(==(path), tabs(e))
  (n === nothing || n > 9) ? "" : String(strip(hint(e, Symbol(:tab_, n))))
end

"""
What the tab of the file at `path` shows of the file's state, after its name,
as the sidebar's tree shows it: git's letter for a file with changes, like M
or U. A terminal's tab has a ring that turns while its shell runs a command,
and none while the shell waits for one. The dots come after these: see `tab_dots`.
"""
tab_marks(e, path) = begin
  (isempty(path) || isremote(path)) && return ()
  o = object(e, path)
  v = get(e.nodes, (:term, path), nothing)
  talk = get(e.nodes, (:chat, path), nothing)   # a session's tab has the ring while its agent works
  working = (v !== nothing && Terms.busy(v)) || (talk isa AgentPane && talk.session !== nothing && talk.session.busy)
  working && redraw_in!(e, SPIN_FRAME)   # the ring turns
  ((o isa FSObject ? entry_marks(e, o) : ())...,
   (working ? (Box(fixed(18px), height(18px), Alignment.Center, justify=Alignment.Center, Spinner(size=11px)),) : ())...)
end

# A click with the middle button closes a tab, as it does in a web browser
onkey(l::TabLabel, ::KeyPress{Keys.mouse_middle}) = (close_tab!(editor(l), l.path); handled)

describe(c::TabClose) =
  Box(fixed(18px), height(18px), radius(4px), Alignment.Center, justify=Alignment.Center, name="Close",
      background(ishovered(c) ? colours.active : clear),
    Icon("x-lg", size=10px, color=ishovered(c) ? colours.ink : colours.dim))

cursor(::TabClose) = :hand
onkey(c::TabClose, ::KeyPress{Keys.mouse_left}) = (close_tab!(editor(c), c.path); handled)

"""
The file's menu, for a right-click on its tab. It has no Rename, since the
name of the file that's renamed is a text field in the sidebar's tree, and
the file may not be in the folder that the tree lists. A page from a web server has no menu.
"""
tab_menu!(e, w, path) = begin
  (isremote(path) || !ispath(path)) && return nothing
  file_menu!(e, w, path, items=filter(!=("Rename"), file_menu(path)))
end

"""
Make the tabs' list hold a row for each tab, and shade the tab of the file
that shows. Tabs whose files have gone close, once a second.
"""
fill_tabs!(e, tree) = begin
  t = get(e.nodes, :tabs_checked, 0.0)
  time() - t > 1 && (drop_gone_tabs!(e); e.nodes[:tabs_checked] = time())
  ts = tabs(e)
  rows = tab_rows(e)
  if [item.firstchild.path for item in tree.children] != rows
    kept = Dict(item.firstchild.path => item for item in tree.children)
    foreach(detach!, collect(tree.children))
    foreach(p -> add_child!(tree, get(() -> Tree.Item(TabLabel(path=p)), kept, p)), rows)
  end
  listed = collect(tree.children)
  i = findfirst(item -> item.firstchild.path == e.buf.path, listed)
  tree.focused = i === nothing ? nothing : listed[i]
  seen = Set{String}()
  e.nodes[:tab_twins] = Set(n for n in map(tab_name, ts) if n in seen || (push!(seen, n); false))
  tree
end

"""
Give the Scroll `s` a place of its own. A Scroll with none takes the place that
its node keeps for the Scroll that it made at that point in the frame, so the
tabs' scroll, which shows only while there are many tabs, would take the
place of the folder's files.
"""
own_scroll!(s) = (getfield(s, :state) === nothing && (s.offset = 0px); s)

"The most of the sidebar's height that the tabs take, as a part of the window's height. More tabs scroll."
const TABS_MOST = 1/3

"""
The tabs at the top of the sidebar, with a line under them, or nothing when no
tab is open. When they need more room than `TABS_MOST` of the window, they
scroll, and the tab of the file that shows comes into sight when another file
shows.
"""
tab_list(e) = begin
  rows = tab_rows(e)
  isempty(rows) && return ()
  e.nodes[:tab_keys_shown] = tab_keys_shown!(e)
  tree = fill_tabs!(e, tab_tree(e))
  high = Tree.ROW_HEIGHT   # the height of a row while the theme's text has its usual size, as the sidebar's has
  pad = 6px
  needs = high * length(rows) + 2pad
  room = max(high + 2pad, (window_size(e)[2] - above_page(e)) * TABS_MOST)
  scroll = node!(() -> own_scroll!(Scroll(width(grow=grow), height(grow=grow))), e, :tabs_scroll)
  at = findfirst(==(e.buf.path), rows)
  if needs > room && at !== nothing && get(e.nodes, :tab_shown, "") != e.buf.path
    # The scroll knows how tall it is once it has been laid out, so a scroll that's new waits a frame
    if scroll.viewport > 0px
      scroll_into_view!(scroll, high * (at - 1), high * at + 2pad)   # with the room above the tab and under it
      e.nodes[:tab_shown] = e.buf.path
    else
      redraw_in!(e, 0)
    end
  end
  list = Column(width(grow=grow), Alignment.Start, padding(pad, 8px, pad, 8px),
                with_theme(() -> describe!(tree), panel_theme()))
  (Box(width(grow=grow), height(min(needs, room)), Alignment.Start, name="Tabs", border(1px, :solid, colours.line)[:bottom],
       needs > room ? reuse!(scroll, list) : list),)
end

"Show the sidebar, if it's hidden, and give it the keyboard"
focus_panel!(e) = begin
  e.panel || toggle_panel!(e)
  focus(file_tree(e))
end

"""
The sidebar keeps its width as it slides in and out from the left edge of the
window, so only its right part shows while it's partly out. At its top are the
tabs of the files that are open. Under them, it lists the folder's files, and
under each file that's open in the list, that file's headings and components.
In agent mode it's dark, on the window's glass, as the agent's pane beside
it is, with a line between the two.
"""
describe(s::Sidebar) = (dark = agent_shows(editor(s)); with_pane_colours(() -> sidebar_view(s, dark), dark))

sidebar_view(s::Sidebar, dark::Bool) = begin
  e = editor(s)
  wide = panel_w(e)
  shows = wide * opened(e)
  # A folder shows as a tree of its files, unless code from the startup page lists it another way, as a folder of emails is listed
  own = folder_view(e, directory(e))
  list = own.list === nothing ? Column(width(grow=grow), Alignment.Start, padding(0px, 8px, 12px, 8px),
                                       with_theme(() -> describe!(fill_tree!(e, file_tree(e))), panel_theme())) : own.list
  own_scroll!(e.files_scroll)   # the tabs' scroll comes and goes over it
  Row(fixed(shows), height(grow=grow), Alignment.Start, clip=true,
    Column(fixed(wide), height(grow=grow), Alignment.Start, background(dark ? clear : colours.panel), name="Files",
           border(1px, :solid, dark ? on_glass(0.1) : colours.line)[:right], offset_x=shows - wide,
      (dark ? (PaneColours(on=true, across=true),) : ())...,   # it's drawn with the panes' colours too: see `PaneColours`
      Box(width(grow=grow), height(max(above_page(e), SIDE_GAP) - (dark ? 1px : 0px))),   # under the top bar
      tab_list(e)...,                            # the files that are open, over the folder
      Row(width(grow=grow), height(30px), padding(16px, 0px), Alignment.Center, clip=true, name="Folder",
        folder_trail(e, wide - 32px)...),
      (own.bar === nothing ? () : (own.bar,))...,
      reuse!(e.files_scroll, list),
      (dark ? (PaneColours(on=false, across=true),) : ())...))
end

"""
The side menu of the window while it's about `o`: a node. Ladder's own is its
sidebar. A kind of folder has a method of this to have a side menu of its own
in the sidebar's place: `side_menu(e, d)` for the folder, and
`side_menu(e, d, o)` for each thing `o` that it holds. Ladder's sidebar isn't
there then: nothing of it shows, not its colour, its line, its tabs or its
list. So the kind's menu draws all of itself, on the page's colour.

The kind's menu has the sidebar's room. It's as wide as the sidebar, which you
drag, and it runs from the top of the window to the bottom, so the window's
buttons and the left end of the top bar lie over its top: `above_page(e)` is
how tall that part is. It slides in and out as the sidebar does.

A kind's menu can have a compact form, which stays while the sidebar is
closed: a method of `compact_width` for the menu's node says how wide that is.
The menu then never slides out. It narrows to that width, and it's laid out as
wide as it shows. While the sidebar is closed, `e.panel` is false, and the
menu draws its compact form. Such a menu is always there, so the top bar's own
button that shows and hides the sidebar goes. A method of `side_button` for the
menu's node gives a button of the menu's own for that place.
"""
side_menu(e, o) = side_menu(e, o.parent, o)
side_menu(e, ::Nothing) = side_menu(e, nothing, nothing)
side_menu(e, d, o) = node!(Sidebar, e, :sidebar)

"""
How wide the side menu `menu` stays while the sidebar is closed: its compact
form, like a rail of icons. 0px is a menu that goes when the sidebar closes,
as Ladder's sidebar does. A kind of folder has a method of this for the node
that its `side_menu` gives.
"""
compact_width(menu) = 0px

"""
The button that the top bar has for the side menu `menu`, in the place of its
own button that shows and hides the sidebar: a node 30px wide at the most, or
nothing. The top bar lies over the top of the menu and takes the clicks there,
so a button in that place is the bar's to draw. It's asked only for a menu
with a compact form. Its click calls `toggle_panel!(e)`.
"""
side_button(menu) = nothing

"""
Find the side menu of the window of `e` for this frame, before anything is
laid out: the page beside it needs its width. `side_part` shows it.
"""
side_tick!(e) = begin
  menu = side_menu(e, window_object(e))
  own = !(menu isa Sidebar)
  e.nodes[:side_menu] = menu
  e.nodes[:own_side_menu] = own
  least = own ? clamp(compact_width(menu), 0px, panel_w(e)) : 0px
  e.nodes[:side_least] = least
  # In agent mode the agent's pane is beside the side menu, and it gives the menu its room: see `menu_room`. While the
  # menu slides, the pane is as wide as it is beside the open menu, so its words don't wrap again in each frame.
  e.nodes[:menu_room] = !agent_shows(e) ? 0px : e.panel || sliding(e) ? panel_w(e) : least
  agent_shows(e) && sliding(e) && redraw_in!(e, 0)   # one more frame after the slide ends gives the pane its room back
  nothing
end

"How wide the side menu stays while the sidebar is closed: its compact form's width, or 0px"
side_least(e) = get(e.nodes, :side_least, 0px)

"""
How wide the sidebar is now, or the side menu that a kind of folder has in its
place: all of its width while it's open, none while it's closed, or the width
of its compact form, and between the two while it slides.
"""
menu_w(e) = (least = side_least(e); least + (panel_w(e) - least) * opened(e))

"""
How wide all that's at the left of the page is now: the sidebar, or the side
menu that a kind of folder has in its place, and in agent mode the agent's
pane beside it.
"""
side_w(e) = menu_w(e) + (agent_shows(e) ? agent_wide(e) : 0px)

"""
What's at the left of the window of `e`: Ladder's sidebar, or the side menu
that a kind of folder has in its place, in the sidebar's room.
"""
side_part(e) = begin
  haskey(e.nodes, :side_menu) || side_tick!(e)
  menu = e.nodes[:side_menu]
  menu isa Sidebar && return menu
  wide, shows = panel_w(e), menu_w(e)
  # A menu with a compact form narrows to it, and is laid out as wide as it shows
  side_least(e) > 0px && return Row(fixed(shows), height(grow=grow), Alignment.Start, clip=sliding(e), name="Side menu", menu)
  # Another keeps its width while it slides, as the sidebar does. Once it's open nothing clips it, so a shadow of its own shows whole.
  Row(fixed(shows), height(grow=grow), Alignment.Start, clip=opened(e) < 1, name="Side menu",
    Column(fixed(wide), height(grow=grow), Alignment.Start, offset_x=shows - wide, menu))
end

"True when the window has a side menu that a kind of folder made, in the place of Ladder's sidebar"
own_side_menu(e) = get(e.nodes, :own_side_menu, false) === true

"True when the sidebar shows Ladder's own tree of the folder's files, and not a list or a menu that a kind of folder made"
files_listed(e) = !own_side_menu(e) && folder_view(e, directory(e)).list === nothing

# --- the edge of the sidebar ----------------------------------------------------------
#
# Drag the line at the sidebar's right edge to make the sidebar wider or
# narrower. A strip a few pixels wide lies over the line, so the mouse
# catches it easily, and the cursor shows arrows that point left and right
# over it. The sidebar keeps the width you give it, in the settings file too.

@def mutable struct PanelEdge <: SemanticUI
  grab::px = 0px   # how far right of the sidebar's edge the mouse was when the drag started
end

describe(::PanelEdge) = Box(width(EDGE_W), height(grow=grow), name="Edge")

cursor(::PanelEdge) = :resize_x

onkey(p::PanelEdge, ev::KeyPress{Keys.mouse_left}) = (p.grab = ev.window.mouse[1] - panel_w(editor(p)); handled)

onmouse(p::PanelEdge, ev::MouseMove) = begin
  held(p, Keys.mouse_left) || return
  side!(editor(p), ev.position[1] - p.grab)
  handled
end

"The strip over the sidebar's edge, while the sidebar is open and not sliding. It starts under the top bar."
panel_edge(e) = e.panel && !sliding(e) && lowered(e) === nothing ?
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(above_page(e), 0px, 0px, panel_w(e) - EDGE_W / 2),
       node!(PanelEdge, e, :edge)),) : ()

# --- the folder at the top of the sidebar ---------------------------------------------

const TRAIL_SIZE = 12px
const TRAIL_ARROW = 7px   # the size of the arrow between two names
const TRAIL_GAP = 2px     # on each side of an arrow
const TRAIL_PAD = 3px     # inside a name, on each side, so its hover background has room

"""
The names of the folders on the way to `folder`, each with where it is, in no
more than `room` with an arrow between each two. The sidebar is narrow, so when
the names don't fit, the ones furthest from the folder shrink to their first
letter, from the left, like `~ › D › Canon › City`. If that still doesn't fit, an
… takes the place of names after the first, and last of all the folder's own
name loses its middle. The … has no path.
"""
trail_names(folder, room) = begin
  short = steps(folder)
  face(i) = Face(SANS, i == length(short) ? "Semibold" : "", TRAIL_SIZE, colours.ink, false)
  wide() = sum(i -> measure(face(i), short[i][1]) + 2TRAIL_PAD, eachindex(short)) + (length(short) - 1) * (TRAIL_ARROW + 2TRAIL_GAP)
  # A hidden folder keeps its dot, so .config shrinks to .c
  initial(n) = startswith(n, '.') ? first(n, 2) : first(n, 1)
  for i in 2:length(short)-1
    wide() <= room && return short
    short[i] = (initial(short[i][1]), short[i][2])
  end
  while wide() > room && length(short) > 2 && short[2][1] != "…"
    # The first name stays, so the trail still shows where it starts
    deleteat!(short, 2)
    length(short) > 2 ? (short[2] = ("…", "")) : insert!(short, 2, ("…", ""))
  end
  while wide() > room && length(short) > 3
    deleteat!(short, 3)
  end
  # A folder whose own name is too long loses the middle of it
  name, at = short[end]
  k = length(name) ÷ 2
  while wide() > room && k > 2
    k -= 1
    short[end] = (first(name, k) * "…" * last(name, k), at)
  end
  short
end

"One name in the trail at the top of the sidebar. A click shows that folder in the sidebar."
@def mutable struct TrailName <: SemanticUI
  path::String = ""   # empty for the … that stands for names left out
  name::String = ""
  last::Bool = false  # the folder that the sidebar shows
end

"The folder at the top of the sidebar, as a trail of names"
folder_trail(e, room) = begin
  names = trail_names(e.folder, room)
  arrow() = Box(padding(TRAIL_GAP, 0px), Icon("chevron-right", size=TRAIL_ARROW, color=colours.faint))
  parts = Any[]
  for (i, (n, at)) in enumerate(names)
    i > 1 && push!(parts, arrow())
    # Each name is kept, so it knows when the mouse is over it
    t = node!(() -> TrailName(), e, (:trail, i))
    t.path, t.name, t.last = at, n, i == length(names)
    push!(parts, t)
  end
  parts
end

"""
True when a click on the name `t` goes somewhere: to a folder further up, or,
for the sidebar's own folder, to that folder while the window shows another page.
"""
goes(t::TrailName) = !isempty(t.path) && (!t.last || page_elsewhere(editor(t)))

"True when the window shows another page than the sidebar's own folder"
page_elsewhere(e) = (d = directory(e); d isa AbstractDirectory && e.buf.path != string(d.path))

describe(t::TrailName) =
  Box(padding(TRAIL_PAD, 1px), radius(4px), background(goes(t) && ishovered(t) ? colours.hover : clear),
    label(t.name, TRAIL_SIZE, color=t.last ? colours.ink : colours.dim, weight=t.last ? "Semibold" : ""))

cursor(t::TrailName) = goes(t) ? :hand : :arrow

onkey(t::TrailName, ::KeyPress{Keys.mouse_left}) = goes(t) ? (open_folder!(editor(t), t.path); handled) : nothing

"""
Open the folder at `path` in the page: its own page, like the home folder's,
a desktop's or a blog's Readme, or else a list of what's in it. The sidebar
lists the folder, and a sidebar that's hidden stays hidden. The trail at the
top of the sidebar, the path in the top bar and the home folder's page open a
folder this way. With `own` false, a folder whose own page is a file in it,
like a blog, shows only its list: ⌘W does that, so it opens no file.
"""
open_folder!(e, path; own=true) = begin
  (isdir(path) && !ispackage(path)) || return show_path!(e, path)
  # The folder's own page says its kind, and loads the code of the kind. It runs now if it hasn't.
  folder_pages!(path)
  Base.invokelatest(own ? follow_folder! : show_folder!, e, path)
end

show_folder!(e, path) = (go_folder!(e, path); show_beside!(e, path); e)

# The backdrop is behind the file finder, and a click on it closes the finder. It doesn't
# dim the page, as the command palette doesn't.
describe(b::Backdrop) = Box(width(grow=grow), height(grow=grow))
onkey(b::Backdrop, ::KeyPress) = (e = editor(b); e.popup = :none; focus(e))

# --- the menu of the page ------------------------------------------------------------------
#
# A right-click on the page opens a menu at the mouse: cut, copy, paste, select
# all, find, export, Insert and Show as Slides. On a word that's spelt wrong, the menu starts
# with the words it may have been meant to be. Insert opens a menu of the kinds of block that a page can
# hold. A right-click on the selection keeps it. Anywhere else, it puts the
# caret there first.

"""
What the Insert menu adds. Each one has its name, the lines of the block, and
the line and the column of the block that the caret goes to. "-" is a line
between two groups.
"""
const INSERTS = [
  ("Paragraph",     [""],                           (1, 0)),
  ("Heading 1",     ["# "],                         (1, 2)),
  ("Heading 2",     ["## "],                        (1, 3)),
  ("Heading 3",     ["### "],                       (1, 4)),
  "-",
  ("Bulleted List", ["- "],                         (1, 2)),
  ("Numbered List", ["1. "],                        (1, 3)),
  ("To-do",         ["- [ ] "],                     (1, 6)),
  ("Quote",         ["> "],                         (1, 2)),
  ("Callout",       ["> [!NOTE]", "> "],            (2, 2)),
  "-",
  ("Table",         ["|  |  |  |", "|---|---|---|", "|  |  |  |", "|  |  |  |"], (1, 2)),
  block_insert(SHEET),
  block_insert(SPREADSHEET),
  ("Code",          ["```julia", "", "```"],        (2, 0)),
  block_insert(LIVE),
  block_insert(DIAGRAM),
  ("Formula",       ["\$\$", "", "\$\$"],           (2, 0)),
  # An agent writes a question and a set of changes, so the menu has neither
  (block_insert(lang) for lang in (TAKEOFF, SCHEDULE, CHART, BOARD, CALENDAR, DAY_BLOCK, COLUMN_BLOCK, FIND,
                                   CHECK, FILTER, SAVE, LOAD, FORM, SKETCH, CANVAS, VIEW_BLOCK, RESULT,
                                   SIGNATURE, CONTACT, GALLERY, MAP, TIMELOG))...,
  # A card is the address of a page, written as a picture's is. The caret goes after the https://.
  ("Link Card",     ["![](https://)"],              (1, 12)),
  # This one records from the microphone into a new file, and the line shows the recorder. The caret goes
  # to an empty line under it, so that you can type while it records.
  ("Recording",     ["![Recording]()", "", ""],     (3, 0)),
  "-",
  # The caret goes to an empty line under the divider
  ("Divider",       ["---", "", ""],                (3, 0)),
  "-",
  # This one goes at the top of the document, wherever the caret is
  ("Front Matter",  ["---", "title: ", "---"],      (2, 7)),
]

# Ask Agent… shows with the name of the agent that it asks, like "Ask Claude…": see `page_menu!`
const PAGE_MENU = ["Ask Agent…", "-", "Cut", "Copy", "Paste", "-", "Select All", "-", "Find…", "Export as HTML…", "-",
                   "Insert" => [x isa String ? x : x[1] for x in INSERTS], "-", "Show as Slides"]

cut!(e) = begin
  run = picked(e.buf)
  copied = copy_selection!(e)
  COPIED_BLOCK[] = nothing   # a block that's cut leaves its page, so it pastes as its lines
  copied === false && return false
  # The part that the caret was on as a whole goes, as ⌫ takes it
  run === nothing ? each_selection!(() -> type!(e, ""), e) : delete_lines!(e)
end
select_all!(e) = begin
  b = e.buf
  b.reading = false   # a selection shows the caret's end of it
  # In a part of another page, it's all of the part
  s, t = hosted(e) === nothing ? (1, length(b.lines)) : e.nodes[:span]
  b.anchor, b.caret = (s, 0), line_end(b, t)
  e
end

"The last line of the block that line `i` is in: the end of its table or of its code block, or the line itself"
block_end(b::Buffer, i::Int) = begin
  k = kinds(b)[i].kind
  k == Kind.table ? table(b, i)[2] : k in (Kind.fence, Kind.code) ? codeblock(b, i)[2] : i
end

"""
Add a block of `lines` to the document, and put the caret at `at`: a line and
a column of the block. On an empty line, the block takes that line's place.
From any other line, it goes after the block that the caret is in. An empty
line goes between the new block and the text on each side of it. A list item
that's added to a list of its own kind goes straight after the item before it.
"""
add_block!(e, lines::Vector{String}, at::Pos) = begin
  b = e.buf
  ks = kinds(b)
  i = b.caret[1]
  onblank = ks[i].kind == Kind.blank
  t = onblank ? i : block_end(b, i)
  before, after = (onblank ? i - 1 : t), t + 1   # the lines that the block will sit between
  blank(j) = !(1 <= j <= length(ks)) || ks[j].kind == Kind.blank
  kind = Line(lines[1]).kind
  item = kind in (Kind.bullet, Kind.ordered, Kind.todo)
  joins = item && !blank(before) && ks[before].kind == kind
  if joins
    # It's the next item of that list: the next number, and as far in as the item before
    lead = carry(head(b.lines[before], ks[before].prefix), kind)
    lines, at = [lead], (1, length(lead))
  end
  pre = !joins && !blank(before)
  post = !blank(after) && !(item && ks[after].kind == kind)
  new = join([pre ? [""] : String[]; lines; post ? [""] : String[]], "\n")
  onblank ? edit!(b, (i, 0), line_end(b, i), new) : edit!(b, line_end(b, t), line_end(b, t), "\n" * new)
  row = (onblank ? i : t + 1) + pre + at[1] - 1
  b.caret = b.anchor = (row, at[2])
  # In a new table, the first cell is selected, as Tab would leave it
  cells = kinds(b)[row].kind == Kind.table ? tablecells(b.lines[row]) : Cell[]
  isempty(cells) || (b.anchor = (row, cells[1].lo); b.caret = (row, cells[1].hi))
  focus(e)
  touch!(e)
end

"""
Add front matter to the top of the document, and put the caret after its first
key. A document has front matter only once, so if it's there already the caret
just goes to it.
"""
add_front_matter!(e) = begin
  b = e.buf
  if front_matter(b.lines) == 0
    _, lines, _ = last(INSERTS)
    # An empty line goes between the front matter and the text
    edit!(b, (1, 0), (1, 0), join(lines, "\n") * "\n" * (isempty(strip(b.lines[1])) ? "" : "\n"))
  end
  b.caret = b.anchor = line_end(b, 2)
  focus(e)
  touch!(e)
end

"Do what the item at `i` of the page's menu does. `j` is the item's place in the Insert menu, when it's one of those."
page_act!(e, i::Int, j::Int=0) = begin
  name = PAGE_MENU[i] isa Pair ? first(PAGE_MENU[i]) : PAGE_MENU[i]
  if name == "Ask Agent…"
    ask_selected!(e)
  elseif name == "Cut"
    cut!(e)
  elseif name == "Copy"
    # While an email as it was sent has the keyboard, what's selected is its words
    a = sent_keys(e)
    a === nothing ? copy_selection!(e) : sent_copy!(a)
  elseif name == "Paste"
    paste!(e)
  elseif name == "Select All"
    a = sent_keys(e)
    a === nothing || a.of.shown === nothing ? select_all!(e) : sent_select_all!(a)
  elseif name == "Find…"
    find!(e)
  elseif name == "Export as HTML…"
    w = window_of(e)
    w === nothing || export_html!(e, w)
  elseif name == "Show as Slides"
    show_slides!(e)
  elseif name == "Insert" && j in eachindex(INSERTS) && INSERTS[j] isa Tuple
    block = INSERTS[j][1]
    block == "Front Matter" ? add_front_matter!(e) : block == "Recording" ? add_recording!(e) : add_block!(e, INSERTS[j][2], INSERTS[j][3])
  end
  nothing
end

"Show the page's menu at the mouse"
page_menu!(e, w) = begin
  b = e.buf
  b.view == :file && return nothing   # a viewer has no text to copy or to find
  e.popup = :none
  focus(e)
  at = settle(b, locate(e, w.mouse))
  # A right-click on a part that shows as one thing, like a formula or a diagram, puts the caret on it as a whole, as a click does
  it = isempty(e.layout) ? nothing : e.layout[item_under(e, w.mouse[1] - e.origin[1], w.mouse[2] - e.origin[2])]
  it !== nothing && it.content isa Live && rich(b) && !b.fixed && part(b, it.first) == (it.first, it.last) && (at = (it.first, 0))
  lo, hi = selection(b)
  # A right-click on the selection keeps it. Anywhere else, it puts the caret there.
  if !(selecting(b) && lo <= at <= hi)
    b.caret = b.anchor = at
    touch!(e)
  end
  # A right-click on a word that's spelt wrong puts the words it may have been meant to be at the top of the menu
  wrong = misspelling_at(e, at)
  fixes = wrong === nothing ? String[] : first(guesses(rest(head(b.lines[wrong[1]], wrong[3]), wrong[2])), 5)
  spell = wrong === nothing ? Any[] : Any[(isempty(fixes) ? ["No Guesses Found"] : fixes)..., "Learn Spelling", "-"]
  n = length(spell)
  act(i, place...) = i <= n ? spell_act!(e, wrong, fixes, i) : page_act!(e, i - n, place...)
  # Cut and Copy are grey with nothing selected, and Front Matter is grey in a document that has it
  off = Any[]
  wrong !== nothing && isempty(fixes) && push!(off, 1)
  selecting(b) || append!(off, n .+ findall(in(("Cut", "Copy")), PAGE_MENU))
  front_matter(b.lines) == 0 || push!(off, (n + findfirst(x -> x isa Pair, PAGE_MENU), length(INSERTS)))
  # Each item that would change the text is grey for a file that's only shown
  readonly(b) && append!(off, n .+ findall(x -> (x isa Pair ? first(x) : x) in ("Cut", "Paste", "Export as HTML…", "Insert", "Show as Slides"), PAGE_MENU))
  b.fixed && append!(off, n .+ findall(x -> (x isa Pair ? first(x) : x) in ("Cut", "Paste", "Insert"), PAGE_MENU))
  # A file of code is no page, and has no place for a table or a recording
  b.view == :code && append!(off, n .+ findall(x -> (x isa Pair ? first(x) : x) in ("Export as HTML…", "Insert", "Show as Slides"), PAGE_MENU))
  # A part of another page isn't the page that the window shows
  hosted(e) === nothing || append!(off, n .+ findall(x -> (x isa Pair ? first(x) : x) in ("Find…", "Export as HTML…", "Show as Slides"), PAGE_MENU))
  # Ask Agent… names the agent that it asks
  items = Any[spell..., (x == "Ask Agent…" ? "Ask $(asks_whom(e))…" : x for x in PAGE_MENU)...]
  system_menu(w, items, act; off) || drawn_menu!(w, items, act; off)
  nothing
end

"Show the menu for what the mouse is over: the page, or a file in the sidebar"
context_menu!(e, w) = begin
  # The text is the editor's own node, so the mouse can be over it and not over the area around it
  onpage = ishovered(node!(Document, e, :document)) || ishovered(node!(Page, e, :page))
  onpage ? page_menu!(e, w) : file_menu!(e, w)
end

# --- the file finder and the project picker ------------------------------------------------
#
# ⌘O opens the file finder: a bar near the top of the window, with a list of
# the folder's pages under it. ⌘P opens the project picker, which looks the
# same and lists projects: the folders that you made favourites, in your
# order, then the git repositories in your home folder, the one that git last
# wrote in first. See "the projects" in folders.jl. Type some letters of a
# name, in order, and the list keeps the rows that have them. ↑ and ↓ choose a
# row, Return opens it and Esc closes the list. A project opens in the window,
# as a click on a folder in the top bar's path opens it. `e.popup` is
# `:finder` or `:projects` while one shows.
#
# Both have the command palette's colours, its font and its rows. The list is
# in the same box as the field, so the two are as wide as each other.

"Open the file finder"
open_finder!(e) = (list_files!(e); open_picker!(e, :finder, "Find a file, or type a web address"))

"Open the project picker. A search for the projects starts on a second thread."
open_projects!(e) = (project_list(e); open_picker!(e, :projects, "Find a project"))

open_picker!(e, kind, words) = begin
  e.popup = kind
  e.picked = 1
  i = input(e)
  i.text = ""
  i.cursor = i.anchor = 0
  # The command palette has the same field, with other words in it and smaller text beside a chip
  i.placeholder, i.font_size, i.font_family = words, 15px, omni_font()
  focus(i)
end

"The projects that the picker lists: the favourites that are there, then the git repositories of the home folder that aren't favourites"
project_list(e) = begin
  favourites = filter(isdir, Folders.favourites())
  [favourites; filter(!in(favourites), Folders.projects(home_folder()))]
end

"Where the project at `path` is, as its row says: the folder that it's in, with ~ for the home folder"
project_place(path) = (d = dirname(path); inside_path(d, homedir()) ? "~" * d[ncodeunits(homedir())+1:end] : d)

"Open the row for `path`: a page of the folder, or a project in the window"
picker_open!(e, path) =
  if e.popup == :projects
    e.popup = :none
    focus(e)
    open_folder!(e, path)
  else
    open!(e, path)
  end

"The pages, or the projects, whose names have the letters typed, in order"
matches(e) = begin
  q = lowercase(input(e).text)
  filter(e.popup == :projects ? project_list(e) : e.files) do path
    name = lowercase(basename(path))
    at = firstindex(name)
    all(q) do c
      found = findnext(c, name, at)
      found === nothing ? false : (at = nextind(name, found); true)
    end
  end
end

"""
The parts of `name`, each with true when its letters are ones that `typed`
has. They're the letters that `matches` finds: the first of each, in order.
"""
letter_runs(name::AbstractString, typed::AbstractString) = begin
  want = collect(lowercase(typed))
  runs = Tuple{String,Bool}[]
  j = 1
  for c in name
    hit = j <= length(want) && lowercase(c) == want[j]
    hit && (j += 1)
    !isempty(runs) && last(runs)[2] == hit ? (runs[end] = (last(runs)[1] * c, hit)) : push!(runs, (string(c), hit))
  end
  runs
end

const FINDER_TOP = 90.0     # how far the finder's bar is from the top of the window
const FINDER_WIDE = 600.0   # how wide its bar is, when the window has room for it
const FINDER_MOST = 9       # the most rows that its list shows

"The rows that the list shows: as many as fit in the window, up to `FINDER_MOST`"
finder_shown(e) = begin
  # Besides the rows, the box has the field, 4 lines and 6px under the card. The window keeps 24px under the box.
  room = num(window_size(e)[2]) - FINDER_TOP - OMNI_FIELD_H - 4 - 6 - 24
  first(matches(e), clamp(floor(Int, room / OMNI_ROW_ONE), 1, FINDER_MOST))
end

finder_key!(e, K) = begin
  found = finder_shown(e)
  # Esc, Return, ↓ and ↑ do what they do here only by themselves
  stepping = K in (Keys.escape, Keys.enter, Keys.down, Keys.up)
  stepping && !unmodified(e) && return nothing
  if K == Keys.escape
    e.popup = :none
    focus(e)
  elseif K == Keys.enter
    # An address on the web that's typed in the file finder is asked for: see "a page from a web server"
    address = finder_address(e)
    address !== nothing ? (e.popup = :none; focus(e); get_page!(e, address)) :
    isempty(found) ? (e.popup = :none; focus(e)) : picker_open!(e, found[clamp(e.picked, 1, length(found))])
  elseif K == Keys.down
    e.picked = min(e.picked + 1, max(1, length(found)))
  elseif K == Keys.up
    e.picked = max(e.picked - 1, 1)
  else
    e.picked = 1
  end
  nothing
end

"Where the finder's box is in the window: its left side, its top and its width. It's centred beside the sidebar."
finder_place(e) = begin
  left, room = num.(page_span(e))
  wide = min(FINDER_WIDE, room - OMNI_LEFT - OMNI_RIGHT)
  (x=left + round((room - wide) / 2), y=FINDER_TOP, w=wide)
end

# The text typed starts where the names of the files under it do: 6px to the card, its line, and 14px in the row
describe(f::FinderInput) = Row(width(grow=grow), height(grow=grow), padding(0px, px(OMNI_BAR_X), 0px, 21px), name="File field", input(editor(f)))
onkey(f::FinderInput, ::KeyPress{Keys.mouse_left}) = focus(input(editor(f)))
cursor(::FinderInput) = :ibeam

"The web address that's typed in the file finder, or nothing when what's typed isn't one. No file's name has a / in it, so an address fits no file."
finder_address(e) = e.popup == :finder ? Remote.typed(input(e).text) : nothing

"What the list says when it has no row"
picker_none(e) =
  finder_address(e) !== nothing ? "Press Return to open $(Remote.label(finder_address(e)))" :
  e.popup == :finder ? "No file has that name" :
  Folders.searching() !== nothing && isempty(project_list(e)) ? "Looking for projects…" :
  isempty(strip(input(e).text)) ? "Your home folder has no git repository" : "No project has that name"

finder(e) = begin
  c = omni(e)
  i = input(e)
  i.color, i.placeholder_color, i.font_size, i.font_family = c.ink, c.muted, 15px, omni_font()
  # While the projects are searched for, the window looks again soon for what the search found
  e.popup == :projects && Folders.searching() !== nothing && redraw_in!(e, 0.1)
  found = finder_shown(e)
  rows = isempty(found) ?
    Row(width(grow=grow), height(px(OMNI_ROW_ONE)), padding(14px, 0px), Box(omni_label(picker_none(e), 14, c.ink, weight=OMNI_NAME))) :
    Column(width(grow=grow), Alignment.Start, [node!(() -> FileRow(path=p, finder=n), e, (:pick, n, p)) for (n, p) in enumerate(found)]...)
  at = finder_place(e)
  # The field is at the top of the box, and the rows are under it on a card with a line round it, 6px inside the box
  omni_at(at.x, at.y, Column(fixed(px(at.w)), Alignment.Start, radius(6px), background(c.drop), border(1px, :solid, c.drop_line),
                             shadow(0, 4, 18, RGBA(0, 0, 0, e.theme == :night ? 0.5 : 0.14)), name=e.popup == :projects ? "Project picker" : "File finder",
    Box(width(grow=grow), height(px(OMNI_FIELD_H)), node!(FinderInput, e, :finder_input)),
    Box(width(grow=grow), padding(0px, 6px, 6px, 6px),
      Column(width(grow=grow), Alignment.Start, radius(4px), clip=true, background(c.drop), border(1px, :solid, c.drop_line), rows))))
end

# --- the command palette --------------------------------------------------------------------
#
# ⌘⇧P opens the command palette. It's Ladder's command line, and it's a copy of
# the omnibar of Centient: how it looks, where it is and what each key does.
# The sizes and the colours here are from Centient's style sheets, and the
# rules are from its code (src/omnibar in Centient). Where Ladder has no use
# for a part of the omnibar, this section says so.
#
# A bar slides up from the bottom of the window, beside the sidebar. Type some
# letters of a command's name, or of what it does. A list over the bar keeps
# the commands that have them, with the nearest first. With no letters, it has
# every command in the order of the alphabet. ↑ and ↓ choose a row, Tab types
# the rest of the first name, Return takes the row, and esc clears the bar.
# Esc in an empty bar closes it. A row has the command's keys at its right.
#
# The list has only the commands that have a use where the keyboard was when
# the palette opened. What's in focus there says which: the part of the page
# that the caret is on, the page, its file and its folder. See "what's in
# focus". A command that works on one of those has its name after its own in
# the row, as Move To Trash has the name of the file. Centient's omnibar has
# no such rule: this is Ladder's own.
#
# A command that takes nothing runs when it's taken. A command that is a Julia
# function asks for each thing that the function takes. Its name stays in the
# bar as a tag, with a chip after it for each argument and a Run button after
# those. A chip is made from an argument's name and its type. The type says
# what kind of chip it is:
#
#   - a switch, for a `Bool`. Space turns it on or off. Return does too, and
#     goes on to the next chip.
#   - a choice of two, for a type with two fixed things to choose from. Both
#     show in the chip. ← and → choose, and so do Space and Return.
#   - a list of three or four fixed things. It hangs over the chip. ↑ and ↓
#     choose, and Return or Tab takes the row and goes on.
#   - a list that's searched, for five or more things, or things that change,
#     like the headings of the page. What you type keeps the rows that have
#     those letters. ↑ and ↓ choose a row, and Return or Tab takes it.
#   - a number or words, which you type. The chip has them as you type, and
#     Return goes on. ↑ and ↓ add one to a number, or take one away.
#
# Tab and ⇧Tab go from chip to chip, round through the Run button. Return on
# Run calls the function. A function's keyword arguments are chips too, which
# show when you press ⌥ and hide when you press it again. Chips that don't fit
# in the bar end in a … button: a click on it, or Tab past the last chip that
# shows, puts them on more lines.
#
# A type says how it's asked for with methods:
#
#   - `choices_for(::Type{T}, e)` gives the things of type `T` to choose
#     from, for the editor `e`
#   - `typed_as(::Type{T}, text)` gives the thing of type `T` that `text`
#     writes, or nothing when it writes none
#   - `chip_kind(::Type{T})` is `:choice` for a type whose things to choose
#     from are few and fixed, like the colours of a page
#   - `worded(x)` gives the words that a row and a chip show for `x`, and
#     `sidenote(x)` the fainter words at the right of its row
#
# An argument of type `Editor`, or one called `e` with no type, isn't asked
# for: it's the window's editor. A `Window`, or a `w` with no type, is its
# window. An argument of a type with neither of the first two methods can't be
# asked for. It's the nearest thing in focus of that type, like the file that
# shows for a `File`. The palette leaves out a method when nothing in focus is
# of that type, and a command when it has no method left.
#
# A function can have several methods, as in Centient. Where they take the
# same type, there's one chip. Where they take a type itself, like
# `f(::Type{Page})` and `f(::Type{Folder})`, the chip chooses between them and
# the chips after it wait for that. Where they take values of different types,
# the chip takes any of them and the chips of the first method show. What's
# said then chooses the methods that go on, so Julia's own dispatch chooses
# what runs. A method that stops where another goes on makes the chips after
# that place ones that can be left out.
#
# What Centient's omnibar has that this doesn't: the bar isn't in the window
# all the time, and the strip that it's in has no colour of its own, so the
# page shows through it, blurred. It takes no message for an agent, so there's no `/` before a
# command. A click outside the list closes the palette. A date is typed, with
# no calendar. A command runs at once, so the Run button never shows that it's
# running. `add_command!` makes a function a command: see "commands that are functions".

# The strip that the bar is in: the room round the bar. It has no colour and no line: the page under it is blurred, and the blur fades out above the bar.
const OMNI_TOP, OMNI_RIGHT, OMNI_BOTTOM, OMNI_LEFT = 14.0, 16.0, 16.0, 14.0
const OMNI_FIELD_H = 44.0      # how tall the bar is with only its field in it, without its border
const OMNI_BAR_X, OMNI_BAR_Y = 14.0, 10.0   # the room inside the bar
const OMNI_GAP = 6.0           # between the tag, the chips and the Run button
const OMNI_CHIP_H = 32.0
const OMNI_ROW = 70.0          # a row of a list with a name and what it does under it
const OMNI_ROW_ONE = 50.0      # a row with a name only
# The weight of a name in a list, and of the letters typed that it has. Centient's Medium looked fuzzy in the Mac's font.
const OMNI_NAME, OMNI_MATCH = "SemiBold", "Heavy"
# The palette's text is in Manrope, as Centient's omnibar is. fonts/ has a file for each weight,
# cut from Centient's variable font. A Ladder without those files uses the Mac's font.
# The keys beside a command stay in the Mac's font, because Manrope has no ⌘, ⇧, ⌥ or ⌃.
const OMNI_FONT_FILES = [joinpath(@__DIR__, "fonts", "Manrope-$w.ttf") for w in ("Regular", "Medium", "SemiBold", "Bold", "ExtraBold")]
const omni_family = Ref(SANS)
"The family of the palette's text: Manrope once its files are read, and the Mac's font before that or without them"
omni_font() = omni_family[]
"""
`family`, after the font files `files` are read, or else `fallback`: when a
file isn't there, or can't be read. The app's self-test runs where it can see
Ladder's folder but can't read what's in it.
"""
font_from(files, family, fallback) = all(isfile, files) && (try foreach(register_font, files); true catch; false end) ? family : fallback
"""
Read the palette's font from its files. As with the sheet's font, a built app
forgets them when it starts. The files are looked for each time, not when the
app is built, because a built app can run on a Mac that doesn't have them.
"""
load_omni_font() = omni_family[] = font_from(OMNI_FONT_FILES, "Manrope", SANS)

# The text of a page of a blog is in Literata, the typeface of the blog's site. fonts/ has its upright and
# italic faces in three weights, with the font's licence (Literata-OFL.txt). Without them it's in Charter.
const SITE_FONT_FILES = [joinpath(@__DIR__, "fonts", "Literata-$s.ttf") for s in ("Regular", "Italic", "SemiBold", "SemiBoldItalic", "Bold", "BoldItalic")]
"Read the typeface of a blog's pages from its files, as `load_omni_font` reads the palette's"
load_site_font() = SITE_FONT[] = font_from(SITE_FONT_FILES, "Literata", SERIF)
"""
The name of the face of the palette's font for `weight`. A font from a file is
found only by the name of its weight, spelled as UI.jl spells it: \"SemiBold\",
not \"Semibold\", and \"ExtraBold\" for \"Heavy\". The Mac's font takes any of them.
"""
omni_weight(weight::AbstractString) = omni_font() == SANS ? weight : weight_name(weight_of(weight))
const OMNI_LIST_MOST = 464.0   # the most of the commands' rows that show before the list scrolls
const OMNI_CHOICES_MOST = 200.0   # and of the rows of a chip's list that's searched
const OMNI_POP_GAP = 10.0      # between a list and what it hangs over
const OMNI_RISE = 0.18         # seconds for the bar to slide up or down
const OMNI_BLUR = 10.0         # how far the page under the strip is blurred, in pixels
const OMNI_FADE = 48.0         # how far above the bar's top line the blur fades out

"The colours of the palette on a light page and on a dark one, which are those of Centient's omnibar"
const OMNI_LIGHT = (
  bar=colorant"#f2ebda", bar_line=colorant"#c4b89c",
  chip=colorant"#faf6ec", chip_line=colorant"#ddd4c0", hover=colorant"#e8dfc8", complete=colorant"#e8f5e9",
  drop=colorant"#f2ebda", drop_line=colorant"#b0a488", selected=colorant"#e8dfc8", rule=colorant"#ddd4c0",
  ink=colorant"#1b1710", ink2=colorant"#454034", muted=colorant"#6e6858", placeholder=colorant"#9c9482",
  run=colorant"#e0d4b9", run_hover=colorant"#d5c8ab", run_ink=colorant"#454034",
  key=colorant"#eae1cb", key_line=colorant"#c4b89c", key_ink=colorant"#454034",
  key_on=colorant"#dacead", key_on_line=colorant"#b0a488", key_on_ink=colorant"#1b1710",
  tip=colorant"#1b1710", tip_ink=colorant"#f7f1e3", toast=colorant"#fffaf5")
const OMNI_DARK = (
  bar=colorant"#18181b", bar_line=clear,
  chip=colorant"#27272a", chip_line=clear, hover=colorant"#3f3f46", complete=colorant"#1a3d2e",
  drop=colorant"#18181b", drop_line=colorant"#3f3f46", selected=colorant"#3f3f46", rule=RGBA(1, 1, 1, 0.06),
  ink=colorant"#f0f0f2", ink2=colorant"#a1a1aa", muted=colorant"#52525b", placeholder=colorant"#cbd5e1",
  run=colorant"#374151", run_hover=colorant"#4b5563", run_ink=colorant"#9ca3af",
  key=colorant"#424242", key_line=colorant"#2a2a2a", key_ink=colorant"#aaaaaa",
  key_on=RGBA(1, 1, 1, 0.15), key_on_line=RGBA(0, 0, 0, 0.3), key_on_ink=RGBA(1, 1, 1, 0.85),
  tip=colorant"#18181b", tip_ink=colorant"#fafafa", toast=colorant"#27272a")
const OMNI_TAG, OMNI_TAG_INK = colorant"#4c1d95", colorant"#e9d5ff"       # the command's name
const OMNI_GO, OMNI_GO_INK, OMNI_GO_LINE = colorant"#22c55e", colorant"#052e16", colorant"#86efac"   # the Run button while Return runs the command
const OMNI_SWITCH_ON, OMNI_SWITCH_OFF, OMNI_KNOB = colorant"#8b5cf6", colorant"#374151", colorant"#e2e8f0"
const OMNI_WRONG = colorant"#b42318"

omni(e) = e.theme == :night ? OMNI_DARK : OMNI_LIGHT

"What a chip holds before anything is said for it"
struct Unsaid end
const UNSAID = Unsaid()

"""
One thing that a method takes: its name, the type that it has to be, true
when it's a keyword argument, and what gives it. `from` is nothing for an
argument that the palette asks for, `:editor` or `:window` for the window's
own, and otherwise the thing in focus that the argument is: see `in_focus`.
"""
struct Argument
  name::Symbol
  type::Any
  keyword::Bool
  from::Any
end
Argument(name, type) = Argument(name, type, false, nothing)
Argument(name, type, keyword::Bool) = Argument(name, type, keyword, nothing)

"""
A chip of the palette: the names and the types of the argument in the methods
that are still in the running, true when it can be left out, and true when
it's a keyword argument, which shows only after ⌥.
"""
struct Wanted
  names::Vector{Symbol}
  types::Vector{Any}
  optional::Bool
  keyword::Bool
end
Wanted(names, types, optional) = Wanted(names, types, optional, false)

"What the command palette holds. It's kept from one frame to the next, and starts again each time the palette opens."
@def mutable struct CommandPalette <: SemanticUI
  command::Union{Nothing,Command} = nothing              # the command whose arguments it asks for, or nothing while it lists the commands
  methods::Vector{Vector{Argument}} = Vector{Argument}[]   # the methods of that command's function that it can call
  values::Vector{Any} = Any[]                            # what's said for each chip that isn't a keyword argument, or `UNSAID`
  keywords::Dict{Symbol,Any} = Dict{Symbol,Any}()        # what's said for each keyword argument that has something
  advanced::Bool = false                                 # ⌥ showed the chips of the keyword arguments
  wrap::Bool = false                                     # the chips are on as many lines as they need
  at::Int = 1                                            # the chip that the keyboard is in. One more than the last chip is the Run button.
  pick::Int = 1                                          # the row of the list that Return takes
  shown::Int = 0                                         # the row that the list last scrolled to
  typed::String = ""                                     # what the field held when the palette last looked
  query::String = ""                                     # the letters that keep the rows of a chip's list
  browsed::Bool = false                                  # an arrow chose the row, so the field has its words and the rows stay as they were
  fault::String = ""                                     # what went wrong, to say over the bar
  rows::Vector{Any} = Any[]                              # the rows of the list in the last frame
  scroll::Scroll = Scroll(width(grow=grow))
  moved::Float64 = 0.0                                   # when the bar last started to slide up or down
  from::Float64 = 0.0                                    # how far up it was then, from 0 to 1
  plan::Any = nothing                                    # where each part is in the window in this frame: see `palette_plan`
  focus::Vector{Any} = Any[]                             # what was in focus when the palette opened, from the nearest: see `in_focus`
  listed::Vector{Command} = Command[]                    # the commands that it lists: the ones that what's in focus takes
  had::Any = nothing                                     # what had the keyboard when the palette opened. It gets the keyboard back.
  inner::Vector{Any} = Any[]                             # what ⌥↑ made a chip bigger from, the last last, for ⌥↓ to go back to
  before::Any = nothing                                  # how the window looked before it showed a row of the list, for Esc to put back: see `preview!`
  pointed::Bool = false                                  # true once the mouse chose a row of the chip's list, for Return and Tab to take: see `palette_say!`
end
"What takes a click outside the palette"
@def mutable struct PaletteCatch <: SemanticUI end
"The outline round a list and what it hangs over, drawn as one shape"
@def mutable struct PaletteLens <: SemanticUI end
"What blurs the page under the strip that the bar is in, as frosted glass does. The blur fades out above the bar."
@def mutable struct PaletteFrost <: SemanticUI end
"The bar: its field, or the command's name with its chips and the Run button"
@def mutable struct PaletteBar <: SemanticUI end
"A row of a list: a command, or something that a chip can be"
@def mutable struct PaletteRow <: SemanticUI
  k::Int = 0
end
"A chip of the palette: one thing that the command takes"
@def mutable struct PaletteChip <: SemanticUI
  k::Int = 0
  over::Float64 = 0.0   # when the mouse came over it, or 0 while it isn't over it
end
"The button after the chips, which runs the command"
@def mutable struct PaletteRun <: SemanticUI end
"The … at the end of the chips that fit, which puts the chips on more lines"
@def mutable struct PaletteMore <: SemanticUI end

palette(e) = node!(CommandPalette, e, :palette)

"What's in focus in the window of `e` for a command. While the palette is open, its own field has the keyboard, so it's what was in focus when the palette opened."
command_focus(e) = begin
  p = get(e.nodes, :palette, nothing)
  e.popup == :commands && p isa CommandPalette && !isempty(p.focus) ? p.focus : in_focus(e)
end

# --- how a type is asked for ---

function choices_for end
function typed_as end

"""
`chip_start(::Type{T}, e)` gives the thing of type `T` that a chip starts with
when its command is taken: the one that the window means, like what the caret
is on. A chip of a type with no method of it starts with nothing.
"""
function chip_start end

"""
`chip_click(::Type{T}, e, w)` gives the thing of type `T` under the mouse of
the window `w`, or nothing. While the palette shows a chip of a type with a
method of it, a click on the window outside the palette chooses that thing
for the chip. See `palette_click!`.
"""
function chip_click end

"Where the thing `x` that a chip has shows in the window of `e`, for a line round it, or nothing"
shown_at(e, x) = x isa SemanticUI ? (try rect(x) catch; nothing end) : nothing

choices_for(::Type{Bool}, e) = [true, false]
choices_for(::Type{T}, e) where T<:Enum = collect(instances(T))
# A method that takes a type itself, like `f(::Type{Page})`, takes that one type. Several such methods make a chip that chooses between them.
choices_for(::Type{Type{T}}, e) where T = Any[T]

typed_as(::Type{<:AbstractString}, text) = isempty(text) ? nothing : String(text)
typed_as(::Type{T}, text) where T<:Integer = tryparse(isconcretetype(T) ? T : Int, text)
typed_as(::Type{T}, text) where T<:AbstractFloat = tryparse(isconcretetype(T) ? T : Float64, text)
# A number of any kind is a whole number where the text writes one
typed_as(::Union{Type{Real},Type{Number}}, text) = something(tryparse(Int, text), tryparse(Float64, text), Some(nothing))
typed_as(::Type{Date}, text) = begin
  word = lowercase(text)
  word == "today" ? Dates.today() : word == "tomorrow" ? Dates.today() + Day(1) : word == "yesterday" ? Dates.today() - Day(1) : tryparse(Date, text)
end

"""
`:choice` for a type whose things to choose from are few and fixed. The chip
of such a type shows two as a choice of two and three or four as a list, as a
select does in Centient. The things of any other type are in a list that's searched.
"""
chip_kind(::Type) = :search
chip_kind(::Type{T}) where T<:Enum = :choice
chip_kind(::Type{Type{T}}) where T = :choice

"The words that the palette shows for `x`, in a row and in a chip"
worded(x) = string(x)
worded(on::Bool) = on ? "On" : "Off"
worded(x::Enum) = uppercasefirst(replace(string(x), '_' => ' '))
worded(T::Type) = replace(string(nameof(T)), r"(?<=[a-z0-9])(?=[A-Z])" => " ")
# A file or a folder has its name. A part of the window has no words, unless its type has a method that gives it some.
worded(o::FSObject) = entry_name(o)
worded(::SemanticUI) = ""

"Fainter words at the right of the row of `x`, or none"
sidenote(x) = ""

"True when the palette can ask for a thing of type `T`"
askable(T) = T isa Union ? any(askable, Base.uniontypes(T)) :
             T isa Type && T !== Any && (hasmethod(choices_for, Tuple{Type{T},Any}) || hasmethod(typed_as, Tuple{Type{T},String}))

"The types among those of a chip that the palette can ask for. A union gives each of its own."
askable_types(types) = Any[U for T in types for U in (T isa Union ? Base.uniontypes(T) : (T,)) if askable(U)]

chooses(T) = hasmethod(choices_for, Tuple{Type{T},Any})
reads(T) = T !== Bool && hasmethod(typed_as, Tuple{Type{T},String})

"What the chip `c` can be, for the editor `e`"
chip_choices(e, c::Wanted) = begin
  out = Any[]
  for T in askable_types(c.types)
    chooses(T) || continue
    for x in Base.invokelatest(choices_for, T, e)
      any(o -> o === x || isequal(o, x), out) || push!(out, x)
    end
  end
  out
end

"What `text` writes for the chip `c`: the thing of the first of its types that can read it, or nothing"
chip_typed(c::Wanted, text::AbstractString) = begin
  for T in askable_types(c.types)
    hasmethod(typed_as, Tuple{Type{T},String}) || continue
    x = Base.invokelatest(typed_as, T, String(text))
    x === nothing || return x
  end
  nothing
end

"""
The kind of chip that `c` is: `:switch`, `:segment` for a choice of two,
`:pick` for a list of three or four, `:search` for a list that's searched,
`:number` or `:text`.
"""
chip_kind(e, c::Wanted) = begin
  types = askable_types(c.types)
  all(T -> T === Bool, types) && return :switch
  if any(chooses, types)
    # Things that are few and fixed, with nothing typed among them, show by how many they are
    (all(T -> chooses(T) && chip_kind(T) == :choice, types) && !any(reads, types)) || return :search
    n = length(chip_choices(e, c))
    return n <= 2 ? :segment : n <= 4 ? :pick : :search
  end
  all(T -> T isa Type && T <: Number, types) ? :number : :text
end

"What a chip says while it has nothing: the argument's name as words, like Due date"
chip_name(c::Wanted) = uppercasefirst(join((lowercase(replace(String(n), '_' => ' ')) for n in c.names), " or "))

"The name of the type `T` as a tooltip writes it"
type_words(T) = T isa Union ? join(map(type_words, Base.uniontypes(T)), " | ") :
                T isa DataType && T.name.name === :Type ? "Type{$(type_words(T.parameters[1]))}" :
                T isa DataType ? String(nameof(T)) : string(T)

"What a chip's tooltip says: the argument's name and its type, as in Centient"
chip_tip(c::Wanted) = string(join(c.names, " or "), " (", join(map(type_words, c.types), " | "), ")")

# --- what's in focus ---
#
# The palette lists the commands that have a use where the keyboard is. What's
# in focus says which: the part of the page that the caret is on, the page,
# its file, and the folder. A command that's a function shows when a method of
# it takes one of those things, by the type of an argument:
#
#     "Give the file or the folder another name"
#     rename!(e, o::FSObject) = ...
#     add_command!(rename!)
#
# Rename shows while a file or a folder is in focus, and its function gets the
# nearest one. A method for a kind of folder, like `f(d::GitDirectory)`, makes
# a command that shows only in such a folder. A command that takes only the
# editor shows everywhere.

"""
The path of the one file or folder that's chosen in `node`, a part of the
window that has the keyboard, or nothing: the row of the sidebar that the
arrows are on, or the one icon or line that's chosen on the page of a folder.
A part that holds files in another way has a method of this.
"""
chosen_path(node) = begin
  T = typeof(node)
  (hasfield(T, :chosen) && hasfield(T, :path) && node.chosen isa AbstractSet && length(node.chosen) == 1) || return nothing
  path = joinpath(node.path, only(node.chosen))
  ispath(path) ? path : nothing
end
chosen_path(t::Tree.ListTree) = (row = t.focused; row !== nothing && row.firstchild isa FileLabel ? row.firstchild.path : nothing)

"""
The things in focus in the window of `e`, from the nearest: what has the
keyboard and each part that it's in, the file or the folder that's chosen
there, the part of the page that the caret is on, the block of Julia code
that it's in, the text of the page, the file that shows, the folder that
holds it, and the sidebar's folder. A file is a `File`, and a folder is of
its kind, a type under `AbstractDirectory`. The editor and the window aren't
in the list: every command can have them.
"""
in_focus(e) = begin
  out = Any[]
  add(x) = (x === nothing || x === e || any(o -> o === x, out) || push!(out, x); nothing)
  thing(path) = try object(e, path) catch; nothing end   # macOS doesn't let Ladder read some folders
  # A part that holds files has the one that's chosen in it nearer than itself
  hold(node) = (path = chosen_path(node); path === nothing || add(thing(path)); add(node))
  w = window_of(e)
  b = e.buf
  field = get(e.nodes, :input, nothing)
  node = w === nothing ? nothing : w.focus
  while node isa SemanticUI && node !== e
    node === field || node isa CommandPalette || hold(node)
    node = node.parent
  end
  full = full_block(e)
  full === nothing || hold(full)
  if full === nothing
    line = b.caret[1]
    # A file that shows in a viewer has the viewer as its one part
    if !caretless(b) || b.view == :file
      k = findfirst(it -> it.first <= line <= it.last && it.content isa Live && it.content.node isa SemanticUI, e.layout)
      k === nothing || hold(e.layout[k].content.node)
    end
    (julia_file(b) || !caretless(b)) && add(julia_part(e, line))
  end
  # The page of a folder, or of a file of a kind that has a page of its own
  shown = page_object(e)
  if shown !== nothing
    view = with_theme(() -> page_view(e, shown), component_theme(e.zoom))
    view isa SemanticUI && hold(view)
  end
  b.view == :file || add(node!(Document, e, :document))
  # A page that isn't saved yet has a file all the same: the one that it will be written to
  o = isempty(b.path) ? nothing : thing(b.path)
  o === nothing && !isempty(b.path) && (o = try FS.File(b.path) catch; nothing end)
  o isa FSObject && (add(o); add(o.parent))
  add(directory(e))
  out
end

"""
True when the command called `name` has something to work on in the window of
`e`, where the type of what's in focus can't say so. A command has a method
of this when it has a use only on some pages, as Bold has on a page of
Markdown. The palette leaves out a command that has none.
"""
works_here(e, ::Val) = true
works_here(e, ::Union{Val{:bold},Val{:italic},Val{:print},Val{:export},Val{:slides},Val{:insert}}) = e.buf.view == :markdown
works_here(e, ::Val{:save}) = writes(e.buf)
works_here(e, ::Val{:back}) = !isempty(e.back) || step_words(e) !== nothing
works_here(e, ::Val{:forward}) = !isempty(e.ahead) || step_words(e, e.ahead) !== nothing
works_here(e, ::Union{Val{:find_next},Val{:find_last}}) = !isempty(found(e))
# A comment is made of a line of code: a file of code, or a line in a code block of a page
works_here(e, ::Val{:comment}) = begin
  b = e.buf
  ks = kinds(b)
  s, t = touched(b)
  any(i -> ks[i].kind == Kind.code && haskey(COMMENT_MARKS, lowercase(ks[i].lang)), s:min(t, length(ks)))
end

# --- the methods of a command's function ---

"""
What gives a method its argument called `name`, of the type `T`, when the
things in `focus` are in focus. `:editor` and `:window` are the window's own:
an `Editor` or a `Window`, or an argument called `e` or `w` with no type. The
nearest thing in focus that's a `T` is the argument of any other type that
the palette can't ask for. Nothing is for an argument that the palette asks
for, and for one that nothing gives. An argument with no type is never a
thing in focus, since everything would do for it.
"""
given(name::Symbol, T, focus) = begin
  (T === Editor || (T === Any && name === :e)) && return :editor
  (T === Window || (T === Any && name === :w)) && return :window
  (T === Any || !(T isa Type) || askable(T)) && return nothing
  k = findfirst(x -> x isa T, focus)
  k === nothing ? nothing : focus[k]
end

"The arguments of the method `sig` that the palette asks for by their place, in their order"
asks(sig::Vector{Argument}) = filter(a -> !a.keyword && a.from === nothing, sig)

"The things in focus that the method `sig` takes, in the order of its arguments"
focus_taken(sig::Vector{Argument}) = Any[a.from for a in sig if !(a.from === nothing || a.from === :editor || a.from === :window)]

"The keyword arguments of the method `m` that have a name, each with its type"
method_keywords(m::Method) = begin
  names = try Base.kwarg_decl(m) catch; Symbol[] end
  body = isempty(names) ? nothing : (try Base.bodyfunction(m) catch; nothing end)
  body === nothing && return Argument[]
  for inner in methods(body)
    # Julia's own method for the body takes the keyword arguments first, in the order of their names
    types = Base.unwrap_unionall(inner.sig).parameters
    length(types) >= 1 + length(names) || continue
    return Argument[Argument(n, (T = types[1+i]; T isa TypeVar ? T.ub : T), true) for (i, n) in enumerate(names) if !endswith(String(n), "...")]
  end
  Argument[]
end

"""
The methods of `f` that the palette can call when the things in `focus` are
in focus, each as its arguments, in the order that they're written in. A
method's argument is the window's own, a thing in focus, or something that
the palette asks for: see `given`. It leaves out a method that takes
something else, or any number of things. So a function is a command only
where a method of it takes what's in focus. A keyword argument that the
palette can't ask for is left out by itself, and keeps the value that the
method gives it.
"""
callable_methods(f, focus=Any[]) = begin
  out = Vector{Argument}[]
  for m in sort!(collect(methods(f)), by=m -> (string(m.file), m.line))
    types = Base.unwrap_unionall(m.sig).parameters[2:end]
    any(Base.isvarargtype, types) && continue
    names = Base.method_argnames(m)[2:end]
    sig = Argument[]
    for (k, T) in enumerate(types)
      T = T isa TypeVar ? T.ub : Base.rewrap_unionall(T, m.sig)
      name = k <= length(names) ? names[k] : Symbol("")
      # An argument with no name, like the one of `f(::Type{Page})`, is called by what it chooses
      (name === Symbol("") || startswith(String(name), '#')) && (name = :kind)
      push!(sig, Argument(name, T, false, given(name, T, focus)))
    end
    all(a -> a.from !== nothing || askable(a.type), sig) || continue
    append!(sig, filter(a -> askable(a.type), method_keywords(m)))
    sig in out || push!(out, sig)
  end
  out
end

fits(x, c::Wanted) = any(T -> x isa T, c.types)

"""
The chips of a command whose function has the methods `sigs`, when `values`
are what's said so far. Each chip is for one place in the arguments. The
methods that take what's said stay in the running, and the chips are theirs.
Where they part and nothing is said yet, there are two cases, as in Centient.
Methods that take a type itself there, like `f(::Type{Page})`, have nothing in
common after it, so the chips stop. Methods that take values of different
types show the chips of the method that's written first. The chips of the
keyword arguments of the methods that are left come last.
"""
palette_chips(sigs::Vector{Vector{Argument}}, values) = begin
  alive = [(asks(s), s) for s in sigs]
  chips = Wanted[]
  k = 1
  waits = false
  while true
    here = filter(s -> length(s[1]) >= k, alive)
    isempty(here) && break
    chip = Wanted(unique(Symbol[s[1][k].name for s in here]), unique(Any[s[1][k].type for s in here]), length(here) < length(alive))
    push!(chips, chip)
    x = k <= length(values) ? values[k] : UNSAID
    if x !== UNSAID && fits(x, chip)
      alive = filter(s -> x isa s[1][k].type, here)
    elseif length(chip.types) > 1
      all(T -> T isa Type && T <: Type, chip.types) && (waits = true; break)
      first_type = here[1][1][k].type
      alive = filter(s -> s[1][k].type == first_type, here)
    else
      alive = here
    end
    k += 1
  end
  waits && return chips
  seen = Symbol[]
  for (_, sig) in alive, a in sig
    (a.keyword && !(a.name in seen)) || continue
    push!(seen, a.name)
    push!(chips, Wanted([a.name], Any[a.type], true, true))
  end
  chips
end

"The chips that show: all of them after ⌥, and without the keyword arguments before"
palette_chips(p::CommandPalette) = begin
  chips = palette_chips(p.methods, p.values)
  p.advanced ? chips : filter(c -> !c.keyword, chips)
end

"What's said for chip `k` of `chips`, or `UNSAID`"
chip_value(p::CommandPalette, chips, k::Int) = begin
  k <= length(chips) || return UNSAID
  c = chips[k]
  c.keyword ? get(p.keywords, only(c.names), UNSAID) : k <= length(p.values) ? p.values[k] : UNSAID
end

"Make `p.values` as long as the chips are, and take away what no longer fits its chip"
settle!(p::CommandPalette) = begin
  for _ in 1:2
    chips = palette_chips(p.methods, p.values)
    n = count(c -> !c.keyword, chips)
    length(p.values) > n && resize!(p.values, n)
    while length(p.values) < n
      push!(p.values, UNSAID)
    end
    for k in 1:n
      p.values[k] === UNSAID || fits(p.values[k], chips[k]) || (p.values[k] = UNSAID)
    end
    named = Dict{Symbol,Wanted}(only(c.names) => c for c in chips if c.keyword)
    filter!(kv -> haskey(named, kv.first) && fits(kv.second, named[kv.first]), p.keywords)
  end
  p
end

"Say `x` for chip `k` of `chips`. `UNSAID` takes away what it had."
say!(p::CommandPalette, chips, k::Int, x) = begin
  c = chips[k]
  if c.keyword
    x === UNSAID ? delete!(p.keywords, only(c.names)) : (p.keywords[only(c.names)] = x)
  else
    p.values[k] = x
  end
  settle!(p)
end

"""
The method that takes what's said: the one whose arguments are the chips from
the first up to the last one that has something. It's nothing while a chip
before that one has nothing, or when no method stops there.
"""
ready_method(sigs::Vector{Vector{Argument}}, values) = begin
  n = something(findfirst(x -> x === UNSAID, values), length(values) + 1) - 1
  all(x -> x === UNSAID, values[n+1:end]) || return nothing
  for sig in sigs
    a = asks(sig)
    length(a) == n && all(k -> values[k] isa a[k].type, 1:n) && return sig
  end
  nothing
end

# --- the lists ---

"A command's name as the palette shows it: `:select_all` reads Select All"
palette_name(name::Symbol) = join(uppercasefirst.(split(String(name), '_', keepempty=false)), ' ')

"""
How well `text` fits the letters `q`, both in small letters. 0 is not at all.
Text that has the letters together fits best, and better the nearer its start
they are. Text that has them in order with others between them fits a little.
"""
palette_fit(text::AbstractString, q::AbstractString) = begin
  at = findfirst(q, text)
  if at !== nothing
    before = length(text, 1, first(at)) - 1
    return max(1, 100 - before) + (before == 0 ? 50 : 0)
  end
  want = collect(q)
  score, k = 0, 1
  for (n, c) in enumerate(text)
    k > length(want) && break
    c == want[k] && (score += n == k ? 2 : 1; k += 1)
  end
  k > length(want) ? score : 0
end

"""
How well the command `c` fits the letters `q`: the best of its name, as it's
written and as it shows, and what it does. A name that fits comes before
words that fit as well, so that "go to" finds Go To before a command whose
words start with "Go to".
"""
command_fit(c::Command, q::AbstractString) = begin
  name = max(palette_fit(lowercase(String(c.name)), q), palette_fit(lowercase(palette_name(c.name)), q))
  max(name == 0 ? 0 : name + 10, palette_fit(lowercase(c.title), q))
end

"""
True when the palette lists the command `c` while the things in `focus` are
in focus. It leaves out the commands that only a key makes sense for, like
the ones that move the caret, the ones that the page can't take, as a key
leaves them out, the ones with nothing to work on here, and a function that
has no method for what's in focus.
"""
in_palette(e, c::Command, focus=in_focus(e)) = begin
  (c.name == :commands || c.kind in (:move, :type)) && return false
  b = e.buf
  (!readonly(b) || c.kind in (:window, :page) || (c.kind == :look && b.view != :file)) || return false
  works_here(e, Val(c.name)) || return false
  c.call === nothing || !isempty(callable_methods(c.call, focus))
end

"The commands that the palette lists while the things in `focus` are in focus, in the order of their names. The page's own functions are among them: see `page_commands`."
palette_commands(e, focus=in_focus(e)) =
  sort!(Command[[c for (_, cs) in COMMAND_GROUPS for c in cs if in_palette(e, c, focus)]; [c for c in page_commands(e) if in_palette(e, c, focus)]],
        by=c -> String(c.name))

"""
The name of the thing in focus that the command `c` works on, to show in its
row, or "" for a command that works on the window or the page as a whole. It
says which file Move To Trash takes before Return is pressed.
"""
palette_target(c::Command, focus) = begin
  c.call === nothing && return ""
  for sig in callable_methods(c.call, focus), x in focus_taken(sig)
    words = worded(x)
    isempty(words) || return words
  end
  ""
end

"The things in `found` whose words fit the letters `q`, with the best fit first. `fit` gives how well one fits."
best_fits(fit, found, q) = begin
  isempty(q) && return found
  scored = [(fit(x), x) for x in found]
  last.(sort!(filter!(s -> first(s) > 0, scored), by=s -> -first(s)))
end

"""
The rows of the palette's list: the commands, or what the chip that the
keyboard is in can be. Each has its name, the fainter words with it, its keys
or nothing, and what Return takes. A list of a few fixed things has them all.
A list that's searched has the ones whose words have the letters typed, in
their own order, and then what the letters write, when they write something.
"""
palette_rows(e, p::CommandPalette) = begin
  if p.command === nothing
    q = lowercase(String(strip(input(e).text)))
    of = keys_now(e).of
    rows = Any[(name=palette_name(c.name), note=c.title, on=palette_target(c, p.focus),
                keys=(list = get(of, c.name, Shortcut[]); isempty(list) ? nothing : first(list)), value=c)
               for c in best_fits(c -> command_fit(c, q), p.listed, q)]
    # A web address or a path that's typed here has Navigate first, with where Return goes: see "a page from a web server"
    to = palette_address(e, p)
    if to !== nothing
      filter!(r -> r.value.name != :navigate, rows)
      c = p.listed[findfirst(c -> c.name == :navigate, p.listed)]
      pushfirst!(rows, (name=palette_name(c.name), note="Go to " * place_label(to), on="", keys=nothing, value=c))
    end
    return rows
  end
  chips = palette_chips(p)
  p.at <= length(chips) || return Any[]
  chip = chips[p.at]
  kind = chip_kind(e, chip)
  kind in (:pick, :search) || return Any[]
  found = collect(Any, chip_choices(e, chip))
  if kind == :search
    q = lowercase(p.query)
    isempty(q) || filter!(x -> occursin(q, lowercase(worded(x))), found)
    typed = chip_typed(chip, p.query)
    typed === nothing || any(x -> isequal(x, typed), found) || push!(found, typed)
  end
  Any[(name=worded(x), note=sidenote(x), on="", keys=nothing, value=x) for x in found]
end

"The rest of the first row's name, when its name starts with what's typed. It shows after the text. In the list of commands, Tab types it."
palette_ghost(e, p::CommandPalette) = begin
  text = input(e).text
  isempty(text) && return ""
  rows = palette_rows(e, p)
  isempty(rows) && return ""
  if p.command !== nothing
    # In a chip, it's the rest of the row that's chosen, and not after an arrow put that row's words in the field
    p.browsed && return ""
    chips = palette_chips(p)
    (p.at <= length(chips) && chip_kind(e, chips[p.at]) == :search) || return ""
  end
  name = rows[p.command === nothing ? 1 : clamp(p.pick, 1, length(rows))].name
  startswith(lowercase(name), lowercase(text)) && length(name) > length(text) ? rest(name, length(text)) : ""
end

"The parts of `name` before, in and after the first place that has the letters `q`, whatever their case"
match_parts(name::AbstractString, q::AbstractString) = begin
  low = lowercase(name)
  at = isempty(q) || length(low) != length(name) ? nothing : findfirst(q, low)
  at === nothing && return (String(name), "", "")
  n = length(low, 1, first(at)) - 1
  (head(name, n), head(rest(name, n), length(q)), rest(name, n + length(q)))
end

# --- opening, closing and the keys ---

"How far up the bar is, from 0 to 1. It slides for `OMNI_RISE` seconds, fast at first."
palette_risen(e, p::CommandPalette) = begin
  to = e.popup == :commands ? 1.0 : 0.0
  t = (time() - p.moved) / OMNI_RISE
  t < 1 ? p.from + (to - p.from) * (1 - (1 - t)^2) : to
end

"True while the palette is in the window: while it's open, and while it slides down after it closes"
palette_shows(e) = e.popup == :commands || (e.popup == :none && haskey(e.nodes, :palette) && palette_risen(e, e.nodes[:palette]) > 0)

"True while the bar slides, so that each frame is drawn as soon as it can be"
palette_moving(e) = haskey(e.nodes, :palette) && time() - e.nodes[:palette].moved < OMNI_RISE

"Put `text` in the palette's field, with the caret after it. With `select`, all of it is selected, so that typing takes its place."
palette_text!(e, p::CommandPalette, text::AbstractString; select=false) = begin
  i = input(e)
  i.text = String(text)
  i.cursor = length(i.text)
  i.anchor = select ? 0 : i.cursor
  p.typed = i.text
  p
end

"Give the keyboard to the field when the palette has something to type in, and to the palette itself for a switch, a choice, a list of a few or the Run button"
palette_focus!(e, p::CommandPalette) = begin
  typing = p.command === nothing
  if !typing
    chips = palette_chips(p)
    typing = p.at <= length(chips) && chip_kind(e, chips[p.at]) in (:text, :number, :search)
  end
  focus(typing ? input(e) : p)
  nothing
end

"Empty the bar: no command, no chips and no text, with the list of commands at its first row. A row that the window showed goes."
palette_clear!(e, p::CommandPalette) = begin
  unpreview!(e, p)
  p.command, p.at, p.pick, p.shown = nothing, 1, 1, 0
  p.advanced = p.wrap = p.browsed = false
  p.query = p.fault = ""
  empty!(p.methods); empty!(p.values); empty!(p.keywords); empty!(p.rows); empty!(p.inner)
  p.scroll.offset = 0px
  palette_text!(e, p, "")
  palette_focus!(e, p)
end

"""
Show the command palette with the list of the commands. With `command`, it
shows that command with its chips, as it does after the command is taken
from the list: the keys of a command that asks for something do that.
"""
open_palette!(e, command::Union{Nothing,Command}=nothing) = begin
  p = palette(e)
  if e.popup != :commands
    from = palette_risen(e, p)
    # What's in focus is read before the palette takes the keyboard, and stays as it is while the palette is open
    w = window_of(e)
    p.had = w === nothing ? nothing : w.focus
    p.focus = in_focus(e)
    p.listed = palette_commands(e, p.focus)
    # The bar starts to slide when the list is ready, so that none of the slide is lost to making it
    p.from, p.moved = from, time()
    e.popup = :commands
  end
  palette_clear!(e, p)
  command === nothing || take_command!(e, window_of(e), p, command)
  nothing
end

# The page under it stays as it was: the caret doesn't show again, and the page doesn't scroll to it
close_palette!(e) = begin
  p = palette(e)
  unpreview!(e, p)
  e.popup == :commands && ((p.from, p.moved) = (palette_risen(e, p), time()); e.popup = :none)
  w = window_of(e)
  w === nothing || hide_tooltip!(w)
  # The part of the page that had the keyboard gets it back, if it still shows, so that it's still the one in focus
  had = p.had
  p.had = nothing
  focus(had isa SemanticUI && had !== get(e.nodes, :input, nothing) && part_of(had, e) && rect(had) !== nothing ? had : e)
  nothing
end

"Show the command palette, or close it when it shows"
toggle_palette!(e) = e.popup == :commands ? close_palette!(e) : open_palette!(e)

"Take the command `c` from the list: run it, or show its chips when it asks for something"
take_command!(e, w, p::CommandPalette, c::Command) = begin
  if c.call === nothing
    close_palette!(e)
    return run!(e, w, c.name)
  end
  sigs = callable_methods(c.call, p.focus)
  isempty(sigs) && return (p.fault = "$(palette_name(c.name)) has nothing to work on here"; nothing)
  palette_clear!(e, p)
  p.command, p.methods = c, sigs
  settle!(p)
  # A function that takes nothing but the editor runs at once
  isempty(p.values) && return palette_run!(e, w, p)
  start_chips!(e, p)
  # A command that runs at once still waits here: what the window gave its chips is shown first, and Return or a click runs it
  # The keyboard goes to the first chip that has nothing yet. When each has something, it goes to the first chip
  # for a thing in the window, so the mouse picks out what a click would choose instead, or else to the Run button.
  chips = palette_chips(p)
  go_chip!(e, p, something(findfirst(x -> x === UNSAID, p.values), findfirst(chip_points, chips), length(chips) + 1))
end

"Give each chip that has nothing the thing that its type starts with: see `chip_start`"
start_chips!(e, p::CommandPalette) = begin
  k = 1
  while k <= length(p.values)
    if p.values[k] === UNSAID
      chips = palette_chips(p.methods, p.values)
      for T in askable_types(chips[k].types)
        hasmethod(chip_start, Tuple{Type{T},Any}) || continue
        x = Base.invokelatest(chip_start, T, e)
        x === nothing || (say!(p, chips, k, x); break)
      end
    end
    k += 1
  end
  p
end

"True when the chip `c` is for a thing that shows in the window, which a click there chooses: its type has a method of `chip_click`"
chip_points(c::Wanted) = !c.keyword && any(T -> hasmethod(chip_click, Tuple{Type{T},Any,Any}), askable_types(c.types))

Base.:(==)(a::Things, b::Things) = a.all == b.all
Base.hash(t::Things, h::UInt) = hash(t.all, hash(:Things, h))
worded(t::Things) = join(map(worded, t.all), ", ")

"""
The letter and the colour of each thing that the palette's chips for things
in the window have, in the order of the chips: A in blue for the first, B in
orange for the next. A chip shows them in place of the things' words, and
the line round each thing in the window has them too. Each is the chip's
number, the thing, its letter and its colour.
"""
chip_letters(p::CommandPalette, chips) = begin
  out = NamedTuple[]
  for k in eachindex(chips)
    chip_points(chips[k]) || continue
    x = chip_value(p, chips, k)
    x === UNSAID && continue
    for y in each_thing(x)
      n = length(out) + 1
      push!(out, (k=k, thing=y, letter=string('A' + n - 1), colour=CHIP_MARKS[mod1(n, length(CHIP_MARKS))]))
    end
  end
  out
end

"The colour that the next thing that a chip for things in the window takes would have"
next_mark(p::CommandPalette, chips) = CHIP_MARKS[mod1(length(chip_letters(p, chips)) + 1, length(CHIP_MARKS))]

"The colour `c` made paler, for the line round what a click would choose"
paler(c) = RGBA(0.6c.r + 0.4, 0.6c.g + 0.4, 0.6c.b + 0.4, 1.0)

"""
The chip that a click on the window chooses a thing for: the one that the
keyboard is in, when it's for a thing in the window. It's nothing while the
keyboard is in another chip, like the words of Ask Agent, so the mouse then
picks nothing out on the page and a click there chooses nothing.
"""
click_chip(e, p::CommandPalette) = begin
  (e.popup == :commands && p.command !== nothing) || return nothing
  chips = palette_chips(p)
  p.at <= length(chips) && chip_points(chips[p.at]) ? p.at : nothing
end

"""
The chip for a thing in the window that ⌥↑ and ⌥↓ make bigger or smaller: the
one that the keyboard is in, or else the first. It's nothing while the
palette shows no such chip.
"""
thing_chip(e, p::CommandPalette) = begin
  k = click_chip(e, p)
  k === nothing || return k
  (e.popup == :commands && p.command !== nothing) || return nothing
  chips = palette_chips(p)
  findfirst(k -> chip_points(chips[k]), eachindex(chips))
end

"True when the chip `c` can have several things, which ⇧ and a click add: its function takes `Things` there"
adds_things(c::Wanted) = any(T -> T isa Type && Things <: T, c.types)

"True when the point `(x, y)` of the window is on the palette: the strip along the bottom, or the list over it"
on_palette(p::CommandPalette, x, y) = begin
  plan = p.plan
  plan === nothing && return false
  within(r) = r.x <= x <= r.x + r.w && r.y <= y <= r.y + r.h
  within(plan.band) || (plan.list !== nothing && within(plan.list.frame))
end

"The part of the window that a concrete box `ui` of its layout is drawn for: the nearest that made it"
drawn_for(ui) = begin
  from = ui.from
  while from !== nothing
    from isa SemanticUI && return from
    from = hasproperty(from, :from) ? from.from : nothing
  end
  nothing
end

"""
The deepest part of the window `w` under its mouse, leaving out what the
palette `p` draws. The palette's layers cover the window while it shows, so
this is what a click outside the palette is on.
"""
under_palette(w, p::CommandPalette) = (s = scene(w); s === nothing ? nothing : hit_past(s, (w.mouse[1], w.mouse[2]), p))
hit_past(ui, (x, y), p) = begin
  ui isa ConcreteRect || return nothing
  (ui.left <= x <= ui.left + ui.width && ui.top <= y <= ui.top + ui.height) || return nothing
  made = drawn_for(ui)
  made === p && return nothing
  # Later children draw on top, so they're found first
  for child in Iterators.reverse(ui.children)
    found = hit_past(child, (x, y), p)
    found === nothing || return found
  end
  made
end

"""
`chip_wider(x, e)` gives the thing of the same type as `x` that holds it in the
window of `e`, like the block that a paragraph is in, or nothing. ⌥↑ in the
palette makes a chip for a thing in the window take it: see `resize_thing!`.
"""
chip_wider(x, e) = nothing

"""
What ⌥↑ and ⌥↓ do while the palette shows a chip for a thing in the window:
↑ (`by` 1) gives the chip the part that holds its thing, and ↓ (`by` -1)
goes back to the thing that it was before.
"""
resize_thing!(e, p::CommandPalette, by::Int) = begin
  k = thing_chip(e, p)
  k === nothing && return nothing
  chips = palette_chips(p)
  x = chip_value(p, chips, k)
  x === UNSAID && return nothing
  if by > 0
    bigger = Base.invokelatest(chip_wider, x, e)
    bigger === nothing && return nothing
    push!(p.inner, x)
    say!(p, chips, k, bigger)
  else
    isempty(p.inner) && return nothing
    say!(p, chips, k, pop!(p.inner))
  end
  redraw_in!(e, 0)
  nothing
end

"What a click at the mouse of the window `w` would choose for chip `k` of the palette, or nothing"
clicked_thing(e, p::CommandPalette, w, k::Int) = begin
  for T in askable_types(palette_chips(p)[k].types)
    hasmethod(chip_click, Tuple{Type{T},Any,Any}) || continue
    x = Base.invokelatest(chip_click, T, e, w)
    x === nothing || return x
  end
  nothing
end

"""
A click on the window while the palette shows a chip that a click chooses
for: the chip gets the thing under the mouse, and the keyboard goes on from
it. True when the palette took the click. It takes a click on nothing that
the chip takes too, so the page under the palette doesn't change.
"""
palette_click!(e, w) = begin
  p = get(e.nodes, :palette, nothing)
  p isa CommandPalette || return false
  k = click_chip(e, p)
  (k === nothing || on_palette(p, num(w.mouse[1]), num(w.mouse[2]))) && return false
  x = clicked_thing(e, p, w, k)
  x === nothing && return true
  empty!(p.inner)
  chips = palette_chips(p)
  had = chip_value(p, chips, k)
  if only_held(w, Keys.shft) && adds_things(chips[k]) && had !== UNSAID
    # ⇧ and a click add the thing to what the chip has, or take it out when it has it. The keyboard stays where it is.
    now = each_thing(had)
    j = findfirst(y -> y == x, now)
    now = j === nothing ? Any[now; x] : deleteat!(copy(now), j)
    say!(p, chips, k, isempty(now) ? UNSAID : length(now) == 1 ? only(now) : Things(now))
    palette_focus!(e, p)
    redraw_in!(e, 0)
    return true
  end
  say!(p, chips, k, x)
  k == p.at ? palette_next!(e, p) : (run_when_ready!(e, p) || palette_focus!(e, p))
  redraw_in!(e, 0)
  true
end

"""
Draw a line round the thing of each chip that's for a thing in the window, in
the chip's colour, with the chip's letter, for as long as the command shows.
While the keyboard is in such a chip, a paler line goes round what a click
would choose, with its words. The window's tool draws them, over the rest of
the window.
"""
mark_chips(ctx, w, e) = begin
  p = get(e.nodes, :palette, nothing)
  (p isa CommandPalette && e.popup == :commands && p.command !== nothing) || return nothing
  chips = palette_chips(p)
  letters = chip_letters(p, chips)
  for l in letters
    r = shown_at(e, l.thing)
    r === nothing || pick_mark(ctx, w, r, l.letter; colour=l.colour)
  end
  k = click_chip(e, p)
  k === nothing && return nothing
  redraw_in!(e, 1/30)   # the line follows the mouse
  on_palette(p, num(w.mouse[1]), num(w.mouse[2])) && return nothing
  x = clicked_thing(e, p, w, k)
  (x === nothing || any(l -> l.thing == x, letters)) && return nothing
  r = shown_at(e, x)
  r === nothing && return nothing
  # With ⇧ held, a click adds the thing, in the colour that it would have
  adds = only_held(w, Keys.shft) && adds_things(chips[k]) && chip_value(p, chips, k) !== UNSAID
  colour = adds ? next_mark(p, chips) : (k2 = findfirst(l -> l.k == k, letters); k2 === nothing ? CHIP_MARKS[1] : letters[k2].colour)
  pick_mark(ctx, w, r, (adds ? "Click to add: " : "Click to choose: ") * worded(x); colour=paler(colour))
  nothing
end

"""
Put the keyboard in chip `k`. One more than the last chip is the Run button.
A chip that's typed in has what's said for it in the field, selected. A list
that's searched starts with an empty field, and its row is the one that's said.
"""
go_chip!(e, p::CommandPalette, k::Int) = begin
  chips = palette_chips(p)
  p.at = clamp(k, 1, length(chips) + 1)
  p.query, p.browsed, p.pointed, p.fault, p.shown = "", false, false, "", 0
  p.scroll.offset = 0px
  x = chip_value(p, chips, p.at)
  typed = p.at <= length(chips) && chip_kind(e, chips[p.at]) in (:text, :number)
  palette_text!(e, p, typed && x !== UNSAID ? worded(x) : "", select=true)
  # A chip on a line that doesn't show puts the chips on as many lines as they need
  p.wrap || palette_fits(e, p, p.at) || (p.wrap = true)
  p.pick = something(findfirst(r -> isequal(r.value, x), palette_rows(e, p)), 1)
  palette_focus!(e, p)
end

"""
True for a command that changes nothing that you'd want to look at before it
runs, like Go To or Theme. The palette runs it as soon as each of its chips
has something, with no press of Run. A command that changes a file, or that
starts something that takes a while, like Rename or Ask Agent, waits for
Run. A command that takes nothing runs at once anyway.
"""
runs_at_once(::Val) = false
runs_at_once(::Union{Val{:go_to},Val{:theme},Val{:text_size},Val{:key_bindings},Val{:spelling},Val{:autosave},Val{:peeks},Val{:insert},Val{:rename_in_code},Val{:show_code},Val{:find_uses}}) = true

"""
Run the palette's command when it runs at once and each of its chips has
something that was said for it. A switch that wasn't touched counts as
nothing here, so taking Spelling doesn't turn it off. True when it ran.
"""
run_when_ready!(e, p::CommandPalette) = begin
  (p.command !== nothing && runs_at_once(Val(p.command.name)) && !isempty(p.values)) || return false
  any(x -> x === UNSAID, p.values) && return false
  ready_method(p.methods, palette_said(e, p)) === nothing && return false
  palette_run!(e, window_of(e), p)
  true
end

"The number that ↑ and ↓ count from in chip `k` of the command `name` while the chip has nothing: 0, or for Text Size the size that the text is now"
counts_from(e, ::Val, k) = 0
counts_from(e, ::Val{:text_size}, k) = text_size(e)

"Go on from the chip that the keyboard is in to the next one, or to the Run button after the last. A command that runs at once runs when its last chip has something."
palette_next!(e, p::CommandPalette) = run_when_ready!(e, p) || go_chip!(e, p, p.at + 1)

# --- a look before you choose ---
#
# As the arrows go through the list of Theme, the window shows each colours,
# and Text Size shows each size. Go To and Find Uses show each place in the window. Esc,
# or a click outside the palette, puts the window back as it was. Return keeps
# the one that's chosen.

"""
`look_of(e, Val(name))` gives how the window of `e` looks now in the ways
that the command `name` changes it, for a command that shows each row of its
list in the window as the arrows reach it. `put_look!` puts that look back.
It's nothing for a command that doesn't show its rows so.
"""
look_of(e, ::Val) = nothing
look_of(e, ::Val{:theme}) = e.theme
look_of(e, ::Val{:text_size}) = e.zoom
put_look!(e, ::Val{:theme}, was) = theme!(e, was)
put_look!(e, ::Val{:text_size}, was) = (e.zoom = was; rewrap!(e))

"Show in the window what the command `name` does with `args`, for a row that the arrows reached: see `look_of`. Most commands just run."
look!(e, ::Val, f, args...) = Base.invokelatest(f, args...)

"What the command's function takes: what's said for each chip, and the editor or the window where it takes them"
palette_args(e, w, sig, said) = (said = copy(said); Any[a.from === nothing ? popfirst!(said) : a.from === :editor ? e : a.from === :window ? w : a.from for a in sig if !a.keyword])

"""
Show in the window the row of the list that the arrows reached, for a command
that does that, like Theme: see `look_of`. The palette keeps how the window
looked before the first, for Esc to put back.
"""
preview!(e, p::CommandPalette) = begin
  p.command === nothing && return nothing
  name = Val(p.command.name)
  was = look_of(e, name)
  was === nothing && return nothing
  said = palette_said(e, p)
  any(x -> x === UNSAID, said) && return nothing
  sig = ready_method(p.methods, said)
  sig === nothing && return nothing
  p.before === nothing && (p.before = was)
  try
    look!(e, name, p.command.call, palette_args(e, window_of(e), sig, said)...)
  catch err
    err isa InterruptException && rethrow()
  end
  nothing
end

"Put the window back as it looked before the palette showed a row of its list in it: see `preview!`"
unpreview!(e, p::CommandPalette) = begin
  was, p.before = p.before, nothing
  (was === nothing || p.command === nothing) || put_look!(e, Val(p.command.name), was)
  nothing
end

"While the window shows a row of the list, a line round the thing of that row, as for a place that Find Uses found"
mark_preview(ctx, w, e) = begin
  p = get(e.nodes, :palette, nothing)
  (p isa CommandPalette && p.before !== nothing && e.popup == :commands && p.command !== nothing) || return nothing
  chips = palette_chips(p)
  p.at <= length(chips) || return nothing
  x = chip_value(p, chips, p.at)
  x === UNSAID && return nothing
  r = shown_at(e, x)
  r === nothing || pick_mark(ctx, w, r, sidenote(x))
  nothing
end

"""
Take in what the field has, when it changed since the palette last looked.
In the list of commands, the first row is the one that's chosen again. A chip
of words or of a number has what the text writes, as it's typed. In a list
that's searched, typing takes away what the chip had and keeps the rows by
the new letters.
"""
palette_sync!(e, p::CommandPalette) = begin
  i = input(e)
  i.text == p.typed && return
  p.typed = i.text
  p.fault = ""
  p.pick, p.shown = 1, 0
  p.scroll.offset = 0px
  p.command === nothing && return
  chips = palette_chips(p)
  kind = p.at <= length(chips) ? chip_kind(e, chips[p.at]) : :run
  text = String(strip(i.text))
  if kind == :text
    say!(p, chips, p.at, isempty(text) ? UNSAID : something(chip_typed(chips[p.at], text), UNSAID))
  elseif kind == :number
    if isempty(text) || text in ("-", ".", "-.")
      say!(p, chips, p.at, UNSAID)
    else
      # Text that writes no number leaves the chip with the number that it had
      x = chip_typed(chips[p.at], text)
      x === nothing || say!(p, chips, p.at, x)
    end
  elseif kind == :search
    p.browsed = false
    p.query = text
    say!(p, chips, p.at, UNSAID)
  else
    # A switch, a choice, a list of a few and the Run button take no text
    palette_text!(e, p, "")
  end
  nothing
end

"""
Say the row that's chosen for the chip that the keyboard is in. With no rows,
the chip stays as it is. A chip that has something keeps it too, unless the
mouse chose a row: the arrows say their row at once, and typing takes away
what the chip had. So the things that clicks on the window chose stay.
"""
palette_say!(e, p::CommandPalette) = begin
  rows = palette_rows(e, p)
  isempty(rows) && return
  chips = palette_chips(p)
  chip_value(p, chips, p.at) === UNSAID || p.pointed || return
  empty!(p.inner)
  say!(p, chips, p.at, rows[clamp(p.pick, 1, length(rows))].value)
  nothing
end

"""
What ↑ and ↓ do in a chip with a list: choose the row before or after, and
say it at once. In a list that's searched, the field then has the row's words,
selected, and the rows stay as they were.
"""
palette_browse!(e, p::CommandPalette, by::Int) = begin
  rows = palette_rows(e, p)
  isempty(rows) && return
  p.pick = clamp(p.pick + by, 1, length(rows))
  row = rows[p.pick]
  chips = palette_chips(p)
  searched = chip_kind(e, chips[p.at]) == :search
  say!(p, chips, p.at, row.value)
  searched && (p.browsed = true; palette_text!(e, p, row.name, select=true))
  nothing
end

"The things that a choice of two chooses between, and the place of the one that's said, or 0"
segment_state(e, p::CommandPalette, chips, k::Int) = begin
  found = chip_choices(e, chips[k])
  x = chip_value(p, chips, k)
  (found, something(findfirst(o -> isequal(o, x), found), 0))
end

"Choose the next of a choice of two, or the one before. From nothing, the next is the first and the one before is the last."
segment_step!(e, p::CommandPalette, k::Int, by::Int) = begin
  chips = palette_chips(p)
  found, at = segment_state(e, p, chips, k)
  isempty(found) && return
  say!(p, chips, k, found[at == 0 ? (by > 0 ? 1 : length(found)) : mod1(at + by, length(found))])
  nothing
end

"Turn a switch on or off. One that has nothing yet is off."
switch!(p::CommandPalette, k::Int) = (chips = palette_chips(p); say!(p, chips, k, chip_value(p, chips, k) !== true); nothing)

"""
What Tab and ⇧Tab do among the chips: go to the next or the last one, round
through the Run button. Tab takes the row that's chosen in a list first, as
Return does, and gives a choice of two that has nothing its first thing.
"""
palette_tab!(e, p::CommandPalette, by::Int) = begin
  chips = palette_chips(p)
  if by > 0 && p.at <= length(chips)
    kind = chip_kind(e, chips[p.at])
    kind in (:pick, :search) && palette_say!(e, p)
    kind == :segment && chip_value(p, chips, p.at) === UNSAID && segment_step!(e, p, p.at, 1)
  end
  go_chip!(e, p, mod1(p.at + by, length(palette_chips(p)) + 1))
end

"What ⌥ does: show the chips of the keyword arguments, or hide them again. A command with none stays as it is."
palette_advanced!(e, p::CommandPalette) = begin
  (p.command !== nothing && any(c -> c.keyword, palette_chips(p.methods, p.values))) || return
  p.advanced = !p.advanced
  p.at > length(palette_chips(p)) && go_chip!(e, p, length(palette_chips(p)) + 1)
  nothing
end

"What's said for each chip that isn't a keyword argument, with off for a switch that wasn't touched"
palette_said(e, p::CommandPalette) = begin
  chips = palette_chips(p.methods, p.values)
  Any[x === UNSAID && chip_kind(e, chips[k]) == :switch ? false : x for (k, x) in enumerate(p.values)]
end

"""
Call the command's function with what's said, and close the palette. While a
chip that the function needs has nothing, the keyboard goes to it. An error
that the function throws shows over the bar, and the palette stays.
"""
palette_run!(e, w, p::CommandPalette) = begin
  said = palette_said(e, p)
  sig = ready_method(p.methods, said)
  if sig === nothing
    chips = palette_chips(p.methods, p.values)
    k = something(findfirst(k -> said[k] === UNSAID && !chips[k].optional, eachindex(said)), 1)
    go_chip!(e, p, k)
    p.fault = "$(chip_name(chips[k])) has nothing yet"
    return
  end
  args = palette_args(e, w, sig, said)
  named = Pair{Symbol,Any}[name => x for (name, x) in p.keywords]
  # The palette closes first, so that the function finds the page with the keyboard, and can show something of its own.
  # A row that the window showed stays, as the command runs with it. A jump notes the place from before that: see `place_now`.
  p.before === nothing || (e.nodes[:unpreviewed] = p.before)
  p.before = nothing
  close_palette!(e)
  try
    value = try
      Base.invokelatest(p.command.call, args...; named...)
    finally
      delete!(e.nodes, :unpreviewed)
    end
    # What a command of the page's own gave back shows under the top bar
    if p.command.kind == :page && value !== nothing
      said = first(split(value isa AbstractString ? value : value_text(value, parentmodule(p.command.call)), '\n'))
      e.nodes[:result] = ("$(palette_name(p.command.name)): " * (length(said) > 120 ? first(said, 119) * "…" : said), time())
      redraw_in!(e, 0)
    end
  catch err
    err isa InterruptException && rethrow()
    p.from, p.moved = palette_risen(e, p), time()
    e.popup = :commands
    go_chip!(e, p, length(palette_chips(p)) + 1)
    p.fault = "Command failed: " * String(first(split(sprint(showerror, err), '\n')))
  end
  nothing
end

"""
What Return does: it takes the command that's chosen, or does what the chip
that the keyboard is in does with it, or runs the command.
"""
palette_take!(e, w, p::CommandPalette) = begin
  if p.command === nothing
    rows = palette_rows(e, p)
    isempty(rows) && return
    c = rows[clamp(p.pick, 1, length(rows))].value
    # Navigate goes at once to a web address or a path that's typed in the list of commands
    to = c.name == :navigate ? palette_address(e, p) : nothing
    to === nothing ? take_command!(e, w, p, c) : (close_palette!(e); navigate!(e, to))
    return
  end
  chips = palette_chips(p)
  p.at > length(chips) && return palette_run!(e, w, p)
  kind = chip_kind(e, chips[p.at])
  if kind == :segment
    segment_step!(e, p, p.at, 1)   # it chooses the next, and stays
  elseif kind == :switch
    switch!(p, p.at)
    palette_next!(e, p)
  elseif kind == :number
    text = String(strip(input(e).text))
    if !isempty(text) && chip_typed(chips[p.at], text) === nothing
      # Text that writes no number goes back to the number that the chip has
      x = chip_value(p, chips, p.at)
      palette_text!(e, p, x === UNSAID ? "" : worded(x), select=true)
    else
      palette_next!(e, p)
    end
  else
    kind in (:pick, :search) && palette_say!(e, p)
    palette_next!(e, p)
  end
  nothing
end

"What a key does while the palette shows. `command` is the command that the key bindings give the key, or nothing."
palette_key!(e, w, K, command) = begin
  p = palette(e)
  palette_sync!(e, p)
  command == :commands && return close_palette!(e)
  # Esc, Return, ↑, ↓ and ⌫ do what they do here only by themselves. Tab can have ⇧ with it, to go back. ⌥ goes down by itself.
  # ⌥↑ makes the thing of a chip for a thing in the window bigger: the part that holds it. ⌥↓ goes back.
  K in (Keys.up, Keys.down) && only_held(w, Keys.opt) && return (resize_thing!(e, p, K == Keys.up ? 1 : -1); nothing)
  K in (Keys.escape, Keys.enter, Keys.up, Keys.down, Keys.backspace) && !unmodified(w) && return nothing
  K == Keys.tab && !(unmodified(w) || only_held(w, Keys.shft)) && return nothing
  K == Keys.opt && setdiff(held_keys(w), Keys.opt) != Keys(0) && return nothing
  if K == Keys.escape
    # Esc empties the bar. In an empty bar, it closes the palette.
    p.command === nothing && isempty(input(e).text) ? close_palette!(e) : palette_clear!(e, p)
  elseif K == Keys.enter
    palette_take!(e, w, p)
  elseif p.command === nothing
    if K == Keys.down || K == Keys.up
      p.pick = clamp(p.pick + (K == Keys.down ? 1 : -1), 1, max(1, length(palette_rows(e, p))))
    elseif K == Keys.tab
      isempty(palette_ghost(e, p)) || palette_text!(e, p, first(palette_rows(e, p)).name)
    end
  elseif K == Keys.tab
    palette_tab!(e, p, only_held(w, Keys.shft) ? -1 : 1)
  elseif K == Keys.opt
    palette_advanced!(e, p)
  else
    chips = palette_chips(p)
    p.at <= length(chips) || return nothing
    kind = chip_kind(e, chips[p.at])
    by = K == Keys.down ? 1 : K == Keys.up ? -1 : 0
    if kind in (:pick, :search) && by != 0
      palette_browse!(e, p, by)
    elseif kind == :search && K == Keys.backspace && isempty(input(e).text)
      # ⌫ in an empty field takes away what the chip has
      say!(p, chips, p.at, UNSAID)
    elseif kind == :number && by != 0
      x = chip_value(p, chips, p.at)
      x = (x isa Number ? x : counts_from(e, Val(p.command.name), p.at)) - by   # ↑ adds one
      fits(x, chips[p.at]) && (say!(p, chips, p.at, x); palette_text!(e, p, worded(x), select=true))
    elseif kind == :segment && K in (Keys.left, Keys.up)
      segment_step!(e, p, p.at, -1)
    elseif kind == :segment && K in (Keys.right, Keys.down, Keys.space)
      segment_step!(e, p, p.at, 1)
    elseif kind == :switch && K == Keys.space
      switch!(p, p.at)
    end
    # A command like Theme shows the row that the arrows reached
    by != 0 && preview!(e, p)
  end
  nothing
end

# --- where each part is ---

omni_wide(text::AbstractString, size::Real, weight="") = isempty(text) ? 0.0 : num(measure(Face(omni_font(), omni_weight(weight), px(size), colours.ink, false), text))

"What a chip shows while the keyboard isn't in it, or while it takes no text: what's said, or its name. The second is true for the name."
chip_words(p::CommandPalette, chips, k::Int) = (x = chip_value(p, chips, k); x === UNSAID ? (chip_name(chips[k]), true) : (worded(x), false))

"How wide chip `k` is. One that's typed in is as wide as its text. An open list that's searched is as wide as its longest row, as in Centient."
chip_wide(e, p::CommandPalette, chips, k::Int) = begin
  chip = chips[k]
  kind = chip_kind(e, chip)
  frame = 18.0   # the room at its two sides, and its border
  kind == :switch && return frame + 32
  if kind == :segment
    found = chip_choices(e, chip)
    return frame + 2 + sum(o -> 16 + ceil(omni_wide(worded(o), 13, "Semibold")), found, init=0.0) + max(0, length(found) - 1)
  end
  words, _ = chip_words(p, chips, k)
  on = p.at == k
  # A chip for things in the window shows only their letters, once it has them
  letters = filter(l -> l.k == k, chip_letters(p, chips))
  isempty(letters) || on || return sum(l -> ceil(omni_wide(l.letter, 13, "Semibold")) + 24, letters)
  wide = omni_wide(on && kind != :pick && !isempty(input(e).text) ? input(e).text : on && kind == :search ? chip_name(chip) : words, 13)
  on && kind == :search && (wide = max(wide, min(320.0, maximum(o -> omni_wide(worded(o), 13), chip_choices(e, chip), init=0.0))))
  # A chip that's typed in has room for one more letter and the caret, so the field holds a letter before the chip grows for it
  frame + max(kind == :number ? 60.0 : 40.0, ceil(wide) + (on && kind != :pick ? 20 : 6))
end

"""
True when the words that the command `name` asks for are what it's for, as the
words of Ask Agent are. Their chip is wide before anything is typed in it.
"""
wide_words(::Val) = false
wide_words(::Val{:ask_agent}) = true

const OMNI_WORDS_LEAST, OMNI_WORDS_MOST = 240.0, 560.0   # how wide the chip of such words is, when the bar has room

"The tag, the chips and the Run button, each with how wide it is, in their order, when a line of the bar has room for `room`"
palette_items(e, p::CommandPalette, chips, room) = begin
  items = Any[(what=:tag, k=0, w=20 + ceil(omni_wide(palette_name(p.command.name), 13, "Medium")))]
  for k in eachindex(chips)
    push!(items, (what=:chip, k=k, w=chip_wide(e, p, chips, k)))
  end
  push!(items, (what=:run, k=0, w=24 + ceil(omni_wide("Run", 13, "Semibold")) + 4 + 11))
  # Words that the command is for take the room that's left on the line, up to OMNI_WORDS_MOST. Long words
  # grow the chip only to the end of the line, and then scroll in it, so the chip and the Run button stay in sight.
  if wide_words(Val(p.command.name))
    at = findfirst(it -> it.what == :chip && chip_kind(e, chips[it.k]) == :text, items)
    if at !== nothing
      it = items[at]
      left = floor(room - (sum(i -> i.w, items) - it.w) - OMNI_GAP * (length(items) - 1))
      most = left >= OMNI_WORDS_LEAST ? left : room
      items[at] = (what=it.what, k=it.k, w=min(most, max(it.w, clamp(left, OMNI_WORDS_LEAST, OMNI_WORDS_MOST))))
    end
  end
  items
end

"`items` on as many lines as they need, when a line has room for `room`"
palette_lines(items, room) = begin
  lines, used = [Any[]], 0.0
  for it in items
    need = it.w + (isempty(last(lines)) ? 0 : OMNI_GAP)
    if used + need > room && !isempty(last(lines))
      push!(lines, Any[])
      used, need = 0.0, it.w
    end
    push!(last(lines), it)
    used += need
  end
  lines
end

"The lines of the bar: all of them when the chips are on as many lines as they need, and the first line with room for the … button when they aren't and don't fit. The second is true when the … shows."
palette_bar_lines(e, p::CommandPalette, chips, room) = begin
  items = palette_items(e, p, chips, room)
  lines = palette_lines(items, room)
  (p.wrap || length(lines) == 1) && return (lines, false)
  ([first(palette_lines(items, room - 42 - OMNI_GAP))], true)
end

"How wide the bar is inside, for the tag, the chips and the Run button"
palette_room(e) = num(page_span(e)[2]) - OMNI_LEFT - OMNI_RIGHT - 2 - 2OMNI_BAR_X

"True when chip `k` is on a line that shows. The Run button, one more than the last chip, always counts as in sight."
palette_fits(e, p::CommandPalette, k::Int) = begin
  chips = palette_chips(p)
  k <= length(chips) || return true
  lines, _ = palette_bar_lines(e, p, chips, palette_room(e))
  any(it -> it.what == :chip && it.k == k, Iterators.flatten(lines))
end

"""
Where each part of the palette is in the window in this frame, in pixels: the
strip along the bottom, the bar in it, each thing in the bar, and the list
with what it hangs over. `down` is how far the whole of it is below its place
while the bar slides. The strip is `band` here.
"""
palette_plan(e, p::CommandPalette) = begin
  H = num(window_size(e)[2])
  # The bar is as wide as the page's space: beside the sidebar, or in agent mode under the page's card
  left = num(page_span(e)[1])
  W = left + num(page_span(e)[2])
  chips = p.command === nothing ? Wanted[] : palette_chips(p)
  room = palette_room(e)
  lines, more = p.command === nothing ? (Any[], false) : palette_bar_lines(e, p, chips, room)
  n = max(1, length(lines))
  bar_h = (p.command === nothing ? OMNI_FIELD_H : n * OMNI_CHIP_H + (n - 1) * OMNI_GAP + 2OMNI_BAR_Y) + 2
  band_h = 1 + OMNI_TOP + bar_h + OMNI_BOTTOM
  down = (1 - palette_risen(e, p)) * band_h
  band = (x=left, y=H - band_h + down, w=W - left, h=band_h)
  bar = (x=left + OMNI_LEFT, y=band.y + 1 + OMNI_TOP, w=W - left - OMNI_LEFT - OMNI_RIGHT, h=bar_h)
  # Each thing in the bar
  places = Any[]
  for (row, line) in enumerate(lines)
    x = bar.x + 1 + OMNI_BAR_X
    for it in line
      push!(places, (what=it.what, k=it.k, x=x, y=bar.y + 1 + OMNI_BAR_Y + (row - 1) * (OMNI_CHIP_H + OMNI_GAP), w=it.w, h=OMNI_CHIP_H))
      x += it.w + OMNI_GAP
    end
  end
  # The list, and what it hangs over
  rows = p.rows
  list = nothing
  if e.popup == :commands && p.command === nothing
    words = isempty(rows) && !isempty(strip_text(input(e))) ? "No command has that name" : ""
    many = isempty(words) ? length(rows) : 1
    if many > 0
      high = isempty(words) ? OMNI_ROW : OMNI_ROW_ONE
      # It's narrower than the bar by a tenth of the bar at each side, as in Centient
      inset = max(48.0, round(bar.w * 0.1))
      wide = min(max(320.0, bar.w - 2inset), bar.w - 2OMNI_FOOT)
      most = clamp(bar.y - 15 - 60, high, OMNI_LIST_MOST)
      tall = min(many * high, most)
      # The list comes down to the bar, so the card of rows is as near the bar's top line as it is to the list's other sides
      frame = (x=bar.x + (bar.w - wide) / 2, y=bar.y - tall - 15, w=wide, h=tall + 15)
      list = (kind=:attach, frame=frame, target=bar, row=high, tall=tall, words=words, round=6.0)
    end
  elseif e.popup == :commands && p.at <= length(chips)
    kind = chip_kind(e, chips[p.at])
    at = findfirst(c -> c.what == :chip && c.k == p.at, places)
    words = kind == :search && isempty(rows) && !isempty(p.query) ? "No matches found" : ""
    many = isempty(words) ? length(rows) : 1
    if kind in (:pick, :search) && at !== nothing && many > 0
      chip = places[at]
      longest = maximum(r -> length(r.name), rows, init=length(words))
      wide = 2ceil(max(max(200.0, ceil(longest * 8.5) + 40), chip.w + 36) / 2)
      # It's over the middle of its chip, and stays over the bar
      x = chip.x + chip.w / 2 - wide / 2
      x + wide > bar.x + bar.w && (x = chip.x + chip.w - wide)
      x < bar.x && (x = chip.x)
      x = clamp(x, 0.0, max(0.0, W - wide))
      top_room = chip.y - OMNI_POP_GAP - 14 - 60
      most = kind == :search ? min(OMNI_CHOICES_MOST, top_room) : min(480.0, top_room)
      tall = min(many * OMNI_ROW_ONE, max(OMNI_ROW_ONE, most))
      frame = (x=x, y=chip.y - OMNI_POP_GAP - tall - 15, w=wide, h=tall + 15)
      list = (kind=:envelope, frame=frame, target=chip, row=OMNI_ROW_ONE, tall=tall, words=words, round=4.0)
    end
  end
  (W=W, H=H, band=band, bar=bar, places=places, more=more, chips=chips, list=list)
end

strip_text(i::TextInput) = String(strip(i.text))

# --- how it looks ---

"Put `child` at `(x, y)` of the window, in a layer of its own"
omni_at(x, y, child) = Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(px(y), 0px, 0px, px(x)), child)

omni_label(text, size, colour; weight="", family=omni_font()) =
  Text(text, size=px(size), family=family, subfamily=family == omni_font() ? omni_weight(weight) : weight, color=colour, wrap=WrapMode.none)

describe(p::CommandPalette) = begin
  e = editor(p)
  c = omni(e)
  i = input(e)
  showing = e.popup == :commands
  showing && palette_sync!(e, p)
  p.rows = showing ? palette_rows(e, p) : Any[]
  p.pick = clamp(p.pick, 1, max(1, length(p.rows)))
  i.color, i.placeholder_color = c.ink, p.command === nothing ? c.muted : c.placeholder
  i.font_size = p.command === nothing ? 15px : 13px
  i.font_family = omni_font()
  was = p.plan
  plan = p.plan = palette_plan(e, p)
  # A text field scrolls by how wide it was in the frame before. When a chip grew or shrank, the next frame shows the field at its new width at once.
  was === nothing || was.places == plan.places || redraw_in!(e, 0)
  i.placeholder = p.command === nothing ? "Type a command" : p.at <= length(plan.chips) ? chip_name(plan.chips[p.at]) : ""
  palette_moving(e) && redraw_in!(p, 0.0)
  band, bar, list = plan.band, plan.bar, plan.list
  # While a list hangs over the bar, the bar has the list's colours, so the two are one shape
  joined = list !== nothing
  layers = Any[
    # The strip has no colour of its own and no line along its top: the page shows through it, blurred, and less so further up
    node!(PaletteFrost, e, :palette_frost),
    omni_at(bar.x, bar.y, Box(fixed(px(bar.w)), height(px(bar.h)), radius(6px), background(joined ? c.drop : c.bar),
                              border(1px, :solid, joined && list.kind == :attach ? c.drop_line : c.bar_line), node!(PaletteBar, e, :palette_bar)))]
  if list !== nothing
    f = list.frame
    push!(layers, node!(PaletteLens, e, :palette_lens))
    # The rows are on a card with a line round it, 6px inside the list's own outline
    card = if isempty(list.words)
      p.scroll.height = height(px(list.tall))
      p.shown == p.pick || (p.shown = p.pick; scroll_into_view!(p.scroll, px(list.row * (p.pick - 1)), px(list.row * p.pick)))
      reuse!(p.scroll, Column(width(grow=grow), Alignment.Start, [node!(() -> PaletteRow(k=k), e, (:palette_row, k)) for k in eachindex(p.rows)]...))
    else
      Row(width(grow=grow), height(px(list.row)), padding(14px, 0px), Box(omni_label(list.words, 14, c.ink, weight=OMNI_NAME)))
    end
    push!(layers, omni_at(f.x + 7, f.y + 7, Box(fixed(px(f.w - 14)), height(px(list.tall + 2)), radius(4px), clip=true, background(c.drop),
                                                border(1px, :solid, c.drop_line), card)))
  end
  if showing && !isempty(p.fault)
    # What went wrong shows where Centient's toast does: over the right end of the bar
    wide = min(bar.w, 24 + ceil(omni_wide(p.fault, 13)) + 2)
    push!(layers, omni_at(bar.x + bar.w - wide, band.y - 54, Box(fixed(px(wide)), height(40px), padding(12px, 0px), radius(8px), clip_x=true,
                                                                  background(c.toast), border(1px, :solid, OMNI_WRONG), lifted,
                                                                  omni_label(p.fault, 13, OMNI_WRONG))))
  end
  Stack(width(grow=grow), height(grow=grow), Alignment.Start, name="Command palette",
    # While a click on the window chooses for a chip, the window's parts are there for the click to find
    (showing && click_chip(e, p) === nothing ? (node!(PaletteCatch, e, :palette_catch),) : ())..., layers...)
end

describe(::PaletteCatch) = Box(width(grow=grow), height(grow=grow))
# A click outside the list of commands closes the palette. While a command has its chips, the palette stays.
onkey(c::PaletteCatch, ::KeyPress) = begin
  e = editor(c)
  palette(e).command === nothing && close_palette!(e)
  handled
end

# It's one pixel at the corner of the window, so the mouse goes through to the chips under what it draws,
# which is placed by the plan. With no size at all it wouldn't be drawn.
describe(::PaletteLens) = Box(fixed(1px), height(1px))

"The places along a quarter of a circle round `(cx, cy)`, from the angle `from` to the angle `to`. 0 is to the right, and a quarter turn on is down."
omni_arc(cx, cy, r, from, to) = [(cx + r * cos(a), cy + r * sin(a)) for a in range(from, to, length=7)]

"""
The outline of a list and what it hangs over, as the places along it, and the
outline of what's filled with the list's colour. Over a chip, the outline goes
round the list, curves in to the chip's sides and goes round the chip, so the
two are one shape. Over the bar, the list's sides go straight down and flare
out onto the bar's top line. Both are Centient's shapes. `q` is how round the
list's top corners are.
"""
lens_shapes(list; q=8.0) = begin
  f, t = list.frame, list.target
  l, top, r, bottom = f.x + 0.5, f.y + 0.5, f.x + f.w - 0.5, f.y + f.h
  quarter = pi / 2
  crown = [omni_arc(l + q, top + q, q, 2quarter, 3quarter); omni_arc(r - q, top + q, q, 3quarter, 4quarter)]
  if list.kind == :attach
    line = t.y + 0.5
    g = OMNI_FOOT
    outline = [omni_arc(l - g, line - g, g, quarter, 0.0); crown; omni_arc(r + g, line - g, g, 2quarter, quarter)]
    return (outline, [outline; (r + g, line + 1.0); (l - g, line + 1.0)], false)
  end
  # Over a chip: the gap between the two is as tall as the curve in to the chip is round
  cl, cr, ct, cb = t.x + 0.5, t.x + t.w - 0.5, t.y, t.y + t.h - 0.5
  g, rc = ct - bottom, list.round
  # A chip that's at an edge of the list has a straight side there
  wall_l, wall_r = cl - g - q < l, cr + g + q > r
  right = wall_r ? [(r, ct)] : [omni_arc(r - q, bottom - q, q, 0.0, quarter); omni_arc(cr + g, bottom + g, g, 3quarter, 2quarter)]
  left = wall_l ? [(l, ct)] : [omni_arc(cl - g, bottom + g, g, 0.0, -quarter); omni_arc(l + q, bottom - q, q, quarter, 2quarter)]
  cr2, cl2 = wall_r ? r : cr, wall_l ? l : cl
  under = [omni_arc(cr2 - rc, cb - rc, rc, 0.0, quarter); omni_arc(cl2 + rc, cb - rc, rc, quarter, 2quarter)]
  ([crown; right; under; left], [crown; right; (cr2, ct + 1.0); (cl2, ct + 1.0); left], true)
end

draw(ctx, size, ui::ConcreteRect, lens::PaletteLens) = begin
  e = editor(lens)
  plan = palette(e).plan
  (plan === nothing || plan.list === nothing) && return
  c = omni(e)
  outline, inside, closed = lens_shapes(plan.list)
  f = plan.list.frame
  # The list's shadow, which stops at the bar
  with_clip(ctx, 0px, 0px, px(plan.W), px(plan.bar.y)) do
    shade = ink(RGBA(0, 0, 0, e.theme == :night ? 0.5 : 0.14))
    blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, 9f0, true)
    Skia.sk_paint_set_maskfilter(shade, blur)
    shape = path_through([(f.x, f.y + 4); (f.x + f.w, f.y + 4); (f.x + f.w, f.y + f.h + 4); (f.x, f.y + f.h + 4)], true)
    Skia.sk_canvas_draw_path(ctx, shape, shade)
    Skia.sk_path_delete(shape)
    Skia.sk_maskfilter_unref(blur)
    Skia.sk_paint_delete(shade)
  end
  paint = ink(c.drop)
  shape = path_through(inside, true)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_path_delete(shape)
  Skia.sk_paint_delete(paint)
  trace(ctx, outline, c.drop_line, 1; closed)
end

# One pixel at the corner of the window, as the lens is, so it takes no clicks. It draws where the plan says.
describe(::PaletteFrost) = Box(fixed(1px), height(1px))

draw(ctx, size, ui::ConcreteRect, f::PaletteFrost) = begin
  plan = palette(editor(f)).plan
  plan === nothing && return
  b, top = plan.band, plan.bar.y - OMNI_FADE
  blur_under(ctx, b.x, top, b.w, b.y + b.h - top, OMNI_BLUR, fade=OMNI_FADE)
end

"""
Blur what's drawn so far in the part `(x, y, w, h)` of the window, as frosted
glass blurs what's behind it. `sigma` is how far the blur spreads. It copies
the pixels drawn so far, and draws the copy back blurred, cut to that part. A
canvas with no pixels of its own, like one that records, stays as it is. With
`fade`, the blur is none at the top of the part, and comes in smoothly to the
whole of it `fade` pixels down.
"""
blur_under(ctx, x, y, w, h, sigma; fade=0.0) = begin
  (w > 0 && h > 0) || return
  surface = Skia.sk_canvas_get_surface(ctx)
  surface == C_NULL && return
  image = Skia.sk_surface_make_image_snapshot(surface)
  image == C_NULL && return
  m = Ref{Skia.sk_matrix_t}()
  Skia.sk_canvas_get_total_matrix(ctx, m)
  sx, sy, tx, ty = Float64(m[].scaleX), Float64(m[].scaleY), Float64(m[].transX), Float64(m[].transY)
  # The copy is in the screen's pixels. Only the part that the blur reads is drawn: the part, and as far round it as the blur spreads.
  reach = 3sigma
  iw, ih = Float64(Skia.sk_image_get_width(image)), Float64(Skia.sk_image_get_height(image))
  l, t = max(0.0, sx * (x - reach) + tx), max(0.0, sy * (y - reach) + ty)
  r, d = min(iw, sx * (x + w + reach) + tx), min(ih, sy * (y + h + reach) + ty)
  if r > l && d > t
    area = Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h)))
    # A fade needs a layer of its own, so that the mask takes away only some of the blur and none of what's under it
    fade > 0 && Skia.sk_canvas_save_layer(ctx, area, C_NULL)
    paint = Skia.sk_paint_new()
    blur = Skia.sk_imagefilter_new_blur(Float32(sigma), Float32(sigma), Skia.SK_TILE_MODE_CLAMP, C_NULL, C_NULL)
    Skia.sk_paint_set_imagefilter(paint, blur)
    with_clip(ctx, px(x), px(y), px(w), px(h)) do
      paint_picture(ctx, image, (l, t, r - l, d - t), ((l - tx) / sx, (t - ty) / sy, (r - l) / sx, (d - t) / sy), paint)
    end
    Skia.sk_imagefilter_unref(blur)
    Skia.sk_paint_delete(paint)
    if fade > 0
      # The mask is clear at the top and solid `fade` down, and eases in and out between
      at = range(0.0, 1.0, length=9)
      points = [Skia.sk_point_t(Float32(x), Float32(y)), Skia.sk_point_t(Float32(x), Float32(y + fade))]
      colours = UInt32[UInt32(round(255 * a^2 * (3 - 2a))) << 24 for a in at]
      shader = Skia.sk_shader_new_linear_gradient(points, colours, Float32.(at), Cint(length(at)), Skia.SK_TILE_MODE_CLAMP, C_NULL)
      mask = Skia.sk_paint_new()
      Skia.sk_paint_set_shader(mask, shader)
      Skia.sk_paint_set_blend_mode(mask, Skia.SK_BLEND_MODE_DSTIN)
      Skia.sk_canvas_draw_rect(ctx, area, mask)
      Skia.sk_shader_unref(shader)
      Skia.sk_paint_delete(mask)
      Skia.sk_canvas_restore(ctx)
    end
  end
  Skia.sk_image_unref(image)
end

"A key as a row shows it: its sign in a box"
omni_key(c, sign, on) = Box(height(22px), padding(8px, 0px), radius(4px), background(on ? c.key_on : c.key),
                            border(1px, :solid, on ? c.key_on_line : c.key_line), omni_label(sign, 11, on ? c.key_on_ink : c.key_ink, family=SANS))

"The signs of the keys of a shortcut, one for each key, as Centient shows them: ⌘, ⇧ and P for ⌘⇧P"
key_signs(s::Shortcut) = String[sign for stroke in s for sign in [[sign for (key, _, sign) in HOLDS if key in stroke.held]; get(() -> uppercase(KEY_OF[stroke.key]), KEY_SIGNS, stroke.key)]]

describe(r::PaletteRow) = begin
  e = editor(r)
  p = palette(e)
  r.k <= length(p.rows) || return Box(height(0px))
  c = omni(e)
  row = p.rows[r.k]
  on = p.pick == r.k
  # A line is between two rows, but not at an edge of the row that's chosen
  ruled = r.k > 1 && !on && p.pick != r.k - 1
  look = (width(grow=grow), padding(14px, 0px), background(on ? c.selected : c.drop), border(1px, :solid, ruled ? c.rule : clear)[:top])
  if p.command !== nothing
    return Row(look..., height(px(OMNI_ROW_ONE)), child_gap=10px, name="Choice",
      Box(width(grow=grow), Alignment.Start, clip_x=true, omni_label(row.name, 14, c.ink, weight=OMNI_NAME)),
      (isempty(row.note) ? () : (Box(omni_label(row.note, 12, on ? c.ink2 : c.muted)),))...)
  end
  # The letters that were typed are in bold where the name has them
  before, found, after = match_parts(row.name, lowercase(strip_text(input(e))))
  parts = [Box(omni_label(text, 14, c.ink, weight=weight)) for (text, weight) in ((before, OMNI_NAME), (found, OMNI_MATCH), (after, OMNI_NAME)) if !isempty(text)]
  Row(look..., height(px(OMNI_ROW)), child_gap=10px, name="Command",
    Column(width(grow=grow), Alignment.Start, child_gap=8px, clip_x=true,
      # What the command works on follows its name, fainter
      Row(child_gap=8px, Alignment.End, Row(parts...), (isempty(row.on) ? () : (Box(padding(0px, 0px, 1px, 0px), omni_label(row.on, 12, on ? c.ink2 : c.muted)),))...),
      Box(omni_label(row.note, 12, on ? c.ink2 : c.muted))),
    (row.keys === nothing ? () : (Row(child_gap=4px, [omni_key(c, sign, on) for sign in key_signs(row.keys)]...),))...)
end
cursor(::PaletteRow) = :hand
# The mouse over a row chooses it, and no more. The row is in sight already, so the list doesn't scroll to it.
onmouse(r::PaletteRow, ::MouseMove) = (p = palette(editor(r)); p.pick = p.shown = r.k; p.pointed = true; handled)
# A click on a row does what Return does on it
onkey(r::PaletteRow, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(r)
  p = palette(e)
  r.k <= length(p.rows) || return handled
  p.pick = p.shown = r.k
  p.pointed = true
  palette_take!(e, ev.window, p)
  handled
end

"The field with the rest of a name after its text, in a fainter colour. `size` is the size of the field's text."
omni_field(e, p::CommandPalette, size) = begin
  i = input(e)
  ghost = palette_ghost(e, p)
  isempty(ghost) && return i
  Stack(width(grow=grow), height(grow=grow),
    Row(width(grow=grow), height(grow=grow), Box(fixed(px(omni_wide(i.text, size)))), Box(omni_label(ghost, size, omni(e).placeholder)), Box(width(grow=grow))),
    i)
end

describe(b::PaletteBar) = begin
  e = editor(b)
  p = palette(e)
  c = omni(e)
  plan = p.plan
  p.command === nothing && return Row(width(grow=grow), height(grow=grow), padding(px(OMNI_BAR_X), 0px), name="Command field", omni_field(e, p, 15))
  lines = Any[]
  for y in unique(pl.y for pl in plan.places)
    parts = Any[]
    for pl in plan.places
      pl.y == y || continue
      push!(parts, pl.what == :tag ? Box(fixed(px(pl.w)), height(px(pl.h)), padding(10px, 0px), radius(4px), background(OMNI_TAG),
                                         Box(omni_label(palette_name(p.command.name), 13, OMNI_TAG_INK, weight="Medium"))) :
                   pl.what == :run ? node!(PaletteRun, e, :palette_run) : node!(() -> PaletteChip(k=pl.k), e, (:palette_chip, pl.k)))
    end
    push!(lines, Row(width(grow=grow), height(px(OMNI_CHIP_H)), child_gap=px(OMNI_GAP), parts...,
                     Box(width(grow=grow)), (plan.more && isempty(lines) ? (node!(PaletteMore, e, :palette_more),) : ())...))
  end
  Column(width(grow=grow), height(grow=grow), Alignment.Start, padding(px(OMNI_BAR_X), px(OMNI_BAR_Y)), child_gap=px(OMNI_GAP), clip=true, name="Command field", lines...)
end
cursor(b::PaletteBar) = palette(editor(b)).command === nothing ? :ibeam : :arrow
onkey(b::PaletteBar, ::KeyPress{Keys.mouse_left}) = (e = editor(b); palette_focus!(e, palette(e)); handled)

describe(m::PaletteMore) = begin
  c = omni(editor(m))
  Row(fixed(42px), height(px(OMNI_CHIP_H)), radius(4px), background(ishovered(m) ? c.hover : c.chip), justify=Alignment.Center,
      border(1px, :solid, c.chip_line), name="More", Box(omni_label("…", 13, c.ink2, weight="Medium")))
end
cursor(::PaletteMore) = :hand
onkey(m::PaletteMore, ::KeyPress{Keys.mouse_left}) = (palette(editor(m)).wrap = true; handled)

describe(chip::PaletteChip) = begin
  e = editor(chip)
  p = palette(e)
  c = omni(e)
  plan = p.plan
  at = plan === nothing ? nothing : findfirst(pl -> pl.what == :chip && pl.k == chip.k, plan.places)
  (at === nothing || chip.k > length(plan.chips)) && return Box()
  pl, wanted = plan.places[at], plan.chips[chip.k]
  kind = chip_kind(e, wanted)
  on = p.at == chip.k
  x = chip_value(p, plan.chips, chip.k)
  # The mouse over a chip for a moment shows what the chip is for
  hovered = ishovered(chip)
  hovered || (chip.over = 0.0)
  hovered && chip.over == 0.0 && (chip.over = time())
  hovered && time() - chip.over < 0.4 && redraw_in!(chip, 0.4 - (time() - chip.over))
  w = window_of(e)
  hovered && w !== nothing && 0.4 <= time() - chip.over < 0.6 &&
    show_tooltip!(w, Box(padding(10px, 6px), omni_label(chip_tip(wanted), 12, TIP_INK)), px(pl.x), px(pl.y), px(pl.w), px(pl.h), placement=:top, gap=6px)
  # While a list hangs over the chip, the two are one shape: the chip has the list's colour, and the outline is the list's
  joined = on && plan.list !== nothing && plan.list.kind == :envelope
  back = on ? c.drop : x !== UNSAID ? c.complete : hovered ? c.hover : c.chip
  look = (fixed(px(pl.w)), height(px(pl.h)), padding(8px, 0px), joined ? radius(0px, 0px, 4px, 4px) : radius(4px), background(back),
          border(1px, :solid, joined ? clear : c.chip_line))
  if kind == :switch
    is = x === true
    return Box(look..., name="Chip",
      Row(fixed(32px), height(18px), radius(9px), background(is ? OMNI_SWITCH_ON : OMNI_SWITCH_OFF), padding(0px, 0px, 0px, is ? 16px : 2px),
        Box(fixed(14px), height(14px), radius(7px), background(OMNI_KNOB)), Box(width(grow=grow))))
  elseif kind == :segment
    found, said = segment_state(e, p, plan.chips, chip.k)
    parts = Any[]
    for (n, o) in enumerate(found)
      n > 1 && push!(parts, Box(fixed(1px), height(grow=grow), background(c.chip_line)))
      push!(parts, Box(height(grow=grow), padding(8px, 0px), background(n == said ? c.hover : clear),
                       omni_label(worded(o), 13, n == said ? c.ink : c.muted, weight="Semibold")))
    end
    return Box(look..., name="Chip", Row(height(23px), radius(3px), clip=true, border(1px, :solid, c.chip_line), parts...))
  end
  if on && kind != :pick
    return Box(look..., name="Chip", omni_field(e, p, 13))
  end
  # A chip for things in the window has each thing's colour and letter, which the line round the thing has too
  letters = filter(l -> l.k == chip.k, chip_letters(p, plan.chips))
  if !isempty(letters)
    # Each letter is in a box of its own, as wide as it is, so its part of the chip can centre it
    cells = [Box(fixed(px(ceil(omni_wide(l.letter, 13, "Semibold")) + 24)), height(px(pl.h)), Alignment.Center, justify=Alignment.Center,
                 background(hovered ? paler(l.colour) : l.colour), Box(omni_label(l.letter, 13, colorant"white", weight="Semibold")))
             for l in letters]
    return Row(fixed(px(pl.w)), height(px(pl.h)), radius(4px), clip=true, name="Chip", cells...)
  end
  words, unsaid = chip_words(p, plan.chips, chip.k)
  Box(look..., clip_x=true, name="Chip", omni_label(words, 13, unsaid ? c.placeholder : c.ink))
end
cursor(chip::PaletteChip) = begin
  e = editor(chip)
  p = palette(e)
  chips = palette_chips(p)
  chip.k <= length(chips) && p.at == chip.k && chip_kind(e, chips[chip.k]) in (:text, :number, :search) ? :ibeam : :hand
end
# A click on a chip puts the keyboard in it. A click on a switch turns it too, and a click on a choice of two chooses the other.
onkey(chip::PaletteChip, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(chip)
  p = palette(e)
  hide_tooltip!(ev.window)
  chips = palette_chips(p)
  chip.k <= length(chips) || return handled
  kind = chip_kind(e, chips[chip.k])
  p.at == chip.k || go_chip!(e, p, chip.k)
  kind == :switch && switch!(p, chip.k)
  kind == :segment && segment_step!(e, p, chip.k, 1)
  palette_focus!(e, p)
  handled
end

describe(r::PaletteRun) = begin
  e = editor(r)
  p = palette(e)
  c = omni(e)
  on = p.at > length(palette_chips(p))
  words = on ? OMNI_GO_INK : c.run_ink
  # The arrow is the sign of the Return key, which the Mac's own font has no character for
  Row(height(px(OMNI_CHIP_H)), padding(10px, 0px), radius(4px), child_gap=4px, name="Run",
      background(on ? OMNI_GO : ishovered(r) ? c.run_hover : c.run), border(2px, :solid, on ? OMNI_GO_LINE : clear),
      (on ? (shadow(0, 0, 0, RGBA(34 / 255, 197 / 255, 94 / 255, 0.3), spread=3px),) : ())...,
      Box(omni_label("Run", 13, words, weight="Semibold")), Icon("arrow-return-left", size=11px, color=words))
end
cursor(::PaletteRun) = :hand
onkey(r::PaletteRun, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(r)
  palette_run!(e, ev.window, palette(e))
  handled
end

# --- the app for Markdown files ----------------------------------------------------------
#
# macOS keeps, for each kind of file, the app that opens it when you
# double-click one. The settings page has a button that makes Ladder that app
# for Markdown files. macOS then tells Ladder which file to open with a
# message, not with an argument, so the app keeps a list of the files it's
# been asked for and the window opens them.

const MARKDOWN_TYPE = "net.daringfireball.markdown"   # macOS's name for the kind of file that Markdown is

"macOS's object for the kind of file that Markdown is"
markdown_type() = begin
  # The class is in a framework that a window loads, but a test without a window hasn't
  ccall(:dlopen, Ptr{Cvoid}, (Cstring, Cint), "/System/Library/Frameworks/UniformTypeIdentifiers.framework/UniformTypeIdentifiers", 1)
  msg(cls("UTType"), "typeWithIdentifier:", nsstring(MARKDOWN_TYPE))
end

"Where the Ladder app is on this Mac, or an empty string when it isn't installed"
app_path() = Sys.isapple() ? with_pool(() -> url_path(msg(workspace(), "URLForApplicationWithBundleIdentifier:", nsstring(APP_ID)))) : ""

"The app that opens a Markdown file when you double-click one, or an empty string when macOS can't say"
markdown_app() = begin
  Sys.isapple() || return ""
  with_pool() do
    type = markdown_type()
    type == C_NULL ? "" : url_path(msg(workspace(), "URLForApplicationToOpenContentType:", type))
  end
end

"""
Open the file at `path` in the app that the Mac uses for it. A file that the
Mac has no app for shows in the Finder.
"""
open_outside(path) = begin
  isfile(path) || return
  isempty(opener(path)) && Sys.isapple() ? show_in_finder(path) : open_url(path)
  nothing
end

"Open the file that the page shows in the app that the Mac uses for it"
open_outside!(e) = (open_outside(e.buf.path); e)

"""
The top bar's button that opens the file of a page that's only shown in the
app that the Mac uses for it, since that app can change it. A folder, or a
file that no app opens, has no button: it would only show it in the Finder.
Nor has an HTML file: its app is a web browser, and Ladder is one for it.
"""
outside_button(e) = isempty(opener(e.buf.path)) || html_page(e.buf) ? () : (button(e, :outside, "box-arrow-up-right"),)

"""
Ask macOS to make Ladder the app that opens Markdown files. macOS shows a
dialog of its own that asks you to confirm, and changes the app when you say
yes. It's true when macOS was asked. It's false when the Ladder app isn't
installed on this Mac, because macOS would then ask about an app with no name.
"""
make_default!() = begin
  (Sys.isapple() && !isempty(app_path())) || return false
  with_pool() do
    # 0xffffffff is every way of opening a file: to read it, to change it and so on
    ccall((:LSSetDefaultRoleHandlerForContentType, "/System/Library/Frameworks/CoreServices.framework/CoreServices"), Int32,
          (Ptr{Cvoid}, UInt32, Ptr{Cvoid}), nsstring(MARKDOWN_TYPE), 0xffffffff, nsstring(APP_ID)) == 0
  end
end

"""
Look for your answer to macOS's dialog, twice a second for two minutes after
the button on the settings page. When the app for Markdown files changes, the
blocks that show which app it is run again.
"""
await_default!(e) = begin
  asked = get(e.nodes, :asked, nothing)
  asked === nothing && return
  at, before, checked = asked
  now = time()
  if now - checked >= 0.5
    if markdown_app() != before
      delete!(e.nodes, :asked)
      return rerun!(e, :app)
    end
    now - at > 120 && return delete!(e.nodes, :asked)
    e.nodes[:asked] = (at, before, now)
  end
  # Nothing else may happen in the window while the dialog is open, so ask for the next look
  redraw_in!(e, 0.5)
end

"""
The files that macOS asked Ladder to open, which it hasn't opened yet. macOS
asks when you double-click a Markdown file in the Finder or drop one on
Ladder's icon. The app puts its own list here.
"""
const inbox = Ref(String[])

"""
Show the last file or folder that macOS asked for. A window shows one file, so
that's the one to show. The settings window keeps its page: another window
shows the file, and with no other window open, a new one does.
"""
receive!(e) = begin
  files = inbox[]
  isempty(files) && return
  if issettings(e)
    i = findfirst(o -> !issettings(o), editors)
    if i === nothing
      path = pop!(files)
      empty!(files)
      ispath(path) && show_window!(page_window(path, e), window_of(e))
    else
      # That window may have nothing else to draw for, so ask it to draw
      w = window_of(editors[i])
      w === nothing || stale!(w)
    end
    return
  end
  path = pop!(files)
  empty!(files)
  isdir(path) ? open_on_folder!(e, path) : isfile(path) && open!(e, path)
  touch!(e)
end

# --- the whole window ---------------------------------------------------------------------

describe(e::Editor) = begin
  scene = describe_window(e)
  # A folder's page that waits runs when the frame is made, so that no part of a frame meets code that's
  # newer than the frame. The next frame is drawn with what the page loaded.
  isempty(FOLDER_PAGES_DUE) || run_folder_pages!()
  # A web folder's page runs then too, once its site may run code. See "a web folder's own page".
  isempty(WEB_PAGES_DUE) || run_web_folder_pages!()
  ask_sandbox!(e)
  haskey(e.nodes, :reload_ask) && ask_reload!(e)
  scene
end

"What the window shows, and what Ladder does in each frame before it"
describe_window(e::Editor) = begin
  # A page of a blog looks as the blog's site does, whatever the theme. Text laid out in the other look is laid out again.
  look = page_look(e)
  look == e.look || (e.look = look; restyle!(e))
  colours_over[], pane_dark[] = nothing, false   # the page's colours, whatever the last frame left
  use!(look == :site ? SITE : look == :news ? NEWS : getproperty(THEMES, e.theme))
  use_code_font!(e)
  side_tick!(e)   # the side menu of this frame, and how wide it is
  win = window_of(e)
  if win !== nothing && e.applied != look_key(e)
    set_dark!(win, look_key(e) == :night)
    e.applied = look_key(e)
  end
  receive!(e)
  await_default!(e)
  remote_tick!(e)
  moved = refresh!(e.buf)
  moved === nothing || (stay!(e, moved); fresh!(e, moved))
  # The bars beside the lines that just changed fade, so the window is drawn again while they show
  isempty(fresh(e)) || redraw_in!(e, 1/30)
  find_tick!(e)
  sound_tick!(e)
  blocks_tick!(e)
  point_tick!(e)
  scrub_tick!(e)
  inline_tick!(e)
  confine!(e)   # while the lines of a block fill the window, the caret stays in them
  job_tick!(e)
  update_tick!(e)
  folder_pages_tick!(e)
  ignored_tick!(e)
  startup_tick!(e)
  foreach(f -> f(e), values(EACH_FRAME))   # what code from the startup page does in each frame, like a look for new email
  zoom_tick!(e)
  slide_tick!(e)
  screen_tick!(e)
  bar_tick!(e)
  code_tick!(e)
  run_tick!(e)
  term_tick!(e)
  ask_tick!(e)
  session_tick!(e)
  chat_tick!(e)
  live_checks_tick!(e)
  file_checks_tick!(e)
  rename_tick!(e)
  line_tick!(e)
  app_tick!(e)
  publish_tick!(e)
  layout!(e)
  inline_diff!(e)   # room for the lines that went from the file, while the window shows what changed in it
  # A page whose long lines don't wrap scrolls sideways as far as its longest line goes, and no further when the window grows
  if !wraps(e)
    e.reach = maximum(it -> it.content isa Flow ? extent(it.content) : 0px, e.layout, init=0px)
    scroll_sideways!(e, 0px)
  end
  # A live block that changed the size of the text stays where it was in the window
  hold = pop!(e.nodes, :hold, nothing)
  hold === nothing || (e.scroll.offset = max(0px, item(e, hold[1]).top - hold[2]))
  e.reveal && (reveal!(e); e.reveal = false)
  reveal_part!(e)   # the caret of a part of another page that has the keyboard
  # The window is drawn again as soon as a key or the mouse does something, so
  # typing shows without waiting for a frame that was already under way. Between
  # times it only wakes to blink the caret.
  if win !== nothing
    # While the sidebar or the panel at the right slides, the top bar's buttons slide, the command palette slides, or the caret moves to a new place, each frame is drawn as soon as it can be
    win.animating = sliding(e) || right_sliding(e) || clearing(e) || gliding(e) || palette_moving(e) || bar_sliding(e)
    # A part of a live block that has the keyboard, like a text field, blinks its own caret
    win.wake = pop!(e.nodes, :ran, false) ? 0.05 : win.focus === e ? 0.51 - mod(time() - e.blink, 0.5) :
               win.focus === nothing ? 0.0 : 0.25
  end
  window_view(e, window_object(e))
end

# The window is made by `window_view`, for the object of the file or the folder
# that the window shows. So a kind of folder, or a kind of file, can have a
# window of its own, as it can have a page of its own with `page_view`. Two
# parts of Ladder's own window are functions of the object too, for a kind that
# wants only that part its own way: `side_menu` is the side menu, which takes
# the sidebar's place, and `bread_crumb` is what the middle of the top bar shows.
#
#     @def struct ShopDirectory <: Ladder.AbstractDirectory end
#     Ladder.side_menu(e, d::ShopDirectory) = shop_menu(e, d)        # while the window shows the folder
#     Ladder.side_menu(e, d::ShopDirectory, o) = shop_menu(e, d)     # while it shows a thing that the folder holds
#
# Each of the three has a method with three arguments, as `entry_marks` has:
# `d` is the directory that holds `o`. The folders in a folder of a kind have
# the kind that `FS.kind` gives them, so a kind can keep its window all the way down.

"""
The object that the window is about: the file or the folder that it shows. A
window that shows no file is about the folder that its sidebar lists. Nothing
when there's no such object.
"""
window_object(e) = begin
  o = e.buf.view == :file ? page_object(e) : text_object(e)
  o === nothing && isempty(e.buf.path) ? directory(e) : o
end

"""
All that the window shows while it's about `o`: a node as big as the window.
Ladder's own is `window_body(e)` with `window_over(e)` over it. A kind of
folder has a method of this to make the whole window itself: `window_view(e, d)`
for the folder, and `window_view(e, d, o)` for each thing `o` that it holds.
Such a window needs `window_over(e)...` at its end to keep the top bar, the
file finder and the command palette.
"""
window_view(e, o) = window_view(e, o.parent, o)
window_view(e, ::Nothing) = window_view(e, nothing, nothing)
window_view(e, d, o) = Stack(width(grow=grow), height(grow=grow), Alignment.Start, name="Editor", window_body(e), window_over(e)...)

"""
The sidebar, the page and the panel at the right, side by side. The sidebar
runs from the top of the window to the bottom, and the top bar lies over the
top of the sidebar and the page.
"""
window_body(e) = agent_shows(e) ? agent_body(e) : Row(width(grow=grow), height(grow=grow), Alignment.Start, background(colours.bg),
  # The lines of a block that fill the window take the sidebar's room too
  (side_w(e) > 0px && lowered(e) === nothing && !as_app(e) ? (side_part(e),) : ())...,
  Column(width(grow=grow), height(grow=grow), Alignment.Start,
    Box(width(grow=grow), height(under_bar(e))),   # under the top bar
    node!(Page, e, :page)),
  right_panel(e)...)

"""
What lies over the sidebar and the page, from the lowest to the highest: the
edge of the sidebar that you drag, what floats over the page, the top bar,
and last the file finder or the command palette.
"""
window_over(e) = begin
  # The command palette has nothing behind it that dims the page, and it shows while it slides down after it closes
  popup = palette_shows(e) ? (palette(e),) : e.popup == :none ? () : (node!(Backdrop, e, :backdrop), finder(e))
  (panel_edge(e)..., tablebar(e)..., put_back_over(e)..., outcome_over(e)..., callbox(e)..., suggestbox(e)..., findbar(e)..., sound_over(e)..., fill_over(e)..., task_over(e)..., slides_over(e)..., takeoff_over(e)..., zoom_over(e)...,
   (screening(e) || bar_shown(e) == 0 ? () : (bar_back(e)..., node!(TopBar, e, :topbar)))...,   # a video that fills the screen is all that the window shows
   popup...)
end

# --- windows ------------------------------------------------------------------------------
#
# Ladder can have more than one window open, each with an editor of its own.
# The settings page opens in a window of its own, so the page you were working
# on stays as it was. ⌘W closes the file that a window shows, and then the
# window. Ladder quits when its last window closes. See "closing a file".

const WELCOME = joinpath(@__DIR__, "pages", "welcome.md")

"""
Make a window for the editor `e`. `show_window!` puts it on the screen. Until
it closes, `e` gets each setting that changes in another window.
"""
window!(e; kw...) = begin
  w = Window(e; kw...)
  push!(editors, e)
  focus(e)
  w
end

"""
Put the window `w` on the screen, if the window `by` that asked for it is on
the screen. A test's window isn't, so the windows that it opens aren't either.
"""
show_window!(w, by) = (by !== nothing && isopen(by) && open(w); w)

onclose(e::Editor, ::Window) = (Base.filter!(o -> o !== e, editors); close_designs!(e); close_terminals!(e); close_agent!(e); close_chats!(e); close_asks!(e); nothing)

"""
A window that shows the Markdown file or the folder at `path`, with the
settings of the editor `like`. `show_window!` puts it on the screen.
"""
page_window(path, like) = begin
  e = build_editor(path)
  foreach(name -> setfield!(e, name, getfield(like, name)), SHARED)
  e.remember = like.remember
  e.size = paper_window(screen_room(), e.side)
  window!(e, title="Ladder", size=e.size)
end

"""
The folder that the window of `e` is in: the folder that its page shows, or
the folder of the file that it shows. A window with no file is in the folder
that its sidebar lists.
"""
current_folder(e) = begin
  path = e.buf.path
  isdir(path) && return path
  !isempty(path) && isdir(dirname(path)) && return dirname(path)
  isdir(e.folder) ? e.folder : homedir()
end

"""
⌘N: open a new window on the folder that the window of `e` is in. Its page
shows the folder, as a click on the folder in the top bar's path does, and its
sidebar is closed. It's as big as the window of `e`, and a little lower and to
the right, as the Mac puts a new window. It gives the new window's editor.
"""
new_window!(e) = begin
  e = top_editor(e)
  folder = current_folder(e)
  shown = blank_editor()
  foreach(name -> setfield!(shown, name, getfield(e, name)), SHARED)
  shown.remember = e.remember
  show_path!(shown, folder)
  by = window_of(e)
  size, at = by === nothing ? (paper_window(screen_room(), e.side), (0px, 0px)) :
                              ((by.size[1], by.size[2]), (by.position[1] + 30px, by.position[2] + 30px))
  shown.size = size
  show_window!(window!(shown, title="Ladder", size=size, position=at), by)
  shown
end

# --- settings -----------------------------------------------------------------------------
#
# The settings are the page's colours, its font and the font's weight, the size
# of its text, its width, how code
# shows, the key bindings and how wide the sidebar is. ⌘, opens the settings in
# a window of their own.
# They're on the pages of one folder, each a Markdown file whose live blocks
# change them. ⌘, shows the folder's main page, and that page has a link to
# each of the others. These are pages like any other: the settings window
# shows them as any window shows a page, and any window can show them. A
# setting that changes in one window changes in every window. They are kept in
# a file, so the next window opens with them.

"The folder of Ladder's own pages. The built app changes it to the copies it writes out."
const pages_dir = Ref(joinpath(@__DIR__, "pages"))

"The folder of the pages that have the settings"
settings_dir() = joinpath(pages_dir[], "settings")

"Where the page of the settings is whose file is called `name`. Without a name, it's the main page, which ⌘, shows."
settings_page(name="settings.md") = joinpath(settings_dir(), name)

const SETTINGS_SIZE = (720px, 820px)   # of the settings window, when the window that asked for it is big enough
const SETTINGS_DROP = 48px             # how far the settings window's top is below the top of the window that asked for it

"""
True when `e` is the editor of the settings window: the one that ⌘, opened,
while it shows a page of the settings' folder. ⌘, closes that window, and a
file that macOS asks for goes to another window. In every other way it's a
window like any other.
"""
issettings(e) = e.settings && (dirname(e.buf.path) == settings_dir() || dirname(e.buf.path) in values(SETTINGS_FOLDERS))

"The editor of the settings window, or nothing while that window isn't open"
settings_editor() = (i = findfirst(issettings, editors); i === nothing ? nothing : editors[i])

"""
Show the settings page in a window of its own. With that window open already,
bring it to the front. In the settings window itself, close it.
"""
toggle_settings!(e) = begin
  by = window_of(e)
  by === nothing && return e
  issettings(e) && return (close(by); e)
  s = settings_editor()
  s === nothing || return (front!(window_of(s)); e)
  s = build_editor(settings_page())
  s.settings = true
  empty!(tabs(s))   # the settings window has no tabs, and its first page got one before it was the settings window
  foreach(name -> setfield!(s, name, getfield(e, name)), SHARED)
  s.remember = e.remember
  s.panel = false
  # The window goes over the middle of the one that asked for it, a little below its top
  wide, tall = SETTINGS_SIZE
  tall = min(tall, max(400px, by.size[2] - 2SETTINGS_DROP))
  at = (max(0px, by.position[1] + (by.size[1] - wide) / 2), by.position[2] + SETTINGS_DROP)
  s.size = (wide, tall)
  show_window!(window!(s, title="Settings", size=s.size, position=at), by)
  e
end

"""
Give the other windows the settings of `e`, after one of them changed. A window
that isn't in `editors`, like one a test makes, keeps its settings to itself.
"""
share_settings!(e) = begin
  any(o -> o === e, editors) || return
  for o in editors
    o === e || adopt_settings!(o, e)
  end
end

"Give `o` the settings of `e` that are different. The line at the top of `o`'s window stays there."
adopt_settings!(o, e) = begin
  changed = filter(name -> getfield(o, name) != getfield(e, name), SHARED)
  isempty(changed) && return o
  for name in changed
    setfield!(o, name, getfield(e, name))
    rerun!(o, name)   # a live block that reads the setting shows the new one
  end
  if :hidden in changed
    list_files!(o)
    # When the list of files is all that changed, the page's lines stay where they are
    changed == (:hidden,) && return (w = window_of(o); w === nothing || stale!(w); o)
  end
  # The width of a sidebar that's hidden changes nothing that the window shows, and the path in the top bar moves no lines
  o.panel || changed != (:side,) || return o
  changed == (:pinned,) && return (w = window_of(o); w === nothing || stale!(w); o)
  # Text of another size or width wraps again, and that moves the lines
  y = o.scroll.offset
  i = findfirst(it -> it.top + it.tall > y, o.layout)
  i === nothing || (o.nodes[:hold] = (o.layout[i].first, o.layout[i].top - y))
  empty!(o.flows)
  w = window_of(o)
  w === nothing || stale!(w)
  o
end

# The app was called Kaydown until 18 November 2026, and its folders in
# ~/Library had that name. The first time Ladder starts, it gives them its own
# name, so the settings and the Welcome pages stay. A folder that has the new
# name already stays as it is, and so does the old one.

"Give the app's folders in `home`'s Library the name Ladder, if they still have the old name Kaydown"
move_old_folders!(home=homedir()) =
  for parts in (("Application Support",), ("Caches",))
    old, new = joinpath(home, "Library", parts..., "Kaydown"), joinpath(home, "Library", parts..., "Ladder")
    (isdir(old) && !ispath(new)) || continue
    try
      mv(old, new)
    catch err
      @warn "Ladder couldn't give its folder its new name" old new exception=err
    end
  end

"""
Give the other windows the settings of `e`, and write them to their file if
this editor keeps them. An editor that's made for a test doesn't.
"""
save_settings!(e) = begin
  usual_zoom!(e)   # the bigger text of a slide is no setting
  share_settings!(e)
  e.remember || return
  try
    mkpath(dirname(settings_file()))
    # After the bundle of key bindings comes a line for each command that has other keys than the bundle's, like key.save=ctrl+s
    changed = join(["key.$name=$(e.rebound[name])\n" for name in sort!(collect(keys(e.rebound)))])
    write(settings_file(), "theme=$(e.theme)\nfont=$(e.font)\nweight=$(e.weight)\nzoom=$(e.zoom)\nwidth=$(e.widest.value)\nplain=$(e.plain)\nspelling=$(e.spelling)\nupdates=$(e.updates)\nautosave=$(e.autosave)\npeeks=$(e.peeks)\nagent=$(e.ai)\nglide=$(e.glide)\nwrap=$(e.wrap)\nnumbers=$(e.numbers)\nshade=$(e.shade)\nbeside=$(e.beside)\nindent=$(e.indent)\ncode=$(e.code_scale)\ncodefont=$(e.code_font)\ncodeweight=$(e.code_weight)\nguide=$(e.guide)\nsidebar=$(e.side.value)\nhidden=$(e.hidden)\nright=$(e.right)\nownmessage=$(e.own)\npinned=$(e.pinned)\nhidebar=$(e.hide_bar)\npagecard=$(page_card_setting())\nagentshidden=$(join(sort!(collect(AGENTS_HIDDEN[])), ','))\nmodels=$(models_setting())\n$(term_settings_text())keys=$(e.bundle)\n$changed")
  catch
    # A file that can't be written only means the settings last as long as the window
  end
  nothing
end

# --- the app's own updates ------------------------------------------------------------------
#
# The Ladder app gets a newer version of itself while you work, and the new
# version takes the app's place when you quit. update.jl does the work, and
# says how. The settings page has a box that turns it off, a line that says how
# far an update has got, and a button to look for one now.
#
# The app gets the new code of its extensions from GitHub the same way, and the
# same box turns that off. The new code loads the next time that Ladder opens.
# The settings page has a line that says which extensions have new code, and a
# button that looks for it now or restarts Ladder to load it.

"Turn on or off whether the app gets a newer version, and its extensions' new code, without being asked"
updates!(e, on::Bool) = begin
  e.updates = on
  Update.own().auto = on
  Update.extensions().auto = on
  save_settings!(e)
  rerun!(e, :updates)
  e
end

"True when a page that's open in a window has changes that aren't in its file"
unsaved() = any(o -> dirty(o.buf) || any(dirty, values(o.buffers)) || !isempty(unsaved_designs(o)), editors)

"""
What happens to the app's update in each frame. Only a window of the app looks
for one: a window that a test makes doesn't. When an update gets further, the
blocks of the settings page that show it run again.
"""
update_tick!(e) = begin
  e.remember || return
  u = Update.own()
  u.auto = e.updates
  wait = Update.tick!(u)
  if get(e.nodes, :update_seen, -1) != u.changed
    e.nodes[:update_seen] = u.changed
    delete!(e.nodes, :update_held)
    rerun!(e, :update)
  end
  isfinite(wait) && redraw_in!(e, wait)   # while it checks or downloads, the window looks again soon
  extensions_tick!(e)
  nothing
end

"""
What happens to the extensions' new code in each frame, as `update_tick!` does
for the app. When it gets further, the block of the settings page that shows
it runs again.
"""
extensions_tick!(e) = begin
  x = Update.extensions()
  x.auto = e.updates
  wait = Update.tick!(x)
  if get(e.nodes, :extensions_seen, -1) != x.changed
    e.nodes[:extensions_seen] = x.changed
    delete!(e.nodes, :extensions_held)
    rerun!(e, :extensions)
  end
  isfinite(wait) && redraw_in!(e, wait)   # while it fetches, the window looks again soon
  nothing
end

"A sentence or two on the extensions' new code, for the settings page"
extensions_news(e) = begin
  reads!(e, :updates)
  reads!(e, :extensions)
  get(e.nodes, :extensions_held, false) && return "Save your changes first. A page has changes that aren't in its file, and a restart would lose them."
  Update.says(Update.extensions())
end

"""
Do what the settings page's button for the extensions offers: look for new
code, or restart Ladder to load it. A restart closes every window, each
extension moves up to its new code, and Ladder opens again. It doesn't happen
while a page has changes that aren't saved.
"""
extensions_act!(e) = begin
  x = Update.extensions()
  if Update.action(x) === :restart && unsaved()
    e.nodes[:extensions_held] = true
    return rerun!(e, :extensions)
  end
  Update.act!(x)
  rerun!(e, :extensions)
  x.again && foreach(o -> (w = window_of(o); w === nothing || close(w)), copy(editors))
  nothing
end

"A sentence or two on how far the app's update has got, for the settings page"
update_news(e) = begin
  reads!(e, :updates)
  reads!(e, :update)
  get(e.nodes, :update_held, false) && return "Save your changes first. A page has changes that aren't in its file, and a restart would lose them."
  Update.says(Update.own())
end

"""
Do what the button on the settings page offers: look for a newer version, get
it, or restart to use it. A restart closes every window, and the new version
opens once it's in the app's place. It doesn't happen while a page has changes
that aren't saved.
"""
update_act!(e) = begin
  u = Update.own()
  if Update.action(u) === :restart && unsaved()
    e.nodes[:update_held] = true
    return rerun!(e, :update)
  end
  Update.act!(u)
  rerun!(e, :update)
  u.again && foreach(o -> (w = window_of(o); w === nothing || close(w)), copy(editors))
  nothing
end

"Give `e` the settings that were kept the last time one changed"
load_settings!(e) = begin
  isfile(settings_file()) || return e
  for line in eachline(settings_file())
    name, value = (split(line, '=', limit=2)..., "")[1:2]
    if name == "theme" && Symbol(value) in THEME_ORDER
      e.theme = Symbol(value)
    elseif name == "font" && !isempty(value)
      e.font = String(value)
    elseif name == "weight"
      w = tryparse(Int, value)
      w !== nothing && 0 < w <= HEAVIEST && (e.weight = w)
    elseif name == "zoom"
      z = tryparse(Float64, value)
      z === nothing || (e.zoom = clamp(z, 0.6, 2.5))
    elseif name == "width"
      w = tryparse(Float64, value)
      w === nothing || (e.widest = px(clamp(w, NARROWEST, WIDEST)))
    elseif name == "plain"
      e.plain = value == "true"
    elseif name == "spelling"
      e.spelling = value != "false"
    elseif name == "updates"
      e.updates = value != "false"
    elseif name == "autosave"
      e.autosave = value == "true"
    elseif name == "glide"
      e.glide = value != "false"
    elseif name == "peeks"
      e.peeks = value != "false"
    elseif name == "agent"
      value = agent_renamed(value)
      k = findfirst(k -> k.name == value, AGENT_KINDS)
      k === nothing || (e.ai = AGENT_KINDS[k].name)
    elseif name == "wrap"
      e.wrap = value != "false"
    elseif name == "numbers"
      e.numbers = value != "false"
    elseif name == "shade"
      e.shade = value == "true"
    elseif name == "beside"
      e.beside = value == "true"
    elseif name == "indent"
      n = tryparse(Int, value)
      n in INDENTS && (e.indent = n)
    elseif name == "code"
      c = tryparse(Float64, value)
      c === nothing || (e.code_scale = clamp(c, CODE_SCALES...))
    elseif name == "guide"
      n = tryparse(Int, value)
      n in GUIDES && (e.guide = n)
    elseif name == "codefont"
      # A font that's no longer on the Mac leaves code in the usual one
      installed_weight(value, 400) > 0 && (e.code_font = String(value))
    elseif name == "codeweight"
      w = tryparse(Int, value)
      w !== nothing && 0 < w <= HEAVIEST && (e.code_weight = w)
    elseif name == "sidebar"
      w = tryparse(Float64, value)
      w === nothing || (e.side = px(round(clamp(w, num(PANEL_MIN), num(PANEL_MAX)))))
    elseif name == "hidden"
      # The sidebar listed its folder before the settings were read
      (value == "true") == e.hidden || (e.hidden = !e.hidden; list_files!(e))
    elseif name == "right"
      e.right = value != "false"
    elseif name == "ownmessage"
      e.own = value == "true"
    elseif name == "pinned"
      e.pinned = value == "true"
    elseif name == "hidebar"
      # It was true or false before the bar could hide in full screen only
      how = value == "true" ? :always : value == "false" ? :never : Symbol(value)
      how in first.(BAR_HIDINGS) && (e.hide_bar = how)
    elseif name == "agentshidden"
      # The agents that you took out of the lists, with commas between their names
      AGENTS_HIDDEN[] = Set(n for n in agent_renamed.(split(value, ',')) if any(k -> k.name == n, AGENT_KINDS))
    elseif name == "models"
      # The model of each agent that you chose last, like Claude:sonnet, with commas between them. An agent that has another name now has other models.
      MODELS_CHOSEN[] = Dict(String(a) => String(m) for (a, m) in (split(pair, ':', limit=2) for pair in split(value, ',') if occursin(':', pair)) if !isempty(m) && !haskey(AGENTS_RENAMED, a))
    elseif name == "pagecard"
      # How wide you made the page's card of agent mode. Nothing after the = means it has a page's shape.
      w = tryparse(Float64, value)
      PAGE_CARD_CHOSEN[] = w === nothing ? nothing : px(round(max(w, num(PAGE_CARD_NARROWEST))))
    elseif startswith(name, "term.")
      # A setting of the terminal, like term.caret=bar
      read_term_setting!(chopprefix(name, "term."), value)
    elseif name == "keys"
      any(b -> first(b) == value, BUNDLES) && (e.bundle = String(value))
    elseif startswith(name, "key.")
      # The shortcuts of one command. A window that has these already gets a new set, not a change to the one it shares.
      command = Symbol(chopprefix(name, "key."))
      haskey(COMMANDS, command) && (e.rebound = merge(e.rebound, Dict(command => written(read_shortcuts(value)))))
    end
  end
  e
end

# --- what code from the startup page adds to -------------------------------------------
#
# Ladder is one program, and code that the startup page loads can add to it.
# That code has Ladder's module, so it calls Ladder's functions as Ladder's own
# files do. The tables here are for the other way: the things that Ladder
# does at its own times, and that such code can have a part in. Each table
# holds functions by a name that the code chooses, like `:email`. So code that
# is loaded twice puts its function in the same place twice, and Ladder calls
# it once.
#
#     Ladder.EACH_FRAME[:email] = e -> look_for_email(e)
#
# Ladder has no table for a kind of block, a command or a key, because it has
# those already: a kind of block goes in `BLOCKS`, `add_insert!` puts it in
# the Insert menu, and `add_commands!` adds commands, with their keys, to the
# ones that the key bindings page lists. `add_command!` makes a function a
# command that the command palette asks the arguments of. It has no table for a folder or a
# file either. Each is an object, and a kind of folder is a type, so code
# writes a method for the type: see `list_files!`.

"More names for the code of a window's pages: `f(m, e)` adds them to the module `m` that the code runs in"
const PAGE_NAMES = Dict{Symbol,Any}()
"A key that code takes while a field of a live block has the keyboard: `f(e, w, K)` is true when it took the key `K`"
const FIELD_KEYS = Dict{Symbol,Any}()
"More folders whose pages show in the settings window as pages of the settings, each by a name"
const SETTINGS_FOLDERS = Dict{Symbol,String}()

"""
Add a kind of block to the Insert menu of a page, before the item called
`before`, or at the end of the blocks. `lines` are what the item writes into
the page, and `caret` is the line of those and the column that the caret goes
to. An item with a name that the menu has takes that item's place.
"""
add_insert!(name::AbstractString, lines, caret; before="Link Card") = begin
  menu = last(PAGE_MENU[findfirst(x -> x isa Pair && first(x) == "Insert", PAGE_MENU)])
  item = (String(name), String.(lines), caret)
  i = findfirst(x -> x isa Tuple && x[1] == name, INSERTS)
  i === nothing || return (INSERTS[i] = item; nothing)
  i = something(findfirst(x -> x isa Tuple && x[1] == before, INSERTS), length(INSERTS))
  insert!(INSERTS, i, item)
  insert!(menu, i, String(name))
  nothing
end

"The buttons that code from the startup page adds to the top bar for the page that shows"
bar_parts(e) = Tuple(Iterators.flatten(f(e) for f in values(BAR_PARTS)))

"""
Add `commands` to Ladder's commands, in the group called `group` on the key
bindings page. Each is a `Command`: its name, what the page calls it, its
kind, its keys, and what it does. A command that has the name of one that's
there takes its place. `ADDED_COMMANDS` keeps them too, for a hot reload.
"""
add_commands!(group::AbstractString, commands) = begin
  put_commands!(COMMAND_GROUPS, group, commands)
  for c in commands
    COMMANDS[c.name] = c
    k = findfirst(((_, o),) -> o.name == c.name, ADDED_COMMANDS)
    k === nothing ? push!(ADDED_COMMANDS, String(group) => c) : (ADDED_COMMANDS[k] = String(group) => c)
  end
  nothing
end

# Reset Module gives the page's code a new module: see `reset_module!`
add_commands!("The text", [Command(:reset_module, "Run the page's Julia code in a new, empty module, without what it made before", :window, "",
                                   (e, w, _) -> reset_module!(e))])

# ⌘⇧V pastes a block that was copied from another page as its lines: see "a block that's copied pastes as a part of its page"
add_commands!("The text", [Command(:paste_copy, "Paste a block from another page as a copy of its lines, not as a part of that page", :edit, "cmd+shift+v",
                                   (e, w, _) -> paste_copy!(e))])

# ⌘⌥M puts a comment on the words that are selected: see "comments in the margin"
add_commands!("The text", [Command(:add_comment, "Put a comment on the words that are selected", :edit, "cmd+opt+m", (e, w, _) -> add_comment!(e))])

# ⌘T opens a new tab, and ⌘1 to ⌘9 show the tabs: see "the files that are open, as tabs"
const TAB_ORDINALS = ("first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth")
add_commands!("Files and windows", [
  Command(:new_tab, "Open a new tab, and find a file to show in it", :window, "cmd+t", (e, w, _) -> new_tab!(e)),
  (Command(Symbol(:tab_, n), "Show the $(TAB_ORDINALS[n]) tab", :window, "cmd+$n", (e, w, _) -> show_tab!(e, n)) for n in 1:9)...])

"The commands that show a tab, from ⌘1 to ⌘9"
const TabCommand = Union{(Val{Symbol(:tab_, n)} for n in 1:9)...}
"The palette lists the command that shows a tab only while the window has that tab"
works_here(e, ::V) where V<:TabCommand = length(tabs(top_editor(e))) >= parse(Int, String(V.parameters[1])[5:end])
works_here(e, ::Val{:new_tab}) = !issettings(top_editor(e))

# --- commands that are functions ----------------------------------------------------------
#
# `add_command!` makes a Julia function a command of the command palette. The
# palette asks for each thing that the function takes, by the argument's name
# and type, and calls the function with them. See "the command palette" for
# how a type is asked for, and how the methods of a function share its chips.
#
#     "Make the page's text `size` pixels tall"
#     text_size!(e, size::Real) = (e.zoom = zoom_for(size); rewrap!(e))
#     add_command!(text_size!)
#
# The command is called Text Size, and it asks for the size, a number. Its row
# says what the function's docstring starts with, or the `title` that
# `add_command!` is given. It has a place on the key bindings page, and its
# keys open the palette with the command taken.
#
# A function that takes a part of a page, a file or a kind of folder is a
# command only while one is in focus, and gets that one:
#
#     "Fetch what's new in a git folder"
#     fetch!(d::GitDirectory) = ...
#     add_command!(fetch!)
#
# See "what's in focus" in the section of the command palette.

"What the docstring of `f` starts with: its first sentence, without the marks round code and the full stop. With no docstring, it's \"\"."
first_words(f) = String(rstrip(replace(doc_sentence(parentmodule(f), nameof(f)), "`" => ""), '.'))

"""
Make the function `f` a command, in the group called `group` on the key
bindings page. `name` is the command's name, which the palette shows as
words: the function's own name, without a `!`. `title` says what it does:
the first line of the function's docstring. `kind` says where it works, and
`keys` are its shortcuts, as a `Command` has them.
"""
add_command!(f; name::Symbol=Symbol(rstrip(String(nameof(f)), '!')), title::AbstractString=first_words(f), kind::Symbol=:window,
             keys::AbstractString="", group::AbstractString="Commands that ask for something") =
  add_commands!(group, [Command(name, String(title), kind, String(keys), (e, w, _) -> open_palette!(e, COMMANDS[name]), f)])

"The colours of a page, for a command to take: Sepia, Paper or Night"
struct Colours
  name::Symbol
end
choices_for(::Type{Colours}, e) = [Colours(name) for name in THEME_ORDER]
chip_kind(::Type{Colours}) = :choice
worded(c::Colours) = uppercasefirst(String(c.name))
theme!(e, colours::Colours) = theme!(e, colours.name)

"A bundle of key bindings, for a command to take: Ladder's own keys, or the keys of another editor"
struct Bundle
  name::String
end
choices_for(::Type{Bundle}, e) = [Bundle(first(b)) for b in BUNDLES]
chip_kind(::Type{Bundle}) = :choice
worded(b::Bundle) = b.name
"Use the keys of a bundle"
key_bindings!(e, bundle::Bundle) = bundle!(e, bundle.name)

"An agent that Ladder can start, for a command to take: Claude, Antigravity, Codex or Grok. See \"the agents that Ladder can start\"."
struct AgentChoice
  name::String
end
choices_for(::Type{AgentChoice}, e) = AgentChoice.(listed_agents(e))
chip_kind(::Type{AgentChoice}) = :choice
worded(a::AgentChoice) = a.name
sidenote(a::AgentChoice) = try agent_path(agent_kind(a.name)); "" catch; "not installed" end
"""
Make `agent` the one that Ladder asks for a change or a question, as Settings
does. A page that an agent shares still asks that agent.
"""
switch_agent!(e, agent::AgentChoice) = preferred_agent!(e, agent.name)
runs_at_once(::Val{:switch_agent}) = true

"A kind of block that the Insert menu adds, for a command to take"
struct InsertKind
  name::String
end
choices_for(::Type{InsertKind}, e) = [InsertKind(x[1]) for x in INSERTS if x isa Tuple]
worded(k::InsertKind) = k.name
"Add a block of a kind to the page, where the caret is"
insert_block!(e, block::InsertKind) = begin
  e.buf.view == :markdown || error("Only a page of Markdown takes a block.")
  i = findfirst(x -> x isa Pair && first(x) == "Insert", PAGE_MENU)
  j = findfirst(x -> x isa Tuple && x[1] == block.name, INSERTS)
  j === nothing && error("The Insert menu has no $(block.name).")
  page_act!(e, i, j)
end

add_command!(go_to!, title="Go to a heading of the page, to a function or a section of a file of code, or to a line by its number", kind=:look)

add_command!(go_to_definition!, title="Go to where the name at the caret is defined", kind=:look)

add_command!(rename_in_code!, title="Give a name of the page's Julia code another name, wherever it means the same thing", kind=:edit)

add_command!(find_uses!, title="List each place that uses the name at the caret, and go to one", kind=:look)

add_command!(add_check!, title="Write a check of the call at the caret over its function, with the value that the call has now", kind=:edit)

add_command!(run_all!, title="Run all the code of the file from the top, and show what each piece comes to", kind=:edit)

add_command!(insert_block!, name=:insert, title="Add a block to the page: a table, a sheet, a chart and so on", kind=:edit)

add_command!(theme!, title="Use other colours for the page")

add_command!(text_size!, title="Make the page's text a number of pixels tall")

add_command!(key_bindings!, title="Use the keys of another editor")

add_command!(switch_agent!, title="Choose the agent that Ladder asks for a change or a question: Claude, Antigravity, Codex or Grok")

add_command!(spelling!, title="Turn the spelling check on or off")

# The command palette asks whether it's on or off. See "the start of a page in a link's card".
add_command!(peeks!, title="Turn on or off showing a page when you hold ⌘ over its link")

add_command!(word_count, title="Say how many words the page has, how many characters, and how long it takes to read", kind=:look)

add_command!(copy_link_to_block!, title="Copy a link that shows the block at the caret in another page, like ![[Ideas#^prices]]", kind=:edit)

# --- a page from a web server ----------------------------------------------------------------
#
# remote_page.jl has a page of Markdown from a web server: how Ladder gets it
# and shows it, the browser folder, ~/Browser, that keeps each page as a file,
# and the web address that each of its files keeps. sandbox.jl has the
# sandbox that the page's code runs in, and the agent that reads a package
# first. The commands of a page from the web are here, with the address that
# the list of commands shows for Navigate.

"""
The web address or the path of the Mac that's typed in the palette's list of
commands, when the list has Navigate to go there, or nothing. Navigate is then
the list's first row, and Return goes there at once. A path here starts with
/, ~ or file://, so that the name of a command is never one.
"""
palette_address(e, p::CommandPalette) = begin
  p.command === nothing || return nothing
  to = navigate_place(e, input(e).text, near=false)
  to !== nothing && any(c -> c.name == :navigate, p.listed) ? to : nothing
end

add_command!(navigate!, title="Go to a file or a folder, like ~/Desktop, or a web address, like example.com/notes.md: Markdown on the web shows here, and the rest in your browser", keys="cmd+l")
add_command!(reload_page!, title="Ask the server again for the page from the web that shows", kind=:look)
add_command!(open_in_browser!, title="Show the page from the web that shows in your browser", kind=:look)

# --- the commands of a file and of a folder --------------------------------------------------
#
# Each takes a file or a folder by its type, so it shows in the palette while
# one is in focus, and works on the nearest: the row of the sidebar that the
# arrows are on, or else the file that shows. A command of a folder works on
# the folder that holds that file.

# The name is typed where it shows: in the sidebar, or in the top bar when the sidebar doesn't list it
rename!(e, o::FSObject) = (path = path_of(o); rename!(e, path, at=e.panel && path in e.listed ? :sidebar : :title); nothing)
duplicate!(e, o::FSObject) = (duplicate!(e, path_of(o)); nothing)
trash!(e, o::FSObject) = (trash!(e, path_of(o)); nothing)
show_in_finder(o::FSObject) = show_in_finder(path_of(o))
"Copy the path of the file or the folder `o`, to paste it somewhere"
copy_path(o::FSObject) = (clipboard(path_of(o)); nothing)
new_page!(e, d::AbstractDirectory) = new_page!(e, path_of(d))
new_folder!(e, d::AbstractDirectory) = new_folder!(e, path_of(d))
new_terminal!(e, d::AbstractDirectory) = new_terminal!(e, path_of(d))

let group = "The file or the folder in focus"
  add_command!(rename!; group, title="Give the file or the folder another name")
  add_command!(duplicate!; group, title="Make a copy of the file or the folder beside it")
  add_command!(trash!; group, name=:move_to_trash, title="Move the file or the folder to the Trash")
  add_command!(show_in_finder; group, title="Show the file or the folder in the Finder")
  add_command!(copy_path; group, title="Copy the path of the file or the folder")
  add_command!(new_page!; group, title="Make a new page in the folder")
  add_command!(new_folder!; group, title="Make a new folder in the folder")
  # ⌘⇧T makes a terminal at once, in the folder of the file that shows
  add_command!(new_terminal!; group, title="Make a new terminal in the folder", keys="cmd+shift+t")
end

"""
True when the page that shows is an email that came or went, so that its
front matter shows as the top of an email: an .eml file, or a page whose front
matter `said` has who it's from, a date and a subject.
"""
email_shows(e, said) = begin
  b = e.buf
  b.view == :markdown && haskey(said, "date") && (Eml.isemail(b.path) || (haskey(said, "from") && haskey(said, "subject")))
end

# --- a page as an app -------------------------------------------------------------------------
#
# The command Show As App opens the page in a window that has only the page:
# no sidebar, no caret, and a top bar with nothing in it, which you drag to
# move the window. The page's blocks work as they do in any window, so a page
# with a board, a chart and a few sliders is a small tool that you leave open.
# What a block changes is written to the page's file at once, since the window
# has nothing that says a page isn't saved. No key changes the page's text
# there. The command, run in that window, makes it a window that changes the
# page again.

"True when the window of `e` shows its page as an app"
as_app(e) = get(e.nodes, :as_app, false) === true

"In each frame of a window that shows its page as an app: keep the caret away, and write what a block changed"
app_tick!(e) = begin
  as_app(e) || return nothing
  b = e.buf
  b.reading = true
  e.panel = false
  dirty(b) && writes(b) && save!(b)
  nothing
end

"Show the page as an app, in a window of its own: only the page, with no sidebar, no caret and nothing in the top bar. In that window, go back to a window that changes the page."
show_as_app!(e) = begin
  if as_app(e)
    delete!(e.nodes, :as_app)
    e.buf.reading = false
    redraw_in!(e, 0)
    return nothing
  end
  b = e.buf
  (b.view == :markdown && !isempty(b.path)) || error("Only a page of Markdown that's in a file shows as an app.")
  dirty(b) && writes(b) && save!(b)
  shown = build_editor(b.path)
  foreach(name -> setfield!(shown, name, getfield(e, name)), SHARED)
  shown.remember = false   # what this window sets, like a sidebar that's shut, isn't written to the settings
  shown.panel = false
  shown.nodes[:as_app] = true
  shown.buf.reading = true
  by = window_of(e)
  size, at = by === nothing ? (paper_window(screen_room(), 0px), (0px, 0px)) : ((by.size[1], by.size[2]), (by.position[1] + 30px, by.position[2] + 30px))
  shown.size = size
  show_window!(window!(shown, title=something(page_title(shown), splitext(basename(b.path))[1]), size=size, position=at), by)
  shown
end

add_command!(show_as_app!, title="Show the page as an app, in a window of its own: only its blocks, with no sidebar or caret, and nothing in the top bar", kind=:look)

# --- when a line last changed ---------------------------------------------------------------
#
# A click on the number of a line, in a file that git keeps, shows the commit
# that last changed the line: its day, who made it, its first line, and the
# lines that the file had there before. git is asked about the text as the
# window has it, so a line that you changed and didn't commit says so. The
# words stay until the next click, key or scroll. git answers in a later
# frame, so the window never waits for it.

"The line whose number the point `pos` of the window is on, or nothing: the page shows numbers, and the point is beside the text, on them"
number_at(e, pos) = begin
  (numbers(e) && !isempty(e.layout)) || return nothing
  x, y = pos
  left = e.origin[1] + sideways(e)   # the numbers stay at the left of a page that's scrolled sideways
  (left - gutter(e) <= x < left - NUMBER_GAP / 2 && y >= e.origin[2]) || return nothing
  locate(e, pos)[1]
end

"What's asked of git about a line, and what it said: the line, the process, the caret, version and scroll that the words stay for, and the commit with the lines before it"
@def mutable struct LineAsked
  line::Int = 0
  root::String = ""
  process::Any = nothing
  out::Any = nothing
  stays::Any = nothing
  found::Any = nothing     # a Git.Blamed once git has answered, or false when it has nothing to say
  before::Vector{String} = String[]
end

"Ask git which commit last changed line `i` of the page. True when git keeps the page, so there's something to ask."
line_history!(e, i::Int) = begin
  b = e.buf
  h = isempty(b.path) ? nothing : page_history(page_key(b.path))
  h === nothing && return false
  asked = try
    process, out = Git.blame(h.root, h.rel, i, join(b.lines, "\n"))
    LineAsked(line=i, root=h.root, process=process, out=out)
  catch
    return false
  end
  e.nodes[:line_asked] = asked
  redraw_in!(e, 0)
  true
end

"The day of a time in seconds, like 14 Nov 2026"
day_words(at::Real) = Dates.format(Dates.unix2datetime(at) + (Dates.now() - Dates.now(Dates.UTC)), "d u yyyy")

"What the window says of the commit that last changed a line. The line as it was has the colours of code in `lang`, like julia, and `open` is the quote of a docstring that's open at its start, or '\\0'."
history_words(a::LineAsked, lang="", open='\0') = begin
  c = a.found
  c === false && return Box(padding(10px, 7px), label("git has nothing on this line.", 12px, color=TIP_INK))
  isempty(c.hash) && return Box(padding(10px, 7px), label("Changed since the last commit.", 12px, color=TIP_INK))
  said(text; family=SANS, color=TIP_INK) = Text(length(text) > 90 ? first(text, 89) * "…" : text, size=12px, family=family, color=color, wrap=WrapMode.none)
  rows = Any[said("$(day_words(c.at))  ·  $(c.who)  ·  $(first(c.hash, 7))", color=RGBA(TIP_INK.r, TIP_INK.g, TIP_INK.b, 0.65)), said(c.words)]
  if isempty(a.before)
    push!(rows, said("This commit added the line.", color=RGBA(TIP_INK.r, TIP_INK.g, TIP_INK.b, 0.65)))
  else
    push!(rows, said("Before:", color=RGBA(TIP_INK.r, TIP_INK.g, TIP_INK.b, 0.65)))
    append!(rows, tip_code([length(l) > 90 ? first(l, 89) * "…" : l for l in first(a.before, 6)], lang; open))
    length(a.before) > 6 && push!(rows, said("and $(length(a.before) - 6) more", color=RGBA(TIP_INK.r, TIP_INK.g, TIP_INK.b, 0.65)))
  end
  Box(padding(10px, 8px), Column(Alignment.Start, child_gap=3px, [Box(r) for r in rows]...))
end

"In each frame: read what git said about a line, show it beside the line's number, and take it away after the next click, key or scroll"
line_tick!(e) = begin
  a = get(e.nodes, :line_asked, nothing)
  a isa LineAsked || return nothing
  w, b = window_of(e), e.buf
  if a.found === nothing
    yield()   # git's end is noticed by a task, which gets its turn here
    process_exited(a.process) || return (redraw_in!(e, 0.05); nothing)
    found = Git.read_blame(String(take!(a.out)))
    a.found = something(found, false)
    found === nothing || isempty(found.hash) || (a.before = try Git.before(a.root, found) catch; String[] end)
    a.stays = (b.path, b.version, b.caret, e.scroll.offset)
  end
  if w === nothing || a.stays != (b.path, b.version, b.caret, e.scroll.offset) || !(1 <= a.line <= length(e.layout))
    w === nothing || close_popup!(w, :line_asked)
    delete!(e.nodes, :line_asked)
    return nothing
  end
  it = item(e, a.line)
  spot = (e.origin[1] + sideways(e) - gutter(e), e.origin[2] + it.top, gutter(e) - NUMBER_GAP / 2, it.content isa Flow ? it.content.lines[1].high : it.tall)
  # The words look as a tooltip does. They stay while the mouse moves, which a tooltip doesn't.
  l = kinds(b)[a.line]
  lang = l.kind == Kind.code ? shared_lang(l.lang) : ""
  # The line as it was is taken to start inside a docstring when the line as it is does
  popup!(w, Bubble(content=history_words(a, lang, string_opens(b)[a.line]), target=spot), anchor=spot, placement=:bottom, gap=4px, key=:line_asked, input=false)
  nothing
end

add_command!(agent_mode!, title="Show an agent's session at the left of the page and the page's outline at its right, in a wider window. Again puts the window back.")

add_command!(end_agent_session!, title="End the session of agent mode. Your next words there start a new one.")

# ⌘⇧A starts a session at once, in the folder of the file that shows
add_command!(new_agent_session!; group="The file or the folder in focus", title="Start a session with your agent in the folder, shown as a page", keys="cmd+shift+a")

add_command!(ask_agent!, title="Ask an agent for a change to a block of code or a part of the window, or a question about it, in your own words")

add_command!(show_change!, title="Show each change that an agent made, the newest first, and reject any part of one")

add_command!(undo_change!, title="Put back the files that an agent changed last, as they were before")

add_command!(show_code!, title="Show the code that draws a part of the window, or a block of Julia code")

add_command!(keep_change!, name=:keep_this_change, title="Keep the function at the caret for each time that Ladder starts: a change to Ladder's own code")

add_command!(stop_agent!, title="Stop the agent that's working now. What it changed so far stays, for Undo Change")

add_command!(fix_check!, title="Ask an agent to make a check of the file pass, by changing the function under it", kind=:edit)

add_command!(ask_for_checks!, title="Ask an agent to write checks of a function, with the values that it should give")

add_command!(show_steps!, title="Run a check of the file again, and show what each line of the function that it calls came to", kind=:look)

# --- a folder's own page ----------------------------------------------------------------
#
# folder_kinds.jl has what kind a folder is: a folder's own page, `.ladder`,
# on the Mac and on a web server, whether you trust a site to run the code of
# its pages, the kinds that Ladder finds by itself, and Show Folder As. The
# commands of trust are here.

add_command!(trust_site!, title="Trust this page's site: the code of its pages runs with no sandbox, and its .ladder pages change how they show", kind=:look)
add_command!(stop_trusting_site!, title="Stop trusting this page's site: the code of its pages runs in the sandbox again", kind=:look)

# --- the browser folder's favourite sites ----------------------------------------------------
#
# The browser folder shows as a desktop of your favourite sites: see
# desktop_page.jl. These commands put the page from the web that shows on it,
# or take it off.

add_command!(add_to_favourites!, title="Put the page from the web that shows on the browser folder's desktop of favourite sites", kind=:look)

add_command!(remove_from_favourites!, title="Take the page from the web that shows off the browser folder's desktop of favourite sites", kind=:look)

# --- the panel at the right, and git's commands ------------------------------------------
#
# The button that shows or hides the panel at the right, and the commands of
# git's panel, which git_page.jl has.

BUTTONS[:right_panel] = (run=toggle_right!, tip=e -> (e.right ? "Hide " : "Show ") * (agent_shows(e) ? "the outline" : side_name(e, page_object(e))),
                         off=e -> false, strong=false, on=e -> e.right)

add_command!(toggle_right!, name=:right_panel, title="Show or hide the panel at the right of the page, like git's panel beside a repository's files")

add_command!(push_branch!, name=:push, title="Send the branch's new commits to the branch that it follows, like origin/main")

add_command!(pull_branch!, name=:pull, title="Bring the new commits of the branch that this one follows, like origin/main")

add_command!(merge_branch!, name=:merge, title="Pull the commits of the branch that this one follows, and join the two branches with a new commit")

add_command!(rebase_branch!, name=:rebase, title="Pull the commits of the branch that this one follows, and make this branch's own commits again after them")

add_command!(commit_file!, name=:commit, title="Commit the file to its git repository, with words that say what changed")

# --- the conversation writes the message of a commit ---
#
# In agent mode, once you have talked with the agent beside the page, the
# Commit button asks that agent for the commit's message in the
# conversation, as it knows why the page changed. See "an agent writes the
# commit's message" in git_page.jl, and `commit_talk` and `ask_talk!` in
# agent/pane.jl.

"Who writes the message of a commit from the Commit button of `e`, in words that go after what it commits"
message_by(e) = e.own ? ", with a message that you write" :
  (p = commit_talk(e); p === nothing ? ", with a message that $(e.ai) writes" : ", with a message that $(p.session.agent) writes in the conversation")

# A click commits the file with a message that the agent of the conversation beside the page writes, or else the
# agent that Settings chose, or that you write when the setting says so. While ticked changes are chosen, it commits only those.
BUTTONS[:commit] = (run=e -> commit_scope!(e, choosing(e) ? :part : :file), off=e -> choosing(e) && isempty(ticked(e)), strong=false,
                    busy=e -> haskey(e.nodes, :writing),
                    tip=e -> haskey(e.nodes, :writing) ? "$(e.nodes[:writing].who) is writing the commit message…" :
                             (!choosing(e) ? "Commit $(basename(e.buf.path))" :
                              (n = length(ticked(e)); n == 0 ? "Tick the changes to commit" : n == 1 ? "Commit the ticked change" : "Commit the $n ticked changes")) *
                             (choosing(e) && isempty(ticked(e)) ? "" : message_by(e)))

add_command!(commit_all_files!, name=:commit_all, title="Commit every changed file of the repository, with words that say what changed")

add_command!(commit_staged_files!, name=:commit_staged, title="Commit the files that are ticked in git's panel, with words that say what changed")

add_command!(commit_ticked!, name=:commit_ticked, title="Commit the ticked changes of the file, with words that say what they change")

BUTTONS[:diff] = (run=toggle_diff!, off=e -> false, strong=false, on=diffing,
                  tip=e -> (diffing(e) ? "Hide what changed in " : "Show what changed in ") * basename(e.buf.path) * " since the last commit")

add_command!(toggle_diff!, name=:show_changes_in_place, title="Show or hide what changed in the file since the last commit, in the file itself")

add_command!(next_change!, title="Go to the next change in the file since the last commit, after the caret")

add_command!(previous_change!, title="Go to the change in the file since the last commit before the caret")

# --- the home folder, and favourite folders ---------------------------------------------------
#
# The home folder is a folder like any other: its page is the table of what's
# in it. ⌘⇧H opens it, as it opens the home folder in the Finder.
#
# A favourite is a folder that you go to often. The folder's menu in the
# sidebar has Add to Favourites, and Remove from Favourites once it's one. The
# palette's command Go To Favourite opens one from any page. folders.jl keeps
# the list.

"Open the home folder in the page. The sidebar lists the home folder, and a sidebar that's hidden stays hidden."
go_home!(e) = open_folder!(e, home_folder())

add_command!(go_to_favourite!, title="Go to one of the folders that you made a favourite")

let group = "The file or the folder in focus"
  add_command!(add_to_favourites!; group, title="Make the folder a favourite, so Go To Favourite goes to it")
  add_command!(remove_from_favourites!; group, title="Take the folder off the favourites, so Go To Favourite doesn't list it")
end

# --- a kind for a folder, in one step ---------------------------------------------------
#
# Show Folder As is in folder_kinds.jl. Its command is here.

add_command!(show_folder_as!, title="Show a folder as a kind of folder: a desktop, notes, or a kind from GitHub")

# --- a folder of news --------------------------------------------------------------------------
#
# news_page.jl has the folder of news: a newspaper that agents write for you,
# with its front page, its feeds, the reading companion and an article. Its
# commands are here.

add_command!(show_interests!, title="Show the page that says the news that you want, of the folder of news that shows: Interests.md")
add_command!(show_feeds!, title="Show the page that lists the RSS and Atom feeds of the folder of news that shows: Feeds.md")
add_command!(open_news!, title="Show your newspaper: the folder News in your home folder, where agents write the news that you ask for")
add_command!(get_the_news!, title="Get the news of the folder of news that shows, now: the posts of its feeds, and the news of each section from Ladder's agent")

# --- the startup page ------------------------------------------------------------------
#
# Ladder has one page that's yours from the start: the startup page. It does
# two things.
#
#   - It's the page that shows the first time you open Ladder, and when
#     Ladder can't open where you were when you last quit it: see "where
#     Ladder opens". So it's the place for links to your pages and a list of
#     what's to do.
#   - Each time Ladder starts, it runs the Julia code of the page: each
#     `julia` block, from the top, in one module. Julia does the same with
#     its startup.jl. So the page is where you load code that adds to Ladder,
#     and it can say in words what each piece of code is for.
#
# The code has what a Julia file that Kip loads has, like `@use`, and one name
# more: `Ladder`, which is this module. Code that adds to Ladder calls
# Ladder's own functions and adds to its tables, as Ladder's own files do.
# There's no other layer between the two. The part before this one has the
# tables for what Ladder does at its own times.
#
# The page is `startup.md`, in the folder of the pages of the settings, since
# it's where you set what Ladder is. The Settings page has a link to it. The
# first time Ladder starts, it writes the page, with links to the welcome page
# and to the settings. From then on the page is yours, and Ladder never writes
# to it: it isn't one of the pages that a newer Ladder brings, and git leaves
# it out of Ladder's own repository. Only the command Keep This Change adds to
# it, when you run it: see "ask for a change to a thing".
#
# Code that fails stops the code after it, and Ladder opens all the same. The
# window then says which line of the page failed, in a toast that stays until
# you close it: see "toasts".

"A folder for the startup page that isn't the folder of the settings. A test names a folder of its own here."
const STARTUP_FOLDER = Ref("")

"The page that Ladder opens when no file is named and it has no place to open from the last time (see `take_place!`), and whose Julia code it runs when it starts"
startup_page() = isempty(STARTUP_FOLDER[]) ? settings_page("startup.md") : joinpath(STARTUP_FOLDER[], "startup.md")

"What the startup page says the first time, before you change it. Its links go from the folder of the settings."
startup_text() = """
  # Home

  Ladder opens this page the first time it starts, and when the place where you last were is gone. The page is yours, so change it as you like.

  - [Welcome](../welcome.md) shows what Ladder can do.
  - [Settings](settings.md) has the colours, the font and the keys. ⌘, opens it too.

  ## Code that runs when Ladder starts

  Each time Ladder starts, it runs the Julia code on this page, from the top. Code here can add to Ladder: the name `Ladder` is Ladder itself. The block below does nothing yet.

  ```julia
  # @use "github.com/you/something" => Something
  # Something.start(Ladder)
  ```
  """

"Write the startup page, if there's none. It gives the page's path."
startup_page!() = begin
  path = startup_page()
  if !isfile(path)
    mkpath(dirname(path))
    write(path, startup_text())
  end
  path
end

"What failed in the code of the startup page when Ladder started, or \"\", and when Ladder started"
const STARTUP = Ref(("", 0.0))
const STARTUP_SHOWS = 12.0   # seconds that the window says what a command of the page gave back

"""
A new module for the code of the startup page, or of a folder's page, at
`path`. It has what a Julia file that Kip loads has, like `@use`, and the
name `Ladder`, which is this module. Its name is the page's path.
"""
code_module(path::AbstractString) = begin
  m = Module(page_module_name(path))
  Core.eval(m, :(const Kip = $Kip))
  Core.eval(m, :(using .Kip))
  Core.eval(m, :(eval(x) = Core.eval($m, x)))
  Core.eval(m, :(include(file) = Base.include($m, file)))
  Core.eval(m, :(const Ladder = $(@__MODULE__)))
  m
end

"""
A new module for the code of the startup page, or of a folder's page, at
`path`, for Ladder to run the page in now. It's the page's module from now on,
so code that you run on the page in a window runs where Ladder ran it: what
the startup page loaded, like `Mail`, is there.
"""
code_module!(path::AbstractString) = (PAGE_MODULES[page_key(path)] = code_module(path))

"True when Ladder runs the code of the page at `path` itself: the startup page, and a folder's page"
ladder_runs(path::AbstractString) = basename(path) == FOLDER_PAGE || page_key(path) == page_key(startup_page())

"""
Run the code of the startup page: each of its `julia` blocks, from the top, in
one module, which this gives. In that module `Ladder` is this module. Code
that fails stops the code after it, and `STARTUP[]` then says what failed.
"""
run_startup!(path=startup_page()) = begin
  m = code_module!(path)
  STARTUP[] = try
    isfile(path) && Base.invokelatest(run_page!, m, path)
    ("", time())
  catch err
    (trouble(err), time())
  end
  # A window says so with a toast, which stays until it's closed: the code runs before the first window opens
  words = STARTUP[][1]
  isempty(words) ? untoast!(:startup) : toast!(:startup, "The startup page stopped", words)
  m
end

# --- a page's own commands ---
#
# A function that a page's own Julia code makes is a command of the palette
# while the page shows, once the page's code has run. Its arguments are its
# chips, as they are for a command of Ladder's own, so it needs a type for
# each that the palette can ask for, like `invoice(client::String,
# hours::Number)`. Its documentation says what it does. What it gives back
# shows under the top bar for a while.

"""
The functions that the Julia code of the page that `e` shows made, as
commands. The page's code must have run, so its module has them.
"""
page_commands(e) = begin
  b = e.buf
  (b.view == :markdown && !isempty(b.path)) || return Command[]
  m = get(PAGE_MODULES, page_key(b.path), nothing)
  m === nothing && return Command[]
  out = Command[]
  for made in page_bounds(e)
    made.span === nothing || continue
    name = Symbol(made.name)
    any(c -> c.name == name, out) && continue
    f = Base.invokelatest(isdefined, m, name) ? Base.invokelatest(getglobal, m, name) : nothing
    (f isa Function && parentmodule(f) === m) || continue
    # A function whose arguments the palette can't ask for, like one with no types, isn't a command
    isempty(callable_methods(f, in_focus(e))) && continue
    title = try first_words(f) catch; "" end
    c = Ref{Command}()
    c[] = Command(name, isempty(title) ? "A function of this page" : title, :page, "", (e, w, _) -> open_palette!(e, c[]), f)
    push!(out, c[])
  end
  out
end

"Say what a command of the page gave back, under the top bar, for a while"
result_tick!(e) = (r = get(e.nodes, :result, nothing); r === nothing || stopped_tick!(e, :result, r...))

"Show the toasts that say what failed in the code of the startup page or of a folder's page, and what a command of the page gave back"
startup_tick!(e) = (toasts_tick!(e); result_tick!(e))

"Say `words` under the top bar for a while after the time `since`. `key` names what failed, and \"\" says nothing."
stopped_tick!(e, key::Symbol, words, since) = begin
  win = window_of(e)
  (isempty(words) || win === nothing || get(e.nodes, (key, :told), 0.0) == since) && return
  left = STARTUP_SHOWS - (time() - since)
  if left <= 0
    close_popup!(win, key)
    e.nodes[(key, :told)] = since
  else
    # The words look as a tooltip does, under the middle of the top bar
    wide, _ = window_size(e)
    spot = (wide / 2, 0px, 1px, max(bar_bottom(e) - 8px, 0px))
    popup!(win, Bubble(content=Box(padding(8px, 5px), label(words, 12px, color=TIP_INK)), target=spot),
           anchor=spot, placement=:bottom, gap=6px, key=key, input=false)
    redraw_in!(e, left)
  end
  nothing
end

# --- toasts ---------------------------------------------------------------------------
#
# Code that Ladder runs by itself, the startup page's and a folder's own page's,
# has no window of its own to say that it failed in, and it can fail before a
# window opens. So each window says so with a toast: a card at its bottom
# right, in the colours of the toast that Centient shows for an error. It says
# what stopped and why, as Julia says it.
#
# A toast stays until you close it with its ×, or until the same page runs
# again with nothing wrong. Every window shows the same toasts, so a toast
# that's closed in one window is closed in all of them.

"The toasts that each window shows, the oldest first: what each is about (`key`), what stopped (`title`) and why (`words`)"
const TOASTS = NamedTuple{(:key, :title, :words),Tuple{Any,String,String}}[]

"How wide a toast is: wider than Centient's, which are 360px, so that a line of code that Julia quotes fits"
const TOAST_W = 480px
"How far a toast is from the window's right and bottom edges"
const TOAST_EDGE = 16px
"The most lines of what went wrong that a toast shows"
const TOAST_LINES = 8
"The colours of a toast for an error on a light page and on a dark one, which are Centient's"
const TOAST_LIGHT = (bg=colorant"#fee2e2", line=colorant"#dc2626", ink=colorant"#991b1b", hover=RGBA(0.6, 0.106, 0.106, 0.1))
const TOAST_DARK = (bg=colorant"#341a1d", line=colorant"#f87171", ink=colorant"#fca5a5", hover=RGBA(0.988, 0.647, 0.647, 0.12))

"Show a toast in each window that says `title`, and why in `words`. It takes the place of the toast about the same `key`."
toast!(key, title::AbstractString, words::AbstractString) = begin
  filter!(it -> it.key != key, TOASTS)
  push!(TOASTS, (key=key, title=String(title), words=String(words)))
  foreach(e -> redraw_in!(e, 0), editors)
  nothing
end

"Close the toast about `key` in every window, if there's one"
untoast!(key) = begin
  any(it -> it.key == key, TOASTS) || return nothing
  filter!(it -> it.key != key, TOASTS)
  foreach(e -> redraw_in!(e, 0), editors)
  nothing
end

"The toasts of a window, a card for each, one over the other at the bottom right"
@def mutable struct Toasts <: SemanticUI
  closes::Dict{Any,Any} = Dict{Any,Any}()   # the × of each toast, by its key
end

"The × of the toast about `key`, which closes it"
@def mutable struct ToastClose <: SemanticUI
  key::Any = nothing
end

"The colours of a toast on the page that shows"
toast_colours() = dark_page() ? TOAST_DARK : TOAST_LIGHT

"""
The lines that a toast shows of what went wrong, each with whether it wraps:
as many as fit, and … for the rest. A file in the home folder starts with ~,
and the words that say only where Julia was, `LoadError:` and `in expression
starting at`, go, as does the ⭒ of the name of a page's module, which the font
of code doesn't have. The lines of code that Julia quotes after `# Error @` don't
wrap, so that the mark under the place that's wrong stays under it. When the
mark is further in than `room` characters, each of those lines starts further
in, after …, so that the place shows.
"""
toast_lines(words, room=typemax(Int)) = begin
  out = Tuple{String,Bool}[]
  code = false
  for line in split(rstrip(replace(words, homedir() => "~", "LoadError: " => "", "⭒" => "")), '\n')
    startswith(line, "in expression starting at") && continue
    push!(out, (String(rstrip(line)), !code || startswith(line, "# Error @")))
    startswith(line, "# Error @") ? (code = true) : (code && startswith(line, '#') && (code = false))
  end
  mark = findfirst(((s, wraps),) -> !wraps && startswith(s, '#') && '╙' in s, out)
  if mark !== nothing
    at = length(out[mark][1], 1, findfirst('╙', out[mark][1]))
    if at > room - 8
      cut = at - room ÷ 2
      out = [wraps ? (s, wraps) : (length(s) > cut ? "…" * s[nextind(s, 0, cut + 1):end] : "", wraps) for (s, wraps) in out]
    end
  end
  length(out) > TOAST_LINES ? [first(out, TOAST_LINES); ("…", true)] : out
end

describe(t::Toasts) = begin
  c = toast_colours()
  filter!(((key, _),) -> any(it -> it.key == key, TOASTS), t.closes)
  cards = map(TOASTS) do it
    x = get!(() -> own!(t, ToastClose(key=it.key)), t.closes, it.key)
    face = Face(codefont(), codestyle(), 12px, c.ink, false)
    room = floor(Int, num(TOAST_W - 24px) / num(measure(face, "0")))   # how many characters of code fit across the toast
    lines = [Box(width(grow=grow), Alignment.Start, Text(line, size=12px, family=codefont(), subfamily=codestyle(), color=c.ink,
                                                         wrap=wraps ? WrapMode.words : WrapMode.none))
             for (line, wraps) in toast_lines(it.words, room)]
    Box(width(TOAST_W), padding(14px, 12px, 12px, 12px), radius(12px), border(1px, :solid, c.line), background(c.bg), lifted,
      Column(width(grow=grow), Alignment.Start, child_gap=6px,
        # A Box of its own keeps the title from taking half of the row
        Row(width(grow=grow), Alignment.Center, child_gap=8px, Box(width(grow=grow), Alignment.Start, omni_label(it.title, 15, c.ink, weight="SemiBold")), x),
        # A line that's too long for the toast goes past its right edge, out of sight
        Box(width(grow=grow), Alignment.Start, clip_x=true, Column(width(grow=grow), Alignment.Start, child_gap=6px, lines...))))
  end
  Column(width(grow=grow), Alignment.End, child_gap=8px, name="Toasts", cards...)
end

describe(x::ToastClose) = (c = toast_colours();
  Box(fixed(20px), radius(10px), Alignment.Center, background(ishovered(x) ? c.hover : clear), Icon("x-lg", size=12px, color=c.ink)))
cursor(::ToastClose) = :hand
onmouse(::ToastClose, ::MouseMove) = handled
onkey(x::ToastClose, ::KeyPress{Keys.mouse_left}) = (untoast!(x.key); handled)

"""
Show the toasts at the bottom right of the window of `e`, or none when there
are none. While the palette of commands shows, they're over its bar.
"""
toasts_tick!(e) = begin
  win = window_of(e)
  win === nothing && return
  isempty(TOASTS) && return close_popup!(win, :toasts)
  wide, high = window_size(e)
  bottom = high - TOAST_EDGE
  e.popup == :commands && (bottom = min(bottom, px(palette_plan(e, palette(e)).band.y) - TOAST_EDGE))
  t = node!(Toasts, e, :toasts)
  # Under the toasts the mouse is theirs, and anywhere else it's the window's: a click elsewhere leaves them
  popup!(win, t, anchor=(wide - TOAST_EDGE - TOAST_W, bottom, TOAST_W, 0px), placement=:top, width=TOAST_W, key=:toasts, modal=false)
  nothing
end

"""
Open an editor window and run it until it closes. `args` can name a Markdown
file or a folder, and `--paper` or `--night` to choose the colours for this
window. With no file, the window shows where Ladder was when it last quit, or
else the startup page: see "where Ladder opens".
"""
open_editor(args) = begin
  move_old_folders!()
  # macOS can pass its own -options to an app it opens, so skip anything with a dash
  paths = filter(a -> !startswith(a, "-"), args)
  Agent.announce()   # an agent's script knows from now on that this Ladder can send it a page
  home = startup_page!()
  Folders.page!()   # the page that lists what you ignore, which the Settings page links to
  run_startup!(home)
  was = isempty(paths) ? take_place!() : nothing
  # The code of the startup page can have made methods since this function started, like those of a kind of folder
  e = was === nothing ? build_editor(isempty(paths) ? home : paths[1]) : Base.invokelatest(place_editor, was)
  load_settings!(e)
  "--night" in args && (e.theme = :night)
  "--paper" in args && (e.theme = :paper)
  e.remember = true
  e.size = paper_window(screen_room(), e.side)
  w = window!(e, title="Ladder", size=e.size)
  was === nothing || put_place!(e, was)
  # This returns when the last window has closed. The window is drawn with the methods of the startup page's code too.
  Base.invokelatest(display, w)
  keep_place!(quit_editor(e))
  # What code from the startup page does last, like the end of a look for email
  foreach(f -> Base.invokelatest(f), values(AT_QUIT))
  # Each extension moves up to the new code that Ladder fetched, which loads the next time that Ladder opens
  x = Update.extensions()
  Update.quit!(x)
  # After Restart Ladder, the program that puts a newer version of the app in its place opens it again too
  x.again && (Update.own().again = true)
  # A newer version of the app that's ready takes the app's place once Ladder has quit
  Update.quit!(Update.own()) || Update.reopen!(x)
end

# --- where Ladder opens --------------------------------------------------------------------
#
# Ladder opens where you were when you last quit it: the file or the folder
# that the front window showed, with the caret and the scroll where they were.
# The tabs of the files that were open in it are open again, but for those
# whose files have gone. The sidebar lists the folder that it listed then, and
# it stays closed until you open it. A window whose file and folder ⌘W closed was at the folder that
# its sidebar listed. The settings window doesn't count: Ladder opens where
# the last window in front of the others was.
#
# Ladder reads the place when it opens, deletes it, and writes it again when it
# quits. So a page that stops Ladder before it quits isn't where Ladder opens
# the next time, and the startup page shows. The startup page shows too the
# first time, and when the file or the folder has gone. A file that's named on
# the command line, as in `julia main.jl notes.md`, shows in the place's
# stead, and Ladder keeps the place for the next time. A file that macOS opens
# Ladder with, after a double-click in the Finder or the `ladder` command,
# shows after the place, so ⌘⌥← goes back to the place.

"The file that keeps where Ladder was when it last quit. A test names a file of its own here."
const PLACE_FILE = Ref(joinpath(homedir(), "Library", "Application Support", "Ladder", "place"))

"The last window that was in front, of the windows that aren't the settings window, or nothing"
const LAST_FRONT = Ref{Any}(nothing)

"""
Where the window of `e` is, for the next time Ladder opens: the file or the
folder that its page shows, the folder that its sidebar lists, its caret, its
anchor, how far it's scrolled and the files of its tabs. A window that shows no file is at the folder
that its sidebar lists. It's nothing when that's nowhere on the Mac.
"""
quit_place(e) = begin
  p = place_now(e)
  path = isempty(p.path) ? e.folder : p.path
  ispath(path) || return nothing
  (; p..., path, folder=e.folder, tabs=filter(ispath, tabs(e)))
end

"Write where the window of `e` is into the place file, for the next time Ladder opens. A place that's nowhere leaves the file as it was."
keep_place!(e) = begin
  p = quit_place(e)
  p === nothing && return nothing
  try
    mkpath(dirname(PLACE_FILE[]))
    write(PLACE_FILE[], "path=$(p.path)\nfolder=$(p.folder)\ncaret=$(p.caret[1]),$(p.caret[2])\nanchor=$(p.anchor[1]),$(p.anchor[2])\noffset=$(p.offset.value)\n" *
                        join("tab=$t\n" for t in p.tabs))
  catch
    # A file that can't be written only means that Ladder opens on the startup page
  end
  nothing
end

"""
Where Ladder was when it last quit, as `quit_place` gives it, or nothing when
there's no place or it has gone from the Mac. It deletes the place file, which
`keep_place!` writes again when Ladder quits.
"""
take_place!() = begin
  file = PLACE_FILE[]
  isfile(file) || return nothing
  kept = Dict{String,String}()
  tabbed = String[]   # a line for each tab
  for line in eachline(file)
    i = findfirst('=', line)
    i === nothing && continue
    line[1:i-1] == "tab" ? push!(tabbed, line[i+1:end]) : (kept[line[1:i-1]] = line[i+1:end])
  end
  rm(file, force=true)
  path = get(kept, "path", "")
  # A folder that the Finder shows as one file, like an app, would open in its own app
  (ispath(path) && !(isdir(path) && ispackage(path))) || return nothing
  pair(s) = (m = match(r"^(\d+),(\d+)$", s); m === nothing ? (1, 0) : (parse(Int, m[1]), parse(Int, m[2])))
  (path=path, folder=get(kept, "folder", ""), caret=pair(get(kept, "caret", "")), anchor=pair(get(kept, "anchor", "")),
   offset=px(something(tryparse(Float64, get(kept, "offset", "")), 0.0)), tabs=filter(p -> isfile(p) || news_tab(p), tabbed))
end

"An editor at the place `p` that `take_place!` gave: its file, or its folder in the page, its tabs, and the folder that its sidebar listed"
place_editor(p) = begin
  e = blank_editor()
  append!(tabs(e), p.tabs)   # the file of the place has a tab among them, or gets one at the bottom
  isdir(p.path) ? open_folder!(e, p.path) : open!(e, p.path)
  isdir(p.folder) && e.folder != p.folder && go_folder!(e, p.folder)
  e
end

"Put the caret and the scroll of the window of `e` where they were at the place `p`, when it's a file that shows"
put_place!(e, p) = (e.buf.path == p.path && !isdir(p.path) && go_place!(e, p); e)

"The window whose place Ladder keeps when it quits: the last one that was in front, of those that aren't the settings window, or else `first`"
quit_editor(first) = (f = LAST_FRONT[]; f isa Editor ? f : first)

# The close, minimise and zoom buttons line up with the sidebar's button, in the middle of the top bar
onopen(e::Editor, w::Window) = (watch_front!(e, w); watch_close!(e, w); place_window_buttons!(hide_titlebar!(w), TOPBAR_H / 2, TOPBAR_H / 2))

# --- saving a page when you leave its window ------------------------------------------------
#
# Ladder writes a page to its file when you press ⌘S, and at no other time.
# A setting changes that: with it on, a window writes its pages when it stops
# being the front window. That's when you click another window, change to
# another app, or hide Ladder. A page with no file has nowhere to go, so it
# stays as it is.

"Turn on or off whether a page is written to its file when its window stops being the front window"
autosave!(e, on::Bool) = (e.autosave = on; save_settings!(e); rerun!(e, :autosave); e)
# The command palette has it as a command, which asks whether it's on or off
add_command!(autosave!, title="Turn on or off saving a page when you leave its window")

"""
The window of `e` stopped being the front window. With the setting on, each
page of the window that has changes is written to its file.
"""
left!(e) = begin
  e.autosave || return e
  write_blocks!(e)   # a block's own changes count as changes to the page
  dirty(e.buf) && writes(e.buf) && save_page!(e)   # a page from a web server keeps its changes in the window
  foreach(b -> b === e.buf || !dirty(b) || save!(b), values(e.buffers))
  redraw_in!(e, 0)   # the top bar no longer says that the page has changes
  e
end

"Have macOS tell `e` when its window `w` comes to the front, and when it stops being the front window. A window that isn't on the screen is never the front one."
watch_front!(e, w) = begin
  isempty(w.glfw) && return w
  GLFW.SetWindowFocusCallback(w.glfw[1], (_, front) -> begin
    # A name of a page's module that acts on a window acts on the front one, when it shows the page
    front && (FRONT_WINDOW[] = e; e.settings || (LAST_FRONT[] = e); return)
    try
      Base.invokelatest(left!, e)
    catch
      # A page that can't be written stays as it is, with its changes, for ⌘S to try
    end
    nothing
  end)
  w
end

const PAGE_AREA_W = 850px   # the width of the page's part of a new window: room for the page at the width it starts with, and the space beside it

"How tall the part of the main screen is that a window can use, under the menu bar and over the Dock"
screen_room() = begin
  if Sys.isapple() && Sys.ARCH == :aarch64
    # macOS gives the rectangle as four numbers: where it starts, how wide it is and how tall
    frame = with_pool() do
      screen = msg(cls("NSScreen"), "mainScreen")
      screen == C_NULL ? nothing : ccall((:objc_msgSend, libobjc), NTuple{4,Float64}, (Ptr{Cvoid}, Ptr{Cvoid}), screen, sel("visibleFrame"))
    end
    frame === nothing || return px(frame[4])
  end
  # Anywhere else, leave room for a menu bar and a Dock of the usual size
  Screen().size[2] - 110px
end

"""
The size that a new window opens at. The page's part of it, beside the
sidebar, has the shape of a sheet of A4 paper that stands up: √2 times as tall
as it's wide. So the window is that wide plus the width of the sidebar, and the
page keeps its shape while the sidebar is open. The page's part is
`PAGE_AREA_W` wide, or as big as fits on a screen that isn't tall enough for that.
`side` is how wide the sidebar is.
"""
paper_window(room::px=screen_room(), side::px=PANEL_W) = begin
  tall = min(num(PAGE_AREA_W) * √2, num(room) - 20)   # a little space under the window
  (px(round(tall / √2)) + side, px(round(tall)))
end

# --- printing ------------------------------------------------------------------------------
#
# ⌘P prints the page. The page is drawn into a PDF the way it reads, with no
# caret and no markup characters, in the Paper colours whatever colours the
# window has. The text is PRINT_TEXT points tall on paper, whatever size it
# has on screen, and the lines are as long as the paper allows. A page ends
# under a line of text or a row of a table or a sheet, never through one, and
# never right under a heading. Then the Mac's print panel slides down over the
# window with the PDF in it. The panel can save the PDF as a file too.

const PRINT_TEXT = 11.0   # the size of the page's text on paper, in points (1/72 of an inch)
const PRINT_X = 60.0      # the margin left and right of the text, in points
const PRINT_Y = 64.0      # the margin above and below it. The page's number is in the one below.
const A4 = (595.0, 842.0)

struct NSSize
  width::Float64
  height::Float64
end

"The size of the paper that the Mac prints on unless you choose another, in points"
paper_size() = begin
  Sys.isapple() || return A4
  s = with_pool() do
    ccall((:objc_msgSend, libobjc), NSSize, (Ptr{Cvoid}, Ptr{Cvoid}), msg(cls("NSPrintInfo"), "sharedPrintInfo"), sel("paperSize"))
  end
  s.width > 0 && s.height > 0 ? (s.width, s.height) : A4
end

"True when item `it` is a line with nothing on it"
blank(e, it::Item) = it.content isa Flow && isempty(strip(e.buf.lines[it.first]))

"""
The places down the page's text where a printed page can end: under each line
of text, and under each row of a table or a sheet. A page doesn't end under a
heading, or under the blank lines after one, so a heading goes onto the next
page with the text under it. For the same reason a page doesn't end under the
heading row of a table.
"""
breaks(e) = begin
  out = px[]
  held = false   # under a heading, with only blank lines since
  for it in e.layout
    c = it.content
    if c isa Flow
      for k in 1:length(c.lines)-1
        push!(out, it.top + line_top(c, k + 1))
      end
    elseif c isa Grid
      # Under the line under each row, after the second
      y = it.top + TABLE_GAP + c.head + 1px
      for (r, h) in enumerate(c.heights[1:end-1])
        y += h + 1px
        r > 1 && push!(out, y)
      end
    elseif c isa Sheet
      for r in 2:length(c.rows)
        push!(out, it.top + row_top(c, r))
      end
    end
    held = c isa Flow && (c.kind == Kind.heading || (held && blank(e, it)))
    held || push!(out, it.top + it.tall)
  end
  # A page doesn't end part of the way down a group of columns: the place would be between two lines of one column only
  columns = get(e.nodes, :columns, nothing)
  columns === nothing || filter!(y -> !any(g -> g.top < y < g.top + g.tall, columns.groups), out)
  sort!(out)
end

"""
The part of the page's text that each printed page shows, from its top to its
bottom. A page holds `room` of text. A blank line at the top of a page, or at
the end of the text, isn't printed.
"""
pages(e, room) = begin
  items = filter(it -> !blank(e, it), e.layout)
  isempty(items) && return [(0px, 0px)]
  total = lowest(e, items)
  ends = breaks(e)
  out = Tuple{px,px}[]
  top = first(items).top
  while true
    if total - top <= room
      push!(out, (top, total))
      return out
    end
    i = findlast(y -> y <= top + room, ends)
    # A block that's taller than a page, like a big live block, is cut where the page ends
    bottom = i === nothing || ends[i] <= top ? top + room : ends[i]
    push!(out, (top, bottom))
    # The next page starts with the next thing that isn't a blank line
    next = findfirst(it -> it.top + it.tall > bottom, items)
    top = max(bottom, items[next].top)
  end
end

"Clip what `canvas` draws to a box"
clip!(canvas, left, top, right, bottom) = begin
  rect = Ref(Skia.sk_rect_t(Float32(left), Float32(top), Float32(right), Float32(bottom)))
  GC.@preserve rect Skia.sk_canvas_clip_rect_with_operation(canvas, Base.unsafe_convert(Ptr{Skia.sk_rect_t}, rect), Skia.SK_CLIP_OP_INTERSECT, true)
end

"""
Draw the page's text into a PDF for paper that's `paper` points wide and tall,
and return the bytes of the PDF. The editor is left as it was.
"""
print_pdf(e, paper=paper_size()) = begin
  pw, ph = paper
  b = e.buf
  caret, anchor, wrapped = b.caret, b.anchor, e.wrap
  stream = Skia.sk_dynamic_memory_wstream_new()
  try
    # With the caret on no line, each line hides its markup and each live block shows what it made
    b.caret = b.anchor = (0, 0)
    # Paper doesn't scroll sideways, so a long line of code goes on under itself
    e.wrap = true
    use!(PAPER)
    use_code_font!(e)
    empty!(e.flows)
    # From pixels on screen to points on paper. The text is as wide as the paper allows.
    scale = PRINT_TEXT / num(body(e).size)
    layout!(e, px((pw - 2PRINT_X) / scale))
    w = e.width
    spans = pages(e, px((ph - 2PRINT_Y) / scale))
    d = node!(Document, e, :document)
    whole = Column(fixed(w), Alignment.Start, page_parts(d, e, e.layout)...)
    total = isempty(e.layout) ? 0px : lowest(e, e.layout)
    # A live block's code can load the drawing methods of what it shows, so the newest methods are used
    scene = Base.invokelatest(describe, whole, (w, total))
    title, creator, none = splitext(name(b))[1], "Ladder", ""
    never = Skia.sk_date_time_t(0, 0, 0, 0, 0, 0, 0, 0)
    # Skia copies the text of the PDF's details as it makes the PDF
    doc = GC.@preserve title creator none begin
      about = Ref(Skia.sk_metadata_t(pointer(title), pointer(none), pointer(none), pointer(none), pointer(creator),
                                     pointer(creator), never, never, 72f0, 0f0, Cint(101)))
      GC.@preserve about Skia.sk_document_make_pdf(Skia.sk_dynamic_memory_wstream_as_wstream(stream),
                                                   Base.unsafe_convert(Ptr{Skia.sk_metadata_t}, about))
    end
    for (n, (top, bottom)) in enumerate(spans)
      canvas = Skia.sk_document_begin_page(doc, Float32(pw), Float32(ph))
      Skia.sk_canvas_save(canvas)
      Skia.sk_canvas_translate(canvas, Float32(PRINT_X), Float32(PRINT_Y))
      Skia.sk_canvas_scale(canvas, Float32(scale), Float32(scale))
      # Only this page's part of the text, though something wide can run into the margins
      margin = PRINT_X / scale
      clip!(canvas, -margin, 0, num(w) + margin, num(bottom - top))
      Skia.sk_canvas_translate(canvas, 0f0, Float32(-num(top)))
      Base.invokelatest(draw, canvas, (w, total), scene)
      Skia.sk_canvas_restore(canvas)
      # The page's number, under the middle of the text
      if length(spans) > 1
        Skia.sk_canvas_save(canvas)
        Skia.sk_canvas_translate(canvas, Float32(PRINT_X), Float32(ph - PRINT_Y / 2 - 6))
        Skia.sk_canvas_scale(canvas, Float32(scale), Float32(scale))
        number = describe(Row(fixed(w), height(20px),
                              Text(string(n), size=px(9 / scale), family=SANS, color=colours.dim, wrap=WrapMode.none,
                                   align=TextAlign.Center)), (w, 20px))
        draw(canvas, (w, 20px), number)
        Skia.sk_canvas_restore(canvas)
      end
      Skia.sk_document_end_page(doc)
    end
    Skia.sk_document_close(doc)
    bytes = Vector{UInt8}(undef, Skia.sk_dynamic_memory_wstream_bytes_written(stream))
    Skia.sk_dynamic_memory_wstream_read(stream, bytes, Csize_t(0), Csize_t(length(bytes)))
    bytes
  finally
    Skia.sk_dynamic_memory_wstream_delete(stream)
    b.caret, b.anchor, e.wrap = caret, anchor, wrapped
    use!(getproperty(THEMES, e.theme))
    empty!(e.flows)
    layout!(e)
  end
end

"""
Show the Mac's print panel over window `w`, with the PDF in `bytes`. It slides
down from the top of the window, and the window waits until you print or cancel.
A window that isn't on the screen, like one a test makes, shows no panel.
"""
print_panel!(e, w, bytes, title) = begin
  (Sys.isapple() && !isempty(w.glfw)) || return
  # PDFKit draws a PDF for the Mac's printing. AppKit doesn't load it by itself.
  Base.Libc.Libdl.dlopen("/System/Library/Frameworks/PDFKit.framework/PDFKit")
  with_pool() do
    data = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt8}, UInt),
                 cls("NSData"), sel("dataWithBytes:length:"), bytes, length(bytes))
    pdf = msg(msg(cls("PDFDocument"), "alloc"), "initWithData:", data)
    pdf == C_NULL && return
    # The panel may still need the last PDF until it closes, so it's kept until the next one
    last = get(e.nodes, :printed, C_NULL)
    last == C_NULL || msg(last, "release")
    e.nodes[:printed] = pdf
    # The PDF has its own margins, so the panel adds none
    info = msg(msg(msg(cls("NSPrintInfo"), "sharedPrintInfo"), "copy"), "autorelease")
    foreach(side -> send(info, "set$(side)Margin:", 0.0), ("Top", "Bottom", "Left", "Right"))
    # Each page is made smaller if it's too big for the paper chosen in the panel (2 is kPDFPrintPageScaleDownToFit)
    op = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Int, Bool),
               pdf, sel("printOperationForPrintInfo:scalingMode:autoRotate:"), info, 2, true)
    op == C_NULL && return
    # The name that "Save as PDF" suggests
    msg(op, "setJobTitle:", nsstring(title))
    win = nswindow(w)
    ccall((:objc_msgSend, libobjc), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
          op, sel("runOperationModalForWindow:delegate:didRunSelector:contextInfo:"), win, print_listener(), sel("printed:success:window:"), win)
  end
  nothing
end

"""
AppKit calls this when the print panel closes, with the window it was over.
The window doesn't get the keyboard back by itself, so this gives it back.
"""
printed(self::Ptr{Cvoid}, cmd::Ptr{Cvoid}, op::Ptr{Cvoid}, ok::Bool, win::Ptr{Cvoid}) = (msg(win, "makeKeyWindow"); nothing)

# The object that AppKit tells when a print panel closes. It's made the first time a panel opens, and lasts as long as the app.
const listener = Ref(C_NULL)

"""
The object that AppKit tells when a print panel closes. Its class is made
here, in Objective-C's runtime, with `printed` as its one method.
"""
print_listener() = begin
  listener[] == C_NULL || return listener[]
  class = cls("LadderPrintListener")
  if class == C_NULL
    class = ccall((:objc_allocateClassPair, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Cstring, Csize_t), cls("NSObject"), "LadderPrintListener", 0)
    method = @cfunction(printed, Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Bool, Ptr{Cvoid}))
    ccall((:class_addMethod, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Cstring), class, sel("printed:success:window:"), method, "v@:@B^v")
    ccall((:objc_registerClassPair, libobjc), Cvoid, (Ptr{Cvoid},), class)
  end
  listener[] = msg(msg(class, "alloc"), "init")
end

"Print the page: show the Mac's print panel with the page drawn for paper"
print!(e, w) = e.buf.view != :markdown ? nothing : print_panel!(e, w, print_pdf(e), splitext(name(e.buf))[1])   # only a Markdown file is a page

if abspath(PROGRAM_FILE) == @__FILE__
  open_editor(ARGS)
end
