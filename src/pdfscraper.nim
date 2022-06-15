## Contains tools for getting information from a pdf
import std/[
  times,
  osproc,
  parseutils,
  strutils,
  os
]

import common

type
  PDFFileInfo* = object
    ## Metadata associated with the PDF
    title*: string
    creationDate*: DateTime
    pages*: int
    author*: string
    keywords*: string
    subject*: string 
    filename*: string

const 
  processOptions = {poStdErrToStdOut, poUsePath}
  
proc getPDFInfo*(path: string): PDFFileInfo =
  ## Uses `pdftotext` to scrape PDF information
  result.filename = path.extractFileName()
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
      result.creationDate = value.parse(timeFormat, tz = utc())
    else: discard

iterator getPDFPages*(path: string): string =
  ## Returns the pages in the PDF
  let process = startProcess("pdftotext", args = [path, "-"], options = processOptions)
  defer: process.close()
  var currLine: string
  for line in process.lines:
    if '\f' in line:
      yield currLine
      currLine.setLen(0)
    currLine &= line & '\n'
