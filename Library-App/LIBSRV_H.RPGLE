**Free
//=================================================================
// File:        LIBSRV_H.RPGLE
// Programmer:  Chris Grimm
// Date:        11/22/2026
//
// Description:
//    Object-oriented interface header for the Library Catalog
//    service program (LIBSRV). Implements Data Inheritance via
//    Template DS composition, Abstraction via public prototypes,
//    and Polymorphism via procedure overloading and pointers.
//
// Maintenance Log:
// Date       Author       Description
// ---------- ------------ ----------------------------------------
// 11/22/2026 Chris Grimm  Initial OOP interface creation.
//=================================================================

/If Defined(LIBSRV_H_INCLUDED)
/Eof
/EndIf
/Define LIBSRV_H_INCLUDED

// Constants
Dcl-C LIB_MAX_ROWS 9999;

// Sort & Direction Constants
Dcl-C SORT_ID      '1';
Dcl-C SORT_TITLE   '2';
Dcl-C SORT_AUTHOR  '3';
Dcl-C SORT_YEAR    '4';
Dcl-C SORT_RATING  '5';

Dcl-C DIR_ASC      'A';
Dcl-C DIR_DESC     'D';

//-----------------------------------------------------------------
// Base Class Template: CatalogItem_t (Inheritance Root)
//-----------------------------------------------------------------
Dcl-Ds CatalogItem_t Qualified Template;
  BookId  Packed(6:0);
  Isbn    VarChar(13);
  Title   VarChar(80);
  Author  VarChar(80);
  PubYear Packed(4:0);
  Lang    VarChar(10);
  Rating  Packed(4:2);
End-Ds;

//-----------------------------------------------------------------
// Derived Class: BookSummary_t (Inherits CatalogItem_t for Subfiles)
//-----------------------------------------------------------------
Dcl-Ds BookSummary_t Qualified Template;
  Item         LikeDs(CatalogItem_t);
  DisplayBadge VarChar(20);
End-Ds;

//-----------------------------------------------------------------
// Derived Class: Book_t (Inherits CatalogItem_t + Extended Fields)
//-----------------------------------------------------------------
Dcl-Ds Book_t Qualified Template;
  Item       LikeDs(CatalogItem_t);
  Isbn13     VarChar(20);
  OrigTitle  VarChar(250);
  RatingsCnt Int(10);
  IsValid    Ind;
End-Ds;

//-----------------------------------------------------------------
// Polymorphic Formatter Callback Prototype (Strategy Pattern)
//-----------------------------------------------------------------
Dcl-Pr FormatterProto VarChar(80) ExtProc(*DclCase);
  InItem LikeDs(CatalogItem_t) Const;
End-Pr;

//-----------------------------------------------------------------
// Public Methods (Abstraction Layer)
//-----------------------------------------------------------------
Dcl-Pr Book_New LikeDs(Book_t) ExtProc('BOOK_NEW');
End-Pr;

Dcl-Pr Book_FindById Ind ExtProc('BOOK_FINDBYID');
  InBookId Packed(6:0) Const;
  OutBook  LikeDs(Book_t);
  OutMsg   VarChar(128);
End-Pr;

Dcl-Pr Book_Validate Ind ExtProc('BOOK_VALIDATE');
  IoBook LikeDs(Book_t);
  OutMsg VarChar(100);
End-Pr;

Dcl-Pr Book_Save Ind ExtProc('BOOK_SAVE');
  IoBook  LikeDs(Book_t);
  InIsNew Ind Const;
  OutMsg  VarChar(100);
End-Pr;

Dcl-Pr Book_Delete Ind ExtProc('BOOK_DELETE');
  InBookId Packed(6:0) Const;
  OutMsg   VarChar(128);
End-Pr;

Dcl-Pr Catalog_Search Int(10) ExtProc('CATALOG_SEARCH');
  InSearchTerm VarChar(40) Const;
  InSortBy     Char(1) Const;
  InSortDir    Char(1) Const;
  OutList      LikeDs(BookSummary_t) Dim(LIB_MAX_ROWS);
  OutMsg       VarChar(128);
End-Pr;

// Polymorphic Overloaded Method: Accepts either Book_t or BookSummary_t
Dcl-Pr Book_FormatSummary VarChar(80)
       Overload(Book_FormatFull: Book_FormatRow);

Dcl-Pr Book_FormatFull VarChar(80) ExtProc('BOOK_FORMATFULL');
  InBook       LikeDs(Book_t) Const Options(*Exact);
  InFormatter  Pointer(*Proc) Const Options(*NoPass: *Omit);
End-Pr;

Dcl-Pr Book_FormatRow VarChar(80) ExtProc('BOOK_FORMATROW');
  InSummary    LikeDs(BookSummary_t) Const Options(*Exact);
  InFormatter  Pointer(*Proc) Const Options(*NoPass: *Omit);
End-Pr;

// Exported Polymorphic Formatter Strategies (Passed via %Paddr)
Dcl-Pr Fmt_StandardBadge VarChar(80) ExtProc('FMT_STANDARDBADGE');
  InItem LikeDs(CatalogItem_t) Const;
End-Pr;

Dcl-Pr Fmt_ClassicBadge VarChar(80) ExtProc('FMT_CLASSICBADGE');
  InItem LikeDs(CatalogItem_t) Const;
End-Pr;
