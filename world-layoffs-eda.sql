-- csv file having headears as
/* 
*/

SELECT * FROM layoffs;

-- first simple duplicate finding, assuming the partition is such that others columns would be same
WITH duplicate_data AS
(
SELECT *,
	row_number()over(PARTITION BY company,location,industry,total_laid_off, percentage_laid_off,`date`) as rownum
FROM layoffs
)
SELECT * 
FROM duplicate_data
WHERE rownum>1;

-- second more detailed and fine duplicate finding
WITH duplicate_data AS
(
SELECT *,
	row_number()over(PARTITION BY company,location,industry,total_laid_off, percentage_laid_off,`date`, stage,country) as rownum
FROM layoffs
)
SELECT * 
FROM duplicate_data
WHERE rownum>1;

-- turns out oda has 2 difference over sweden and norway and terminus stage so fine partitioning is important

WITH duplicate_data AS
(
SELECT *,
	row_number()over(PARTITION BY company,location,industry,total_laid_off, percentage_laid_off,`date`) as rownum
FROM layoffs
)
SELECT * 
FROM duplicate_data
WHERE company IN (
	SELECT company 
	FROM duplicate_data
	WHERE rownum>1
    );
    
-- finding out company of the duplicates to check visually if it is duplicate or not

CREATE TABLE layoffs_staging LIKE layoffs;
-- Creating a staging table so that changes can be made keeping the original table intact

INSERT INTO layoffs_staging
WITH duplicate_data AS
(
SELECT *,
	row_number()over(PARTITION BY company,location,industry,total_laid_off, percentage_laid_off,`date`, stage,country) as rownum
FROM layoffs
)
SELECT company,location,industry,total_laid_off,percentage_laid_off,`date`,stage,country,funds_raised_millions 
FROM duplicate_data
WHERE rownum=1;
-- previously had kept the condition incorrect >1
-- had copied only duplicate data as >1 was active 
TRUNCATE TABLE layoffs_staging;
-- after truncating added the rows
--  here we have to work by copying data because the data does not has a unique id or primary key
SELECT * FROM layoffs_staging;
/* DATA CLEANED FROM DUPLICATES*/

-- STANDARDIZATION

SELECT DISTINCT TRIM(company) FROM layoffs_staging;

UPDATE layoffs_staging
SET company=TRIM(company);

SELECT * FROM layoffs where company like '% ';

SELECT DISTINCT industry 
FROM layoffs_staging 
ORDER BY 1;
-- 3 identified null blank and crypto

SELECT * 
FROM layoffs_staging 
WHERE industry like 'Crypt%';

UPDATE layoffs_staging
SET industry='Crypto'
WHERE industry like 'Crypt%';
-- minor update as both are from the same field

SELECT DISTINCT country
FROM layoffs_staging;
-- FOUND US as different

UPDATE layoffs_staging
SET country = TRIM(trailing '.' FROM country);

SELECT `date`, str_to_date(`date`, '%m/%d/%Y')
FROM layoffs_staging;

UPDATE layoffs_staging
SET `date`=str_to_date(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging
MODIFY `date` DATE;

SELECT *
FROM layoffs_staging
WHERE industry is NULL or industry ='';

SELECT *
FROM layoffs_staging t1
JOIN layoffs_staging t2 ON t1.company=t2.company
WHERE t1.industry is null or t1.industry='';
-- Finding if industry can be self populated

SELECT *
FROM layoffs_staging t1
JOIN layoffs_staging t2 ON t1.company=t2.company
WHERE (t1.industry is null or t1.industry='') and t2.industry is not null;

UPDATE layoffs_staging t1
JOIN layoffs_staging t2 ON t1.company=t2.company 
SET t1.industry = t2.industry
WHERE (t1.industry is null or t1.industry='') and t2.industry is not null;
-- logic did only work with null as industry
UPDATE layoffs_staging
SET industry = NULL
WHERE industry ='';

SELECT * FROM layoffs_staging WHERE industry is null;

/*  	CLEANING DONE	*/

SELECT * 
FROM layoffs_staging;

SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_staging;
-- 12000,1

SELECT *
FROM layoffs_staging
WHERE percentage_laid_off=1
order by funds_raised_millions desc;

SELECT company, SUM(total_laid_off)
FROM layoffs_staging
GROUP BY company
ORDER BY 2 DESC;

SELECT industry, SUM(total_laid_off)
FROM layoffs_staging
GROUP BY industry;

SELECT country, SUM(total_laid_off)
FROM layoffs_staging
GROUP BY country
ORDER BY 2 DESC;

SELECT company,YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging
GROUP BY company,YEAR(`date`)
ORDER BY 3 DESC;

SELECT stage, SUM(total_laid_off)
FROM layoffs_staging
GROUP BY stage
ORDER BY 1 ;

SELECT DATE_FORMAT(`date`,'%Y-%m') as `month`, sum(total_laid_off)
FROM layoffs_staging
WHERE DATE_FORMAT(`date`,'%Y-%m') IS NOT NULL 
GROUP BY `month`
ORDER BY `month`;

WITH rolling_total AS
(
	SELECT DATE_FORMAT(`date`,'%Y-%m') as `month`, sum(total_laid_off) as total_off
	FROM layoffs_staging
	WHERE DATE_FORMAT(`date`,'%Y-%m') IS NOT NULL 
	GROUP BY `month`
	ORDER BY `month`
)
SELECT `month`, total_off,
SUM(total_off) over(ORDER BY`month`) as runto
FROM rolling_total
;

WITH company_year(Company, years, total) as 
(
	SELECT company,YEAR(`date`), SUM(total_laid_off)
	FROM layoffs_staging
	GROUP BY company,YEAR(`date`)
)
SELECT *, dense_rank() over(PARTITION BY years order by total DESC) as ranking
FROM company_year
WHERE years is not null and total is not null
ORDER BY ranking;