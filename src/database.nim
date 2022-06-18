
import std/[
  times,
  options
]

import tiny_sqlite
import common, pdfscraper
import anano

const tablesScript = slurp("tables.sql")

using db: DbConn

type
  SearchResult* = object
    page*: int
    pdf*: NanoID

#
# Converters
#

proc toDBValue(dt: DateTime): DBValue =
  ## Converts DateTime into a string for SQLite
  DBValue(kind: sqliteText, strVal: dt.format(timeFormat))

proc fromDBValue(value: DBValue, T: typedesc[DateTime]): DateTime =
  ## Converts string from SQLite into a DateTime
  value.strVal.parse(timeFormat, tz = utc())

proc toDBValue(dt: NanoID): DBValue =
  ## Converts a NanoID into an sqlite blob (more efficient than string)
  DBValue(kind: sqliteBlob, blobVal: @dt)

proc fromDBValue(value: DBValue, T: typedesc[NanoID]): NanoID =
  ## Get the ID back from the value
  for i in 0 ..< nanoIDSize:
    result[i] = value.blobVal[i]

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


proc insert*(db; pdf: PDFFileInfo): NanoID {.discardable.} =
  ## Inserts PDF metadata into the database.
  ## Returns the ID that SQLite gave it
  const stmt = """
      INSERT INTO PDF (id, title, lastModified, pages, author, keywords, subject, filename)
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?
      )
  """
  let id = genNanoID()
  db.exec(stmt, id, pdf.title, pdf.lastModified, pdf.pages, pdf.author, pdf.keywords, pdf.subject, pdf.filename)
  result = id

proc insertPage*(db; pdfID: NanoID, num: int, body: string) {.discardable.} =
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
      pdf: fromDBValue(row["id"], NanoID)
    )
    
proc getPDF*(db; pdfID: NanoID): Option[PDFFileInfo] =
  ## Get metadata on PDF from its ID
  const stmt = """
    SELECT title, lastModified, pages, author, keywords, subject, filename
    FROM PDF
    WHERE id = ?
  """
  result = some db.one(stmt, pdfID).get().to(PDFFileInfo)

export tiny_sqlite
export anano
