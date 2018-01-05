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





[‎1/‎5/‎2018 12:42 PM]
here's another fun one for you: can you think of a way to easily reproject all layers in a db?

[‎1/‎5/‎2018 12:50 PM]  Spencer Gardner:
you'd need to create a function to do it automatically

[‎1/‎5/‎2018 12:51 PM]  Spencer Gardner:
but you can list all the tables in the db with

[‎1/‎5/‎2018 12:51 PM]  Spencer Gardner:
SELECT table_schema,table_name
FROM information_schema.tables
ORDER BY table_schema,table_name;

[‎1/‎5/‎2018 12:51 PM]  Spencer Gardner:
come to think of it, that might be a nice tdg function to have
it can read through all tables and reproject them all

[‎1/‎5/‎2018 12:51 PM]  Spencer Gardner:
if you're doing it table by table, you can do it like this:

[‎1/‎5/‎2018 12:52 PM]  Spencer Gardner:
ALTER table_name ALTER COLUMN geom TYPE geometry([point/line/poly], 9999) USING ST_Transform(geom,9999)
the USING tells it to run the reproject at the same time as changing the column type
