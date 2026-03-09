-- Create Database
CREATE DATABASE kaggle_coffee;

USE kaggle_coffee;

-- Create Table
CREATE TABLE raw_coffee (
	transaction_id VARCHAR(255),
    item VARCHAR(255),
    quantity VARCHAR(255),
    price_per_unit VARCHAR(255),
    total_spent VARCHAR(255),
    payment_method VARCHAR(255),
    location VARCHAR(255),
    transaction_date VARCHAR(255)
);

-- Upload Data
LOAD DATA INFILE '/Users/claireremolano/anaconda_projects/coffee/dirty_cafe_sales.csv'
INTO TABLE raw_coffee
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Create Staging Table
CREATE TABLE staging_data
SELECT *
FROM raw_coffee;

-- Checking Columns

# Check for distinct Transaction ID 
SELECT transaction_id, COUNT(*)
FROM staging_data
GROUP BY transaction_id
HAVING COUNT(*) > 1;
# No duplicates

SELECT transaction_id, COUNT(*)
FROM staging_data
GROUP BY transaction_id
ORDER BY transaction_id DESC;

# Item
SELECT item, COUNT(*) AS frequency, COUNT(*) / (SELECT COUNT(*) FROM staging_data) AS proportion
FROM staging_data
GROUP BY item
ORDER BY frequency DESC;
## Cafe items, UNKNOWN, ERROR, and blank spaces

# Quantity
SELECT quantity, COUNT(*) AS frequency, COUNT(*) / (SELECT COUNT(*) FROM staging_data) AS proportion
FROM staging_data
GROUP BY quantity
ORDER BY frequency DESC; 
## Range 1-5 items, UNKNOWN, ERROR

# Price Per Unit
SELECT price_per_unit, COUNT(*) AS frequency, COUNT(*) / (SELECT COUNT(*) FROM staging_data) AS proportion
FROM staging_data
GROUP BY price_per_unit
ORDER BY frequency DESC;
## Range float(1-5), UNKNOWN, ERROR, blank spaces

# Total Spent
SELECT total_spent, COUNT(*) AS frequency, COUNT(*) / (SELECT COUNT(*) FROM staging_data) AS proportion
FROM staging_data
GROUP BY total_spent
ORDER BY frequency DESC;
## Floats, UNKNOWN, ERROR, blank spaces

# Payment Method
SELECT payment_method, COUNT(*) AS frequency, COUNT(*) / (SELECT COUNT(*) FROM staging_data) AS proportion
FROM staging_data
GROUP BY payment_method
ORDER BY frequency DESC;
## Credit Card, Cash, Digital Wallet, UNKNOWN, ERROR
### Verdict considering dropping column since more than 20% of data is missing

# Location 
SELECT location, COUNT(*) AS frequency, COUNT(*) / (SELECT COUNT(*) FROM staging_data) AS proportion
FROM staging_data
GROUP BY location
ORDER BY frequency DESC;
## Takeaway, In-store, UNKNOWN, ERROR, blank spaces
### Verdict: Consider dropping column since more than 20% of values are UNKNOWN, ERROR, and blank spaces

# Transaction Date
SELECT transaction_date, COUNT(*) AS frequency, COUNT(*) / (SELECT COUNT(*) FROM staging_data) AS proportion
FROM staging_data
GROUP BY transaction_date
ORDER BY frequency DESC;
## 2023-MO-DAY, UNKNOWN, ERROR, blank spaces

# Item Statistics
SELECT DISTINCT item, price_per_unit
FROM staging_data
ORDER BY item, price_per_unit DESC;
# Some items have distinct prices: Cookies $1, Tea $1.50, Coffee $2, Salad $5
# Cake and Juice $3
# Sandwich and Smoothie $4

-- Further steps
	# *No duplicate transaction ids
	# 1. Remove normalize values (remove hidden characters, trim, etc.)
    # 2. Convert blank spaces and UNKNOWN as NULL
    # 3. Convert ERRORs for future analysis:
		#transaction_date VARCHAR(255), need datetime 2026-01-01
	# 4. Recalculate missing values for items, price, quantity, and total_spent
	# 5. Ensure correct data types

DELIMITER $$

CREATE FUNCTION clean_str(val VARCHAR(255))
RETURNS VARCHAR(255)
DETERMINISTIC 
BEGIN
	DECLARE clean VARCHAR(255);
    
    SET clean = TRIM(REGEXP_REPLACE(val, '[\r\n\t[:space:]]', ''));
    
    RETURN CASE 
				WHEN clean IN ('', 'UNKNOWN', 'ERROR') THEN NULL 
                ELSE clean
		   END;
END;
$$
DELIMITER ;

UPDATE staging_data
SET
	# Numeric columns
    quantity = clean_str(quantity), 
    price_per_unit = clean_str(price_per_unit),
	total_spent = clean_str(total_spent),
    
    # String columns
    transaction_id = clean_str(transaction_id),
    item = clean_str(item), 
    payment_method = clean_str(payment_method),
    location = clean_str(location),
    
    # Further processing to convert to datetime needed
	transaction_date = CASE
		WHEN TRIM(REGEXP_REPLACE(transaction_date, '[\r\n\t[:space:]]', '')) IN ('', 'UNKNOWN', 'ERROR') THEN NULL
        ELSE STR_TO_DATE(TRIM(REGEXP_REPLACE(transaction_date, '[\r\n\t[:space:]]', '')), '%Y-%m-%d')
	END
;

-- Remove rows where transaction date is null. No further information on how to impute date. 
DELETE FROM staging_data
WHERE transaction_date IS NULL;

-- Convert Data Types
ALTER TABLE staging_data
MODIFY quantity INT,
MODIFY price_per_unit DECIMAL(10,1),
MODIFY total_spent DECIMAL(10,1),
MODIFY transaction_date DATETIME
;

# In earlier query, there are distinct prices for each item. 
UPDATE staging_data AS original
JOIN ( 
	SELECT item, AVG(price_per_unit) AS avg_price
    FROM staging_data
    WHERE price_per_unit IS NOT NULL
    GROUP BY item
) AS s
	ON original.item = s.item
SET original.price_per_unit = s.avg_price
WHERE original.price_per_unit IS NULL
;

-- Fill missing values based on existing data:
	#Cookies = 1.0
    #Tea = 1.5
    #Coffee = 2.0
    #Salad = 5.0
    #Recalculate missing values with known price_per_unit, quantity, and/ total_spent
DELIMITER $$
CREATE PROCEDURE fill_missing_vals()
BEGIN 
	DECLARE rows_affected INT DEFAULT 1;
    
    WHILE rows_affected > 0 DO
		
		UPDATE staging_data
		SET item =
			CASE price_per_unit
				WHEN 1.0 THEN 'Cookie'
				WHEN 1.5 THEN 'Tea'
				WHEN 2.0 THEN 'Coffee'
				WHEN 5.0 THEN 'Salad'
			END
		WHERE item IS NULL
			AND price_per_unit IN (1.0, 1.5, 2.0, 5.0);
		SET rows_affected = ROW_COUNT();

		UPDATE staging_data
		SET quantity = total_spent/price_per_unit
		WHERE quantity IS NULL 
			AND total_spent IS NOT NULL 
			AND price_per_unit IS NOT NULL;
		SET rows_affected = rows_affected + ROW_COUNT();

		UPDATE staging_data	
		SET price_per_unit = total_spent/quantity
		WHERE price_per_unit IS NULL 
			AND total_spent IS NOT NULL
			AND quantity IS NOT NULL;
		SET rows_affected = rows_affected + ROW_COUNT();

		UPDATE staging_data
		SET total_spent = quantity*price_per_unit
		WHERE total_spent IS NULL
			AND quantity IS NOT NULL 
			AND price_per_unit IS NOT NULL;
		SET rows_affected = rows_affected + ROW_COUNT();
        
	END WHILE;
    
END
$$

DELIMITER ;

CALL fill_missing_vals();

# Avg Item Statistics
SELECT item, AVG(price_per_unit) AS avg_price, AVG(quantity) AS avg_quantity, AVG(total_spent) AS avg_spent
FROM staging_data
GROUP BY item;

SELECT item, price_per_unit, quantity, total_spent
FROM staging_data
WHERE item = 'Coffee';

SELECT item, price_per_unit, quantity, total_spent
FROM staging_data
WHERE item IS NULL
	OR price_per_unit IS NULL
    OR quantity IS NULL
    OR total_spent IS NULL;
#Less than 1000 that are missing values

#Check for cases that can be imputed
SELECT item, price_per_unit, quantity, total_spent
FROM staging_data
WHERE item IS NULL
	AND price_per_unit != 3.0 
    AND price_per_unit != 4.0
	OR price_per_unit IS NULL
    OR quantity IS NULL
    OR total_spent IS NULL;

UPDATE staging_data
SET
	item = 'Salad',
    price_per_unit = 5.0,
    quantity = 5
WHERE total_spent = 25.0
	AND item IS NULL 
    AND price_per_unit IS NULL
    AND quantity IS NULL;
    
UPDATE staging_data
SET
    price_per_unit = 3.0,
    quantity = 3
WHERE total_spent = 9.0
	AND item IS NULL 
    AND price_per_unit IS NULL
    AND quantity IS NULL;
    
# Include other date columns
ALTER TABLE staging_data
ADD COLUMN month_num INT,
ADD COLUMN month_name VARCHAR(255),
ADD COLUMN quarter_num INT,
ADD COLUMN day_of_week INT,
ADD COLUMN is_weekend TINYINT,
ADD COLUMN week_of_year INT,
ADD COLUMN week_of_month INT,
ADD COLUMN day_of_month INT
;

UPDATE staging_data
SET
	month_num = MONTH(transaction_date),
    month_name = MONTHNAME(transaction_date),
    quarter_num = QUARTER(transaction_date),
    day_of_week = DAYOFWEEK(transaction_date),
    is_weekend = CASE
		WHEN DAYOFWEEK(transaction_date) IN (1,7) THEN 1
        ELSE 0
	END,
    week_of_year = WEEK(transaction_date, 3),
    week_of_month = CEILING(DAY(transaction_date)/7.0),
    day_of_month = DAY(transaction_date)
;

SELECT DISTINCT week_of_month
FROM staging_data;

SELECT 'transaction_id', 'item', 'quantity', 'price_per_unit', 'total_spent', 'payment_method', 'location', 
	'transaction_date', 'month', 'month_name', 'quarter', 'day_of_week', 'is_weekend', 
    'week_of_year', 'week_of_month', 'day_of_month' #Create header
UNION ALL 
SELECT *
FROM staging_data
INTO OUTFILE '/usr/local/mysql/data//cafe_staging_data.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';











