# zoom-window2.el

## Introduction

`zoom-window2` provides window zoom like tmux zoom and unzoom.


## Screenshot

![Screenshot of zoom-window2.el](image/zoom-window.gif)

Background color of `mode-line` is changed when zoomed


`zoom-window2.el` supports elscreen and persp-mode.

## Features

- Support elscreen
- Support multiple frames(This feature cannot use with elscreen and persp-mode yet)

## Basic Usage

#### `zoom-window2-zoom`

Toggle between zooming current window and unzooming

#### `zoom-window2-next`

Switch to next buffer which is in zoomed frame/screen/perspective.


## Customization

### `zoom-window2-mode-line-color`(Default is `"green"`)

Color of `mode-line` when zoom-window2 is enabled

### `zoom-window2-use-elscreen`(Default is `nil`)

Set `non-nil` if you use `elscreen`

## Example

```lisp
(require 'zoom-window2)
(global-set-key (kbd "C-x C-z") 'zoom-window2-zoom)
(custom-set-variables
 '(zoom-window2-mode-line-color "DarkGreen"))
```

### zoom-window2 with [elscreen](https://github.com/knu/elscreen)

```lisp
(require 'elscreen)
(elscreen-start)

(require 'zoom-window2)
(setq zoom-window2-use-elscreen t)
(zoom-window2-setup)

(global-set-key (kbd "C-x C-z") 'zoom-window2-zoom)
```
