normalize_player_key <- function(value) {
  normalized <- stringi::stri_trans_general(as.character(value), "Latin-ASCII")
  normalized <- tolower(normalized)
  normalized <- gsub("[^a-z0-9]+", " ", normalized)
  trimws(gsub("\\s+", " ", normalized))
}

normalize_league_name <- function(value) {
  dplyr::recode(as.character(value), "LaLiga" = "La Liga", .default = as.character(value))
}

normalize_team_key <- function(value) {
  key <- normalize_player_key(value)
  key <- gsub(
    "\\b(de|del|da|do|fc|cf|sc|ac|afc|acf|as|ssc|ss|vfl|vfb|sv|tsg|rc|rcd|cd|us|uc|bc|osc|losc|club|calcio|balompie|futbol|deportivo|olympique|racing)\\b",
    " ",
    key
  )
  key <- gsub("\\b[0-9]+\\b", " ", key)
  key <- trimws(gsub("\\s+", " ", key))

  aliases <- c(
    "athletic bilbao" = "athletic",
    "bayern munich" = "bayern munchen",
    "bor monchengladbach" = "borussia monchengladbach",
    "celta vigo" = "celta",
    "inter" = "inter milan",
    "internazionale" = "inter milan",
    "internazionale milano" = "inter milan",
    "lazio roma" = "lazio",
    "lille osc" = "lille",
    "losc lille" = "lille",
    "lyonnais" = "lyon",
    "man utd" = "manchester united",
    "monchengladbach" = "borussia monchengladbach",
    "rayo vallecano madrid" = "rayo vallecano",
    "strasbourg alsace" = "strasbourg"
  )
  matched_alias <- match(key, names(aliases))
  key[!is.na(matched_alias)] <- unname(aliases[matched_alias[!is.na(matched_alias)]])
  key
}

add_prior_team_performance <- function(player_data, team_data) {
  player_required <- c("team_name", "league", "season")
  team_required <- c(
    "team_name", "league", "season_start", "matches_played",
    "points_per_game", "goal_difference_per_game", "table_position"
  )
  missing_player <- setdiff(player_required, names(player_data))
  missing_team <- setdiff(team_required, names(team_data))
  if (length(missing_player) > 0 || length(missing_team) > 0) {
    stop(
      "Missing required columns. Player data: ",
      paste(missing_player, collapse = ", "),
      "; team data: ",
      paste(missing_team, collapse = ", "),
      call. = FALSE
    )
  }

  team_keys <- c("team_key", "league", "season")
  team_data_keyed <- team_data %>%
    dplyr::transmute(
      team_key = normalize_team_key(team_name),
      league = normalize_league_name(league),
      season = as.integer(season_start) + 1L,
      team_matches_played_prior = as.numeric(matches_played),
      team_points_per_game_prior = as.numeric(points_per_game),
      team_goal_difference_per_game_prior = as.numeric(goal_difference_per_game),
      team_table_position_prior = as.numeric(table_position)
    )
  duplicate_team_keys <- team_data_keyed %>%
    dplyr::count(dplyr::across(dplyr::all_of(team_keys))) %>%
    dplyr::filter(n != 1L)
  if (nrow(duplicate_team_keys) > 0) {
    stop("Team data contains duplicate league-season-team keys.", call. = FALSE)
  }

  player_data_keyed <- player_data %>%
    dplyr::mutate(
      .team_join_key = normalize_team_key(team_name),
      .league_join_key = normalize_league_name(league),
      .season_join_key = as.integer(season)
    )
  joined <- player_data_keyed %>%
    dplyr::left_join(
      team_data_keyed,
      by = c(
        ".team_join_key" = "team_key",
        ".league_join_key" = "league",
        ".season_join_key" = "season"
      ),
      relationship = "many-to-one"
    ) %>%
    dplyr::select(-.team_join_key, -.league_join_key, -.season_join_key)

  joined
}

prepare_player_market_data <- function(stats_data, market_data, min_minutes = 450) {
  stats_required <- c(
    "Player", "Born", "Season_End_Year", "Comp", "Min_Playing", "Url",
    "Squad", "Nation", "Pos", "Age", "MP_Playing", "Starts_Playing",
    "Gls", "Ast", "G+A", "G_minus_PK", "PK", "PKatt", "CrdY", "CrdR",
    "PrgC_Progression", "PrgP_Progression", "PrgR_Progression",
    "xG_Expected", "npxG_Expected", "xAG_Expected"
  )
  market_required <- c(
    "player_name", "player_dob", "player_url", "comp_name",
    "season_start_year", "player_market_value_euro", "player_age",
    "player_position", "country", "squad"
  )
  missing_stats <- setdiff(stats_required, names(stats_data))
  missing_market <- setdiff(market_required, names(market_data))
  if (length(missing_stats) > 0 || length(missing_market) > 0) {
    stop(
      "Missing required columns. FBref: ",
      paste(missing_stats, collapse = ", "),
      "; Transfermarkt: ",
      paste(missing_market, collapse = ", "),
      call. = FALSE
    )
  }
  if (!is.numeric(min_minutes) ||
      length(min_minutes) != 1 ||
      !is.finite(min_minutes) ||
      min_minutes < 0) {
    stop("min_minutes must be one non-negative number.", call. = FALSE)
  }

  key_columns <- c("player_name_key", "birth_year", "season_start", "league")
  sum_columns <- c(
    "MP_Playing", "Starts_Playing", "Min_Playing", "Gls", "Ast", "G+A",
    "G_minus_PK", "PK", "PKatt", "CrdY", "CrdR", "PrgC_Progression",
    "PrgP_Progression", "PrgR_Progression", "xG_Expected",
    "npxG_Expected", "xAG_Expected"
  )

  stats_keyed <- stats_data %>%
    dplyr::mutate(
      player_name_key = normalize_player_key(Player),
      birth_year = suppressWarnings(as.integer(Born)),
      season_start = as.integer(Season_End_Year) - 1L,
      league = normalize_league_name(Comp)
    ) %>%
    dplyr::filter(
      !is.na(player_name_key),
      !is.na(birth_year),
      !is.na(season_start),
      !is.na(Url)
    )

  stats_key_counts <- stats_keyed %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(key_columns))) %>%
    dplyr::summarise(
      source_ids = dplyr::n_distinct(Url),
      .groups = "drop"
    )
  ambiguous_stats_keys <- sum(stats_key_counts$source_ids != 1L)

  sum_if_present <- function(values) {
    if (all(is.na(values))) NA_real_ else sum(as.numeric(values), na.rm = TRUE)
  }

  stats_clean <- stats_keyed %>%
    dplyr::inner_join(
      dplyr::filter(stats_key_counts, source_ids == 1L),
      by = key_columns
    ) %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(key_columns))) %>%
    dplyr::summarise(
      Player = dplyr::first(Player),
      Squad = paste(sort(unique(Squad)), collapse = "; "),
      Comp = dplyr::first(Comp),
      Nation = dplyr::first(Nation),
      Pos = dplyr::first(Pos),
      Age = dplyr::first(Age),
      Born = dplyr::first(Born),
      Url = dplyr::first(Url),
      Season_End_Year = dplyr::first(Season_End_Year),
      dplyr::across(dplyr::all_of(sum_columns), sum_if_present),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      Mins_Per_90_Playing = Min_Playing / 90,
      Gls_Per = Gls / pmax(Mins_Per_90_Playing, 1),
      Ast_Per = Ast / pmax(Mins_Per_90_Playing, 1),
      `G+A_Per` = `G+A` / pmax(Mins_Per_90_Playing, 1),
      xG_Per = xG_Expected / pmax(Mins_Per_90_Playing, 1),
      xAG_Per = xAG_Expected / pmax(Mins_Per_90_Playing, 1)
    ) %>%
    dplyr::filter(Min_Playing >= min_minutes)

  market_keyed <- market_data %>%
    dplyr::mutate(
      player_name_key = normalize_player_key(player_name),
      birth_year = suppressWarnings(as.integer(format(as.Date(player_dob), "%Y"))),
      season_start = as.integer(season_start_year),
      league = normalize_league_name(comp_name)
    ) %>%
    dplyr::filter(
      !is.na(player_name_key),
      !is.na(birth_year),
      !is.na(season_start),
      !is.na(player_url),
      is.finite(player_market_value_euro),
      player_market_value_euro > 0
    )

  market_key_counts <- market_keyed %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(key_columns))) %>%
    dplyr::summarise(
      source_ids = dplyr::n_distinct(player_url),
      valuations = dplyr::n_distinct(player_market_value_euro),
      .groups = "drop"
    )
  ambiguous_market_keys <- sum(
    market_key_counts$source_ids != 1L | market_key_counts$valuations != 1L
  )

  market_clean <- market_keyed %>%
    dplyr::inner_join(
      dplyr::filter(market_key_counts, source_ids == 1L, valuations == 1L),
      by = key_columns
    ) %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(key_columns))) %>%
    dplyr::summarise(
      comp_name = dplyr::first(comp_name),
      country = dplyr::first(country),
      season_start_year = dplyr::first(season_start_year),
      player_name = dplyr::first(player_name),
      player_position = dplyr::first(player_position),
      player_age = dplyr::first(player_age),
      player_dob = dplyr::first(player_dob),
      player_url = dplyr::first(player_url),
      squad = dplyr::first(squad),
      player_market_value_euro = dplyr::first(player_market_value_euro),
      market_value_m = player_market_value_euro / 1e6,
      .groups = "drop"
    )

  if (nrow(stats_clean) == 0 || nrow(market_clean) == 0) {
    stop("No eligible source records remain after identity and value checks.", call. = FALSE)
  }

  joined <- dplyr::inner_join(
    stats_clean,
    market_clean,
    by = key_columns,
    relationship = "one-to-one",
    na_matches = "never"
  )
  if (nrow(joined) == 0) {
    stop("No player-season records matched across both sources.", call. = FALSE)
  }

  data_quality <- tibble::tibble(
    Check = c(
      "FBref input rows",
      "Transfermarkt input rows",
      "FBref rows missing a usable identity key",
      "Transfermarkt rows missing a usable identity key or positive value",
      "Ambiguous FBref player-season keys excluded",
      "Ambiguous Transfermarkt player-season keys excluded",
      "FBref rows after aggregation and minutes filter",
      "Transfermarkt rows after deduplication",
      "Matched player-season records",
      "Unmatched FBref records",
      "Unmatched Transfermarkt records",
      "FBref match rate (%)",
      "Transfermarkt match rate (%)"
    ),
    Value = c(
      nrow(stats_data),
      nrow(market_data),
      nrow(stats_data) - nrow(stats_keyed),
      nrow(market_data) - nrow(market_keyed),
      ambiguous_stats_keys,
      ambiguous_market_keys,
      nrow(stats_clean),
      nrow(market_clean),
      nrow(joined),
      nrow(dplyr::anti_join(stats_clean, market_clean, by = key_columns)),
      nrow(dplyr::anti_join(market_clean, stats_clean, by = key_columns)),
      100 * nrow(joined) / nrow(stats_clean),
      100 * nrow(joined) / nrow(market_clean)
    )
  )

  list(joined = joined, data_quality = data_quality)
}
