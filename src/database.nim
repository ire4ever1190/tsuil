
import std/[
  times,
  options,
  sha1
]

import pkg/[
  tiny_sqlite,
  anano
]

import common

const tablesScript = slurp("tables.sql")

using db: DbConn


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
  DBValue(kind: sqliteBlob, blobVal: @cast[array[nanoIDSize, byte]](dt))

proc fromDBValue(value: DBValue, T: typedesc[NanoID]): NanoID =
  ## Get the ID back from the value
  for i in 0 ..< nanoIDSize:
    result[i] = char(value.blobVal[i])

proc toDBValue(hash: SecureHash): DBValue =
  ## Converts hash into blob
  DBValue(kind: sqliteBlob, blobVal: @cast[array[0..19, byte]](hash))

proc fromDbValue(value: DBValue, T: typedesc[SecureHash]): SecureHash =
  ## Gets hash back from the value
  for i in 0..19:
    result.Sha1Digest[i] = uint8(value.blobVal[i])

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


proc insert*(db; pdf: PDFFileInfo, id = genNanoID()): NanoID {.discardable.} =
  ## Inserts PDF metadata into the database.
  ## Returns the ID that was generated for it
  const stmt = """
      INSERT INTO PDF (id, title, lastModified, pages, author, keywords, subject, filename, hash)
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
  """
  db.exec(stmt, id, pdf.title, pdf.lastModified, pdf.pages, pdf.author, pdf.keywords, pdf.subject, pdf.filename, pdf.hash)
  result = id

proc deletePDF*(db; id: NanoID) =
  ## Deletes the PDF from the database
  const stmt = """
    DELETE FROM PDF
    WHERE ID = ?
  """
  db.exec(stmt, id)

proc insertPage*(db; pdfID: NanoID, num: int, body: string) =
  ## Inserts a page into the database.
  ## PDFs metadata must already exist
  const stmt = """
    INSERT INTO PAGE_fts (id, num, body)
    VALUES (
      ?, ?, ?
    )
  """
  db.exec(stmt, pdfID, num, body)

proc update*(db; id: NanoID, update: PDFUpdate) =
  ## Updates a PDF with the values in update
  const stmt = """
    UPDATE PDF
    SET title = ?, subject = ?
    WHERE id = ?
  """
  db.exec(stmt, update.title, update.subject, id)

proc searchFor*(db; query: string): seq[SearchResult] =
  ## Searches for some text and then returns
  ## list of results (which have the pdf and page)
  const stmt = """
    SELECT id, num
    FROM PAGE_fts
    WHERE body MATCH ?
      ORDER BY RANK
    LIMIT 25
  """
  for row in db.iterate(stmt, query):
    result &= SearchResult(
      page: fromDBValue(row["num"], int),
      pdf: fromDBValue(row["id"], NanoID)
    )

proc getPDF*(db; pdfID: NanoID): Option[PDFFileInfo] =
  ## Get metadata on PDF from its ID
  const stmt = """
    SELECT id as id, title, lastModified, pages, author, keywords, subject, filename, hash
    FROM PDF
    WHERE id = ?
  """
  result = some db.one(stmt, pdfID).get().to(PDFFileInfo)

proc getPDFs*(db;): seq[PDFFileInfo] =
  ## Gets all PDFS in database
  # TODO: implement pagination
  const stmt = """
     SELECT id as id, title, lastModified, pages, author, keywords, subject, filename, hash
     FROM PDF
     ORDER BY lastModified DESC
  """
  for row in db.iterate(stmt):
    result &= row.to(PDFFileInfo)

proc getSubjects*(db): seq[string] =
  ## Gets list of all subjects in the database
  const stmt = """
    SELECT DISTINCT(subject)
    FROM PDF
  """
  for row in db.iterate(stmt):
    result &= row[0].strVal

export tiny_sqlite
export anano
#
