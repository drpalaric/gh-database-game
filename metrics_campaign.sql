--- Attributed Users who logged in today and this week

-- with dau as (
--     select aa.server_received_time::DATE as "date", count (distinct aa.device_id) as dau
--     from golfheroes.amplitude_analytics as aa
--     join global.users as u 
--     on aa.device_id = u.username
--     join golfheroes_v3.user_stats as us
--     on u.id = us.user_id
--     where 
--         aa.server_received_time > '2019-04-29' and 
--         aa.event_type = 'Core - App Open' and
--         us.affiliate_id = 'justin_bieber'
--     group by 1
-- ) 
-- select 
--     date, 
--     dau,
--     (select count(distinct aa.device_id) from golfheroes.amplitude_analytics as aa 
--     join global.users as u 
--     on aa.device_id = u.username
--     join golfheroes_v3.user_stats as us
--     on u.id = us.user_id
--     where aa.server_received_time::DATE between date - 7 * interval '1 day' and date and
--     aa.event_type = 'Core - App Open' and
--     us.affiliate_id = 'justin_bieber'
--     ) as wau
--     from dau

---- number of attributed users

select count(*) from golfheroes_v3.user_stats where affiliate_id = 'justin_bieber';

-- number of attributed users - individuals

select 
    us.user_id, 
    u.username as device_id,
    affiliate_id,
    campaign
from 
    golfheroes_v3.user_stats us
    join global.users u 
    on us.user_id = u.id
where affiliate_id = 'justin_bieber';


---- ads watched by attributed users

-- ad per user
select 
    us.user_id as "User ID",
    aa.event_type as "Ad Watched",
    count(aa.event_type)
from 
    golfheroes_v3.user_stats us 
    join global.users u
    on us.user_id = u.id
    join golfheroes.amplitude_analytics aa
    on u.username = aa.device_id
where 
    us.affiliate_id = 'justin_bieber' and 
    event_type in (
        'Ads - Player Watched Chest Bonus Loot Ad', 
        'Ads - Player Watched Chest Reduce Time Ad',
        'Ads - Player Watched Game Loss Ad',
        'Ads - Player Watched Wager Ad'
    )
group by
    us.user_id, aa.event_type;

-- users per ad 

select
    aa.event_type as "Ad Watched",
    count(aa.event_type) as "Total Times Watched"
from 
    golfheroes_v3.user_stats us 
    join global.users u
    on us.user_id = u.id
    join golfheroes.amplitude_analytics aa
    on u.username = aa.device_id
where 
    us.affiliate_id = 'justin_bieber' and 
    event_type in (
        'Ads - Player Watched Chest Bonus Loot Ad', 
        'Ads - Player Watched Chest Reduce Time Ad',
        'Ads - Player Watched Game Loss Ad',
        'Ads - Player Watched Wager Ad'
    )
group by 
    aa.event_type;

-- total ads watched
select 
    count(aa.event_type) as "Total Ads Watched"
from 
    golfheroes_v3.user_stats us 
    join global.users u
    on us.user_id = u.id
    join golfheroes.amplitude_analytics aa
    on u.username = aa.device_id
where 
    us.affiliate_id = 'justin_bieber' and 
    event_type in (
        'Ads - Player Watched Chest Bonus Loot Ad', 
        'Ads - Player Watched Chest Reduce Time Ad',
        'Ads - Player Watched Game Loss Ad',
        'Ads - Player Watched Wager Ad'
    );


---- number of attributed purchases 

-- by user

select 
    ubt.user_id as "User ID", 
    count(*) as "Total Purchases"
from 
    golfheroes_v3.user_bank_transactions ubt
    join golfheroes_v3.store_items si
    on ubt.store_items_id = si.id
    join golfheroes_v3.user_stats us
    on ubt.user_id =  us.user_id
where 
    us.affiliate_id = 'justin_bieber'
group by 
    ubt.user_id;

-- total

select 
    count(*) as "Total Attributed Purchases"
from 
    golfheroes_v3.user_bank_transactions ubt
    join golfheroes_v3.store_items si
    on ubt.store_items_id = si.id
    join golfheroes_v3.user_stats us
    on ubt.user_id =  us.user_id
where 
    us.affiliate_id = 'justin_bieber';

---- dollar value of attributed purchases

-- with users all transactions
select 
    ubt.id as "Transaction ID", 
    ubt.user_id as "User ID", 
    ubt.issuer as "Store", 
    ubt.store_items_id as "GH Store ID",
    si.cost_amount as "Cost of Item"
from 
    golfheroes_v3.user_bank_transactions ubt
    join golfheroes_v3.store_items si
    on ubt.store_items_id = si.id
    join golfheroes_v3.user_stats us
    on ubt.user_id =  us.user_id
where 
    us.affiliate_id = 'justin_bieber';

-- transactions per user

select 
    ubt.user_id as "User ID",
    count(*) as "Total # Purchases",
    sum(si.cost_amount)::numeric::money as "Total $ Per User"
from 
    golfheroes_v3.user_bank_transactions ubt
    join golfheroes_v3.store_items si
    on ubt.store_items_id = si.id
    join golfheroes_v3.user_stats us
    on ubt.user_id =  us.user_id
where 
    us.affiliate_id = 'justin_bieber'
group by 
    ubt.user_id;

-- transactions total 

select 
    sum(si.cost_amount)::numeric::money as "Total $ Overall"
from 
    golfheroes_v3.user_bank_transactions ubt
    join golfheroes_v3.store_items si
    on ubt.store_items_id = si.id
    join golfheroes_v3.user_stats us
    on ubt.user_id =  us.user_id
where 
    us.affiliate_id = 'justin_bieber';









Core - App Open
Core - App Close
store items with dollar amounts (1, 2,3, 4, 5, 6, 200, 201)
7289 | E6096233-D7B4-56AB-AD0E-274C59E29DFA