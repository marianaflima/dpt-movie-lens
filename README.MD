# Technical Challenge 01 — Real-world case with BigQuery and Metabase (adapted)
---
For the brazilian portuguese version, ![click here]('pt-br/README.md')
---
## **Cloud / Data**

- **MinIO**

Storage for the CSV files (raw layer).

- **DuckDB**

External tables, analytical modeling, SQL queries, and view creation.

## **BI / Visualization**

- **Metabase**

Business Intelligence tool for building charts and dashboards.

## **Local infrastructure**

- **Docker**

Used to spin up Metabase, DuckDB, and MinIO locally.

## **Language**

- **SQL (DuckDB)**

Used for:

1. data cleaning
2. analytical modeling
3. table creation
4. view creation
5. dashboard metrics

---
## Pipeline Architecture

![](img/architecture.png)

---
## Technical decisions

- The original challenge asked for GCP tools such as Cloud Storage and BigQuery, and I adapted it to use MinIO together with DuckDB to produce a similar result, putting together a docker-compose file to spin up three instances.
- The main motivation was to be able to complete the same challenge using open-source / free tools, in case I couldn't get it done within GCP's free tier.
- I actually started implementing the project using PostgreSQL instead of DuckDB, but for what I needed, PostgreSQL wasn't faithful to the original infrastructure nor efficient for fetching the data remotely.
- The only real snag I ran into was using DuckDB together with Metabase: the database can only be accessed by either Metabase or the CLI/interface, not both at the same time, which is a known limitation for anyone running Metabase with DuckDB.

## Step by step

### Bronze Layer

1. Once I had the containers up, I logged into the MinIO web interface and created a bucket via `Create Bucket` named `movie-lens`, then created a folder named "raw" inside the bucket, where I uploaded the CSV files.

2. To access MinIO from the command line, I used the following command in the terminal, after accessing the MinIO container via bash:

```bash
mc alias set myminio http://localhost:9000 minioadmin minioadmin123
```

3. I created `/data/analytics.duckdb`, installed and loaded `httpfs`, configured the MinIO variables, and enabled its interface using the commands below:

```bash
duckdb /data/analytics.duckdb -ui
```

```bash
INSTALL httpfs; LOAD httpfs;

SET s3_endpoint = 'localhost:9000';
SET s3_access_key_id = 'minioadmin';
SET s3_secret_access_key = 'minioadmin123';
SET s3_use_ssl = false;
SET s3_url_style='path';
```

- I also created schemas to better organize the database:

```bash
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
```

4. To import the data and create the equivalent of GCS's external tables, defining all types as VARCHAR, I ran the query:

```bash
CREATE OR REPLACE VIEW bronze.elicitations AS SELECT * FROM read_csv(
  's3://movie-lens/raw/movie_elicitation_set.csv',
  types = {
    'tstamp':'VARCHAR',
    'source':'VARCHAR',
    'month_idx':'VARCHAR',
    'movieId':'VARCHAR',
  }
);
```

- I checked it with the command:

```bash
SELECT * FROM bronze.elicitations LIMIT 5;

┌─────────┬───────────┬─────────┬─────────────────────┐
│ movieId │ month_idx │ source  │       tstamp        │
│ varchar │  varchar  │ varchar │       varchar       │
├─────────┼───────────┼─────────┼─────────────────────┤
│ 1       │ 0         │ 1       │ 2023-02-27 19:30:03 │
│ 1       │ 1         │ 1       │ 2023-04-01 00:01:47 │
│ 1       │ 2         │ 1       │ 2023-05-01 00:02:01 │
│ 1       │ 3         │ 1       │ 2023-06-01 00:01:40 │
│ 1       │ 4         │ 1       │ 2023-07-01 00:01:56 │
└─────────┴───────────┴─────────┴─────────────────────┘
```

- I adapted the query for the other CSVs, and in the end we had these views:

```bash
SELECT view_name FROM duckdb_views;

┌────────────────────┐
│     view_name      │
│      varchar       │
├────────────────────┤
│ additional_ratings │
│ beliefs            │
│ elicitations       │
│ movies             │
│ ratings            │
│ recommendations    │
└────────────────────┘
```

### Silver Layer

5. From the views, I created the analytical tables `silver.dim_movies` and `silver.fact_ratings`.

- For `dim_movies`, my challenge was extracting the year from the title to create a separate release-year column, and this was the query I built:

```bash
CREATE OR REPLACE TABLE silver.dim_movies (
  titulo VARCHAR,
  generos VARCHAR,
  ano_lancamento INTEGER
);

INSERT INTO silver.dim_movies 
  SELECT
    regexp_replace(title, '\s\(\d{4}\)$', ''),
    genres,
    regexp_extract(title, '\((\d{4})\)$', 1)::INTEGER
  FROM bronze.movies
  WHERE regexp_matches(title, '\(\d{4}\)$');
;
```

- Here's the final result:

```bash
SELECT * FROM silver.dim_movies LIMIT 10;

┌─────────────────────────────┬─────────────────────────────────────────────┬────────────────┐
│           titulo            │                   generos                   │ ano_lancamento │
│           varchar           │                   varchar                   │     int32      │
├─────────────────────────────┼─────────────────────────────────────────────┼────────────────┤
│ Toy Story                   │ Adventure|Animation|Children|Comedy|Fantasy │           1995 │
│ Jumanji                     │ Adventure|Children|Fantasy                  │           1995 │
│ Grumpier Old Men            │ Comedy|Romance                              │           1995 │
│ Waiting to Exhale           │ Comedy|Drama|Romance                        │           1995 │
│ Father of the Bride Part II │ Comedy                                      │           1995 │
│ Heat                        │ Action|Crime|Thriller                       │           1995 │
│ Sabrina                     │ Comedy|Romance                              │           1995 │
│ Tom and Huck                │ Adventure|Children                          │           1995 │
│ Sudden Death                │ Action                                      │           1995 │
│ GoldenEye                   │ Action|Adventure|Thriller                   │           1995 │
└─────────────────────────────┴─────────────────────────────────────────────┴────────────────┘
```

- For the `silver.fact_ratings` table, my challenge was unifying the tables and cleaning up the final dataset. I still had to do some cleanup on this particular dataset, because the rating column was supposed to range from 0.5 to 5.0, but there were -1 values, and since that data only represented 12% of the total records (combining the two original tables), I didn't see a problem leaving them out.

```bash
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
```

- Here's the final result:

```bash
SELECT * FROM silver.fact_ratings LIMIT 5;

┌────────┬─────────┬────────┬─────────────────────┐
│ userId │ movieId │ rating │       tstamp        │
│ int32  │  int32  │ double │      timestamp      │
├────────┼─────────┼────────┼─────────────────────┤
│  42170 │       1 │    4.0 │ 1998-06-18 16:31:37 │
│  42170 │       7 │    4.0 │ 1998-06-18 16:31:37 │
│  42170 │      17 │    4.0 │ 1998-06-18 16:31:37 │
│  42170 │      24 │    2.0 │ 1997-11-07 13:41:17 │
│  42170 │      36 │    2.0 │ 1997-11-07 13:27:51 │
└────────┴─────────┴────────┴─────────────────────┘
```

### Gold Layer

6. With a little help from Claude, I put together the queries for the views that would be consumed by Metabase, as requested by the challenge, building a view for each one:

```bash
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

```


```bash
CREATE OR REPLACE VIEW gold.vw_scatter_popularity_vs_quality AS
SELECT
  m.movieId,
  m.titulo,
  COUNT(*)                 AS popularidade_qtd_avaliacoes,
  ROUND(AVG(f.rating), 2)  AS qualidade_media_rating
FROM silver.fact_ratings f
JOIN silver.dim_movies m ON m.movieId = f.movieId
GROUP BY m.movieId, m.titulo;
```


```bash
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
```


```bash
CREATE OR REPLACE VIEW gold.vw_ratings_heatmap AS
SELECT
    EXTRACT(year FROM tstamp::timestamp)  AS year,
    EXTRACT(month FROM tstamp::timestamp) AS month,
    COUNT(*) AS qtd_avaliacoes,
    ROUND(AVG(rating), 2) AS media_rating
FROM silver.fact_ratings
GROUP BY 1, 2;
```


```bash
CREATE OR REPLACE VIEW gold.vw_user_activity AS
SELECT
  f.userId,
  COUNT(*)                                          AS qtd_avaliacoes,
  ROUND(AVG(f.rating), 2)                           AS media_rating_dado,
  MIN(f.tstamp::timestamp)             AS primeira_avaliacao,
  MAX(f.tstamp::timestamp)             AS ultima_avaliacao
FROM silver.fact_ratings f
GROUP BY f.userId;
```


```bash
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
```

7. Next, I connected Metabase to the database and started building the charts (with Claude's help here too).

![](img/dashboard-1.png)
![](img/dashboard-2.png)
![](img/dashboard-3.png)
![](img/dashboard-4.png)
