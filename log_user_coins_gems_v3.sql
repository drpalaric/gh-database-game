-- assumes when a user is created, they have their first transaction added with default coin amounts

create or replace function golfheroes_v3.user_transactions_fn (userid integer, transaction_amount integer, transaction_type text)
    returns void as $$
BEGIN
    IF EXISTS (select from golfheroes_v3.user_transaction_log where currency_type = transaction_type and user_id = userid)  then
        insert into golfheroes_v3.user_transaction_log (user_id, previous_amount, new_amount, currency_type, transaction_kind, transaction_value)
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
                transaction_amount as transaction_value
            from previous_transaction
            group by user_id, new_amount, currency_type;
	ELSE 
		insert into golfheroes_v3.user_transaction_log (user_id, previous_amount, new_amount, currency_type, transaction_kind, transaction_value)
		values (userid, 0, 0, transaction_type, 'CREATION', 0);
    END IF;
END;
$$ LANGUAGE plpgsql;

create or replace function golfheroes_v3.user_bank_fn() returns trigger language plpgsql as $user_bank_update_total$
begin
    if NEW.currency_type = 'COINS' then
        update golfheroes_v3.user_bank set coin_currency = NEW.new_amount where user_id = NEW.user_id;
    elsif NEW.currency_type = 'GEMS' then
         update golfheroes_v3.user_bank set gem_currency = NEW.new_amount where user_id = NEW.user_id;
    end if;
	RETURN NEW;
end;
$user_bank_update_total$;

create trigger user_bank_trigger after insert on golfheroes_v3.user_transaction_log
    for each row execute procedure golfheroes_v3.user_bank_fn();

insert into golfheroes_v3.user_transaction_log
(user_id, previous_amount, new_amount, currency_type, transaction_kind, transaction_value) 
select user_id, coin_currency as previous_amount, coin_currency as new_amount, 'COINS' as currency_type, 'CREATION-V2' as transaction_kind, 0 as transaction_value from 
golfheroes_v3.user_bank;