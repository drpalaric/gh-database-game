--                                            Table "golfheroes_v3.store_items"
--      Column     |          Type           | Collation | Nullable |                       Default                        
-- ----------------+-------------------------+-----------+----------+------------------------------------------------------
--  id             | integer                 |           | not null | nextval('golfheroes_v3.store_item_id_seq'::regclass)
--  name           | text                    |           |          | 
--  reward_id      | integer                 |           |          | 
--  coins          | integer                 |           |          | 
--  gems           | integer                 |           |          | 
--  cost_amount    | double precision        |           |          | 
--  sku            | character varying(45)   |           |          | 
--  items          | integer[]               |           |          | 
--  apple_store_id | text                    |           |          | 
--  play_store_id  | text                    |           |          | 
--  tour_level     | integer                 |           |          | 
--  item_type      | golfheroes_v3.deal_type |           |          | 
--  cost_type      | golfheroes_v3.cost_type |           |          | 
--  rarity         | integer                 |           |          | 
--  item_id        | integer                 |           |          | 
--  item_quantity  | integer                 |           |          | 
--  deleted        | boolean                 |           |          | 
--  is_unique      | boolean                 |           |          | 
--  coin_cost      | integer                 |           | not null | 0
--  gem_cost       | integer                 |           | not null | 0
--  event_type     | text                    |           |          | 
--  tickets        | integer                 |           | not null | 0


create table golfheroes_v3.user_store_items_log (
    id serial primary key not null,
    user_id int not null,
    store_id int,
    reward_id int,
    coins int,
    gems int,
    coin_cost int,
    gem_cost int,
    cost_amount numeric,
    transaction_type text,
    transaction_kind text,
    created_at timestamp with time zone default transaction_timestamp()
);

create or replace function golfheroes_v3.user_store_items_log_fn (userid integer, storeid integer)
    returns void as $$
BEGIN

    


END;
$$ LANGUAGE plpgsql;

-- IF (select golfheroes_v3.store_items where item_type = 'BUNDLE' and id = storeid) THEN

    --     IF (select golfheroes_v3.store_items where item_type = 'BUNDLE' and id = storeid and items is not null) THEN

    --         insert into golfheroes_v3.user_store_items_log (user_id, store_id, name, cost, gems, coins, transaction_type, transaction_kind)
    --             select 
    --                 userid as user_id,
    --                 storeid as store_id,
    --                 name, 



    --     END IF;
    
    
    -- ELSIF (select golfheroes_v3.store_items where item_type = 'DAILY' and id = storeid) THEN



    -- ELSIF (select golfheroes_v3.store_items where item_type = 'GACHA' and id = storeid) THEN

    
    
    -- ELSIF (select golfheroes_v3.store_items where item_type = 'STATIC' and id = storeid) THEN



    -- ELSIF (select golfheroes_v3.store_items where item_type = 'WEEKLY' and id = storeid) THEN



    -- ELSE

    --     RAISE EXCEPTION 'ITEM TYPE NOT FOUND FOR THIS ITEM IN STORE ITEMS';

    -- END IF;