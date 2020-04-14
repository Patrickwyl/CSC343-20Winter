-- Q4. Plane Capacity Histogram

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO air_travel, public;
DROP TABLE IF EXISTS q4 CASCADE;

CREATE TABLE q4 (
	airline CHAR(2),
	tail_number CHAR(5),
	very_low INT,
	low INT,
	fair INT,
	normal INT,
	high INT
);

-- Do this for each of the views that define your intermediate steps.  
-- (But give them better names!) The IF EXISTS avoids generating an error 
-- the first time this file is imported.
DROP VIEW IF EXISTS intermediate_step CASCADE;


-- Define views for your intermediate steps here:

CREATE VIEW FlightCompleted AS
SELECT Booking.flight_id, Booking.seat_class, Booking.row, Booking.letter
FROM Booking JOIN Departure ON Booking.flight_id = Departure.flight_id;

CREATE VIEW CountOccupy AS
SELECT flight_id, count(*) AS occupy
FROM FlightCompleted
GROUP BY flight_id;

CREATE VIEW PlaneOccupy AS
SELECT airline, plane, occupy
FROM CountOccupy JOIN Flight ON CountOccupy.flight_id = Flight.id;

CREATE VIEW PlaneCapacity AS
SELECT tail_number, (capacity_economy + capacity_business + capacity_first) AS capacity
From Plane;

CREATE VIEW Capacity AS
SELECT PlaneOccupy.airline, PlaneCapacity.tail_number, occupy::float /capacity as percentage
FROM PlaneCapacity JOIN PlaneOccupy ON PlaneCapacity.tail_number = PlaneOccupy.plane;

CREATE VIEW Very_low AS
SELECT airline, tail_number, count(*) AS very_low
FROM Capacity
WHERE percentage < 0.2
GROUP BY airline, tail_number;

CREATE VIEW Low AS
SELECT airline, tail_number, count(*) AS low
FROM Capacity
WHERE percentage >= 0.2 and percentage < 0.4
GROUP BY airline, tail_number;

CREATE VIEW Fair AS
SELECT airline, tail_number, count(*) AS fair
FROM Capacity
WHERE percentage >= 0.4 and percentage < 0.6
GROUP BY airline, tail_number;

CREATE VIEW Normal AS
SELECT airline, tail_number, count(*) AS normal
FROM Capacity
WHERE percentage >= 0.6 and percentage < 0.8
GROUP BY airline, tail_number;

CREATE VIEW High AS
SELECT airline, tail_number, count(*) AS high
FROM Capacity
WHERE percentage >= 0.8
GROUP BY airline, tail_number;

CREATE VIEW Histogram AS
SELECT airline, tail_number, coalesce(very_low, 0) AS very_low, 
coalesce(low, 0) AS low , coalesce(Fair, 0) AS fair, 
coalesce(normal, 0) AS normal, coalesce(high, 0) AS high
FROM Very_low NATURAL FULL JOIN Low NATURAL FULL JOIN Fair 
NATURAL FULL JOIN Normal NATURAL FULL JOIN High;

CREATE VIEW Result AS
SELECT Plane.airline, Plane.tail_number, coalesce(very_low, 0) AS very_low, 
coalesce(low, 0) AS low , coalesce(Fair, 0) AS fair, 
coalesce(normal, 0) AS normal, coalesce(high, 0) AS high
FROM Plane NATURAL FULL JOIN Histogram;


-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q4
(SELECT airline, tail_number, very_low, low, fair, normal, high
FROM Result);
