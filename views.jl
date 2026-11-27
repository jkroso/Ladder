# What the window asks of the object of a folder or a file, to show it: what
# the sidebar lists of it and how, its icon and its name there, and what the
# page shows for it. This file only names these functions. main.jl gives each
# its usual methods, and a kind of folder gives methods for its own type, in
# main.jl or in a file of its own, like the pages of the Mac's own folders.
#
#     page_view(e, d::DownloadsDirectory) = ...   # the page of the Downloads folder
#     entry_icon(o::TrashDirectory) = "trash"     # its icon in the sidebar

"What the sidebar of the editor `e` lists of the directory `d`"
function entries end

"The icon that the object `o` has in the sidebar"
function entry_icon end

"The name that the object `o` has in the sidebar"
function entry_name end

"What follows the name of the object `o` in its row of the sidebar of the editor `e`: nodes, or `()`"
function entry_marks end

"How the sidebar of the editor `e` lists the directory `d`: `(list=..., bar=...)`"
function folder_view end

"What the page of the editor `e` shows for the object `o`, a file or a folder: a node, or nothing to leave Ladder's own viewer"
function page_view end

"True when what `page_view` gives for the object `o` is as wide as the window has room for"
function page_fills end

"True when a window that's opened on the folder `d` shows what `page_view` gives for it first"
function page_first end
