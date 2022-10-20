-- -----------------------------------------------------------------------
-- Copyright (c) 2022 Cisco Systems, Inc. and others.  All rights reserved.
--
-- Upgrade form 2.2.1 to 2.2.2
-- -----------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS base_attrs_next_hop_idx ON base_attrs (next_hop);


CREATE OR REPLACE FUNCTION update_global_ip_rib(max_interval interval DEFAULT '2 hour')
	RETURNS void AS $$
DECLARE
	execution_start timestamptz  := clock_timestamp();
	insert_count    int;
	start_time timestamptz := now();
BEGIN

	select time_bucket('5 minutes', timestamp - interval '5 minute') INTO start_time
	FROM global_ip_rib order by timestamp desc limit 1;

	IF start_time is null THEN
		start_time = time_bucket('5 minutes', now() - max_interval);
		raise INFO '-> Last query time is null, setting last query time within %', max_interval;
	ELSIF start_time < now() - max_interval THEN
		start_time = time_bucket('5 minutes', now() - max_interval);
		raise INFO '-> Last query time is greater than max % time, setting last query time', max_interval;
	ELSIF start_time > now() THEN
		start_time = time_bucket('5 minutes', now() - interval '15 minutes');
		raise INFO '-> Last query time is greater than current time, setting last query time to past 15 minutes';
	END IF;

	raise INFO 'Start time       : %', execution_start;
	raise INFO 'Last Query Time  : %', start_time;

	raise INFO '-> Updating changed prefixes ...';

	insert_count = 0;

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
	WHERE
		(timestamp >= start_time OR first_added_timestamp >= start_time)
	  AND origin_as != 23456
	GROUP BY r.prefix, r.origin_as
	ON CONFLICT (prefix,recv_origin_as)
		DO UPDATE SET timestamp=excluded.timestamp,
		              first_added_timestamp=excluded.first_added_timestamp,
		              iswithdrawn=excluded.iswithdrawn,
		              num_peers=excluded.num_peers,
		              advertising_peers=excluded.advertising_peers,
		              withdrawn_peers=excluded.withdrawn_peers;

	GET DIAGNOSTICS insert_count = row_count;
	raise INFO 'Rows updated   : %', insert_count;
	raise INFO 'Duration       : %', clock_timestamp() - execution_start;
	raise INFO 'Completion time: %', clock_timestamp();

	-- Update IRR
	raise INFO '-> Updating IRR info';
	UPDATE global_ip_rib r SET
		                       irr_origin_as=i.origin_as,
		                       irr_source=i.source,
		                       irr_descr=i.descr
	FROM info_route i
	WHERE  r.timestamp >= start_time and i.prefix = r.prefix;

	GET DIAGNOSTICS insert_count = row_count;
	raise INFO 'Rows updated   : %', insert_count;
	raise INFO 'Duration       : %', clock_timestamp() - execution_start;
	raise INFO 'Completion time: %', clock_timestamp();


	-- Update RPKI entries - Limit query to only update what has changed in interval time
	--    NOTE: The global_ip_rib table should have current times when first run (new table).
	--          This will result in this query taking a while. After first run, it shouldn't take
	--          as long.
	raise INFO '-> Updating RPKI info';
	UPDATE global_ip_rib r SET rpki_origin_as=p.origin_as
	FROM rpki_validator p
	WHERE r.timestamp >= start_time
	  AND p.prefix >>= r.prefix
	  AND r.prefix_len >= p.prefix_len
	  AND r.prefix_len <= p.prefix_len_max;

	GET DIAGNOSTICS insert_count = row_count;
	raise INFO 'Rows updated   : %', insert_count;
	raise INFO 'Duration       : %', clock_timestamp() - execution_start;


	raise INFO 'Completion time: %', clock_timestamp();

END;
$$ LANGUAGE plpgsql;

drop view IF EXISTS v_ls_links CASCADE;

ALTER TABLE ls_links
	ALTER COLUMN admin_group TYPE bigint,
	ALTER COLUMN unreserved_bw TYPE varchar(128);
ALTER TABLE ls_links_log
	ALTER COLUMN admin_group TYPE bigint,
	ALTER COLUMN unreserved_bw TYPE varchar(128);


CREATE VIEW v_ls_links AS
SELECT localn.name as Local_Router_Name,remoten.name as Remote_Router_Name,
       localn.igp_router_id as Local_IGP_RouterId,localn.router_id as Local_RouterId,
       remoten.igp_router_id Remote_IGP_RouterId, remoten.router_id as Remote_RouterId,
       localn.seq, localn.bgp_ls_id as bgpls_id,
       CASE WHEN ln.protocol in ('OSPFv2', 'OSPFv3') THEN localn.ospf_area_id ELSE localn.isis_area_id END as AreaId,
       ln.mt_id as MT_ID,interface_addr as InterfaceIP,neighbor_addr as NeighborIP,
       ln.isIPv4,ln.protocol,igp_metric,local_link_id,remote_link_id,admin_group,max_link_bw,max_resv_bw,
       unreserved_bw,te_def_metric,mpls_proto_mask,srlg,ln.name,ln.timestamp,local_node_hash_id,remote_node_hash_id,
       localn.igp_router_id as localn_igp_router_id,remoten.igp_router_id as remoten_igp_router_id,
       ln.base_attr_hash_id as base_attr_hash_id, ln.peer_hash_id as peer_hash_id,
       CASE WHEN ln.iswithdrawn THEN 'WITHDRAWN' ELSE 'ACTIVE' END as state
FROM ls_links ln
	     JOIN ls_nodes localn ON (ln.local_node_hash_id = localn.hash_id
	AND ln.peer_hash_id = localn.peer_hash_id)
	     JOIN ls_nodes remoten ON (ln.remote_node_hash_id = remoten.hash_id
	AND ln.peer_hash_id = remoten.peer_hash_id);
