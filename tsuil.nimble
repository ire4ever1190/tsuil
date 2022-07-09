# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Manages your PDFs and search through all of them"
license       = "MIT"
srcDir        = "src"
bin           = @["tsuil"]


# Dependencies

requires "nim >= 1.6.0"
requires "mike#f6d6b6d"
requires "tiny_sqlite == 0.1.3"
requires "asyncthreadpool#7e533b3"
requires "anano == 0.2.0"

before build:
  when defined(release):
    exec "npm run build"
