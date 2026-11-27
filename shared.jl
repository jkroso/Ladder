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
       sidenote, worded, matter_view, on_own_page, table_view, web_kind, table_item

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

"True while Ladder is built into an app (see app/bundle.jl)"
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

"True while Ladder is built into an app (see app/bundle.jl)"
function table_head end

"The buttons over the part `v`"
function toolbar end

"True while Ladder is built into an app (see app/bundle.jl)"
function callee end

"True while Ladder is built into an app (see app/bundle.jl)"
function extent end

"True while Ladder is built into an app (see app/bundle.jl)"
function julia_file end

"The level that `node` shows at"
function level end

"Show `node` at level `i` of `levels(node)`"
function level! end

"True while Ladder is built into an app (see app/bundle.jl)"
function levels end

"A type as Julia writes it, with no module's name in front of a type of the module `m`"
function type_name end

"True while Ladder is built into an app (see app/bundle.jl)"
function add_row! end

"True while Ladder is built into an app (see app/bundle.jl)"
function field_text end

"True while Ladder is built into an app (see app/bundle.jl)"
function hold! end

"Keep only the rows that have `words` in column `column`"
function keep! end

"True when column `c` of `s` shows only some rows"
function narrowed end

"What the mouse over a formula says"
function tip end

"True while Ladder is built into an app (see app/bundle.jl)"
function caret end

"The name of the thing that the mouse is on in `part`, or nothing"
function pointed end

"True while Ladder is built into an app (see app/bundle.jl)"
function press! end

"What a chip says"
function chip_words end

"The field at the top of the list of where rows can come from, that searches it"
function choice_input end

"True while Ladder is built into an app (see app/bundle.jl)"
function choose! end

"True while Ladder is built into an app (see app/bundle.jl)"
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

"True while Ladder is built into an app (see app/bundle.jl)"
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

"True while Ladder is built into an app (see app/bundle.jl)"
function turn! end

"True while Ladder is built into an app (see app/bundle.jl)"
function works_here end

"True while Ladder is built into an app (see app/bundle.jl)"
function step! end

"True for contacts in a page that can't be changed, like an email"
function locked end

"True while Ladder is built into an app (see app/bundle.jl)"
function asks end

"True while Ladder is built into an app (see app/bundle.jl)"
function add_to_favourites! end

"True while Ladder is built into an app (see app/bundle.jl)"
function page_covers end

"Remove from Favourites"
function remove_from_favourites! end

"True while Ladder is built into an app (see app/bundle.jl)"
function choices_for end

"Give the command `name` the bundle's shortcuts again"
function put_back! end

"True while Ladder is built into an app (see app/bundle.jl)"
function runs_at_once end

"Fainter words at the right of the row of `x`, or none"
function sidenote end

"The words that the palette shows for `x`, in a row and in a chip"
function worded end

"True while Ladder is built into an app (see app/bundle.jl)"
function matter_view end

"True when the page shows the folder `o`'s own page, when that's a file in it, like a blog's Readme"
function on_own_page end

"True while Ladder is built into an app (see app/bundle.jl)"
function table_view end

"True while Ladder is built into an app (see app/bundle.jl)"
function web_kind end

"The table in lines `from` to `to` as what its page's kind of folder shows in its place, or nothing when the kind shows the table"
function table_item end
