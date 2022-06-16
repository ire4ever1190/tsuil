import mike
import common
import database
import pdfscraper
import std/[
  os,
  tables,
  times,
  locks,
  isolation
]

import threading/channels

const pdfFolder = "pdfs"


var
  dbLock: Lock 
  db {.guard: dbLock.} = openDatabase("database.db")

db.createTables()

proc process(name, file: sink string)  = 
  # Write the file
  let path = pdfFolder / name
  discard existsOrCreateDir(pdfFolder)
  
  path.writeFile(file)
  if not path.isPDF():
    echo name, " was not a PDF"
    return
  {.gcsafe.}:
    withLock dbLock:
      let info = path.getPDFInfo()
      let pdfID = db.insert info
      var i = 1
      for page in path.getPDFPages():
        echo "Adding ", i
        db.insertPage(pdfID, i, page)
        inc i
      echo "done"

var pdfChan = newChan[MultipartValue]()

proc pdfWorker() =
  while true:
    var info: MultipartValue
    pdfChan.recv(info)
    echo "Processing ", info.name, "..."
    process(info.filename, info.value)

var worker: Thread[void]
createThread(worker, pdfWorker)
      
const index = slurp("../public/index.html")



"/" -> get:
  ctx.addHeader("Content-Type", "text/html")
  ctx.send(index)

"/uploadfile" -> post:
  var form = ctx.multipartForm()
  echo "recieved ", form["file"].name
  pdfChan.send(unsafeIsolate move form["file"])
  ctx.send "Processing"

"/search" -> get:
  let query = ctx.queryParams["query"]
  var res: string
  {.gcsafe.}:
    withLock dbLock:
      for result in db.searchFor(query):
        res &= $result.page & "\n"
  ctx.send(res)  
run()
