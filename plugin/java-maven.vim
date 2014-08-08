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
  let b:mvnGroupId = g:xpath(b:mvnPomFile, "//project/groupId/text()", "project")
  let b:mvnArtifactId = g:xpath(b:mvnPomFile, "//project/artifactId/text()", "project")
  let b:mvnVersion = g:xpath(b:mvnPomFile, "//project/version/text()", "project")
  let b:mvnSourceDirectory = g:xpath(b:mvnPomFile, "sourceDirectory", "project", "${basedir}/src/main/java")
  let b:mvnTestSourceDirectory = g:xpath(b:mvnPomFile, "testSourceDirectory", "project", "${basedir}/src/test/java")
  call <SID>debug("[java-maven] [MvnSetup] b:mvnPomDirectory .........: " . b:mvnPomDirectory)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnPomFile ..............: " . b:mvnPomFile)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnGroupId ..............: " . b:mvnGroupId)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnArtifactId ...........: " . b:mvnArtifactId)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnVersion ..............: " . b:mvnVersion)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnSourceDirectory ......: " . b:mvnSourceDirectory)
  call <SID>debug("[java-maven] [MvnSetup] b:mvnTestSourceDirectory ..: " . b:mvnTestSourceDirectory)

  " Configure javacomplete.vim
  let b:classpath = <SID>MvnDependencyBuildClasspath(b:mvnPomFile)

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
" FIXME It needs to use a caching system. E.g. Put the classpath in a file
"       in .cache/vim using the groupId-artifactId of the POM. If the caching
"       file is more recent than the POM, the cached content is still valid
"       for every buffer
function! <SID>MvnDependencyBuildClasspath(pomFile)
  let projectID = <SID>evaluateProjectID(a:pomFile)
  let classpath = <SID>cacheRead(g:javamaven_cache, projectID, "classpath", getftime(a:pomFile))
  if empty(classpath)
    let shellCommand = <SID>mvnCommand(a:pomFile) . " dependency:build-classpath | grep -v '^\\[INFO'"
    call <SID>debug("[java-maven] [MvnDependencyBuildClasspath] executing " . shellCommand)
    let classpath = system(shellCommand)

    call <SID>cacheWrite(g:javamaven_cache, projectID, "classpath", classpath)
  endif

  return classpath
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

" --  evaluateProjectID  -------------------------------------------------------
" Returns the projectID of specified POM
"
" Internally it gets groupId, artifactId and version and joins them with '-'.
" E.g.
"     <groupId>github</groupId>
"     <artifactId>myproj</artifactId>
"     <version>1.0.0-SNAPSHOT</version>
"  becomes:
"     github-myproj-1.0.0-SNAPSHOT
" I was in doubt to use also the version, but if you are working on multiple
" branches, probably the unique way to know it is the different version...
function! <SID>evaluateProjectID(pomFile)
  let mvnGroupId = g:xpath(a:pomFile, "//project/groupId/text()", "project")
  let mvnArtifactId = g:xpath(a:pomFile, "//project/artifactId/text()", "project")
  let mvnVersion = g:xpath(a:pomFile, "//project/version/text()", "project")
  return join([ mvnGroupId, mvnArtifactId, mvnVersion ], '.')
endfunction

" --  cacheRead  ---------------------------------------------------------------
" Returns specified property from cache of specified projectID
"
" It uses file to contains property value, so we can use filesystem to check
" update datetime and check the validity with specified timestampOfSource
function! <SID>cacheRead(cacheDirectory, projectID, property, timestampOfSource)
  let cacheFile = a:cacheDirectory . "/" . a:projectID . "/" . a:property
  call <SID>debug("[java-maven] [cacheRead] cacheFile = " . cacheFile)
  if !filereadable(cacheFile)
    call <SID>debug("[java-maven] [cacheRead] not found or not readable")
    return ""
  endif
  " Check if the cache file is older than source...
  if (getftime(cacheFile) < a:timestampOfSource)
    call <SID>debug("[java-maven] [cacheRead] too old")
    return ""
  endif

  let cachedValue = join(readfile(cacheFile), "")
  call <SID>debug("[java-maven] [cacheRead] returning '" . cachedValue . "'")
  return cachedValue
endfunction

" --  cacheWrite  --------------------------------------------------------------
" Write specified property value in cache of specified projectID
function! <SID>cacheWrite(cacheDirectory, projectID, property, value)
  let cacheFileParent = a:cacheDirectory . "/" . a:projectID
  if ! isdirectory(cacheFileParent)
    call mkdir(cacheFileParent, "p")
  endif

  let cacheFile = cacheFileParent . "/" . a:property
  call <SID>debug("[java-maven] [cacheWrite] cacheFile = " . cacheFile)

  call writefile([ a:value ], cacheFile)
  call <SID>debug("[java-maven] [cacheWrite] value '" . a:value . "' cached in " . cacheFile)
endfunction

" --  xpath  -------------------------------------------------------------------
" Returns the specified xpath on specified xmlFile.
"
" Accept 2 additional parameters:
"    * 3rd parameter ...: can be a name of the tag containing a namespace
"                         definition. xmllint gives error when xml contains
"                         namespaces and the fast way I found is to clean
"                         the specified tag. E.g. in Maven POM, the
"                            <project xmlns=...>
"                         is replace with:
"                            <project>
"                         In this way, xmllint runs perfectly
"    * 4th parameter ...: the default value to return when no value is found
"                         in XML
function! g:xpath(xmlFile, xpath, ...)
  call <SID>debug("[java-maven] [xpath] executing xpath '" . a:xpath . "' on file " . a:xmlFile)
  let tmpXml = a:xmlFile
  if (a:0 > 0)
    let tmpXml = tempname()
    " remove namespace from specified tag (a:1)
    let shellCommand = "sed 's/<" . a:1 . " .*>/<" . a:1 . ">/g' " . a:xmlFile . " > " . tmpXml
    call <SID>debug("[java-maven] [xpath] executing command '" . shellCommand . "' before xpath...")

    call system(shellCommand)
  endif

  let xpathCmd = "xmllint --xpath \"" . a:xpath . "\" " . tmpXml
  call <SID>debug("[java-maven] [xpath] executing command '" . xpathCmd . "' to retrieve xpath...")
  
  let value = system(xpathCmd)
  " When xmllint does not find anything and a default value has been provided...
  if value =~ "^XPath set is empty.*" && a:0 > 1
    let value = a:2
  endif

  call <SID>debug("[java-maven] [xpath] returning '" . value . "'")
  return value
endfunction

" --  mvnCommand  --------------------------------------------------------------
" Returns the mvn command that should be launched using specified POM file
function! <SID>mvnCommand(pomFile)
  let mvnCommand = "mvn -f " . a:pomFile
  call <SID>debug("[java-maven] [mvnCommand] returning '" . mvnCommand . "'")
  return mvnCommand
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
