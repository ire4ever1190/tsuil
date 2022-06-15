import std/unittest

import tiny_sqlite
import database, pdfscraper

let db = openDatabase(":memory:")

test "Creating tables":
  db.createTables()

suite "PDF info":
  let info = getPDFInfo("tests/example.pdf")
  var id: int64
  test "Inserting":
    id = db.insert info
    check db.value("SELECT COUNT(*) FROM PDF").get().intVal == 1
    
  test "Retrieving via ID":
    let dbInfo = db.getPDF(id)
    check:
      dbInfo.title == info.title
      dbInfo.creationDate == info.creationDate
      
