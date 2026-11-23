**Free
//=================================================================
// File:        LIBSRV.SQLRPGLE
// Programmer:  Chris Grimm
// Date:        11/22/2026
//
// Description:
//    Service program implementing encapsulated domain logic,
//    validation, DB2 persistence, and polymorphic formatting
//    for the Library Catalog application.
//
// DB Files:    CGRIMM1.BOOKS
//
// Maintenance Log:
// Date       Author       Description
// ---------- ------------ ----------------------------------------
// 11/22/2026 Chris Grimm  Initial OOP service program module.
// 11/22/2026 Chris Grimm  Flattened SQL host vars for SQL0314.
//=================================================================

Ctl-Opt NoMain Option(*SrcStmt: *NoDebugIo);

/Copy QRPGLESRC,LIBSRV_H

Exec Sql Set Option Commit = *None, CloSqlCsr = *EndMod;

// Private Helper Prototypes (Encapsulated - Not Exported)
Dcl-Pr GetNextBookId Packed(6:0);
End-Pr;

//=================================================================
// Constructor: Book_New
//=================================================================
Dcl-Proc Book_New Export;
  Dcl-Pi *N LikeDs(Book_t);
  End-Pi;

  Dcl-Ds newBook LikeDs(Book_t);

  Clear newBook;
  newBook.Item.BookId  = GetNextBookId();
  newBook.Item.PubYear = 0;
  newBook.Item.Rating  = 0.00;
  newBook.IsValid      = *Off;

  Return newBook;
End-Proc;

//=================================================================
// Method: Book_FindById
//=================================================================
Dcl-Proc Book_FindById Export;
  Dcl-Pi *N Ind;
    InBookId Packed(6:0) Const;
    OutBook  LikeDs(Book_t);
    OutMsg   VarChar(128);
  End-Pi;

  Dcl-Ds sqlItem LikeDs(CatalogItem_t);
  Dcl-S  searchId Packed(6:0);

  Clear OutBook;
  Clear OutMsg;
  searchId = InBookId;

  Exec Sql
    Select book_id,
           Coalesce(isbn, ''),
           Coalesce(title, ''),
           Coalesce(authors, ''),
           Coalesce(original_publication_year, 0),
           Coalesce(language_code, ''),
           Coalesce(average_rating, 0),
           Coalesce(isbn13, ''),
           Coalesce(original_title, ''),
           Coalesce(ratings_count, 0)
      Into :sqlItem.BookId,
           :sqlItem.Isbn,
           :sqlItem.Title,
           :sqlItem.Author,
           :sqlItem.PubYear,
           :sqlItem.Lang,
           :sqlItem.Rating,
           :OutBook.Isbn13,
           :OutBook.OrigTitle,
           :OutBook.RatingsCnt
      From cgrimm1.books
     Where book_id = :searchId;

  If SqlCode <> 0;
    OutMsg = 'Error loading Book ID ' + %Char(InBookId)
           + '. SQLCODE: ' + %Char(SqlCode);
    Return *Off;
  EndIf;

  OutBook.Item    = sqlItem;
  OutBook.IsValid = *On;
  Return *On;
End-Proc;

//=================================================================
// Method: Book_Validate (Encapsulated Domain Guard Clauses)
//=================================================================
Dcl-Proc Book_Validate Export;
  Dcl-Pi *N Ind;
    IoBook LikeDs(Book_t);
    OutMsg VarChar(100);
  End-Pi;

  IoBook.IsValid = *Off;
  Clear OutMsg;

  IoBook.Item.Isbn   = %Trim(IoBook.Item.Isbn);
  IoBook.Item.Title  = %Trim(IoBook.Item.Title);
  IoBook.Item.Author = %Trim(IoBook.Item.Author);
  IoBook.Item.Lang   = %Trim(IoBook.Item.Lang);

  If IoBook.Item.Title = '';
    OutMsg = 'Title is required.';
    Return *Off;
  EndIf;

  If IoBook.Item.Author = '';
    OutMsg = 'Author is required.';
    Return *Off;
  EndIf;

  If IoBook.Item.Rating < 0 Or IoBook.Item.Rating > 5;
    OutMsg = 'Average rating must be between 0.00 and 5.00.';
    Return *Off;
  EndIf;

  IoBook.IsValid = *On;
  Return *On;
End-Proc;

//=================================================================
// Method: Book_Save (Encapsulates Insert & Update Persistence)
//=================================================================
Dcl-Proc Book_Save Export;
  Dcl-Pi *N Ind;
    IoBook  LikeDs(Book_t);
    InIsNew Ind Const;
    OutMsg  VarChar(100);
  End-Pi;

  Dcl-Ds saveItem LikeDs(CatalogItem_t);

  If Not Book_Validate(IoBook: OutMsg);
    Return *Off;
  EndIf;

  If InIsNew And IoBook.Item.BookId <= 0;
    IoBook.Item.BookId = GetNextBookId();
  EndIf;

  saveItem = IoBook.Item;

  If InIsNew;
    Exec Sql
      Insert Into cgrimm1.books
        (book_id, isbn, title, authors,
         original_publication_year, language_code, average_rating)
      Values
        (:saveItem.BookId, :saveItem.Isbn, :saveItem.Title,
         :saveItem.Author, :saveItem.PubYear, :saveItem.Lang,
         :saveItem.Rating);

    If SqlCode = 0;
      OutMsg = 'Book ID ' + %Char(saveItem.BookId)
             + ' added successfully.';
      Return *On;
    Else;
      OutMsg = 'Insert failed. SQLCODE: ' + %Char(SqlCode);
      Return *Off;
    EndIf;
  Else;
    Exec Sql
      Update cgrimm1.books
         Set isbn                      = :saveItem.Isbn,
             title                     = :saveItem.Title,
             authors                   = :saveItem.Author,
             original_publication_year = :saveItem.PubYear,
             language_code             = :saveItem.Lang,
             average_rating            = :saveItem.Rating
       Where book_id = :saveItem.BookId;

    If SqlCode = 0;
      OutMsg = 'Book ID ' + %Char(saveItem.BookId)
             + ' updated successfully.';
      Return *On;
    Else;
      OutMsg = 'Update failed. SQLCODE: ' + %Char(SqlCode);
      Return *Off;
    EndIf;
  EndIf;
End-Proc;

//=================================================================
// Method: Book_Delete
//=================================================================
Dcl-Proc Book_Delete Export;
  Dcl-Pi *N Ind;
    InDelId Packed(6:0) Const;
    OutMsg  VarChar(128);
  End-Pi;

  Dcl-S delBookId Packed(6:0);

  delBookId = InDelId;

  Exec Sql
    Delete From cgrimm1.books
     Where book_id = :delBookId;

  If SqlCode = 0;
    OutMsg = 'Book ID ' + %Char(delBookId) + ' deleted.';
    Return *On;
  Else;
    OutMsg = 'Delete failed. SQLCODE: ' + %Char(SqlCode);
    Return *Off;
  EndIf;
End-Proc;

//=================================================================
// Method: Catalog_Search (Collection Query + Dynamic Sort)
//=================================================================
Dcl-Proc Catalog_Search Export;
  Dcl-Pi *N Int(10);
    InSearchTerm VarChar(40) Const;
    InSortBy     Char(1) Const;
    InSortDir    Char(1) Const;
    OutList      LikeDs(BookSummary_t) Dim(LIB_MAX_ROWS);
    OutMsg       VarChar(128);
  End-Pi;

  Dcl-S sqlStmt    VarChar(1000);
  Dcl-S searchLike VarChar(42);
  Dcl-S searchTrim VarChar(40);
  Dcl-S orderByCol VarChar(30);
  Dcl-S orderDir   VarChar(4);
  Dcl-S count      Int(10) Inz(0);
  Dcl-Ds itemRow   LikeDs(CatalogItem_t);

  Clear OutList;
  Clear OutMsg;

  sqlStmt = 'SELECT book_id, '
          + 'COALESCE(isbn, ''''), '
          + 'COALESCE(title, ''''), '
          + 'COALESCE(authors, ''''), '
          + 'COALESCE(original_publication_year, 0), '
          + 'COALESCE(language_code, ''''), '
          + 'COALESCE(average_rating, 0) '
          + 'FROM cgrimm1.books ';

  searchTrim = %Trim(InSearchTerm);
  If searchTrim <> '';
    searchLike = '%' + %Upper(searchTrim) + '%';
    sqlStmt += 'WHERE UPPER(title) LIKE ? '
            +  'OR UPPER(authors) LIKE ? '
            +  'OR UPPER(COALESCE(isbn, '''')) LIKE ? '
            +  'OR CHAR(book_id) = ? ';
  EndIf;

  Select;
    When InSortBy = SORT_TITLE;
      orderByCol = 'title';
    When InSortBy = SORT_AUTHOR;
      orderByCol = 'authors';
    When InSortBy = SORT_YEAR;
      orderByCol = 'original_publication_year';
    When InSortBy = SORT_RATING;
      orderByCol = 'average_rating';
    Other;
      orderByCol = 'book_id';
  EndSl;

  If %Upper(InSortDir) = DIR_DESC;
    orderDir = 'DESC';
  Else;
    orderDir = 'ASC';
  EndIf;

  sqlStmt += 'ORDER BY ' + orderByCol + ' ' + orderDir;

  Exec Sql Prepare S1 From :sqlStmt;
  Exec Sql Declare C1 Cursor For S1;

  If searchTrim <> '';
    Exec Sql Open C1 Using :searchLike, :searchLike,
                           :searchLike, :searchTrim;
  Else;
    Exec Sql Open C1;
  EndIf;

  DoW SqlCode = 0;
    Clear itemRow;
    Exec Sql Fetch C1 Into :itemRow;

    If SqlCode <> 0 Or count >= LIB_MAX_ROWS;
      Leave;
    EndIf;

    count += 1;
    OutList(count).Item         = itemRow;
    OutList(count).DisplayBadge = Fmt_StandardBadge(itemRow);
  EndDo;

  Exec Sql Close C1;

  If count = 0;
    OutMsg = 'No books found. SQLCODE: ' + %Char(SqlCode);
  EndIf;

  Return count;
End-Proc;

//=================================================================
// Polymorphic Overloaded Method 1: Book_FormatFull
//=================================================================
Dcl-Proc Book_FormatFull Export;
  Dcl-Pi *N VarChar(80);
    InBook       LikeDs(Book_t) Const Options(*Exact);
    InFormatter  Pointer(*Proc) Const Options(*NoPass: *Omit);
  End-Pi;

  Dcl-Pr DynamicFmt VarChar(80) ExtProc(fmtPtr);
    InItem LikeDs(CatalogItem_t) Const;
  End-Pr;
  Dcl-S fmtPtr Pointer(*Proc);

  If %Parms() >= 2 And %Addr(InFormatter) <> *Null;
    fmtPtr = InFormatter;
    Return DynamicFmt(InBook.Item);
  EndIf;

  Return Fmt_StandardBadge(InBook.Item);
End-Proc;

//=================================================================
// Polymorphic Overloaded Method 2: Book_FormatRow
//=================================================================
Dcl-Proc Book_FormatRow Export;
  Dcl-Pi *N VarChar(80);
    InSummary    LikeDs(BookSummary_t) Const Options(*Exact);
    InFormatter  Pointer(*Proc) Const Options(*NoPass: *Omit);
  End-Pi;

  Dcl-Pr DynamicFmt VarChar(80) ExtProc(fmtPtr);
    InItem LikeDs(CatalogItem_t) Const;
  End-Pr;
  Dcl-S fmtPtr Pointer(*Proc);

  If %Parms() >= 2 And %Addr(InFormatter) <> *Null;
    fmtPtr = InFormatter;
    Return DynamicFmt(InSummary.Item);
  EndIf;

  Return Fmt_StandardBadge(InSummary.Item);
End-Proc;

//=================================================================
// Polymorphic Formatter Strategy A: Fmt_StandardBadge
//=================================================================
Dcl-Proc Fmt_StandardBadge Export;
  Dcl-Pi *N VarChar(80);
    InItem LikeDs(CatalogItem_t) Const;
  End-Pi;

  Return %Trim(InItem.Title) + ' (' + %Char(InItem.PubYear)
       + ') - ' + %Char(InItem.Rating) + '/5';
End-Proc;

//=================================================================
// Polymorphic Formatter Strategy B: Fmt_ClassicBadge
//=================================================================
Dcl-Proc Fmt_ClassicBadge Export;
  Dcl-Pi *N VarChar(80);
    InItem LikeDs(CatalogItem_t) Const;
  End-Pi;

  Dcl-S eraTag VarChar(15);

  If InItem.PubYear > 0 And InItem.PubYear < 1970;
    eraTag = '(CLASSIC) ';
  Else;
    eraTag = '(MODERN) ';
  EndIf;

  Return eraTag + %Trim(InItem.Title) + ' by ' + %Trim(InItem.Author);
End-Proc;

//=================================================================
// Private Helper: GetNextBookId (Encapsulated)
//=================================================================
Dcl-Proc GetNextBookId;
  Dcl-Pi *N Packed(6:0);
  End-Pi;

  Dcl-S nextId Packed(6:0) Inz(1);

  Exec Sql
    Select Coalesce(Max(book_id), 0) + 1
      Into :nextId
      From cgrimm1.books;

  Return nextId;
End-Proc;
