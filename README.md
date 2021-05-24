# vim-java-maven
> A vim plugin to be used on Java &amp; Maven projects...

## Summary

  * [Introduction](#intro)
  * [Requirements](#req)
  * [What it does](#what-it-does)
  * [Todo](#todo)


## <a name="intro"></a>Introduction

This is a vim plugin I am trying to create.  
It has an old story and I do not maintain it actively.  
The reason is that I cannot have the same experience I have at the moment with others IDE.  
Anyway I leave it here as a learning process for someone who wants to understand how I made 
something (DISCLAIMER: probably I made it wrong :D).


## <a name="req"></a>Requirements

  * `Java`, `Maven`, `sed` and `xmllint`: it executes some commands using `maven`. For example, in order to understand
    the source and test directories and then configure the `alternate.vim` plugin
  * `ctags`: to generate tags (can be disabled defining `g:javamaven_skip_tags`)
  * [alternate.vim](https://github.com/compactcode/alternate.vim): setup alternate commands
  * [open.vim](https://github.com/compactcode/open.vim): setup commands to open alternate, etc...


## <a name="what-it-does"></a>What it does

  * Allow code navigation using `Ctrl-]` (only if `ctags` is left enabled)
  * Allow code navigation using `gf` (WARNING: I need to fix a bug happening when a directory has the same name of the java object)
  * Caches project data so that the 2nd time you open a file it is very fast. It re-generates project data if the `pom.xml` is updated
  * Provide the following commands:
	  * `:A`: open in a new buffer the related test (the alternate)
		* `:AV`: open it in a vertical window
		* `:AS`: open it in a horizontal window
	  * `:MvnTest`: run the related test
	  * `:Mvn`: execute the command specified after it


## <a name="todo"></a>Todo

  * `gf` opening also Java files: it works, but I need to create a custom function to avoid
    vim prioritize directories over files
  * Try to read the java version configured in pom.xml
  * add also `Javac`, `Java` command using the configured `classpath`: this could be handy 
    to speed up test execution and lint verification
  * `:autocmd BufNewFile  *.java   0r ~/vim/skeleton.java` should create a file buffer having
    the package name correctly setup for the current directory in relation to the base pom root
