-- -----------------------------------------------------------------------
-- Copyright (c) 2022 Cisco Systems, Inc. and others.  All rights reserved.
--
-- Ugrade from 2.1.0 to 2.2.0 changes
-- -----------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ip_rib_prefix_idx ON ip_rib (prefix);

CREATE OR REPLACE FUNCTION update_global_ip_rib(max_interval interval DEFAULT '2 hour')
	RETURNS void AS $$
DECLARE
	execution_start timestamptz  := clock_timestamp();
	insert_count    int;
	start_time timestamptz := now();
	chg_prefix inet;
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

	raise INFO '-> Looping through changed prefixes ...';

	insert_count = 0;

	FOR chg_prefix IN
		SELECT prefix
		FROM ip_rib_log WHERE timestamp >= start_time AND origin_as != 23456
		UNION SELECT prefix FROM ip_rib where first_added_timestamp >= start_time
		GROUP BY prefix

		LOOP
			insert_count = insert_count + 1;

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
			WHERE r.prefix = chg_prefix
			  AND origin_as != 23456
			GROUP BY r.prefix, r.origin_as
			ON CONFLICT (prefix,recv_origin_as)
				DO UPDATE SET timestamp=excluded.timestamp,
				              first_added_timestamp=excluded.first_added_timestamp,
				              iswithdrawn=excluded.iswithdrawn,
				              num_peers=excluded.num_peers,
				              advertising_peers=excluded.advertising_peers,
				              withdrawn_peers=excluded.withdrawn_peers;

		END LOOP;

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

drop view IF EXISTS v_ip_routes CASCADE;
CREATE  VIEW v_ip_routes AS
SELECT  CASE WHEN length(rtr.name) > 0 THEN rtr.name ELSE host(rtr.ip_address) END AS RouterName,
        CASE WHEN length(p.name) > 0 THEN p.name ELSE host(p.peer_addr) END AS PeerName,
        r.prefix AS Prefix,r.prefix_len AS PrefixLen,
        attr.origin AS Origin,r.origin_as AS Origin_AS,attr.med AS MED,
        attr.local_pref AS LocalPref,attr.next_hop AS NH,attr.as_path AS AS_Path,
        attr.as_path_count AS ASPath_Count,attr.community_list AS Communities,
        attr.ext_community_list AS ExtCommunities,attr.large_community_list AS LargeCommunities,
        attr.cluster_list AS ClusterList,
        attr.originator_id as Originator, attr.aggregator AS Aggregator,p.peer_addr AS PeerAddress, p.peer_as AS PeerASN,r.isIPv4 as isIPv4,
        p.isIPv4 as isPeerIPv4, p.isL3VPNpeer as isPeerVPN,
        r.timestamp AS LastModified, r.first_added_timestamp as FirstAddedTimestamp,
        r.path_id, r.labels,
        r.hash_id as rib_hash_id,
        r.base_attr_hash_id as base_hash_id, r.peer_hash_id, rtr.hash_id as router_hash_id,r.isWithdrawn,
        r.isPrePolicy,r.isAdjRibIn
FROM ip_rib r
	     JOIN bgp_peers p ON (r.peer_hash_id = p.hash_id)
	     JOIN base_attrs attr ON (attr.hash_id = r.base_attr_hash_id and attr.peer_hash_id = r.peer_hash_id)
	     JOIN routers rtr ON (p.router_hash_id = rtr.hash_id);

drop view IF EXISTS v_ip_routes_geo CASCADE;
CREATE  VIEW v_ip_routes_geo AS
SELECT  CASE WHEN length(rtr.name) > 0 THEN rtr.name ELSE host(rtr.ip_address) END AS RouterName,
        CASE WHEN length(p.name) > 0 THEN p.name ELSE host(p.peer_addr) END AS PeerName,
        r.prefix AS Prefix,r.prefix_len AS PrefixLen,
        attr.origin AS Origin,r.origin_as AS Origin_AS,attr.med AS MED,
        attr.local_pref AS LocalPref,attr.next_hop AS NH,attr.as_path AS AS_Path,
        attr.as_path_count AS ASPath_Count,attr.community_list AS Communities,
        attr.ext_community_list AS ExtCommunities,attr.large_community_list AS LargeCommunities,
        attr.cluster_list AS ClusterList,attr.originator_id as Originator,
        attr.aggregator AS Aggregator,p.peer_addr AS PeerAddress, p.peer_as AS PeerASN,r.isIPv4 as isIPv4,
        p.isIPv4 as isPeerIPv4, p.isL3VPNpeer as isPeerVPN,
        r.timestamp AS LastModified, r.first_added_timestamp as FirstAddedTimestamp,
        r.path_id, r.labels,
        r.hash_id as rib_hash_id,
        r.base_attr_hash_id as base_hash_id, r.peer_hash_id, rtr.hash_id as router_hash_id,r.isWithdrawn,
        r.isPrePolicy,r.isAdjRibIn,
        g.ip as geo_ip,g.city as City, g.stateprov as stateprov, g.country as country,
        g.latitude as latitude, g.longitude as longitude
FROM ip_rib r
	     JOIN bgp_peers p ON (r.peer_hash_id = p.hash_id)
	     JOIN base_attrs attr ON (attr.hash_id = r.base_attr_hash_id and attr.peer_hash_id = r.peer_hash_id)
	     JOIN routers rtr ON (p.router_hash_id = rtr.hash_id)
	     LEFT JOIN geo_ip g ON (g.ip && host(r.prefix)::inet)
WHERE  r.isWithdrawn = false;


drop view IF EXISTS v_ip_routes_history CASCADE;
CREATE VIEW v_ip_routes_history AS
SELECT
	CASE WHEN length(rtr.name) > 0 THEN rtr.name ELSE host(rtr.ip_address) END AS RouterName,
	rtr.ip_address as RouterAddress,
	CASE WHEN length(p.name) > 0 THEN p.name ELSE host(p.peer_addr) END AS PeerName,
	log.prefix AS Prefix,log.prefix_len AS PrefixLen,
	attr.origin AS Origin,log.origin_as AS Origin_AS,
	attr.med AS MED,attr.local_pref AS LocalPref,attr.next_hop AS NH,
	attr.as_path AS AS_Path,attr.as_path_count AS ASPath_Count,attr.community_list AS Communities,
	attr.ext_community_list AS ExtCommunities,attr.large_community_list AS LargeCommunities,
	attr.cluster_list AS ClusterList,attr.originator_id as Originator,
	attr.aggregator AS Aggregator,p.peer_addr AS PeerIp,
	p.peer_as AS PeerASN,  p.isIPv4 as isPeerIPv4, p.isL3VPNpeer as isPeerVPN,
	log.id,log.timestamp AS LastModified,
	CASE WHEN log.iswithdrawn THEN 'Withdrawn' ELSE 'Advertised' END as event,
	log.base_attr_hash_id as base_attr_hash_id, log.peer_hash_id, rtr.hash_id as router_hash_id
FROM ip_rib_log log
	     JOIN base_attrs attr
	          ON (log.base_attr_hash_id = attr.hash_id AND
	              log.peer_hash_id = attr.peer_hash_id)
	     JOIN bgp_peers p ON (log.peer_hash_id = p.hash_id)
	     JOIN routers rtr ON (p.router_hash_id = rtr.hash_id);

