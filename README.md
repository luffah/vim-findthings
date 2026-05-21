# Find things (Vim) 

This plugin add features:

* commands starting with List and Grep (enhanced lgrep)
* recursive listing of a directory
* list vim things : oldfiles, syntax, buffers, tabs, marks,
                    history, keymap, colorscheme, functions, commands
* allow to diff direchory (with vimdiff) [setf directory if the path is not recognized].

### All commands use filters

First, what is it ?

* a filter is a pattern like useable in =~ expression
* pattern shall be cumulated with '&'
* '!filter' invert the filter


### Commands
**List** path [filter [& [!]filter]]<br>
    Show a recursive list of the directory in args, with optionnal filters.

**ListHere**<br>
    (see List) List directory of the current file

**ListOld** [filter]<br>
    List old files

**ListSyntaxFiles** [filter]<br>
    List syntax files

**ListBuffers** [filter]<br>
    List buffers

**ListTabs** [filter]<br>
    List tabs

**ListMarks** [filter]<br>
    List marks

**ListSearchHistory** [filter]<br>
    List search history

**ListCmdHistory** [filter]<br>
    List command history

**ListHi** [filter]<br>
    List syntax color elements (:hi)

**ListSyntax** [filter]<br>
    List syntax for the current filetype (:syntax)

**ListAutoCmd** [filter]<br>
    List syntax color elements (:au)

**ListKeyMap** [filter]<br>
    List keymapping (:map command)

**ListCommands** [filter]<br>
    List commands (:command command)

**ListFunctions** [filter]<br>
    List commands (:function command)

**ListColors** [filter]<br>
    List colorscheme (:colors command)

**Grep** path pattern<br>
    Grep ...

**GrepHere** pattern<br>
    Grep in directory related to current file

**VGrepHere** pattern<br>
    GrepHere in another window in order to explore without hidden current buffer

**GrepFile** pattern<br>
    grep a pattern in current file

**GrepSetF** filetype<br>
    add allowed filetype to search with grep (this update b:find_related_file_extensions)
