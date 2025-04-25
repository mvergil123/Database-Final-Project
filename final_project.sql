-- -- SET search_path TO group41;

-- -- Creating the table
-- -- SET ROLE group41;   -- when creating an object 
CREATE TABLE IF NOT EXISTS video_game_sales (
    Rank INTEGER,
    Name TEXT,
    Platform TEXT,
    Year TEXT,
    Genre TEXT,
    Publisher TEXT,
    NA_Sales NUMERIC,
    EU_Sales NUMERIC,
    JP_Sales NUMERIC,
    Other_Sales NUMERIC,
    Global_Sales NUMERIC
);

-- -- Bulk loading the data from the CSV file into the table
\COPY video_game_sales FROM 'vgsales.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"');

-- -- Some of the years are 'N/A' in the dataset so I set the value of year to text and will clean later. 

-- -- query to check for data and look for any odd values (i.e 'N/A', 'NULL', etc.)
SELECT * FROM video_game_sales
WHERE Rank IS NULL OR Name IS NULL OR Platform IS NULL OR Year IS NULL OR Genre IS NULL OR Publisher IS NULL
OR NA_Sales IS NULL OR EU_Sales IS NULL OR JP_Sales IS NULL OR Other_Sales IS NULL OR Global_Sales IS NULL
OR Name = 'N/A' OR Platform = 'N/A' OR Year = 'N/A' OR Genre = 'N/A' OR Publisher = 'N/A'
OR Name = 'Name' OR Platform = 'Platform' OR Year = 'Year' OR Genre = 'Genre' OR Publisher = 'Publisher';

-- -- ^ after running the query above, I found that a lot of the video games had 'N/A' as their value for year. These data pieces were the ones that were causing the error at the beginning. 
-- -- side note*** some of the games also have 'unknown' values for their publisher 


-- -- query to replace the 'N/A' values in year to NULL
UPDATE video_game_sales
SET Year = NULL
WHERE Year = 'N/A';

-- -- ^ query updated 271 rows 

-- -- now we can change the data type of year to integer
ALTER TABLE video_game_sales
ALTER COLUMN Year TYPE INTEGER USING NULLIF(Year, 'N/A')::INTEGER;
-- -- year column is now an integer data type which will allow for simpler queries and data retrieval.

-- -- query to check for years that are in the future 
SELECT DISTINCT Year
FROM video_game_sales
WHERE Year > 2025;
-- -- no rows returned 

-- -- query to check for any negative sale values
SELECT * FROM video_game_sales
WHERE NA_Sales < 0 OR EU_Sales < 0 OR JP_Sales < 0 OR Other_Sales < 0 OR Global_Sales < 0;
-- -- no rows returned

-- Performance Tuning 
-- 1. Analyzing query performance for viewing the best selling games from Nintendo
EXPLAIN ANALYZE 
SELECT * 
FROM video_game_sales
WHERE publisher = 'Nintendo'
ORDER BY global_sales DESC
LIMIT 10;

-- Creating the index on the publisher and global sales columns which will improve our times
CREATE INDEX idx_publisher_global_sales 
ON video_game_sales (publisher, global_sales DESC);

-- 2. Analyzing query performance for global sales by genre in 2004
EXPLAIN ANALYZE
SELECT Genre, SUM(global_sales)
FROM video_game_sales
WHERE year = 2004
GROUP BY genre
ORDER BY SUM(global_sales) DESC;

CREATE INDEX idx_year_genre
ON video_game_sales (year, genre);

-- 3. Analyzing query performance for the top PS4 games by global sales
EXPLAIN ANALYZE
SELECT Name, Global_Sales
FROM video_game_sales
WHERE Platform = 'PS4'
ORDER BY Global_Sales DESC
LIMIT 10;

CREATE INDEX idx_platform_sales
ON video_game_sales (platform, global_sales DESC);



-- Interesting Queries
--Best genre per year and its total_sales based on the genre
WITH genre_sales AS (
SELECT year, genre, SUM(global_sales) AS total_sales
FROM video_game_sales
GROUP BY year, genre),
ranked_genres AS (
SELECT year, genre, total_sales, RANK() OVER (PARTITION BY year ORDER BY total_sales DESC) AS rank
FROM genre_sales )
SELECT year, genre, total_sales FROM ranked_genres
WHERE rank = 1
ORDER BY year;

--Best selling game per year along with its genre and its global sales
SELECT  v.year, v.name AS top_game, v.genre, v.global_sales
FROM video_game_sales v
WHERE v.global_sales = ( SELECT MAX(v2.global_sales) FROM video_game_sales v2 WHERE v2.year = v.year)
AND v.year IS NOT NULL
ORDER BY v.year;

--Top 5 publishes with the number of games they published and its averages sales per game
SELECT publisher, COUNT(*) AS num_games, ROUND(AVG(global_sales), 2) AS avg_sales_per_game
FROM video_game_sales
WHERE global_sales IS NOT NULL
GROUP BY publisher
HAVING COUNT(*) >= 5
ORDER BY avg_sales_per_game DESC
LIMIT 5;
