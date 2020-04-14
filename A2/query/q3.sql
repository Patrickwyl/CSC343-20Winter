-- Q3. North and South Connections

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO air_travel, public;
DROP TABLE IF EXISTS q3 CASCADE;

CREATE TABLE q3 (
    outbound VARCHAR(30),
    inbound VARCHAR(30),
    direct INT,
    one_con INT,
    two_con INT,
    earliest timestamp
);

-- Do this for each of the views that define your intermediate steps.  
-- (But give them better names!) The IF EXISTS avoids generating an error 
-- the first time this file is imported.
DROP VIEW IF EXISTS intermediate_step CASCADE;


-- Define views for your intermediate steps here:

CREATE VIEW CanadaCity AS
SELECT city
FROM airport
WHERE country = 'Canada'
GROUP BY city;

CREATE VIEW USCity AS
SELECT city
FROM airport
WHERE country = 'USA'
GROUP BY city;

CREATE VIEW CANUS AS
SELECT CanadaCity.city AS inbound, USCity.city AS outbound
FROM CanadaCity CROSS JOIN USCity
GROUP BY inbound, outbound;

CREATE VIEW USCAN AS
SELECT USCity.city AS inbound, CanadaCity.city AS outbound
FROM USCity CROSS JOIN CanadaCity
GROUP BY inbound, outbound;

CREATE VIEW CityPair AS
SELECT outbound, inbound
FROM USCAN UNION 
SELECT outbound, inbound
FROM CANUS;

CREATE VIEW CanDep AS
SELECT city AS outbound, inbound, s_dep, s_arv
FROM flight JOIN airport ON flight.outbound = airport.code
WHERE country = 'Canada' and s_dep >= timestamp'Apr-30-2020 00:00';

CREATE VIEW USDep AS
SELECT city AS outbound, inbound, s_dep, s_arv
FROM flight JOIN airport ON flight.outbound = airport.code
WHERE country = 'USA' and s_dep >= timestamp'Apr-30-2020 00:00';

CREATE VIEW USCanD AS
SELECT outbound, city AS inbound, s_dep, s_arv
FROM USDep JOIN airport ON USDep.inbound = airport.code
WHERE country = 'Canada';

CREATE VIEW CanUSD AS
SELECT outbound, city AS inbound, s_dep, s_arv
FROM CanDep JOIN airport ON CanDep.inbound = airport.code
WHERE country = 'USA';

CREATE VIEW Direct AS
(SELECT outbound, inbound, s_arv FROM CanUSD)
UNION
(SELECT outbound, inbound, s_arv FROM USCanD);

CREATE VIEW DirectDay AS
SELECT outbound, inbound, s_arv 
FROM Direct
WHERE (s_arv - timestamp'Apr-30-2020 00:00' < interval '1 day');

CREATE VIEW CanOneCon AS
SELECT CanDep.outbound, flight.outbound AS con1, flight.inbound, flight.s_arv AS s_arv
FROM CanDep JOIN flight ON CanDep.inbound = flight.outbound
WHERE (flight.s_dep - CanDep.s_arv) > interval '30 minutes';

CREATE VIEW USOneCon AS
SELECT USDep.outbound, flight.outbound AS con1, flight.inbound, flight.s_arv AS s_arv
FROM USDep JOIN flight ON USDep.inbound = flight.outbound
WHERE (flight.s_dep - USDep.s_arv) > interval '30 minutes';

CREATE VIEW CanConUS AS
SELECT CanOneCon.outbound, CanOneCon.con1, city AS inbound, CanOneCon.s_arv
FROM CanOneCon JOIN airport ON CanOneCon.inbound = airport.code
WHERE country = 'USA';

CREATE VIEW USConCan AS
SELECT USOneCon.outbound, USOneCon.con1, city AS inbound, USOneCon.s_arv
FROM USOneCon JOIN airport ON USOneCon.inbound = airport.code
WHERE country = 'Canada';

CREATE VIEW OneCon AS
(SELECT outbound, inbound, s_arv FROM CanConUS)
UNION
(SELECT outbound, inbound, s_arv FROM USConCan);

CREATE VIEW OneConDay AS
SELECT * FROM OneCon
WHERE (s_arv - timestamp'Apr-30-2020 00:00' < interval '1 day');

CREATE VIEW CanTwoCon AS
SELECT CanOneCon.outbound, CanOneCon.con1, flight.outbound AS con2, flight.inbound, flight.s_arv AS s_arv
FROM CanOneCon JOIN flight ON CanOneCon.inbound = flight.outbound;

CREATE VIEW USTwoCon AS
SELECT USOneCon.outbound, USOneCon.con1, flight.outbound AS con2, flight.inbound, flight.s_arv AS s_arv
FROM USOneCon JOIN flight ON USOneCon.inbound = flight.outbound;

CREATE VIEW CanTwoConUS AS
SELECT CanTwoCon.outbound, CanTwoCon.con1, CanTwoCon.con2, city AS inbound, CanTwoCon.s_arv
FROM CanTwoCon JOIN airport ON CanTwoCon.inbound = airport.code
WHERE country = 'USA';

CREATE VIEW USTwoConCan AS
SELECT USTwoCon.outbound, USTwoCon.con1, USTwoCon.con2, city AS inbound, USTwoCon.s_arv
FROM USTwoCon JOIN airport ON USTwoCon.inbound = airport.code
WHERE country = 'Canada';

CREATE VIEW TwoCon AS
(SELECT outbound, inbound, s_arv FROM CanTwoConUS)
UNION
(SELECT outbound, inbound, s_arv FROM USTwoConCan);

CREATE VIEW TwoConDay AS
SELECT * FROM TwoCon
WHERE (s_arv - timestamp'Apr-30-2020 00:00' < interval '1 day');

CREATE VIEW DirLoc AS
SELECT CityPair.outbound, CityPair.inbound, DirectDay.s_arv AS dir_arr
FROM CityPair JOIN DirectDay ON (CityPair.inbound = DirectDay.inbound AND CityPair.outbound = DirectDay.outbound);

CREATE VIEW ConLoc AS
SELECT CityPair.outbound, CityPair.inbound, OneConDay.s_arv AS con_arr
FROM CityPair JOIN OneConDay ON (CityPair.inbound = OneConDay.inbound AND CityPair.outbound = OneConDay.outbound);

CREATE VIEW TConLoc AS
SELECT CityPair.outbound, CityPair.inbound, TwoConDay.s_arv AS con2_arr
FROM CityPair JOIN TwoConDay ON (CityPair.inbound = TwoConDay.inbound AND CityPair.outbound = TwoConDay.outbound);

CREATE VIEW DirInt AS
SELECT outbound, inbound, count(*) AS direct, min(dir_arr - timestamp'Apr-30-2020 00:00') as interv
FROM DirLoc
GROUP BY outbound, inbound;

CREATE VIEW ConInt AS
SELECT outbound, inbound, count(*) AS one_con, min(con_arr - timestamp'Apr-30-2020 00:00') as interv
FROM ConLoc
GROUP BY outbound, inbound;

CREATE VIEW Con2Int AS
SELECT outbound, inbound, count(*) AS two_con, min(con2_arr- timestamp'Apr-30-2020 00:00') as interv
FROM TConLoc
GROUP BY outbound, inbound;

CREATE VIEW JoinInter AS
(SELECT outbound, inbound, interv FROM DirInt)
UNION ALL
(SELECT outbound, inbound, interv FROM ConInt)
UNION ALL
(SELECT outbound, inbound, interv FROM Con2Int);

CREATE VIEW MinInt AS
SELECT outbound, inbound, (timestamp'Apr-30-2020 00:00' + min(interv)) AS earliest
FROM JoinInter
GROUP BY outbound, inbound;

CREATE VIEW Result AS 
SELECT MinInt.outbound AS outbound, MinInt.inbound AS inbound, COALESCE(DirInt.direct, 0) AS direct, COALESCE(ConInt.one_con, 0) AS one_con, COALESCE(Con2Int.two_con, 0) AS two_con, MinInt.earliest AS earliest
FROM MinInt NATURAL FULL JOIN DirInt NATURAL FULL JOIN ConInt NATURAL FULL JOIN Con2Int;





-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q3
(SELECT outbound, inbound, direct, one_con, two_con, earliest
FROM Result);
