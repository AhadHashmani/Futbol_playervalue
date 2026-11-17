library(readr)
library(dplyr)

source("R/data_pipeline.R")
source("R/model_metrics.R")

stopifnot(
  identical(normalize_player_key("Aït Yahia"), normalize_player_key("Ait Yahia")),
  identical(normalize_league_name("LaLiga"), "La Liga"),
  identical(normalize_team_key("Bayern Munich"), normalize_team_key("Bayern München")),
  identical(normalize_team_key("Athletic Bilbao"), normalize_team_key("Athletic Club"))
)

stats_data <- read_csv(
  "ststistics from all leagues.csv",
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

team_data <- read_csv("data/team_season_performance.csv", show_col_types = FALSE)
player_context <- add_prior_team_performance(
  joined %>% transmute(team_name = squad, league, season = season_start),
  team_data
)
test_season_context <- player_context %>% filter(season == max(season))
stopifnot(
  nrow(team_data) > 900,
  dplyr::n_distinct(team_data$league) == 5,
  nrow(dplyr::distinct(team_data, league, season_start)) == 50,
  nrow(player_context) == nrow(joined),
  mean(!is.na(test_season_context$team_points_per_game_prior)) >= 0.6
)

fixture_context <- add_prior_team_performance(
  tibble::tibble(
    team_name = c("Bayern Munich", "Athletic Bilbao", "Newly Promoted"),
    league = c("Bundesliga", "La Liga", "Premier League"),
    season = c(2023L, 2023L, 2023L)
  ),
  tibble::tibble(
    team_name = c("Bayern München", "Athletic Club"),
    league = c("Bundesliga", "La Liga"),
    season_start = c(2022L, 2022L),
    matches_played = c(34L, 38L),
    points_per_game = c(2.4, 1.8),
    goal_difference_per_game = c(1.7, 0.4),
    table_position = c(1L, 8L)
  )
)
stopifnot(
  identical(fixture_context$team_points_per_game_prior[1:2], c(2.4, 1.8)),
  is.na(fixture_context$team_points_per_game_prior[[3]])
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
