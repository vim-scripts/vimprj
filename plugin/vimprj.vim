

try
   call vimprj#init()

   if exists(':VimprjInfo') != 2
      command -nargs=? -complete=file VimprjInfo call vimprj#info()
   endif
catch
   " for some reason, vimprj plugin can't be initialized
endtry

