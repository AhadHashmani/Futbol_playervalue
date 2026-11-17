library(readr)
library(dplyr)

source("R/data_pipeline.R")
source("R/model_metrics.R")

stopifnot(
  identical(normalize_player_key("Aït Yahia"), normalize_player_key("Ait Yahia")),
  identical(normalize_league_name("LaLiga"), "La Liga")
)

stats_data <- read_csv(
  "all_leagues_stats.csv",
  col_types = cols(Age = col_character()),
  show_col_types = FALSE
)
market_data <- read_csv("market_values.csv", show_col_types = FALSE)
prepared <- prepare_player_market_data(stats_data, market_data)
joined <- prepared$joined
key_columns <- c("player_name_key", "birth_year", "season_start", "league")
joined_keys <- do.call(paste, c(joined[key_columns], sep = "\r"))

stopifnot(
  nrow(joined) > 0,
  !anyDuplicated(joined_keys),
  any(prepared$data_quality$Check == "FBref match rate (%)"),
  any(prepared$data_quality$Check == "Transfermarkt match rate (%)"),
  identical(
    sort(unique(joined$league)),
    sort(c("Bundesliga", "La Liga", "Ligue 1", "Premier League", "Serie A"))
  ),
  all(joined$player_market_value_euro > 0),
  all(joined$Min_Playing >= 450)
)

metrics <- calculate_regression_metrics(c(1, 2, 3), c(1, 2, 2))
stopifnot(
  isTRUE(all.equal(unname(metrics[["RMSE"]]), sqrt(1 / 3))),
  isTRUE(all.equal(unname(metrics[["MAE"]]), 1 / 3)),
  isTRUE(all.equal(unname(metrics[["R_squared"]]), 0.5))
)
stopifnot(
  isTRUE(all.equal(calculate_smearing_factor(c(log(2), log(4)), c(log(2), log(2))), 1.5)),
  isTRUE(all.equal(inverse_log_market_value(log(2)), 1)),
  isTRUE(all.equal(calculate_conformal_radius(1:4, rep(1, 4), coverage = 0.5), 2))
)

message(
  "All checks passed: ",
  nrow(joined),
  " unique matched player-season rows across five leagues."
)
