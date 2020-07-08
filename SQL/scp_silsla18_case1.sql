-- Spec #1: Pure CDL bibs, no print holdings, no UCLA 856 fields, WITHOUT PO
-- DELETE bibs and holdings for Vanguard.
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
, print as (
  select b.bib_id
  from bibs b
  inner join bib_mfhd bm on b.bib_id = bm.bib_id
  inner join mfhd_master mm on bm.mfhd_id = mm.mfhd_id
  inner join location l on mm.location_id = l.location_id
  where l.location_code != 'in'
)
, online_only as (
  select bib_id from bibs
  minus
  select bib_id from print
)
select bib_id
from online_only o
where not exists (
  select * from line_item
  where bib_id = o.bib_id
)
order by bib_id
;
