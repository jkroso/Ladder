# Functions that more than one file gives methods to, each for its own types,
# like a drop at the end of a drag on a calendar, a schedule or a takeoff. A
# function is named here once, so that each file adds its methods to the same
# function and not to one of its own.
#
#     drop!(v::CalendarView) = ...   # calendar_view.jl
#     drop!(v::TakeoffView) = ...    # main.jl

export drop!, dragging, click_twice!, settle!, answer!, commit!, stop_asking!, full_room, row_at, vertical,
       beside, diff_wide, beside!, found!, on_paper, show_place!, ask!, button!, field, fit!, fit_zoom,
       moved!, order_words, page!, say!, table_head, toolbar, callee, extent, julia_file, level, level!,
       levels, type_name, add_row!, field_text, hold!, keep!, narrowed, tip, caret, pointed, press!,
       chip_words, choice_input, choose!, choosing_tick!, chosen, draw_drag, hush!, key_given!, locate, marks,
       more_words, name_row!, own_button, stop_choosing!, theme!, turn!, works_here, step!, locked, asks,
       add_to_favourites!, page_covers, remove_from_favourites!, choices_for, put_back!, runs_at_once,
       sidenote, worded, matter_view, on_own_page, table_view, web_kind, table_item, page_side, page_outline, side_name,
       page_back!, wide_words, chip_click, chip_kind, chip_start, look!, look_of, put_look!, shown_at, drag!,
       hint, head_in_charge, compact_width, chip_wider

"A drag on the part `v` ended: what moved is written down"
function drop! end

"True while the mouse drags something of the part `v`"
function dragging end

"Note a click at `(x, y)` on the part `v`. True when it's the second of two clicks in one place."
function click_twice! end

"Take away the field that the part `v` shows for a new thing. With `keep`, what was typed goes into its block."
function settle! end

"Do what the text field of the part `v` was for with what's typed in it"
function answer! end

"Write the part `v` into its block. ⌘Z takes the change back."
function commit! end

"Take the text field of the part `v` away. The keyboard goes back to the part."
function stop_asking! end

"How tall the part `v` is when it fills the window and what it shows needs less"
function full_room end

"The place of the row of the part `v` that's `y` down the window, or nothing"
function row_at end

"The place one line up or down from the caret, in the part that the caret is in"
function vertical end

"True when the part `v` shows the old lines beside the new"
function beside end

"How wide the lines of a change are in the part `v`"
function diff_wide end

"Show the old lines beside the new ones in `x`, or under them"
function beside! end

"Work out again what the search of the part `v` finds"
function found! end

"True while the page of the editor `e` is drawn for paper"
function on_paper end

"Move the part `v`, if it must, so that all of `card` shows"
function show_place! end

"Show the text field for `what`, with `text` in it and selected"
function ask! end

"The button of `v` that's kept under `key`, with what it does and shows now"
function button! end

"The text field in a box, where the thing that it changes was"
function field end

"Show the whole of the view `v`"
function fit! end

"How many px to a point fits the whole page in the view, with white round it"
function fit_zoom end

"Note that the view moved just now, and keep the page in it"
function moved! end

"What the two orders of a column are called"
function order_words end

"Go on by `by` pages"
function page! end

"A sentence at the foot of the block"
function say! end

"The headings of a table: of the measures of a takeoff, or made from `words`"
function table_head end

"The buttons over the part `v`"
function toolbar end

"The function that a call names: from the types `tt`, or at a place in code"
function callee end

"How far something goes: the lines of a Flow, a canvas, the data of a chart, or a column of a sheet"
function extent end

"True when the page or the buffer is a file of Julia code that you change. For a method `m`, the file of Julia's own code that it's in"
function julia_file end

"The level that `node` shows at"
function level end

"Show `node` at level `i` of `levels(node)`"
function level! end

"The levels of abstraction that `node` can show at, from the lowest to the highest"
function levels end

"A type as Julia writes it, with no module's name in front of a type of the module `m`"
function type_name end

"Add a row to the table of the form `v`, with what's in its fields, in one edit, so one ⌘Z takes it away"
function add_row! end

"Lay out the text of the field `f` for `room`, and give what shows it, with how tall its text is and how tall its first line is"
function field_text end

"Keep something as it is: the view on the page, a film's picture for `seconds`, or a column of a sheet"
function hold! end

"Keep only the rows that have `words` in column `column`"
function keep! end

"True when column `c` of `s` shows only some rows"
function narrowed end

"What the mouse over a formula says"
function tip end

"Draw a caret: in a Flow, in a sheet, or at a side of a rectangle"
function caret end

"The name of the thing that the mouse is on in `part`, or nothing"
function pointed end

"What a press of the mouse does on a part: a sheet, a film, or the page"
function press! end

"What a chip says"
function chip_words end

"The field at the top of the list of where rows can come from, that searches it"
function choice_input end

"Choose row `k` of a list, or the thing `item`"
function choose! end

"What happens in each frame to a list while you choose from it"
function choosing_tick! end

"True when the row `r` of the list is where the block's rows come from now, or one of the tables that a chart draws"
function chosen end

"Draw what a drag is doing"
function draw_drag end

"Stop the sound or the video that the breadcrumb's player is playing, and end the program of a SolidCraft design that it shows"
function hush! end

"Keep `key` as the key that `v` names, and say how that went"
function key_given! end

"The place in a sheet under a point that is (dx, dy) from the top left of its item"
function locate end

"The boxes that the selection covers in a Flow or a sheet, or the marks of a folder"
function marks end

"What the line under the table says"
function more_words end

"Give the row on line `i`, which has no name, a place for one, and put the caret there"
function name_row! end

"True when the node `n` has a button beside it that stands for all that's in it"
function own_button end

"Take the list away"
function stop_choosing! end

"Use the colours called `name` for the page"
function theme! end

"Go on: by `by` pages of a PDF file or a view that zooms, or by a turn of an agent's session"
function turn! end

"True when the command called `name` has something to work on in the window of `e`, where the type of what's in focus can't say so"
function works_here end

"While a file of the gallery fills the window, go `by` files on"
function step! end

"True for contacts in a page that can't be changed, like an email"
function locked end

"The arguments of the method `sig` that the palette asks for by their place, in their order"
function asks end

"Add to Favourites"
function add_to_favourites! end

"True when what `page_view` gives for `o` covers the page's whole space in the window"
function page_covers end

"Remove from Favourites"
function remove_from_favourites! end

"What the palette's list offers for a chip of the type `T` in the window of `e`, from the nearest"
function choices_for end

"Give the command `name` the bundle's shortcuts again"
function put_back! end

"True for a command that changes nothing that you'd want to look at before it runs, like Go To or Theme"
function runs_at_once end

"Fainter words at the right of the row of `x`, or none"
function sidenote end

"The words that the palette shows for `x`, in a row and in a chip"
function worded end

"What shows in place of the card of the front matter of the page `o`, which the directory `d` holds, while the caret isn't in it"
function matter_view end

"True when the page shows the folder `o`'s own page, when that's a file in it, like a blog's Readme"
function on_own_page end

"What shows in place of the table in lines `from` to `to` of the page `o`, which the directory `d` holds, while the caret isn't in it"
function table_view end

"The kind of the web folder at `f`, which is in the web folder `d`"
function web_kind end

"The table in lines `from` to `to` as what its page's kind of folder shows in its place, or nothing when the kind shows the table"
function table_item end

"What shows in a panel at the right of the window, beside what `page_view` gives for `o`"
function page_side end

"""
The outline of `o`, what the page of `e` shows: its headings and its parts, as
`Entry`s, or nothing when a thing of its kind has no outline. A kind of file or
folder that can list its parts has a method of this. An outline can be empty,
like that of a page with no headings yet.
"""
function page_outline end

"What the button that hides the panel at the right calls the panel of `o`"
function side_name end

"Take a step back in what `page_view` gives for `o`, before the window shows the file that showed before"
function page_back! end

"True when the words that the command `name` asks for are what it's for, as the words of Ask Agent are"
function wide_words end

"What a click at the mouse of the window `w` chooses for a chip of the type `T`, or nothing"
function chip_click end

"`:choice` for a type whose things to choose from are few and fixed"
function chip_kind end

"What a chip of the type `T` starts as when the palette asks for one, or nothing"
function chip_start end

"Show in the window what the command `name` does with `args`, for a row that the arrows reached"
function look! end

"`look_of(e, Val(name))` gives how the window of `e` looks now in the ways that the command `name` changes it, for a command that shows each row of its list in the window as the arrows reach it"
function look_of end

"What `put_look!` gives"
function put_look! end

"Where the thing `x` that a chip has shows in the window of `e`, for a line round it, or nothing"
function shown_at end

"While the mouse button is down, go to the level of each stop of `l` that the mouse comes to, and return true"
function drag! end

"The first shortcut of the command `name` with two spaces before it, to end a tooltip with, or nothing when the command has no keys"
function hint end

"What shows the page's front matter, like the top of an email, while the top bar asks it for its levels"
function head_in_charge end

"How wide the side menu `menu` stays while the sidebar is closed"
function compact_width end

"`chip_wider(x, e)` gives the thing of the same type as `x` that holds it in the window of `e`, like the block that a paragraph is in, or nothing"
function chip_wider end
