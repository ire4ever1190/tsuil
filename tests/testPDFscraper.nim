import std/unittest
import pdfscraper
import std/times
import std/sequtils
import std/strutils

test "Getting info":
  let info = getPDFInfo("tests/example.pdf")
  check:
    info.title == "Example Title"
    info.creationDate == "2022-06-15T14:20:53+10".parse("yyyy-MM-dd'T'hh:mm:sszz")
    info.subject == "Example Subject"
    info.keywords == "Some Keywords"
    info.author == "John Doe"
    info.pages == 2
    
test "Getting pages":
  let pages = toSeq: getPDFPages("tests/example.pdf")
  check:
    pages.len == 2
    pages[0].strip() == "First page\n\n1"
    pages[1].strip() == "Second page\n\n2"
