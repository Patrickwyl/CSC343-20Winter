-- Q2. Refunds!

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO air_travel, public;
DROP TABLE IF EXISTS q2 CASCADE;

CREATE TABLE q2 (
    airline CHAR(2),
    name VARCHAR(50),
    year CHAR(4),
    seat_class seat_class,
    refund REAL
);

-- Do this for each of the views that define your intermediate steps.  
-- (But give them better names!) The IF EXISTS avoids generating an error 
-- the first time this file is imported.
DROP VIEW IF EXISTS intermediate_step CASCADE;


-- Define views for your intermediate steps here:

CREATE VIEW DepArv AS
SELECT Departure.flight_id, Departure.datetime AS r_dep, Arrival.datetime AS r_arv
FROM Departure JOIN Arrival ON Departure.flight_id = Arrival.flight_id;

CREATE VIEW FlightYear AS
SELECT id AS flight_id, airline, outbound, inbound, 
EXTRACT(YEAR FROM s_dep) AS year, s_dep, s_arv
FROM Flight;

CREATE VIEW DepartureCountry AS
SELECT flight_id, airline, country AS dep_country, inbound, year, s_dep, s_arv
FROM Airport JOIN FlightYear ON Airport.code = FlightYear.outbound;

CREATE VIEW FlightCountry AS
SELECT flight_id, airline, dep_country, country AS arv_country, year, s_dep, s_arv
FROM Airport JOIN DepartureCountry ON Airport.code = DepartureCountry.inbound;

CREATE VIEW Domestic AS
SELECT Booking.flight_id, airline, year, seat_class, price, s_dep, s_arv
FROM FlightCountry JOIN Booking ON FlightCountry.flight_id = Booking.flight_id
WHERE dep_country = arv_country;

CREATE VIEW International AS
SELECT Booking.flight_id, airline, year, seat_class, price, s_dep, s_arv
FROM FlightCountry JOIN Booking ON FlightCountry.flight_id = Booking.flight_id
WHERE dep_country <> arv_country;

CREATE VIEW DomesticDelay4 AS
SELECT airline, year, seat_class, price
FROM Domestic NATURAL JOIN DepArv
WHERE EXTRACT(epoch FROM (r_dep - s_dep)) >= 4*3600 
and  EXTRACT(epoch FROM (r_dep - s_dep)) < 10*3600
and EXTRACT(epoch FROM (r_arv - s_arv)) > EXTRACT(epoch FROM (r_dep - s_dep))/2;

CREATE VIEW DomesticDelay10 AS
SELECT airline, year, seat_class, price
FROM Domestic NATURAL JOIN DepArv
WHERE EXTRACT(epoch FROM (r_dep - s_dep)) >= 10*3600 
and EXTRACT(epoch FROM (r_arv - s_arv)) > EXTRACT(epoch FROM (r_dep - s_dep))/2;

CREATE VIEW InternationalDelay7 AS
SELECT airline, year, seat_class, price
FROM International NATURAL JOIN DepArv
WHERE EXTRACT(epoch FROM (r_dep - s_dep)) >= 7*3600 
and  EXTRACT(epoch FROM (r_dep - s_dep)) < 12*3600
and EXTRACT(epoch FROM (r_arv - s_arv)) > EXTRACT(epoch FROM (r_dep - s_dep))/2;

CREATE VIEW InternationalDelay12 AS
SELECT airline, year, seat_class, price
FROM International NATURAL JOIN DepArv
WHERE EXTRACT(epoch FROM (r_dep - s_dep)) >= 12*3600 
and EXTRACT(epoch FROM (r_arv - s_arv)) > EXTRACT(epoch FROM (r_dep - s_dep))/2;

CREATE VIEW DomesticRefund1 AS
SELECT airline, year, seat_class, sum(price*0.35) AS refund_d1
FROM DomesticDelay4
GROUP BY airline, year, seat_class;

CREATE VIEW DomesticRefund2 AS
SELECT airline, year, seat_class, sum(price*0.5) AS refund_d2
FROM DomesticDelay10
GROUP BY airline, year, seat_class;

CREATE VIEW InternationalRefund1 AS
SELECT airline, year, seat_class, sum(price*0.35) AS refund_I1
FROM InternationalDelay7
GROUP BY airline, year, seat_class;

CREATE VIEW InternationalRefund2 AS
SELECT airline, year, seat_class, sum(price*0.5) AS refund_I2
FROM InternationalDelay12
GROUP BY airline, year, seat_class;

CREATE VIEW DomesticRefund AS
SELECT airline, year, seat_class, COALESCE(refund_d1,0) + COALESCE(refund_d2,0) AS refundD
FROM DomesticRefund1 NATURAL FULL JOIN DomesticRefund2;

CREATE VIEW InternationalRefund AS
SELECT airline, year, seat_class, COALESCE(refund_I1,0) + COALESCE(refund_I2,0) AS refundI
FROM InternationalRefund1 NATURAL FULL JOIN InternationalRefund2;

CREATE VIEW Refund AS
SELECT airline, year, seat_class, COALESCE(refundD,0) + COALESCE(refundI,0) AS refund
FROM DomesticRefund NATURAL FULL JOIN InternationalRefund;

CREATE VIEW Result AS
SELECT airline, name, year, seat_class, refund
FROM Refund JOIN Airline ON Refund.airline = Airline.code;


-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q2
(SELECT airline, name, year, seat_class, refund
FROM Result);
