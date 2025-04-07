create table golfheroes.user_chests_transaction_log (
    id serial primary key not null,
    user_id int not null,
    previous_amount int not null,
    new_amount int not null, 
    chest_id int not null,
    slot_number int not null,
    created_at timestamp with time zone default transaction_timestamp(),
    transaction_kind text
);

