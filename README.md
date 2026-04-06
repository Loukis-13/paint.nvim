# Paint.nvim
Painting tool plugin for neovim inspired in MS Paint and Durdraw

https://github.com/user-attachments/assets/c947b5bb-1416-4b05-b28f-4a6e6a546cb0

## Features
- [x] Keyboard drawing
- [x] Mouse drawing
- [x] Save/Load
- [ ] Undo/Redo
- [ ] Shapes
  - [x] Line
  - [x] Square
  - [x] Circle
  - [ ] Triangle
- [ ] Tools
  - [x] Pencil
  - [x] Eraser
  - [x] Eye drop
  - [x] Fill
  - [ ] Text
  - [ ] Color picker
- [x] User command arguments
- [x] Choose pencil type / Char list

If you want a new feature or find a bug, please open an issue.

## Installation
### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "Loukis-13/paint.nvim",
    opts = {}
}
```

### vim.pack
```lua
vim.pack.add({ "https://github.com/Loukis-13/paint.nvim" })
require("paint.nvim").setup({})
```

## Configuration
```lua
{
  rows = 40,      -- height of the canvas
  cols = 120,     -- width of the canvas
  char_list = {   -- chars for the quick char selection list
    { '█', 'Full Block' },
    { '▓', 'Dark Shade' },
    { '▒', 'Medium Shade' },
    { '░', 'Light Shade' },
    { '▔', 'Upper One Eighth Block' },
    { '▀', 'Upper Half Block' },
    { '▁', 'Lower One Eighth Block' },
    { '▂', 'Lower One Quarter Block' },
    { '▃', 'Lower Three Eighths Block' },
    { '▄', 'Lower Half Block' },
    { '▅', 'Lower Five Eighths Block' },
    { '▆', 'Lower Three Quarters Block' },
    { '▇', 'Lower Seven Eighths Block' },
    { '▉', 'Left Seven Eighths Block' },
    { '▊', 'Left Three Quarters Block' },
    { '▋', 'Left Five Eighths Block' },
    { '▌', 'Left Half Block' },
    { '▍', 'Left Three Eighths Block' },
    { '▎', 'Left One Quarter Block' },
    { '▏', 'Left One Eighth Block' },
    { '▐', 'Right Half Block' },
    { '▕', 'Right One Eighth Block' },
    { '▖', 'Quadrant Lower Left' },
    { '▗', 'Quadrant Lower Right' },
    { '▘', 'Quadrant Upper Left' },
    { '▙', 'Quadrant Upper Left and Lower Left and Lower Right' },
    { '▚', 'Quadrant Upper Left and Lower Right' },
    { '▛', 'Quadrant Upper Left and Upper Right and Lower Left' },
    { '▜', 'Quadrant Upper Left and Upper Right and Lower Right' },
    { '▝', 'Quadrant Upper Right' },
    { '▞', 'Quadrant Upper Right and Lower Left' },
    { '▟', 'Quadrant Upper Right and Lower Left and Lower Right' },
  }
}
```

## Usage
You can start this plugin with `:Paint`, but it's better used as a standalone like:
```shell
nvim +Paint

# define the dimension of the canvas
nvim +"Paint rows=100 cols=100"

# load a file
nvim +"Paint load file.json"
```

### Keyboard commands
**\<Space\>** - tool down (begin to draw/erase)  
**\<Esc\>** - tool up (stops drawing/erasing)  
**p** - pencil  
**e** - eraser  
**f** - type foreground color in #RRGGBB format  
**b** - type background color in #RRGGBB format  
**Pf** - pick foreground color under cursor as the current foreground color  
**Pb** - pick background color under cursor as the current background color  
**c** - type char to be used for drawing  
**C** - select pre-defined char from list  
**F** - fill area under cursor with selected colors  
**s** - select shape to draw.  
**w** - Save to file (.json/.ansi)  

To draw a shape:
- enter `V-BLOCK` mode (\<C-v\> or \<C-q\>),
- select the area of the shape,
- return to normal mode (\<Esc\>).

### Mouse commands
#### On palette
**\<LeftMouse\>** - pick foreground color  
**\<RightMouse\>** - pick background color  

#### On canvas
**\<LeftMouse\>/\<LeftDrag\>** - Draw  

## Support
Toss me a coin if you liked what I did.  

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/Loukis)

A big red heart for you ❤  

https://github.com/user-attachments/assets/dea19ecc-55ee-4c0f-a2d3-46afeb88d6c2
