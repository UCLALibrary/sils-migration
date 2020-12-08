set linesize 10;

-- Case 2: MARCIVE bibs with internet holdings and other holdings
-- These will have internet hols and bib 856 fields deleted.

with bibs as (
  select distinct
    record_id as bib_id
  from vger_subfields.ucladb_bib_subfield
  where tag = '910a'
  and upper(subfield) like '%MARCIVE%'
)
, hols as (
  select 
    bm.bib_id
  , bm.mfhd_id
  , l.location_code
  from bibs b
  inner join bib_mfhd bm on b.bib_id = bm.bib_id
  inner join mfhd_master mm on bm.mfhd_id = mm.mfhd_id
  inner join location l on mm.location_id = l.location_id
)
select distinct bib_id
from hols h
where location_code = 'in'
and exists (
  select * from hols where bib_id = h.bib_id and mfhd_id != h.mfhd_id and location_code != 'in'
)
order by bib_id
;
