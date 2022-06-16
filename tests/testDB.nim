import std/[
  unittest,
  sequtils
]

import tiny_sqlite
import database, pdfscraper

let db = openDatabase(":memory:")

const pdfFile = "tests/example.pdf"

test "Creating tables":
  db.createTables()

var id: int64 # ID of the PDF we are testing with

suite "PDF info":
  let info = getPDFInfo(pdfFile)
  test "Inserting":
    id = db.insert info
    check db.value("SELECT COUNT(*) FROM PDF").get().intVal == 1
    
  test "Retrieving via ID":
    let dbInfo = db.getPDF(id).get()
    check:
      dbInfo.title == info.title
      dbInfo.creationDate == info.creationDate

suite "Pages":
  let pages = toSeq: getPDFPages(pdfFile)
  test "Inserting":
    var i = 1
    for page in pages:
      db.insertPage(id, i, page)
      inc i

  test "Searching for generic text":
    let results = db.searchFor("page")
    check results.len == 2

  test "Search for specific text":
    let results = db.searchFor("First page")
    check results.len == 1
    check results[0].page == 1
