import mike
import mike/errors
import common
import database
import pdfscraper
import std/[
  os,
  tables,
  locks,
  strutils,
  json,
  md5,
  times,
  algorithm,
  setutils,
  sha1
]
from tiny_sqlite import SqliteError
import asyncthreadpool

const
  # Move this stuff to config file
  pdfFolder = "pdfs"
  databaseFile {.strdefine.} = "database.db"

proc `%`(id: NanoID): JsonNode =
  result = % $id

var
  dbLock: Lock 
  db {.guard: dbLock.} = openDatabase(databaseFile)

template withDB(body: untyped) =
  ## Run a block of code with the DB lock turned on
  ## Also turns on gcsafe since it is protected
  withLock dbLock:
    {.gcsafe.}:
      body

db.createTables()

proc process(name, file: string): Option[string] =
  ## Processes a PDF file
  ## - writes to disk
  ## - gets info
  ## - adds to database
  ## Errors are return in result (if isSome)
  # Write the file
  let path = pdfFolder / name
  discard existsOrCreateDir(pdfFolder)
  
  path.writeFile(file)
  if not path.isPDF():
    removeFile file
    return some"File is not a PDF"
  
  withDB:
    let info = path.getPDFInfo()
    var pdfID: NanoID
    try:
      pdfID = db.insert info
    except SqliteError as e:
      # Might not be exact error, but most likely thing that happened
      result = some"File is already in database"
    if result.isNone:
      # result = some $pdfID
      let newPath = pdfFolder / $pdfID & ".pdf"
      moveFile(path, newPath)
      var i = 1
      for page in newPath.getPDFPages():
        db.insertPage(pdfID, i, page)
        inc i

# Pretty overkill to have seperate worker thread
# since it completes fast but wanted to try it out
var pdfWorker = newThreadPool()

const index = slurp("../public/index.html")

import std/httpclient

proc sendReactFile(ctx: Context, path: string) {.async.} =
  ## When in release mode it gets the files from the build folder
  ## During debug it makes a request to the dev server and returns response (hacky yes, but works)
  when defined(release):
    await ctx.sendFile(getAppDir() / "build" / path)
  else:
    let client = newAsyncHttpClient()
    defer: client.close()
    let resp = await client.request("http://127.0.0.1:3000/" & path)
    ctx.send(await resp.body, resp.code, resp.headers)

"/" -> get:
  await ctx.sendReactFile("index.html")

"/static/^file" -> get:
  await ctx.sendReactFile("static" / ctx.pathParams["file"])

"/pdf" -> post:
  var form = ctx.multipartForm()
  if "file" in form:
    echo "recieved ", form["file"].name
    let
      name = form["file"].name
      file = form["file"].value
    {.gcsafe.}:
      let resVal = await pdfWorker.spawn process(
        name,
        file
      )
    # Wait for it to be processed
    let status = if resVal.isNone: Http200 else: Http400
    ctx.send(%*{"success": resVal.isNone, "msg": resVal.get("")}, status)
  else:
    raise (ref KeyError)(msg: "Invalid upload, make sure the file is in the `file` param")

# "/pdf/:id" -> delete:


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
    raise (ref KeyError)(msg: "Missing `query` query parameter")

"/pdf/:id" -> get:
  let strID = ctx.pathParams["id"]
  if strID.len != nanoIDSize:
    raise (ref KeyError)(msg: "PDF with id " & strID & " is not valid")
  else:
    let id = ctx.pathParams["id"].parseNanoID()
    var info: Option[PDFFileInfo]
    withDB: info = db.getPDF(id)
    if info.isSome:
      # Generate a weak ETag to allow the client to cache the PDFs
      # It will just be a hash of the last modification time
      var etag = $info.get().hash
      # Then check if the client should reuse their cache or not
      if ctx.getHeader("ETag", "") == etag:
        ctx.send("Use cache", Http304)
      else:
        ctx.setHeader("ETag", etag)
        await ctx.sendFile("pdfs" / $id & ".pdf")
    else:
      raise (ref NotFoundError)(msg: "Couldn't find pdf: " & strID)

run(threads = 1, port = 4356)
