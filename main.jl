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
@use "./agent/recall" exports...
@use "./agent/pane" exports...
@use "./code_thing" exports...
@use "./agent/ask" exports...
@use "./check_fails" exports...
@use "./code_picker" exports...
@use "./news_page" exports...
@use "./folder_kinds" exports...
@use "./remote_page" exports...
@use "./sandbox" exports...
@use "./drag_number" exports...
@use "./file_blocks" exports...
@use "./table_bar" exports...
@use "./page_as_app" exports...
@use "./showed_before" exports...
@use "./day_view" exports...
@use "./line_history" exports...
@use "./todo_clock" exports...
@use "./givers" exports...
@use "./sum_functions" exports...
@use "./page_mouse" exports...
@use "./peek_cards" exports...
@use "./dropped_files" exports...
@use "./wiki_links" exports...
@use "./copied_blocks" exports...
@use "./markdown_app" exports...
@use "./top_bar" exports...
@use "./last_place" exports...
@use "./autosave" exports...
@use "./editing" exports...
@use "./right_panel" exports...
@use "./page_menu" exports...
@use "./caret_glide" exports...
@use "./page_layout" exports...
@use "./renames" exports...
@use "./toasts" exports...
@use "./printing" exports...
@use "./centient_job" exports...
@use "./tabs" exports...
@use "./commands" exports...
@use "./file_menu" exports...
@use "./settings" exports...
@use "./transclusion" exports...
@use "./page_draw" exports...
@use "./startup_page" exports...
@use "./palette" exports...
@use "./finder" exports...
@use "./sidebar" exports...
@use "./windows" exports...

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
  Core.eval(m, :(const term_again = $(() -> (reads!(e, :terminal); TERM_SETTINGS.again))))
  Core.eval(m, :(const term_again! = $(on -> term_setting!(e, :again, Bool(on)))))
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

# --- the top of an email -----------------------------------------------------------
#
# email_head.jl has the top of an email, which shows its subject, who sent it
# and when, and who it's to, and every field of its header a level down. It
# also says when the top of a page has the ladder in the top bar.

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
  all::Vector{Tuple{String,String}} = Tuple{String,String}[]     # each step with its whole name, as it would show with room for all of them
  size::Any = nothing                                            # how big the window was when the path was put in place
  crumbs::Dict{String,Any} = Dict{String,Any}()                  # the TitleCrumb of each step, by its path
  gap::Any = nothing                                             # the TitleGap, when an … stands for folders that there's no room for
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
  name::String = ""   # as it shows, which can be shorter than its whole name
  full::String = ""   # its whole name
  last::Bool = false
end

"The … of the path in the top bar, in the place of folders that there's no room for"
@def mutable struct TitleGap <: SemanticUI
  names::Vector{String} = String[]   # the folders that it stands for, from the left
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
  # In the page the name is in the middle of its room, and the path stays in that room. The file's name stays where it
  # was, under the mouse, so the folders before it have only the room from the left end to the name, and their names
  # shrink to fit it, as in the sidebar.
  lo = r.left + r.width / 2 - room / 2
  if inpage
    left = r.left + get(e.nodes, :title_lead, 0px) - lo   # the room for the folders, before the name
    shown = title_steps(all, min(room - more, left + title_widths(all[end:end])[1] - TT_PAD + TT_EDGE + 1px))
  end
  v = get!(() -> own!(t, TitleTrail()), e.nodes, :title_trail)
  v.path == path || (empty!(v.crumbs); empty!(v.arrows))
  # A pinned path is in the middle of the bar. After a click unpins it, it stays there until it closes, so the name doesn't move from under the mouse.
  v.centred = trail_pinned(e) || (v.centred && any(p -> p.key == :title_trail, popups(w)))
  v.path, v.steps, v.all, v.size, v.parts, v.title_at = path, shown, all, window_size(e), parts, title_place(e, t)
  widths = title_widths(shown)
  total = title_wide(shown) + more
  # How far the file's name is from the path's left edge
  before = sum(widths[1:end-1], init=0px) + TT_ARROW * (length(shown) - 1) + TT_EDGE + 1px + TT_PAD
  # The name is in the middle of its room in the bar, with the headings after it and as much room before it, so the middle of the name's node is the bar's
  x = v.centred ? r.left + r.width / 2 - total / 2 : r.left + get(e.nodes, :title_lead, 0px) - before
  # In the page the path stays in the name's room, so it lies over nothing else of the page
  inpage && (x = clamp(x, lo, max(lo, lo + room - total)))
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
      # The … knows the names of the folders that it stands for: those between the steps either side of it
      g = v.gap === nothing ? (v.gap = own!(v, TitleGap())) : v.gap
      from, to = (findfirst(s -> s[2] == v.steps[j][2], v.all) for j in (i - 1, i + 1))
      g.names = from === nothing || to === nothing ? String[] : first.(v.all[from+1:to-1])
      push!(parts, g)
    else
      c = get!(() -> own!(v, TitleCrumb(path=path)), v.crumbs, path)
      c.name, c.last = name, i == n
      k = findfirst(s -> s[2] == path, v.all)
      c.full = k === nothing ? name : v.all[k][1]
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

describe(g::TitleGap) =
  Box(height(grow=grow), padding(TT_PAD, 0px), Alignment.Center, justify=Alignment.Center, name="Gap",
    label("…", 13px, color=colours.faint))

# A name that's shorter than its whole name, to fit, shows its whole name in a tooltip while the mouse is over it.
# The … shows the names of the folders that it stands for.
onmouse(c::TitleCrumb, ev::MouseMove) = (c.name == c.full || crumb_tip!(c, ev.window, c.full); nothing)
onmouse(g::TitleGap, ev::MouseMove) = (isempty(g.names) || crumb_tip!(g, ev.window, join(g.names, " › ")); nothing)

"Show `words` in a tooltip under `node`, a part of the path. The path is a popup, so the tooltip goes by the node's rectangle: one that follows a node in a popup closes at once."
crumb_tip!(node, w, words) = (r = rect(node); r === nothing || show_tooltip!(w, tip_label(words), r.left, r.top, r.width, r.height, placement=:bottom, gap=6px); nothing)

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

# --- commands that are functions ----------------------------------------------------------
#
# commands.jl has this part of Ladder. Its commands are here.

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

# --- a page as an app -------------------------------------------------------------------------
#
# page_as_app.jl has this part of Ladder. Its commands are here.

add_command!(show_as_app!, title="Show the page as an app, in a window of its own: only its blocks, with no sidebar or caret, and nothing in the top bar", kind=:look)

# --- when a line last changed ---------------------------------------------------------------
#
# line_history.jl has this part of Ladder. Its commands are here.

add_command!(agent_mode!, title="Show an agent's session at the left of the page and the page's outline at its right, in a wider window. Again puts the window back.")
add_command!(end_agent_session!, title="End the session of agent mode. Your next words there start a new one.")
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

# --- saving a page when you leave its window ------------------------------------------------
#
# autosave.jl has this part of Ladder. Its commands are here.

add_command!(autosave!, title="Turn on or off saving a page when you leave its window")
