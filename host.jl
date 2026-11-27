# What the part of a page asks of the window that shows it: the window's
# editor, the object of the file or the folder that the page shows, and the
# things that the window does with a folder or a file. This file only names
# them. main.jl gives each its methods for its Editor, so a view in a file of
# its own, like the page of a kind of folder, can call them without main.jl.
#
#     e = editor(node)               # the window's editor that a node of a page is part of
#     go_folder!(e, "/Users/sam")    # list that folder in the sidebar
#     open_folder!(e, "/Users/sam")  # show it in the page

export editor, page_object, object, list_files!, go_folder!, open!, open_folder!, show_path!, show_beside!,
       free_path, folder_kind, page_top, trash!, file_act!, show_in_finder, above_page, touch!, show_line!,
       page_day, save_settings!, rerun!, page_room, page_tables, named_table, layout!, command_of,
       click_page!, text_object, say_result!, lowered

"The editor of the window that `node`, a part of a page, is part of"
function editor end

"The object of the file or the folder that the page of the editor `e` shows, or nothing"
function page_object end

"The object of the folder or the file at `path`, as the sidebar of the editor `e` lists it, or nothing when nothing is there"
function object end

"Read the folder of the sidebar of the editor `e` again"
function list_files! end

"Show the folders and the files of `folder` in the sidebar of the editor `e`"
function go_folder! end

"Show the file or the folder at `path` in the page of the editor `e`"
function open! end

"Open the folder at `path` in the page of the editor `e`"
function open_folder! end

"Show the file or the folder at `path` the way that a click on a link to it does, in the window of the editor `e`"
function show_path! end

"Show the folder or the file at `path` in the page of the editor `e`, while the sidebar goes on with the folder that it lists"
function show_beside! end

"A path in the folder `dir` for something new called `base`, with the ending `ending`, that no file and no page of the editor `e` has yet"
function free_path end

"The kind of the folder at `path`: the type under AbstractDirectory that its object has"
function folder_kind end

"How far down the page of the editor `e` its text starts, under the top bar and what the page shows over its text"
function page_top end

"Move the file or the folder at `path` to the Trash, and take it out of the sidebar of the editor `e`"
function trash! end

"Do to the file or the folder at `path` what the item `name` of its menu says, in the editor `e`"
function file_act! end

"Open a Finder window on the folder of the file at `path`, with the file selected"
function show_in_finder end

"How much room the top bar of the editor `e` keeps at the top of the window, over the page"
function above_page end

"The caret of the editor `e` moved or its text changed, so show the caret"
function touch! end

"Put the caret of the editor `e` at the end of line `i` of the page, and bring the line in sight"
function show_line! end

"The day that the page of the editor `e` shows itself on: today, unless a `day` block says another"
function page_day end

"Give the other windows the settings of the editor `e`, and write them to their file if `e` keeps them"
function save_settings! end

"Run again the live blocks of the editor `e` that asked for `setting`"
function rerun! end

"How wide and how tall the page's space in the window of the editor `e` is"
function page_room end

"Every table of the page of the editor `e` that shows, with its lines, its heading and the text of its cells"
function page_tables end

"Which of `tables`, the tables of the page of the editor `e`, the line `from` calls, or nothing"
function named_table end

"Work out what the page of the editor `e` shows and how tall each part is, for text that's `width` wide"
function layout! end

"The command that the key `K` runs by itself in the window `w` of the editor `e`, or nothing"
function command_of end

"Give a click on `node`, a part of a page, to the page, as a click on its text is given"
function click_page! end

"The object of the page of text that the editor `e` shows, or nothing"
function text_object end

"Say `words` under the top bar of the editor `e` for a while"
function say_result! end

"The first and the last line of the block whose lines fill the window of the editor `e` as text, or nothing"
function lowered end
