WITH orders_dr AS (

	SELECT
			 oi.sku 
			 , oi.order_id
			 , oi.delivery_date::date
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
			 , sub_total / 100.0 as sub_total
		FROM summary.v_order_items AS oi
		LEFT OUTER JOIN summary.mv_sku_mappings AS m
			ON oi.sku = m.ordered_sku
		WHERE 1=1
			AND order_type = 'FC'
			AND status IN (2,4,8)
)

,item_list AS (
	SELECT DISTINCT item_id FROM gs.experiment_items
)

, dup_experiment_list AS (
	SELECT 
		i.item_id
		,v2.experiment AS v2_flag
		,v2.change_date AS v2_date
		,v3.experiment AS v3_flag
		,v3.change_date AS v3_date
		,CONCAT( NVL(v2_flag,'') , NVL(v3_flag,'')) AS e_group
		,LEAST( v2_date, v3_date) as min_change_date
	FROM item_list as i
	LEFT JOIN (
				SELECT * FROM gs.experiment_items WHERE experiment ='v2'
			) AS v2
		--ON v2.item_id = i.item_id
		USING (item_id)
	LEFT JOIN (
				SELECT * FROM gs.experiment_items WHERE experiment ='v3'
			) AS v3
		--ON v3.item_id = i.item_id
		USING (item_id)
)

,experiment_list AS (
	SELECT 
		item_id,
		e_group,
		MIN(min_change_date) AS min_change_date
	FROM dup_experiment_list
	GROUP BY item_id, e_group
)

, v3orders AS (
	SELECT 
		o.*
		, v3a.item_id
		, v3a.e_group
		, v3a.min_change_date AS date_to_golive
	FROM orders_dr as o
	INNER JOIN experiment_list as v3a
		ON o.last_sku = v3a.item_id
)

--select * from v3orders;
SELECT
	last_sku
	, delivery_date
	, SUM(last_sku_cases) as cases_sold
	, MIN(date_to_golive) as golive_min
FROM v3orders
GROUP BY delivery_date, last_sku
ORDER BY last_sku, delivery_date 
;

