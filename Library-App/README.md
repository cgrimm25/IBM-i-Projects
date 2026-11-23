# IBM i Object-Oriented Library Catalog (`Library-App`)

An interactive 5250 subfile application and object-oriented service program (`LIBSRV`) for IBM i written in fully free-form RPGLE (`**Free`) and SQLRPGLE. The application demonstrates OOP principles on IBM i—including encapsulation, inheritance, abstraction, and polymorphism—backed by a Db2 for i SQL database (`CGRIMM1.BOOKS`).

## Repository Structure

```text
Library-App/
├── Data/
│   └── BOOKSSAVF.SAVF          # Binary IBM i save file containing the BOOKS *FILE (PF) object and data
├── LIBDSPF.DSPF                # External 27x132 DDS display file (subfile, detail screen, delete popup)
├── LIBMAIN.RPGLE               # **Free 5250 presentation controller (subfile & screen event loop)
├── LIBSRV.BND                  # Binder source defining the LIBSRV_OOP_V1 service program signature
├── LIBSRV.SQLRPGLE             # **Free SQLRPGLE service program implementing domain logic & Db2 CRUD
├── LIBSRV_H.RPGLE              # Copybook header defining base/derived data structures & prototypes
└── README.md                   # Project documentation and setup instructions
```

---

## Object-Oriented Architecture on IBM i

* **Inheritance (`LIBSRV_H.RPGLE`):** Uses `QUALIFIED TEMPLATE` data structures with nested `LIKEDS` composition. `CatalogItem_t` serves as the base class, extended by `BookSummary_t` (for subfile rows) and `Book_t` (for full detail/validation state).
* **Encapsulation (`LIBSRV.SQLRPGLE`):** Database persistence (`Book_FindById`, `Book_Save`, `Book_Delete`, `Catalog_Search`), domain validation guard clauses (`Book_Validate`), and private ID generation (`GetNextBookId`) are isolated inside the `LIBSRV` service program.
* **Abstraction (`LIBSRV.BND` & `LIBSRV_H.RPGLE`):** `LIBMAIN` interacts strictly through public prototypes and an explicit binder language signature (`LIBSRV_OOP_V1`), decoupled from underlying SQL statements.
* **Polymorphism (`Overload` & `Pointer(*Proc)`):**
  * **Procedure Overloading:** `Book_FormatSummary` accepts either a `Book_t` or `BookSummary_t` structure (`Options(*Exact)`) and dispatches to `Book_FormatFull` or `Book_FormatRow`.
  * **Strategy Pattern via Procedure Pointers:** Formatting callbacks (`Fmt_StandardBadge`, `Fmt_ClassicBadge`) are passed dynamically via `%Paddr` to swap presentation behavior at runtime.

---

## Features

* **Dynamic Search & Multi-Column Sort:** Filter books by ID, ISBN, Title, or Author (`Catalog_Search`) and sort ascending or descending by ID, Title, Author, Publication Year, or Average Rating.
* **Full Subfile CRUD (`LIBDSPF.DSPF`):**
  * **Function Keys:**
    * `F3` — Exit the application.
    * `F5` — Refresh the subfile and reset search/sort filters.
    * `F6` — Add a new book with automatic `Book_ID` assignment (`GetNextBookId`).
    * `F12` — Cancel out of the detail screen or delete popup.
  * **Subfile Row Options (`Opt` column):**
    * `2` — Edit existing book metadata with domain validation (`Title`, `Author`, and `0.00–5.00` rating checks).
    * `4` — Delete confirmation popup window (`LIBDEL`) with red border and `Y/N` prompt.
    * `5` — Read-only detail view (`DSPATR(PR)`) displaying polymorphic era formatting (`(CLASSIC)` vs. `(MODERN)`).

---

## Setup & Compilation Order (RDi / IBM i)

IBM i ILE objects must be built in dependency order—database first, then the display file, followed by the service program module, binder export, binding directory, and finally the main caller program (`LIBMAIN`). Replace `<YOUR_LIB>` with your target library (e.g., `CGRIMM1`).

### 1. Restore the `BOOKS` Database Table
Upload `Data/BOOKSSAVF.SAVF` in **binary mode** to `/QSYS.LIB/<YOUR_LIB>.LIB/BOOKSSAVF.FILE` (or create a save file with `CRTSAVF FILE(<YOUR_LIB>/BOOKSSAVF)` and copy via `CPYFRMSTMF`), then restore the physical file:
```cl
RSTOBJ OBJ(BOOKS) SAVLIB(CGRIMM1) DEV(*SAVF) SAVF(<YOUR_LIB>/BOOKSSAVF) RSTLIB(<YOUR_LIB>)
```
*(Verify that `<YOUR_LIB>/BOOKS` exists and contains data before compiling `LIBSRV.SQLRPGLE`, since the SQL precompiler validates embedded SQL statements against the table.)*

### 2. Upload Source Members to Source Physical Files
Place each source file into its corresponding IBM i source physical file in `<YOUR_LIB>`:
* `LIBDSPF.DSPF` $\rightarrow$ `<YOUR_LIB>/QDDSSRC` (Member: `LIBDSPF`, Type: `DSPF`)
* `LIBSRV_H.RPGLE` $\rightarrow$ `<YOUR_LIB>/QRPGLESRC` (Member: `LIBSRV_H`, Type: `RPGLE`)
* `LIBMAIN.RPGLE` $\rightarrow$ `<YOUR_LIB>/QRPGLESRC` (Member: `LIBMAIN`, Type: `RPGLE`)
* `LIBSRV.SQLRPGLE` $\rightarrow$ `<YOUR_LIB>/QSQLRPGSRC` (Member: `LIBSRV`, Type: `SQLRPGLE`)
* `LIBSRV.BND` $\rightarrow$ `<YOUR_LIB>/QSRVSRC` (Member: `LIBSRV`, Type: `BND`)

*(Note: `LIBMAIN.RPGLE` and `LIBSRV.SQLRPGLE` both include `/Copy QRPGLESRC,LIBSRV_H`. Ensure `<YOUR_LIB>` is in your library list, or update the `/Copy` directive if your copybook lives in a different library.)*

### 3. Compile in Exact Dependency Order

1. **Compile the Display File (`LIBDSPF`):**
   * **In RDi:** Right-click `LIBDSPF.DSPF` $\rightarrow$ **Compile $\rightarrow$ CRTDSPF**.
   * **CL Command:**
     ```cl
     CRTDSPF FILE(<YOUR_LIB>/LIBDSPF) SRCFILE(<YOUR_LIB>/QDDSSRC) SRCMBR(LIBDSPF)
     ```
2. **Compile the Service Program Module (`LIBSRV`):**
   * *Must be compiled as a `*MODULE` (not `*PGM`)* so it can be bound into a service program.
   * **In RDi:** Right-click `LIBSRV.SQLRPGLE` $\rightarrow$ **Compile $\rightarrow$ CRTSQLRPGI** (ensure **Object type** is `*MODULE`), or run the CL command below.
   * **CL Command:**
     ```cl
     CRTSQLRPGI OBJ(<YOUR_LIB>/LIBSRV) SRCFILE(<YOUR_LIB>/QSQLRPGSRC) SRCMBR(LIBSRV) OBJTYPE(*MODULE) DBGVIEW(*SOURCE)
     ```
3. **Create the Service Program (`LIBSRV`) using Binder Source (`LIBSRV.BND`):**
   * Binds the `LIBSRV` module and exports the `LIBSRV_OOP_V1` public symbol signature.
   * **CL Command:**
     ```cl
     CRTSRVPGM SRVPGM(<YOUR_LIB>/LIBSRV) MODULE(<YOUR_LIB>/LIBSRV) SRCFILE(<YOUR_LIB>/QSRVSRC) SRCMBR(LIBSRV)
     ```
4. **Create the Binding Directory (`LIBBND`) & Register `LIBSRV`:**
   * `LIBMAIN.RPGLE` references `BndDir('CGRIMM1/LIBBND')` in its `Ctl-Opt` header (update `'CGRIMM1/LIBBND'` to `'<YOUR_LIB>/LIBBND'` if compiling into a different library).
   * **CL Commands:**
     ```cl
     CRTBNDDIR BNDDIR(<YOUR_LIB>/LIBBND) TEXT('Library Catalog Binding Directory')
     ADDBNDDIRE BNDDIR(<YOUR_LIB>/LIBBND) OBJ((<YOUR_LIB>/LIBSRV *SRVPGM))
     ```
5. **Compile the Main Presentation Program (`LIBMAIN`):**
   * *Must be compiled last*, after `LIBDSPF` exists (for record format level checks) and `LIBBND` / `LIBSRV` are created (for procedure resolution).
   * **In RDi:** Right-click `LIBMAIN.RPGLE` $\rightarrow$ **Compile $\rightarrow$ CRTBNDRPG**.
   * **CL Command:**
     ```cl
     CRTBNDRPG PGM(<YOUR_LIB>/LIBMAIN) SRCFILE(<YOUR_LIB>/QRPGLESRC) SRCMBR(LIBMAIN) DBGVIEW(*SOURCE)
     ```

### 4. Run the Application
Ensure `<YOUR_LIB>` is in your library list (`ADDLIBLE LIB(<YOUR_LIB>)`) and call the program:
```cl
CALL PGM(<YOUR_LIB>/LIBMAIN)
```

*(Note on Recompiling: If you later modify `LIBDSPF.DSPF`, recompile both `LIBDSPF` and `LIBMAIN` to prevent level check errors. If you modify `LIBSRV.SQLRPGLE` without changing exported procedure signatures, recompile the `LIBSRV` `*MODULE` and run `UPDSRVPGM SRVPGM(<YOUR_LIB>/LIBSRV) MODULE(<YOUR_LIB>/LIBSRV)`.)*