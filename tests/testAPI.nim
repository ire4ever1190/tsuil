import std/[
  unittest,
  httpclient,
  osproc,
  os,
  streams,
  json
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



suite "Uploading PDFs":
  template uploadPDF(file: string) =
    var form = newMultipartData()
    form.addFiles({"file": file})
    let resp {.inject.} = post("/pdf", multipart = form)

  test "Uploading real PDF":
    uploadPDF("tests/example.pdf")
    let body = resp.body.parseJson()
    check resp.code == Http200
    check body["success"].bval

  test "Cannot reupload PDF":
    uploadPDF("tests/example.pdf")
    let body = resp.body.parseJson()
    check body == %* {
      "success":false,
      "msg":"File is already in database"
    }

client.close()
kill serverProcess
close serverProcess