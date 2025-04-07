create table golfheroes_v3.user_gacha_log (
    id serial primary key,
    user_id int not null,
    previous_gacha_ticket jsonb,
    new_gacha_ticket jsonb,
    gacha_ticket_type text,
    gacha_event_type text,
    previous_gacha_amount int,
    new_gacha_amount int,
    transaction_amount int,
    created_at timestamp with time zone default transaction_timestamp(),
    transaction_type text
);


create or replace function golfheroes_v3.user_gatcha_log_fn (userid int, amount int, ticket_type text, event_type text) 
    returns void as $$

BEGIN
    
    IF EXISTS (select from golfheroes_v3.user_gacha_log where user_id = userid and gacha_ticket_type = ticket_type and gacha_event_type = event_type) THEN

        /***************

            If the function sees that there is a user, it has the ticket type, and also a gacha type,
            it updates the gacha amount. It finds the previous gacha and its amount then adds or subtracts
            whatever you pass in.

            Since you could have multiple events, it checks for the last time that event was logged, 
            then uses that for the previous amount and adds/subtracts on what you pass in.

        ***************/


        insert into golfheroes_v3.user_gacha_log (user_id, previous_gacha_ticket, new_gacha_ticket, gacha_ticket_type, gacha_event_type, previous_gacha_amount, new_gacha_amount, transaction_amount, transaction_type)
            with previous_gacha_transaction as (
                select
                    recent_log.user_id,
                    recent_log.new_gacha_ticket,
                    matching_event_log.gacha_ticket_type,
                    matching_event_log.gacha_event_type,
                    matching_event_log.new_gacha_amount
                from golfheroes_v3.user_gacha_log as recent_log 
                JOIN 
                    (
                        select
                            user_id, 
                            new_gacha_ticket,
                            gacha_ticket_type,
                            gacha_event_type,
                            new_gacha_amount
                        from golfheroes_v3.user_gacha_log
                        where
                            user_id = userid and
                            gacha_event_type = event_type and
                            gacha_ticket_type = ticket_type
                        order by id desc
                        limit 1
                    ) as matching_event_log
                ON recent_log.user_id = matching_event_log.user_id
                where 
                    recent_log.user_id = userid
                    order by recent_log.id desc
                    limit 1
            )
            select 
                user_id,
                new_gacha_ticket as previous_gacha_ticket,
                jsonb_set(new_gacha_ticket, concat('{' || gacha_ticket_type || ',' || gacha_event_type || ',amount}')::text[], concat(sum(new_gacha_amount + amount))::jsonb) as new_gacha_ticket,
                gacha_ticket_type,
                gacha_event_type,
                new_gacha_amount as previous_gacha_amount,
                sum(new_gacha_amount + amount) as new_gacha_amount,
                amount as transaction_amount,
                case 
                    when amount < 0
                    then 'DEBIT'
                    when amount > 0 
                    then 'CREDIT'
                    when amount = 0
                    then 'NO CHANGE'
                end as transaction_type
            from previous_gacha_transaction
            
            group by 
                user_id, 
                new_gacha_ticket, 
                gacha_ticket_type, 
                gacha_event_type, 
                new_gacha_amount, 
                transaction_amount;

    ELSIF EXISTS (select from golfheroes_v3.user_gacha_log where user_id = userid and gacha_ticket_type = ticket_type and gacha_event_type <> event_type) THEN

        /********

            Insert a new gacha event here --- 

            We can assume that there is another gacha already in place and that the ticket type already exists. 
            We insert the new gacha event type in the JSONB object with an amount of 0 for 'CREATION'.
            Then we add the amount 3 as the default amount to the new event.

            - We have to distinguist between 'NONEVENT' and other events because the default for 'NONEVENT' is 3,
              while for other events it's 0.
        
        *********/


        IF (event_type = 'NONEVENT') THEN

            /**************

                If the function passes in a NONEVENT, then this is first set to 0 on creation and then adds a value of 3
                for the default amount.

            **************/

            with creation_val as (
                
                insert into golfheroes_v3.user_gacha_log (user_id, previous_gacha_ticket, new_gacha_ticket, gacha_ticket_type, gacha_event_type, previous_gacha_amount, new_gacha_amount, transaction_amount, transaction_type)
                    select
                        user_id,
                        new_gacha_ticket as previous_gacha_ticket,
                        jsonb_insert(new_gacha_ticket, concat('{' || ticket_type || ',' || event_type || '}')::text[], jsonb_build_object('amount', 0)) as new_gacha_ticket,
                        ticket_type as gacha_ticket_type,
                        event_type as gacha_event_type,
                        0 as previous_gacha_amount,
                        0 as new_gacha_amount,
                        0 as transaction_amount,
                        'CREATION' as transaction_type
                    from golfheroes_v3.user_gacha_log
                    where 
                        user_id = userid
                    order by id desc
                    limit 1
                    RETURNING *

            )

            insert into golfheroes_v3.user_gacha_log (user_id, previous_gacha_ticket, new_gacha_ticket, gacha_ticket_type, gacha_event_type, previous_gacha_amount, new_gacha_amount, transaction_amount, transaction_type)
                select 
                    user_id,
                    new_gacha_ticket as previous_gacha_ticket,
                    jsonb_set(new_gacha_ticket, concat('{' || gacha_ticket_type || ',' || gacha_event_type || ',amount}')::text[], concat(sum(new_gacha_amount + 3))::jsonb) as new_gacha_ticket,
                    gacha_ticket_type,
                    gacha_event_type,
                    new_gacha_amount as previous_gacha_amount,
                    sum(new_gacha_amount + 3) as new_gacha_amount,
                    3 as transaction_amount,
                    'CREDIT' as transaction_type
                from creation_val
                group by 
                    user_id, 
                    previous_gacha_ticket, 
                    new_gacha_ticket, 
                    gacha_ticket_type, 
                    gacha_event_type, 
                    new_gacha_amount, 
                    transaction_amount;

        ELSE  

            /**************

                If the function passes in anything other than NONEVENT, then this is first set to 0 on creation. No other amount is 
                given here. If you want to update the amount, you'll need to run the function again and add an amount.

            **************/

            insert into golfheroes_v3.user_gacha_log (user_id, previous_gacha_ticket, new_gacha_ticket, gacha_ticket_type, gacha_event_type, previous_gacha_amount, new_gacha_amount, transaction_amount, transaction_type)
                select
                    user_id,
                    new_gacha_ticket as previous_gacha_ticket,
                    jsonb_insert(new_gacha_ticket, concat('{' || ticket_type || ',' || event_type || '}')::text[], jsonb_build_object('amount', 0)) as new_gacha_ticket,
                    ticket_type as gacha_ticket_type,
                    event_type as gacha_event_type,
                    0 as previous_gacha_amount,
                    0 as new_gacha_amount,
                    0 as transaction_amount,
                    'CREATION' as transaction_type
                from golfheroes_v3.user_gacha_log
                where 
                    user_id = userid
                order by id desc
                limit 1;
        END IF;


    ELSIF EXISTS (select from golfheroes_v3.user_gacha_log where user_id = userid and gacha_ticket_type <> ticket_type) THEN

         /********

            Insert a new gacha ticket here --- 

            We can assume that there is another gacha already in place and that the ticket type does not exist. 
            We insert the new gacha ticket along with a new type in the JSONB object with an amount of 0 for 'CREATION'.
            Then we add the amount 3 as the default amount to the new event.
        
        *********/

        IF (event_type = 'NONEVENT') THEN

            /**************

                If the function passes in a NONEVENT, then this is first set to 0 on creation and then adds a value of 3
                for the default amount.

            **************/

            with creation_val as (

                insert into golfheroes_v3.user_gacha_log (user_id, previous_gacha_ticket, new_gacha_ticket, gacha_ticket_type, gacha_event_type, previous_gacha_amount, new_gacha_amount, transaction_amount, transaction_type)
                    select
                        user_id,
                        new_gacha_ticket as previous_gacha_ticket,
                        jsonb_insert(new_gacha_ticket, concat('{' || ticket_type || '}')::text[], jsonb_build_object(event_type, jsonb_build_object('amount', 0))) as new_gacha_ticket,
                        ticket_type as gacha_ticket_type,
                        event_type as gacha_event_type,
                        0 as previous_gacha_amount,
                        0 as new_gacha_amount,
                        0 as transaction_amount,
                        'CREATION' as transaction_type
                    from golfheroes_v3.user_gacha_log
                    where 
                        user_id = userid
                    order by id desc
                    limit 1
                    RETURNING *

            )

            insert into golfheroes_v3.user_gacha_log (user_id, previous_gacha_ticket, new_gacha_ticket, gacha_ticket_type, gacha_event_type, previous_gacha_amount, new_gacha_amount, transaction_amount, transaction_type)
                select 
                    user_id,
                    new_gacha_ticket as previous_gacha_ticket,
                    jsonb_set(new_gacha_ticket, concat('{' || gacha_ticket_type || ',' || gacha_event_type || ',amount}')::text[], concat(sum(new_gacha_amount + 3))::jsonb) as new_gacha_ticket,
                    gacha_ticket_type,
                    gacha_event_type,
                    new_gacha_amount as previous_gacha_amount,
                    sum(new_gacha_amount + 3) as new_gacha_amount,
                    3 as transaction_amount,
                    'CREDIT' as transaction_type
                from creation_val
                group by 
                    user_id, 
                    previous_gacha_ticket, 
                    new_gacha_ticket, 
                    gacha_ticket_type, 
                    gacha_event_type, 
                    new_gacha_amount, 
                    transaction_amount;

        ELSE 

             /**************

                If the function passes in anything other than NONEVENT, then this is first set to 0 on creation. No other amount is 
                given here. If you want to update the amount, you'll need to run the function again and add an amount.

            **************/

            insert into golfheroes_v3.user_gacha_log (user_id, previous_gacha_ticket, new_gacha_ticket, gacha_ticket_type, gacha_event_type, previous_gacha_amount, new_gacha_amount, transaction_amount, transaction_type)
                select
                    user_id,
                    new_gacha_ticket as previous_gacha_ticket,
                    jsonb_insert(new_gacha_ticket, concat('{' || ticket_type || '}')::text[], jsonb_build_object(event_type, jsonb_build_object('amount', 0))) as new_gacha_ticket,
                    ticket_type as gacha_ticket_type,
                    event_type as gacha_event_type,
                    0 as previous_gacha_amount,
                    0 as new_gacha_amount,
                    0 as transaction_amount,
                    'CREATION' as transaction_type
                from golfheroes_v3.user_gacha_log
                where 
                    user_id = userid
                order by id desc
                limit 1;
        END IF;


    ELSIF NOT EXISTS (select from golfheroes_v3.user_gacha_log where user_id = userid) THEN

        /********

            This will run when a player is created for the first time. It's suppose to run when the
            initial CTE creates the player ID.

        *********/


        insert into golfheroes_v3.user_gacha_log (user_id, previous_gacha_ticket, new_gacha_ticket, gacha_ticket_type, gacha_event_type, previous_gacha_amount, new_gacha_amount, transaction_amount, transaction_type)
            values
        (
            userid, 
            '{"regular": {"NONEVENT": {"amount": 0}}}'::jsonb, 
            '{"regular": {"NONEVENT": {"amount": 0}}}'::jsonb,
            'regular',
            'NONEVENT',
            0,
            0,
            0,
            'CREATION'
        ), 
        (
            userid,
            '{"regular": {"NONEVENT": {"amount": 0}}}'::jsonb, 
            '{"regular": {"NONEVENT": {"amount": 3}}}'::jsonb,
            'regular',
            'NONEVENT',
            0,
            3,
            3,
            'CREDIT'
        );

    END IF;
END;
$$ LANGUAGE plpgsql;


create or replace function golfheroes_v3.user_update_gacha_fn() 
returns trigger language plpgsql as $set_user_gacha$

BEGIN

    update golfheroes_v3.user_bank 
        set gacha_tickets = NEW.new_gacha_ticket
    where 
        user_id = NEW.user_id;

    RETURN NEW;
END;
$set_user_gacha$;

create trigger user_gacha_trigger after insert on golfheroes_v3.user_gacha_log
    for each row execute procedure golfheroes_v3.user_update_gacha_fn();




/********************************************************/


-- select jsonb_insert('{"t": {"TEST": {"amount": 5}, "hello": {"amount": 3}}}', concat('{' || 'new' || '}')::text[], jsonb_build_object('thing', jsonb_build_object('amount', 0)));

-- jsonb_set('{"t": {"TEST": {"amount": 5}, "hello": {"amount": 3}}}', concat('{' || 't' || ',' || 'hello' || ',' || 'amount' || '}'), '4', false)
--  jsonb_set('{"t": {"TEST": {"amount": 5}, "hello": {"amount": 3}}}, concat('{' || 't' || ',' || 'hello' || ',amount}')::text[], sum(0 + 3)) as new_gacha_ticket,

-- data example
-- {"regular": {"NONEVENT": {"amount": 2}}}

-- insert data

insert into golfheroes_v3.user_gacha_log (user_id, previous_gacha_ticket, new_gacha_ticket, gacha_ticket_type, gacha_event_type, previous_gacha_amount, new_gacha_amount, transaction_amount, transaction_type)
select 
    user_id,
    gacha_tickets as previous_gacha_ticket,
    gacha_tickets as new_gacha_ticket,
    'regular' as gacha_ticket_type,
    'NONEVENT' as gacha_event_type,
    (gacha_tickets -> 'regular' ->  'NONEVENT' ->> 'amount')::int as previous_gacha_amount, 
    (gacha_tickets -> 'regular' ->  'NONEVENT' ->> 'amount')::int as new_gacha_amount,
    0 as transaction_amount,
    'CREATION' as transaction_type
from golfheroes_v3.user_bank where user_id = 243;

insert into golfheroes_v3.user_gacha_log (user_id, previous_gacha_ticket, new_gacha_ticket, gacha_ticket_type, gacha_event_type, previous_gacha_amount, new_gacha_amount, transaction_amount, transaction_type)
select 
    user_id,
    gacha_tickets as previous_gacha_ticket,
    jsonb_build_object('regular', json_build_object('NONEVENT', json_build_object('amount', 9))) as new_gacha_ticket,
    'regular' as gacha_ticket_type,
    'NONEVENT' as gacha_event_type,
    8 as previous_gacha_amount, 
    9 as new_gacha_amount,
    1 as transaction_amount, 
    'CREDIT' as transaction_type
from golfheroes_v3.user_bank where user_id = 243;

-- {
--     "regular": {
--         "NONEVENT": {
--             "amount": 3 -- default
--         },
        -- "EVENT1": {
        --     "amount": 0
        -- }
--     }
-- }

-- store items

-- golfheroes tour level 1, 2, 3 - 

select * from golfheroes_v3.user_gacha_log;

select golfheroes_v3.user_gatcha_log_fn (243, 1, 'regular', 'NONEVENT');

