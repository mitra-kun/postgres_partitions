-- alter table profiles drop CONSTRAINT fk_locousers_id;
-- alter table tweets drop CONSTRAINT fk_gid;
-- alter table tweets drop CONSTRAINT fk_locouser_id;

--------------------------------------------------------------
-- profiles
--------------------------------------------------------------

--------------------------------------------------------------
-- создание партиционных таблиц. 
--   в каждую таблицу будут включены записей 
--   определённой категории
--------------------------------------------------------------

do $$
declare
    i int4;
begin
    for i in SELECT distinct category FROM profiles
    loop
        execute format('CREATE TABLE profiles_p_%s ( like profiles including all )', i );
        execute format('ALTER TABLE profiles_p_%s inherit profiles', i);
        execute format('ALTER TABLE profiles_p_%s add constraint profiles_partitioning_check check ( category = %s )', i, i);
    end loop;
end;
$$;

------------------------------------------------
-- создание триггера маршрутизатора
------------------------------------------------
create or replace function partition_for_profiles() returns trigger as $$
DECLARE
    v_parition_name text;
BEGIN
    v_parition_name := format( 'profiles_p_%s', NEW.category );
    execute 'INSERT INTO ' || v_parition_name || ' VALUES ( ($1).* )' USING NEW;
    return NULL;
END;
$$ language plpgsql;
 
create trigger partition_profiles before insert 
on profiles for each row execute procedure partition_for_profiles();

------------------------------------------------
-- создание пакетного файла
------------------------------------------------

\pset format unaligned
\pset tuples_only true
\o /tmp/run.profiles.migration.sql
SELECT
    format(
        'with x as (DELETE FROM ONLY profiles WHERE category = %s returning *) INSERT INTO profiles_p_%s SELECT * FROM x;',
        i.category,
        i.category
    )
FROM
    (SELECT distinct category FROM profiles) i;
\o