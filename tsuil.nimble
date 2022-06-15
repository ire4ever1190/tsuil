# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Manages your PDFs and search through all of them"
license       = "MIT"
srcDir        = "src"
bin           = @["tsuil"]


# Dependencies

requires "nim >= 1.6.0"
requires "mike#8b26ed5"
requires "tiny_sqlite == 0.1.3"
requires "threading == 0.1.0"

