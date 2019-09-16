--------------------------------------------------------------
-- user_signals
--------------------------------------------------------------
--------------------------------------------------------------
-- создание партиционных таблиц. 
--   в каждую таблицу будут включены записей 
--   определённого периода
--------------------------------------------------------------

do $$
declare
    i int4;
begin
    for i in SELECT distinct period FROM user_signals
    loop
        execute format('CREATE TABLE user_signals_p_%s ( like user_signals including all )', i );
        execute format('ALTER TABLE user_signals_p_%s inherit user_signals', i);
        execute format('ALTER TABLE user_signals_p_%s add constraint user_signals_partitioning_check check ( period = %s )', i, i);
    end loop;
end;
$$;

------------------------------------------------
-- создание триггера маршрутизатора
------------------------------------------------
create or replace function partition_for_user_signals() returns trigger as $$
DECLARE
    v_parition_name text;
BEGIN
    v_parition_name := format( 'user_signals_p_%s', NEW.period );
    execute 'INSERT INTO ' || v_parition_name || ' VALUES ( ($1).* )' USING NEW;
    return NULL;
END;
$$ language plpgsql;
 
create trigger partition_user_signals before insert 
on user_signals for each row execute procedure partition_for_user_signals();

------------------------------------------------
-- создание пакетного файла
------------------------------------------------

\pset format unaligned
\pset tuples_only true
\o /tmp/run.user_signals.migration.sql
SELECT
    format(
        'with x as (DELETE FROM ONLY user_signals WHERE period = %s returning *) INSERT INTO user_signals_p_%s SELECT * FROM x;',
        i.period,
        i.period
    )
FROM
    (SELECT distinct period FROM user_signals) i;
\o