# vim-java-maven
> A vim plugin to be used on Java &amp; Maven projects...

## Summary

  * [Introduction](#intro)
  * [Requirements](#req)
  * [Functions](#functions)
  * [Todo](#todo)


## <a name="intro"></a>Introduction

This is a vim plugin I am trying to create.  
It has an old story and I do not maintain it actively.  
The reason is that I cannot have the same experience I have at the moment with others IDE.  
Anyway I leave it here as a learning process for someone who wants to understand how I made 
something (DISCLAIMER: probably I made it wrong :D).

**WARNING**: it is slow, because it needs to execute some commands to retrieve data from `pom.xml`
and because I don't know how to cache in a good way.

## <a name="req"></a>Requirements

  * Java and Maven: it executes some commands using maven. For example, in order to understand
    the source and test directories and then configure the `alternate.vim` plugin
  * [alternate.vim](https://github.com/compactcode/alternate.vim): setup alternate commands
  * [open.vim](https://github.com/compactcode/open.vim): setup commands to open alternate, etc...


## <a name="functions"></a>Functions

  * `:A`: open in a new buffer the related test (the alternate)
    * `:AV`: open it in a vertical window
    * `:AS`: open it in a horizontal window
  * `:MvnTest`: run the related test
  * `:Mvn`: execute the command specified after it


## <a name="todo"></a>Todo

  * Cache important variables for every buffer under the same `pom.xml`
