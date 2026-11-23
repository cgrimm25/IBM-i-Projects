**Free
//========================================================================
// Program:     BOOKIMPORT.SQLRPGLE
// Programmer:  Chris Grimm
// Date:        11/19/2026
//
// Description:
//     Batch ingestion program that streams UTF-8 CSV book records from
//     the IFS (Books.csv) via QSYS2.IFS_READ_UTF8, parses RFC-4180
//     quoted columns, sanitizes all 23 fields, and loads the BOOKS Db2
//     table under Commitment Control.
//
// DB Files:    BOOKS        (Db2 SQL Table - Library Catalog)
//
// Maintenance Log:
// Date       Author       Description
// ---------- ------------ -----------------------------------------------
// 11/19/2026 Chris Grimm  Initial program creation.
//========================================================================

Ctl-Opt DftActGrp(*No) ActGrp(*New) Option(*SrcStmt: *NoDebugIo);

// External Printer File Declaration
Dcl-F BOOKERRP Printer(*Ext) OflInd(PageOfl) UsrOpn;

// Constants
Dcl-C MAX_COLS 23;
Dcl-C IFS_PATH '/home/CGRIMM/Books.csv';

// Indicators & Counters
Dcl-S PageOfl       Ind Inz(*Off);
Dcl-S LoadedCount   Int(10) Inz(0);
Dcl-S SkippedCount  Int(10) Inz(0);

// Array to hold parsed CSV columns for a single row
Dcl-S CsvCols VarChar(300) Dim(MAX_COLS);

// Sanitized Book Record Data Structure (Maps all 23 columns of BOOKS)
Dcl-Ds BookRec Qualified;
  BookId      Int(10);
  GrBookId    Int(10);
  BstBookId   Int(10);
  WorkId      Int(10);
  BooksCnt    Int(10);
  Isbn        VarChar(20);
  Isbn13      VarChar(20);
  Authors     VarChar(250);
  PubYear     Int(10);
  OrigTitle   VarChar(250);
  Title       VarChar(250);
  LangCode    VarChar(15);
  AvgRating   Packed(3:2);
  RatingsCnt  Int(10);
  WrkRatCnt   Int(10);
  WrkRevCnt   Int(10);
  Ratings1    Int(10);
  Ratings2    Int(10);
  Ratings3    Int(10);
  Ratings4    Int(10);
  Ratings5    Int(10);
  ImageUrl    VarChar(255);
  SmImgUrl    VarChar(255);
End-Ds;

// Processing Variables
Dcl-S LineNum   Int(10);
Dcl-S RawLine   VarChar(2500) Ccsid(1208);
Dcl-S ErrReason VarChar(34);

// Configure SQL Commitment Control
Exec Sql Set Option Commit = *Chg, CloSqlCsr = *EndMod;

// Open Printer File and print initial report headers
Open BOOKERRP;
PrintReportHeaders();

// Clear previous catalog data before fresh import
Exec Sql Delete From BOOKS;

// Declare cursor to stream UTF-8 lines from IFS (skipping header row 1)
Exec Sql Declare CsvCursor Cursor For
  Select Line_Number, Cast(Line As VarChar(2500) Ccsid 1208)
    From Table(Qsys2.Ifs_Read_Utf8(Path_Name => :IFS_PATH))
   Where Line_Number > 1;

Exec Sql Open CsvCursor;

DoU SqlCode <> 0;
  Exec Sql Fetch Next From CsvCursor Into :LineNum, :RawLine;
  If SqlCode <> 0;
    Leave;
  EndIf;

  // Parse CSV line into CsvCols array
  ParseCsvLine(RawLine : CsvCols);

  // Map and sanitize all 23 columns into BookRec
  If MapAndSanitize(CsvCols : BookRec : ErrReason);
    Exec Sql
      Insert Into BOOKS (
        BOOK_ID, GOODREADS_BOOK_ID, BEST_BOOK_ID, WORK_ID, BOOKS_COUNT,
        ISBN, ISBN13, AUTHORS, ORIGINAL_PUBLICATION_YEAR, ORIGINAL_TITLE,
        TITLE, LANGUAGE_CODE, AVERAGE_RATING, RATINGS_COUNT,
        WORK_RATINGS_COUNT, WORK_TEXT_REVIEWS_COUNT,
        RATINGS_1, RATINGS_2, RATINGS_3, RATINGS_4, RATINGS_5,
        IMAGE_URL, SMALL_IMAGE_URL
      ) Values (
        :BookRec.BookId, :BookRec.GrBookId, :BookRec.BstBookId,
        :BookRec.WorkId, :BookRec.BooksCnt, :BookRec.Isbn,
        :BookRec.Isbn13, :BookRec.Authors, :BookRec.PubYear,
        :BookRec.OrigTitle, :BookRec.Title, :BookRec.LangCode,
        :BookRec.AvgRating, :BookRec.RatingsCnt, :BookRec.WrkRatCnt,
        :BookRec.WrkRevCnt, :BookRec.Ratings1, :BookRec.Ratings2,
        :BookRec.Ratings3, :BookRec.Ratings4, :BookRec.Ratings5,
        :BookRec.ImageUrl, :BookRec.SmImgUrl
      );

    If SqlCode = 0;
      LoadedCount += 1;
    Else;
      SkippedCount += 1;
      PrintErrorLine(LineNum : 'SQL Insert Error: ' + %Char(SqlCode) : RawLine);
    EndIf;
  Else;
    SkippedCount += 1;
    PrintErrorLine(LineNum : ErrReason : RawLine);
  EndIf;
EndDo;

Exec Sql Close CsvCursor;

// Commit all imported books
Exec Sql Commit;

// Print summary footer and close printer file
If SkippedCount = 0;
  Write NOERRORS;
EndIf;

PrtLoaded  = LoadedCount;
PrtSkipped = SkippedCount;
Write RPTSUMMARY;
Write RPTOTALS;

Close BOOKERRP;

Dsply ('BOOKIMPORT Loaded: ' + %Char(LoadedCount));
Dsply ('BOOKIMPORT Skipped: ' + %Char(SkippedCount));

*InLr = *On;
Return;

//========================================================================
// Procedure:   PrintReportHeaders
// Description: Writes page and column headers to BOOKERRP.
//========================================================================
Dcl-Proc PrintReportHeaders;
  Write RPTHEADER;
  Write RPTSUBHDR;
  Write COLHEADER;
  Write COLUNDER;
  PageOfl = *Off;
End-Proc;

//========================================================================
// Procedure:   PrintErrorLine
// Description: Prints a rejected CSV row to BOOKERRP and handles page
//              overflow automatically.
//========================================================================
Dcl-Proc PrintErrorLine;
  Dcl-Pi *N;
    InLineNum Int(10) Const;
    InReason  VarChar(34) Const;
    InRawLine VarChar(2500) Const;
  End-Pi;

  If PageOfl;
    PrintReportHeaders();
  EndIf;

  PrtLineNum = InLineNum;
  PrtReason  = InReason;
  If InRawLine <> '';
    PrtRawData = %Subst(InRawLine : 1 : %Min(%Len(InRawLine) : 82));
  Else;
    PrtRawData = '';
  EndIf;

  Write DETAIL;
End-Proc;

//========================================================================
// Procedure:   ParseCsvLine
// Description: Splits an RFC-4180 CSV line into fields while respecting
//              double-quoted strings containing commas.
//========================================================================
Dcl-Proc ParseCsvLine;
  Dcl-Pi *N;
    InLine   VarChar(2500) Const;
    OutCols  VarChar(300) Dim(MAX_COLS);
  End-Pi;

  Dcl-S i        Int(10);
  Dcl-S Len      Int(10);
  Dcl-S ColIdx   Int(10) Inz(1);
  Dcl-S InQuotes Ind Inz(*Off);
  Dcl-S Ch       Char(1);
  Dcl-S Buffer   VarChar(300) Inz('');

  Clear OutCols;
  Len = %Len(InLine);

  For i = 1 To Len;
    Ch = %Subst(InLine : i : 1);

    If Ch = '"';
      If InQuotes And i < Len And %Subst(InLine : i + 1 : 1) = '"';
        Buffer += '"';
        i += 1;
      Else;
        InQuotes = Not InQuotes;
      EndIf;
    ElseIf Ch = ',' And Not InQuotes;
      If ColIdx <= MAX_COLS;
        OutCols(ColIdx) = %Trim(Buffer);
        ColIdx += 1;
      EndIf;
      Buffer = '';
    Else;
      If %Len(Buffer) < 300;
        Buffer += Ch;
      EndIf;
    EndIf;
  EndFor;

  If ColIdx <= MAX_COLS;
    OutCols(ColIdx) = %Trim(Buffer);
  EndIf;
End-Proc;

//========================================================================
// Procedure:   MapAndSanitize
// Description: Converts raw CSV text columns into typed Db2 fields across
//              all 23 columns of Books.csv.
//========================================================================
Dcl-Proc MapAndSanitize;
  Dcl-Pi *N Ind;
    Cols      VarChar(300) Dim(MAX_COLS) Const;
    Book      LikeDs(BookRec);
    OutReason VarChar(34);
  End-Pi;

  Clear Book;
  OutReason = '';

  Monitor;
    // Required fields check
    If Cols(1) = '';
      OutReason = 'Missing required BOOK_ID';
      Return *Off;
    EndIf;
    If Cols(8) = '';
      OutReason = 'Missing required AUTHORS';
      Return *Off;
    EndIf;
    If Cols(11) = '';
      OutReason = 'Missing required TITLE';
      Return *Off;
    EndIf;

    // Identifiers (Cols 1-5)
    Book.BookId    = ParseCleanInt(Cols(1));
    Book.GrBookId  = ParseCleanInt(Cols(2));
    Book.BstBookId = ParseCleanInt(Cols(3));
    Book.WorkId    = ParseCleanInt(Cols(4));
    Book.BooksCnt  = ParseCleanInt(Cols(5));

    // Publication Info (Cols 6-12)
    Book.Isbn      = SafeSubstr(Cols(6)  : 20);
    Book.Isbn13    = SafeSubstr(Cols(7)  : 20);
    Book.Authors   = SafeSubstr(Cols(8)  : 250);
    Book.PubYear   = ParseCleanInt(Cols(9));
    Book.OrigTitle = SafeSubstr(Cols(10) : 250);
    Book.Title     = SafeSubstr(Cols(11) : 250);
    Book.LangCode  = SafeSubstr(Cols(12) : 15);

    // Ratings & Reviews (Cols 13-21)
    If Cols(13) <> '';
      Book.AvgRating = %Dec(Cols(13) : 3 : 2);
    EndIf;
    Book.RatingsCnt = ParseCleanInt(Cols(14));
    Book.WrkRatCnt  = ParseCleanInt(Cols(15));
    Book.WrkRevCnt  = ParseCleanInt(Cols(16));
    Book.Ratings1   = ParseCleanInt(Cols(17));
    Book.Ratings2   = ParseCleanInt(Cols(18));
    Book.Ratings3   = ParseCleanInt(Cols(19));
    Book.Ratings4   = ParseCleanInt(Cols(20));
    Book.Ratings5   = ParseCleanInt(Cols(21));

    // Image Links (Cols 22-23)
    Book.ImageUrl  = SafeSubstr(Cols(22) : 255);
    Book.SmImgUrl  = SafeSubstr(Cols(23) : 255);

    Return *On;
  On-Error;
    OutReason = 'Numeric data conversion error';
    Return *Off;
  EndMon;
End-Proc;

//========================================================================
// Procedure:   ParseCleanInt
// Description: Safely converts numeric strings (including decimals like
//              "2008.0" or blanks) into an integer value.
//========================================================================
Dcl-Proc ParseCleanInt;
  Dcl-Pi *N Int(10);
    InStr VarChar(300) Const;
  End-Pi;

  Dcl-S CleanStr VarChar(50);
  Dcl-S DotPos   Int(10);

  CleanStr = %Trim(InStr);
  If CleanStr = '';
    Return 0;
  EndIf;

  DotPos = %Scan('.' : CleanStr);
  If DotPos > 1;
    CleanStr = %Subst(CleanStr : 1 : DotPos - 1);
  ElseIf DotPos = 1;
    Return 0;
  EndIf;

  Return %Int(CleanStr);
End-Proc;

//========================================================================
// Procedure:   SafeSubstr
// Description: Safely truncates a VarChar string to target column width.
//========================================================================
Dcl-Proc SafeSubstr;
  Dcl-Pi *N VarChar(255);
    InStr  VarChar(300) Const;
    MaxLen Int(10) Const;
  End-Pi;

  If InStr = '';
    Return '';
  EndIf;

  Return %Subst(InStr : 1 : %Min(%Len(InStr) : MaxLen));
End-Proc;
