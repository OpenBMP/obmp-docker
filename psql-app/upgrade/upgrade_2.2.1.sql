-- -----------------------------------------------------------------------
-- Copyright (c) 2022 Cisco Systems, Inc. and others.  All rights reserved.
--
-- Ugrade from 2.2.0 to 2.2.1 changes
-- -----------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ip_rib_first_added_timestamp_idx ON ip_rib (first_added_timestamp DESC);

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

CREATE OR REPLACE FUNCTION sync_global_ip_rib()
	RETURNS void AS $$
DECLARE
	execution_start timestamptz  := clock_timestamp();
	insert_count    int;
	start_time timestamptz := now();
BEGIN

	raise INFO 'Start time       : %', execution_start;

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
	WHERE origin_as != 23456
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
	WHERE  i.prefix = r.prefix;

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
	WHERE
			p.prefix >>= r.prefix
	  AND r.prefix_len >= p.prefix_len
	  AND r.prefix_len <= p.prefix_len_max;

	GET DIAGNOSTICS insert_count = row_count;
	raise INFO 'Rows updated   : %', insert_count;
	raise INFO 'Duration       : %', clock_timestamp() - execution_start;


	raise INFO 'Completion time: %', clock_timestamp();

END;
$$ LANGUAGE plpgsql;

