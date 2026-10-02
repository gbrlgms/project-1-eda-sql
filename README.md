# Airbnb Rio de Janeiro: Where Should You Stay?

*SQL: From Data to Insight — Data Science & Machine Learning, Week 3*

A complete data pipeline, from raw data to insight, that treats Rio de Janeiro's Airbnb market as a dataset to answer a practical question: if you were planning a trip to Rio, where should you stay, what should you book, and when should you go?

`SQLite` · `Python` · `Pandas` · `SQL queries` · `Data visualization` · `ETL pipeline`

## What I set out to answer

Rather than open-ended exploration, the analysis is framed from the perspective of a prospective guest, moving from broad considerations to a final recommendation:

1. **Location** — Which neighborhoods (and zones) have the most listings, and which score highest for location?
2. **Property attributes** — Which combination of property type, room type, and capacity gives the best value per guest?
3. **Host characteristics** — Do Superhosts and single- vs. multi-listing hosts actually deliver better occupancy and ratings?
4. **Timing** — How does review activity (a proxy for demand) change across the year in the best-rated neighborhoods?
5. **Putting it together** — Combining all of the above into a single score per listing, to rank the best overall choices.

Before looking at the data, each question was paired with an educated hypothesis based on general knowledge of Rio, which the analysis then confirmed, partially confirmed, or contradicted.

## The data

The core dataset is [Inside Airbnb](https://insideairbnb.com/)'s snapshot of every Airbnb listing in Rio de Janeiro, taken on **June 24th, 2026**, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/):

| File | Rows | Columns | What it is |
|---|---|---|---|
| `listings.csv.gz` | 48,713 | 90 | One row per listing: price, room type, neighborhood, host, review scores, availability. |
| `reviews.csv.gz` | 1,388,472 | 6 | One row per review: `listing_id`, `date`, `reviewer_id`, `reviewer_name`, `comments`. |
| `neighbourhoods.csv` | 160 | 2 | One row per neighborhood. |
| `neighbourhoods.geojson` | 160 | 3 | One row per neighborhood, with geometry. |

> Data sourced from [Inside Airbnb](https://insideairbnb.com/), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Since Rio's neighborhoods (*bairros*) aren't grouped into zones (*Zona Sul*, *Zona Norte*, etc.) anywhere in the Inside Airbnb data, I supplemented it with a bairro-to-zone mapping, built by converting a [PDF published by the Rio city government](https://www.rio.rj.gov.br/dlstatic/10112/5148142/4145881/ListadeBairroseAPs_Mapa) into a CSV with the help of Claude, since no ready-made table was available online.

## Database design

The cleaned data is loaded into a SQLite database of five tables, organized in a star-like structure around `listings`:

- **`listings`** — the central table; each row is a property (`id` primary key).
- **`hosts`** — referenced by `listings.host_id`; one host can have multiple listings.
- **`neighborhoods`** — referenced by `listings.neighborhood_id`; grouped into zones via `neighborhoods.group_id → neighborhood_groups.id`.
- **`neighborhood_groups`** — Rio's four zones (Central, South, North, West).
- **`room_types`** — a lookup table for the four room type categories.
- **`reviews`** — referenced by `reviews.listing_id → listings.id`; one listing can have many reviews.

The ERD (`erd.png`) and schema (`sql/schema.sql`) were designed with drawSQL, then exported and adapted to SQLite dialect, with inline `PRIMARY KEY`/`FOREIGN KEY` declarations and `PRAGMA foreign_keys = ON`, since SQLite doesn't support deferred constraint creation.

## What I found

1. **Listing density**: Copacabana has by far the most listings; South and West zones dominate the top 10, with Centro (Central zone) an unexpected fourth. North zone comes last, as expected.
2. **Location scores**: South zone dominates, but Flamengo — not a neighborhood singled out beforehand — takes the top spot, while Copacabana, despite being the most popular, ranks last among the top 10. Popularity and location quality aren't the same thing.
3. **Value for money**: Private rooms beat entire homes, confirming the hypothesis, but the best deals come from *larger* groups (5-6, 7+ guests) splitting the cost, not the smaller 2-3 guest listings originally expected.
4. **Hosts**: Superhosts outperform non-superhosts on occupancy and rating; among Superhosts, single-listing hosts beat multi-listing hosts on both measures, supporting the idea that scale comes at some cost to the guest experience.
5. **Seasonality**: The hypothesized winter (June-August) lull shows up in most years, but the expected Carnival peak (February-March) is inconsistent, appearing clearly only in 2025. November is the most consistent peak across all three years, a pattern not anticipated going in.
6. **Combined ranking**: Combining location, price-per-guest, and rating into a single score surfaces listings that no single metric would have caught alone — modest, well-located private rooms in South Zone neighborhoods outside the usual Copacabana/Ipanema spotlight, hosted by small-scale Superhosts, confirming that the best overall choice trades a bit of fame for better value.

See `notebooks/03_hypothesis_and_visualization.ipynb` for the full write-up, supporting queries, and visualizations, and its "Limitations and Next Steps" section for the caveats behind these findings.

## How to run it

```bash
# 1. Clone the repo
git clone https://github.com/gbrlgms/project-1-eda-sql.git
cd <your-repo>

# 2. Check you already have the libraries — a current Anaconda install does.
#    If this prints, skip to step 3 and install nothing.
python -c "import pandas, numpy, matplotlib, seaborn, openpyxl; print('all present')"

#    Only if that failed:
pip install -r requirements.txt

# 3. Download the raw data (Inside Airbnb, Rio de Janeiro, 2026-06-24 snapshot)
python download_data.py airbnb --city rio

# 4. Run the notebooks in order
jupyter lab notebooks/01_eda.ipynb
```

- **`notebooks/01_eda.ipynb`** — load the raw files, inspect structure, and run data quality checks (`get_quality`).
- **`notebooks/02_processing.ipynb`** — drop empty columns, fix data types, handle missing values, convert prices to euros, fill in neighborhood zones, validate foreign keys (`match_keys`), and load the cleaned tables into the SQLite database following `sql/schema.sql`.
- **`notebooks/03_hypothesis_and_visualization.ipynb`** — run the queries in `sql/queries.sql` answering each research question, visualize the results, and report the findings. **This notebook is the project report.**

Raw data lands in `data/raw/` (gitignored, fetched by `download_data.py`); cleaned tables are exported to `data/clean/` before loading; reusable cleaning/loading logic lives in `src/functions.py`.
