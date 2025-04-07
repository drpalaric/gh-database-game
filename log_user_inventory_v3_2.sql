select golfheroes_v3.user_inventory_transactions_fn2 (243, 116, 1, 1);
select * from golfheroes_v3.user_inventory_log where user_id = 243 and item_id = 116;
select * from golfheroes_v3.user_inventory where item_id = 116 and user_id = 243;

create or replace function golfheroes_v3.user_inventory_transactions_fn (userid integer, itemid integer, item_amount integer, item_source text, item_level integer default 0)
    returns void as $$
DECLARE

    user_item_amount integer;

BEGIN

    IF EXISTS (select from golfheroes_v3.user_inventory_log where user_id = userid) THEN

        IF EXISTS (select from golfheroes_v3.user_inventory_log where user_id = userid and item_id = itemid) THEN

            -- if the user and the item already exists in the log, update the log with the new values for that item

                IF EXISTS (select from golfheroes_v3.items where id = itemid and is_unique is false)  THEN

                    insert into golfheroes_v3.user_inventory_log (user_id, item_id, previous_item_level, new_item_level, previous_amount, new_amount, transaction_kind, transaction_value, source)
                        with current_user_item as (
                            select 
                                user_id,
                                item_id,
                                previous_item_level,
                                new_item_level,
                                previous_amount,
                                new_amount
                            from golfheroes_v3.user_inventory_log
                            where user_id = userid and item_id = itemid
                            order by id desc
                            limit 1
                        )
                        select 
                            user_id,
                            item_id,
                            new_item_level as previous_item_level,
                            case 
                                when item_level < new_item_level
                                then new_item_level
                                when item_level > new_item_level
                                then item_level
                                when item_level = new_item_level
                                then item_level
                            end as new_item_level,
                            new_amount as previous_amount,
                            sum(new_amount + item_amount) as new_amount,
                            case 
                                when item_amount < 0
                                then 'DEBIT'
                                when item_amount > 0 
                                then 'CREDIT'
                                when item_amount = 0
                                then 'NO CHANGE'
                            end as transaction_kind,
                            item_amount as transaction_value,
                            item_source as source
                        from current_user_item
                        group by user_id, item_id, new_item_level, new_amount;
                
                ELSIF EXISTS (select from golfheroes_v3.items where id = itemid and is_unique is true) and item_amount <= 1 THEN 

                    select into user_item_amount amount from golfheroes_v3.user_inventory where user_id = userid and item_id = itemid;

                    CASE  
                        WHEN user_item_amount < 1 or item_amount < 1 THEN
                            
                            insert into golfheroes_v3.user_inventory_log (user_id, item_id, previous_item_level, new_item_level, previous_amount, new_amount, transaction_kind, transaction_value, source)
                                with current_user_item as (
                                    select 
                                        user_id,
                                        item_id,
                                        previous_item_level,
                                        new_item_level,
                                        previous_amount,
                                        new_amount
                                    from golfheroes_v3.user_inventory_log
                                    where user_id = userid and item_id = itemid
                                    order by id desc
                                    limit 1
                                )
                                select 
                                    user_id,
                                    item_id,
                                    new_item_level as previous_item_level,
                                    case 
                                        when item_level < new_item_level
                                        then new_item_level
                                        when item_level > new_item_level
                                        then item_level
                                        when item_level = new_item_level
                                        then item_level
                                    end as new_item_level,
                                    new_amount as previous_amount,
                                    sum(new_amount + item_amount) as new_amount,
                                    case 
                                        when item_amount < 0
                                        then 'DEBIT'
                                        when item_amount > 0 
                                        then 'CREDIT'
                                        when item_amount = 0
                                        then 'NO CHANGE'
                                    end as transaction_kind,
                                    item_amount as transaction_value,
                                    item_source as source
                                from current_user_item
                                group by user_id, item_id, new_item_level, new_amount;

                        WHEN user_item_amount = 1 THEN

                            RAISE EXCEPTION 'UNIQUE ITEM EXCEPTION - ITEM ALREADY EXISTS IN USER INVENTORY'; 
                        
                        ELSE 
                            
                            RAISE EXCEPTION 'UNIQUE ITEM EXCEPTION - CHECK IF THIS ITEM EXISTS FROM A PREVIOUS TRANSACTION BEFORE THE CODE CHANGE';

                    END CASE;

                ELSIF EXISTS (select from golfheroes_v3.items where id = itemid and is_unique is true) and item_amount > 1 THEN

                    RAISE EXCEPTION 'UNIQUE ITEM EXCEPTION - ITEM AMOUNT TO ADD WILL EXCEED MAXIMUM AMOUNT ALLOWED'; 

                END IF;

        ELSIF EXISTS (select from golfheroes_v3.items where id = itemid) THEN

            -- if the user doesn't exist in the log, but the item is in the inventory, add the user and the item to the log

            insert into golfheroes_v3.user_inventory_log 
            (user_id,   item_id,    previous_item_level,    new_item_level,     previous_amount,    new_amount,     transaction_kind,   transaction_value,  source)     values 
            (userid,    itemid,     0,                      0,                  0,                  0,              'CREATION',         0,                 'CREATION'), 
            (userid,    itemid,     0,                      item_level,         0,                  item_amount,    'CREDIT',           item_amount,       'CREATION');
            
        ELSE

            -- if the item doesn't exsit in the inventory, raise an exception

            RAISE EXCEPTION 'ITEM DOES NOT EXIST IN THE GAME INVENTORY';

        END IF;

    ELSE 

        -- Adding the default items for a user if they are not in the log
        -- using a CTE here to return the rows of each item that's been inserted

        with default_vals AS (
            insert into golfheroes_v3.user_inventory_log (user_id, item_id, previous_item_level, new_item_level, previous_amount, new_amount, transaction_kind, transaction_value, source)
            select 
                userid as user_id,
                item_id,
                0 as previous_item_level,
                0 as new_item_level,
                0 as previous_amount,
                0 as new_amount,
                'CREATION' as transaction_kind,
                0 as transaction_value,
                'CREATION' as source
            from golfheroes_v3.default_inventory RETURNING *

        )  
        -- Inserting a value of 1 for each of the deafult items after they've been created 
        -- using the CTE, we'll add a value of 1 for each item that's inserted

        insert into golfheroes_v3.user_inventory_log (user_id, item_id, previous_item_level, new_item_level, previous_amount, new_amount, transaction_kind, transaction_value, source)
            select 
                user_id,
                item_id,
                previous_item_level,
                item_level as new_item_level,
                previous_amount as new_amount,
                1 as new_amount,
                'CREDIT' as transaction_kind,
                1 as transaction_value,
                'CREATION' as source
            from default_vals;
    END IF;

END;
$$ LANGUAGE plpgsql;


-- After a row is inserted, the trigger will update the user's inventory
-- We'll assume that the item has already been added to the inventory

create or replace function golfheroes_v3.user_update_items_fn() 
returns trigger language plpgsql as $set_user_items$
begin

    IF EXISTS (select from golfheroes_v3.user_inventory where user_id = NEW.user_id) THEN

        IF EXISTS (select from golfheroes_v3.user_inventory where user_id = NEW.user_id and item_id = NEW.item_id) THEN

            update golfheroes_v3.user_inventory 
                set 
                    amount = NEW.new_amount, 
                    level = NEW.new_item_level 
            where 
                user_id = NEW.user_id and 
                item_id = NEW.item_id;
        
        ELSE 

            insert into golfheroes_v3.user_inventory (user_id, item_id, amount, level)
            values (NEW.user_id, NEW.item_id, NEW.new_amount, NEW.new_item_level);
        
        END IF;

    ELSE  

        insert into golfheroes_v3.user_inventory (user_id, item_id, amount, level)
        values (NEW.user_id, NEW.item_id, NEW.new_amount, NEW.new_item_level);

    END IF;

    RETURN NEW;
END;
$set_user_items$;

create trigger update_user_items_trigger_v3 after insert on golfheroes_v3.user_inventory_log
    for each row 
    execute procedure golfheroes_v3.user_update_items_fn();


----
insert into golfheroes_v3.user_inventory_log (user_id, item_id, previous_item_level, new_item_level, previous_amount, new_amount, transaction_kind, transaction_value)
select user_id, item_id, level as previous_item_level, level as new_item_level, amount as previous_amount, amount as new_amount, 'CREATION' as transaction_kind, 0 as transaction_value
from golfheroes_v3.user_inventory;

insert into golfheroes_v3.user_inventory         
(user_id, item_id, amount, level) 
select user_id, item_id, amount, level
from golfheroes_v3.user_inventory;