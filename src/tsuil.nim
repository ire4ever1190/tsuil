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
  json,
  md5,
  times,
  algorithm,
  setutils
]

import threading/channels

const pdfFolder = "pdfs"

proc `%`(id: NanoID): JsonNode =
  result = % $id

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

import std/httpclient

proc sendReactFile(ctx: Context, path: string) {.async.} =
  when defined(release):
    await ctx.sendFile("build" / path)
  else:
    let client = newAsyncHttpClient()
    defer: client.close()
    let resp = await client.request("http://127.0.0.1:3000/" & path)
    
    ctx.send(await resp.body, resp.code, resp.headers)

proc send(ctx: Context, msg: ErrorMsg) =
  ## Sends error message
  ctx.send(msg, HttpCode(msg.code))

"/" -> get:
  await ctx.sendReactFile("index.html")

"/static/^file" -> get:
  await ctx.sendReactFile("static" / ctx.pathParams["file"])

"/uploadfile" -> post:
  var form = ctx.multipartForm()
  if "file" in form:
    echo "recieved ", form["file"].name
    pdfChan.send(unsafeIsolate move form["file"])
    ctx.send "Processing"
  else:
    ctx.send(ErrorMsg(msg: "Invalid upload, make sure the file is in the `file` param", code: 403))

"/search" -> get:
  if "query" in ctx.queryParams:
    let query = ctx.queryParams["query"]
    var resp = newJObject()
    withDB:
      for r in db.searchFor(query):
        let id = $r.pdf
        if id notin resp:
          resp[id] = db.getPDF(r.pdf).get().toJson()
          resp[id]["pages"] = newJArray()
        resp[id]["pages"] &= %r.page
    # TODO: Sort the PDFs according to how many results were in each one
    ctx.send(resp)
  else:
    ctx.send(ErrorMsg(msg: "Missing `query` query parameter", code: 403))

"/pdf/:id" -> get:
  if ctx.pathParams["id"].len != nanoIDSize:
    ctx.send(ErrorMsg(msg: "Invalid ID", code: 403))
  else:
    let id = ctx.pathParams["id"].parseNanoID()
    var info: Option[PDFFileInfo]
    withDB: info = db.getPDF(id)
    if info.isSome:
      # Generate a weak ETag to allow the client to cache the PDFs
      # It will just be a hash of the last modification time
      var etag: string
      etag &= "W/\""
      etag &= $toMD5(info.get().lastModified.format(timeFormat))
      etag &= "\""
      # Then check if the client should reuse their cache or not
      if ctx.getHeader("ETag", "") == etag:
        ctx.send("Use cache", Http304)
      else:
        ctx.setHeader("ETag", etag)
        await ctx.sendFile("pdfs" / $id & ".pdf")
    else:
      ctx.send(ErrorMsg(msg: "Couldn't find pdf: " & $id, code: 404))
    
run(threads = 1)
