-- -- spencer's stuff
-- UPDATE  barriers_prioritized
-- SET     name_of_column = (
--           SELECT  SUM(ST_length(ST_Intersection(trails.geom,barriers_prioritized.buff_qtr)))
--           FROM    trails
--           WHERE   ST_Intersects(trails.geom,barriers_prioritized.buff_qtr)
--         )
--         +
--         (
--           SELECT  SUM(ST_length(ST_Intersection(trails.geom,barriers_prioritized.buff_qtr)))
--           FROM    trails
--           WHERE   ST_Intersects(trails.geom,barriers_prioritized.buff_qtr)
--         )
--         ;

-- sum lgth of features within a buffer
UPDATE  barriers_prioritized
SET     name_of_column = (
          SELECT  SUM(ST_length(ST_Intersection(trails.geom,barriers_prioritized.buff_qtr)))
          FROM    trails
          WHERE   ST_Intersects(trails.geom,barriers_prioritized.buff_qtr)
        ) ;


--delete dupllicate geometries
delete from property_new
where id !=
(select id from property_new t2
where t2.geom=property_new.geom
order by id
limit 1);

--aggregate all row values that intersect
update proj_startend_pts
  set start_intersection = (select string_agg(bike_network_current.street,' / ')
  from bike_network_current
  where st_dwithin(proj_startend_pts.geom, bike_network_current.geom, 100)
  and bike_network_current.street !=proj_startend_pts.street);


--Copy Tabel
select tdg.tdgcopytable(
'mndot_rds',
'mndot_backup_20170804',
'scratch');





-- [‎1/‎5/‎2018 12:42 PM]
-- here's another fun one for you: can you think of a way to easily reproject all layers in a db?
--
-- [‎1/‎5/‎2018 12:50 PM]  Spencer Gardner:
-- you'd need to create a function to do it automatically
--
-- [‎1/‎5/‎2018 12:51 PM]  Spencer Gardner:
-- but you can list all the tables in the db with
--
-- [‎1/‎5/‎2018 12:51 PM]  Spencer Gardner:
-- SELECT table_schema,table_name
-- FROM information_schema.tables
-- ORDER BY table_schema,table_name;
--
-- [‎1/‎5/‎2018 12:51 PM]  Spencer Gardner:
-- come to think of it, that might be a nice tdg function to have
-- it can read through all tables and reproject them all
--
-- [‎1/‎5/‎2018 12:51 PM]  Spencer Gardner:
-- if you're doing it table by table, you can do it like this:
--
-- [‎1/‎5/‎2018 12:52 PM]  Spencer Gardner:
-- ALTER table_name ALTER COLUMN geom TYPE geometry([point/line/poly], 9999) USING ST_Transform(geom,9999)
-- the USING tells it to run the reproject at the same time as changing the column type


alter table areas_of_interest alter column geom type geometry(multipolygon,2276) using ST_Transform(geom,2276);

















--NOTE sub select that won't overwrite previous values

UPDATE automated.intersections as i
SET streets = (SELECT concat('Midblock - ',a.full_street_name)
FROM automated.austin_network a
WHERE i.f_status IN ('Done','Reviewed')
ORDER BY ST_Distance(i.geom,a.geom)
LIMIT 1
)
WHERE i.midblock = 1
;



--=====================================================================
--  Degrees, Min, Sec to Decimal Degrees
--=================================================================

CREATE OR REPLACE FUNCTION DMS2DD(strDegMinSec varchar)
    RETURNS numeric
    AS
    $$
    DECLARE
       i               numeric;
       intDmsLen       numeric;          -- Length of original string
       strCompassPoint Char(1);
       strNorm         varchar(16) = ''; -- Will contain normalized string
       strDegMinSecB   varchar(100);
       blnGotSeparator integer;          -- Keeps track of separator sequences
       arrDegMinSec    varchar[];        -- TYPE stringarray is table of varchar(2048) ;
       dDeg            numeric := 0;
       dMin            numeric := 0;
       dSec            numeric := 0;
       strChr          Char(1);
    BEGIN
       -- Remove leading and trailing spaces
       strDegMinSecB := REPLACE(strDegMinSec,' ','');
       -- assume no leading and trailing spaces?
       intDmsLen := Length(strDegMinSecB);

       blnGotSeparator := 0; -- Not in separator sequence right now

       -- Loop over string, replacing anything that is not a digit or a
       -- decimal separator with
       -- a single blank
       FOR i in 1..intDmsLen LOOP
          -- Get current character
          strChr := SubStr(strDegMinSecB, i, 1);
          -- either add character to normalized string or replace
          -- separator sequence with single blank
          If strpos('0123456789,.', strChr) > 0 Then
             -- add character but replace comma with point
             If (strChr <> ',') Then
                strNorm := strNorm || strChr;
             Else
                strNorm := strNorm || '.';
             End If;
             blnGotSeparator := 0;
          ElsIf strpos('neswNESW',strChr) > 0 Then -- Extract Compass Point if present
            strCompassPoint := strChr;
          Else
             -- ensure only one separator is replaced with a blank -
             -- suppress the rest
             If blnGotSeparator = 0 Then
                strNorm := strNorm || ' ';
                blnGotSeparator := 0;
             End If;
          End If;
       End Loop;

       -- Split normalized string into array of max 3 components
       arrDegMinSec := string_to_array(strNorm, ' ');

       --convert specified components to double
       i := array_upper(arrDegMinSec,1);
       If i >= 1 Then
          dDeg := CAST(arrDegMinSec[1] AS numeric);
       End If;
       If i >= 2 Then
          dMin := CAST(arrDegMinSec[2] AS numeric);
       End If;
       If i >= 3 Then
          dSec := CAST(arrDegMinSec[3] AS numeric);
       End If;

       -- convert components to value
       return (CASE WHEN UPPER(strCompassPoint) IN ('S','W')
                    THEN -1
                    ELSE 1
                END
               *
               (dDeg + dMin / 60 + dSec / 3600));
    End
$$
    LANGUAGE 'plpgsql' IMMUTABLE;


alter table upenn_bike_racks add column lat_dec FLOAT;
alter table upenn_bike_racks add column lon_dec FLOAT;

UPDATE upenn_bike_racks
set lat_dec = dms2dd(lat),
lon_dec = dms2dd(long)
;

alter table upenn_bike_racks add column geom geometry(point,4326);

update upenn_bike_racks
set geom = ST_SetSRID(ST_MakePoint(lon_dec, lat_dec), 4326);

create index sidx_upenn_bike_racks_geom on upenn_bike_racks using gist(geom);
analyze upenn_bike_racks (geom);
