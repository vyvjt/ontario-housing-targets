# ------------------------------------------------------------------
# load_data.R -- read, validate and tidy Ontario housing-supply data
# ------------------------------------------------------------------
# Source: Ontario Data Catalogue, "Ontario's housing supply progress"
#         (Ministry of Municipal Affairs and Housing),
#         Open Government Licence - Ontario.
# The two CSVs are bundled in data/ so the project runs offline.
# Set `use_online = TRUE` to re-download the live files instead.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
})

URL_2023 <- "https://data.ontario.ca/dataset/77ac513f-a65a-4cf0-b889-31be6ddb6f46/resource/c922b5b4-9850-40c8-b905-afc3aaa347c0/download/ontarios_housing_supply_-_january_december_2023_-_en.csv"
URL_2024 <- "https://data.ontario.ca/dataset/77ac513f-a65a-4cf0-b889-31be6ddb6f46/resource/3bb04ba5-2445-44e0-9d2c-8a25dd1b18e6/download/ontarios_housing_supply_-_january_december_2024_-_en.csv"

AGGREGATE_ROW <- "Municipalities without targets"

# Read one year's file and give it year-neutral column names ----------
read_year <- function(path, year) {
  raw <- read_csv(path, col_types = cols(.default = col_character()),
                  show_col_types = FALSE)
  names(raw) <- c("municipality", "ten_year_target", "cum_progress_since_2022",
                  "annual_target", "annual_units", "progress_pct_text", "status")
  raw |>
    mutate(
      year            = year,
      municipality    = str_squish(municipality),        # "Woodstock " -> "Woodstock"
      across(c(ten_year_target, cum_progress_since_2022,
               annual_target, annual_units), parse_number),
      progress_pct    = parse_number(progress_pct_text), # "89.90%" -> 89.9
      status          = str_squish(status),
      is_aggregate    = municipality == AGGREGATE_ROW
    ) |>
    select(-progress_pct_text)
}

load_housing <- function(use_online = FALSE, data_dir = "data") {
  p23 <- if (use_online) URL_2023 else file.path(data_dir, "ontario_housing_supply_2023.csv")
  p24 <- if (use_online) URL_2024 else file.path(data_dir, "ontario_housing_supply_2024.csv")
  bind_rows(read_year(p23, 2023), read_year(p24, 2024))
}

# Wide table: one row per municipality, both years side by side --------
make_wide <- function(long) {
  long |>
    filter(!is_aggregate) |>
    select(municipality, year, ten_year_target, cum_progress_since_2022,
           annual_target, annual_units, progress_pct, status) |>
    pivot_wider(
      names_from  = year,
      values_from = c(cum_progress_since_2022, annual_target, annual_units,
                      progress_pct, status),
      names_sep   = "_"
    ) |>
    mutate(
      status_2023 = factor(status_2023, levels = c("Not met", "On track", "Exceeded")),
      status_2024 = factor(status_2024, levels = c("Not met", "On track", "Exceeded")),
      size_class  = cut(ten_year_target,
                        breaks = c(0, 5000, 20000, 60000, Inf),
                        labels = c("Small (<5k)", "Medium (5-20k)",
                                   "Large (20-60k)", "Major (60k+)"),
                        right = FALSE)
    )
}
