-- =========================================================================
-- queries.sql - your analysis
--
-- Project 1 | SQL: From Data to Insight
-- Student: Gabriel Gomes 
-- Dataset: Inside Airbnb (Rio de Janeiro)
--
-- This is a DELIVERABLE, graded on two things: the SQL, and what you wrote
-- underneath it. A query with no finding recorded is half an answer - in a
-- month you will not remember what it told you, and neither will whoever is
-- marking it.
--
-- Five queries minimum, each earning its place by answering a question you
-- wrote down in notebook 01. The aggregation should happen here, in SQL,
-- not in pandas after a SELECT *.
-- =========================================================================

-- =========================================================================
-- Q1 | Which neighborhoods (and zones) have the most listings —
--     where will I have the widest selection?
-- =========================================================================
-- Hypothesis: South Zone (esp. Copacabana, Ipanema) likely has the most listings; Barra da Tijuca a distant second.
-- Finding: Copacabana has by far the most listings. Most of the top 10 neighborhoods are in the South or West zones,
-- with Centro ranking fourth. At the zone level, South and West dominate, while the North zone comes last.

-- By neighborhood
SELECT
    n.name        AS neighborhood,
    ng.name       AS zone,
    COUNT(l.id)   AS total_listings
FROM neighborhoods AS n
JOIN neighborhood_groups AS ng 
	ON ng.id = n.group_id
LEFT JOIN listings AS l   
	ON l.neighborhood_id = n.id
GROUP BY n.id
ORDER BY total_listings DESC;
 
-- By zone
SELECT
    ng.name       AS zone,
    COUNT(l.id)   AS total_listings
FROM neighborhood_groups AS ng
LEFT JOIN neighborhoods AS n 
	ON n.group_id = ng.id
LEFT JOIN listings AS l      
	ON l.neighborhood_id = n.id
GROUP BY ng.id
ORDER BY total_listings DESC;

-- =========================================================================
-- Q2 |  Which neighborhoods do guests rate highest for location —
--     where am I most likely to be happy with where I stayed?
-- =========================================================================
-- Hypothesis: Ipanema, Leblon, and Copacabana likely score highest for location, due to 
-- beach proximity and walkability.
-- Finding: Top 10 location scores are mostly South zone. Flamengo leads (4.95), ahead of
-- high-volume Ipanema/Leblon (4.94). Low-listing neighborhoods (Joa, Paqueta, Urca) also
-- rank well. Copacabana, despite most listings (12817), ranks last in top 10 (4.90).

SELECT
    n.name   AS neighborhood,
    ng.name   AS zone,
    COUNT(l.id)  AS n_listings,
    ROUND(AVG(l.review_scores_location), 2) AS avg_location_score
FROM neighborhoods AS n
JOIN neighborhood_groups AS ng 
	ON ng.id = n.group_id
JOIN listings AS l  
	ON l.neighborhood_id = n.id
WHERE l.review_scores_location IS NOT NULL
GROUP BY n.id
HAVING n_listings >= 20          -- avoid neighborhoods with too few ratings to be reliable
ORDER BY avg_location_score DESC;

-- =========================================================================
-- Q3 | Which combination of property attributes gives the best
--     deal — highest review scores for the price per guest?
-- =========================================================================
-- Hypothesis: Small private rooms/studios for 2-3 guests likely offer the best value for money.
-- Finding: Excl. shared rooms, private rooms (esp. homes/rental units) offer best value,
-- led by private room in home, 5-6 guests (€6.42/guest, 0.75 ratio). Entire homes/apts
-- cost ~2x more per guest; entire rental unit 5-6 guests (n=4237, most robust) ranks last (0.20).

SELECT
    l.property_type,
    rt.name AS room_type,
    CASE
        WHEN l.accommodates <= 2 THEN '1-2 guests'
        WHEN l.accommodates <= 4 THEN '3-4 guests'
        WHEN l.accommodates <= 6 THEN '5-6 guests'
        ELSE '7+ guests'
    END                                            AS capacity_band,
    COUNT(*)                                       AS n_listings,
    ROUND(AVG(l.price / NULLIF(l.accommodates, 0)), 2) AS avg_price_per_guest,
    ROUND(AVG(l.review_scores_rating), 2)          AS avg_rating,
    ROUND(
        AVG(l.review_scores_rating) / AVG(l.price / NULLIF(l.accommodates, 0))
    , 4)                                            AS value_per_guest_ratio
FROM listings AS l 
JOIN room_types AS rt
	ON l.room_type_id = rt.id
WHERE l.price > 0
  AND l.accommodates > 0
  AND l.review_scores_rating IS NOT NULL
  AND l.number_of_reviews >= 5
  AND room_type <> 'Shared room'
GROUP BY l.property_type, room_type, capacity_band
HAVING n_listings >= 10
ORDER BY value_per_guest_ratio DESC
LIMIT 20;

-- =========================================================================
-- Q4 | Am I better off booking with a Superhost or multi-listing
--     host, versus a smaller/non-Superhost listing?
-- =========================================================================
-- Hypothesis: Superhosts likely rate higher on average; hosts with many listings may
-- rate slightly lower than small, single-listing hosts.
-- Finding: Superhost + single listing performs best (126.2 nights/yr, 4.92 rating).
-- Superhost + multi-listing 2nd (95.5 nights, 4.87). Non-superhost + multi-listing has
-- lowest occupancy (34.7); non-superhost + single-listing lowest overall but rates higher (4.81) than multi.

SELECT
    CASE
        WHEN h.is_superhost = 1 AND h.listings_count > 1 THEN 'Superhost + multi-listing'
        WHEN h.is_superhost = 1 AND h.listings_count = 1 THEN 'Superhost + single listing'
        WHEN h.is_superhost = 0 AND h.listings_count > 1 THEN 'Non-superhost + multi-listing'
        ELSE 'Non-superhost + single listing'
    END                                           AS host_segment,
    COUNT(l.id)                                   AS n_listings,
    ROUND(AVG(l.estimated_occupancy_l365d), 1)    AS avg_occupancy_nights_l365d,
    ROUND(AVG(l.review_scores_rating), 2)         AS avg_rating
FROM listings AS l
JOIN hosts AS h 
    ON h.id = l.host_id
GROUP BY host_segment
ORDER BY avg_occupancy_nights_l365d DESC;

-- =========================================================================
-- Q5 | In the highest-rated neighborhoods, how does review
--     activity change across the year — is there a clear
--     high/low season?
-- =========================================================================
-- Hypothesis: Review activity likely peaks around Carnival (Feb/Mar) and New Year's, with a summer-wide bump (Dec-Feb) and a winter (Jun-Aug) low.
-- Finding: Winter (Jun-Aug) dip appears most years, partially confirming hypothesis.
-- Carnival (Feb-Mar) peak only shows in 2025, not 2023/2024. Nov is the most consistent
-- peak (not hypothesized). Strong 2023-2025 growth trend likely reflects adoption, not seasonality.

SELECT
    strftime('%Y-%m', r.date)            AS year_month,
    COUNT(*)                             AS n_reviews
FROM reviews AS r
JOIN listings AS l       
    ON l.id = r.listing_id
WHERE year_month BETWEEN '2023-01' AND '2025-12'
GROUP BY year_month
ORDER BY year_month;

-- =========================================================================
--    Consolidated score: the single best overall pick.
--    Combines: top-rated neighborhood, Superhost/multi-listing
--    status, and best value-per-guest attributes into one
--    normalized score per listing (higher rating + lower price
--    per guest = better score).
-- =========================================================================

WITH top_neighborhoods AS (
    SELECT
        n.id AS neighborhood_id,
        n.name AS neighborhood,
        ng.name AS zone
    FROM neighborhoods AS n
    JOIN neighborhood_groups AS ng
        ON ng.id = n.group_id
    JOIN listings AS l
        ON l.neighborhood_id = n.id
    WHERE l.review_scores_location IS NOT NULL
    GROUP BY n.id
    HAVING COUNT(l.id) >= 20
    ORDER BY AVG(l.review_scores_location) DESC
    LIMIT 20
),
scored AS (
    SELECT
        l.url,
        l.name,
        tn.neighborhood,
        tn.zone,
        l.property_type,
        rt.name AS room_type,
        l.price / NULLIF(l.accommodates, 0) AS price_per_guest,
        l.review_scores_rating AS rating,
        h.is_superhost,
        h.listings_count
    FROM listings AS l
    JOIN top_neighborhoods AS tn
        ON tn.neighborhood_id = l.neighborhood_id
    JOIN room_types AS rt
        ON rt.id = l.room_type_id
    JOIN hosts AS h
        ON h.id = l.host_id
    WHERE l.price > 0
      AND l.accommodates > 0
      AND l.review_scores_rating IS NOT NULL
      AND l.number_of_reviews >= 5
      AND rt.name <> 'Shared room'
      AND h.is_superhost = 1
      AND h.listings_count = 1
),
bounds AS (
    SELECT
        MIN(price_per_guest) AS min_price,
        MAX(price_per_guest) AS max_price,
        MIN(rating) AS min_rating,
        MAX(rating) AS max_rating
    FROM scored
)
SELECT
    s.url,
    s.name,
    s.neighborhood,
    s.zone,
    s.property_type,
    s.room_type,
    ROUND(s.price_per_guest, 2) AS price_per_guest,
    s.rating,
	-- normalized rating: 0 (worst) to 1 (best)
    ROUND((s.rating - b.min_rating) /
        NULLIF(b.max_rating - b.min_rating, 0), 3) AS rating_norm,
	-- normalized price: 0 (cheapest) to 1 (most expensive), then
    -- inverted so 1 = cheapest (a "benefit" like rating)
    ROUND(1 - (s.price_per_guest - b.min_price) /
        NULLIF(b.max_price - b.min_price, 0), 3) AS price_value_norm,
	-- final score: simple average of the two normalized benefits;
    -- adjust the weights below if rating or price should matter more
    ROUND(
        0.5 * ((s.rating - b.min_rating) /
            NULLIF(b.max_rating - b.min_rating, 0))
        + 0.5 * (1 - (s.price_per_guest - b.min_price) /
            NULLIF(b.max_price - b.min_price, 0)),
        3
    ) AS overall_score
FROM scored AS s
CROSS JOIN bounds AS b
ORDER BY overall_score DESC
LIMIT 50;