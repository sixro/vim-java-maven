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
if !exists("g:javamaven_cache")
  let g:javamaven_cache = $HOME . "/.cache/vim/javamaven"
  
endif


" ==  Autocmd(s)  ==============================================================
"
" Setup Maven when a java file is opened
autocmd filetype java :call <SID>MvnSetup()

" --  javacomplete  ------------------------------------------------------------
autocmd Filetype java setlocal omnifunc=javacomplete#Complete 
autocmd Filetype java setlocal completefunc=javacomplete#CompleteParamsInfo 

" Configure make in vim
autocmd Filetype java set makeprg="!javac -cp ".b:classpath." -d  ".b:mvnOutputDirectory." ".@%


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

  " if a cache file exists, we sources it.
  " Otherwise we need to collect information from the current pom and store
  " them in the cache file
  let b:cacheFilename = s:cacheFileNameFor(b:mvnPomDirectory)
  let b:cacheFilepath = g:javamaven_cache . "/" . b:cacheFilename
  if (filereadable(b:cacheFilepath))
    call <SID>debug("[java-maven] [MvnSetup] cache file found (" . b:cacheFilepath . "). Sourcing properties from it...")
    execute 'source ' . fnameescape(b:cacheFilepath)
  else
    call <SID>debug("[java-maven] [MvnSetup] unable to find cache file (" . b:cacheFilepath . "). Collecting all properties and generating them...")
    let tmp = system("mvn help:effective-pom -Doutput=/tmp/pom-temp.xml")
    let b:mvnSourceDirectory = system("xmllint -xpath '//project/build/sourceDirectory/text()' /tmp/pom-temp2.xml")
    let b:mvnSourceDirectory = <SID>asLocal(b:mvnSourceDirectory, b:mvnPomDirectory)
    let b:mvnTestSourceDirectory = system("xmllint -xpath '//project/build/testSourceDirectory/text()' /tmp/pom-temp2.xml")
    let b:mvnTestSourceDirectory = <SID>asLocal(b:mvnTestSourceDirectory, b:mvnPomDirectory)
    let b:mvnOutputDirectory = system("xmllint -xpath '//project/build/outputDirectory/text()' /tmp/pom-temp2.xml")
    let b:mvnOutputDirectory = <SID>asLocal(b:mvnOutputDirectory, b:mvnPomDirectory)

    " Configure javacomplete.vim
    let b:mvnPomFile = b:mvnPomDirectory . "/pom.xml"
    let b:classpath = <SID>MvnDependencyBuildClasspath(b:mvnPomFile)
    let b:classpath = b:classpath . ":" . b:mvnOutputDirectory

    if ! isdirectory(g:javamaven_cache)
      call mkdir(g:javamaven_cache, "p")
    endif
    call writefile([ "let b:mvnPomDirectory = \"" . b:mvnPomDirectory . "\"" ], b:cacheFilepath, "a")
    call writefile([ "let b:mvnPomFile = \"" . b:mvnPomFile . "\"" ], b:cacheFilepath, "a")
    call writefile([ "let b:mvnSourceDirectory = \"" . b:mvnSourceDirectory . "\"" ], b:cacheFilepath, "a")
    call writefile([ "let b:mvnTestSourceDirectory = \"" . b:mvnTestSourceDirectory . "\"" ], b:cacheFilepath, "a")
    call writefile([ "let b:mvnOutputDirectory = \"" . b:mvnOutputDirectory . "\"" ], b:cacheFilepath, "a")
    call writefile([ "let b:classpath = \"" . b:classpath . "\"" ], b:cacheFilepath, "a")
  endif

  call <SID>debug("[java-maven] [MvnSetup] b:mvnPomDirectory .........: " . b:mvnPomDirectory)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnPomFile ..............: " . b:mvnPomFile)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnSourceDirectory ......: " . b:mvnSourceDirectory)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnTestSourceDirectory ..: " . b:mvnTestSourceDirectory)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnOutputDirectory ......: " . b:mvnOutputDirectory)
  call <SID>debug("[java-maven] [MvnSetup] b:classpath ...............: " . b:classpath)

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

" --  MvnDependencyBuildClasspath  ---------------------------------------------
" Returns the build classpath of specified Maven POM.
" 
" Internally it calls the dependency maven plugin with option build-classpath.
function! <SID>MvnDependencyBuildClasspath(pomFile)
  let shellCommand = <SID>mvnCommand(a:pomFile) . " dependency:build-classpath | grep -v '^\\[INFO'"
  call <SID>debug("[java-maven] [MvnDependencyBuildClasspath] executing " . shellCommand)
  let classpath = system(shellCommand)
  let classpath = substitute(classpath, ".$", "", "")
  return classpath
endfunction

" --  isCurrentBufferATest  ----------------------------------------------------
" Returns true if current buffer is a test
" TODO currently it checks only if the filename ends with 'Test'. It is probably better to check if current buffer contains a @Test inside...
function! <SID>isCurrentBufferATest()
  let bufferName = expand("%:t:r")
  let isATest = <SID>endsWith(bufferName, "Test") || <SID>endsWith(bufferName, "IT")

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


" --  cacheFileNameFor  --------------------------------------------------------
" Returns a suitable cache filename for the specified pom directory.
"
" It consider not only the directory name containing the pom (assuming that
" usually it is the project name), but it consider also (if present) the
" git branch name. The reason of this is that it could be possible that
" your deps change between different branches of the same project.
function! s:cacheFileNameFor(pomDir)
  let projectDirName = fnamemodify(a:pomDir, ':t')
  let branchName = "nobranch"
  if isdirectory(a:pomDir . "/.git")
    let branchName = system("git branch --show-current --no-color")
    " Remove annoying ^@ at the end
    let branchName = substitute(branchName, ".$", "", "")
  endif
  let cacheFilename = projectDirName . "_" . branchName
  call <SID>debug("[java-maven] [cacheFileNameFor] Project Dir Name: " . projectDirName . ", Branch: " . branchName . "; returning " . cacheFilename)
  return cacheFilename
endfunction


" --  javaCommand  -------------------------------------------------------------
" Returns the javac command that should be launched
function! <SID>javaCommand(classpath, objectName)
  let cmd = "java -cp \"" . a:classpath . "\" " . objectName
  call <SID>debug("[java-maven] [javaCommand] returning '" . cmd . "'")
  return cmd
endfunction


" --  javaCommand  -------------------------------------------------------------
" Returns the java command that should be launched
function! <SID>javaCommand(classpath, objectName)
  let cmd = "java -cp \"" . a:classpath . "\" " . a:objectName
  call <SID>debug("[java-maven] [javaCommand] returning '" . cmd . "'")
  return cmd
endfunction


" --  javacCommand  -------------------------------------------------------------
" Returns the javac command executed with specified classpath and fileName
function! <SID>javacCommand(classpath, destDir, fileName)
  let cmd = "javac -cp \"" . a:classpath . "\" -d " . a:destDir . " " . a:fileName
  call <SID>debug("[java-maven] [javacCommand] returning '" . cmd . "'")
  return cmd
endfunction


" --  mvnCommand  --------------------------------------------------------------
" Returns the mvn command that should be launched using specified POM file
function! <SID>mvnCommand(pomFile)
  let mvnCommand = "mvn -f " . a:pomFile
  call <SID>debug("[java-maven] [mvnCommand] returning '" . mvnCommand . "'")
  return mvnCommand
endfunction


" --  asLocal  -----------------------------------------------------------------
" Returns the specified directory as if it is local to the specified
" pomDirectory
function! <SID>asLocal(dir, pomDir)
  let tmp = substitute(a:dir, a:pomDir . "/", "", "")
  " Remove annoying ^@ character at the end
  let tmp = substitute(tmp, ".$", "", "")
  return tmp
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
