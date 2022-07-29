# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Manages your PDFs and search through all of them"
license       = "MIT"
srcDir        = "src"
bin           = @["tsuil"]
installDirs   = @["public"]


# Dependencies

requires "nim >= 1.6.0"
requires "mike#70a4548"
requires "tiny_sqlite == 0.1.3"
requires "asyncthreadpool#7e533b3"
requires "anano == 0.2.0"
requires "karax == 1.2.2"

task buildJS, "Builds JS files":
  selfExec "js -d:release --outdir:public/ src/frontend"

before install:
  buildJSTask()
  cpDir "public/", "src/public/"

before build:
  echo "Building JS..."
  buildJSTask()
