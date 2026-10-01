-- =========================================================================
-- schema.sql - the tables your database is made of
--
-- Project 1 | SQL: From Data to Insight
-- Student: Gabriel Gomes
-- Dataset: Inside Airbnb (Rio de Janeiro)
--
-- This is a DELIVERABLE: it is how someone rebuilds your database from
-- nothing, and the tables here must match the ERD you drew.
--
-- Written for SQLite. On MySQL, add a CREATE DATABASE / USE at the top and
-- swap the types (TEXT -> VARCHAR(n), REAL -> DECIMAL, INTEGER PRIMARY KEY
-- -> INT PRIMARY KEY AUTO_INCREMENT).
-- =========================================================================

-- SQLite does not enforce foreign keys unless you ask it to, once per
-- connection. Without this line a broken key is accepted in silence.
PRAGMA foreign_keys = ON;


-- --- Lookup tables -------------------------------------------------------
-- The categorical columns you pulled out: an id and the value it stands for.
-- These have no foreign keys of their own, so they are created and loaded
-- FIRST.

CREATE TABLE neighborhood_groups (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE neighborhoods (
    id       INTEGER PRIMARY KEY,
    name     TEXT NOT NULL,
    group_id INTEGER NOT NULL,
    geometry TEXT NOT NULL,  -- WKT or GeoJSON string (SQLite has no native GEOMETRY type)
    FOREIGN KEY (group_id) REFERENCES neighborhood_groups(id)
);

CREATE TABLE hosts (
    id                                      INTEGER PRIMARY KEY,
    name                                    TEXT,
    url                                     TEXT,
    time_as_host_years                      INTEGER,
    time_as_host_months                     INTEGER,
    is_superhost                            INTEGER CHECK (is_superhost IN (0, 1)),
    listings_count                          INTEGER
);

CREATE TABLE "room_types"(
    "id" INTEGER NOT NULL PRIMARY KEY,
    "name" VARCHAR(255) NOT NULL
);

-- --- Your main table -----------------------------------------------------
-- The rows you are actually analysing: the numbers you care about, plus one
-- foreign key pointing at each lookup table above. Created and loaded LAST,
-- because every key it carries has to already exist somewhere else.


CREATE TABLE listings (
    id                          INTEGER PRIMARY KEY,
    name                        TEXT,
    description                 TEXT,
    url                         TEXT NOT NULL,
    host_id                     INTEGER NOT NULL,
    neighborhood_id             INTEGER NOT NULL,
    property_type               INTEGER NOT NULL,
    room_type_id                INTEGER NOT NULL,
    accommodates                INTEGER NOT NULL,
    bathrooms                   INTEGER,
    bedrooms                    INTEGER,
    beds                        INTEGER,
    amenities                   TEXT,
    price                       REAL NOT NULL,
    minimum_nights              INTEGER,
    maximum_nights              INTEGER,
    has_availability            INTEGER CHECK (has_availability IN (0, 1)),
    number_of_reviews           INTEGER,
    estimated_occupancy_l365d   INTEGER,
    first_review                TEXT,  -- ISO 'YYYY-MM-DD'
    last_review                 TEXT,  -- ISO 'YYYY-MM-DD'
    review_scores_rating        REAL,
    review_scores_accuracy      REAL,
    review_scores_cleanliness   REAL,
    review_scores_checkin       REAL,
    review_scores_communication REAL,
    review_scores_location      REAL,
    review_scores_value         REAL,
    reviews_per_month           REAL,
    price_outlier               INTEGER CHECK (price_outlier IN (0, 1)),
    price_imputed               INTEGER CHECK (price_imputed IN (0, 1)),
    FOREIGN KEY (host_id)         REFERENCES hosts(id),
    FOREIGN KEY (neighborhood_id) REFERENCES neighborhoods(id),
    FOREIGN KEY(room_type_id) REFERENCES room_types(id)
);

CREATE TABLE reviews (
    id            INTEGER PRIMARY KEY,
    listing_id    INTEGER NOT NULL,
    date          TEXT NOT NULL,  -- ISO 'YYYY-MM-DD'
    reviewer_id   INTEGER NOT NULL,
    reviewer_name TEXT,
    comments      TEXT,
    FOREIGN KEY (listing_id) REFERENCES listings(id)
);

-- --- Indexes (optional) --------------------------------------------------
-- Worth adding on your foreign keys if a query starts to feel slow.

CREATE INDEX "neighborhoods_group_id_index" ON "neighborhoods"("group_id");
CREATE INDEX listings_host_id_index         ON listings(host_id);
CREATE INDEX listings_neighborhood_id_index ON listings(neighborhood_id);
CREATE INDEX reviews_listing_id_index ON reviews(listing_id);
CREATE INDEX "listings_room_type_id_index" ON "listings"("room_type_id");
