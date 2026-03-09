# Cafe Item Revenue Forecasting

## Project Overview
This project analyzes daily revenue trends and volatility of cafe menu items using a synthetic 2023 dataset of 10,000 transactions. SARIMAX and Prophet models forecast item-level revenue for the first week of 2024 to provide insights into menu stability, demand patterns, and potential promotions.

## Goals
- Visualize trends, seasonality, and stability of cafe items.
- Forecast daily revenue per item for the first week of 2024.
- Identify items to keep, promote, or consider for removal.

## Dataset
- Synthetic dataset from [Kaggle](https://www.kaggle.com/datasets/ahmedmohamed2003/cafe-sales-dirty-data-for-cleaning-training).  
- Contains `ds` (date), `item`, `quantity`, `price_per_unit`, and `total_spent`.  
- Pre-cleaned in MySQL and further cleaned in Python.  
- Missing values imputed, and payment_method & location columns dropped due to >20% missing data.  
- For items sharing the same price, a Random Forest classifier predicted the correct item based on total spent.

## Methodology
1. Aggregated daily revenue per item and created cyclical day-of-week features (sine and cosine) to capture weekly seasonality.
2. Applied **SARIMAX** and **Prophet** for forecasting. Both models compared to a naive baseline using historical daily totals.
3. Log transformation applied to target variable to stabilize variance and avoid negative lower confidence intervals; results were inverse-transformed after forecasting.
4. Time-series cross-validation used to evaluate model performance.

## Results
- Both SARIMAX and Prophet outperformed the naive baseline in terms of MAE and residual distribution.  
- Prophet produced the lowest mean absolute error and was used for final forecasts.
<img width="944" height="350" alt="summary (1)" src="https://github.com/user-attachments/assets/7d36560c-c724-4b7f-b805-c17b672933f8" />
- Analysis suggested all items should be kept; smoothies may be offered seasonally during peak demand.
<img width="1998" height="1598" alt="Cafe Menu Decisions" src="https://github.com/user-attachments/assets/b04699c2-41c3-4837-8c4a-3b76ae0cac53" />

## Visualizations
Interactive visualizations created with [Tableau Public](https://public.tableau.com/app/profile/claire.remolano/vizzes) ("Cafe Sales"). Python visualizations also included for residuals, MAE, and revenue trends.

## Limitations
- Synthetic dataset with fixed item prices; real-world variability and profit/cost data are not included.  
- Only one type of item purchased per transaction; real customer behavior may vary.  

## Future Considerations
- Model and forecast **profit per item** instead of revenue for actionable menu decisions.  
- Explore additional exogenous features such as promotions, holidays, or weather to improve forecasts.

## Repository Structure
- dirty_cafe_sales.csv is from [Kaggle](https://www.kaggle.com/datasets/ahmedmohamed2003/cafe-sales-dirty-data-for-cleaning-training).
- Preliminary cleaning was done using MySQL with cafe_cleaning.sql and resulting in cafe_staging_data.csv.
- Imputation, EDA, data preprocessing, and modeling results and can be seen in the Cafe_sales.ipynb. 
- Helper functions and classes for data processing and modeling can be found in data_processing.py and modeling.py, respectively.
