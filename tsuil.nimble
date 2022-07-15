# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Manages your PDFs and search through all of them"
license       = "MIT"
srcDir        = "src"
bin           = @["tsuil"]

installDirs = @["build"]

# Dependencies

requires "nim >= 1.6.0"
requires "mike#70a4548"
requires "tiny_sqlite == 0.1.3"
requires "asyncthreadpool#7e533b3"
requires "anano == 0.2.0"

before install:
  echo "Building JS..."
  echo get("nimblePath")
  # Install dependencies then build
  exec "npm install react-app-rewired"
  exec "npm install"
  exec "npm run build"
  echo "Done"
  mvDir "build", "src/build"
