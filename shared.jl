# Functions that more than one file gives methods to, each for its own types,
# like a drop at the end of a drag on a calendar, a schedule or a takeoff. A
# function is named here once, so that each file adds its methods to the same
# function and not to one of its own.
#
#     drop!(v::CalendarView) = ...   # calendar_view.jl
#     drop!(v::TakeoffView) = ...    # main.jl

export drop!, dragging, click_twice!, settle!, answer!, commit!, stop_asking!, full_room, row_at, vertical, beside,
       diff_wide, beside!, found!, on_paper, show_place!

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
