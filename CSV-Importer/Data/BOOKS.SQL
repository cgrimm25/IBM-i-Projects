--========================================================================
-- File:        BOOKS.SQL
-- Programmer:  Chris Grimm
-- Date:        11/19/2026
--
-- Description:
--     SQL DDL script to create the BOOKS table with explicit Long SQL
--     Names and Short System Names (FOR COLUMN) for all 23 columns,
--     along with search and sort indexes.
--
-- Maintenance Log:
-- Date       Author       Description
-- ---------- ------------ -----------------------------------------------
-- 11/19/2026 Chris Grimm  Initial SQL DDL creation.
--========================================================================

DROP TABLE IF EXISTS BOOKS;

CREATE TABLE BOOKS (
    -- Identifiers
    BOOK_ID                   FOR COLUMN BOOKID     INTEGER       NOT NULL,
    GOODREADS_BOOK_ID         FOR COLUMN GRBOOKID   INTEGER,
    BEST_BOOK_ID              FOR COLUMN BSTBOOKID  INTEGER,
    WORK_ID                   FOR COLUMN WORKID     INTEGER,
    BOOKS_COUNT               FOR COLUMN BOOKSCNT   INTEGER,

    -- Publication Info
    ISBN                      FOR COLUMN ISBN10     VARCHAR(20),
    ISBN13                    FOR COLUMN ISBN13NO   VARCHAR(20),
    AUTHORS                   FOR COLUMN AUTHOR     VARCHAR(250)  NOT NULL,
    ORIGINAL_PUBLICATION_YEAR FOR COLUMN PUBYEAR    INTEGER,
    ORIGINAL_TITLE            FOR COLUMN ORIGTITLE  VARCHAR(250),
    TITLE                     FOR COLUMN BKTITLE    VARCHAR(250)  NOT NULL,
    LANGUAGE_CODE             FOR COLUMN LANGCODE   VARCHAR(15),

    -- Ratings & Reviews
    AVERAGE_RATING            FOR COLUMN AVGRATING
                              DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    RATINGS_COUNT             FOR COLUMN RATINGSCNT
                              INTEGER       NOT NULL DEFAULT 0,
    WORK_RATINGS_COUNT        FOR COLUMN WRKRATCNT
                              INTEGER       NOT NULL DEFAULT 0,
    WORK_TEXT_REVIEWS_COUNT   FOR COLUMN WRKREVCNT
                              INTEGER       NOT NULL DEFAULT 0,
    RATINGS_1                 FOR COLUMN RATING1
                              INTEGER       NOT NULL DEFAULT 0,
    RATINGS_2                 FOR COLUMN RATING2
                              INTEGER       NOT NULL DEFAULT 0,
    RATINGS_3                 FOR COLUMN RATING3
                              INTEGER       NOT NULL DEFAULT 0,
    RATINGS_4                 FOR COLUMN RATING4
                              INTEGER       NOT NULL DEFAULT 0,
    RATINGS_5                 FOR COLUMN RATING5
                              INTEGER       NOT NULL DEFAULT 0,
    -- Image Links
    IMAGE_URL                 FOR COLUMN IMAGEURL   VARCHAR(255),
    SMALL_IMAGE_URL           FOR COLUMN SMIMGURL   VARCHAR(255),

    CONSTRAINT PK_BOOKS PRIMARY KEY (BOOK_ID)
);

-- Indexes to optimize Subfile sorting and searching
CREATE INDEX IDX_BOOKS_ISBN   ON BOOKS (ISBN);
CREATE INDEX IDX_BOOKS_AUTHOR ON BOOKS (AUTHORS);
CREATE INDEX IDX_BOOKS_YEAR   ON BOOKS (ORIGINAL_PUBLICATION_YEAR);
CREATE INDEX IDX_BOOKS_RATING ON BOOKS (AVERAGE_RATING DESC);
