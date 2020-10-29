
--USES SPECIFICT 5/15/2020
--START PREFERED VENDOR COSTS

WITH pref AS (
        SELECT 
                item_id
                , internal_id
                , vendor
                , other_vendor
                , vendor_cost AS current_cost
        FROM views.v_item_vendors
        WHERE preferred_vendor_flg = 1
)

, hist_cost AS (
        SELECT 
                item_id
                , vendor
                , other_vendor
                , vendor_cost AS hist_cost
                , _datacoral_load_timestamp::date as load_date
                , ROW_NUMBER() OVER( PARTITION BY item_id, other_vendor, _datacoral_load_timestamp::date ORDER BY _datacoral_load_timestamp DESC) AS rank
        FROM netsuite.item_vendors 
        WHERE vendor = other_vendor
        AND _datacoral_load_timestamp::date >= (date '2020-05-15')
)

, no_fill AS (
	SELECT 
		item_id::int
		, hist_cost
		, load_date
	FROM hist_cost 
	WHERE 
		rank = 1
		AND load_date >= (date '2020-05-15')
		AND lower(item_id) NOT LIKE '%%test%%'
)

, sku_list AS (
	SELECT DISTINCT item_id FROM no_fill
)

, date_range AS 
(
	SELECT 
	*
	 from static.dates
	WHERE date_sk >= (date '2020-05-15') AND date_sk <= CURRENT_DATE
	order by date_sk
)

, sku_date AS (
	SELECT 
		* 
		FROM sku_list 
		CROSS JOIN date_range
	ORDER BY item_id, date_sk
)

, cost_date AS (
	SELECT 
		sd.item_id,
		sd.date_sk AS load_date,
		hist_cost  
		FROM sku_date as sd
		LEFT JOIN no_fill as nf 
			ON (nf.item_id = sd.item_id AND sd.date_sk = nf.load_date)
	ORDER BY sd.item_id, date_sk 
)

-- END PREFERRED VENDOR COST

, orders_dr AS (

	SELECT
			-- order info
			 oi.sku 
			 , oi.order_id
			 , oi.delivery_date::date
			 -- product matching
			 , COALESCE(m.cheetah_sku, oi.sku) AS cheetah_sku
			 , CASE WHEN (m.discontinued_type IS NULL OR m.discontinued_type = 'Direct Replacement')
			 	THEN COALESCE(m.cheetah_sku, oi.sku)
			 	ELSE sku
			 	END AS last_sku
			 --conversion factor
			 , m.case_conversion_factor
			 , CASE WHEN (m.discontinued_type = 'Direct Replacement')
			 	THEN m.case_conversion_factor
			 	ELSE Null
			 	END AS direct_conversion_factor
			 , oi.quantity
			 , oi.quantity_case
			 , quantity_case * COALESCE(direct_conversion_factor, 1.0) AS last_sku_cases
			 , m.discontinued_type	 

			 -- additional order info
			 , restaurant_id
			 , EXTRACT( week FROM delivery_date) AS week
			 , EXTRACT( year FROM delivery_date) AS year
			 , sub_total / 100.0 AS order_rev
			 --
			 , CASE WHEN vi.custitem_catchweight_item 
			 		THEN base_units_in_cs * c.hist_cost
			 	ELSE c.hist_cost
			 	END AS case_cost
			 , case_cost * oi.quantity_case AS order_cost
			 
		FROM summary.v_order_items AS oi
		LEFT OUTER JOIN summary.mv_sku_mappings AS m
			ON oi.sku = m.ordered_sku
		LEFT JOIN cost_date AS c 
			ON ( oi.sku = c.item_id AND oi.delivery_date = c.load_date)
		LEFT JOIN views.v_item_info AS vi
			ON vi.item_id = oi.sku
		WHERE 1=1
			AND order_type = 'FC'
			AND status IN (2,4,8)
			AND oi.delivery_date::date >= (date '2020-05-15')
)

, raw_item_list AS (
	SELECT DISTINCT item_id FROM gs.experiment_items
)

, item_list AS ( 
	SELECT 
		i.item_id
		,v2.experiment AS v2_flag
		,v2.change_date AS v2_date
		,v3.experiment AS v3_flag
		,v3.change_date AS v3_date
		,CONCAT( NVL(v2_flag,'') , NVL(v3_flag,'')) AS exp_group
		,LEAST( v2_date, v3_date) as min_change_date
	FROM raw_item_list as i
	LEFT JOIN (
				SELECT * FROM gs.experiment_items WHERE experiment ='v2'
			) AS v2
		--ON v2.item_id = i.item_id
		USING ( item_id )
	LEFT JOIN (
				SELECT * FROM gs.experiment_items WHERE experiment ='v3'
			) AS v3
		--ON v3.item_id = i.item_id
		ON i.item_id = v3.item_id-- USING ( item_id )  --here?
)

, v3orders AS (
	SELECT 
		o.*
		, v3a.exp_group
		, v3a.min_change_date AS date_to_golive
	FROM orders_dr as o
	INNER JOIN item_list as v3a
		ON o.last_sku = v3a.item_id
)

, daily_sum AS (
	SELECT
		last_sku
		, delivery_date
		, SUM( last_sku_cases ) as cases_sold
		, SUM( order_rev ) as revenue
		, SUM( order_cost ) as cost
		, MIN( date_to_golive ) as golive_min
	FROM v3orders
	GROUP BY delivery_date, last_sku
	ORDER BY last_sku, delivery_date 
)

SELECT 
	s.*
	, vi.custitem_product_group_name AS product_group
	, vi.custitem_product_subcategory_name AS sub_category
	, vi.custitem_cseg_category_name AS category  
FROM daily_sum AS s
LEFT JOIN views.v_item_info AS vi
	ON vi.item_id = s.last_sku

;



