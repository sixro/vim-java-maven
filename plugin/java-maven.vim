" java-maven.vim - Java & Maven
" Author: Roberto Simoni <http://sixro.net>

if exists("g:loaded_javamaven") || &cp || v:version < 700
	finish
endif
let g:loaded_javamaven = 1

" ==  Globals  =================================================================
if !exists("g:javamaven_debug")
  let g:javamaven_debug = 0
endif


" ==  Autocmd(s)  ==============================================================
"
" Setup Maven when a java file is opened
autocmd filetype java :call <SID>MvnSetup()

" --  javacomplete  ------------------------------------------------------------
autocmd Filetype java setlocal omnifunc=javacomplete#Complete 
autocmd Filetype java setlocal completefunc=javacomplete#CompleteParamsInfo 


" ==  Mappings  ================================================================

" --  javacomplete  ------------------------------------------------------------
inoremap <buffer> <C-X><C-U> <C-X><C-U><C-P>
inoremap <buffer> <C-S-Space> <C-X><C-U><C-P> 


" ==  Commands  ================================================================
"
command! -nargs=* Mvn call <SID>Mvn(<f-args>)
command! MvnTest call <SID>MvnTest()

" --  alternate.vim  -----------------------------------------------------------
" Require open.vim plugin too
command! A  Open(alternate#FindAlternate())
command! AV OpenVertical(alternate#FindAlternate())
command! AS OpenHorizontal(alternate#FindAlternate())


" ==  Script function(s)  ======================================================

" --  MvnSetup  ----------------------------------------------------------------
" Searches for a pom.xml in parent directories and when it finds it, setup
" specific buffer variables (in this way, you can have multiple maven based
" projects opened at the same time):
"     * b:mvnPomDirectory ..: is the directory of the pom.xml
"                             Empty if no pom.xml has been found
"     * b:mvnPomFile .......: is the pom.xml related to the current buffer
"
function! <SID>MvnSetup()
  call <SID>debug("[java-maven] [MvnSetup] Setting up Maven in Vim...")

  let b:mvnPomDirectory = <SID>MvnPomDirectory()
  if empty(b:mvnPomDirectory)
    return
  endif

  let b:mvnPomFile = b:mvnPomDirectory . "/pom.xml"
  let b:mvnSourceDirectory = g:readPom(b:mvnPomFile, "sourceDirectory", "${basedir}/src/main/java")
  let b:mvnTestSourceDirectory = g:readPom(b:mvnPomFile, "testSourceDirectory", "${basedir}/src/test/java")
  call <SID>debug("[java-maven] [MvnSetup] b:mvnPomDirectory .........: " . b:mvnPomDirectory)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnPomFile ..............: " . b:mvnPomFile)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnSourceDirectory ......: " . b:mvnSourceDirectory)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnTestSourceDirectory ..: " . b:mvnTestSourceDirectory)

  " Configure alternate.vim plugin
  let b:alternate_source_dirs = b:mvnSourceDirectory
  let b:alternate_test_token = "Test"
  let b:alternate_test_token_location = "$"
  let b:alternate_test_dirs = b:mvnTestSourceDirectory
  let b:alternate_enabled = 1
endfunction

" --  Mvn  ---------------------------------------------------------------------
" Execute Maven with specified arguments. It is used by the command 'Mvn' (see
" on top of this script).
" Internally the function uses the buffer variable b:mvnPomFile to be sure
" to execute the specified command on the project to which the current buffer
" relates to.
" It is possible to specify additional switched like:
"     -q .....: to enable quiet mode
"
function! <SID>Mvn(...)
  if empty(b:mvnPomDirectory)
    echoerr "This buffer does not seem part of a Maven project (b:mvnPomDirectory is empty)"
    return
  endif

  let shellArgs = join(a:000, ' ')
  call <SID>debug("[java-maven] [Mvn] parameters: " . shellArgs)

  let shellCommand = "mvn -f " . b:mvnPomFile . " " . shellArgs
  call <SID>debug("[java-maven] [Mvn] executing: " . shellCommand)
  execute "!" . shellCommand
endfunction

" --  MvnPomDirectory  ---------------------------------------------------------
" Returns the Maven pom.xml directory if it exists or "" if it is unable to
" find it.
" It searches in all parent directories for a 'pom.xml' file.
function! <SID>MvnPomDirectory()
  let currentDir = expand("%:p:h")
  let pomFile = currentDir . "/pom.xml"
  call <SID>debug("[java-maven] [MvnPomRoot] buffer directory: " . currentDir . ", pom file: " . pomFile)

  while currentDir != "/" && !filereadable(pomFile)
    let currentDir = fnamemodify(currentDir, ':h')
    let pomFile = currentDir . "/pom.xml"
    call <SID>debug("[java-maven] [MvnPomRoot] buffer directory: " . currentDir . ", pom file: " . pomFile)
  endwhile

  if filereadable(pomFile)
    return currentDir
  else
    return ""
  endif
endfunction

" --  MvnTest  -----------------------------------------------------------------
" If current buffer is a test class runs only it, else run all tests
function! <SID>MvnTest()
  if <SID>isCurrentBufferATest()
    let bufferName = expand("%:t:r")
    call <SID>ExecMvnTest(bufferName)
  else
    call <SID>ExecMvnTest("")
  endif
endfunction

" --  isCurrentBufferATest  ----------------------------------------------------
" Returns true if current buffer is a test
" TODO currently it checks only if the filename ends with 'Test'. It is probably better to check if current buffer contains a @Test inside...
function! <SID>isCurrentBufferATest()
  let bufferName = expand("%:t:r")
  let isATest = <SID>endsWith(bufferName, "Test")

  call <SID>debug("[java-maven] [isCurrentBufferATest] returning " . isATest)
  return isATest
endfunction

" --  ExecMvnTest  -------------------------------------------------------------
" Execute shell command:
"     mvn test [-Dtest=testName]
" where the optional part is added only if testName is not empty
function! <SID>ExecMvnTest(testName)
  let commandParams = "-q test -Dsurefire.useFile=false"
  if !empty(a:testName)
    let commandParams .= " -Dtest=" . a:testName
  endif
  execute ":Mvn " . commandParams
endfunction

" --  readPom  -----------------------------------------------------------------
" Returns true if specified 'text' ends with 'toFind'
function! g:readPom(pomFile, tag, defaultValue)
  "let shellCmd = "grep '" . a:tag . "' " . a:pomFile . " | sed 's/\\s*<\\/*" . a:tag . ">//g'"
  let shellCmd = "grep '" . a:tag . "' " . a:pomFile
  call <SID>debug("[java-maven] [readPom] shellCmd = " . shellCmd)
  let text = system(shellCmd)
  if empty(text)
    let text = a:defaultValue
  else
    call <SID>debug("[java-maven] [readPom] initial = " . text)
    let text = substitute(text, ".*<" . a:tag . ">", "", "")
    call <SID>debug("[java-maven] [readPom] then = " . text)
    let text = substitute(text, "</" . a:tag . ">.*", "", "")
    call <SID>debug("[java-maven] [readPom] then2 = " . text)
  endif
  let text = substitute(text, "${basedir}/", "", "")
  call <SID>debug("[java-maven] [readPom] returning " . text)
  return text
endfunction

" --  endsWith  ----------------------------------------------------------------
" Returns true if specified 'text' ends with 'toFind'
function! <SID>endsWith(text, toFind)
  let pattern = "\." . a:toFind . "$"
  return a:text =~ pattern
endfunction

" --  debug  -------------------------------------------------------------------
" Returns true if specified 'text' ends with 'toFind'
function! <SID>debug(text)
  if g:javamaven_debug
    echom a:text
  endif
endfunction

" vim:set ft=vim sw=2 sts=2 et:
