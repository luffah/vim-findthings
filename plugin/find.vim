" find.vim   -- Vim lib to find and list things
" @Author:      luffah (luffah AT runbox com)
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2026-05-17
" @Last Change: 2026-05-17
" @Revision:    1
" License AGPL-3.0 or later (http://www.gnu.org/licenses/agpl).

" @Overview
" This plugin add features:
"  - commands starting with List and Grep (enhanced lgrep)
"  - recursive listing of a directory
"  - list vim things : oldfiles, syntax, buffers, tabs, marks,
"                      history, keymap, colorscheme, functions, commands
"  - allow to diff direchory (with vimdiff) [setf directory if the path is not recognized].
"
"@global g:find_keymapping
"setup keys for the window header
let s:find_keymapping=
      \ {'close': 'q',
      \ 'jump': '<Space>',
      \ 'jump_close': '<enter>',
      \ 'exec': '<enter>',
      \ 'jump_tab_close': 'c',
      \ 'innewtab': 't',
      \ 'filter': 'f',
      \ 'grep': 'F',
      \ 'reload': 'r',
      \ 'vsplit': 'v',
      \ 'hsplit': 's',
      \ 'search_parent': 'p',
      \ 'diff_push_file': 'P',
      \ 'go': '<enter>',
      \ 'open_buffer': '<Space>',
      \ 'kill_buffer': 'k',
      \ }

"@global g:find_action_desc
"setup description for the window header
let s:find_action_desc=
      \ {'close': 'Close',
      \ 'jump': 'Open aside',
      \ 'exec': 'Process',
      \ 'jump_close': 'Open here',
      \ 'jump_tab_close': 'Open in new tab',
      \ 'innewtab': 'Open in new tab but stay here',
      \ 'filter': 'Filter',
      \ 'grep': 'Grep',
      \ 'reload': 'Reload',
      \ 'vsplit': 'Open in vsplit',
      \ 'hsplit': 'Open in hsplit',
      \ 'search_parent': 'Search in parent dir',
      \ 'diff_push_file': 'Copy/push file',
      \ 'open_buffer': 'Open buffer',
      \ 'kill_buffer': 'Kill buffer',
      \ 'go': 'Go',
      \ }

let s:find_open_orientation = {
      \ 'preview': 'vertical rightbelow',
      \ 'vsplit': 'vertical rightbelow',
      \ 'split': 'rightbelow'
      \ }

let s:find_panel_style= { 'sep_block': ' -> ', 'sep_inline': ':' }

call extend(s:find_keymapping, get(g:,'find_keymapping', {}))
call extend(s:find_action_desc, get(g:,'find_action_desc', {}))
call extend(s:find_open_orientation, get(g:,'find_open_orientation', {}))
call extend(s:find_panel_style, get(g:,'find_panel_style', {}))
let g:find_conceal_pattern=get(g:,'find_conceal_pattern',
      \ '\('.
      \ '-[a-z0-9]\{16,}\(\/\)\@='.
      \ '\)\C')

let g:find_max_depth=get(g:, 'find_max_depth', 20)

let g:find_cache_dir=get(g:, 'find_cache_dir', g:tmpdir.'/cache')

call mkdir(g:find_cache_dir, 'p')

" User interface basis
function! s:key_desc(action_name,block_alignement)
  if has_key(b:_action_desc,a:action_name)
    let l:desc=b:_action_desc[a:action_name]
  else
    let l:desc=a:action_name
  endif
  if has_key(b:_keymapping,a:action_name)
    if a:block_alignement
      let l:desc=printf('%'.a:block_alignement.'s',
            \ b:_keymapping[a:action_name] )
            \ .s:find_panel_style['sep_block'].l:desc
    else
      " for statusline 
      let l:desc=b:_keymapping[a:action_name].s:find_panel_style['sep_inline'].l:desc
    endif
  else 
    let l:desc=""
  endif
  return l:desc
endfunction
function! s:automapping(action_name,action, ...)
  if has_key(b:_keymapping,a:action_name)
    exe "nnoremap <silent> <nowait> <buffer> ".b:_keymapping[a:action_name].' '.a:action 
    return s:key_desc(a:action_name, get(a:000, 0, 10))
  endif
  return ''
endfunction


" ~~~ LIST ~~
"  Aside windows to find and use things
let s:header_separator='-------------------------------------'

" Creation of the interactive window
function! s:setupwin()
  if exists('b:find_window_up')
    return
  endif
  let l:_ref_window=win_getid()
  let l:cur_buf=bufnr()
  if ! get(b:, 'find_avoid_new_window', 0)
    if line('$') != 1 || !empty(getline(1))
      vnew
      let b:_ref_window=l:_ref_window
    endif
  endif
  set buftype=nofile
  set nobuflisted
  let b:_find_buffer=1
  if get(t:, 'diff', 0)
    let l:winlist = map(tabpagebuflist('.'), '[v:val, bufwinid(v:val)]')
    let l:winlist = filter(l:winlist, 'v:val[1] != -1 && v:val[0] != '.l:cur_buf)
    let l:diff_companion=-1
    for l:w in l:winlist
      call setbufvar(l:w[0], 'diff_companion', l:_ref_window)
      call setbufvar(l:w[0], 'find_avoid_new_window',get(b:, 'find_avoid_new_window', 0))
      let l:diff_companion=l:w[1]
    endfor
    if l:diff_companion != -1
      let b:diff_companion=l:diff_companion
    endif
  else
      set bufhidden=wipe
  endif
  syn case ignore
  syn match MoreMsg /.*\( -> .*\)\@=/
  syn match Comment /×.*/
  syn match Identifier /$.*/
  let b:find_window_up=1
  let b:activated_conceal=0
  setlocal nowrap cursorline
  let b:_keymapping=s:find_keymapping
  let b:_action_desc=s:find_action_desc
endfu
fu! s:clearlines()
  let l:b=getreg('"')
  %delete
  call setreg('"', l:b)
endfu

" Filters in arguments
function! s:filter(list, filter)
  let l:ret=[]
  let l:filters=[]
  let l:negfilters=[]
  for l:filt in split(a:filter,'&')
    if l:filt =~ '!.*'
      call add(l:negfilters, l:filt[1:])
    else
      call add(l:filters, l:filt)
    endif
  endfor
  if len(l:filters) + len(l:negfilters) == 0
    return a:list
  endif
  for l:i in a:list
    let l:skip=0
    for l:filt in l:negfilters
      if l:i =~ l:filt
        let l:skip=1
        break
      endif
    endfor
    if l:skip
      continue
    endif
    for l:filt in l:filters
      if l:i !~ l:filt
        let l:skip=1
        break
      endif
    endfor
    if l:skip
      continue
    endif
    call add(l:ret, l:i)
  endfor
  return l:ret
endfunction

function! s:fetch_filters_param(args)
  let l:filter=""
  let l:grep=""
  let l:_grep=0
  for l:a in a:args
    if l:a == '<'
      let l:_grep=1
    elseif l:_grep
      let l:grep .= l:a
    else
      if len(l:filter)
        let l:filter.='&'
      endif
      let l:filter.=l:a
    endif
  endfor
  return [l:filter, l:grep]
endfunction

"" Least common path
"@function find#lcp(lines)
"Take a list of paths and return the least common path
function! find#lcp(lines)
  let l:lines = sort(copy(a:lines))
  let l:first = split(l:lines[0], '/')
  let l:last = split(l:lines[-1], '/')
  let l:i = 0
  while (len(l:first) > i && l:first[i] == l:last[i])
    let l:i = l:i + 1
  endwhile
  if l:i > 0
    let l:i = l:i - 1
    return substitute('/'.join(l:first[:l:i], '/').'/', '^\/\~', '\\\~','')
  endif
  return ''
endfunction

function! s:check_fname_conceal(lines)
  if b:activated_conceal
    return 0
  endif
  let b:activated_conceal=1
  if len(a:lines) > 1
    let l:lcp=find#lcp(a:lines)
    if len(l:lcp)
      exe 'syn match ConcealCommonPrefix |'.l:lcp.'| conceal'
    endif
  endif
  exe 'syn match ConcealLine /'.g:find_conceal_pattern.'/ conceal'
  setlocal conceallevel=2
  return 1
endfunction


" List functions
"@function find#List(dir,...)
"The function for List* commands which list files, check examples.
function! find#List(dir,...)
  let l:dir=resolve(a:dir)
  " if (filereadable(l:dir))
  "   exe "tabnew ".l:dir
  "   return
  " endif
  let [l:filter, l:grep] = s:fetch_filters_param(a:000)
  call s:setupwin()
  let b:_find_buffer_type='file'
  let b:dir=(len(l:dir)>1?substitute(l:dir,'/$','',''):l:dir)
  call s:ListUpdate(l:filter, l:grep)
endfunction

"@function find#ListFileCmd(dir,...)
"The function for List* commands which list files from a command (like oldfiles), check examples.
function! find#ListFileCmd(cmd,format,...)
  let [l:filter, l:grep] = s:fetch_filters_param(a:000)
  call s:setupwin()
  let b:_find_buffer_cmd_parsing_pattern=a:format
  let b:_find_buffer_cmd=a:cmd
  let b:_find_buffer_type='file'
  call s:ListFileCmdUpdate(l:filter)
endfunction

"@function find#ListCmd(dir,...)
"The function for List* commands which list things (like functions), check examples.
function! find#ListCmd(cmd,bdict,...)
  let [l:filter, l:grep] = s:fetch_filters_param(a:000)
  let l:extra=""
  call s:setupwin()
  let b:_find_buffer_cmd_dict=a:bdict
  let b:_find_buffer_cmd=a:cmd
  let b:_find_buffer_type='none'
  let l:abbrevs = {'<': 'in_format', '>': 'out_format', '<(': 'param_parsing', ':': 'exec', '::': 'commands',  'o': 'opts'}
  let l:defaults = {'in_format': '^\(.*\)$', 'out_format': '\1', 'param_parsing': '\(.*\)'}
  for l:k in keys(l:abbrevs)
    if has_key(b:_find_buffer_cmd_dict, l:k)
      let b:_find_buffer_cmd_dict[l:abbrevs[l:k]] = b:_find_buffer_cmd_dict[l:k]
    endif
  endfor
  for l:k in keys(l:defaults)
    if !has_key(b:_find_buffer_cmd_dict, l:k)
      let b:_find_buffer_cmd_dict[l:k] = l:defaults[l:k]
    endif
  endfor
  for l:c in get(b:_find_buffer_cmd_dict, 'commands', [])
    if len(l:c) > 2
      let b:_keymapping[l:c[0]]=l:c[2]
    endif
    if len(l:c) > 3
      let b:_action_desc[l:c[0]]=l:c[3]
    endif
  endfor
  call s:ListCmdUpdate(l:filter)
  for l:o in split(get(b:_find_buffer_cmd_dict, 'opts', ''), ' ')
      if l:o == 'autoexit' | autocmd WinLeave <buffer> bd
      elseif l:o == 'autoupdate' | autocmd WinEnter <buffer> call s:ListCmdUpdate(b:filter)
      elseif l:o =~ 'ft=.*' | exe 'setf '.split(l:o, '=')[1]
      endif
  endfor
endfunction

" tools to for interactive actions {{{
fu! s:chdir(d)
  let b:dir=resolve(expand(b:dir.'/'.a:d))
endfu
fu! s:_getline_(pos)
  return substitute(getline(a:pos), ' \$.*$', '','')
endfu
fu! s:_fixed_file_path(fname)
  if exists('b:dir') && a:fname !~ '^/'
    return b:dir.'/'.a:fname
  else
    return a:fname
  endif
endfu
fu! s:getline()
  return s:_fixed_file_path(s:_getline_('.'))
endfu

function! s:open(mode, ...)
  let l:file = b:_find_buffer_type == 'file' ? s:get_fname_line() : s:getline()
  let l:sens=get(a:000, 0, s:find_open_orientation[a:mode])
  if a:mode == 'preview'
    let l:ope=(bufexists(l:file)? 'buffer ' : 'e ')
    wincmd w
    if get(b:,'_find_buffer',0)
      " find buffer alone
      wincmd v
    endif
    exe l:ope.l:file
    wincmd W
  endif 
  if a:mode =~ 'split'
    exe l:sens.' split '.l:file
  endif
endfunction

fu! s:edit_cursor_file(...)
  let l:indiff=index(a:000, 'diff')
  let l:diff=get(t:, 'diff', 0)
  if l:indiff > -1
    let l:fname_diff=a:000[l:indiff+1]
    silent call search('^'.l:fname_diff.'\s*\$', 'c')
    let l:diff = 1
  endif
  let l:fname = s:_getline_('.')
  let l:diff_companion=-1
  if l:diff && exists('b:diff_companion')
    let l:diff_companion=b:diff_companion
  endif
  set bufhidden=hide
  if l:diff
      diffoff
      let l:cmd='silent e '.s:_fixed_file_path(l:fname)
  else
      let l:cmd='silent e '.s:_fixed_file_path(l:fname)
  endif
  if l:diff && exists('b:diff_companion')
    " let l:cmd.=' | let b:diff_root_path="'.expand('%:p').'"'
    let l:cmd.=' | let b:diff_root_buf='.bufnr() 
    let l:cmd.=' | let t:diff_root_buf_linenr='.line('.')
    let l:cmd.=' | nmap <buffer> q :call <SID>exit_child_file_diff()<cr>'
  endif
  silent exe l:cmd
  let l:cur_win=win_getid()
  if l:diff
    diffthis
    if (l:indiff == -1) && l:diff_companion !=-1
      call win_gotoid(l:diff_companion)
      diffoff
      call s:edit_cursor_file('diff', l:fname)
      call win_gotoid(l:cur_win)
    endif
  endif
endfu

fu! s:activate_dir_or_file(forcedir)
  if a:forcedir && isdirectory(expand('%:p'))
      if &diff
          let t:diff=1
      endif
      let b:find_avoid_new_window=1
      silent call find#List(expand('%:p'))
  else
      silent exe 'e '.expand('%:p')
  endif
endfu

fu! s:exit_child_file_diff()
  " let l:diff_root_buf=b:diff_root_buf
  " exec 'bu '.b:diff_root_buf.' | wincmd w | exe "bu ".b:diff_root_buf'
  " if bufname(l:diff_root_buf) !~ '/$'
  "   windo setf directory
  " endif

  exec 'diffoff | bu '.b:diff_root_buf . ' | '.bufnr().'bd | diffthis'
  " call s:activate_dir_or_file(1)
  wincmd w
  exec 'diffoff | bu '.b:diff_root_buf . ' | '.bufnr().'bd | diffthis'
  " call s:activate_dir_or_file(1)
endfu

fu! s:diff_push_cursor_file()
  let l:fname = s:getline()
  let l:origdir=getbufinfo('%')[0]['variables']['dir']
  let l:difbuf = winbufnr(b:diff_companion)
  let l:tgtdir=getbufinfo(l:difbuf)[0]['variables']['dir']
  let l:newfpath=substitute(l:fname, '^'.l:origdir.'/', l:tgtdir.'/', '')
  let l:fl = readfile(l:fname, "b")
  if filereadable(l:newfpath)
    " if input('Overwrite '.l:newfpath.' ? [y/N]') !~ 'y'
    unsilent echo 'Overwrite '.l:newfpath.' ? [y/N]'
    if nr2char(getchar()) !~ 'y'
      return
    endif
    redraw!
  endif
  call writefile(l:fl, l:newfpath, "b")
  wincmd w
  call s:ListUpdate('')
  wincmd w
endfu

fu! s:_exestr_w_diff_propagation(str)
   return 'if exists("b:diff_companion") <bar> wincmd w <bar> '.a:str.' <bar> wincmd w <bar> endif <bar> '.a:str
endfu

function! s:jump_tab_close()
  let s:last_file=s:get_fname_line()
  autocmd WinLeave <buffer> bd
  call s:tabnew(s:last_file)
endfu
function! s:tabnew(fname)
  if exists('GoToBuffer')  " see buffers.vim
    exe 'GoToBuffer '.a:fname
  else
    exe 'tabnew '.a:fname
  endif
endfu

function! s:get_fname_line()
  let l:fname=s:_getline_('.')
  let l:fname=substitute(l:fname, '[^ ]* \(.*\)', '\1','')
  let l:fname=escape(l:fname,"'".' "\')
  if exists('b:dir')
    let l:fname=b:dir.'/'.l:fname
  endif
  return l:fname
endfu

function! s:format_fname_line(val)
  if ! file_readable(expand(v:val))
    let l:val='× '.v:val
  else
    let l:val=substitute(v:val,'.*/\([^/]*\)','\1','').' '.v:val
  endif
  return l:val
endfunction

"@function find#ref_win_do(cmd, back=0 or 1)
"Function to jump to the window related to the listing window. 
function! find#ref_win_do(cmd, back)
  if get(b:, '_ref_window', 0)
    if a:back == 1
        let l:cur_win=win_getid()
    endif
    call win_gotoid(b:_ref_window)
    call execute(a:cmd)
    if a:back == 1
      call win_gotoid(l:cur_win)
    endif
  endif
endfunction




"}}}


""
" Update the buffer in order to show the results 
" of s:Find  i.e. the files matching the filter
function! s:ListUpdate(filter, grep)
  if get(b:,'_find_buffer',0)
    call s:clearlines()
    let b:filter = a:filter
    let b:grep = a:grep
    let l:res = s:Find(b:dir, g:find_max_depth, a:filter, a:grep)
    call s:check_fname_conceal(l:res)
    let l:head= ['Dir : '.b:dir]
    call extend(l:head, [
          \  s:automapping('jump_close', ":call <SID>edit_cursor_file()<cr>"),
          \  s:automapping('innewtab',":silent exe 'tabnew '.<SID>getline()<cr>gTdd"),
          \ ])
    if exists('t:diff')
      call extend(l:head, [
          \  s:automapping('diff_push_file',":silent call <SID>diff_push_cursor_file()<cr>"),
          \])
    else
      call s:automapping('vsplit',":silent call <SID>open('vsplit')<cr>")
      call s:automapping('hsplit',":silent call <SID>open('split')<cr>")
      call extend(l:head, [
          \  s:automapping('jump_tab_close',":call <SID>jump_tab_close()<cr>"),
          \  s:automapping('jump',":silent call <SID>open('preview')<cr>"),
          \  s:automapping('search_parent',":silent call <SID>chdir('..') <bar> call <SID>ListUpdate(b:filter, b:grep)<cr>"),
          \ ])
    endif
    call extend(l:head, [
          \  s:automapping('grep',":call setreg('/', input('Grep ? ')) <bar> ".s:_exestr_w_diff_propagation("silent call <SID>ListUpdate(b:filter, getreg('/'))")."<cr>"),
          \  s:automapping('filter',":let t:find_filter_input = input('Filter ? ') <bar> ".s:_exestr_w_diff_propagation("silent call <SID>ListUpdate(t:find_filter_input, b:grep)")."<cr>"),
          \  s:automapping('close',':'.s:_exestr_w_diff_propagation('q').'<cr>'),
          \  s:header_separator])
    call setline(1, l:head + l:res)
    if exists('t:diff_root_buf_linenr')
        exe max([len(l:head) + 1, min([t:diff_root_buf_linenr, line('$')])])
      else
        exe len(l:head) + 1
    endif
  endif
endfunction

function! s:ListFileCmdUpdate(filter)
  if get(b:,'_find_buffer',0)
    call s:automapping('vsplit',":call <SID>open('split', 'vertical rightbelow')<cr>")
    call s:automapping('hsplit',":call <SID>open('split')<cr>")
    call s:clearlines()
    let l:lines = split(execute(b:_find_buffer_cmd), "\n")
    call map(l:lines, "substitute(v:val, b:_find_buffer_cmd_parsing_pattern, '\\1','')")
    let l:lines = s:filter(l:lines, a:filter)
    call s:check_fname_conceal(l:lines)
    call map(l:lines, '<SID>format_fname_line(v:val)')
    let l:head= ['Cmd : '.b:_find_buffer_cmd]
    call extend(l:head, [
          \  s:automapping('jump_close', ":exe 'e '.<SID>get_fname_line()<cr>"),
          \  s:automapping('jump_tab_close',":call <SID>jump_tab_close()<cr>"),
          \  s:automapping('innewtab',":exe 'tabnew '.<SID>get_fname_line()<cr>gTdd"),
          \  s:automapping('jump',":call <SID>open('preview')<cr>"),
          \  s:automapping('filter',":call <SID>ListFileCmdUpdate(input('Filter ? '))<cr>"),
          \  s:automapping('close',':q<cr>'),
          \  s:header_separator])
    call setline(1, l:head + l:lines)
    exe len(l:head) + 1
  endif
endfunction

function! s:ListCmdUpdate(filter)
  if get(b:,'_find_buffer',0)
    let l:cur_win=win_getid()
    let l:win_changed=0
    let b:filter=a:filter
    let l:cmd = b:_find_buffer_cmd
    if get(b:, '_ref_window', 0)
      let l:win_changed=1
      call win_gotoid(b:_ref_window)
    endif
    let l:lines = split(execute(l:cmd),"\n")
    if l:win_changed
      call win_gotoid(l:cur_win)
    endif
    let l:d = b:_find_buffer_cmd_dict
    let l:lines = filter(l:lines, "v:val =~ '".escape(l:d['in_format'],"'")."'")
    let l:lines = map(l:lines, "substitute(v:val,l:d['in_format'],l:d['out_format'],'')")
    let l:lines = filter(l:lines, "v:val =~ '.*".escape(a:filter,"'").".*'")
    if has_key(l:d, 'sorted')
       call sort(l:lines, l:d['sorted'])

    endif
    if get(l:d, 'opts', '') =~ '.*reverse.*'
      call reverse(l:lines)
    endif
    let l:au=''
    let l:curline=0
    if get(l:d, 'opts', '') =~ '.*autoupdate.*'
       let l:curline=line('.')
       let l:au=' <bar> if win_getid() == '.l:cur_win.' <bar> call <SID>ListCmdUpdate(b:filter) <bar> endif'
    endif
    call s:clearlines()
    " todo separate jump when no jump possible
    let l:head= ['Cmd : '.b:_find_buffer_cmd]


    if len(get(l:d, 'commands', [])) > 0 
      for l:c in l:d['commands']
        let l:jump_cmd="substitute(<SID>getline(),'"
              \. substitute(l:d['param_parsing'],"'","''",'g')
              \."','". substitute(substitute(l:c[1],"'", "''", 'g'),'\\1','\\1','g')
              \."','')"
        call add(l:head, s:automapping(l:c[0], ':exe '.l:jump_cmd.l:au.'<Cr>'))
      endfor
    elseif len(get(l:d, 'exec', '')) > 0
      let l:jump_cmd="substitute(<SID>getline(),'"
            \. substitute(l:d['param_parsing'],"'","''",'g')
            \."','". substitute(escape(l:d['exec'],"'"),'\\1','\\1','g')
            \."','')"
      call add(l:head, s:automapping('exec', ":exe ".l:jump_cmd.l:au."<Cr>"))
    endif

    call extend(l:head, [
          \  s:automapping('filter', ":call <SID>ListCmdUpdate(input('Filter ? '))<Cr>"),
          \  s:automapping('close',':q<cr>'),
          \  s:header_separator])
    call setline(1, l:head + l:lines)
    exe max([len(l:head) + 1, min([l:curline, line('$')])])
  endif
endfunction

function! s:get_saddest_vim_find_impl(basedir, dir, depth, filter)
  let l:ret=[]
  let l:retdirs=[]
  for l:i in globpath(a:dir,'*', get(g:, 'find_disable_wildignore', 0) ,1)
    if isdirectory(l:i)
      if a:depth > 0
        call extend(l:retdirs ,s:get_saddest_vim_find_impl(a:basedir,l:i,a:depth-1, a:filter))
      else
        let l:i=substitute(l:i,a:basedir.'/*','','')
        call add(l:retdirs, l:i.'/')
      endif
    else
      let l:addinfo = ''
      let l:i=substitute(l:i,a:basedir.'/*','','')
      call add(l:ret, l:i.l:addinfo)
    endif
  endfor
  call extend(l:ret, l:retdirs) " files before directories
  return s:filter(l:ret, a:filter)
endfunction

""
" Find files in dir matching the filter
" basedir is used to construct relative path
"
function! s:Find(basedir, depth, filter, grep)
  if has("win32")
    return s:get_saddest_vim_find_impl(a:basedir, a:basedir, a:depth, a:filter)
    " maybe you deserve it
  endif

  let l:ret=[]
  let l:disable_wildignore = get(g:, 'find_disable_wildignore', 0)
  let l:use_cache = !get(g:, 'find_use_no_cache', 0)
  let l:build_cmd = 1
  if l:use_cache
      let l:cache_file = g:find_cache_dir.'/'.sha256(substitute(l:disable_wildignore.a:basedir.a:depth, '/', '_', 'g'))
      if filereadable(l:cache_file)
          let l:build_cmd = 0
      endif
  endif

  if l:build_cmd
      let l:wildignore=''
      if !l:disable_wildignore
        let l:wildignore=''
        for l:i in split(&wildignore, ',')
          if l:i =~ '\*'
            if l:i =~ '/'
                let l:ignore='-path "*/'.escape(l:i, '"').'"'
            else
                let l:ignore='-name "'.escape(l:i, '"').'"'
            endif
          else
            let l:ignore='-path "*/'.escape(l:i, '"').'"'
          endif
          let l:wildignore.=' ! '.l:ignore
        endfor
      endif
      let l:sorted_find = 'find ' . a:basedir . " -maxdepth " . a:depth . " -type f "
                  \ . l:wildignore . " -printf '" . '%h\0%d\0%p\n' . "'"
                  \ . " | sort -t '".'\0'."' -n"
                  \ . " | awk -F '" . '\0' . "' '" . '{print $3}' . "'"
  endif

  if l:use_cache
      if l:build_cmd
          call system(l:sorted_find." > ".l:cache_file)
      endif
      let l:sorted_find = "cat ". l:cache_file
  endif

  if len(a:grep) > 0
    let l:sorted_find .= " | xargs grep -l '".escape(a:grep, "'")."'"
  endif
  if get(t:, 'diff', 0) 
    let l:sorted_find .= " | xargs sum -s | awk -F ' ' '".'{print $3 " $" $1}'."'"
  endif
  let l:sorted_find .= " | sed 's|".a:basedir."/*||' 2> /dev/null"
  let l:ret = []
  let l:cur_dir = ""
  let l:prev_dir = ""
  let l:show_dirs = len(a:grep) == 0
  " unsilent echo l:sorted_find
  for l:i in systemlist(l:sorted_find)
    if l:show_dirs && l:i =~ '/'
      let l:cur_dir=substitute(l:i, '/[^/]*$', '/', '')
      if l:prev_dir != l:cur_dir
        call add(l:ret, l:cur_dir)
      endif
    endif
    call add(l:ret, l:i)
    let l:prev_dir=l:cur_dir
  endfor
  return s:filter(l:ret, a:filter)
endfunction

" ~~~ LIST FILE ~~~

"@command List <dir> [<filter> [& [!]<filter>]] 
"Show a recursive list of the directory in args, with optionnal filters:
"  - a filter is a pattern like useable in =~ expression
"  - pattern shall be cumulated with '&'
"  - '!<filter>' invert the filter
command! -nargs=* -complete=file List :call find#List(<f-args>)

"@command ListHere
"(see List) List directory of the current file
command! -nargs=* ListHere :call find#List(expand('%:p:h'), <q-args>)

augroup FindExploreListFile
  autocmd! Filetype directory  call <SID>activate_dir_or_file(1)
  autocmd! BufReadCmd */  if isdirectory(expand('%:p')) | setf directory | endif
augroup END

" ~~~ LIST VIM ELEMENTS : buffers, tabs, mark, history, ... ~~~
"@command  ListOld [<filter>]
"List old files
command! -nargs=* ListOld :call find#ListFileCmd('oldfiles','\s*\d\+\s*:\s*\(.*\)\s*.*',<f-args>)

"@command ListSyntaxFiles [<filter>]
"List syntax files
command! -nargs=* ListSyntaxFiles :call find#ListFileCmd(
      \ 'echo  globpath(&rtp,''syntax/'.&ft.'.vim'')','\(.*\)', <f-args>)

"@command ListBuffers [<filter>]
"List buffers
command! -nargs=* ListBuffers :call find#ListCmd('buffers', {
      \ 'in_format': '\s*\(\d\+\).*"\(.*\)".*',
      \ 'out_format':'\=printf("%-2s %s", submatch(1),substitute(submatch(2), "\\(-\\w\\w\\w\\w\\)\\w*/", "\\1/", ""))',
      \ 'sorted': {i1, i2 -> substitute(i1,'^\s*\d\+\s*',"", "") ># substitute(i2,'^\s*\d\+\s*',"", "") },
      \ 'opts': 'autoupdate',
      \ 'param_parsing':'^\s*\(\d\+\).*',
      \ 'commands': [['open_buffer', 'call find#ref_win_do("bu \1", 1)'], ['kill_buffer', '\1bd']] +
      \             (exists(':GoToBuffer') ? [['go', 'GoToBuffer \1']] : [])
      \ }, <f-args>)

"@command ListTabs [<filter>]
"List tabs
command! -nargs=* ListTabs :call find#ListCmd("echo substitute(execute('tabs'), '\n[ >#]', '', 'g')", {
      \ 'opts': 'autoexit',
      \ 'param_parsing': '^[a-zA-Z]\+ \(\d\+\).*',
      \ 'commands': [['go', 'norm \1gt']]}, <f-args>)

"@command ListMarks [<filter>]
"List marks
command! -nargs=* ListMarks :call find#ListCmd('marks', {
      \ 'in_format': '\s*\(\d\)\s\+\d\+\s\+\d\+\(.\+\)',
      \ 'out_format': '\=printf("%-4s %s",submatch(1),submatch(2))', 
      \ 'param_parsing': '\(\d\+\).*',
      \ 'commands': [['go', 'norm `\1']]},<f-args>)

"@command ListSearchHistory [<filter>]
"List search history
command! -nargs=* ListSearchHistory :call find#ListCmd('history /', {
      \ 'in_format': '\s*\d\+\s*\(.*\)\s*.*',
      \ 'opts': 'reverse',
      \ 'exec': 'windo /\1'}, <f-args>)

"@command ListCmdHistory [<filter>]
"List command history
command! -nargs=* ListCmdHistory :call find#ListCmd('history :', {'<': '\s*\d\+\s*\(.*\)\s*.*', 'o': 'reverse', ':': '\1'}, <f-args>)

"@command ListHi [<filter>]
"List syntax color elements (:hi)
command! -nargs=* ListHi :call find#ListCmd('hi', {'<': '\(.*\)', 'o': 'reverse', 'param_parsing': '\(.*\)\sxxx.*', ':': 'hi \1'}, <f-args>)

"@command ListSyntax [<filter>]
"List syntax for the current filetype (:syntax)
command! -nargs=* ListSyntax :call find#ListCmd('syntax', {'o': 'ft=vim'}, <f-args>)

"@command ListAutoCmd [<filter>]
"List syntax color elements (:au)
command! -nargs=* ListAutoCmd :call find#ListCmd('au', {'o': 'ft=vim'}, <f-args>)

"@command ListKeyMap [<filter>]
"List keymapping (:map command)
command! -nargs=* ListKeyMap :call find#ListCmd('map', {'o': 'ft=vim'},<f-args>)

"@command ListCommands [<filter>]
"List commands (:command command)
command! -nargs=* ListCommands :call find#ListCmd('command',  {'o': 'ft=vim', '<(': '\(.*\)(.*'}, <f-args>)

"@command ListFunctions [<filter>]
"List commands (:function command)
command! -nargs=* ListFunctions :call find#ListCmd('function', {'<': 'function \(.*\)', 'o': 'ft=vim', '<(': '\(.*\)(.*', ':': 'function \1'},<f-args>)

"@command ListColors [<filter>]
"List colorscheme (:colors command)
command! -nargs=* ListColors :call find#ListCmd('echo  globpath(&rtp,''colors/*.vim'')', {'<': '.*/\(.*\).vim', ':': (exists(':SetColorScheme')?'SetColorScheme': 'colorscheme').' \1'}, <f-args>)



" ~~~ GREP ~~
" Enhanced lgrep (grep with location window)
"
" add :
"   g:find_related_file_extensions  to rename grep_related_file_extensions
"
" (only) require:
"   g:find_keymapping
"   g:find_action_desc
"   s:automapping (with s:key_desc)
"


"@global g:find_related_file_extensions
" map filetypes relations
" default: { 'cpp': ['cpp', 'hpp'], 'hpp': ['cpp', 'hpp'] }
let g:find_related_file_extensions=get(g:,'find_related_file_extensions',{
      \ 'cpp': ['cpp', 'hpp'],
      \ 'hpp': ['cpp', 'hpp']
      \ })

fu! s:_add_related_file_extension(ext)
  call add(b:find_related_file_extensions, a:ext)
endfu
fu! s:_rm_related_file_extension(ext)
  let l:idx=index(b:find_related_file_extensions, a:ext)
  if l:idx != -1
    call remove(b:find_related_file_extensions, l:idx)
  endif
endfu
fu! s:_set_related_file_extension(...)
  let l:mode='_default_add_'
  let l:args=[]
  let l:w=''
  for l:a in a:000
    for l:c in split(l:a, '\zs')
      if l:c == '+' || l:c == '-'
        call add(l:args, l:c)
        if len(l:w) > 0
          call add(l:args, l:w)
          let l:w=''
        endif
      else
        let l:w.=l:c
      endif
    endfor
  endfor
  if len(l:w) > 0
    call add(l:args, l:w)
    let l:w=''
  endif
  for l:a in l:args
    if l:a == '+' || l:a == '-'
      let l:mode=l:a
    elseif l:a =='define'
      let b:find_related_file_exensions = []
      let l:mode = '+'
    elseif l:mode == '_default_add_'
      let b:find_related_file_extensions = get(g:find_related_file_extensions, &ft, [])
      call s:_add_related_file_extension(l:a)
      let l:mode = '+'
    elseif l:mode == '+'
      call s:_add_related_file_extension(l:a)
    elseif l:mode == '-'
      call s:_rm_related_file_extension(l:a)
    endif
  endfor
  echo b:find_related_file_extensions
endfu
function! s:CompleteRelatedFileExtension(argstart, cmdline, cursorpos)
  return get(b:,'find_related_file_extensions', []) + ['+', '-']
endfunction
fu! s:_get_related_file_extensions(ext)
  let l:res=get(b:,'find_related_file_extensions', get(g:find_related_file_extensions, &ft, []))
  if !len(l:res)
    if len(a:ext)
      call add(l:res, a:ext)
      if len(&ft) && a:ext != &ft
        call add(l:res, &ft)
      endif
    endif
  endif
  return l:res
endfu

"@function find#Grep(arg, dir, ...)
"Function used for Grep*, check examples.
fu! find#Grep(arg, dir,...)
  if !len(a:dir) 
    return
  endif
  let l:grep_opt_dict=get(b:, 'grep_opt_dict', {})
  let l:orig_file=get(b:, 'orig_file', get(l:grep_opt_dict, 'file',expand('%')))
  let l:orig_ext=get(b:, 'orig_ext', get(l:grep_opt_dict, 'ext',  stridx(l:orig_file, '.') > 0 ? substitute(l:orig_file, '^.*\.\([^.]*\)', '\1','') : ''))
  let l:arg=get(b:, 'grep_name', a:arg)
  let l:dir=expand(a:dir)
  let l:filetypes = []
  let l:parent_dir=substitute(l:dir, '\/[^/]*\/\?$', '', '')
  if has("win32")
    "assuming findstr
    let l:grep_opt='/s'
  else
    "assuming grep
    let l:grep_opt='-r'
    if len(a:000) == 1
      let l:grep_opt_dict=a:1
      if type(l:grep_opt_dict) == type("")
        if l:grep_opt_dict =~ ':'
          let l:grep_opt_dict=eval(l:grep_opt_dict)
        elseif l:grep_opt_dict == '*'
          let l:grep_opt_dict={'filetypes':[]}
        elseif len(l:grep_opt_dict) > 0
          let l:grep_opt_dict={'filetypes':split(l:grep_opt_dict, ',')}
        endif
      endif
    endif
    if isdirectory(l:dir)
      let l:filetypes=get(l:grep_opt_dict, 'filetypes', s:_get_related_file_extensions(l:orig_ext))
      for l:ft in l:filetypes
        if len(l:ft)
          let l:grep_opt.=" --include='*.".l:ft."'"
        endif
      endfor
    endif
  endif
  let l:open=get(l:grep_opt_dict, 'open', 'tabnew')

  let l:origwin=0
  " if a:dir != expand('%') && (line('$') != 1 || !empty(getline(1)))
  if (line('$') != 1 || !empty(getline(1)))
      let l:curbuf=bufnr('.')
      let l:origwin=win_getid()
      exe l:open
      let l:newwin=win_getid()
      if l:open =~ 'new' | exe 'bu '.l:curbuf | endif
  endif
  try
    exe 'silent! lgrep '.l:grep_opt.' "'.escape(l:arg, '"').'" '.a:dir
  catch /E480:/
    echo v:exception
    if win_gotoid(l:newwin) | close | endif | win_gotoid(l:origwin)
    return
  endtry
  if len(getloclist(winnr())) == 0
    if win_gotoid(l:newwin) | close | endif | win_gotoid(l:origwin)
  else
    lopen
    setlocal switchbuf=useopen
    let b:grep_opt_dict=l:grep_opt_dict
    let b:grep_name=l:arg
    let b:grep_dir=l:dir
    let b:find_related_file_extensions=l:filetypes
    let b:orig_file=l:orig_file
    let b:orig_ext=l:orig_ext
    let b:_keymapping=s:find_keymapping
    let b:_action_desc=s:find_action_desc
    let l:statusline= s:automapping('search_parent',":call find#Grep('".escape(b:grep_name,"'")."','".l:parent_dir."')<cr>", 0).'  '
    let l:statusline.=s:automapping('jump',":.ll<cr>", 0).'  '
    let l:statusline.=s:automapping('jump_close',":.ll<cr>:lclose<cr>", 0).'  '
    let l:statusline.=s:automapping('close',':lclose<cr>'.(l:origwin?':q<cr>:call win_gotoid('.l:origwin.')<cr>':''), 0).'  '
    let l:statusline.=s:automapping('reload',":call find#Grep('".escape(b:grep_name,"'")."','".l:dir."')<cr>", 0)
    setlocal cursorline
    exe "setlocal statusline=".substitute(substitute(l:statusline,
          \'\([^ ]\+\)\('.s:find_panel_style['sep_inline'].'\)\(\w*\)', '%#MoreMsg#\1%#Comment#\2\3','g'),
          \' ','\\ ','g')
  endif
  redraw!
  echo l:dir.' '.join(l:filetypes, ' ')
endfu

" FIXME below expand() are useless because already expanded in Grep

"@command Grep <dir> <pattern>
" Grep ...
command! -nargs=* -complete=file Grep :call find#Grep(<f-args>)

"@command GrepHere <pattern>
" Grep in directory related to current file
command! -nargs=1 GrepHere :call find#Grep( <q-args>, expand('%:p:h'))

"@command VGrepHere <pattern>
" GrepHere in another window in order to explore without hidden current buffer
command! -nargs=1 VGrepHere :call find#Grep(<q-args>, expand('%:p:h'), {'open': 'vertical rightbelow split'})

"@command GrepFile <pattern>
" grep a pattern in current file
command! -nargs=1 GrepFile :call find#Grep(<q-args>, expand('%:p'))

"@command GrepSetF <filetype>
" add allowed filetype to search with grep (this update b:find_related_file_extensions)
command! -nargs=* -complete=customlist,<SID>CompleteRelatedFileExtension GrepSetF :call <SID>_set_related_file_extension(<f-args>)
