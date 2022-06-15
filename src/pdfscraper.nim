## Contains tools for getting information from a pdf
import std/[
  times,
  osproc,
  parseutils,
  strutils
]

type
  PDFFileInfo* = object
    title*: string
    creationDate*: DateTime
    pages*: int
    author*: string
    keywords*: string
    subject*: string 

const 
  processOptions = {poStdErrToStdOut, poUsePath}
  timeFormat = "yyyy-MM-dd'T'hh:mm:sszz" # ISO-8601
  
proc getPDFInfo*(path: string): PDFFileInfo =
  ## Uses `pdftotext` to scrape PDF information
  let process = startProcess("pdfinfo", args = [path, "-isodates"], options = processOptions)
  defer: process.close()
  for line in process.lines:
    # Get key and value
    var key: string
    var i = line.parseUntil(key, ':') + 1
    # Value is padded to look pretty so remove that
    i += line.skipWhitespace(i)
    let value = line[i..^1]
    
    case key
    of "Title":
      result.title = value
    of "Subject":
      result.subject = value
    of "Pages":  
      result.pages = value.parseInt()
    of "Author":
      result.author = value
    of "Keywords":
      result.keywords = value
    of "CreationDate":
      result.creationDate = value.parse(timeFormat)
    else: discard

iterator getPDFPages*(path: string): string =
  ## Returns the pages in the PDF
  let process = startProcess("pdftotext", args = [path, "-"], options = processOptions)
  defer: process.close()
  var currLine: string
  for line in process.lines:
    echo line
    if '\f' in line:
      yield currLine
      currLine.setLen(0)
    currLine &= line & '\n'
  # yield currLine
