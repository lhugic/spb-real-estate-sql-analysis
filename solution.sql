/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 *
 * Автор: Васильев Арсений
 * Дата: 16.04.2026
*/

-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats 
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
prepared_data AS (
	SELECT
		CASE
			WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
			ELSE 'ЛенОбл'
		END AS region,
		CASE
			WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
			WHEN a.days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
			WHEN a.days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
			WHEN a.days_exposition >= 181 THEN '181+ days'
			ELSE 'non category'
		END AS category,
		a.last_price::numeric / f.total_area AS price_per_sqm,
		f.total_area,
        f.rooms,
        f.balcony,
        f.ceiling_height,
        f.kitchen_area,
        f.living_area,
        f.floors_total
	FROM real_estate.advertisement a
	LEFT JOIN real_estate.flats f USING(id)
	LEFT JOIN real_estate.city c USING(city_id)
	LEFT JOIN real_estate.type t USING(type_id)
	WHERE
		a.id IN (SELECT id FROM filtered_id)
		AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
		AND t.type = 'город'
)
SELECT
	region,
	category,
	COUNT(*) AS count,
	ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY region), 2) AS percent_in_region,
	ROUND(AVG(price_per_sqm)::numeric, 2) AS avg_price_per_sqm,
	ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
	ROUND(AVG(living_area)::numeric, 2) AS avg_living_area,
	ROUND(AVG(kitchen_area)::numeric, 2) AS avg_kitchen_area,
	ROUND(AVG(rooms)::numeric, 0) AS avg_rooms,
	ROUND(AVG(balcony)::numeric, 0) AS avg_balcony,
	ROUND(AVG(ceiling_height)::numeric, 2) AS avg_ceiling_height,
	ROUND(AVG(floors_total)::numeric, 0) AS avg_floors_total
FROM prepared_data
WHERE category != 'non category'
GROUP BY region, category
ORDER BY region, category;

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats 
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
prepared_data AS (
    SELECT
        a.id,
        EXTRACT(MONTH FROM a.first_day_exposition) AS pub_month,
        EXTRACT(MONTH FROM a.first_day_exposition + (a.days_exposition || ' days')::interval) AS rem_month,
        a.last_price / f.total_area AS price_per_sqm,
        f.total_area,
        a.days_exposition
    FROM real_estate.advertisement a
    JOIN real_estate.flats f USING(id)
    JOIN real_estate.type t USING(type_id)
    WHERE
        a.id IN (SELECT id FROM filtered_id)
        AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
        AND t.type = 'город'
),
pub_stats AS (
    SELECT
        pub_month AS month,
        COUNT(*) AS pub_count,
        AVG(price_per_sqm) AS pub_price_per_sqm,
        AVG(total_area) AS pub_avg_area
    FROM prepared_data
    GROUP BY pub_month
),
rem_stats AS (
    SELECT
        rem_month AS month,
        COUNT(*) AS rem_count,
        AVG(price_per_sqm) AS rem_price_per_sqm,
        AVG(total_area) AS rem_avg_area
    FROM prepared_data
    WHERE days_exposition IS NOT NULL
    GROUP BY rem_month
)
SELECT
    CASE COALESCE(p.month, r.month)
        WHEN 1 THEN 'январь'
        WHEN 2 THEN 'февраль'
        WHEN 3 THEN 'март'
        WHEN 4 THEN 'апрель'
        WHEN 5 THEN 'май'
        WHEN 6 THEN 'июнь'
        WHEN 7 THEN 'июль'
        WHEN 8 THEN 'август'
        WHEN 9 THEN 'сентябрь'
        WHEN 10 THEN 'октябрь'
        WHEN 11 THEN 'ноябрь'
        WHEN 12 THEN 'декабрь'
    END AS month,
    p.pub_count,
    ROUND(p.pub_price_per_sqm::numeric, 2) AS pub_price_per_sqm,
    ROUND(p.pub_avg_area::numeric, 2) AS pub_avg_area,
    r.rem_count,
    ROUND(r.rem_price_per_sqm::numeric, 2) AS rem_price_per_sqm,
    ROUND(r.rem_avg_area::numeric, 2) AS rem_avg_area
FROM pub_stats p
FULL JOIN rem_stats r USING(month)
ORDER BY COALESCE(p.month, r.month);