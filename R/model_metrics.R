inverse_log_market_value <- function(predicted_log_value, smearing_factor = 1) {
  if (any(!is.finite(predicted_log_value)) ||
      length(smearing_factor) != 1 ||
      !is.finite(smearing_factor) ||
      smearing_factor <= 0) {
    stop("Predictions and smearing factor must be finite; smearing must be positive.", call. = FALSE)
  }
  pmax(exp(predicted_log_value) * smearing_factor - 1, 0)
}

calculate_smearing_factor <- function(actual_log_value, predicted_log_value) {
  if (length(actual_log_value) != length(predicted_log_value) || length(actual_log_value) == 0) {
    stop("Smearing inputs must have equal, non-zero lengths.", call. = FALSE)
  }
  if (any(!is.finite(actual_log_value)) || any(!is.finite(predicted_log_value))) {
    stop("Smearing inputs must contain only finite values.", call. = FALSE)
  }
  factor <- mean(exp(actual_log_value - predicted_log_value))
  if (!is.finite(factor) || factor <= 0) {
    stop("Unable to calculate a finite positive smearing factor.", call. = FALSE)
  }
  factor
}

calculate_regression_metrics <- function(actual, predicted) {
  if (length(actual) != length(predicted) || length(actual) == 0) {
    stop("Metric inputs must have equal, non-zero lengths.", call. = FALSE)
  }
  if (any(!is.finite(actual)) || any(!is.finite(predicted))) {
    stop("Metric inputs must contain only finite values.", call. = FALSE)
  }

  squared_error <- sum((actual - predicted)^2)
  total_sum_squares <- sum((actual - mean(actual))^2)
  c(
    RMSE = sqrt(mean((actual - predicted)^2)),
    MAE = mean(abs(actual - predicted)),
    R_squared = if (total_sum_squares == 0) NA_real_ else 1 - squared_error / total_sum_squares
  )
}

calculate_conformal_radius <- function(actual, predicted, coverage = 0.9) {
  if (length(actual) != length(predicted) || length(actual) == 0) {
    stop("Conformal inputs must have equal, non-zero lengths.", call. = FALSE)
  }
  if (any(!is.finite(actual)) || any(!is.finite(predicted))) {
    stop("Conformal inputs must contain only finite values.", call. = FALSE)
  }
  if (!is.finite(coverage) || coverage <= 0 || coverage >= 1) {
    stop("coverage must be between 0 and 1.", call. = FALSE)
  }

  residuals <- sort(abs(actual - predicted))
  rank <- min(ceiling((length(residuals) + 1) * coverage), length(residuals))
  residuals[[rank]]
}
