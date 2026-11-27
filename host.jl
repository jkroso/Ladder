# What the part of a page asks of the window that shows it: the window's
# editor, the object of the file or the folder that the page shows, and the
# things that the window does with a folder or a file. This file only names
# them. main.jl gives each its methods for its Editor, so a view in a file of
# its own, like the page of a kind of folder, can call them without main.jl.
#
#     e = editor(node)               # the window's editor that a node of a page is part of
#     go_folder!(e, "/Users/sam")    # list that folder in the sidebar
#     open_folder!(e, "/Users/sam")  # show it in the page

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
