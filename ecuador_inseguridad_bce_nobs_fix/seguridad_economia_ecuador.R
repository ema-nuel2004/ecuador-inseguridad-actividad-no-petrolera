
# Seguridad, toques de queda y actividad economica no petrolera en Ecuador
# Periodo: enero 2022 - marzo 2026

options(stringsAsFactors = FALSE)
required_packages <- c("readr", "dplyr", "lubridate", "ggplot2", "sandwich", "lmtest", "broom")
missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
if (length(missing_packages) > 0) install.packages(missing_packages)

library(readr)
library(dplyr)
library(lubridate)
library(ggplot2)
library(sandwich)
library(lmtest)
library(broom)

get_project_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_path <- normalizePath(sub(file_arg, "", args[grepl(file_arg, args)]), mustWork = FALSE)
  if (length(script_path) > 0 && file.exists(script_path[1])) return(dirname(script_path[1]))
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    path <- rstudioapi::getActiveDocumentContext()$path
    if (!is.null(path) && nzchar(path)) return(dirname(path))
  }
  getwd()
}

project_dir <- get_project_dir()
setwd(project_dir)
invisible(lapply(c("data/processed", "outputs/tables", "outputs/figures", "conclusions"), dir.create, recursive = TRUE, showWarnings = FALSE))

imaec <- read_csv("data/essential/bce_imaec_202603_extracted.csv", show_col_types = FALSE) %>% mutate(date = as.Date(date))
homicidios <- read_csv("data/essential/homicidios_mensual_2022_2026.csv", show_col_types = FALSE) %>% mutate(date = as.Date(date))
curfews_raw <- read_csv("data/essential/curfews_ecuador_2022_2026.csv", show_col_types = FALSE) %>% mutate(start_date = as.Date(start_date), end_date = as.Date(end_date))
cutoff <- read_csv("data/essential/analysis_cutoff.csv", show_col_types = FALSE)
analysis_start <- as.Date(cutoff$analysis_start[1])
analysis_cutoff <- as.Date(cutoff$analysis_cutoff[1])

month_sequence <- tibble(date = seq(analysis_start, floor_date(analysis_cutoff, "month"), by = "month"))
curfew_panel <- month_sequence %>%
  rowwise() %>%
  mutate(
    month_end = ceiling_date(date, "month") - days(1),
    days_in_month = as.integer(month_end - date + 1),
    curfew_days = sum(pmax(0, as.integer(pmin(month_end, curfews_raw$end_date) - pmax(date, curfews_raw$start_date) + 1))),
    curfew_intensity = sum(pmax(0, as.integer(pmin(month_end, curfews_raw$end_date) - pmax(date, curfews_raw$start_date) + 1)) / days_in_month * curfews_raw$population_weight * curfews_raw$hours_restricted_per_day / 24)
  ) %>% ungroup() %>% select(date, curfew_days, curfew_intensity)

panel <- imaec %>%
  filter(date >= analysis_start, date <= floor_date(analysis_cutoff, "month")) %>%
  left_join(homicidios, by = "date") %>%
  left_join(curfew_panel, by = "date") %>%
  arrange(date) %>%
  mutate(
    dlog_imaec_no_petrolero = 100 * (log(imaec_no_petrolero) - lag(log(imaec_no_petrolero))),
    dlog_imaec_petrolero = 100 * (log(imaec_petrolero) - lag(log(imaec_petrolero))),
    dlog_imaec_total = 100 * (log(imaec_total) - lag(log(imaec_total))),
    dlog_imaec_vulnerable = 100 * (log(imaec_vulnerable) - lag(log(imaec_vulnerable))),
    dlog_no_petrolero_l1 = lag(dlog_imaec_no_petrolero, 1),
    dlog_vulnerable_l1 = lag(dlog_imaec_vulnerable, 1),
    dlog_petrolero_l1 = lag(dlog_imaec_petrolero, 1),
    homicidios_100k_anualizado_l1 = lag(homicidios_100k_anualizado, 1),
    homicidios_100k_anualizado_l2 = lag(homicidios_100k_anualizado, 2),
    curfew_intensity_l1 = lag(curfew_intensity, 1),
    month = month(date),
    trend = row_number(),
    season_sin = sin(2 * pi * month / 12),
    season_cos = cos(2 * pi * month / 12)
  )
write_csv(panel, "data/processed/panel_mensual_analisis.csv")

model_nobs <- function(model) {
  mf <- tryCatch(stats::model.frame(model), error = function(e) NULL)
  if (!is.null(mf)) return(nrow(mf))
  rr <- tryCatch(stats::residuals(model), error = function(e) NULL)
  if (!is.null(rr)) return(length(rr))
  return(NA_integer_)
}

model_r2_adj <- function(model) {
  out <- tryCatch(summary(model)$adj.r.squared, error = function(e) NA_real_)
  as.numeric(out)
}

model_rmse <- function(model) {
  rr <- tryCatch(stats::residuals(model), error = function(e) NULL)
  if (is.null(rr)) return(NA_real_)
  sqrt(mean(rr^2, na.rm = TRUE))
}

safe_newey_west <- function(model, lag_value = 3) {
  n <- model_nobs(model)
  lag_use <- ifelse(is.na(n), lag_value, max(0, min(lag_value, n - 1)))
  tryCatch(
    sandwich::NeweyWest(model, lag = lag_use, prewhite = FALSE, adjust = TRUE),
    error = function(e1) {
      message("Aviso: Newey-West no pudo calcularse para un modelo. Se usa HC1 como respaldo. Detalle: ", e1$message)
      tryCatch(
        sandwich::vcovHC(model, type = "HC1"),
        error = function(e2) {
          message("Aviso: HC1 tampoco pudo calcularse. Se usa la matriz clasica de varianza-covarianza.")
          stats::vcov(model)
        }
      )
    }
  )
}

model_table_nw <- function(model, model_name, dependent) {
  nw <- safe_newey_west(model, lag_value = 3)
  ct <- lmtest::coeftest(model, vcov. = nw)
  tibble(
    model = model_name,
    dependent = dependent,
    term = rownames(ct),
    estimate = as.numeric(ct[, 1]),
    std_error_nw = as.numeric(ct[, 2]),
    t_value = as.numeric(ct[, 3]),
    p_value = as.numeric(ct[, 4]),
    nobs = model_nobs(model),
    r2_adj = model_r2_adj(model),
    rmse = model_rmse(model)
  )
}

diagnostics_table <- function(model, model_name) {
  bg <- tryCatch(lmtest::bgtest(model, order = 3), error = function(e) NULL)
  bp <- tryCatch(lmtest::bptest(model), error = function(e) NULL)
  dw <- tryCatch(lmtest::dwtest(model), error = function(e) NULL)
  tibble(
    model = model_name,
    nobs = model_nobs(model),
    r2_adj = model_r2_adj(model),
    rmse = model_rmse(model),
    durbin_watson = ifelse(is.null(dw), NA_real_, as.numeric(dw$statistic[[1]])),
    breusch_godfrey_lag3_p_value = ifelse(is.null(bg), NA_real_, bg$p.value),
    breusch_pagan_p_value = ifelse(is.null(bp), NA_real_, bp$p.value)
  )
}

base_data <- panel %>% filter(!is.na(dlog_imaec_no_petrolero), !is.na(dlog_no_petrolero_l1), !is.na(homicidios_100k_anualizado_l1), !is.na(curfew_intensity), !is.na(dlog_imaec_petrolero))
lag_data <- panel %>% filter(!is.na(dlog_imaec_no_petrolero), !is.na(homicidios_100k_anualizado_l2), !is.na(curfew_intensity_l1), !is.na(dlog_imaec_petrolero))

m_ardl_np <- lm(dlog_imaec_no_petrolero ~ dlog_no_petrolero_l1 + homicidios_100k_anualizado + homicidios_100k_anualizado_l1 + curfew_intensity + dlog_imaec_petrolero + trend + season_sin + season_cos, data = base_data)
m_ardl_v <- lm(dlog_imaec_vulnerable ~ dlog_vulnerable_l1 + homicidios_100k_anualizado + homicidios_100k_anualizado_l1 + curfew_intensity + dlog_imaec_petrolero + trend + season_sin + season_cos, data = base_data)
m_ardl_p <- lm(dlog_imaec_petrolero ~ dlog_petrolero_l1 + homicidios_100k_anualizado + homicidios_100k_anualizado_l1 + curfew_intensity + trend + season_sin + season_cos, data = base_data)

m_base <- lm(dlog_imaec_no_petrolero ~ homicidios_100k_anualizado + curfew_intensity + dlog_imaec_petrolero + trend + season_sin + season_cos, data = base_data)
m_vulnerable <- lm(dlog_imaec_vulnerable ~ homicidios_100k_anualizado + curfew_intensity + dlog_imaec_petrolero + trend + season_sin + season_cos, data = base_data)
m_lags <- lm(dlog_imaec_no_petrolero ~ homicidios_100k_anualizado + homicidios_100k_anualizado_l1 + homicidios_100k_anualizado_l2 + curfew_intensity + curfew_intensity_l1 + dlog_imaec_petrolero + trend + season_sin + season_cos, data = lag_data)

coef_table <- bind_rows(
  model_table_nw(m_ardl_np, "ARDL_no_petrolero", "dlog_imaec_no_petrolero"),
  model_table_nw(m_ardl_v, "ARDL_actividad_vulnerable", "dlog_imaec_vulnerable"),
  model_table_nw(m_ardl_p, "ARDL_placebo_petrolero", "dlog_imaec_petrolero"),
  model_table_nw(m_base, "base_no_petrolero", "dlog_imaec_no_petrolero"),
  model_table_nw(m_vulnerable, "actividad_vulnerable", "dlog_imaec_vulnerable"),
  model_table_nw(m_lags, "rezagos_no_petrolero", "dlog_imaec_no_petrolero")
)
write_csv(coef_table, "outputs/tables/model_coefficients_newey_west.csv")
write_csv(coef_table %>% filter(grepl("^ARDL", model)), "outputs/tables/modelos_principales_ardl_newey_west.csv")

diag_table <- bind_rows(
  diagnostics_table(m_ardl_np, "ARDL_no_petrolero"),
  diagnostics_table(m_ardl_v, "ARDL_actividad_vulnerable"),
  diagnostics_table(m_ardl_p, "ARDL_placebo_petrolero"),
  diagnostics_table(m_base, "base_no_petrolero"),
  diagnostics_table(m_vulnerable, "actividad_vulnerable"),
  diagnostics_table(m_lags, "rezagos_no_petrolero")
)
write_csv(diag_table, "outputs/tables/diagnosticos_econometricos.csv")

effects <- tibble(
  model = c("ARDL_no_petrolero", "ARDL_no_petrolero", "ARDL_actividad_vulnerable", "ARDL_actividad_vulnerable", "ARDL_no_petrolero"),
  effect = c("impacto_acumulado_homicidios_t_t1", "multiplicador_dinamico_homicidios", "impacto_acumulado_homicidios_t_t1", "multiplicador_dinamico_homicidios", "efecto_toque_queda_contemporaneo"),
  estimate = c(
    coef(m_ardl_np)["homicidios_100k_anualizado"] + coef(m_ardl_np)["homicidios_100k_anualizado_l1"],
    (coef(m_ardl_np)["homicidios_100k_anualizado"] + coef(m_ardl_np)["homicidios_100k_anualizado_l1"]) / (1 - coef(m_ardl_np)["dlog_no_petrolero_l1"]),
    coef(m_ardl_v)["homicidios_100k_anualizado"] + coef(m_ardl_v)["homicidios_100k_anualizado_l1"],
    (coef(m_ardl_v)["homicidios_100k_anualizado"] + coef(m_ardl_v)["homicidios_100k_anualizado_l1"]) / (1 - coef(m_ardl_v)["dlog_vulnerable_l1"]),
    coef(m_ardl_np)["curfew_intensity"]
  )
)
write_csv(effects, "outputs/tables/efectos_dinamicos_ardl.csv")

summary_table <- tibble(
  indicador = c("periodo", "observaciones_panel", "obs_modelo_ardl", "ultimo_imaec", "homicidios_promedio_mensual", "homicidios_min", "homicidios_max", "mes_homicidios_max", "curfew_months_in_sample", "r2_adj_ardl_no_petrolero", "r2_adj_ardl_vulnerable"),
  valor = c(paste(min(panel$date), max(panel$date), sep = " a "), nrow(panel), model_nobs(m_ardl_np), max(panel$date), round(mean(panel$homicidios), 2), min(panel$homicidios), max(panel$homicidios), panel$date[which.max(panel$homicidios)], sum(panel$curfew_intensity > 0), round(summary(m_ardl_np)$adj.r.squared, 3), round(summary(m_ardl_v)$adj.r.squared, 3))
)
write_csv(summary_table, "outputs/tables/resumen_descriptivo.csv")

ggplot(panel, aes(x = date)) + geom_line(aes(y = imaec_no_petrolero, linetype = "IMAEc no petrolero"), linewidth = 0.8) + geom_line(aes(y = imaec_vulnerable, linetype = "Indice vulnerable"), linewidth = 0.8) + labs(title = "Actividad no petrolera y actividad vulnerable", x = NULL, y = "Indice 2018 = 100", linetype = NULL) + theme_minimal()
ggsave("outputs/figures/actividad_no_petrolera_vulnerable.png", width = 9, height = 5, dpi = 160)

ggplot(panel, aes(x = date, y = homicidios)) + geom_col() + labs(title = "Homicidios mensuales utilizados en el analisis", x = NULL, y = "Homicidios") + theme_minimal()
ggsave("outputs/figures/homicidios_mensuales.png", width = 9, height = 5, dpi = 160)

ggplot(panel, aes(x = date)) + geom_line(aes(y = dlog_imaec_no_petrolero, linetype = "No petrolero"), linewidth = 0.8, na.rm = TRUE) + geom_line(aes(y = dlog_imaec_vulnerable, linetype = "Vulnerable"), linewidth = 0.8, na.rm = TRUE) + geom_hline(yintercept = 0) + labs(title = "Crecimiento mensual de la actividad", x = NULL, y = "Variacion logaritmica mensual (%)", linetype = NULL) + theme_minimal()
ggsave("outputs/figures/crecimiento_mensual.png", width = 9, height = 5, dpi = 160)

plot_coef <- coef_table %>% filter(model %in% c("ARDL_no_petrolero", "ARDL_actividad_vulnerable", "ARDL_placebo_petrolero"), term %in% c("homicidios_100k_anualizado", "homicidios_100k_anualizado_l1", "curfew_intensity")) %>% mutate(ci_low = estimate - 1.96 * std_error_nw, ci_high = estimate + 1.96 * std_error_nw, label = paste(model, term, sep = " | "))

ggplot(plot_coef, aes(x = estimate, y = reorder(label, estimate))) + geom_point() + geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0.15) + geom_vline(xintercept = 0) + labs(title = "Coeficientes ARDL principales con intervalos Newey-West", x = "Estimacion", y = NULL) + theme_minimal()
ggsave("outputs/figures/coeficientes_principales.png", width = 9, height = 5, dpi = 160)

get_row <- function(model_name, term_name) coef_table %>% filter(model == model_name, term == term_name) %>% slice(1)
np_lag <- get_row("ARDL_no_petrolero", "homicidios_100k_anualizado_l1")
np_curf <- get_row("ARDL_no_petrolero", "curfew_intensity")
v_lag <- get_row("ARDL_actividad_vulnerable", "homicidios_100k_anualizado_l1")
p_lag <- get_row("ARDL_placebo_petrolero", "homicidios_100k_anualizado_l1")

conclusion <- c(
  "# Conclusion econometrica actualizada", "",
  paste0("Fecha de ejecucion: ", Sys.Date()), "",
  paste0("Ventana empirica efectiva: ", min(panel$date), " a ", max(panel$date), "."), "",
  "El modelo principal es un ARDL mensual con errores Newey-West. Esta especificacion permite que la inseguridad afecte con rezago a la actividad economica no petrolera.", "",
  paste0("Rezago de homicidios en el modelo no petrolero: ", round(np_lag$estimate, 4), "; error estandar Newey-West: ", round(np_lag$std_error_nw, 4), "; p-valor: ", round(np_lag$p_value, 4), "."),
  paste0("Toque de queda contemporaneo en el modelo no petrolero: ", round(np_curf$estimate, 4), "; p-valor: ", round(np_curf$p_value, 4), "."),
  paste0("Rezago de homicidios en actividad vulnerable: ", round(v_lag$estimate, 4), "; p-valor: ", round(v_lag$p_value, 4), "."),
  paste0("Rezago de homicidios en placebo petrolero: ", round(p_lag$estimate, 4), "; p-valor: ", round(p_lag$p_value, 4), "."), "",
  "La lectura economica central es que la inseguridad funciona como un shock de costos de transaccion y demanda presencial. Afecta movilidad, horarios efectivos, confianza del consumidor y decisiones de inversion local. Por eso el contraste con el sector petrolero es importante: si la relacion se concentra en la actividad no petrolera y vulnerable, el canal social es mas plausible.", "",
  "La muestra se corta en marzo de 2026 porque ese es el ultimo mes disponible en el archivo IMAEc usado. El objetivo inicial era llegar a mayo de 2026 por el ultimo toque de queda, pero esa extension se incorpora cuando el BCE publique esos indices. No se imputan meses sin IMAEc oficial."
)
writeLines(conclusion, "conclusions/conclusion_econometrica_actualizada.md")
message("Analisis terminado. Revise outputs/tables, outputs/figures y conclusions/conclusion_econometrica_actualizada.md")
