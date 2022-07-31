import std/[
  unittest,
  sequtils,
  sha1
]

import tiny_sqlite
import database, pdfscraper, types

let db = openDatabase(":memory:")

const pdfFile = "tests/example.pdf"

test "Creating tables":
  db.createTables()

var id: NanoID # ID of the PDF we are testing with

suite "PDF info":
  var info = getPDFInfo(pdfFile)
  
  test "Inserting":
    id = db.insert info
    check info.filename == "example.pdf"
    check db.value("SELECT COUNT(*) FROM PDF").get().intVal == 1

  test "Getting all":
    info.id = id
    check db.getPDFs() == @[info]
    
  test "Retrieving via ID":
    let dbInfo = db.getPDF(id).get()
    check:
      dbInfo.title == info.title
      dbInfo.lastModified == info.lastModified

  test "Can't add same PDF":
    expect SqliteError:
      db.insert getPDFInfo(pdfFile)

  test "Updating Info":
    let newInfo = PDFUpdate(
      title: "New title",
      subject: "Computing"
    )
    db.update(id, newInfo)
    let dbInfo = db.getPDF(id).get()
    check:
      dbInfo.title == "New title"
      dbInfo.subject == "Computing"

  test "Getting all subjects":
    check db.getSubjects() == @["Computing"]    
    

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
