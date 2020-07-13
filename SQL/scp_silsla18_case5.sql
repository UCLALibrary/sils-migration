set linesize 10;

-- Spec #5: Pure CDL bibs, HAS print holdings, no UCLA 856 fields
-- UPDATE bibs, with CDL 856 deletion, AND delete internet holdings

with bibs as (
  select distinct
    record_id as bib_id
  from vger_subfields.ucladb_bib_subfield bs
  where tag = '856x'
  -- Significant (3700+) typos and case variations
  and (subfield like 'CDL%' or upper(subfield) like 'UC OPEN ACCESS%')
  and not exists (
    select *
    from vger_subfields.ucladb_bib_subfield
    where record_id = bs.record_id
    and tag = '856x'
    and subfield in ('UCLA', 'UCLA Law')
  )
)
, has_print as (
  select distinct b.bib_id
  from bibs b
  inner join bib_mfhd bm on b.bib_id = bm.bib_id
  inner join mfhd_master mm on bm.mfhd_id = mm.mfhd_id
  inner join location l on mm.location_id = l.location_id
  where l.location_code != 'in'
)
-- TODO: Possibly augment this with internet holdings ids for deletion
select bib_id
from has_print p
order by bib_id
;
