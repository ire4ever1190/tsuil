
import std/[
  times
]

import tiny_sqlite

import common, pdfscraper

const tablesScript = slurp("tables.sql")

using db: DbConn

type
  SearchResult* = object
    page*: int
    pdf*: int64

#
# Converters
#

proc toDBValue(dt: DateTime): DbValue =
  ## Converts DateTime into a string for SQLite
  DBValue(kind: sqliteText, strVal: dt.format(timeFormat))

proc fromDBValue(value: DbValue, T: typedesc[DateTime]): DateTime =
  ## Converts string from SQLite into a DateTime
  value.strVal.parse(timeFormat, tz = utc())

#
# Utils
#

proc createTables*(db) =
  ## Creates all the tables
  db.execScript(tablesScript)

proc to[T](x: ResultRow, obj: typedesc[T]): T =
  for field, value in result.fieldPairs():
    value = fromDBValue(x[field], typeof(value))
  
#
# Access procs
#


proc insert*(db; pdf: PDFFileInfo): int64 {.discardable.} =
  ## Inserts PDF metadata into the database.
  ## Returns the ID that SQLite gave it
  const stmt = """
      INSERT INTO PDF (title, creationDate, pages, author, keywords, subject, filename)
      VALUES (
        ?, ?, ?, ?, ?, ?, ?
      )
  """
  db.exec(stmt, pdf.title, pdf.creationDate, pdf.pages, pdf.author, pdf.keywords, pdf.subject, pdf.filename)
  result = db.lastInsertRowID()

proc insertPage*(db; pdfID: int64, num: int, body: string) {.discardable.} =
  ## Inserts a page into the database.
  ## PDFs metadata must already exist
  const stmt = """
    INSERT INTO PAGE_fts (id, num, body)
    VALUES (
      ?, ?, ?
    )
  """
  db.exec(stmt, pdfID, num, body)

proc searchFor*(db; query: string): seq[SearchResult] =
  ## Searches for some text and then returns 
  ## list of results (which have the pdf and page)
  const stmt = """
    SELECT id, num 
    FROM PAGE_fts 
    WHERE body MATCH ? 
      ORDER BY RANK
  """
  for row in db.iterate(stmt, query):
    result &= SearchResult(
      page: fromDBValue(row["num"], int),
      pdf: fromDBValue(row["id"], int64)
    )
    
proc getPDF*(db; pdfID: int64): PDFFileInfo =
  ## Get metadata on PDF from its ID
  const stmt = """
    SELECT title, creationDate, pages, author, keywords, subject, filename
    FROM PDF
    WHERE id = ?
  """
  result = db.one(stmt, pdfID).get().to(PDFFileInfo)

export tiny_sqlite
