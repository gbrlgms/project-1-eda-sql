"""Your reusable functions live here.

The rule from the brief: Python logic goes in `.py` files, SQL goes in `.sql`
files, and the notebooks hold the narrative. The moment a cell grows past a few
lines, or you find yourself pasting it a second time, move it here and call it
from the notebook.

To use this module from a notebook in `notebooks/`:

    import sys
    sys.path.append("..")
    from src.functions import *

The three below are only there to show the shape. Rename them, change the
arguments, write your own. This is a starting point, not an interface you have
to implement.
"""

import pandas as pd
from pathlib import Path
import plotly.graph_objects as go
from shapely import wkt
from shapely.geometry import mapping
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
CLEAN = ROOT / "data" / "clean"
DB = ROOT / "data" / "project.db"


# ...existing imports and constants...

def get_quality(df):
    """Summarize column types, missing values, blanks, and unique values."""
    quality = pd.DataFrame({
        "dtype": df.dtypes.astype(str),
        "nulls": df.isna().sum(),
        "nulls_%": (df.isna().mean() * 100).round(1),
        # Treat empty or whitespace-only strings as blanks.
        "blanks": df.apply(
            lambda col: col.astype("string").str.strip().eq("").sum()
        ),
        "n_unique": df.nunique(),
    })

    # Keep only columns with missing values or blank strings.
    return quality[
        (quality["nulls"] > 0) | (quality["blanks"] > 0)
    ].sort_values("nulls_%", ascending=False)


def drop_null_columns(df):
    """Return a copy of the DataFrame without columns that are entirely null."""
    quality = get_quality(df)

    # Select columns where every value is missing.
    all_null_columns = quality[quality["nulls_%"] == 100.0].index.tolist()
    return df.drop(columns=all_null_columns)


def brl_to_eur(price):
    """Convert a price from Brazilian reais to euros using a fixed rate."""
    exchange_rate = 0.17
    return round(exchange_rate * price)


def impute_price_grouped_median(
    df: pd.DataFrame,
    price_col: str = "price",
    group_cols: list[str] = None,
    flag_col: str = "price_imputed",
    outlier_threshold: float = None,
) -> pd.DataFrame:
    """Fill missing prices using progressively broader group medians.

    Optionally mark prices above ``outlier_threshold`` as missing first.
    Adds ``flag_col`` to indicate which rows needed imputation.
    """
    if group_cols is None:
        group_cols = ["neighbourhood_cleansed", "room_type", "accommodates"]

    out = df.copy()

    # Treat prices above the threshold as missing before filling.
    if outlier_threshold is not None:
        out["price_outlier"] = (
            (out[price_col] > outlier_threshold).fillna(False).astype(bool)
        )
        out.loc[out["price_outlier"], price_col] = pd.NA

    # Record which prices were missing before imputation.
    out[flag_col] = out[price_col].isna()

    # Try the most specific groups first, dropping one grouping column
    # at each fallback step. Use the overall median as the final fallback.
    for n in range(len(group_cols), -1, -1):
        cols = group_cols[:n]

        if cols:
            fill_values = out.groupby(cols)[price_col].transform("median")
        else:
            fill_values = out[price_col].median()

        out[price_col] = out[price_col].fillna(fill_values)

        # Stop once every price has been filled.
        if not out[price_col].isna().any():
            break

    return out


def match_keys(df1, df2):
    """Check whether all values in ``df1`` exist in ``df2['id']``.

    Returns True if every key matches; otherwise returns the unmatched keys.
    """
    keys_to_check = pd.Index(df1.unique())
    available_keys = pd.Index(df2["id"].unique())

    if keys_to_check.isin(available_keys).all():
        return True

    return keys_to_check[~keys_to_check.isin(available_keys)]


def create_neighborhood_heatmap(
    df: pd.DataFrame,
    name_col: str = "neighborhood",
    score_col: str = "avg_location_score",
    geometry_col: str = "geometry",
) -> go.Figure:
    """Create an interactive map of neighborhood location scores."""
    # Exclude rows that cannot be drawn or colored.
    data = df[[name_col, score_col, geometry_col]].dropna().copy()
    if data.empty:
        raise ValueError("No rows have both a location score and geometry.")

    # Convert WKT strings to Shapely geometries when needed.
    geometries = [
        wkt.loads(value) if isinstance(value, str) else value
        for value in data[geometry_col]
    ]

    # Build the GeoJSON features Plotly uses to draw the polygons.
    geojson = {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "properties": {name_col: name},
                "geometry": mapping(geometry),
            }
            for name, geometry in zip(data[name_col], geometries)
        ],
    }

    # Center the map on the combined bounds of all neighborhood polygons.
    min_x, min_y, max_x, max_y = unary_union(geometries).bounds

    fig = go.Figure(
        go.Choroplethmap(
            geojson=geojson,
            featureidkey=f"properties.{name_col}",
            locations=data[name_col],
            z=data[score_col],
            colorscale="Viridis",
            colorbar_title="Avg. location score",
            marker_line_color="white",
            marker_line_width=0.5,
        )
    )
    fig.update_layout(
        title="Average Location Score by Neighborhood",
        map={
            "style": "open-street-map",
            "center": {"lon": (min_x + max_x) / 2, "lat": (min_y + max_y) / 2},
            "zoom": 9,
        },
        margin={"r": 0, "t": 50, "l": 0, "b": 0},
    )
    return fig


def create_monthly_review_activity_plot(question_5: pd.DataFrame) -> go.Figure:
    """Plot monthly review totals with a separate line for each year."""
    # Confirm the input has the columns needed for the chart.
    required_columns = {"year_month", "n_reviews"}
    missing_columns = required_columns.difference(question_5.columns)
    if missing_columns:
        raise ValueError(f"Missing required columns: {sorted(missing_columns)}")

    # Parse dates and counts, then extract year and calendar month.
    data = question_5.loc[:, ["year_month", "n_reviews"]].copy()
    data["year_month"] = pd.to_datetime(data["year_month"], format="%Y-%m")
    data["n_reviews"] = pd.to_numeric(data["n_reviews"], errors="raise")
    data["year"] = data["year_month"].dt.year
    data["month"] = data["year_month"].dt.month

    years = [2023, 2024, 2025]
    months = list(range(1, 13))
    month_labels = [
        pd.Timestamp(year=2000, month=month, day=1).strftime("%b")
        for month in months
    ]

    # Arrange counts by month and year; fill months without data with zero.
    yearly = (
        data[data["year"].isin(years)]
        .pivot_table(
            index="month",
            columns="year",
            values="n_reviews",
            aggfunc="sum",
        )
        .reindex(index=months, columns=years, fill_value=0)
        .fillna(0)
    )

    # Sum yearly counts to make the background bar chart.
    monthly_totals = yearly.sum(axis=1)

    fig = go.Figure()
    fig.add_trace(
        go.Bar(
            x=month_labels,
            y=monthly_totals.tolist(),
            name="Total reviews (2023–2025)",
            marker_color="lightgray",
            opacity=0.45,
        )
    )

    # Overlay one colored line for each year.
    year_colors = {2023: "#F5CC27", 2024: "green", 2025: "blue"}
    for year in years:
        fig.add_trace(
            go.Scatter(
                x=month_labels,
                y=yearly[year].tolist(),
                mode="lines+markers",
                name=str(year),
                line={"color": year_colors[year]},
            )
        )

    fig.update_layout(
        title="Monthly Review Activity: 2023–2025",
        xaxis_title="Month",
        yaxis_title="Review count",
        template="plotly_white",
        barmode="overlay",
        legend_title="Series",
    )
    return fig