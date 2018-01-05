--connect to Census database
SELECT dblink_connect_u('census','dbname=census user=gis password=gis');

--create table as selection of ca_demographics where it intersects Marin Co.
DROP TABLE IF EXISTS scratch.dblink_test;
CREATE TABLE scratch.dblink_test AS
  (select t.geom, t.geoid_data
  from dblink
      ('census','SELECT
        st_transform(geom,2872),
        geoid_str
        FROM ca_demographics')
      as t(
      geom GEOMETRY ,
      geoid_data TEXT),
    county_boundary_legal
    WHERE ST_Intersects(t.geom,county_boundary_legal.geom)
    );

--Disconnect from Census database
SELECT dblink_disconnect('census');

--define geometry and projection - for some reason, dblink won't let you do this
--in the select statement
ALTER TABLE dblink_test
	ALTER COLUMN geom TYPE geometry(multipolygon,2872)
	USING ST_SetSRID(geom,2872);

--add primary key
ALTER TABLE dblink_test ADD COLUMN id SERIAL PRIMARY KEY;

--create spatial index
CREATE INDEX sidx_dblink_text ON scratch.dblink_test USING GIST (geom);
ANALYZE scratch.dblink_test(geom);
