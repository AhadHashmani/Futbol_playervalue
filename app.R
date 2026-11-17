library(shiny)
library(readr)
library(dplyr)
library(ggplot2)

required_outputs <- c("player_valuations.csv", "model_comparison.csv", "evaluation_summary.csv")
missing_outputs <- required_outputs[!file.exists(required_outputs)]
if (length(missing_outputs) > 0) {
  stop(
    "Run player_market_value_analysis.Rmd first; missing outputs: ",
    paste(missing_outputs, collapse = ", "),
    call. = FALSE
  )
}

valuations <- read_csv("player_valuations.csv", show_col_types = FALSE)
comparison <- read_csv("model_comparison.csv", show_col_types = FALSE)
evaluation <- read_csv("evaluation_summary.csv", show_col_types = FALSE)
selected_metrics <- comparison %>%
  filter(Model == evaluation$selected_model[[1]])

ui <- fluidPage(
  titlePanel("Player Market Value Explorer"),
  p(
    "Observed Transfermarkt values compared with a season-based model. ",
    "Gaps are descriptive, not evidence of market mispricing. Team context uses prior-season results ",
    "and is not a causal estimate of an individual player's impact."
  ),
  sidebarLayout(
    sidebarPanel(
      selectInput("league", "League", choices = c("All", sort(unique(valuations$league)))),
      selectInput("position", "Position", choices = c("All", sort(unique(valuations$position)))),
      selectInput(
        "gap_status",
        "Model gap",
        choices = c("All", sort(unique(valuations$gap_status)))
      ),
      downloadButton("download", "Download filtered players")
    ),
    mainPanel(
      h4(textOutput("evaluation_summary")),
      plotOutput("value_plot", height = "450px"),
      h4("Largest relative gaps and prior-season team context"),
      tableOutput("players")
    )
  )
)

server <- function(input, output, session) {
  filtered_valuations <- reactive({
    result <- valuations
    if (input$league != "All") {
      result <- filter(result, league == input$league)
    }
    if (input$position != "All") {
      result <- filter(result, position == input$position)
    }
    if (input$gap_status != "All") {
      result <- filter(result, gap_status == input$gap_status)
    }
    result
  })

  output$evaluation_summary <- renderText({
    metric <- selected_metrics[1, ]
    paste0(
      "Test season ", evaluation$test_season[[1]],
      " | Selected model: ", evaluation$selected_model[[1]],
      " | Test RMSE: €", round(metric$Test_RMSE_EUR_M, 2), "M",
      " | 90% interval coverage: ",
      round(evaluation$observed_test_interval_coverage[[1]] * 100, 1), "%"
    )
  })

  output$value_plot <- renderPlot({
    ggplot(filtered_valuations(), aes(x = predicted_value, y = actual_value, color = gap_status)) +
      geom_errorbar(
        aes(ymin = prediction_lower_90, ymax = prediction_upper_90),
        alpha = 0.15,
        width = 0
      ) +
      geom_point(alpha = 0.65) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
      labs(
        x = "Model estimate (€M)",
        y = "Observed value (€M)",
        color = "Model gap"
      ) +
      theme_minimal()
  })

  output$players <- renderTable({
    filtered_valuations() %>%
      arrange(desc(abs(valuation_gap_pct))) %>%
      select(
        player_name, team_name, age, position, league,
        team_matches_played_prior, team_points_per_game_prior,
        team_goal_difference_per_game_prior,
        team_table_position_prior, actual_value, predicted_value,
        prediction_lower_90, prediction_upper_90, valuation_gap_pct, gap_status
      ) %>%
      rename(
        Player = player_name,
        Club = team_name,
        Age = age,
        Position = position,
        League = league,
        `Prior team matches` = team_matches_played_prior,
        `Prior team points/game` = team_points_per_game_prior,
        `Prior team goal difference/game` = team_goal_difference_per_game_prior,
        `Prior team position` = team_table_position_prior,
        `Observed value (€M)` = actual_value,
        `Model estimate (€M)` = predicted_value,
        `90% lower (€M)` = prediction_lower_90,
        `90% upper (€M)` = prediction_upper_90,
        `Gap (%)` = valuation_gap_pct,
        `Model gap category` = gap_status
      ) %>%
      head(30)
  }, digits = 2)

  output$download <- downloadHandler(
    filename = function() paste0("player-valuation-gaps-", evaluation$test_season[[1]], ".csv"),
    content = function(file) write_csv(filtered_valuations(), file)
  )
}

shinyApp(ui, server)
