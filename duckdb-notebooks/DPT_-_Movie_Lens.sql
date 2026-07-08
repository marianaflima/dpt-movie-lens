
--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

INSTALL httpfs;
LOAD httpfs;

SET s3_endpoint = 'localhost:9000';
SET s3_access_key_id = 'minioadmin';
SET s3_secret_access_key = 'minioadmin123';
SET s3_use_ssl = false;
SET s3_url_style='path';

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW bronze.elicitations AS SELECT * FROM read_csv(
  's3://movie-lens/raw/movie_elicitation_set.csv',
  types = {
    'tstamp':'VARCHAR',
    'source':'VARCHAR',
    'month_idx':'VARCHAR',
    'movieId':'VARCHAR',
  }
);
SELECT * FROM bronze.elicitations LIMIT 5;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW bronze.movies AS SELECT * FROM read_csv(
  's3://movie-lens/raw/movies.csv',
   types = {
    'genres':'VARCHAR',
    'title':'VARCHAR',
    'movieId':'VARCHAR',
  } 
);
SELECT * FROM bronze.movies LIMIT 5;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW bronze.recommendations AS SELECT * FROM read_csv(
  's3://movie-lens/raw/user_recommendation_history.csv',
  types = {
    'predictedRating':'VARCHAR',
    'tstamp':'VARCHAR',
    'movieId':'VARCHAR',
    'userId':'VARCHAR',
  }
);
SELECT * FROM bronze.recommendations LIMIT 5;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW bronze.ratings AS SELECT * FROM read_csv(
    's3://movie-lens/raw/user_rating_history.csv',
    types = {
      'rating': 'VARCHAR',
      'tstamp':'VARCHAR',
      'movieId':'VARCHAR',
      'userId':'VARCHAR',
    }
);
SELECT * FROM bronze.ratings LIMIT 5;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW bronze.additional_ratings AS SELECT * FROM read_csv(
  's3://movie-lens/raw/ratings_for_additional_users.csv', 
  types = {
    'rating': 'VARCHAR',
    'tstamp':'VARCHAR',
    'movieId':'VARCHAR',
    'userId':'VARCHAR',
  }
);
SELECT * FROM bronze.additional_ratings LIMIT 5;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW bronze.beliefs AS SELECT * FROM read_csv(
  's3://movie-lens/raw/belief_data.csv',
  types = {
      'systemPredictRating': 'VARCHAR',
      'userCertainty': 'VARCHAR',
      'userElicitRating': 'VARCHAR',
      'tstamp':'VARCHAR',
      'movieId':'VARCHAR',
      'userId':'VARCHAR',
      'source': 'VARCHAR',
      'watchDate':'VARCHAR',
      'movie_idx':'VARCHAR',
      'isSeen':'VARCHAR',
    }
);
SELECT * FROM bronze.beliefs LIMIT 5;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

SELECT view_name FROM duckdb_views;


--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE TABLE silver.dim_movies (
  movieId VARCHAR,
  titulo VARCHAR,
  generos VARCHAR,
  ano_lancamento INTEGER
);

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

INSERT INTO silver.dim_movies 
  SELECT
    movieId::VARCHAR,
    regexp_replace(title, '\s\(\d{4}\)$', '') AS title,
    genres::VARCHAR,
    regexp_extract(title, '\((\d{4})\)$', 1)::INTEGER AS release_year
  FROM bronze.movies
  WHERE regexp_matches(title, '\(\d{4}\)$');
;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

SELECT * FROM silver.dim_movies LIMIT 10;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE TABLE silver.fact_ratings AS
SELECT 
  TRY_CAST(userId AS VARCHAR) AS userId,
  TRY_CAST(movieId AS VARCHAR) AS movieId,
  TRY_CAST(rating AS DOUBLE) AS rating,
  TRY_CAST(tstamp AS TIMESTAMP) AS tstamp
FROM bronze.ratings
WHERE TRY_CAST(rating AS DOUBLE) IS NOT NULL
AND rating <> -1
UNION ALL
SELECT
  TRY_CAST(userId AS VARCHAR) AS userId,
  TRY_CAST(movieId AS VARCHAR) AS movieId,
  TRY_CAST(rating AS DOUBLE) AS rating,
  TRY_CAST(tstamp AS TIMESTAMP) AS tstamp
FROM bronze.additional_ratings
WHERE TRY_CAST(rating AS DOUBLE) IS NOT NULL
AND rating <> -1;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

SELECT * FROM silver.fact_ratings LIMIT 10;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW gold.vw_movie_kpis AS
SELECT
  COUNT(DISTINCT f.movieId)              AS total_filmes_avaliados,
  COUNT(DISTINCT f.userId)                AS total_usuarios,
  COUNT(*)                                  AS total_avaliacoes,
  ROUND(AVG(f.rating), 2)                   AS media_geral_rating,
  ROUND(STDDEV(f.rating), 2)                AS desvio_padrao_rating,
  MIN((f.tstamp)::timestamp)     AS primeira_avaliacao,
  MAX((f.tstamp)::timestamp)     AS ultima_avaliacao
FROM silver.fact_ratings f;

SELECT * FROM gold.vw_movie_kpis;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW gold.vw_top_movies AS
SELECT
  m.movieId,
  m.titulo,
  m.ano_lancamento,
  COUNT(*)                 AS qtd_avaliacoes,
  ROUND(AVG(f.rating), 2)  AS media_rating
FROM silver.fact_ratings f
JOIN silver.dim_movies m ON m.movieId = f.movieId
GROUP BY m.movieId, m.titulo, m.ano_lancamento
HAVING COUNT(*) >= 50         
ORDER BY media_rating DESC, qtd_avaliacoes DESC
LIMIT 10;

SELECT * FROM gold.vw_top_movies;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW gold.vw_scatter_popularity_vs_quality AS
SELECT
  m.movieId,
  m.titulo,
  COUNT(*)                 AS popularidade_qtd_avaliacoes,
  ROUND(AVG(f.rating), 2)  AS qualidade_media_rating
FROM silver.fact_ratings f
JOIN silver.dim_movies m ON m.movieId = f.movieId
GROUP BY m.movieId, m.titulo;

SELECT * FROM gold.vw_scatter_popularity_vs_quality LIMIT 10;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW gold.vw_ratings_heatmap AS
SELECT
    EXTRACT(year FROM tstamp::timestamp)  AS year,
    EXTRACT(month FROM tstamp::timestamp) AS month,
    COUNT(*) AS qtd_avaliacoes,
    ROUND(AVG(rating), 2) AS media_rating
FROM silver.fact_ratings
GROUP BY 1, 2;

SELECT * FROM gold.vw_ratings_heatmap LIMIT 10;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW gold.vw_user_activity AS
SELECT
  f.userId,
  COUNT(*)                                          AS qtd_avaliacoes,
  ROUND(AVG(f.rating), 2)                           AS media_rating_dado,
  MIN(f.tstamp::timestamp)             AS primeira_avaliacao,
  MAX(f.tstamp::timestamp)             AS ultima_avaliacao
FROM silver.fact_ratings f
GROUP BY f.userId;

SELECT * FROM gold.vw_user_activity LIMIT 10;

--           _      _      _
--         >(.)__ <(.)__ =(.)__
--          (___/  (___/  (___/ 
-- °º¤ø,¸¸,ø¤º°`°º¤ø,¸,ø¤°º¤ø,¸¸,ø¤º°`°º¤ø,¸

CREATE OR REPLACE VIEW gold.vw_genre_performance AS
SELECT
  genero,
  COUNT(*)                       AS qtd_avaliacoes,
  COUNT(DISTINCT f.movieId)     AS qtd_filmes,
  ROUND(AVG(f.rating), 2)        AS media_rating
FROM silver.fact_ratings f
JOIN silver.dim_movies m ON m.movieId = f.movieId
CROSS JOIN UNNEST(string_split(m.generos, '|')) AS t(genero)
GROUP BY genero
ORDER BY media_rating DESC;

SELECT * FROM gold.vw_genre_performance LIMIT 10;

