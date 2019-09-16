-- пример разработан на базе статьи https://habrahabr.ru/post/273933/
------------------------------------------------

------------------------------------------------
-- создание функции для генерации рандомной строки
------------------------------------------------
create or replace function random_string(length integer) returns text as 
$$
declare
  chars text[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
  result text := '';
  i integer := 0;
begin
  if length < 0 then
    raise exception 'Given length cannot be less than 0';
  end if;
  for i in 1..length loop
    result := result || chars[1+random()*(array_length(chars, 1)-1)];
  end loop;
  return result;
end;
$$ language plpgsql;

------------------------------------------------
-- создание экспериментальной таблицы
------------------------------------------------
create tablespace dbspace LOCATION 'D:\postgres';

create table users (
    id             serial primary key,
    username       text not null unique,
    password       text,
    created_on     timestamptz not null,
    last_logged_on timestamptz not null
) TABLESPACE dbspace;

------------------------------------------------
-- Вставка тестовых данных
------------------------------------------------
insert into users (username, password, created_on, last_logged_on)
    select
        random_string( (random() * 4 + 5)::int4),
        random_string( 20 ),
        now() - '2 years'::interval * random(),
        now() - '2 years'::interval * random()
    from
        generate_series(1, 100000);

create index newest_users on users (created_on);

------------------------------------------------
-- test
------------------------------------------------
-- select max(id) from users;

------------------------------------------------
-- создание партиционных таблиц. 
--   в каждую таблицу будет включено 10000 записей
------------------------------------------------

do $$
declare
    i int4;
    id_min INT4;
    id_max INT4;
begin
    for i in 1..10
    loop
        id_min := (i - 1) * 10000 + 1;
        id_max := i * 10000;
        execute format('CREATE TABLE users_p_%s ( like users including all )', i );
        execute format('ALTER TABLE users_p_%s inherit users', i);
        execute format('ALTER TABLE users_p_%s add constraint partitioning_check check ( id >= %s AND id <= %s )', i, id_min, id_max );
    end loop;
end;
$$;

------------------------------------------------
-- test плана выполнения
------------------------------------------------
--explain analyze select * from users where id = 123;


------------------------------------------------
-- создание триггера маршрутизатора
------------------------------------------------
create or replace function partition_for_users() returns trigger as $$
DECLARE
    v_parition_name text;
BEGIN
    v_parition_name := format( 'users_p_%s', 1 + ( NEW.id - 1 ) / 10000 );
    execute 'INSERT INTO ' || v_parition_name || ' VALUES ( ($1).* )' USING NEW;
    return NULL;
END;
$$ language plpgsql;
 
create trigger partition_users before insert on users for each row execute procedure partition_for_users();

------------------------------------------------
-- создание пакетного файла
------------------------------------------------

\pset format unaligned
\pset tuples_only true
\o /tmp/run.batch.migration.sql
SELECT
    format(
        'with x as (DELETE FROM ONLY users WHERE id >= %s AND id <= %s returning *) INSERT INTO users_p_%s SELECT * FROM x;',
        i,
        i + 999,
        ( i - 1 ) / 10000 + 1
    )
FROM
    generate_series( 1, 100000, 1000 ) i;
\o

------------------------------------------------
-- Далее для партиционирования 
--   запускается в отдельном потоке
--   скрипт /tmp/run.batch.migration.sql
------------------------------------------------

------------------------------------------------
-- После работы скрипта необходимо 
--   очистить родительсткую таблицу
--   если вакуум до неё не добрался 
--   выполнив скрипт
------------------------------------------------
-- truncate only users;
