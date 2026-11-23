# IBM i Library Catalog CSV Batch Importer (`BOOKIMPORT`)

A free-form SQLRPGLE (`**Free`) batch ingestion utility and external DDS audit report for IBM i that streams UTF-8 CSV book catalog records from the Integrated File System (IFS), parses RFC-4180 quoted fields, sanitizes all 23 columns, and loads a Db2 for i SQL table under Commitment Control.

## Repository Structure

```text
CSV-Importer/
├── Data/
│   ├── Books.csv               # UTF-8 23-column book catalog dataset for IFS ingestion
│   ├── BOOKS.SQL               # SQL DDL script defining the BOOKS table, system names, PK, and indexes
│   └── BOOKSSAVF.SAVF          # Reference IBM i save file containing the expected post-import BOOKS *FILE object
├── Bookerrp.prtf               # External 132-column DDS printer file for import audit & exception reporting
├── Bookimport.sqlrpgle         # Main **Free SQLRPGLE batch ingestion and sanitization program
└── README.md                   # Project documentation and setup instructions
```

---

## Key Technical Features

* **Native IFS UTF-8 Streaming:** Uses Db2's `QSYS2.IFS_READ_UTF8` table function to stream lines directly from `/home/CGRIMM/Books.csv` in CCSID `1208` (UTF-8), skipping the header row (`Line_Number > 1`)[cite: 22].
* **Custom RFC-4180 CSV Parser (`ParseCsvLine`):** Character-by-character state parser that splits comma-delimited columns while preserving embedded commas and escaped double quotes (`""`) inside quoted strings[cite: 22].
* **Data Sanitization & Type Safety (`MapAndSanitize`):**
  * Validates required fields (`BOOK_ID`, `AUTHORS`, `TITLE`) prior to database insertion[cite: 22].
  * Strips trailing decimals from integer fields (e.g., `"2008.0"` → `2008`) via `ParseCleanInt`[cite: 22].
  * Safely truncates oversized text strings to target Db2 column widths via `SafeSubstr`[cite: 22].
  * Wraps conversions in a `Monitor` / `On-Error` block so malformed rows are logged to the audit report rather than crashing the batch job[cite: 22].
* **Commitment Control (`*CHG`):** Clears existing records and inserts validated rows within a single transaction unit, issuing `EXEC SQL COMMIT` upon completion[cite: 22].
* **Exception & Audit Reporting (`BOOKERRP`):** Prints rejected line numbers, specific rejection reasons (or `SQLCODE` errors), an 82-character raw CSV snippet, and final loaded/skipped record totals[cite: 21, 22].

---

## Database Schema (`BOOKS`)

Defined in `Data/BOOKS.SQL`, the `BOOKS` table maps 23 long SQL column names to 10-character IBM i system names (`FOR COLUMN`) alongside search and sort indexes[cite: 24]:

| Category | SQL Column Name | System Name | Type & Constraints |
| :--- | :--- | :--- | :--- |
| **Identifiers** | `BOOK_ID` | `BOOKID` | `INTEGER NOT NULL` (`PK_BOOKS`)[cite: 24] |
| | `GOODREADS_BOOK_ID` | `GRBOOKID` | `INTEGER`[cite: 24] |
| | `BEST_BOOK_ID` | `BSTBOOKID` | `INTEGER`[cite: 24] |
| | `WORK_ID` | `WORKID` | `INTEGER`[cite: 24] |
| | `BOOKS_COUNT` | `BOOKSCNT` | `INTEGER`[cite: 24] |
| **Publication Info** | `ISBN` | `ISBN10` | `VARCHAR(20)`[cite: 24] |
| | `ISBN13` | `ISBN13NO` | `VARCHAR(20)`[cite: 24] |
| | `AUTHORS` | `AUTHOR` | `VARCHAR(250) NOT NULL`[cite: 24] |
| | `ORIGINAL_PUBLICATION_YEAR` | `PUBYEAR` | `INTEGER`[cite: 24] |
| | `ORIGINAL_TITLE` | `ORIGTITLE` | `VARCHAR(250)`[cite: 24] |
| | `TITLE` | `BKTITLE` | `VARCHAR(250) NOT NULL`[cite: 24] |
| | `LANGUAGE_CODE` | `LANGCODE` | `VARCHAR(15)`[cite: 24] |
| **Ratings & Metrics** | `AVERAGE_RATING` | `AVGRATING` | `DECIMAL(3, 2) NOT NULL DEFAULT 0.00`[cite: 24] |
| | `RATINGS_COUNT` | `RATINGSCNT` | `INTEGER NOT NULL DEFAULT 0`[cite: 24] |
| | `WORK_RATINGS_COUNT` | `WRKRATCNT` | `INTEGER NOT NULL DEFAULT 0`[cite: 24] |
| | `WORK_TEXT_REVIEWS_COUNT` | `WRKREVCNT` | `INTEGER NOT NULL DEFAULT 0`[cite: 24] |
| | `RATINGS_1` – `RATINGS_5` | `RATING1` – `RATING5` | `INTEGER NOT NULL DEFAULT 0`[cite: 24] |
| **Media Links** | `IMAGE_URL` | `IMAGEURL` | `VARCHAR(255)`[cite: 24] |
| | `SMALL_IMAGE_URL` | `SMIMGURL` | `VARCHAR(255)`[cite: 24] |

* **Indexes:** `IDX_BOOKS_ISBN`, `IDX_BOOKS_AUTHOR`, `IDX_BOOKS_YEAR`, `IDX_BOOKS_RATING`[cite: 24]

---

## Setup & Execution (RDi / IBM i)

1. **Create the `BOOKS` Table:**
   * Run `Data/BOOKS.SQL` using IBM i Access Client Solutions (**Run SQL Scripts**) or `RUNSQLSTM` targeting your library (e.g., `CGRIMM1`) to build the empty `BOOKS` table and indexes[cite: 24].
2. **Upload the CSV Dataset to the IFS:**
   * Upload `Data/Books.csv` to your IFS directory (default path in `Bookimport.sqlrpgle` is `/home/CGRIMM/Books.csv`; update the `IFS_PATH` constant if using a different directory)[cite: 22].
3. **Compile Objects in RDi:**
   * Compile `Bookerrp.prtf` (`CRTPRTF`).
   * Compile `Bookimport.sqlrpgle` (`CRTSQLRPGI` with `OBJTYPE(*PGM)`).
4. **Run the Batch Importer:**
   * Call `BOOKIMPORT` from a 5250 session or RDi command line to parse `Books.csv` and populate `BOOKS`:
     ```cl
     CALL PGM(<YOUR_LIB>/BOOKIMPORT)
     ```
   * Inspect the generated `BOOKERRP` spooled file (`WRKSPLF`) to verify total records loaded and review any skipped rows[cite: 21, 22].
5. **Reference Save File (`Data/BOOKSSAVF.SAVF`):**
   * `BOOKSSAVF.SAVF` is included as a reference snapshot of the populated `BOOKS` physical file (`*FILE` `PF`) so you can inspect or compare your imported results (`DSPSAVF` or `RSTOBJ` into a separate comparison library)[cite: 25].