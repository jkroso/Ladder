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
@use "./files/pictures" picture natural thumbnail finder_icon pdf_pages pdf_page pdf_size pdf_part pdf_lines forget_picture photo_place
@use "./spelling" misspelt guesses learn!
@use "./files/transcribe" Transcription check! finished phrases words_between
@use "./html" html footnotes NOTE escape
@use "./markdown" Kind Line Span Cell classify spans tablecells isdivider words isdone front_matter after_matter MATTER TOML_MATTER MATH CALLOUTS callout opens_callout wikitarget block_id only_id
@use "./markdown" COMMENT
@use "./code/highlight" tokens left_open
@use "./blocks/sheet" SHEET Result Given sheetcells parts uses tally known units shown number_at nudged name_values ident cases folded RUN_ROW
@use "github.com/jkroso/Units.jl" => Units
@use "github.com/jkroso/Units.jl/Money" => Cash
@use "./blocks/spreadsheet" SPREADSHEET Value spreadcells spreadtexts isformula letters answers moved
@use "./merge" changes combine follow unified
@use "./agent/waiters" => Agent
@use "./agent/for_agents" => Offer
@use "./agent/for_agents" on_main
@use "./agent/repl" => Repls
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./pasteboard" => Pasteboard
@use "./blocks/takeoff" => Plans
@use "./blocks/schedule" => Schedules
@use "./blocks/chart" => Charts
@use "./blocks/csv" => Csvs
@use "./blocks/filter" => Filters
@use "./blocks/save" => Saves
@use "./blocks/forms" => Forms
@use "./blocks/math" => Maths
@use "./blocks/ask" => Asks
@use "./blocks/changes" => Diffs
@use "./blocks/board" => Boards
@use "./blocks/gallery" => Galleries
@use "./blocks/calendar" => Calendars
@use "./blocks/linkcard" => Cards
@use "./blocks/columns" => Columns
@use "./blocks/repeats" => Repeats
@use "./blocks/find" => Searches
@use "./blocks/sketch" => Sketches
@use "./blocks/canvas" => Canvases
@use "./blocks/signature" => Signatures
@use "./blocks/contact" => Contacts
@use "./blocks/map" => Maps
@use "./blocks/timelog" => Timelogs
@use "./blocks/day" => Days
@use "./dates" => DatesRead
@use "./centient" => Centient
@use "./window/update" => Update
@use "./files/mime" => Mime
@use "github.com/jkroso/JSON.jl" JSONObject JSONNumber json_value write_json
@use "./files/eml" => Eml
@use "./files/webpage" => Webpages
@use "./web" => Web
@use "./web/select" => WebSelect
@use "./web/browser" => Browsers
@use "./web/files" => Webfiles
@use "./web/fetch" => Webfetch
@use "./web/hiddenpage" => Hidden
@use "./web/source" => Sources
@use "./files/remote" => Remote
@use "./code/guard" => Guard
Guard.LADDER[] = @__MODULE__
@use "./page/slides" => Slides
@use "./folders/desktop" => Desks
@use "./term/view" => Terms
@use "./folders/git" => Git
@use "./cad/view" => Designs
@use "./cad/agent" => DesignTools
@use "./folders/notes" => Notes
@use "./folders/zip" => Zips
@use "./folders/macfile" => MacFiles
@use "./folders/trash" => Trash
@use "./app/facts" APP_ID   # the Ladder app's name for macOS
@use "./folders/folders" => Folders
@use "./folders/blog" => Blogs
@use "./folders/news" => News
@use "./folders/sites" => Sites
@use "./folders/feeds" => Feeds
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
@use "./blocks/blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./additions" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./folders/git_marks" exports...
@use "./folders/notes_page" => NotesPages NotesDirectory
@use "./folders/zip_page" => ZipPages
@use "./folders/macfolders_page" => MacPages DownloadsDirectory TrashDirectory PicturesDirectory ScreenshotsDirectory mac_kind
@use "./blocks/ask_view" exports...
@use "./blocks/linkcard_view" exports...
@use "./blocks/changes_view" exports...
@use "./blocks/sketch_view" exports...
@use "./blocks/math_view" exports...
@use "./blocks/takeoff_view" exports...
@use "./code/julia_levels" exports...
@use "./blocks/csv_view" exports...
@use "./blocks/json_view" exports...
@use "./blocks/map_view" exports...
@use "./window/fill_view" exports...
@use "./files/file_view" exports...
@use "./blocks/sheet_view" exports...
@use "./blocks/columns_view" exports...
@use "./blocks/live_view" exports...
@use "./files/long_file" exports...
@use "./blocks/schedule_view" exports...
@use "./blocks/board_view" exports...
@use "./blocks/calendar_view" exports...
@use "./blocks/gallery_view" exports...
@use "./blocks/timelog_view" exports...
@use "./blocks/check_view" exports...
@use "./blocks/canvas_view" exports...
@use "./blocks/find_view" exports...
@use "./blocks/load_view" exports...
@use "./blocks/contact_view" exports...
@use "./blocks/signature_view" exports...
@use "./files/webpage_view" exports...
@use "./term/terminal_view" exports...
@use "./blocks/view_block" exports...
@use "./blocks/result_block" exports...
@use "./page/slides_view" exports...
@use "./page/cover_view" exports...
@use "./files/email_view" exports...
@use "./files/email_head" exports...
@use "./folders/desktop_page" exports...
@use "./folders/folder_table" exports...
@use "./folders/blog_page" exports...
@use "./folders/git_page" exports...
@use "./code/run_code" exports...
@use "./code/module_view" exports...
@use "./code/code_names" exports...
@use "./code/code_nav" exports...
@use "./cad/design_view" exports...
@use "./files/media_view" exports...
@use "./page/page_extras" exports...
@use "./code/levels_view" exports...
@use "./blocks/rows_from" exports...
@use "./blocks/chart_view" exports...
@use "./blocks/filter_view" exports...
@use "./blocks/save_view" exports...
@use "./blocks/form_view" exports...
@use "./agent/kinds" exports...
@use "./agent/session" exports...
@use "./agent/window" exports...
@use "./agent/page" exports...
@use "./agent/recall" exports...
@use "./agent/pane" exports...
@use "./code/code_thing" exports...
@use "./agent/ask" exports...
@use "./code/check_fails" exports...
@use "./code/code_picker" exports...
@use "./folders/news_page" exports...
@use "./folders/folder_kinds" exports...
@use "./files/remote_page" exports...
@use "./code/sandbox" exports...
@use "./page/drag_number" exports...
@use "./blocks/file_blocks" exports...
@use "./page/table_bar" exports...
@use "./window/page_as_app" exports...
@use "./window/showed_before" exports...
@use "./blocks/day_view" exports...
@use "./page/line_history" exports...
@use "./blocks/todo_clock" exports...
@use "./code/givers" exports...
@use "./code/sum_functions" exports...
@use "./page/page_mouse" exports...
@use "./page/peek_cards" exports...
@use "./page/dropped_files" exports...
@use "./page/wiki_links" exports...
@use "./page/copied_blocks" exports...
@use "./window/markdown_app" exports...
@use "./window/top_bar" exports...
@use "./window/last_place" exports...
@use "./page/autosave" exports...
@use "./page/editing" exports...
@use "./window/right_panel" exports...
@use "./page/page_menu" exports...
@use "./page/caret_glide" exports...
@use "./page/page_layout" exports...
@use "./page/renames" exports...
@use "./window/toasts" exports...
@use "./page/printing" exports...
@use "./centient_job" exports...
@use "./window/tabs" exports...
@use "./window/commands" exports...
@use "./window/file_menu" exports...
@use "./window/app_updates" exports...
@use "./window/settings" exports...
@use "./code/page_names" exports...
@use "./page/transclusion" exports...
@use "./page/page_draw" exports...
@use "./window/startup_page" exports...
@use "./window/palette" exports...
@use "./window/finder" exports...
@use "./window/sidebar" exports...
@use "./window/windows" exports...
@use "./page/marked_things" exports...
@use "./page/caret_on_part" exports...
@use "./window/title_path" exports...
@use "./window/bar_hides" exports...

# --- the page's layout ---------------------------------------------------------------
#
# page_names.jl has the names that a window gives the code of its pages: see
# `sandbox` there. Each setting's two names, like `page_theme` and
# `page_theme!`, are in its row of SETTINGS, in settings.jl.

# --- the app's own updates ------------------------------------------------------------------
#
# app_updates.jl has this part of Ladder. settings.jl reads the file of the
# settings: see `load_settings!` there.

if abspath(PROGRAM_FILE) == @__FILE__
  open_editor(ARGS)
end
