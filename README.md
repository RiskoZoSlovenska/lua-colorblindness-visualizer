# Lua Colorblindness Visualizer

A small library (like it literally exposes a single function (so far)) which applies a colorblindness filter on images.

Uses an algorithm explained nicely by https://ixora.io/projects/colorblindness/color-blindness-simulation-research/.


Currently only the tritanopia filter is implemented, but I plan on adding others.

***Disclaimer:** I have virtually no knowledge (yet) of math and color matrixes and human light perception and so on. I'm merely putting what I read into code.*



## Docs

TBA

***Note:** Do note that I mostly plan on using this my own personal purposes so the interface may change at any time.*



## Installation and dependencies

Coming to popular lua package managers soon (not actually lol)

Requires [lua-vips](https://github.com/libvips/lua-vips), which in turn depends on [libvips](http://libvips.github.io/libvips) and [LuaJIT](https://luajit.org/).