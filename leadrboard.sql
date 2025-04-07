with total_wins as (
    select winner_id,
    tour,
    count(winner_id) as total
    from golfheroes_v3.games
    group by winner_id, tour
)
select
    winner_id,
    tour,
    total,
    dense_rank() over (partition by tour order by total desc) as ranking
from 
    total_wins;

SELECT --udd.user_id,
    si.name,
    si.cost_amount,
    si.cost_type,
    si.item_type,
    si.rarity,
    si.item_id,
    si.item_quantity,
    --udd.date,
    --u.tour_level,
    i.legacy_id,
    --udd.store_id,
    --udd.purchased,
    --udd.coin_purchased,
    --udd.gem_purchased,
    si.coin_cost,
    si.gem_cost
FROM 
    golfheroes_v3.items i
    full JOIN golfheroes_v3.store_items si
    ON si.item_id = i.id
WHERE si.deleted IS NOT TRUE;

    JOIN golfheroes_v3.user_daily_deals udd
    ON udd.store_id = si.id
    JOIN golfheroes_v3.user_stats u
    ON u.user_id = udd.user_id
    WHERE si.deleted IS NOT TRUE;

--- list of user's deals for a single day

select 
    udd.user_id,
    si.name,
    si.cost_amount,
    si.cost_type,
    si.item_type,
    si.rarity,
    si.item_id,
    si.item_quantity,
    i.item_data,
    udd.date,
    u.tour_level,
    i.legacy_id,
    udd.store_id,
    udd.purchased,
    udd.coin_purchased,
    udd.gem_purchased,
    si.coin_cost,
    si.gem_cost
FROM golfheroes_v3.user_daily_deals udd
JOIN golfheroes_v3.store_items si
ON udd.store_id = si.id 
JOIN golfheroes_v3.user_stats u
ON udd.user_id = u.user_id
full outer JOIN golfheroes_v3.items i
ON i.id = si.item_id
where 
    udd.user_id = 243 AND
    si.deleted is not true AND
    udd.date = '2019-05-08';