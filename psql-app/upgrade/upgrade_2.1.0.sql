-- -----------------------------------------------------------------------
-- Copyright (c) 2022 Cisco Systems, Inc. and others.  All rights reserved.
--
-- Ugrade from 2.0.3 to 2.1.0 changes
-- -----------------------------------------------------------------------
ALTER TABLE base_attrs SET (autovacuum_vacuum_cost_limit = 1000);
ALTER TABLE base_attrs SET (autovacuum_vacuum_cost_delay = 5);

alter table global_ip_rib
	add column advertising_peers int DEFAULT 0,
	add column withdrawn_peers int DEFAULT 0;

CREATE OR REPLACE FUNCTION update_global_ip_rib(
	int_time interval DEFAULT '15 minutes'
)
	RETURNS void AS $$
DECLARE
	execution_start timestamptz  := clock_timestamp();
	insert_count    int;
BEGIN
	raise INFO 'Start time     : %', now();
	raise INFO 'Interval Time  : %', int_time;
	raise INFO '-> Inserting rows in global_ip_rib ...';

	lock table global_ip_rib IN SHARE ROW EXCLUSIVE MODE;

	-- Load changed prefixes only - First time will load every prefix. Expect in that case it'll take a little while.
	INSERT INTO global_ip_rib (prefix,prefix_len,recv_origin_as,
	                           iswithdrawn,timestamp,first_added_timestamp,num_peers,advertising_peers,withdrawn_peers)
	SELECT r.prefix,
	       max(r.prefix_len),
	       r.origin_as,
	       bool_and(r.iswithdrawn)                                             as isWithdrawn,
	       max(r.timestamp),
	       min(r.first_added_timestamp),
	       count(distinct r.peer_hash_id)                                      as total_peers,
	       count(distinct r.peer_hash_id) FILTER (WHERE r.iswithdrawn = False) as advertising_peers,
	       count(distinct r.peer_hash_id) FILTER (WHERE r.iswithdrawn = True)  as withdrawn_peers
	FROM ip_rib r
	WHERE prefix in (
		SELECT prefix
		FROM ip_rib_log
		WHERE
				timestamp >= now() - int_time AND
				origin_as != 23456
		GROUP BY prefix
	)
	GROUP BY r.prefix, r.origin_as
	ON CONFLICT (prefix,recv_origin_as)
		DO UPDATE SET timestamp=excluded.timestamp,
		              first_added_timestamp=excluded.timestamp,
		              iswithdrawn=excluded.iswithdrawn,
		              num_peers=excluded.num_peers,
		              advertising_peers=excluded.advertising_peers,
		              withdrawn_peers=excluded.withdrawn_peers;

	GET DIAGNOSTICS insert_count = row_count;
	raise INFO 'Rows updated   : %', insert_count;
	raise INFO 'Execution time : %', clock_timestamp() - execution_start;
	raise INFO 'Completion time: %', now();

	-- Update IRR
	raise INFO '-> Updating IRR info';
	UPDATE global_ip_rib r SET
		                       irr_origin_as=i.origin_as,
		                       irr_source=i.source,
		                       irr_descr=i.descr
	FROM info_route i
	WHERE  r.timestamp >= now() - (int_time * 3) and i.prefix = r.prefix;

	-- Update RPKI entries - Limit query to only update what has changed in interval time
	--    NOTE: The global_ip_rib table should have current times when first run (new table).
	--          This will result in this query taking a while. After first run, it shouldn't take
	--          as long.
	raise INFO '-> Updating RPKI info';
	UPDATE global_ip_rib r SET rpki_origin_as=p.origin_as
	FROM rpki_validator p
	WHERE r.timestamp >= now() - (int_time * 3)
	  AND p.prefix >>= r.prefix
	  AND r.prefix_len >= p.prefix_len
	  AND r.prefix_len <= p.prefix_len_max;

END;
$$ LANGUAGE plpgsql;

drop index IF EXISTS global_ip_rib_iswithdrawn_timestamp_idx;
CREATE INDEX ON global_ip_rib (iswithdrawn,timestamp DESC);

drop index IF EXISTS ip_rib_timestamp_idx;
CREATE INDEX ON ip_rib (timestamp DESC);

drop index IF EXISTS global_ip_rib_iswithdrawn_idx;
drop index IF EXISTS global_ip_rib_timestamp_idx;
drop index IF EXISTS global_ip_rib_timestamp_prefix_idx;

CREATE INDEX ON global_ip_rib (timestamp DESC);

