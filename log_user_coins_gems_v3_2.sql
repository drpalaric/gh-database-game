-- assumes when a user is created, they have their first transaction added with default coin amounts

create or replace function golfheroes.user_transactions_fn (userid integer, transaction_amount integer, transaction_type text, transaction_source text)
    returns void as $$
BEGIN
    IF EXISTS (select from golfheroes.user_transaction_log where currency_type = transaction_type and user_id = userid)  then
        insert into golfheroes.user_transaction_log (user_id, previous_amount, new_amount, currency_type, transaction_kind, transaction_value, source)
            with previous_transaction as (
                select
                    user_id,
                    previous_amount,
                    new_amount,
                    currency_type
                from golfheroes.user_transaction_log 
                where user_id = userid and currency_type = transaction_type
                order by id desc
                limit 1
            )
            select 
                user_id, 
                new_amount as previous_amount, 
                sum(new_amount + transaction_amount) as new_amount, 
                currency_type,
                case 
                    when transaction_amount < 0
                    then 'DEBIT'
                    when transaction_amount > 0 
                    then 'CREDIT'
                    when transaction_amount = 0
                    then 'NO CHANGE'
                end as transaction_kind,
                transaction_amount as transaction_value,
                transaction_source as source
            from previous_transaction
            group by user_id, new_amount, currency_type;
	ELSE 
		insert into golfheroes.user_transaction_log (user_id, previous_amount, new_amount, currency_type, transaction_kind, transaction_value, source)
		values (userid, 0, 0, transaction_type, 'CREATION', 0, 'CREATION');
    END IF;
END;
$$ LANGUAGE plpgsql;

create or replace function golfheroes.user_bank_fn() returns trigger language plpgsql as $user_bank_update_total$
begin
    if NEW.currency_type = 'COINS' then
        update golfheroes.user_bank set coin_currency = NEW.new_amount where user_id = NEW.user_id;
    elsif NEW.currency_type = 'GEMS' then
         update golfheroes.user_bank set gem_currency = NEW.new_amount where user_id = NEW.user_id;
    end if;
	RETURN NEW;
end;
$user_bank_update_total$;

create trigger user_bank_trigger after insert on golfheroes.user_transaction_log
    for each row execute procedure golfheroes.user_bank_fn();



/************************** create a bank account if they don't have one **********************************/

create or replace function golfheroes_v3.user_transactions_fn3 (userid integer, transaction_amount integer, transaction_type text, transaction_source text)
    returns void as $$
BEGIN

    IF EXISTS (select from golfheroes_v3.user_bank where user_id = userid) then

        IF EXISTS (select from golfheroes_v3.user_transaction_log where currency_type = transaction_type and user_id = userid)  then
            insert into golfheroes_v3.user_transaction_log (user_id, previous_amount, new_amount, currency_type, transaction_kind, transaction_value, source)
                with previous_transaction as (
                    select
                        user_id,
                        previous_amount,
                        new_amount,
                        currency_type
                    from golfheroes_v3.user_transaction_log 
                    where user_id = userid and currency_type = transaction_type
                    order by id desc
                    limit 1
                )
                select 
                    user_id, 
                    new_amount as previous_amount, 
                    sum(new_amount + transaction_amount) as new_amount, 
                    currency_type,
                    case 
                        when transaction_amount < 0
                        then 'DEBIT'
                        when transaction_amount > 0 
                        then 'CREDIT'
                        when transaction_amount = 0
                        then 'NO CHANGE'
                    end as transaction_kind,
                    transaction_amount as transaction_value,
                    transaction_source as source
                from previous_transaction
                group by user_id, new_amount, currency_type;
        ELSE 
            insert into golfheroes_v3.user_transaction_log (user_id, previous_amount, new_amount, currency_type, transaction_kind, transaction_value, source)
            values (userid, 0, 0, transaction_type, 'CREATION', 0, 'CREATION');
        END IF;
    
    ELSIF EXISTS (select from golfheroes.user_bank where user_id = userid) THEN

        with new_user as(
            select id from global.users where id = userid
            returning *
        ), us as(
            insert into golfheroes_v3.user_stats(user_id, trophy_level, tour_level, max_trophy_level, is_dev)
                select user_id, trophy_level, tour_level, max_trophy_level, is_dev
                from golfheroes.user_stats where user_id = new_user.id
        ), ui as (
            insert into golfheroes_v3.user_inventory(user_id, level, amount, item_id) 
                select user_id, level, amount, item_id 
                from golfheroes.user_inventory where user_id = new_user.id
        ), uts as (
            insert into golfheroes_v3.user_tour_stats(user_id, tour_id, wins, losses, trophies, first_unlock) 
                select user_id, tour_id, wins, losses, trophies, first_unlock 
                from golfheroes.user_tour_stats where user_id = new_user.id
        ), up as (
            insert into golfheroes_v3.user_profile(user_id)
                select user_id from golfheroes.user_profile where user_id = new_user.id
        ), uq as (
            insert into golfheroes_v3.user_quests(user_id)
                select user_id from golfheroes.user_quests where user_id = new_user.id
        ), uc as (      
            insert into golfheroes_v3.user_chests(user_id)
                select user_id from golfheroes.user_chests where user_id = new_user.id
        ) 
        insert into golfheroes_v3.user_bank(user_id, coin_currency, gem_currency, gacha_tickets)
            select user_id, coin_currency, gem_currency, gacha_tickets from golfheroes.user_bank where user_id = new_user.id;

        insert into golfheroes_v3.user_transaction_log (user_id, previous_amount, new_amount, currency_type, transaction_kind, transaction_value, source)
            select 
                user_id, 
                previous_amount, 
                new_amount, 
                currency_type, 
                'CREATED - V2' as transaction_kind, 
                transaction_value,
                'TRANSFERED - V2' as source
            from golfheroes.user_transaction_log
            where 
                user_id = userid and 
                transaction_kind = transaction_type
            order by created_at desc
            limit 1;

        insert into golfheroes_v3.user_transaction_log (user_id, previous_amount, new_amount, currency_type, transaction_kind, transaction_value, source)
           with previous_transaction as (
                    select
                        user_id,
                        previous_amount,
                        new_amount,
                        currency_type
                    from golfheroes_v3.user_transaction_log 
                    where user_id = userid and currency_type = transaction_type
                    order by id desc
                    limit 1
                )
                select 
                    user_id, 
                    new_amount as previous_amount, 
                    sum(new_amount + transaction_amount) as new_amount, 
                    currency_type,
                    case 
                        when transaction_amount < 0
                        then 'DEBIT'
                        when transaction_amount > 0 
                        then 'CREDIT'
                        when transaction_amount = 0
                        then 'NO CHANGE'
                    end as transaction_kind,
                    transaction_amount as transaction_value,
                    transaction_source as source
                from previous_transaction
                group by user_id, new_amount, currency_type;

    ELSE 

        RAISE EXCEPTION 'NO BANK ACCT IN V2 OR V3 - CHECK IF USER HAS BEEN CREATED.';

    END IF;

END;
$$ LANGUAGE plpgsql;

