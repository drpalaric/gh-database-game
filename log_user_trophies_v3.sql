create table golfheroes_v3.user_trophy_transaction_log (
    id serial primary key not null,
    user_id int not null,
    previous_amount int not null,
    new_amount int not null, 
    amount_awarded int not null,
    tour_id int not null,
    created_at timestamp with time zone default transaction_timestamp(),
    transaction_kind text
);

create or replace function golfheroes_v3.user_trophy_transactions_fn (userid integer, trophy_amount integer, trophy_tour_id integer)
    returns void as $$
begin

    IF trophy_tour_id NOT IN (1, 2, 3) THEN
        RAISE EXCEPTION 'CANNOT HAVE A TOUR ID THAT DOES NOT EXIST';
    END IF;

    IF EXISTS (select from golfheroes_v3.user_trophy_transaction_log where user_id = userid) THEN
        insert into golfheroes_v3.user_trophy_transaction_log (user_id, previous_amount, new_amount, amount_awarded, tour_id, transaction_kind)
            with current_tour_stats as (
                select 
                    user_id,
                    previous_amount,
                    new_amount,
                    tour_id
                from golfheroes_v3.user_trophy_transaction_log
                where user_id = userid and tour_id = trophy_tour_id
                order by id desc
                limit 1
            ) 
            select
                user_id,
                new_amount as previous_amount,
                sum(new_amount + trophy_amount) as new_amount,
                trophy_amount as amount_awarded,
                trophy_tour_id as tour_id,
                case 
                    when trophy_amount = 0
                    then 'NO CHANGE'
                    when trophy_amount > 0
                    then 'AWARDED'
                    when trophy_amount < 0
                    then 'LOST'
                end as transaction_kind
            from current_tour_stats
            group by user_id, new_amount;
	ELSE 
        FOR tour_id_counter IN 1..3 LOOP
		    insert into golfheroes_v3.user_trophy_transaction_log (user_id, previous_amount, new_amount, amount_awarded, tour_id, transaction_kind)
		    values (userid, 0, 0, 0, tour_id_counter, 'CREATION');
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;

create or replace function golfheroes_v3.user_trophy_fn() returns trigger language plpgsql as $user_trophy_update_total$
begin
    if NEW.transaction_kind = 'AWARDED' or NEW.transaction_kind = 'LOST' then
        update golfheroes_v3.user_tour_stats set trophies = NEW.new_amount where user_id = NEW.user_id and tour_id = NEW.tour_id;
    end if;
	RETURN NEW;
end;
$user_trophy_update_total$;

create trigger user_trophy_trigger after insert on golfheroes_v3.user_trophy_transaction_log
    for each row execute procedure golfheroes_v3.user_trophy_fn();


insert into golfheroes_v3.user_trophy_transaction_log (user_id, previous_amount, new_amount, amount_awarded, tour_id, transaction_kind)
select user_id, trophies as previous_amount, trophies as new_amount, 0 as amount_awarded, tour_id, 'CREATION' as transaction_kind
from golfheroes_v3.user_tour_stats ;