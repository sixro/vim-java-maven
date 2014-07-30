" java-maven.vim - Java & Maven
" Author: Roberto Simoni <http://sixro.net>

if exists("g:loaded_javamaven") || &cp || v:version < 700
	finish
endif
let g:loaded_javamaven = 1

autocmd filetype java :call <SID>MvnSetup()

function! <SID>MvnSetup()
  echom "[java-maven] [MvnSetup] Setting up Maven in Vim..."
  let b:mvnPomDirectory = MvnPomDirectory()
  if empty(b:mvnPomDirectory)
    return
  endif

  let b:mvnPomFile = b:mvnPomDirectory . "/pom.xml"
  echom "[java-maven] [MvnSetup] b:mvnPomDirectory ..: " . b:mvnPomDirectory
  echom "[java-maven] [MvnSetup] b:mvnPomFile .......: " . b:mvnPomFile
endfunction

" If current buffer is a test class runs only it, else run all tests
function! s:MvnTest()
  if s:isCurrentBufferATest()
    let bufferName = expand("%:t:r")
    call s:ExecMvnTest(bufferName)
  else
    call s:ExecMvnTest("")
  endif
endfunction

" Returns true if current buffer is a test
" FIXME: currently it checks only if the filename ends with 'Test'. It is 
" probably better to check if current buffer contains a @Test inside...
function! s:isCurrentBufferATest()
  let bufferName = expand("%:t:r")
  let isATest = s:endsWith(bufferName, "Test")

  echom "[java-maven] [isCurrentBufferATest] returning " . isATest
  return isATest
endfunction

function! MvnPomDirectory()
  let currentDir = expand("%:p:h")
  let pomFile = currentDir . "/pom.xml"
  echom "[java-maven] [MvnPomRoot] buffer directory: " . currentDir . ", pom file: " . pomFile

  while currentDir != "/" && !filereadable(pomFile)
    let currentDir = fnamemodify(currentDir, ':h')
    let pomFile = currentDir . "/pom.xml"
    echom "[java-maven] [MvnPomRoot] buffer directory: " . currentDir . ", pom file: " . pomFile
  endwhile

  if filereadable(pomFile)
    return currentDir
  else
    return ""
  endif
endfunction

" Execute shell command:
"     mvn test [-Dtest=testName]
" where the optional part is added only if testName is not empty
function! s:ExecMvnTest(testName)
  let shellCommand = "mvn -q test -Dsurefire.useFile=false"
  if !empty(a:testName)
    let shellCommand .= " -Dtest=" . a:testName
  endif

  echom "[java-maven] [MvnTest] executing " . shellCommand
  execute "!" . shellCommand
endfunction

" Returns true if specified 'text' ends with 'toFind'
function! s:endsWith(text, toFind)
  let pattern = "\." . a:toFind . "$"
  return a:text =~ pattern
endfunction

command MvnTest call <SID>MvnTest()

" vim:set ft=vim sw=2 sts=2 et:
