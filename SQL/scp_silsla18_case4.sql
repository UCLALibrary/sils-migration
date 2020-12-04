set linesize 10;

-- Spec #4: Hybrid CDL/UCLA bibs WITH open CDL PO
-- UPDATE bibs, with CDL 856 modification

with bibs as (
  select distinct
    record_id as bib_id
  from vger_subfields.ucladb_bib_subfield bs
  where tag = '856x'
  -- Significant (3700+) typos and case variations
  and (subfield like 'CDL%' or upper(subfield) like 'UC OPEN ACCESS%')
  and exists (
    select *
    from vger_subfields.ucladb_bib_subfield
    where record_id = bs.record_id
    and tag = '856x'
    and subfield in ('UCLA', 'UCLA Law')
  )
), cdl_open_orders as (
  select
    b.bib_id
  , po.po_number
  , v.vendor_code
  , pos.po_status_desc
  from bibs b
  inner join bib_mfhd bm on b.bib_id = bm.bib_id
  inner join mfhd_master mm on bm.mfhd_id = mm.mfhd_id
  inner join location l on mm.location_id = l.location_id
  inner join line_item_copy_status lics on mm.mfhd_id = lics.mfhd_id
  inner join line_item li on lics.line_item_id = li.line_item_id
  inner join purchase_order po on li.po_id = po.po_id
  inner join vendor v on po.vendor_id = v.vendor_id
  inner join po_status pos on po.po_status = pos.po_status
  where l.location_code = 'in'
  and v.vendor_code = 'LXO'
  and pos.po_status_desc in ('Approved/Sent', 'Received Partial')
)
select bib_id
from bibs b
where exists (
  select * from cdl_open_orders
  where bib_id = b.bib_id
)
order by bib_id
;
