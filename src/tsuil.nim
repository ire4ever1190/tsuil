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

import types

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

import std/httpclient

proc sendTsuilFile(ctx: Context, path: string) {.async.} =
  ## When in release mode it gets the files from the build folder
  ## During debug it makes a request to the dev server and returns response (hacky yes, but works)
  await ctx.sendFile("public" / path, dir = getAppDir())


"/" -> get:
  await ctx.sendTsuilFile("index.html")

"/favicon.ico" -> get:
  await ctx.sendTsuilFile("favicon.ico")

"/static/^file" -> get:
  await ctx.sendTsuilFile(ctx.pathParams["file"])

"/pdf" -> post:
  var form = ctx.multipartForm()
  if "file" in form:
    echo "recieved ", form["file"].name
    let
      name = form["file"].filename.get("file.pdf")
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


"/pdfs" -> get:
  withDB:
    ctx.send db.getPDFs().toJson()




"/search" -> get:
  if "query" in ctx.queryParams:
    let query = ctx.queryParams["query"]
    var resp = newJObject()
    withDB:
      for r in db.searchFor(query):
        let id = $r.pdf
        if id notin resp:
          resp[id] = newJObject()
          resp[id]["pdf"] = db.getPDF(r.pdf).get().toJson()
          resp[id]["pages"] = newJArray()
        resp[id]["pages"] &= %r.page
    # TODO: Sort the PDFs according to how many results were in each one
    ctx.send(resp)
  else:
    raise (ref KeyError)(msg: "Missing `query` query parameter")

template withID(testID: string, body: untyped) =
  ## Parses ID and runs body if its valid
  let strID {.inject.}= testID
  if strID.len != nanoIDSize:
    raise (ref KeyError)(msg: "PDF with id " & strID & " is not valid")
  else:
    let id {.inject.} = ctx.pathParams["id"].parseNanoID()
    body
    
"/pdf/:id" -> get:
  withID(ctx.pathParams["id"]):
    var info: Option[PDFFileInfo]
    withDB: info = db.getPDF(id)
    if info.isSome:
      # Generate a weak ETag to allow the client to cache the PDFs
      # It will just be a hash of the last modification time
      var etag = $info.get().hash
      # Then check if the client should reuse their cache or not
      if ctx.getHeader("If-None-Match", "") == etag:
        ctx.send("Use cache", Http304)
      else:
        ctx.setHeader("ETag", etag)
        await ctx.sendFile("pdfs" / $id & ".pdf")
    else:
      raise (ref NotFoundError)(msg: "Couldn't find pdf: " & strID)

"/pdf/:id" -> put:
  withID ctx.pathParams["id"]:
    withDB:
      echo ctx.json(PDFUpdate)
      db.update(id, ctx.json(PDFUpdate))
      echo "updated"

"/subjects" -> get:
  withDB:
    ctx.send db.getSubjects()

run(threads = 1, port = 4356)





