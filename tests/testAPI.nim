import std/[
  unittest,
  httpclient,
  osproc,
  os,
  streams,
  json,
  sequtils
]

let serverProcess = startProcess(
  "nim c -r -f -d:databaseFile=':memory:' src/tsuil.nim",
  options = {poStdErrToStdOut, poUsePath, poEvalCommand}
)

let client = newHttpClient()

func serverUrl(path: string): string =
  result = "http://127.0.0.1:8080" & path

proc post(path: string, body = "", multipart: MultipartData = nil): Response =
  client.post(serverUrl path, body, multipart)

proc get(path: string): Response =
  client.get(serverUrl path)

# Wait for server to start
while serverProcess.running:
  try:
    discard get("/")
    break
  except OSError:
    echo "Waiting..."
    sleep 1000
    discard

assert serverProcess.running, serverProcess.outputStream().readAll()


template uploadPDF(file: string) =
  var form = newMultipartData()
  form.addFiles({"file": file})
  let resp {.inject.} = post("/pdf", multipart = form)
  let body {.inject.} = resp.body.parseJson()

suite "Uploading PDFs":
  test "Uploading real PDF":
    uploadPDF("tests/example.pdf")
    check resp.code == Http200
    check body["success"].bval

  test "Cannot reupload PDF":
    uploadPDF("tests/example.pdf")
    check resp.code == Http400
    check body == %* {
      "success": false,
      "msg":"File is already in database"
    }

  test "Cannot upload fake PDF":
    uploadPDF("tests/notpdf.pdf")
    check resp.code == Http400
    check body == %* {
      "success": false,
      "msg": "File is not a PDF"
    }

# test "Delete PDF":
  # client.delete serverUrl("/pdf/" &

test "Searching":
  let resp = get("/search?query=first")
  check resp.code == Http200
  let body = resp.body.parseJson()
  let ids = toSeq(body.keys)
  check ids.len == 1
  let pdf = body[ids[0]]
  check:
    pdf["title"].str == "Example Title"
    pdf["author"].str == "John Doe"
    pdf["hash"].str == "B198598A60CBE85FA77AFF44119ACF36986F6FAF"
    pdf["pages"] == % @[1]

# test "Updating PDF":

client.close()
kill serverProcess
close serverProcess