" java-maven.vim - Java & Maven
" Author: Roberto Simoni <http://sixro.net>

if exists("g:loaded_javamaven") || &cp || v:version < 700
	finish
endif
let g:loaded_javamaven = 1

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
