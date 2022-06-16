import mike
import common
import database
import pdfscraper
import std/[
  os,
  tables,
  locks,
  isolation,
  strutils,
  json
]

import threading/channels

const pdfFolder = "pdfs"


var
  dbLock: Lock 
  db {.guard: dbLock.} = openDatabase("database.db")

template withDB(body: untyped) =
  ## Run a block of code with the DB lock turned on
  ## Also turns on gcsafe since it is protected
  withLock dbLock:
    {.gcsafe.}:
      body

db.createTables()

proc process(name, file: sink string)  = 
  # Write the file
  let path = pdfFolder / name
  discard existsOrCreateDir(pdfFolder)
  
  path.writeFile(file)
  if not path.isPDF():
    echo name, " was not a PDF"
    return
  
  withDB:
    let info = path.getPDFInfo()
    let pdfID = db.insert info
    let newPath = pdfFolder / $pdfID & ".pdf"
    moveFile(path, newPath)
    var i = 1
    for page in newPath.getPDFPages():
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
    process(info.filename.get(), info.value)

var worker: Thread[void]
createThread(worker, pdfWorker)
      
const index = slurp("../public/index.html")

type
  ErrorMsg = object
    msg: string
    code: int


"/" -> get:
  ctx.setHeader("Content-Type", "text/html")
  ctx.send(index)

"/uploadfile" -> post:
  var form = ctx.multipartForm()
  echo "recieved ", form["file"].name
  pdfChan.send(unsafeIsolate move form["file"])
  ctx.send "Processing"

"/search" -> get:
  let query = ctx.queryParams["query"]
  var res: seq[SearchResult]
  withDB:
    res = db.searchFor(query)
  ctx.send(res)  

"/pdf/:id" -> get:
  let id = ctx.pathParams["id"].parseBiggestInt().int64
  var info: Option[PDFFileInfo]
  withDB: info = db.getPDF(id)
  if info.isSome:
    ctx.setHeader("Cache-Control", "public, max-age=432000") # Cache for next 5 days
    await ctx.sendFile("pdfs" / $id & ".pdf")
  else:
    ctx.send(ErrorMsg(msg: "Couldn't find pdf: " & $id, code: 404), Http404)
    
run(threads = 1)
