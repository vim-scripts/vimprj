

if v:version < 700
   call confirm("vimprj: You need Vim 7.0 or higher")
   finish
endif

" Dependencies

let s:iDfrankUtil_min_version = 100

" Dependency functions

function! <SID>GetVersionString(iVersion)
   let l:iLen = strlen(a:iVersion)
   return strpart(a:iVersion, 0, l:iLen - 2).'.'.strpart(a:iVersion, l:iLen - 2)
endfunction

function! <SID>CheckCompatibility(sCurPluginName, sDepPluginName, sDepPluginVerVar, iDepPluginNeededVer)
   let l:iDepPluginCurVer = -1
   let l:dRes = {'boolCompatible' : 0, 'msg' : ''}

   if exists(a:sDepPluginVerVar)
      exec ('let l:iDepPluginCurVer = '.a:sDepPluginVerVar)
   endif

   if l:iDepPluginCurVer < a:iDepPluginNeededVer
      let l:dRes.boolCompatible = 0

      if !exists('s:'.a:sCurPluginName.a:sDepPluginName.'_warning_shown')
         let l:sMsg = a:sCurPluginName." error: you need for plugin '".a:sDepPluginName."' version ".<SID>GetVersionString(a:iDepPluginNeededVer)." to be installed, but "
         if l:iDepPluginCurVer > 0
            let l:sMsg .= "your current version of '".a:sDepPluginName."' is ".<SID>GetVersionString(l:iDepPluginCurVer)
         else
            let l:sMsg .= "you have not currently '".a:sDepPluginName."' installed."
         endif
         exec 'let s:'.a:sCurPluginName.a:sDepPluginName.'_warning_shown = 1'
         let l:dRes.msg = l:sMsg
      endif
   else
      let l:dRes.boolCompatible = 1
      " versions are compatible
   endif

   return l:dRes

endfunction


" CHECK DEPENDENCY: DfrankUtil

try
   call dfrank#util#init()
catch
   " no DfrankUtil plugin installed
endtry

let s:sDfrankUtilCompatibility = <SID>CheckCompatibility(
         \     "Vimprj", 
         \     "DfrankUtil", 
         \     "g:dfrank#util#version", 
         \     s:iDfrankUtil_min_version
         \  )

if !s:sDfrankUtilCompatibility.boolCompatible
   if !empty(s:sDfrankUtilCompatibility.msg)
      call confirm(s:sDfrankUtilCompatibility.msg)
   endif
   let s:boolNeedFinish = 1
endif

" -----


if exists("s:boolNeedFinish")
   finish
endif


" all dependencies is ok

let g:vimprj#version           = 106
let g:vimprj#loaded            = 1

let s:boolInitialized          = 0


" ************************************************************************************************
"                                          PUBLIC FUNCTIONS
" ************************************************************************************************

function! vimprj#info()
   let l:sProjectRoot = g:vimprj#dRoots[ g:vimprj#sCurVimprjKey ].proj_root
   echo '* Project root: '
            \  .(l:sProjectRoot != '' ? l:sProjectRoot : 'not found')
            \  .'  (Project root is a directory which contains "'
            \  .g:vimprj_dirNameForSearch.'" directory or file)'
endfunction

" applies all settings from .vimprj dir
function! vimprj#applyVimprjSettings(sVimprjKey)

   call <SID>_AddToDebugLog(s:DEB_LEVEL__ALL, 'function start: __ApplyVimprjSettings__', {'sVimprjKey' : a:sVimprjKey})
   "call confirm ("vimprj#applyVimprjSettings ".a:sVimprjKey)

   call <SID>SourceVimprjFiles(g:vimprj#dRoots[ a:sVimprjKey ]["path"])
   call <SID>ChangeDirToVimprj(g:vimprj#dRoots[ a:sVimprjKey ]["cd_path"])

   " для каждого проекта, в который входит файл, добавляем tags и path

   call <SID>_AddToDebugLog(s:DEB_LEVEL__ALL, 'function end: __ApplyVimprjSettings__', {})
endfunction

function! vimprj#getVimprjKeyOfFile(iFileNum)
   return g:vimprj#dFiles[ a:iFileNum ]['sVimprjKey']
endfunction


" задаем пустые массивы с данными
function! vimprj#init()
   if s:boolInitialized
      return
   endif

   "echoerr "initing"

   let s:DEB_LEVEL__ASYNC  = 1
   let s:DEB_LEVEL__PARSE  = 2
   let s:DEB_LEVEL__ALL    = 3

   if !exists('g:vimprj_recurseUpCount')
      let g:vimprj_recurseUpCount = 10
   endif

   if !exists('g:vimprj_dirNameForSearch')
      let g:vimprj_dirNameForSearch = '.vimprj'
   endif

   if !exists('g:vimprj_changeCurDirIfVimprjFound')
      let g:vimprj_changeCurDirIfVimprjFound = 1
   endif


   " задаем пустые массивы с данными
   let g:vimprj#dRoots = {}
   let g:vimprj#dFiles = {}
   let g:vimprj#iCurFileNum = 0
   let g:vimprj#sCurVimprjKey = 'default'

   " -- hooks --
   "  You can look example of using this hooks in plugin Indexer ( http://goo.gl/KbPoA )

   let g:vimprj#dHooks = {
            \     'NeedSkipBuffer'       : {},
            \     'OnAddNewVimprjRoot'   : {},
            \     'SetDefaultOptions'    : {},
            \     'OnTakeAccountOfFile'  : {},
            \     'OnFileOpen'           : {},
            \     'OnBufSave'            : {},
            \     'ApplySettingsForFile' : {},
            \  }

   " указываем обработчик открытия нового файла: OnFileOpen
   augroup Vimprj_LoadFile
      autocmd! Vimprj_LoadFile BufReadPost
      autocmd! Vimprj_LoadFile BufNewFile
      autocmd Vimprj_LoadFile BufReadPost * call <SID>OnFileOpen(bufnr(expand('<afile>')))
      autocmd Vimprj_LoadFile BufNewFile *  call <SID>OnFileOpen(bufnr(expand('<afile>')))
   augroup END

   " указываем обработчик входа в другой буфер: OnBufEnter
   augroup Vimprj_BufEnter
      autocmd! Vimprj_BufEnter BufEnter
      autocmd Vimprj_BufEnter BufEnter * call <SID>OnBufEnter(bufnr(expand('<afile>')))
   augroup END

   augroup Vimprj_BufWritePost
      autocmd! Vimprj_BufWritePost BufWritePost
      autocmd Vimprj_BufWritePost BufWritePost * call <SID>OnBufSave()
   augroup END

   let s:boolInitialized = 1

endfunction

" ************************************************************************************************
"                                       PRIVATE FUNCTIONS
" ************************************************************************************************



" Парсит директорию проекта (директорию, в которой лежит директория .vimprj)
" Добавляет новый vimprj_root
"
" @param sProjectRoot path to proj dir
"
function! <SID>ParseNewVimprjRoot(sProjectRoot)

   let l:sVimprjDirName = a:sProjectRoot.'/'.g:vimprj_dirNameForSearch

   " if dir .vimprj exists, and if this vimprj_root has not been parsed yet 

   if isdirectory(l:sVimprjDirName) || filereadable(l:sVimprjDirName)
      let l:sVimprjKey = dfrank#util#GetKeyFromPath(a:sProjectRoot)
      if !has_key(g:vimprj#dRoots, l:sVimprjKey)


         call <SID>SourceVimprjFiles(l:sVimprjDirName)
         call <SID>ChangeDirToVimprj(substitute(a:sProjectRoot, ' ', '\\ ', 'g'))

         call <SID>AddNewVimprjRoot(l:sVimprjKey, a:sProjectRoot, a:sProjectRoot)


      endif
   else
      echoerr "<SID>ParseNewVimprjRoot error: there's no ".g:vimprj_dirNameForSearch
               \  ." dir in the project dir '".a:sProjectRoot."'"
   endif

endfunction


function! <SID>CreateDefaultProjectIfNotAlready()
   if !has_key(g:vimprj#dRoots, "default")
      " создаем дефолтный "проект"
      call <SID>AddNewVimprjRoot("default", "", getcwd())
      call <SID>TakeAccountOfFile(0, 'default')
   endif
endfunction

function! <SID>TakeAccountOfFile(iFileNum, sVimprjKey)
   "call confirm('TakeAccountOfFile '.a:iFileNum.' '.a:sVimprjKey)

   if !has_key(g:vimprj#dFiles, a:iFileNum)
      let g:vimprj#dFiles[ a:iFileNum ] = {}
   endif

   if a:iFileNum > 0
      let l:sFilename = dfrank#util#BufName(a:iFileNum)
   else
      let l:sFilename = ""
   endif
   
   let g:vimprj#dFiles[ a:iFileNum ]['sVimprjKey'] = a:sVimprjKey
   let g:vimprj#dFiles[ a:iFileNum ]['sFilename']  = l:sFilename

   call <SID>ExecHooks('OnTakeAccountOfFile', {
            \     'iFileNum'   : a:iFileNum,
            \  })
endfunction


" sets
"    g:vimprj#iCurFileNum     ( from bufnr('%') )
"    g:vimprj#sCurVimprjKey   ( from g:vimprj#dFiles )
function! <SID>SetCurrentFile(iFileNum)

   call <SID>_AddToDebugLog(s:DEB_LEVEL__ALL, 'function start: __SetCurrentFile__', {'filename' : expand('<afile>')})

   let g:vimprj#iCurFileNum   = a:iFileNum
   let g:vimprj#sCurVimprjKey = g:vimprj#dFiles[ g:vimprj#iCurFileNum ].sVimprjKey

   call <SID>_AddToDebugLog(s:DEB_LEVEL__ALL, 'function end: __SetCurrentFile__', {'text' : ('g:vimprj#iCurFileNum='.g:vimprj#iCurFileNum.'; g:vimprj#sCurVimprjKey='.g:vimprj#sCurVimprjKey)})

endfunction



function! <SID>_AddToDebugLog(iLevel, sType, dData)
   "call confirm (a:sType)
endfunction

function! <SID>ExecHooks(sHooksgroup, dParams)
   "echoerr a:sHooksgroup
   "call confirm("ExecHooks ".a:sHooksgroup)
   let l:lRetValues = []
   let l:dParams = a:dParams

   if !has_key(g:vimprj#dHooks, a:sHooksgroup)
      echoerr "No hook group ".a:sHooksgroup
      return 
   endif

   for l:sKey in keys(g:vimprj#dHooks[ a:sHooksgroup ])
      "call confirm("-- ".l:sKey)


      silent! let l:dParams['dVimprjRootParams'] = 
                  \  g:vimprj#dRoots[g:vimprj#sCurVimprjKey][ l:sKey ]

      "try
         "call add(l:lRetValues, g:vimprj#dHooks[ a:sHooksgroup ][ l:sKey ](l:dParams))
      "catch

         "" workaround for old buggy Vim version.
         "" don't know what exactly version contains fix for this.

         let l:tmp = g:vimprj#dHooks[ a:sHooksgroup ][ l:sKey ](l:dParams)
         call add(l:lRetValues, l:tmp)
         unlet l:tmp

      "endtry

      silent! unlet l:dParams['dVimprjRootParams']



   endfor
   return l:lRetValues
endfunction


" добавляет новый vimprj root, заполняет его текущими параметрами
"
" ВНИМАНИЕ! "текущими" параметрами - это означает, что на момент вызова
" этого метода все .vim файлы из .vimprj уже должны быть выполнены!
function! <SID>AddNewVimprjRoot(sVimprjKey, sPath, sCdPath)

   if !has_key(g:vimprj#dRoots, a:sVimprjKey)

      call <SID>_AddToDebugLog(s:DEB_LEVEL__PARSE, 'function start: __AddNewVimprjRoot__', {'sVimprjKey' : a:sVimprjKey, 'sPath' : a:sPath, 'sCdPath' : a:sCdPath})

      let g:vimprj#dRoots[a:sVimprjKey] = {}
      let g:vimprj#dRoots[a:sVimprjKey]["cd_path"] = a:sCdPath
      let g:vimprj#dRoots[a:sVimprjKey]["proj_root"] = a:sPath
      if (!empty(a:sPath))
         let g:vimprj#dRoots[a:sVimprjKey]["path"] = a:sPath.'/'.g:vimprj_dirNameForSearch
      else
         let g:vimprj#dRoots[a:sVimprjKey]["path"] = ""
      endif

      call <SID>ExecHooks('OnAddNewVimprjRoot', {'sVimprjKey' : a:sVimprjKey})

      call <SID>_AddToDebugLog(s:DEB_LEVEL__PARSE, 'function end: __AddNewVimprjRoot__', {})
   endif
endfunction




" returns if we should to skip this buffer ('skip' means not to generate tags
" for it)
function! <SID>NeedSkipBuffer(iFileNum)

   " COMMENTED!! file should be readable 
   " commented because of we should parse creation of new files,
   " which isn't readable at BufNewFile.
   "
   "if !filereadable(bufname(a:iFileNum))
      "return 1
   "endif

   " skip directories
   if isdirectory(bufname(a:iFileNum))
      return 1
   endif
   
   " &buftype should be empty for regular files
   if !empty(getbufvar(a:iFileNum, "&buftype"))
      return 1
   endif

   " buffer name should not be empty
   if empty(bufname(a:iFileNum))
      return 1
   endif


   let l:lNeedSkip = <SID>ExecHooks('NeedSkipBuffer', {
            \     'iFileNum' : a:iFileNum,
            \  })

   for l:boolCurNeedSkip in l:lNeedSkip
      if l:boolCurNeedSkip
         return 1
      endif
   endfor


   return 0
endfunction

function! <SID>SourceVimprjFiles(sPath)
   "call confirm("sourcing files from: ". a:sPath)
   
   call <SID>ExecHooks('SetDefaultOptions', {'sVimprjDirName' : a:sPath})

   if isdirectory(a:sPath)

      " sourcing all *vim files in .vimprj dir
      let l:lSourceFilesList = split(glob(a:sPath.'/*vim'), '\n')
      let l:sThisFile = expand('%:p')
      for l:sFile in l:lSourceFilesList
         exec 'source '.l:sFile
      endfor

   elseif filereadable(a:sPath)

      " sourcing just one specified file
      exec 'source '.a:sPath

   endif
endfunction

function! <SID>ChangeDirToVimprj(sPath)
   " переключаем рабочую директорию
   if (g:vimprj_changeCurDirIfVimprjFound)
      exec "cd ".a:sPath
      " ???? иначе не работает
      exec "cd ".a:sPath
   endif
endfunction

function! <SID>GetVimprjRootOfFile(iFileNum)

   let l:sFilename = dfrank#util#BufName(a:iFileNum) "expand('<afile>:p:h')
   let l:sDirname = dfrank#util#GetPathHeader(l:sFilename)

   let l:i = 0
   let l:sCurPath = ''
   let l:sProjectRoot = ''
   while (l:i < g:vimprj_recurseUpCount)
      let l:sTmp = simplify(l:sDirname.l:sCurPath.'/'.g:vimprj_dirNameForSearch)
      if isdirectory(l:sTmp) || filereadable(l:sTmp)

         " directory or file with needed name found
         let l:sProjectRoot = simplify(l:sDirname.l:sCurPath)
         break

      endif
      let l:sCurPath = l:sCurPath.'/..'
      let l:i = l:i + 1
   endwhile

   if !empty(l:sProjectRoot)

      " .vimprj directory or file is found.
      " проверяем, не открыли ли мы файл из директории .vimprj (или, если это
      " файл, то не открыли ли мы этот файл)

      let l:sPathToDirNameForSearch = l:sProjectRoot.'/'.g:vimprj_dirNameForSearch
      "let l:iPathToDNFSlen = strlen(l:sPathToDirNameForSearch)

      "if strpart(l:sFilename, 0, l:iPathToDNFSlen) == l:sPathToDirNameForSearch " открытый файл - из директории .vimprj, так что для него

      if dfrank#util#IsFileInSubdir(l:sFilename, l:sPathToDirNameForSearch)
         " НЕ будем применять настройки из этой директории.
         let l:sProjectRoot = ''
      endif

   endif

   if !empty(l:sProjectRoot)
      let l:sVimprjKey = dfrank#util#GetKeyFromPath(l:sProjectRoot)
   else
      let l:sVimprjKey = "default"
   endif

   return      {
            \     'sProjectRoot' : l:sProjectRoot,
            \     'sVimprjKey'   : l:sVimprjKey,
            \  }

endfunction

function! <SID>OnFileOpen(iFileNum)

   let l:iFileNum = a:iFileNum "bufnr(expand('<afile>'))

   "call confirm("OnFileOpen " . a:iFileNum . " " . bufname(a:iFileNum))


   call <SID>CreateDefaultProjectIfNotAlready()

   if (<SID>NeedSkipBuffer(l:iFileNum))
      return
   endif

   call <SID>_AddToDebugLog(s:DEB_LEVEL__PARSE, 'function start: __OnFileOpen__', {'filename' : expand('%')})


   "let l:sTmp = input("OnNewFileOpened_".getbufvar('%', "&buftype"))

   " actual tags dirname. If .vimprj directory will be found then this tags
   " dirname will be /path/to/dir/.vimprj/tags

   " ищем .vimprj
   let l:dTmp = <SID>GetVimprjRootOfFile(l:iFileNum)

   let l:sVimprjKey   = l:dTmp['sVimprjKey']
   let l:sProjectRoot = l:dTmp['sProjectRoot']

   " if file account is already taken, we should anyway parse it again,
   " because it happens at least at :saveas new_filename

   "if <SID>IsFileAccountTaken(l:iFileNum)
      "call confirm('file account is already taken '.dfrank#util#BufName(l:iFileNum))
   "endif

   unlet l:dTmp

   " if this .vimprj project is not known yet, then adding it.
   " otherwise just applying settings, if necessary.

   call <SID>TakeAccountOfFile(l:iFileNum, l:sVimprjKey)

   if !has_key(g:vimprj#dRoots, l:sVimprjKey)
      " .vimprj project is NOT known.
      " adding.

      " l:sProjectRoot can NEVER be empty here,
      " because it is empty only for 'default' sVimprjKey,
      " and this sVimprjKey is added when vim starts.
      call <SID>ParseNewVimprjRoot(l:sProjectRoot)

   else
      " .vimprj project is known.
      " if it is inactive - applying settings from it.
      if l:sVimprjKey != g:vimprj#sCurVimprjKey
         call vimprj#applyVimprjSettings(l:sVimprjKey)
      endif

   endif


   call <SID>SetCurrentFile(l:iFileNum)

   call <SID>ExecHooks('OnFileOpen', {
            \     'iFileNum'   : l:iFileNum,
            \  })

   if l:iFileNum == bufnr('%')
      call <SID>ExecHooks('ApplySettingsForFile', {
               \     'iFileNum'   : l:iFileNum,
               \  })
   else
      " need to switch back to %
      " (at least, it happens when ":w new_filename" at any NAMED file)

      "echoerr "returning to buffer ".bufname('%')." from ".bufname(l:iFileNum)

      call <SID>OnBufEnter(bufnr('%'))



      "if <SID>IsFileAccountTaken(bufnr('%'))
         "call <SID>OnBufEnter(bufnr('%'))
      "else
         "" for some reason (i dunno) it happens when from default project open
         "" [BufExplorer].
         "call <SID>OnFileOpen(bufnr('%'))
      "endif
   endif

   call <SID>_AddToDebugLog(s:DEB_LEVEL__PARSE, 'function end: __OnFileOpen__', {})
endfunction

" returns if buffer is changed (swithed) to another, or not
function! <SID>IsBufSwitched()
   return (g:vimprj#iCurFileNum != bufnr('%'))
endfunction

function! <SID>IsFileAccountTaken(iFileNum)
   return has_key(g:vimprj#dFiles, a:iFileNum)
endfunction


function! <SID>OnBufEnter(iFileNum)
   let l:iFileNum = a:iFileNum

   call <SID>CreateDefaultProjectIfNotAlready()

   if (<SID>NeedSkipBuffer(l:iFileNum))
      return
   endif

   "call confirm("OnBufEnter " . a:iFileNum . " " . bufname(a:iFileNum))

   call <SID>_AddToDebugLog(s:DEB_LEVEL__ALL, 'function start: __OnBufEnter__', {'filename' : expand('%')})

   if (!<SID>IsBufSwitched())
      return
   endif

   if !<SID>IsFileAccountTaken(l:iFileNum)
      "echoerr "not taken account of ".bufname(l:iFileNum)
      call <SID>OnFileOpen(l:iFileNum)
   endif

   let l:sPrevVimprjKey = g:vimprj#sCurVimprjKey
   call <SID>SetCurrentFile(l:iFileNum)

   " applying vimprj settings if only vimprj root changed
   if l:sPrevVimprjKey != g:vimprj#sCurVimprjKey
      call vimprj#applyVimprjSettings(g:vimprj#sCurVimprjKey)
   endif

   call <SID>ExecHooks('ApplySettingsForFile', {
            \     'iFileNum'   : l:iFileNum,
            \  })


   call <SID>_AddToDebugLog(s:DEB_LEVEL__ALL, 'function end: __OnBufEnter__', {})

endfunction

function! <SID>OnBufSave()
   let l:iFileNum = bufnr(expand('<afile>'))

   if !has_key(g:vimprj#dFiles, l:iFileNum)
      " saving file that wasn't parsed yet
      " (like  ":w new_filename" on any named or [No Name] file)

      call <SID>OnFileOpen(l:iFileNum)
   else

      if g:vimprj#dFiles[ l:iFileNum ]['sFilename'] != dfrank#util#BufName(l:iFileNum)
         " file is just renamed/moved
         " (like ":saveas new_filename")

         "call confirm('renamed. previous="'.g:vimprj#dFiles[ l:iFileNum ]['sFilename'].'" current="'.dfrank#util#BufName(l:iFileNum).'"')
         call <SID>OnFileOpen(l:iFileNum)

      else
         " usual file save
         call <SID>ExecHooks('OnBufSave', {
                  \     'iFileNum'   : l:iFileNum,
                  \  })
      endif

   endif
endfunction


if !s:boolInitialized
   call vimprj#init()
endif


