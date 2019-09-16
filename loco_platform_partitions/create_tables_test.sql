CREATE SEQUENCE public.locousers_ids_locouser_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE public.locousers_ids_locouser_id_seq
  OWNER TO postgres;

CREATE TABLE public.locousers_ids
(
  locouser_id integer NOT NULL DEFAULT nextval('locousers_ids_locouser_id_seq'::regclass),
  sourceuser_id text,
  country_code character(10),
  CONSTRAINT pk_locousers_ids PRIMARY KEY (locouser_id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE public.locousers_ids
  OWNER TO postgres;

CREATE TABLE public.profiles
(
  category integer NOT NULL,
  score1 double precision,
  score2 double precision,
  score3 double precision,
  score4 double precision,
  period_id integer NOT NULL,
  user_id bigint NOT NULL,
  scoresum double precision,
  locouser_id bigint NOT NULL,
  CONSTRAINT pk_profiles PRIMARY KEY (locouser_id, category, period_id),
  CONSTRAINT fk_locousers_id FOREIGN KEY (locouser_id)
      REFERENCES public.locousers_ids (locouser_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE,
  autovacuum_enabled=true
);
ALTER TABLE public.profiles
  OWNER TO postgres;

create index inx_category_profiles on public.profiles (category);  
create index inx_locouser_id_profiles on public.profiles (locouser_id);  
create index inx_period_category_id_profiles on public.profiles (period_id, category);  

CREATE SEQUENCE public.new_grid_500_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 421554
  CACHE 1;
ALTER TABLE public.new_grid_500_seq
  OWNER TO postgres;

CREATE TABLE public.grid_500_uk_new
(
  gid integer NOT NULL DEFAULT nextval('new_grid_500_seq'::regclass),
  geom geometry(Polygon,4326),
  "long" double precision,
  lat double precision,
  CONSTRAINT pk_new_grid_500_uk PRIMARY KEY (gid)
)
WITH (
  OIDS=FALSE,
  autovacuum_enabled=true
);
ALTER TABLE public.grid_500_uk_new
  OWNER TO postgres;

CREATE TABLE public.tweets
(
  gid integer NOT NULL,
  tweet_id bigint NOT NULL,
  user_id bigint,
  posted_on timestamp without time zone, -- The timestamp value from the sourse
  posted_on_hour integer, -- The hour is recalculated in accordance with GMT
  posted_on_dow integer, -- The dow is recalculated in accordance with GMT
  keywords text,
  keywords_count integer,
  locouser_id bigint,
  posted_on_date date, -- The date is recalculated in accordance with GMT
  CONSTRAINT pk_tweets PRIMARY KEY (tweet_id),
  CONSTRAINT fk_gid FOREIGN KEY (gid)
      REFERENCES public.grid_500_uk_new (gid) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT fk_locouser_id FOREIGN KEY (locouser_id)
      REFERENCES public.locousers_ids (locouser_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE,
  autovacuum_enabled=true
);
ALTER TABLE public.tweets
  OWNER TO postgres;

copy profiles from '/tmp/categ_test.csv' CSV;
copy tweets from '/tmp/tweets_test.csv' CSV;
copy locousers_ids from '/tmp/tweets_test.csv' CSV;
