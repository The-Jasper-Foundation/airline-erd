-- =====================================================================
-- AIRLINE WORKED EXAMPLE  -  MOD002589 practice (NOT the hospital project)
-- 10 tables. Answers the 3 client questions from Tutorial 3/4.
-- Runs in MySQL 8 (and MariaDB). All data is invented.
-- Built with Claude as a study aid while learning ER modelling.
--
-- HOW TO RUN IT
--   1. Open MySQL Workbench (or the mysql command line)
--   2. Open this file and run the whole thing
--   3. Scroll to the bottom: Q1, Q2, Q3 each print a result table
-- =====================================================================

DROP DATABASE IF EXISTS airline_example;
CREATE DATABASE airline_example;
USE airline_example;


-- ---------------------------------------------------------------------
-- 1. LOOKUP TABLES  (made first, because other tables point at them)
-- ---------------------------------------------------------------------

-- Each country written ONCE. Clients and airports point here.  (NEW for Q2)
CREATE TABLE Country (
    country_id   INT          AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(60)  NOT NULL UNIQUE
);

CREATE TABLE Airline (
    airline_id   INT          AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(60)  NOT NULL UNIQUE
);

CREATE TABLE Airport (
    airport_id   INT          AUTO_INCREMENT PRIMARY KEY,
    iata_code    CHAR(3)      NOT NULL UNIQUE,          -- e.g. LHR
    name         VARCHAR(80)  NOT NULL,
    city         VARCHAR(60)  NOT NULL,
    country_id   INT          NOT NULL,
    FOREIGN KEY (country_id) REFERENCES Country(country_id)
);


-- ---------------------------------------------------------------------
-- 2. PEOPLE AND FLIGHTS
-- ---------------------------------------------------------------------

CREATE TABLE Client (
    client_id    INT           AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(80)   NOT NULL,
    email        VARCHAR(120)  NOT NULL UNIQUE,
    country_id   INT           NOT NULL,                -- NEW for Q2
    FOREIGN KEY (country_id) REFERENCES Country(country_id)
);

CREATE TABLE Flight (
    flight_id               INT          AUTO_INCREMENT PRIMARY KEY,
    flight_number           VARCHAR(8)   NOT NULL,      -- text: EK001 has letters
    airline_id              INT          NOT NULL,
    origin_airport_id       INT          NOT NULL,
    destination_airport_id  INT          NOT NULL,
    departure_time          DATETIME     NOT NULL,
    arrival_time            DATETIME     NOT NULL,
    offers_kids_meal        BOOLEAN      NOT NULL DEFAULT FALSE,   -- NEW for Q3
    FOREIGN KEY (airline_id)             REFERENCES Airline(airline_id),
    FOREIGN KEY (origin_airport_id)      REFERENCES Airport(airport_id),
    FOREIGN KEY (destination_airport_id) REFERENCES Airport(airport_id),
    CHECK (arrival_time > departure_time),
    CHECK (origin_airport_id <> destination_airport_id)
);


-- ---------------------------------------------------------------------
-- 3. PRICES
-- ---------------------------------------------------------------------

-- One row per flight + cabin + passenger type. A child fare = a child discount.
CREATE TABLE Fare (
    fare_id         INT            AUTO_INCREMENT PRIMARY KEY,
    flight_id       INT            NOT NULL,
    cabin_class     ENUM('economy','premium','business') NOT NULL,
    passenger_type  ENUM('adult','child','infant')       NOT NULL,   -- NEW for Q3
    price           DECIMAL(8,2)   NOT NULL CHECK (price >= 0),
    FOREIGN KEY (flight_id) REFERENCES Flight(flight_id),
    UNIQUE (flight_id, cabin_class, passenger_type)    -- no duplicate fares
);

-- A new row every time a price changes. Nothing is overwritten.  (NEW for Q1)
CREATE TABLE FareHistory (
    history_id   INT            AUTO_INCREMENT PRIMARY KEY,
    fare_id      INT            NOT NULL,
    old_price    DECIMAL(8,2)   NOT NULL,
    new_price    DECIMAL(8,2)   NOT NULL,
    changed_at   DATETIME       NOT NULL,
    FOREIGN KEY (fare_id) REFERENCES Fare(fare_id)
);

-- Link table: which client wants alerts for which flight.  (NEW for Q1)
-- Client <-> Flight is many-to-many, so it needs a table in the middle.
CREATE TABLE PriceAlert (
    alert_id     INT        AUTO_INCREMENT PRIMARY KEY,
    client_id    INT        NOT NULL,
    flight_id    INT        NOT NULL,
    created_at   DATETIME   NOT NULL,
    FOREIGN KEY (client_id) REFERENCES Client(client_id),
    FOREIGN KEY (flight_id) REFERENCES Flight(flight_id),
    UNIQUE (client_id, flight_id)                      -- can't sign up twice
);


-- ---------------------------------------------------------------------
-- 4. BOOKINGS
-- ---------------------------------------------------------------------

CREATE TABLE Booking (
    booking_id    INT          AUTO_INCREMENT PRIMARY KEY,
    booking_ref   CHAR(6)      NOT NULL UNIQUE,
    client_id     INT          NOT NULL,
    flight_id     INT          NOT NULL,
    booking_date  DATETIME     NOT NULL,
    status        ENUM('confirmed','cancelled') NOT NULL DEFAULT 'confirmed',
    FOREIGN KEY (client_id) REFERENCES Client(client_id),
    FOREIGN KEY (flight_id) REFERENCES Flight(flight_id)
);

-- Composition: delete a booking and its passengers go too (ON DELETE CASCADE).
CREATE TABLE Passenger (
    passenger_id   INT          AUTO_INCREMENT PRIMARY KEY,
    booking_id     INT          NOT NULL,
    fare_id        INT          NOT NULL,
    name           VARCHAR(80)  NOT NULL,
    date_of_birth  DATE         NOT NULL,              -- NEW for Q3
    seat_number    VARCHAR(4),
    FOREIGN KEY (booking_id) REFERENCES Booking(booking_id) ON DELETE CASCADE,
    FOREIGN KEY (fare_id)    REFERENCES Fare(fare_id)
);


-- =====================================================================
-- MOCK DATA  (invented, for practice)
-- =====================================================================

INSERT INTO Country (name) VALUES
  ('United Kingdom'), ('United Arab Emirates'), ('India');      -- ids 1,2,3

INSERT INTO Airline (name) VALUES ('Emirates'), ('British Airways');   -- ids 1,2

INSERT INTO Airport (iata_code, name, city, country_id) VALUES
  ('LHR', 'Heathrow',                'London', 1),   -- 1
  ('DXB', 'Dubai International',     'Dubai',  2),   -- 2
  ('BOM', 'Chhatrapati Shivaji Intl','Mumbai', 3);   -- 3

INSERT INTO Client (name, email, country_id) VALUES
  ('Amy Clarke',   'amy@example.com',   1),   -- 1  UK
  ('Raj Patel',    'raj@example.com',   3),   -- 2  India
  ('Tom Hughes',   'tom@example.com',   1),   -- 3  UK
  ('Layla Haddad', 'layla@example.com', 2),   -- 4  UAE
  ('Priya Nair',   'priya@example.com', 3);   -- 5  India

INSERT INTO Flight (flight_number, airline_id, origin_airport_id, destination_airport_id,
                    departure_time, arrival_time, offers_kids_meal) VALUES
  ('EK001', 1, 1, 2, '2019-12-20 08:00', '2019-12-20 19:00', TRUE),   -- 1  Dec, kids meal
  ('EK002', 1, 2, 3, '2019-11-15 10:00', '2019-11-15 14:30', TRUE),   -- 2  Nov (wrong month)
  ('EK003', 1, 2, 1, '2019-12-22 09:00', '2019-12-22 13:30', TRUE),   -- 3  Dec, kids meal, NO child fare
  ('BA107', 2, 1, 2, '2019-12-18 21:00', '2019-12-19 07:50', FALSE),  -- 4  Dec, child fare, NO kids meal
  ('BA139', 2, 1, 3, '2019-12-23 20:00', '2019-12-24 09:30', TRUE);   -- 5  Dec, both

INSERT INTO Fare (flight_id, cabin_class, passenger_type, price) VALUES
  (1, 'economy', 'adult', 450.00),   -- 1
  (1, 'economy', 'child', 340.00),   -- 2
  (2, 'economy', 'adult', 210.00),   -- 3
  (3, 'economy', 'adult', 430.00),   -- 4
  (4, 'economy', 'adult', 520.00),   -- 5
  (4, 'economy', 'child', 390.00),   -- 6
  (5, 'economy', 'adult', 610.00),   -- 7
  (5, 'economy', 'child', 460.00),   -- 8
  (1, 'business','adult',1900.00);   -- 9

INSERT INTO FareHistory (fare_id, old_price, new_price, changed_at) VALUES
  (1, 480.00, 450.00, '2019-11-20 09:00'),   -- EK001 economy adult dropped
  (2, 360.00, 340.00, '2019-11-20 09:00'),   -- EK001 economy child dropped
  (7, 580.00, 610.00, '2019-11-21 12:00'),   -- BA139 went up
  (3, 200.00, 210.00, '2019-10-01 08:00');   -- old change, before the last run

INSERT INTO PriceAlert (client_id, flight_id, created_at) VALUES
  (1, 1, '2019-10-05 10:00'),   -- Amy watches EK001
  (3, 1, '2019-10-07 18:00'),   -- Tom watches EK001
  (2, 5, '2019-10-09 12:00'),   -- Raj watches BA139
  (4, 3, '2019-10-10 08:00');   -- Layla watches EK003 (no change, no alert)

INSERT INTO Booking (booking_ref, client_id, flight_id, booking_date, status) VALUES
  ('AB12CD', 1, 1, '2019-11-01 10:00', 'confirmed'),   -- Emirates, UK
  ('EF34GH', 3, 3, '2019-11-02 11:00', 'confirmed'),   -- Emirates, UK
  ('IJ56KL', 1, 3, '2019-11-03 12:00', 'confirmed'),   -- Emirates, UK
  ('MN78OP', 2, 2, '2019-10-04 13:00', 'confirmed'),   -- Emirates, India
  ('QR90ST', 5, 1, '2019-11-05 14:00', 'confirmed'),   -- Emirates, India
  ('UV12WX', 4, 1, '2019-11-06 15:00', 'confirmed'),   -- Emirates, UAE
  ('YZ34AB', 4, 3, '2019-11-07 16:00', 'cancelled'),   -- cancelled: not counted
  ('CD56EF', 3, 4, '2019-11-08 17:00', 'confirmed');   -- British Airways: not counted

INSERT INTO Passenger (booking_id, fare_id, name, date_of_birth, seat_number) VALUES
  (1, 1, 'Amy Clarke',  '1990-04-12', '32A'),
  (1, 2, 'Ben Clarke',  '2013-06-30', '32B'),   -- child on a child fare
  (2, 4, 'Tom Hughes',  '1985-01-22', '40C'),
  (3, 4, 'Amy Clarke',  '1990-04-12', '12F'),
  (4, 3, 'Raj Patel',   '1979-09-02', '18D'),
  (5, 1, 'Priya Nair',  '1995-12-01', '27E'),
  (6, 1, 'Layla Haddad','1988-03-15', '05A'),
  (7, 4, 'Layla Haddad','1988-03-15', '06A'),
  (8, 5, 'Tom Hughes',  '1985-01-22', '44K');


-- =====================================================================
-- THE THREE CLIENT QUESTIONS
-- =====================================================================

-- Q1. Find all changed prices, and the clients who opted in to alerts for that flight.
--     "Changed since the program last ran" -> here, since 1 Nov 2019.
SELECT  c.name         AS client,
        c.email,
        f.flight_number,
        fa.cabin_class,
        fa.passenger_type,
        fh.old_price,
        fh.new_price,
        fh.changed_at
FROM        FareHistory fh
JOIN        Fare        fa ON fa.fare_id   = fh.fare_id
JOIN        Flight      f  ON f.flight_id  = fa.flight_id
JOIN        PriceAlert  pa ON pa.flight_id = f.flight_id
JOIN        Client      c  ON c.client_id  = pa.client_id
WHERE       fh.changed_at >= '2019-11-01'
ORDER BY    c.name, fh.changed_at, fa.passenger_type;


-- Q2. Bookings per country for ONE airline, most first.
--     "Country" = the client's country. Cancelled bookings left out.
SELECT  co.name    AS country,
        COUNT(*)   AS bookings
FROM        Booking  b
JOIN        Flight   f  ON f.flight_id   = b.flight_id
JOIN        Airline  a  ON a.airline_id  = f.airline_id
JOIN        Client   c  ON c.client_id   = b.client_id
JOIN        Country  co ON co.country_id = c.country_id
WHERE       a.name   = 'Emirates'
  AND       b.status = 'confirmed'
GROUP BY    co.country_id, co.name
ORDER BY    bookings DESC;


-- Q3. Flights in December 2019 with a child fare AND a kids' meal.
--     Filter on the FLIGHT's departure date, not the booking date.
SELECT DISTINCT
        f.flight_number,
        f.departure_time
FROM        Flight f
JOIN        Fare   fa ON fa.flight_id = f.flight_id
WHERE       f.departure_time >= '2019-12-01'
  AND       f.departure_time <  '2020-01-01'
  AND       f.offers_kids_meal = TRUE
  AND       fa.passenger_type  = 'child'
ORDER BY    f.departure_time;
