--------------------------------------------------------------
-- tweets
--------------------------------------------------------------

--------------------------------------------------------------
-- создание партиционных таблиц. 
--   в каждую таблицу будут включены записей 
--   определённой даты
--------------------------------------------------------------

do $$
declare
    start_date timestamp;
    end_date timestamp;
begin
    for start_date in SELECT distinct date_trunc('month', posted_on) FROM tweets
    loop
	end_date = start_date + INTERVAL '1 month';
        execute format('CREATE TABLE tweets_p_%s ( like tweets including all )', to_char(start_date, 'MM_YYYY'));
        execute format('ALTER TABLE tweets_p_%s inherit tweets', to_char(start_date, 'MM_YYYY'));
        execute format('ALTER TABLE tweets_p_%s add constraint tweets_partitioning_check check ( posted_on >= ''%s''::date and posted_on < ''%s''::date )',to_char(start_date, 'MM_YYYY'), start_date, end_date);
    end loop;
end;
$$;

------------------------------------------------
-- создание триггера маршрутизатора
------------------------------------------------
create or replace function partition_for_tweets() returns trigger as $$
DECLARE
    v_parition_name text;
BEGIN
    v_parition_name := format( 'tweets_p_%s', to_char(NEW.posted_on, 'MM_YYYY'));
    execute 'INSERT INTO ' || v_parition_name || ' VALUES ( ($1).* )' USING NEW;
    return null;
END;
$$ language plpgsql;
 
create trigger partition_tweets before insert 
on tweets for each row execute procedure partition_for_tweets();

------------------------------------------------
-- создание пакетного файла
------------------------------------------------

\pset format unaligned
\pset tuples_only true
\o /tmp/run.tweets.migration.sql
SELECT
    format(
        'with x as (DELETE FROM ONLY tweets WHERE posted_on >= ''%s''::date and posted_on < ''%s''::date returning *) INSERT INTO tweets_p_%s SELECT * FROM x;',
        i.start_date,
        i.end_date,
        i.part_name
    )
FROM
    (SELECT distinct date_trunc('month', posted_on) as "start_date", date_trunc('month', posted_on) + INTERVAL '1 month' as "end_date", to_char(posted_on, 'MM_YYYY') part_name FROM tweets) i;
\o