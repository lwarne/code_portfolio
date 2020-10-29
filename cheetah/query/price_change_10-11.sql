WITH item_list AS (
	SELECT DISTINCT item_id FROM gs.experiment_items
)

, dup_experiment_list AS (
	SELECT 
		i.item_id
		,v2.experiment AS v2_flag
		,v2.change_date::date AS v2_date
		,v3.experiment AS v3_flag
		,v3.change_date::date AS v3_date
		,CONCAT( NVL(v2_flag,'') , NVL(v3_flag,'')) AS e_group
		,LEAST( v2_date, v3_date) as min_change_date
	FROM item_list as i
	LEFT JOIN (
				SELECT * FROM gs.experiment_items WHERE experiment ='v2'
			) AS v2
		ON v2.item_id = i.item_id
	LEFT JOIN (
				SELECT * FROM gs.experiment_items WHERE experiment ='v3'
			) AS v3
		ON v3.item_id = i.item_id )

,experiment_list AS (
	SELECT 
		item_id,
		e_group,
		MIN(min_change_date) AS min_change_date
	FROM dup_experiment_list
	GROUP BY item_id, e_group
)

, sku_list AS (
	SELECT item_id
	FROM experiment_list
)

, max_date AS (
    SELECT MAX(updated_at) AS max_ph
    FROM pg.products_history
)

, date_rows AS (
    SELECT sku
    	, weight_price_cents
        , unit_price_cents
        , pack_price_cents
        , updated_at
        , date_sk
        , ROW_NUMBER() OVER (PARTITION BY sku, date_sk ORDER BY updated_at DESC) AS rn
    FROM pg.products_history ph
    FULL JOIN static.dates dt
        ON dt.date_sk >= ph.updated_at
    INNER JOIN sku_list ON sku_list.item_id = sku
    JOIN max_date md ON md.max_ph >= dt.date_sk
    WHERE 1=1
    AND store_id = 18
    --AND sku = '103479'
)

, latest_prices_daily AS (
    SELECT 
    	*
    	,date (date_sk - interval '3 day') as minus_3
    	,date (date_sk + interval '3 day') as plus_3
    FROM date_rows
    WHERE 1=1
    	AND rn = 1
    ORDER BY date_sk, updated_at
)

, raw_changed_prices AS (
	SELECT 
		e.item_id
		, e.min_change_date
		
		, bp.date_sk as before_date
		, bp.weight_price_cents AS before_weight_price_cents
		, bp.unit_price_cents AS before_unit_price_cents 
		, bp.pack_price_cents AS before_pack_price_cents
		
		, fp.date_sk AS after_date
		, fp.weight_price_cents AS after_weight_price_cents
		, fp.unit_price_cents AS after_unit_price_cents
		, fp.pack_price_cents AS after_pack_price_cents
		
--		, tp.date_sk AS today_date
--		, tp.weight_price_cents AS today_weight_price_cents
--		, tp.unit_price_cents AS today_unit_price_cents
--		, tp.pack_price_cents AS today_pack_price_cents
		
	FROM experiment_list AS e
	LEFT JOIN latest_prices_daily AS bp
		ON bp.plus_3 = e.min_change_date AND bp.sku = e.item_id
	LEFT JOIN latest_prices_daily AS fp
		ON fp.minus_3 = e.min_change_date AND fp.sku = e.item_id
--	LEFT JOIN latest_prices_daily AS tp
--		ON tp.date_sk = e.min_change_date AND tp.sku = e.item_id
)

-- calculate change
SELECT 
	*
	--missing
	, CASE WHEN before_date IS NULL THEN TRUE ELSE FALSE END AS missing_before

	--change
	, CASE WHEN NOT missing_before 
		THEN (after_weight_price_cents::float - before_weight_price_cents::float) / before_weight_price_cents::float
		END AS weight_price_change
	, CASE WHEN NOT missing_before 
		THEN (after_unit_price_cents::float - before_unit_price_cents::float) / before_unit_price_cents::float
		END AS unit_price_change
	, CASE WHEN NOT missing_before 
		THEN (after_pack_price_cents::float - before_pack_price_cents::float) / before_pack_price_cents::float
		END AS pack_pack_change
	, LEAST(weight_price_change, unit_price_change, pack_pack_change) AS max_price_change
FROM raw_changed_prices as rcp
ORDER BY max_price_change