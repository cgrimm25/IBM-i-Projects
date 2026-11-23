**Free
//=================================================================
// File:        LIBMAIN.RPGLE
// Programmer:  Chris Grimm
// Date:        11/22/2026
//
// Description:
//    Presentation controller (5250 UI) for the IBM i Book Library
//    application. Delegates all persistence, validation, and
//    domain formatting to the LIBSRV OOP service program.
//
// Maintenance Log:
// Date       Author       Description
// ---------- ------------ ----------------------------------------
// 11/22/2026 Chris Grimm  Initial program creation.
// 11/22/2026 Chris Grimm  Refactored to delegate to LIBSRV OOP API.
//=================================================================

Ctl-Opt DftActGrp(*No) ActGrp(*New) BndDir('CGRIMM1/LIBBND')
        Option(*SrcStmt: *NoDebugIo);

Dcl-F LIBDSPF WorkStn Sfile(LIBSBFL:rrn) IndDs(dspfInd);

/Copy QRPGLESRC,LIBSRV_H

// Indicator Data Structure (requires INDARA in LIBDSPF)
Dcl-Ds dspfInd Qualified;
  exit          Ind Pos(3);
  refresh       Ind Pos(5);
  addBook       Ind Pos(6);
  cancel        Ind Pos(12);
  sflDsp        Ind Pos(30);
  sflDspCtl     Ind Pos(31);
  sflClr        Ind Pos(32);
  sflEnd        Ind Pos(33);
  protectFields Ind Pos(40);
End-Ds;

// Subfile relative record number & catalog collection
Dcl-S rrn      Packed(4:0);
Dcl-Ds bookList LikeDs(BookSummary_t) Dim(LIB_MAX_ROWS);

//-----------------------------------------------------------------
// Mainline
//-----------------------------------------------------------------
FSORT = SORT_ID;
FDIR  = DIR_ASC;
Clear FSEARCH;
Clear FMSG;

loadSubfile();

DoW Not dspfInd.exit;
  Write LIBFTR;
  ExFmt LIBCTL;
  Clear FMSG;

  Select;
    When dspfInd.exit;
      Leave;

    When dspfInd.refresh;
      Clear FSEARCH;
      FSORT = SORT_ID;
      FDIR  = DIR_ASC;
      loadSubfile();

    When dspfInd.addBook;
      showDetail('A': 0);
      loadSubfile();

    Other;
      processOptions();
      loadSubfile();
  EndSl;
EndDo;

*InLr = *On;
Return;

//-----------------------------------------------------------------
// loadSubfile: Populates LIBSBFL via Catalog_Search()
//-----------------------------------------------------------------
Dcl-Proc loadSubfile;
  Dcl-S rowCount Int(10);
  Dcl-S idx      Int(10);
  Dcl-S msgText  VarChar(128);

  // Clear subfile
  dspfInd.sflClr = *On;
  Write LIBCTL;
  dspfInd.sflClr = *Off;
  rrn = 0;

  // Normalize sort inputs
  If FSORT < SORT_ID Or FSORT > SORT_RATING;
    FSORT = SORT_ID;
  EndIf;
  If %Upper(FDIR) = DIR_DESC;
    FDIR = DIR_DESC;
  Else;
    FDIR = DIR_ASC;
  EndIf;

  // Delegate search & sort to LIBSRV
  rowCount = Catalog_Search(%Trim(FSEARCH): FSORT: FDIR:
                            bookList: msgText);

  For idx = 1 To rowCount;
    SOPT    = ' ';
    SID     = bookList(idx).Item.BookId;
    SISBN   = bookList(idx).Item.Isbn;
    STITLE  = bookList(idx).Item.Title;
    SAUTHOR = bookList(idx).Item.Author;
    SYEAR   = bookList(idx).Item.PubYear;
    SLANG   = bookList(idx).Item.Lang;
    SRATING = bookList(idx).Item.Rating;

    rrn += 1;
    Write LIBSBFL;
  EndFor;

  dspfInd.sflDsp    = (rrn > 0);
  dspfInd.sflDspCtl = *On;
  dspfInd.sflEnd    = *On;

  If rrn = 0;
    FMSG = msgText;
  EndIf;
End-Proc;

//-----------------------------------------------------------------
// processOptions: Reads modified subfile rows (2, 4, 5)
//-----------------------------------------------------------------
Dcl-Proc processOptions;
  ReadC LIBSBFL;

  DoW Not %Eof(LIBDSPF);
    Select;
      When SOPT = '5';
        showDetail('5': SID);

      When SOPT = '2';
        showDetail('2': SID);

      When SOPT = '4';
        deleteBook(SID: %Trim(STITLE));

      When SOPT <> ' ';
        FMSG = 'Invalid option "' + SOPT + '". Use 2, 4, or 5.';
    EndSl;

    SOPT = ' ';
    Update LIBSBFL;

    If dspfInd.exit;
      Leave;
    EndIf;

    ReadC LIBSBFL;
  EndDo;
End-Proc;

//-----------------------------------------------------------------
// showDetail: Handles Display ('5'), Edit ('2'), and Add ('A')
//-----------------------------------------------------------------
Dcl-Proc showDetail;
  Dcl-Pi *N;
    mode     Char(1) Const;
    inBookId Packed(6:0) Const;
  End-Pi;

  Dcl-Ds currentBook LikeDs(Book_t);
  Dcl-S  isNewMode   Ind;
  Dcl-S  msgText     VarChar(128);
  Dcl-S  saveMsg     VarChar(100);

  Clear LIBDTL;
  Clear DMSG;
  dspfInd.cancel = *Off;
  isNewMode = (mode = 'A');

  If isNewMode;
    dspfInd.protectFields = *Off;
    DMODE = 'ADD NEW BOOK';
    currentBook = Book_New();
  Else;
    If Not Book_FindById(inBookId: currentBook: msgText);
      FMSG = msgText;
      Return;
    EndIf;

    If mode = '5';
      dspfInd.protectFields = *On;
      DMODE = 'DISPLAY BOOK DETAILS';
      // Polymorphic call using Classic/Modern badge strategy
      DMSG = Book_FormatSummary(currentBook: %Paddr('FMT_CLASSICBADGE'));
    Else;
      dspfInd.protectFields = *Off;
      DMODE = 'EDIT BOOK DETAILS';
    EndIf;
  EndIf;

  // Bind object fields to DSPF screen fields
  DID     = currentBook.Item.BookId;
  DISBN   = currentBook.Item.Isbn;
  DTITLE  = currentBook.Item.Title;
  DAUTHOR = currentBook.Item.Author;
  DYEAR   = currentBook.Item.PubYear;
  DLANG   = currentBook.Item.Lang;
  DRATING = currentBook.Item.Rating;

  DoW Not dspfInd.exit And Not dspfInd.cancel;
    ExFmt LIBDTL;
    Clear DMSG;

    If dspfInd.exit Or dspfInd.cancel;
      Leave;
    EndIf;

    If mode = '5';
      Leave;
    EndIf;

    // Hydrate object state from screen inputs
    currentBook.Item.Isbn    = %Trim(DISBN);
    currentBook.Item.Title   = %Trim(DTITLE);
    currentBook.Item.Author  = %Trim(DAUTHOR);
    currentBook.Item.PubYear = DYEAR;
    currentBook.Item.Lang    = %Trim(DLANG);
    currentBook.Item.Rating  = DRATING;

    // Delegate validation & persistence to LIBSRV
    If Book_Save(currentBook: isNewMode: saveMsg);
      FMSG = saveMsg;
      Leave;
    Else;
      DMSG = saveMsg;
    EndIf;
  EndDo;

  dspfInd.cancel = *Off;
End-Proc;

//-----------------------------------------------------------------
// deleteBook: Displays confirmation popup and delegates delete
//-----------------------------------------------------------------
Dcl-Proc deleteBook;
  Dcl-Pi *N;
    inBookId Packed(6:0) Const;
    inTitle  VarChar(45) Const;
  End-Pi;

  Dcl-S msgText VarChar(128);

  WID            = inBookId;
  WTITLE         = inTitle;
  WCONF          = 'N';
  dspfInd.cancel = *Off;

  DoW Not dspfInd.exit And Not dspfInd.cancel;
    ExFmt LIBDEL;

    If dspfInd.exit Or dspfInd.cancel;
      Leave;
    EndIf;

    If %Upper(WCONF) = 'Y';
      Book_Delete(inBookId: msgText);
      FMSG = msgText;
      Leave;
    ElseIf %Upper(WCONF) = 'N';
      FMSG = 'Delete cancelled.';
      Leave;
    EndIf;
  EndDo;

  dspfInd.cancel = *Off;
End-Proc;
