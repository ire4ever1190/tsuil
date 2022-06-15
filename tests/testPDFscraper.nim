import std/[
  strutils,
  sequtils,
  times,
  unittest
]

import pdfscraper
import common

test "Getting info":
  let info = getPDFInfo("tests/example.pdf")
  check:
    info.title == "Example Title"
    info.creationDate == "2022-06-15T14:20:53+10".parse(timeFormat)
    info.subject == "Example Subject"
    info.keywords == "Some Keywords"
    info.author == "John Doe"
    info.pages == 2
    info.filename == "example.pdf"
    
test "Getting pages":
  let pages = toSeq: getPDFPages("tests/example.pdf")
  check:
    pages.len == 2
    pages[0].strip() == "First page\n\n1"
    pages[1].strip() == "Second page\n\n2"
