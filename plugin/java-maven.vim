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

function! s:isCurrentBufferATest()
  " FIXME: it is probably better to check if current buffer contains a @Test
  let bufferName = expand("%:t:r")
  let isATest = bufferName =~ "\.Test$"

  echom "[java-maven] [isCurrentBufferATest] returning " . isATest
  return isATest
endfunction

" Execute shell command:
"     mvn test [-Dtest=testName]
" where the optional part is added only if testName is not empty
function! s:ExecMvnTest(testName)
  let shellCommand = "mvn test"
  if !empty(a:testName)
    let shellCommand .= " -Dtest=" . a:testName
  endif

  echom "[java-maven] [MvnTest] executing " . shellCommand
  execute "!" . shellCommand
endfunction

command MvnTest call <SID>MvnTest()

" vim:set ft=vim sw=2 sts=2 et:
