import std/[
  strutils,
  sequtils,
  times,
  unittest
]

import pdfscraper
import common

const pdfFile = "tests/example.pdf"


test "Getting info":
  let info = getPDFInfo(pdfFile)
  check:
    info.title == "Example Title"
    info.lastModified == "2022-06-15T14:20:53+10".parse(timeFormat)
    info.subject == "Example Subject"
    info.keywords == "Some Keywords"
    info.author == "John Doe"
    info.pages == 2
    info.filename == "example.pdf"
    
test "Getting pages":
  let pages = toSeq: getPDFPages(pdfFile)
  check:
    pages.len == 2
    pages[0].strip() == "First page\n\n1"
    pages[1].strip() == "Second page\n\n2"

test "Checking is PDF":
  check pdfFile.isPDF()
  check not "tests/notpdf.pdf".isPDF()
