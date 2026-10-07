# ============================================================
# 04_2D_Synthetic_Sensitivity.R
# ============================================================
#
# Consolidated revised 2D synthetic sensitivity analysis.
#


rm(list = ls())
gc()

# ============================================================
# Paths
# ============================================================

# Run from the repository's root folder.
project_directory <- "."
scripts_directory <- file.path(project_directory, "Scripts")
analysis_root_directory <- file.path(
  project_directory,
  "Results",
  "2D_Synthetic_sqrtNB_q099"
)
locked_input_directory <- file.path(analysis_root_directory, "00_Locked_Inputs")
baseline_output_directory <- file.path(analysis_root_directory, "01_Baseline_Fits")
geometry_output_directory <- file.path(analysis_root_directory, "02_Geometry")
topology_output_directory <- file.path(analysis_root_directory, "03_Topology")
sensitivity_output_directory <- file.path(analysis_root_directory, "04_Sensitivity")
model_object_directory <- file.path(sensitivity_output_directory, "model_objects")

for (d in c(sensitivity_output_directory, model_object_directory)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# ============================================================
# Authoritative QPH implementation
# ============================================================

qph_core_file <- file.path(scripts_directory, "00_QPH_Core_Functions.R")
if (!file.exists(qph_core_file)) {
  stop("Missing authoritative QPH core: ", qph_core_file)
}
source(qph_core_file, local = FALSE)

expected_qph_core_version <- "sqrtNB_q099_v1"
if (
  !exists("QPH_CORE_VERSION", inherits = TRUE) ||
    !identical(as.character(QPH_CORE_VERSION), expected_qph_core_version)
) {
  stop("Unexpected QPH core version.")
}
qph_core_md5 <- unname(tools::md5sum(qph_core_file))

# ============================================================
# Packages
# ============================================================

required_packages <- c("hypervolume", "e1071", "TDAstats", "TDA", "R.utils")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop("Install required package(s): ", paste(missing_packages, collapse = ", "))
}

library(hypervolume)
library(e1071)
library(TDAstats)
library(TDA)
library(R.utils)

# ============================================================
# Locked design
# ============================================================

expected_shape_names <- c("spiral", "ellipse", "annulus", "banana", "two_balls")
shape_labels <- c(
  spiral = "Spiral band",
  ellipse = "Filled ellipse",
  annulus = "Annulus",
  banana = "Concave banana",
  two_balls = "Two separated disks"
)
method_order <- c("Gaussian KDE", "SVM", "QPH")

sensitivity_sample_size <- 900L
baseline_samples_per_point <- 100L
baseline_sd_count <- 3

qph_bandwidth_multipliers <- c(0.75, 1.00, 1.25)
qph_baseline_q <- 0.99
qph_q_values <- c(0.950, 0.975, 0.990)

kde_bandwidth_multipliers <- c(0.75, 1.00, 1.25)
kde_baseline_quantile <- 0.95
kde_quantile_values <- c(0.925, 0.950, 0.975)

samples_per_point_values <- c(25L, 50L, 100L, 150L)

svm_baseline_nu <- 0.010
svm_nu_values <- c(
  0.005,
  0.010,
  0.015
)

svm_baseline_gamma <- 0.50
svm_gamma_values <- c(
  0.25,
  0.50,
  0.75
)
svm_scale_factor <- 1

shared_chunk_size <- 100L
potential_batch_size <- 500L
show_progress_messages <- TRUE

sensitivity_fit_seed_base <- 61001L
sensitivity_geometry_seed_base <- 71001L
sensitivity_topology_seed_base <- 81001L
matched_reference_seed_base <- 2100001L

resume_model_fits <- TRUE
resume_geometry <- TRUE
resume_topology <- TRUE
resume_matched_reference <- TRUE
retry_failed_model_fits <- TRUE
retry_failed_geometry <- TRUE
retry_failed_topology <- TRUE
retry_failed_matched_reference <- TRUE

jaccard_num_points_max <- 10000L
jaccard_distance_factor <- 1

ph_sample_size <- 300L
number_of_topology_repetitions <- 10L
maximum_homology_dimension <- 1L
ph_threshold <- -1
ph_prime_field <- 2L
ph_standardize <- FALSE
ph_timeout_seconds <- 6 * 60
number_of_matched_reference_replicates <- 20L

diagnostic_dimension <- c(
  spiral = 1L,
  ellipse = 1L,
  annulus = 1L,
  banana = 1L,
  two_balls = 0L
)
diagnostic_label <- c(
  spiral = "Spiral band: H1",
  ellipse = "Filled ellipse: H1",
  annulus = "Annulus: H1",
  banana = "Concave banana: H1",
  two_balls = "Two separated disks: finite H0"
)

# Fixed colours retained from the revised manuscript figures.
method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)
true_region_colour <- "#D9D9D9"
occurrence_colour <- "#111111"

# ============================================================
# Inputs
# ============================================================

occurrence_archive_file <- file.path(
  locked_input_directory,
  "synthetic_occurrence_clouds_authoritative.rds"
)
baseline_results_file <- file.path(
  baseline_output_directory,
  "baseline_fit_results_sqrtNB_q099.rds"
)
geometry_results_file <- file.path(
  geometry_output_directory,
  "synthetic_geometry_results_sqrtNB_q099.rds"
)
baseline_topology_subsample_file <- file.path(
  topology_output_directory,
  "topology_subsample_indices_sqrtNB_q099.rds"
)
baseline_persistence_file <- file.path(
  topology_output_directory,
  "persistence_diagrams_sqrtNB_q099.rds"
)

required_input_files <- c(
  occurrence_archive_file,
  baseline_results_file,
  geometry_results_file,
  baseline_topology_subsample_file,
  baseline_persistence_file
)
missing_input_files <- required_input_files[!file.exists(required_input_files)]
if (length(missing_input_files) > 0L) {
  stop(
    "Missing required revised input(s):\n  ",
    paste(missing_input_files, collapse = "\n  ")
  )
}

# ============================================================
# Outputs
# ============================================================

sensitivity_design_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_design_2D_sqrtNB_q099.csv"
)
model_checkpoint_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_model_checkpoint_2D_sqrtNB_q099.rds"
)
model_registry_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_model_registry_2D_sqrtNB_q099.csv"
)
model_results_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_model_results_2D_sqrtNB_q099.rds"
)
qph_audit_file <- file.path(
  sensitivity_output_directory,
  "QPH_sensitivity_bandwidth_audit_2D_sqrtNB_q099.csv"
)

geometry_checkpoint_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_geometry_checkpoint_2D_sqrtNB_q099.rds"
)
geometry_results_output_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_geometry_results_2D_sqrtNB_q099.rds"
)
geometry_summary_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_geometry_summary_2D_sqrtNB_q099.csv"
)
geometry_series_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_geometry_series_2D_sqrtNB_q099.csv"
)

topology_subsample_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_topology_subsample_indices_2D_sqrtNB_q099.rds"
)
topology_checkpoint_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_topology_checkpoint_2D_sqrtNB_q099.rds"
)
topology_persistence_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_topology_persistence_2D_sqrtNB_q099.rds"
)
topology_replicate_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_topology_replicates_2D_sqrtNB_q099.csv"
)
topology_summary_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_topology_summary_2D_sqrtNB_q099.csv"
)
topology_series_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_topology_series_2D_sqrtNB_q099.csv"
)

matched_reference_manifest_file <- file.path(
  sensitivity_output_directory,
  "matched_reference_condition_manifest_2D_sqrtNB_q099.csv"
)
matched_reference_checkpoint_file <- file.path(
  sensitivity_output_directory,
  "matched_reference_checkpoint_2D_sqrtNB_q099.rds"
)
matched_reference_replicate_file <- file.path(
  sensitivity_output_directory,
  "matched_reference_replicates_2D_sqrtNB_q099.csv"
)
matched_reference_observed_file <- file.path(
  sensitivity_output_directory,
  "observed_vs_matched_reference_2D_sqrtNB_q099.csv"
)
matched_reference_exceedance_file <- file.path(
  sensitivity_output_directory,
  "matched_reference_exceedance_summary_2D_sqrtNB_q099.csv"
)
matched_reference_diagnostic_file <- file.path(
  sensitivity_output_directory,
  "matched_reference_diagnostic_summary_2D_sqrtNB_q099.csv"
)
matched_reference_series_file <- file.path(
  sensitivity_output_directory,
  "matched_reference_series_2D_sqrtNB_q099.csv"
)

failure_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_failures_2D_sqrtNB_q099.csv"
)
run_metadata_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_run_metadata_2D_sqrtNB_q099.rds"
)
analysis_notes_file <- file.path(
  sensitivity_output_directory,
  "SENSITIVITY_ANALYSIS_NOTES_2D_sqrtNB_q099.txt"
)
session_information_file <- file.path(
  sensitivity_output_directory,
  "sensitivity_session_information_2D_sqrtNB_q099.txt"
)

# ============================================================
# General helpers
# ============================================================

safe_md5 <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  unname(tools::md5sum(path))
}

hash_r_object <- function(object) {
  f <- tempfile(fileext = ".rds")
  on.exit(unlink(f), add = TRUE)
  saveRDS(object, f, version = 3)
  safe_md5(f)
}

write_csv_safely <- function(x, file) {
  tryCatch(
    {
      utils::write.csv(x, file = file, row.names = FALSE)
      invisible(file)
    },
    error = function(e) {
      alternative <- sub(
        "\\.csv$",
        paste0("_new_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"),
        file
      )
      warning("Could not overwrite ", basename(file), "; writing ", basename(alternative))
      utils::write.csv(x, file = alternative, row.names = FALSE)
      invisible(alternative)
    }
  )
}

value_label <- function(value) {
  if (length(value) != 1L || is.na(value)) return("NA")
  x <- format(value, scientific = FALSE, trim = TRUE, digits = 12)
  x <- sub("\\.?0+$", "", x)
  if (identical(x, "")) x <- "0"
  gsub("\\.", "p", x)
}

make_safe_id <- function(x) gsub("[^A-Za-z0-9_.-]+", "_", x)

safe_sd <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) <= 1L) return(NA_real_)
  stats::sd(x)
}

format_mean_sd <- function(mean_value, sd_value, digits = 4L) {
  if (!is.finite(mean_value)) return(NA_character_)
  if (!is.finite(sd_value)) {
    return(sprintf(paste0("%.", digits, "f"), mean_value))
  }
  sprintf(
    paste0("%.", digits, "f +/- %.", digits, "f"),
    mean_value,
    sd_value
  )
}

standardise_points <- function(x, object_name = "points") {
  x <- as.matrix(x)
  storage.mode(x) <- "double"
  if (nrow(x) < 1L) stop(object_name, " contains no rows.")
  if (ncol(x) != 2L) stop(object_name, " must contain exactly two columns.")
  if (any(!is.finite(x))) stop(object_name, " contains non-finite values.")
  colnames(x) <- c("Environmental axis 1", "Environmental axis 2")
  x
}

standardise_hypervolume_axis_names <- function(hv) {
  if (!methods::is(hv, "Hypervolume")) stop("Object is not a Hypervolume.")
  if (as.integer(hv@Dimensionality) != 2L) stop("Expected a 2D Hypervolume.")
  axis_names <- c("Environmental axis 1", "Environmental axis 2")
  colnames(hv@Data) <- axis_names
  colnames(hv@RandomPoints) <- axis_names
  methods::validObject(hv)
  hv
}

validate_hypervolume <- function(hv, object_name = "hv") {
  hv <- standardise_hypervolume_axis_names(hv)
  if (!is.finite(hv@Volume) || hv@Volume <= 0) stop(object_name, " has invalid area.")
  if (nrow(hv@RandomPoints) < 1L) stop(object_name, " has no stochastic points.")
  invisible(TRUE)
}

point_cloud_diameter <- function(points) {
  points <- standardise_points(points)
  if (nrow(points) < 2L) return(NA_real_)
  max(stats::dist(points))
}

# ============================================================
# Load revised upstream outputs
# ============================================================

occurrence_archive <- readRDS(occurrence_archive_file)
baseline_results <- readRDS(baseline_results_file)
geometry_results_input <- readRDS(geometry_results_file)
baseline_topology_subsamples <- readRDS(baseline_topology_subsample_file)
baseline_persistence_results <- readRDS(baseline_persistence_file)

if (!is.list(baseline_results) || is.null(baseline_results$scenarios)) {
  stop("Unexpected revised baseline result structure.")
}
if (!is.list(geometry_results_input) || is.null(geometry_results_input$geometry_summary) || is.null(geometry_results_input$true_references)) {
  stop("Unexpected revised geometry result structure.")
}
if (!is.list(baseline_topology_subsamples) || is.null(baseline_topology_subsamples$indices)) {
  stop("Unexpected revised topology subsample structure.")
}
if (!is.list(baseline_persistence_results)) {
  stop("Unexpected revised persistence result structure.")
}

baseline_scenarios <- baseline_results$scenarios
baseline_geometry_summary <- geometry_results_input$geometry_summary
true_references <- geometry_results_input$true_references

if (!identical(names(occurrence_archive$master_datasets), expected_shape_names)) {
  stop("Unexpected shape order in occurrence archive.")
}
if (!all(expected_shape_names %in% names(true_references))) {
  stop("Missing one or more true references.")
}

# ============================================================
# Baseline accessors
# ============================================================

scenario_name_for <- function(shape_name) paste(shape_name, sensitivity_sample_size, sep = "_")

get_occurrence_points <- function(shape_name) {
  shape_subsets <- occurrence_archive$occurrence_subsets[[shape_name]]
  if (is.null(shape_subsets)) stop("Missing shape: ", shape_name)
  subset_object <- shape_subsets[[as.character(sensitivity_sample_size)]]
  if (is.null(subset_object)) stop("Missing n=900 occurrence subset for ", shape_name)
  standardise_points(subset_object$points, paste0(shape_name, " occurrences"))
}

get_baseline_scenario <- function(shape_name) {
  scenario <- baseline_scenarios[[scenario_name_for(shape_name)]]
  if (is.null(scenario)) stop("Missing revised baseline scenario for ", shape_name)
  scenario
}

get_baseline_method_record <- function(shape_name, method) {
  scenario <- get_baseline_scenario(shape_name)
  if (identical(method, "QPH")) result <- scenario$qph
  else if (identical(method, "Gaussian KDE")) result <- scenario$gaussian_kde
  else if (identical(method, "SVM")) result <- scenario$svm
  else stop("Unknown method: ", method)
  if (is.null(result) || !isTRUE(result$success)) stop("Unavailable baseline: ", shape_name, " / ", method)
  result
}

get_baseline_hypervolume <- function(shape_name, method) {
  standardise_hypervolume_axis_names(get_baseline_method_record(shape_name, method)$hypervolume)
}

get_baseline_geometry_row <- function(shape_name, method) {
  rows <- baseline_geometry_summary[
    baseline_geometry_summary$Shape_code == shape_name &
      baseline_geometry_summary$Sample_size == sensitivity_sample_size &
      baseline_geometry_summary$Method == method &
      baseline_geometry_summary$Success,
    , drop = FALSE
  ]
  if (nrow(rows) != 1L) stop("Expected one baseline geometry row for ", shape_name, " / ", method)
  rows
}

# ============================================================
# Verify revised baselines before sensitivity fitting
# ============================================================

for (shape_name in expected_shape_names) {
  occurrence_points <- get_occurrence_points(shape_name)
  if (nrow(occurrence_points) != sensitivity_sample_size) stop("Unexpected n for ", shape_name)

  scenario <- get_baseline_scenario(shape_name)

  qa <- scenario$qph$audit
  expected_k <- max(2L, min(as.integer(round(sqrt(sensitivity_sample_size))), sensitivity_sample_size - 1L))
  if (!identical(as.integer(qa$K), expected_k)) stop("QPH K mismatch for ", shape_name)
  if (!isTRUE(all.equal(as.numeric(qa$baseline_scalar_h), sqrt(mean(qa$local_s)), tolerance = 1e-12))) {
    stop("QPH h mismatch for ", shape_name)
  }
  if (!isTRUE(all.equal(as.numeric(qa$fitted_bandwidth), rep(qa$baseline_scalar_h, 2L), tolerance = 1e-12))) {
    stop("QPH baseline not isotropic for ", shape_name)
  }
  if (!isTRUE(all.equal(as.numeric(qa$q), qph_baseline_q))) stop("QPH q mismatch for ", shape_name)

  kr <- scenario$gaussian_kde
  if (!isTRUE(all.equal(as.numeric(kr$probability_quantile), kde_baseline_quantile))) {
    stop("KDE quantile mismatch for ", shape_name)
  }
  if (length(kr$bandwidth) != 2L) stop("Missing KDE bandwidth for ", shape_name)

  sr <- scenario$svm$hypervolume
  if (!isTRUE(all.equal(as.numeric(sr@Parameters$svm.nu), svm_baseline_nu))) stop("SVM nu mismatch for ", shape_name)
  if (!isTRUE(all.equal(as.numeric(sr@Parameters$svm.gamma), svm_baseline_gamma))) stop("SVM gamma mismatch for ", shape_name)
  if (!identical(as.integer(sr@Parameters$samples.per.point), baseline_samples_per_point)) stop("SVM spp mismatch for ", shape_name)
}

# ============================================================
# Sensitivity design
# ============================================================

create_sensitivity_design <- function() {
  rows <- list()
  i <- 0L

  add_row <- function(
      shape_name, method, family,
      bw = NA_real_, q = NA_real_, spp = baseline_samples_per_point,
      nu = NA_real_, gamma = NA_real_, varied = NA_real_, baseline = FALSE
  ) {
    i <<- i + 1L
    method_code <- if (identical(method, "Gaussian KDE")) "KDE" else method
    id <- paste(
      shape_name, method_code, gsub(" ", "_", family),
      paste0("bw", value_label(bw)),
      paste0("q", value_label(q)),
      paste0("spp", spp),
      paste0("nu", value_label(nu)),
      paste0("gamma", value_label(gamma)),
      sep = "__"
    )
    rows[[i]] <<- data.frame(
      Condition_id = id,
      Shape_code = shape_name,
      Shape = unname(shape_labels[shape_name]),
      Sample_size = sensitivity_sample_size,
      Method = method,
      Variation_family = family,
      Bandwidth_multiplier = bw,
      Quantile_level = q,
      Samples_per_point = as.integer(spp),
      SVM_nu = nu,
      SVM_gamma = gamma,
      Varied_value = varied,
      Is_baseline = baseline,
      stringsAsFactors = FALSE
    )
  }

  for (shape_name in expected_shape_names) {
    add_row(shape_name, "QPH", "Baseline", 1, qph_baseline_q, baseline = TRUE)
    for (v in setdiff(qph_bandwidth_multipliers, 1)) add_row(shape_name, "QPH", "Bandwidth", v, qph_baseline_q, varied = v)
    for (v in setdiff(qph_q_values, qph_baseline_q)) add_row(shape_name, "QPH", "Quantile", 1, v, varied = v)
    for (v in setdiff(samples_per_point_values, baseline_samples_per_point)) add_row(shape_name, "QPH", "Sampling effort", 1, qph_baseline_q, v, varied = v)

    add_row(shape_name, "Gaussian KDE", "Baseline", 1, kde_baseline_quantile, baseline = TRUE)
    for (v in setdiff(kde_bandwidth_multipliers, 1)) add_row(shape_name, "Gaussian KDE", "Bandwidth", v, kde_baseline_quantile, varied = v)
    for (v in setdiff(kde_quantile_values, kde_baseline_quantile)) add_row(shape_name, "Gaussian KDE", "Quantile", 1, v, varied = v)
    for (v in setdiff(samples_per_point_values, baseline_samples_per_point)) add_row(shape_name, "Gaussian KDE", "Sampling effort", 1, kde_baseline_quantile, v, varied = v)

    add_row(shape_name, "SVM", "Baseline", spp = baseline_samples_per_point, nu = svm_baseline_nu, gamma = svm_baseline_gamma, baseline = TRUE)
    for (v in setdiff(samples_per_point_values, baseline_samples_per_point)) add_row(shape_name, "SVM", "Sampling effort", spp = v, nu = svm_baseline_nu, gamma = svm_baseline_gamma, varied = v)
    for (v in setdiff(svm_nu_values, svm_baseline_nu)) add_row(shape_name, "SVM", "SVM nu", nu = v, gamma = svm_baseline_gamma, varied = v)
    for (v in setdiff(svm_gamma_values, svm_baseline_gamma)) add_row(shape_name, "SVM", "SVM gamma", nu = svm_baseline_nu, gamma = v, varied = v)
  }

  design <- do.call(rbind, rows)
  rownames(design) <- NULL

  seed_key <- paste(
    design$Shape_code,
    design$Variation_family,
    ifelse(is.na(design$Varied_value), "baseline", vapply(design$Varied_value, value_label, character(1))),
    design$Samples_per_point,
    sep = "|"
  )
  design$Fit_seed <- sensitivity_fit_seed_base + match(seed_key, unique(seed_key))

  for (r in seq_len(nrow(design))) {
    if (isTRUE(design$Is_baseline[r])) {
      design$Fit_seed[r] <- get_baseline_scenario(design$Shape_code[r])$sampling_seed
    }
  }
  design$Requires_new_fit <- !design$Is_baseline
  design
}

sensitivity_design <- create_sensitivity_design()
expected_total_conditions <- length(expected_shape_names) * (8L + 8L + 8L)
expected_new_fits <- length(expected_shape_names) * (7L + 7L + 7L)
if (nrow(sensitivity_design) != expected_total_conditions) stop("Unexpected condition count.")
if (sum(sensitivity_design$Requires_new_fit) != expected_new_fits) stop("Unexpected new-fit count.")
if (anyDuplicated(sensitivity_design$Condition_id)) stop("Duplicated condition IDs.")
write_csv_safely(sensitivity_design, sensitivity_design_file)

message(
  "Sensitivity design: ", nrow(sensitivity_design),
  " unique conditions; ", sum(sensitivity_design$Requires_new_fit), " new fits."
)

# ============================================================
# Safe analysis signature
# ============================================================

installed_hypervolume_version <- as.character(utils::packageVersion("hypervolume"))
installed_tda_stats_version <- as.character(utils::packageVersion("TDAstats"))
installed_tda_version <- as.character(utils::packageVersion("TDA"))

analysis_settings <- list(
  script = "04_2D_Synthetic_Sensitivity.R",
  qph_core_version = QPH_CORE_VERSION,
  qph_core_md5 = qph_core_md5,
  occurrence_md5 = safe_md5(occurrence_archive_file),
  baseline_md5 = safe_md5(baseline_results_file),
  geometry_md5 = safe_md5(geometry_results_file),
  topology_subsample_md5 = safe_md5(baseline_topology_subsample_file),
  baseline_persistence_md5 = safe_md5(baseline_persistence_file),
  design = sensitivity_design[, setdiff(names(sensitivity_design), "Fit_seed"), drop = FALSE],
  ph_sample_size = ph_sample_size,
  topology_repetitions = number_of_topology_repetitions,
  ph_threshold = ph_threshold,
  ph_prime_field = ph_prime_field,
  ph_standardize = ph_standardize,
  ph_timeout_seconds = ph_timeout_seconds,
  null_replicates = number_of_matched_reference_replicates,
  seeds = c(sensitivity_fit_seed_base, sensitivity_geometry_seed_base, sensitivity_topology_seed_base, matched_reference_seed_base),
  colours = c(method_colours, true_region_colour, occurrence_colour),
  package_versions = c(hypervolume = installed_hypervolume_version, TDAstats = installed_tda_stats_version, TDA = installed_tda_version)
)
analysis_settings_hash <- hash_r_object(analysis_settings)

# ============================================================
# Model registry and fitting
# ============================================================

empty_model_registry <- function() {
  data.frame(
    Condition_id = character(0), Success = logical(0), Shape_code = character(0),
    Shape = character(0), Sample_size = integer(0), Method = character(0),
    Variation_family = character(0), Bandwidth_multiplier = numeric(0),
    Quantile_level = numeric(0), Samples_per_point = integer(0),
    SVM_nu = numeric(0), SVM_gamma = numeric(0), Is_baseline = logical(0),
    Fit_seed = integer(0), Fit_source = character(0), Object_file = character(0),
    True_area = numeric(0), Estimated_area = numeric(0), Signed_area_error = numeric(0),
    Absolute_area_error = numeric(0), Relative_area_error_percent = numeric(0),
    Random_points = integer(0), Point_density = numeric(0), Runtime_seconds = numeric(0),
    Base_bandwidth_axis_1 = numeric(0), Base_bandwidth_axis_2 = numeric(0),
    Used_bandwidth_axis_1 = numeric(0), Used_bandwidth_axis_2 = numeric(0),
    QPH_K = integer(0), QPH_mean_s = numeric(0), QPH_scalar_h = numeric(0),
    QPH_retained_fraction = numeric(0), Error_message = character(0),
    stringsAsFactors = FALSE
  )
}

model_object_path <- function(condition_id) {
  file.path(model_object_directory, paste0(make_safe_id(condition_id), ".rds"))
}

if (resume_model_fits && file.exists(model_checkpoint_file)) {
  cp <- readRDS(model_checkpoint_file)
  if (!identical(cp$analysis_settings_hash, analysis_settings_hash)) {
    stop("Incompatible sensitivity model checkpoint.")
  }
  model_registry <- cp$registry
} else {
  model_registry <- empty_model_registry()
}

registry_row <- function(condition_id) {
  x <- model_registry[model_registry$Condition_id == condition_id, , drop = FALSE]
  if (nrow(x) == 0L) return(NULL)
  if (nrow(x) > 1L) stop("Duplicate registry row: ", condition_id)
  x
}

replace_registry_row <- function(new_row) {
  keep <- model_registry$Condition_id != new_row$Condition_id[1L]
  model_registry <<- rbind(model_registry[keep, , drop = FALSE], new_row)
  rownames(model_registry) <<- NULL
}

save_model_checkpoint <- function() {
  saveRDS(
    list(analysis_settings_hash = analysis_settings_hash, registry = model_registry, last_updated = as.character(Sys.time())),
    model_checkpoint_file,
    version = 3
  )
  write_csv_safely(model_registry, model_registry_file)
}

for (condition_index in seq_len(nrow(sensitivity_design))) {
  condition <- sensitivity_design[condition_index, , drop = FALSE]
  condition_id <- condition$Condition_id[1L]
  existing <- registry_row(condition_id)

  if (!is.null(existing) && isTRUE(existing$Success[1L])) {
    object_ok <- isTRUE(existing$Is_baseline[1L]) || (!is.na(existing$Object_file[1L]) && file.exists(existing$Object_file[1L]))
    if (object_ok) {
      message("Skipping successful model condition: ", condition_id)
      next
    }
  }
  if (!is.null(existing) && !retry_failed_model_fits) next

  shape_name <- condition$Shape_code[1L]
  method <- condition$Method[1L]
  occurrence_points <- get_occurrence_points(shape_name)
  true_area <- as.numeric(occurrence_archive$master_datasets[[shape_name]]$true_area)
  object_file <- model_object_path(condition_id)

  message("Fitting/reusing sensitivity condition ", condition_index, "/", nrow(sensitivity_design), ": ", condition_id)

  fit_row <- tryCatch({
    qph_diagnostics <- NULL
    base_bandwidth <- NULL
    used_bandwidth <- NULL

    if (isTRUE(condition$Is_baseline[1L])) {
      baseline_record <- get_baseline_method_record(shape_name, method)
      hv <- standardise_hypervolume_axis_names(baseline_record$hypervolume)
      runtime_seconds <- as.numeric(baseline_record$runtime_seconds)
      fit_source <- "Reused revised Script 01 baseline"
      object_file <- NA_character_

      if (identical(method, "QPH")) {
        base_bandwidth <- as.numeric(baseline_record$audit$baseline_isotropic_bandwidth)
        used_bandwidth <- as.numeric(baseline_record$audit$fitted_bandwidth)
        qph_diagnostics <- list(audit = baseline_record$audit, retained_fraction = baseline_record$retained_fraction)
      } else if (identical(method, "Gaussian KDE")) {
        base_bandwidth <- as.numeric(baseline_record$bandwidth)
        used_bandwidth <- base_bandwidth
      }
    } else {
      set.seed(as.integer(condition$Fit_seed[1L]))
      fit_time <- system.time({
        if (identical(method, "QPH")) {
          bandwidth_info <- estimate_qph_sqrt_nb_bandwidth(occurrence_points)
          baseline_record <- get_baseline_method_record(shape_name, "QPH")
          if (!isTRUE(all.equal(as.numeric(bandwidth_info$bandwidth), as.numeric(baseline_record$audit$baseline_isotropic_bandwidth), tolerance = 1e-12))) {
            stop("Fresh sqrt-NB bandwidth differs from saved baseline for ", shape_name)
          }
          base_bandwidth <- as.numeric(bandwidth_info$bandwidth)
          used_bandwidth <- base_bandwidth * as.numeric(condition$Bandwidth_multiplier[1L])
          qph_diagnostics <- construct_qph(
            data = occurrence_points,
            bandwidth = used_bandwidth,
            bandwidth_info = bandwidth_info,
            name = paste0("QPH sensitivity: ", condition_id),
            samples_per_point = as.integer(condition$Samples_per_point[1L]),
            sd_count = baseline_sd_count,
            q = as.numeric(condition$Quantile_level[1L]),
            sampling_seed = as.integer(condition$Fit_seed[1L]),
            sampling_chunk_size = shared_chunk_size,
            potential_batch_size = potential_batch_size,
            verbose = show_progress_messages
          )
          hv <- qph_diagnostics$hypervolume
        } else if (identical(method, "Gaussian KDE")) {
          baseline_record <- get_baseline_method_record(shape_name, "Gaussian KDE")

          # Keep the exact intended numerical sensitivity bandwidth:
          #   h_used = multiplier * h_Silverman.
          #
          # hypervolume >= 3 requires the bandwidth object supplied to
          # hypervolume_gaussian() to carry method metadata from
          # estimate_bandwidth(). Converting the saved Silverman bandwidth
          # with as.numeric() removes that metadata, so rebuild the chosen
          # vector through method = "fixed" without changing its values.
          base_bandwidth <- as.numeric(baseline_record$bandwidth)

          used_bandwidth_numeric <- (
            base_bandwidth *
              as.numeric(condition$Bandwidth_multiplier[1L])
          )

          names(used_bandwidth_numeric) <- colnames(occurrence_points)

          used_bandwidth <- hypervolume::estimate_bandwidth(
            data = occurrence_points,
            method = "fixed",
            value = used_bandwidth_numeric
          )

          hv <- hypervolume::hypervolume_gaussian(
            data = occurrence_points,
            name = paste0("Gaussian KDE sensitivity: ", condition_id),
            kde.bandwidth = used_bandwidth,
            samples.per.point = as.integer(condition$Samples_per_point[1L]),
            sd.count = baseline_sd_count,
            quantile.requested = as.numeric(condition$Quantile_level[1L]),
            quantile.requested.type = "probability",
            chunk.size = shared_chunk_size,
            verbose = show_progress_messages
          )
        } else if (identical(method, "SVM")) {
          hv <- hypervolume::hypervolume_svm(
            data = occurrence_points,
            name = paste0("SVM sensitivity: ", condition_id),
            samples.per.point = as.integer(condition$Samples_per_point[1L]),
            svm.nu = as.numeric(condition$SVM_nu[1L]),
            svm.gamma = as.numeric(condition$SVM_gamma[1L]),
            scale.factor = svm_scale_factor,
            chunk.size = shared_chunk_size,
            verbose = show_progress_messages
          )
        } else {
          stop("Unknown method: ", method)
        }
      })
      runtime_seconds <- unname(fit_time["elapsed"])
      fit_source <- "New revised sensitivity fit"
      hv <- standardise_hypervolume_axis_names(hv)
      validate_hypervolume(hv, condition_id)
      saveRDS(
        list(
          condition = condition, hypervolume = hv, occurrence_points = occurrence_points,
          base_bandwidth = base_bandwidth, used_bandwidth = used_bandwidth,
          qph_diagnostics = qph_diagnostics, runtime_seconds = runtime_seconds,
          fit_source = fit_source, created_at = as.character(Sys.time())
        ),
        object_file,
        version = 3
      )
    }

    validate_hypervolume(hv, condition_id)
    estimated_area <- as.numeric(hv@Volume)
    signed_error <- estimated_area - true_area
    qa <- if (!is.null(qph_diagnostics)) qph_diagnostics$audit else NULL

    data.frame(
      Condition_id = condition_id, Success = TRUE, Shape_code = shape_name,
      Shape = condition$Shape[1L], Sample_size = sensitivity_sample_size,
      Method = method, Variation_family = condition$Variation_family[1L],
      Bandwidth_multiplier = condition$Bandwidth_multiplier[1L],
      Quantile_level = condition$Quantile_level[1L],
      Samples_per_point = as.integer(condition$Samples_per_point[1L]),
      SVM_nu = condition$SVM_nu[1L], SVM_gamma = condition$SVM_gamma[1L],
      Is_baseline = condition$Is_baseline[1L], Fit_seed = as.integer(condition$Fit_seed[1L]),
      Fit_source = fit_source, Object_file = object_file, True_area = true_area,
      Estimated_area = estimated_area, Signed_area_error = signed_error,
      Absolute_area_error = abs(signed_error),
      Relative_area_error_percent = 100 * signed_error / true_area,
      Random_points = nrow(hv@RandomPoints), Point_density = as.numeric(hv@PointDensity),
      Runtime_seconds = runtime_seconds,
      Base_bandwidth_axis_1 = if (!is.null(base_bandwidth)) base_bandwidth[1L] else NA_real_,
      Base_bandwidth_axis_2 = if (!is.null(base_bandwidth)) base_bandwidth[2L] else NA_real_,
      Used_bandwidth_axis_1 = if (!is.null(used_bandwidth)) used_bandwidth[1L] else NA_real_,
      Used_bandwidth_axis_2 = if (!is.null(used_bandwidth)) used_bandwidth[2L] else NA_real_,
      QPH_K = if (!is.null(qa)) as.integer(qa$K) else NA_integer_,
      QPH_mean_s = if (!is.null(qa)) as.numeric(qa$mean_s) else NA_real_,
      QPH_scalar_h = if (!is.null(qa)) as.numeric(qa$baseline_scalar_h) else NA_real_,
      QPH_retained_fraction = if (!is.null(qph_diagnostics)) as.numeric(qph_diagnostics$retained_fraction) else NA_real_,
      Error_message = NA_character_, stringsAsFactors = FALSE
    )
  }, error = function(e) {
    msg <- conditionMessage(e)
    warning("Model condition failed: ", condition_id, ": ", msg)
    data.frame(
      Condition_id = condition_id, Success = FALSE, Shape_code = shape_name,
      Shape = condition$Shape[1L], Sample_size = sensitivity_sample_size,
      Method = method, Variation_family = condition$Variation_family[1L],
      Bandwidth_multiplier = condition$Bandwidth_multiplier[1L],
      Quantile_level = condition$Quantile_level[1L],
      Samples_per_point = as.integer(condition$Samples_per_point[1L]),
      SVM_nu = condition$SVM_nu[1L], SVM_gamma = condition$SVM_gamma[1L],
      Is_baseline = condition$Is_baseline[1L], Fit_seed = as.integer(condition$Fit_seed[1L]),
      Fit_source = NA_character_, Object_file = object_file, True_area = true_area,
      Estimated_area = NA_real_, Signed_area_error = NA_real_, Absolute_area_error = NA_real_,
      Relative_area_error_percent = NA_real_, Random_points = NA_integer_, Point_density = NA_real_,
      Runtime_seconds = NA_real_, Base_bandwidth_axis_1 = NA_real_, Base_bandwidth_axis_2 = NA_real_,
      Used_bandwidth_axis_1 = NA_real_, Used_bandwidth_axis_2 = NA_real_,
      QPH_K = NA_integer_, QPH_mean_s = NA_real_, QPH_scalar_h = NA_real_,
      QPH_retained_fraction = NA_real_, Error_message = msg, stringsAsFactors = FALSE
    )
  })

  replace_registry_row(fit_row)
  save_model_checkpoint()
}

model_registry <- model_registry[
  match(sensitivity_design$Condition_id, model_registry$Condition_id),
  , drop = FALSE
]
rownames(model_registry) <- NULL
write_csv_safely(model_registry, model_registry_file)
saveRDS(
  list(analysis_settings_hash = analysis_settings_hash, design = sensitivity_design, registry = model_registry, completed_at = as.character(Sys.time())),
  model_results_file,
  version = 3
)

# QPH audit table.
qph_rows <- list(); qi <- 0L
for (r in seq_len(nrow(sensitivity_design))) {
  cnd <- sensitivity_design[r, , drop = FALSE]
  if (!identical(cnd$Method[1L], "QPH")) next
  rr <- model_registry[model_registry$Condition_id == cnd$Condition_id[1L] & model_registry$Success, , drop = FALSE]
  if (nrow(rr) != 1L) next
  qi <- qi + 1L
  qph_rows[[qi]] <- data.frame(
    Condition_id = cnd$Condition_id[1L], Shape_code = cnd$Shape_code[1L], Shape = cnd$Shape[1L],
    Variation_family = cnd$Variation_family[1L], Bandwidth_multiplier = cnd$Bandwidth_multiplier[1L],
    q = cnd$Quantile_level[1L], Samples_per_point = cnd$Samples_per_point[1L],
    K = rr$QPH_K[1L], Mean_s = rr$QPH_mean_s[1L], Baseline_scalar_h = rr$QPH_scalar_h[1L],
    Base_bandwidth_axis_1 = rr$Base_bandwidth_axis_1[1L], Base_bandwidth_axis_2 = rr$Base_bandwidth_axis_2[1L],
    Used_bandwidth_axis_1 = rr$Used_bandwidth_axis_1[1L], Used_bandwidth_axis_2 = rr$Used_bandwidth_axis_2[1L],
    Retained_fraction = rr$QPH_retained_fraction[1L], Fit_seed = rr$Fit_seed[1L], stringsAsFactors = FALSE
  )
}
if (length(qph_rows) > 0L) write_csv_safely(do.call(rbind, qph_rows), qph_audit_file)

get_condition_hypervolume <- function(condition_id) {
  drow <- sensitivity_design[sensitivity_design$Condition_id == condition_id, , drop = FALSE]
  rrow <- model_registry[model_registry$Condition_id == condition_id, , drop = FALSE]
  if (nrow(drow) != 1L || nrow(rrow) != 1L || !isTRUE(rrow$Success[1L])) {
    stop("Unavailable sensitivity condition: ", condition_id)
  }
  if (isTRUE(drow$Is_baseline[1L])) {
    return(get_baseline_hypervolume(drow$Shape_code[1L], drow$Method[1L]))
  }
  object_file <- rrow$Object_file[1L]
  if (is.na(object_file) || !file.exists(object_file)) stop("Missing model object for ", condition_id)
  standardise_hypervolume_axis_names(readRDS(object_file)$hypervolume)
}

# ============================================================
# Geometry sensitivity
# ============================================================

geometry_analysis_hash <- hash_r_object(list(
  parent_hash = analysis_settings_hash,
  geometry_input_md5 = safe_md5(geometry_results_file),
  num_points_max = jaccard_num_points_max,
  distance_factor = jaccard_distance_factor,
  seed_base = sensitivity_geometry_seed_base
))

if (resume_geometry && file.exists(geometry_checkpoint_file)) {
  cp <- readRDS(geometry_checkpoint_file)
  if (!identical(cp$geometry_analysis_hash, geometry_analysis_hash)) {
    stop("Incompatible geometry sensitivity checkpoint.")
  }
  geometry_results <- cp$results
} else {
  geometry_results <- list()
}

for (condition_index in seq_len(nrow(sensitivity_design))) {
  condition <- sensitivity_design[condition_index, , drop = FALSE]
  condition_id <- condition$Condition_id[1L]
  registry <- model_registry[model_registry$Condition_id == condition_id, , drop = FALSE]

  if (nrow(registry) != 1L || !isTRUE(registry$Success[1L])) {
    geometry_results[[condition_id]] <- list(
      success = FALSE,
      summary = data.frame(
        Condition_id = condition_id, Success = FALSE,
        Shape_code = condition$Shape_code[1L], Shape = condition$Shape[1L],
        Method = condition$Method[1L], Variation_family = condition$Variation_family[1L],
        Bandwidth_multiplier = condition$Bandwidth_multiplier[1L],
        Quantile_level = condition$Quantile_level[1L],
        Samples_per_point = condition$Samples_per_point[1L],
        SVM_nu = condition$SVM_nu[1L], SVM_gamma = condition$SVM_gamma[1L],
        Is_baseline = condition$Is_baseline[1L], True_area = registry$True_area[1L],
        Estimated_area = NA_real_, Signed_area_error = NA_real_, Absolute_area_error = NA_real_,
        Relative_area_error_percent = NA_real_, Intersection_area = NA_real_, Union_area = NA_real_,
        Jaccard_similarity = NA_real_, Sorensen_similarity = NA_real_, True_region_coverage = NA_real_,
        Excess_estimated_area = NA_real_, Excess_estimated_fraction = NA_real_,
        Estimated_centroid_axis_1 = NA_real_, Estimated_centroid_axis_2 = NA_real_,
        True_centroid_axis_1 = NA_real_, True_centroid_axis_2 = NA_real_,
        Centroid_displacement = NA_real_, Geometry_source = NA_character_,
        Set_operation_runtime_seconds = NA_real_, Set_operation_seed = NA_integer_,
        Error_message = registry$Error_message[1L], stringsAsFactors = FALSE
      )
    )
    next
  }

  existing <- geometry_results[[condition_id]]
  if (!is.null(existing) && isTRUE(existing$success)) next
  if (!is.null(existing) && !retry_failed_geometry) next

  shape_name <- condition$Shape_code[1L]
  method <- condition$Method[1L]
  reference <- true_references[[shape_name]]
  set_seed <- sensitivity_geometry_seed_base + condition_index

  message("Geometry sensitivity ", condition_index, "/", nrow(sensitivity_design), ": ", condition_id)

  geometry_results[[condition_id]] <- tryCatch({
    if (isTRUE(condition$Is_baseline[1L])) {
      b <- get_baseline_geometry_row(shape_name, method)
      summary_row <- data.frame(
        Condition_id = condition_id, Success = TRUE, Shape_code = shape_name,
        Shape = condition$Shape[1L], Method = method,
        Variation_family = condition$Variation_family[1L],
        Bandwidth_multiplier = condition$Bandwidth_multiplier[1L],
        Quantile_level = condition$Quantile_level[1L],
        Samples_per_point = condition$Samples_per_point[1L],
        SVM_nu = condition$SVM_nu[1L], SVM_gamma = condition$SVM_gamma[1L],
        Is_baseline = TRUE, True_area = b$True_area, Estimated_area = b$Estimated_area,
        Signed_area_error = b$Signed_area_error, Absolute_area_error = b$Absolute_area_error,
        Relative_area_error_percent = b$Relative_area_error_percent,
        Intersection_area = b$Intersection_area, Union_area = b$Union_area,
        Jaccard_similarity = b$Jaccard_similarity, Sorensen_similarity = b$Sorensen_similarity,
        True_region_coverage = b$True_region_coverage,
        Excess_estimated_area = b$Excess_estimated_area,
        Excess_estimated_fraction = b$Excess_estimated_fraction,
        Estimated_centroid_axis_1 = b$Estimated_centroid_axis_1,
        Estimated_centroid_axis_2 = b$Estimated_centroid_axis_2,
        True_centroid_axis_1 = b$True_centroid_axis_1,
        True_centroid_axis_2 = b$True_centroid_axis_2,
        Centroid_displacement = b$Centroid_displacement,
        Geometry_source = "Reused revised Script 02 baseline",
        Set_operation_runtime_seconds = b$Set_operation_runtime_seconds,
        Set_operation_seed = b$Set_operation_seed,
        Error_message = NA_character_, stringsAsFactors = FALSE
      )
    } else {
      estimated_hv <- get_condition_hypervolume(condition_id)
      true_hv <- standardise_hypervolume_axis_names(reference$hypervolume)
      set.seed(set_seed)
      set_time <- system.time({
        hv_set <- hypervolume::hypervolume_set(
          hv1 = estimated_hv,
          hv2 = true_hv,
          num.points.max = jaccard_num_points_max,
          verbose = FALSE,
          check.memory = FALSE,
          distance.factor = jaccard_distance_factor
        )
      })
      overlap <- hypervolume::hypervolume_overlap_statistics(hv_set)
      intersection_area <- as.numeric(hv_set@HVList$Intersection@Volume)
      union_area <- as.numeric(hv_set@HVList$Union@Volume)
      jaccard_value <- as.numeric(overlap[["jaccard"]])
      sorensen_value <- if (is.finite(jaccard_value)) 2 * jaccard_value / (1 + jaccard_value) else NA_real_
      estimated_centroid <- colMeans(estimated_hv@RandomPoints)
      true_centroid <- as.numeric(reference$true_centroid)
      centroid_displacement <- sqrt(sum((estimated_centroid - true_centroid)^2))
      estimated_area <- as.numeric(estimated_hv@Volume)
      true_area <- as.numeric(reference$true_area)
      signed_error <- estimated_area - true_area
      coverage <- intersection_area / true_area
      excess_area <- estimated_area - intersection_area
      excess_fraction <- if (estimated_area > 0) excess_area / estimated_area else NA_real_

      summary_row <- data.frame(
        Condition_id = condition_id, Success = TRUE, Shape_code = shape_name,
        Shape = condition$Shape[1L], Method = method,
        Variation_family = condition$Variation_family[1L],
        Bandwidth_multiplier = condition$Bandwidth_multiplier[1L],
        Quantile_level = condition$Quantile_level[1L],
        Samples_per_point = condition$Samples_per_point[1L],
        SVM_nu = condition$SVM_nu[1L], SVM_gamma = condition$SVM_gamma[1L],
        Is_baseline = FALSE, True_area = true_area, Estimated_area = estimated_area,
        Signed_area_error = signed_error, Absolute_area_error = abs(signed_error),
        Relative_area_error_percent = 100 * signed_error / true_area,
        Intersection_area = intersection_area, Union_area = union_area,
        Jaccard_similarity = jaccard_value, Sorensen_similarity = sorensen_value,
        True_region_coverage = coverage, Excess_estimated_area = excess_area,
        Excess_estimated_fraction = excess_fraction,
        Estimated_centroid_axis_1 = estimated_centroid[1L],
        Estimated_centroid_axis_2 = estimated_centroid[2L],
        True_centroid_axis_1 = true_centroid[1L], True_centroid_axis_2 = true_centroid[2L],
        Centroid_displacement = centroid_displacement,
        Geometry_source = "Calculated by revised sensitivity script",
        Set_operation_runtime_seconds = unname(set_time["elapsed"]),
        Set_operation_seed = set_seed, Error_message = NA_character_,
        stringsAsFactors = FALSE
      )
    }
    list(success = TRUE, summary = summary_row)
  }, error = function(e) {
    msg <- conditionMessage(e)
    warning("Geometry sensitivity failed for ", condition_id, ": ", msg)
    list(
      success = FALSE,
      summary = data.frame(
        Condition_id = condition_id, Success = FALSE, Shape_code = shape_name,
        Shape = condition$Shape[1L], Method = method,
        Variation_family = condition$Variation_family[1L],
        Bandwidth_multiplier = condition$Bandwidth_multiplier[1L],
        Quantile_level = condition$Quantile_level[1L],
        Samples_per_point = condition$Samples_per_point[1L],
        SVM_nu = condition$SVM_nu[1L], SVM_gamma = condition$SVM_gamma[1L],
        Is_baseline = condition$Is_baseline[1L], True_area = reference$true_area,
        Estimated_area = registry$Estimated_area[1L], Signed_area_error = registry$Signed_area_error[1L],
        Absolute_area_error = registry$Absolute_area_error[1L],
        Relative_area_error_percent = registry$Relative_area_error_percent[1L],
        Intersection_area = NA_real_, Union_area = NA_real_, Jaccard_similarity = NA_real_,
        Sorensen_similarity = NA_real_, True_region_coverage = NA_real_,
        Excess_estimated_area = NA_real_, Excess_estimated_fraction = NA_real_,
        Estimated_centroid_axis_1 = NA_real_, Estimated_centroid_axis_2 = NA_real_,
        True_centroid_axis_1 = reference$true_centroid[1L],
        True_centroid_axis_2 = reference$true_centroid[2L],
        Centroid_displacement = NA_real_, Geometry_source = NA_character_,
        Set_operation_runtime_seconds = NA_real_, Set_operation_seed = set_seed,
        Error_message = msg, stringsAsFactors = FALSE
      )
    )
  })

  saveRDS(
    list(geometry_analysis_hash = geometry_analysis_hash, results = geometry_results, last_updated = as.character(Sys.time())),
    geometry_checkpoint_file,
    version = 3
  )
}

geometry_summary <- do.call(rbind, lapply(geometry_results, function(x) x$summary))
geometry_summary <- geometry_summary[
  match(sensitivity_design$Condition_id, geometry_summary$Condition_id),
  , drop = FALSE
]
rownames(geometry_summary) <- NULL
write_csv_safely(geometry_summary, geometry_summary_file)
saveRDS(
  list(geometry_analysis_hash = geometry_analysis_hash, results = geometry_results, summary = geometry_summary, completed_at = as.character(Sys.time())),
  geometry_results_output_file,
  version = 3
)

# ============================================================
# Expand unique conditions into plot-ready OFAT series
# ============================================================

expand_sensitivity_series <- function(summary_table) {
  output <- list(); oi <- 0L
  add <- function(row, family, value) {
    oi <<- oi + 1L
    row$Sensitivity_family <- family
    row$Parameter_value <- value
    output[[oi]] <<- row
  }

  for (r in seq_len(nrow(summary_table))) {
    row <- summary_table[r, , drop = FALSE]
    method <- row$Method[1L]
    family <- row$Variation_family[1L]
    baseline <- isTRUE(row$Is_baseline[1L])

    if (baseline && identical(method, "QPH")) {
      add(row, "Bandwidth multiplier", 1)
      add(row, "Quantile", qph_baseline_q)
      add(row, "Sampling effort", baseline_samples_per_point)
    } else if (baseline && identical(method, "Gaussian KDE")) {
      add(row, "Bandwidth multiplier", 1)
      add(row, "Quantile", kde_baseline_quantile)
      add(row, "Sampling effort", baseline_samples_per_point)
    } else if (baseline && identical(method, "SVM")) {
      add(row, "Sampling effort", baseline_samples_per_point)
      add(row, "SVM nu", svm_baseline_nu)
      add(row, "SVM gamma", svm_baseline_gamma)
    } else if (identical(family, "Bandwidth")) {
      add(row, "Bandwidth multiplier", row$Bandwidth_multiplier[1L])
    } else if (identical(family, "Quantile")) {
      add(row, "Quantile", row$Quantile_level[1L])
    } else if (identical(family, "Sampling effort")) {
      add(row, "Sampling effort", row$Samples_per_point[1L])
    } else if (identical(family, "SVM nu")) {
      add(row, "SVM nu", row$SVM_nu[1L])
    } else if (identical(family, "SVM gamma")) {
      add(row, "SVM gamma", row$SVM_gamma[1L])
    }
  }

  if (length(output) == 0L) return(summary_table[FALSE, , drop = FALSE])
  result <- do.call(rbind, output)
  rownames(result) <- NULL
  result
}

geometry_series <- expand_sensitivity_series(geometry_summary)
write_csv_safely(geometry_series, geometry_series_file)

# ============================================================
# Persistent-homology helpers
# ============================================================

tda_calculate_homology_formals <- names(formals(TDAstats::calculate_homology))
tda_supports_prime_field <- "p" %in% tda_calculate_homology_formals

empty_diagram <- function() {
  matrix(
    numeric(0),
    nrow = 0L,
    ncol = 3L,
    dimnames = list(NULL, c("dimension", "birth", "death"))
  )
}

standardize_diagram <- function(diagram) {
  diagram <- as.matrix(diagram)
  storage.mode(diagram) <- "double"
  if (length(diagram) == 0L) return(empty_diagram())
  if (ncol(diagram) != 3L) stop("Persistence diagram must contain three columns.")
  colnames(diagram) <- c("dimension", "birth", "death")
  diagram
}

finite_diagram <- function(diagram) {
  diagram <- standardize_diagram(diagram)
  if (nrow(diagram) == 0L) return(diagram)
  diagram[
    is.finite(diagram[, "birth"]) & is.finite(diagram[, "death"]),
    , drop = FALSE
  ]
}

max_finite_persistence <- function(diagram, dimension) {
  diagram <- finite_diagram(diagram)
  rows <- diagram[diagram[, "dimension"] == dimension, , drop = FALSE]
  if (nrow(rows) == 0L) return(0)
  p <- rows[, "death"] - rows[, "birth"]
  p <- p[is.finite(p) & p >= 0]
  if (length(p) == 0L) return(0)
  max(p)
}

calculate_persistence_with_timeout <- function(points) {
  points <- standardise_points(points)
  start_time <- proc.time()[["elapsed"]]

  tryCatch({
    args <- list(
      mat = points,
      dim = maximum_homology_dimension,
      threshold = ph_threshold,
      format = "cloud"
    )
    if ("standardize" %in% tda_calculate_homology_formals) args$standardize <- ph_standardize
    if ("return_df" %in% tda_calculate_homology_formals) args$return_df <- FALSE
    if (tda_supports_prime_field) args$p <- ph_prime_field

    diagram <- R.utils::withTimeout(
      do.call(TDAstats::calculate_homology, args),
      timeout = ph_timeout_seconds,
      onTimeout = "error"
    )
    list(
      success = TRUE,
      diagram = standardize_diagram(diagram),
      runtime_seconds = proc.time()[["elapsed"]] - start_time,
      failure_type = NA_character_,
      error_message = NA_character_
    )
  }, TimeoutException = function(e) {
    list(
      success = FALSE, diagram = empty_diagram(),
      runtime_seconds = proc.time()[["elapsed"]] - start_time,
      failure_type = "computational-limit failure",
      error_message = conditionMessage(e)
    )
  }, error = function(e) {
    text <- conditionMessage(e)
    timeout <- grepl("time limit|timeout|reached elapsed", text, ignore.case = TRUE)
    list(
      success = FALSE, diagram = empty_diagram(),
      runtime_seconds = proc.time()[["elapsed"]] - start_time,
      failure_type = if (timeout) "computational-limit failure" else "calculation failure",
      error_message = text
    )
  })
}

calculate_bottleneck_safe <- function(occurrence_diagram, method_diagram, dimension) {
  occurrence_diagram <- finite_diagram(occurrence_diagram)
  method_diagram <- finite_diagram(method_diagram)
  tryCatch({
    value <- TDA::bottleneck(
      Diag1 = occurrence_diagram,
      Diag2 = method_diagram,
      dimension = dimension
    )
    list(success = TRUE, distance = as.numeric(value), error_message = NA_character_)
  }, error = function(e) {
    list(success = FALSE, distance = NA_real_, error_message = conditionMessage(e))
  })
}

source_to_key <- function(source_name) gsub("[^A-Za-z0-9]+", "_", source_name)

baseline_persistence_key <- function(shape_name, repetition, source_name) {
  paste(
    scenario_name_for(shape_name),
    paste0("rep", repetition),
    source_to_key(source_name),
    sep = "__"
  )
}

get_baseline_persistence_result <- function(shape_name, repetition, source_name) {
  key <- baseline_persistence_key(shape_name, repetition, source_name)
  result <- baseline_persistence_results[[key]]
  if (is.null(result)) stop("Missing baseline persistence key: ", key)
  result
}

# Validate n=900 paired occurrence subsamples/results.
for (shape_name in expected_shape_names) {
  scenario_indices <- baseline_topology_subsamples$indices[[scenario_name_for(shape_name)]]
  if (is.null(scenario_indices)) stop("Missing baseline topology indices for ", shape_name)
  for (rep in seq_len(number_of_topology_repetitions)) {
    entry <- scenario_indices[[as.character(rep)]]
    if (is.null(entry) || is.null(entry[["Occurrence"]])) stop("Missing occurrence topology entry for ", shape_name, " rep ", rep)
    if (length(entry[["Occurrence"]]$selected_row_indices) != ph_sample_size) stop("Occurrence PH sample size mismatch.")
    invisible(get_baseline_persistence_result(shape_name, rep, "Occurrence"))
  }
}

# ============================================================
# Sensitivity hypervolume topology subsamples
# ============================================================

topology_subsample_hash <- hash_r_object(list(
  parent_hash = analysis_settings_hash,
  ph_sample_size = ph_sample_size,
  repetitions = number_of_topology_repetitions,
  seed_base = sensitivity_topology_seed_base
))

create_sensitivity_topology_subsamples <- function() {
  archive <- list()
  new_conditions <- sensitivity_design[!sensitivity_design$Is_baseline, , drop = FALSE]

  for (condition_index in seq_len(nrow(new_conditions))) {
    condition <- new_conditions[condition_index, , drop = FALSE]
    condition_id <- condition$Condition_id[1L]
    registry <- model_registry[model_registry$Condition_id == condition_id, , drop = FALSE]
    reps <- list()

    if (nrow(registry) != 1L || !isTRUE(registry$Success[1L])) {
      for (rep in seq_len(number_of_topology_repetitions)) {
        reps[[as.character(rep)]] <- list(
          available = FALSE, seed = NA_integer_, source_point_count = NA_integer_,
          selected_row_indices = integer(0), error_message = registry$Error_message[1L]
        )
      }
      archive[[condition_id]] <- reps
      next
    }

    hv <- get_condition_hypervolume(condition_id)
    source_count <- nrow(hv@RandomPoints)

    for (rep in seq_len(number_of_topology_repetitions)) {
      seed <- sensitivity_topology_seed_base + condition_index * 100L + rep
      if (source_count < ph_sample_size) {
        reps[[as.character(rep)]] <- list(
          available = FALSE, seed = seed, source_point_count = source_count,
          selected_row_indices = integer(0),
          error_message = paste0("Only ", source_count, " stochastic points; ", ph_sample_size, " required.")
        )
      } else {
        set.seed(seed)
        selected <- sample.int(source_count, ph_sample_size, replace = FALSE)
        reps[[as.character(rep)]] <- list(
          available = TRUE, seed = seed, source_point_count = source_count,
          selected_row_indices = selected, error_message = NA_character_
        )
      }
    }
    archive[[condition_id]] <- reps
  }

  list(topology_subsample_hash = topology_subsample_hash, indices = archive, created_at = as.character(Sys.time()))
}

# Rebuild deterministically on every Script-04 restart.
#
# This is necessary when a previously failed estimator condition has just
# been repaired: an older archive may permanently mark that condition as
# unavailable. The same seeds are reused, so already-successful conditions
# receive the same subsample indices as before.
sensitivity_topology_subsamples <- create_sensitivity_topology_subsamples()

saveRDS(
  sensitivity_topology_subsamples,
  topology_subsample_file,
  version = 3
)

# ============================================================
# Sensitivity PH calculations
# ============================================================

topology_analysis_hash <- hash_r_object(list(
  parent_hash = analysis_settings_hash,
  topology_subsample_hash = topology_subsample_hash,
  baseline_persistence_md5 = safe_md5(baseline_persistence_file),
  max_dimension = maximum_homology_dimension,
  threshold = ph_threshold,
  prime_field = ph_prime_field,
  standardize = ph_standardize,
  timeout = ph_timeout_seconds,
  TDAstats = installed_tda_stats_version,
  TDA = installed_tda_version
))

if (resume_topology && file.exists(topology_checkpoint_file)) {
  cp <- readRDS(topology_checkpoint_file)
  if (!identical(cp$topology_analysis_hash, topology_analysis_hash)) stop("Incompatible sensitivity topology checkpoint.")
  topology_results <- cp$results
} else {
  topology_results <- list()
}

topology_result_key <- function(condition_id, repetition) {
  paste(condition_id, paste0("rep", repetition), sep = "__")
}

for (condition_index in seq_len(nrow(sensitivity_design))) {
  condition <- sensitivity_design[condition_index, , drop = FALSE]
  condition_id <- condition$Condition_id[1L]
  registry <- model_registry[model_registry$Condition_id == condition_id, , drop = FALSE]

  for (rep in seq_len(number_of_topology_repetitions)) {
    key <- topology_result_key(condition_id, rep)
    existing <- topology_results[[key]]
    if (!is.null(existing) && isTRUE(existing$success)) next
    if (!is.null(existing) && !retry_failed_topology) next

    if (nrow(registry) != 1L || !isTRUE(registry$Success[1L])) {
      topology_results[[key]] <- list(
        key = key, condition_id = condition_id, shape_code = condition$Shape_code[1L],
        shape = condition$Shape[1L], method = condition$Method[1L], repetition = rep,
        success = FALSE, diagram = empty_diagram(), runtime_seconds = NA_real_,
        point_cloud_diameter = NA_real_, selected_row_indices = integer(0),
        subsample_seed = NA_integer_, source = NA_character_, failure_type = "model-fit failure",
        error_message = registry$Error_message[1L]
      )
      next
    }

    if (isTRUE(condition$Is_baseline[1L])) {
      b <- get_baseline_persistence_result(condition$Shape_code[1L], rep, condition$Method[1L])
      topology_results[[key]] <- list(
        key = key, condition_id = condition_id, shape_code = condition$Shape_code[1L],
        shape = condition$Shape[1L], method = condition$Method[1L], repetition = rep,
        success = b$success, diagram = b$diagram, runtime_seconds = b$runtime_seconds,
        point_cloud_diameter = b$point_cloud_diameter,
        selected_row_indices = b$selected_row_indices,
        subsample_seed = b$subsample_seed, source = "Reused revised Script 04 baseline",
        failure_type = b$failure_type, error_message = b$error_message
      )
      next
    }

    condition_entries <- sensitivity_topology_subsamples$indices[[condition_id]]
    entry <- if (is.null(condition_entries)) NULL else condition_entries[[as.character(rep)]]
    if (is.null(entry) || !isTRUE(entry$available)) {
      topology_results[[key]] <- list(
        key = key, condition_id = condition_id, shape_code = condition$Shape_code[1L],
        shape = condition$Shape[1L], method = condition$Method[1L], repetition = rep,
        success = FALSE, diagram = empty_diagram(), runtime_seconds = NA_real_,
        point_cloud_diameter = NA_real_, selected_row_indices = integer(0),
        subsample_seed = if (is.null(entry)) NA_integer_ else entry$seed,
        source = NA_character_, failure_type = "subsample failure",
        error_message = if (is.null(entry)) "Missing sensitivity topology subsample." else entry$error_message
      )
      next
    }

    message("Sensitivity PH: ", condition_id, " rep ", rep)
    hv <- get_condition_hypervolume(condition_id)
    points <- hv@RandomPoints[entry$selected_row_indices, , drop = FALSE]
    ph <- calculate_persistence_with_timeout(points)
    topology_results[[key]] <- c(
      list(
        key = key, condition_id = condition_id, shape_code = condition$Shape_code[1L],
        shape = condition$Shape[1L], method = condition$Method[1L], repetition = rep,
        point_cloud_diameter = point_cloud_diameter(points),
        selected_row_indices = entry$selected_row_indices,
        subsample_seed = entry$seed, source = "Calculated by revised sensitivity script"
      ),
      ph
    )

    saveRDS(
      list(topology_analysis_hash = topology_analysis_hash, results = topology_results, last_updated = as.character(Sys.time())),
      topology_checkpoint_file,
      version = 3
    )
  }
}

saveRDS(topology_results, topology_persistence_file, version = 3)

# ============================================================
# Paired bottleneck replicate table
# ============================================================

topology_rows <- list(); ti <- 0L
for (condition_index in seq_len(nrow(sensitivity_design))) {
  condition <- sensitivity_design[condition_index, , drop = FALSE]
  target_dim <- as.integer(diagnostic_dimension[condition$Shape_code[1L]])

  for (rep in seq_len(number_of_topology_repetitions)) {
    method_result <- topology_results[[topology_result_key(condition$Condition_id[1L], rep)]]
    occurrence_result <- get_baseline_persistence_result(condition$Shape_code[1L], rep, "Occurrence")

    for (dim in 0:maximum_homology_dimension) {
      ti <- ti + 1L
      method_ok <- !is.null(method_result) && isTRUE(method_result$success)
      occurrence_ok <- isTRUE(occurrence_result$success)

      if (!method_ok || !occurrence_ok) {
        errs <- c(if (!is.null(method_result)) method_result$error_message else "Missing method PH", occurrence_result$error_message)
        errs <- errs[!is.na(errs) & nzchar(errs)]
        topology_rows[[ti]] <- data.frame(
          Condition_id = condition$Condition_id[1L], Shape_code = condition$Shape_code[1L], Shape = condition$Shape[1L],
          Method = condition$Method[1L], Variation_family = condition$Variation_family[1L],
          Bandwidth_multiplier = condition$Bandwidth_multiplier[1L], Quantile_level = condition$Quantile_level[1L],
          Samples_per_point = condition$Samples_per_point[1L], SVM_nu = condition$SVM_nu[1L], SVM_gamma = condition$SVM_gamma[1L],
          Is_baseline = condition$Is_baseline[1L], Repetition = rep, Homology_dimension = dim,
          Diagnostic_dimension = target_dim, Is_diagnostic_dimension = dim == target_dim,
          Success = FALSE, Bottleneck_distance = NA_real_, Occurrence_diameter = occurrence_result$point_cloud_diameter,
          Normalized_bottleneck_distance = NA_real_, Method_maximum_persistence = NA_real_,
          Occurrence_maximum_persistence = if (occurrence_ok) max_finite_persistence(occurrence_result$diagram, dim) else NA_real_,
          PH_runtime_seconds = if (is.null(method_result)) NA_real_ else method_result$runtime_seconds,
          Error_message = paste(errs, collapse = " | "), stringsAsFactors = FALSE
        )
        next
      }

      bn <- calculate_bottleneck_safe(occurrence_result$diagram, method_result$diagram, dim)
      occurrence_diameter <- as.numeric(occurrence_result$point_cloud_diameter)
      norm_bn <- if (isTRUE(bn$success) && is.finite(occurrence_diameter) && occurrence_diameter > 0) bn$distance / occurrence_diameter else NA_real_

      topology_rows[[ti]] <- data.frame(
        Condition_id = condition$Condition_id[1L], Shape_code = condition$Shape_code[1L], Shape = condition$Shape[1L],
        Method = condition$Method[1L], Variation_family = condition$Variation_family[1L],
        Bandwidth_multiplier = condition$Bandwidth_multiplier[1L], Quantile_level = condition$Quantile_level[1L],
        Samples_per_point = condition$Samples_per_point[1L], SVM_nu = condition$SVM_nu[1L], SVM_gamma = condition$SVM_gamma[1L],
        Is_baseline = condition$Is_baseline[1L], Repetition = rep, Homology_dimension = dim,
        Diagnostic_dimension = target_dim, Is_diagnostic_dimension = dim == target_dim,
        Success = bn$success, Bottleneck_distance = bn$distance, Occurrence_diameter = occurrence_diameter,
        Normalized_bottleneck_distance = norm_bn,
        Method_maximum_persistence = max_finite_persistence(method_result$diagram, dim),
        Occurrence_maximum_persistence = max_finite_persistence(occurrence_result$diagram, dim),
        PH_runtime_seconds = method_result$runtime_seconds, Error_message = bn$error_message,
        stringsAsFactors = FALSE
      )
    }
  }
}

topology_replicates <- do.call(rbind, topology_rows)
rownames(topology_replicates) <- NULL
write_csv_safely(topology_replicates, topology_replicate_file)

summarise_topology_group <- function(group_data) {
  successful <- group_data[group_data$Success & is.finite(group_data$Bottleneck_distance), , drop = FALSE]
  mb <- if (nrow(successful) > 0L) mean(successful$Bottleneck_distance) else NA_real_
  sb <- safe_sd(successful$Bottleneck_distance)
  mn <- if (nrow(successful) > 0L) mean(successful$Normalized_bottleneck_distance, na.rm = TRUE) else NA_real_
  sn <- safe_sd(successful$Normalized_bottleneck_distance)
  mp <- if (nrow(successful) > 0L) mean(successful$Method_maximum_persistence) else NA_real_
  sp <- safe_sd(successful$Method_maximum_persistence)
  data.frame(
    Repetitions_requested = number_of_topology_repetitions,
    Repetitions_successful = nrow(successful),
    Mean_bottleneck_distance = mb, SD_bottleneck_distance = sb,
    Mean_bottleneck_plus_minus_SD = format_mean_sd(mb, sb),
    Mean_normalized_bottleneck = mn, SD_normalized_bottleneck = sn,
    Mean_normalized_plus_minus_SD = format_mean_sd(mn, sn),
    Mean_maximum_persistence = mp, SD_maximum_persistence = sp,
    Mean_persistence_plus_minus_SD = format_mean_sd(mp, sp),
    stringsAsFactors = FALSE
  )
}

group_keys <- unique(topology_replicates[, c(
  "Condition_id", "Shape_code", "Shape", "Method", "Variation_family",
  "Bandwidth_multiplier", "Quantile_level", "Samples_per_point", "SVM_nu", "SVM_gamma",
  "Is_baseline", "Homology_dimension", "Diagnostic_dimension", "Is_diagnostic_dimension"
), drop = FALSE])

summary_rows <- vector("list", nrow(group_keys))
for (g in seq_len(nrow(group_keys))) {
  key <- group_keys[g, , drop = FALSE]
  data <- topology_replicates[
    topology_replicates$Condition_id == key$Condition_id[1L] &
      topology_replicates$Homology_dimension == key$Homology_dimension[1L],
    , drop = FALSE
  ]
  summary_rows[[g]] <- cbind(key, summarise_topology_group(data))
}

topology_summary <- do.call(rbind, summary_rows)
rownames(topology_summary) <- NULL
write_csv_safely(topology_summary, topology_summary_file)

topology_series <- expand_sensitivity_series(
  topology_summary[topology_summary$Is_diagnostic_dimension, , drop = FALSE]
)
write_csv_safely(topology_series, topology_series_file)

# ============================================================
# Condition-level matched filled-ellipse helpers
# ============================================================

make_positive_definite <- function(covariance_matrix) {
  covariance_matrix <- as.matrix(covariance_matrix)
  covariance_matrix <- (covariance_matrix + t(covariance_matrix)) / 2
  eig <- eigen(covariance_matrix, symmetric = TRUE)
  largest <- max(eig$values)
  floor_value <- max(largest * 1e-10, .Machine$double.eps)
  adjusted <- pmax(eig$values, floor_value)
  eig$vectors %*% diag(adjusted, nrow = length(adjusted)) %*% t(eig$vectors)
}

generate_condition_matched_ellipse <- function(target_points, number_of_points, seed) {
  target_points <- standardise_points(target_points, "target_points")
  number_of_points <- as.integer(number_of_points)
  if (length(number_of_points) != 1L || is.na(number_of_points) || number_of_points < 3L) {
    stop("number_of_points must be >= 3.")
  }

  target_centroid <- colMeans(target_points)
  target_covariance <- make_positive_definite(stats::cov(target_points))
  set.seed(seed)
  theta <- stats::runif(number_of_points, 0, 2 * pi)
  radius <- sqrt(stats::runif(number_of_points))
  unit_disk <- cbind(radius * cos(theta), radius * sin(theta))
  unit_disk <- sweep(unit_disk, 2, colMeans(unit_disk), "-")
  unit_covariance <- make_positive_definite(stats::cov(unit_disk))
  whitened <- unit_disk %*% solve(chol(unit_covariance))
  ellipse_points <- whitened %*% chol(target_covariance)
  ellipse_points <- sweep(ellipse_points, 2, target_centroid, "+")
  ellipse_points <- standardise_points(ellipse_points, "matched ellipse")

  list(
    points = ellipse_points,
    target_centroid = target_centroid,
    target_covariance = target_covariance,
    centroid_error = max(abs(colMeans(ellipse_points) - target_centroid)),
    covariance_error = max(abs(stats::cov(ellipse_points) - target_covariance))
  )
}

# ============================================================
# Matched-reference condition manifest
# ============================================================

manifest_rows <- list(); mi <- 0L
for (shape_name in expected_shape_names) {
  mi <- mi + 1L
  manifest_rows[[mi]] <- data.frame(
    Matched_condition_id = paste0("Occurrence__", shape_name),
    Source_type = "Occurrence", Condition_id = NA_character_,
    Shape_code = shape_name, Shape = unname(shape_labels[shape_name]), Method = "Occurrence",
    Variation_family = "Occurrence", Bandwidth_multiplier = NA_real_, Quantile_level = NA_real_,
    Samples_per_point = NA_integer_, SVM_nu = NA_real_, SVM_gamma = NA_real_, Is_baseline = NA,
    Diagnostic_dimension = as.integer(diagnostic_dimension[shape_name]),
    Diagnostic_label = unname(diagnostic_label[shape_name]),
    stringsAsFactors = FALSE
  )
}

for (r in seq_len(nrow(sensitivity_design))) {
  cnd <- sensitivity_design[r, , drop = FALSE]
  mi <- mi + 1L
  manifest_rows[[mi]] <- data.frame(
    Matched_condition_id = paste0("Estimator__", cnd$Condition_id[1L]),
    Source_type = "Estimator", Condition_id = cnd$Condition_id[1L],
    Shape_code = cnd$Shape_code[1L], Shape = cnd$Shape[1L], Method = cnd$Method[1L],
    Variation_family = cnd$Variation_family[1L], Bandwidth_multiplier = cnd$Bandwidth_multiplier[1L],
    Quantile_level = cnd$Quantile_level[1L], Samples_per_point = cnd$Samples_per_point[1L],
    SVM_nu = cnd$SVM_nu[1L], SVM_gamma = cnd$SVM_gamma[1L], Is_baseline = cnd$Is_baseline[1L],
    Diagnostic_dimension = as.integer(diagnostic_dimension[cnd$Shape_code[1L]]),
    Diagnostic_label = unname(diagnostic_label[cnd$Shape_code[1L]]),
    stringsAsFactors = FALSE
  )
}

matched_reference_manifest <- do.call(rbind, manifest_rows)
rownames(matched_reference_manifest) <- NULL
matched_reference_manifest$Condition_number <- seq_len(nrow(matched_reference_manifest))
matched_reference_manifest$Null_replicates_requested <- number_of_matched_reference_replicates
matched_reference_manifest$Null_point_count <- ph_sample_size
matched_reference_manifest$Matching_basis <- "Full occurrence/hypervolume stochastic cloud centroid and covariance"
write_csv_safely(matched_reference_manifest, matched_reference_manifest_file)

get_full_matched_condition_points <- function(manifest_row) {
  if (identical(manifest_row$Source_type[1L], "Occurrence")) {
    return(get_occurrence_points(manifest_row$Shape_code[1L]))
  }
  hv <- get_condition_hypervolume(manifest_row$Condition_id[1L])
  standardise_points(hv@RandomPoints, "full stochastic cloud")
}

matched_reference_hash <- hash_r_object(list(
  parent_hash = topology_analysis_hash,
  manifest = matched_reference_manifest[, setdiff(names(matched_reference_manifest), "Condition_number"), drop = FALSE],
  null_replicates = number_of_matched_reference_replicates,
  null_points = ph_sample_size,
  seed_base = matched_reference_seed_base,
  ph_threshold = ph_threshold,
  ph_prime_field = ph_prime_field,
  ph_standardize = ph_standardize,
  ph_timeout_seconds = ph_timeout_seconds
))

if (resume_matched_reference && file.exists(matched_reference_checkpoint_file)) {
  cp <- readRDS(matched_reference_checkpoint_file)
  if (!identical(cp$matched_reference_hash, matched_reference_hash)) stop("Incompatible matched-reference checkpoint.")
  matched_reference_results <- cp$results
} else {
  matched_reference_results <- list()
}

matched_null_key <- function(matched_condition_id, null_replicate) {
  paste(matched_condition_id, paste0("null", sprintf("%02d", null_replicate)), sep = "__")
}

# ============================================================
# Run/resume matched filled-ellipse null PH
# ============================================================

for (condition_number in seq_len(nrow(matched_reference_manifest))) {
  mr <- matched_reference_manifest[condition_number, , drop = FALSE]
  matched_condition_id <- mr$Matched_condition_id[1L]

  if (identical(mr$Source_type[1L], "Estimator")) {
    rr <- model_registry[model_registry$Condition_id == mr$Condition_id[1L], , drop = FALSE]
    if (nrow(rr) != 1L || !isTRUE(rr$Success[1L])) next
  }

  full_points <- get_full_matched_condition_points(mr)

  for (null_rep in seq_len(number_of_matched_reference_replicates)) {
    key <- matched_null_key(matched_condition_id, null_rep)
    existing <- matched_reference_results[[key]]
    if (!is.null(existing) && isTRUE(existing$success)) next
    if (!is.null(existing) && !retry_failed_matched_reference) next

    null_seed <- matched_reference_seed_base + condition_number * 1000L + null_rep
    message(
      "Matched ellipse PH ", condition_number, "/", nrow(matched_reference_manifest),
      " null ", null_rep, "/", number_of_matched_reference_replicates, ": ", matched_condition_id
    )

    result <- tryCatch({
      generated <- generate_condition_matched_ellipse(full_points, ph_sample_size, null_seed)
      ph <- calculate_persistence_with_timeout(generated$points)
      c(
        list(
          key = key, matched_condition_id = matched_condition_id,
          condition_number = condition_number, null_replicate = null_rep,
          seed = null_seed, source_type = mr$Source_type[1L],
          condition_id = mr$Condition_id[1L], shape_code = mr$Shape_code[1L],
          shape = mr$Shape[1L], method = mr$Method[1L],
          target_full_point_count = nrow(full_points), null_point_count = ph_sample_size,
          centroid_error = generated$centroid_error,
          covariance_error = generated$covariance_error
        ),
        ph
      )
    }, error = function(e) {
      list(
        key = key, matched_condition_id = matched_condition_id,
        condition_number = condition_number, null_replicate = null_rep,
        seed = null_seed, source_type = mr$Source_type[1L],
        condition_id = mr$Condition_id[1L], shape_code = mr$Shape_code[1L],
        shape = mr$Shape[1L], method = mr$Method[1L],
        target_full_point_count = nrow(full_points), null_point_count = ph_sample_size,
        centroid_error = NA_real_, covariance_error = NA_real_,
        success = FALSE, diagram = empty_diagram(), runtime_seconds = NA_real_,
        failure_type = "null-generation failure", error_message = conditionMessage(e)
      )
    })

    matched_reference_results[[key]] <- result
    saveRDS(
      list(matched_reference_hash = matched_reference_hash, results = matched_reference_results, last_updated = as.character(Sys.time())),
      matched_reference_checkpoint_file,
      version = 3
    )
  }
}

# ============================================================
# Matched-reference replicate table (H0 and H1 retained)
# ============================================================

null_rows <- list(); ni <- 0L
for (condition_number in seq_len(nrow(matched_reference_manifest))) {
  mr <- matched_reference_manifest[condition_number, , drop = FALSE]
  for (null_rep in seq_len(number_of_matched_reference_replicates)) {
    result <- matched_reference_results[[matched_null_key(mr$Matched_condition_id[1L], null_rep)]]
    for (dim in 0:maximum_homology_dimension) {
      ni <- ni + 1L
      null_rows[[ni]] <- data.frame(
        Matched_condition_id = mr$Matched_condition_id[1L], Source_type = mr$Source_type[1L],
        Condition_id = mr$Condition_id[1L], Shape_code = mr$Shape_code[1L], Shape = mr$Shape[1L],
        Method = mr$Method[1L], Null_replicate = null_rep, Homology_dimension = dim,
        Success = !is.null(result) && isTRUE(result$success),
        Maximum_persistence = if (!is.null(result) && isTRUE(result$success)) max_finite_persistence(result$diagram, dim) else NA_real_,
        Runtime_seconds = if (is.null(result)) NA_real_ else result$runtime_seconds,
        Centroid_matching_error = if (is.null(result)) NA_real_ else result$centroid_error,
        Covariance_matching_error = if (is.null(result)) NA_real_ else result$covariance_error,
        Error_message = if (is.null(result)) "Matched-reference result unavailable." else result$error_message,
        stringsAsFactors = FALSE
      )
    }
  }
}

matched_reference_replicates <- do.call(rbind, null_rows)
rownames(matched_reference_replicates) <- NULL
write_csv_safely(matched_reference_replicates, matched_reference_replicate_file)

# ============================================================
# Observed PH vs condition-level reference threshold
# ============================================================

observed_rows <- list(); oi <- 0L
for (condition_number in seq_len(nrow(matched_reference_manifest))) {
  mr <- matched_reference_manifest[condition_number, , drop = FALSE]
  shape_name <- mr$Shape_code[1L]
  target_dim <- as.integer(mr$Diagnostic_dimension[1L])

  good_nulls <- matched_reference_replicates[
    matched_reference_replicates$Matched_condition_id == mr$Matched_condition_id[1L] &
      matched_reference_replicates$Homology_dimension == target_dim &
      matched_reference_replicates$Success &
      is.finite(matched_reference_replicates$Maximum_persistence),
    , drop = FALSE
  ]
  threshold <- if (nrow(good_nulls) > 0L) max(good_nulls$Maximum_persistence) else NA_real_

  for (rep in seq_len(number_of_topology_repetitions)) {
    if (identical(mr$Source_type[1L], "Occurrence")) {
      observed <- get_baseline_persistence_result(shape_name, rep, "Occurrence")
    } else {
      observed <- topology_results[[topology_result_key(mr$Condition_id[1L], rep)]]
    }

    observed_ok <- !is.null(observed) && isTRUE(observed$success)
    observed_max <- if (observed_ok) max_finite_persistence(observed$diagram, target_dim) else NA_real_
    observed_error <- if (is.null(observed)) "Observed PH result unavailable." else observed$error_message

    oi <- oi + 1L
    observed_rows[[oi]] <- data.frame(
      Matched_condition_id = mr$Matched_condition_id[1L], Source_type = mr$Source_type[1L],
      Condition_id = mr$Condition_id[1L], Shape_code = shape_name, Shape = mr$Shape[1L],
      Method = mr$Method[1L], Variation_family = mr$Variation_family[1L],
      Bandwidth_multiplier = mr$Bandwidth_multiplier[1L], Quantile_level = mr$Quantile_level[1L],
      Samples_per_point = mr$Samples_per_point[1L], SVM_nu = mr$SVM_nu[1L], SVM_gamma = mr$SVM_gamma[1L],
      Is_baseline = mr$Is_baseline[1L], Repetition = rep, Homology_dimension = target_dim,
      Diagnostic_label = mr$Diagnostic_label[1L], Observed_success = observed_ok,
      Observed_maximum_persistence = observed_max,
      Null_replicates_requested = number_of_matched_reference_replicates,
      Null_replicates_successful = nrow(good_nulls),
      Matched_reference_threshold = threshold,
      Exceeds_matched_reference = if (observed_ok && is.finite(observed_max) && is.finite(threshold)) observed_max > threshold else NA,
      Error_message = observed_error, stringsAsFactors = FALSE
    )
  }
}

observed_vs_matched_reference <- do.call(rbind, observed_rows)
rownames(observed_vs_matched_reference) <- NULL
write_csv_safely(observed_vs_matched_reference, matched_reference_observed_file)

# ============================================================
# Exceedance-proportion summary
# ============================================================

exceedance_rows <- list(); ei <- 0L
for (condition_number in seq_len(nrow(matched_reference_manifest))) {
  mr <- matched_reference_manifest[condition_number, , drop = FALSE]
  observed <- observed_vs_matched_reference[
    observed_vs_matched_reference$Matched_condition_id == mr$Matched_condition_id[1L],
    , drop = FALSE
  ]
  successful <- observed[
    observed$Observed_success & is.finite(observed$Observed_maximum_persistence) & !is.na(observed$Exceeds_matched_reference),
    , drop = FALSE
  ]
  target_dim <- as.integer(mr$Diagnostic_dimension[1L])
  good_nulls <- matched_reference_replicates[
    matched_reference_replicates$Matched_condition_id == mr$Matched_condition_id[1L] &
      matched_reference_replicates$Homology_dimension == target_dim &
      matched_reference_replicates$Success & is.finite(matched_reference_replicates$Maximum_persistence),
    , drop = FALSE
  ]
  n_exceed <- if (nrow(successful) > 0L) sum(successful$Exceeds_matched_reference) else 0L
  prop_exceed <- if (nrow(successful) > 0L) n_exceed / nrow(successful) else NA_real_

  ei <- ei + 1L
  exceedance_rows[[ei]] <- data.frame(
    Matched_condition_id = mr$Matched_condition_id[1L], Source_type = mr$Source_type[1L],
    Condition_id = mr$Condition_id[1L], Shape_code = mr$Shape_code[1L], Shape = mr$Shape[1L],
    Method = mr$Method[1L], Variation_family = mr$Variation_family[1L],
    Bandwidth_multiplier = mr$Bandwidth_multiplier[1L], Quantile_level = mr$Quantile_level[1L],
    Samples_per_point = mr$Samples_per_point[1L], SVM_nu = mr$SVM_nu[1L], SVM_gamma = mr$SVM_gamma[1L],
    Is_baseline = mr$Is_baseline[1L], Diagnostic_dimension = target_dim,
    Diagnostic_label = mr$Diagnostic_label[1L],
    Null_replicates_requested = number_of_matched_reference_replicates,
    Null_replicates_successful = nrow(good_nulls),
    Matched_reference_threshold = if (nrow(good_nulls) > 0L) max(good_nulls$Maximum_persistence) else NA_real_,
    Observed_repetitions_requested = number_of_topology_repetitions,
    Observed_repetitions_successful = nrow(successful),
    Number_exceeding_matched_reference = n_exceed,
    Exceedance_proportion = prop_exceed,
    Mean_observed_maximum_persistence = if (nrow(successful) > 0L) mean(successful$Observed_maximum_persistence) else NA_real_,
    SD_observed_maximum_persistence = safe_sd(successful$Observed_maximum_persistence),
    stringsAsFactors = FALSE
  )
}

matched_reference_exceedance_summary <- do.call(rbind, exceedance_rows)
rownames(matched_reference_exceedance_summary) <- NULL
write_csv_safely(matched_reference_exceedance_summary, matched_reference_exceedance_file)

matched_reference_diagnostic_summary <- matched_reference_exceedance_summary[
  matched_reference_exceedance_summary$Source_type == "Estimator",
  , drop = FALSE
]
write_csv_safely(matched_reference_diagnostic_summary, matched_reference_diagnostic_file)

matched_reference_series <- expand_sensitivity_series(matched_reference_diagnostic_summary)
write_csv_safely(matched_reference_series, matched_reference_series_file)

# ============================================================
# Failure audit
# ============================================================

failure_rows <- list(); fi <- 0L

mf <- model_registry[!model_registry$Success, , drop = FALSE]
if (nrow(mf) > 0L) {
  for (r in seq_len(nrow(mf))) {
    fi <- fi + 1L
    failure_rows[[fi]] <- data.frame(
      Analysis_stage = "Model fitting", Condition_id = mf$Condition_id[r],
      Shape_code = mf$Shape_code[r], Method = mf$Method[r], Repetition = NA_integer_,
      Error_message = mf$Error_message[r], stringsAsFactors = FALSE
    )
  }
}

gf <- geometry_summary[!geometry_summary$Success, , drop = FALSE]
if (nrow(gf) > 0L) {
  for (r in seq_len(nrow(gf))) {
    fi <- fi + 1L
    failure_rows[[fi]] <- data.frame(
      Analysis_stage = "Geometry", Condition_id = gf$Condition_id[r],
      Shape_code = gf$Shape_code[r], Method = gf$Method[r], Repetition = NA_integer_,
      Error_message = gf$Error_message[r], stringsAsFactors = FALSE
    )
  }
}

tf <- topology_replicates[!topology_replicates$Success, , drop = FALSE]
if (nrow(tf) > 0L) {
  tf <- unique(tf[, c("Condition_id", "Shape_code", "Method", "Repetition", "Error_message"), drop = FALSE])
  for (r in seq_len(nrow(tf))) {
    fi <- fi + 1L
    failure_rows[[fi]] <- data.frame(
      Analysis_stage = "Persistent homology / bottleneck", Condition_id = tf$Condition_id[r],
      Shape_code = tf$Shape_code[r], Method = tf$Method[r], Repetition = tf$Repetition[r],
      Error_message = tf$Error_message[r], stringsAsFactors = FALSE
    )
  }
}

nf <- matched_reference_replicates[!matched_reference_replicates$Success, , drop = FALSE]
if (nrow(nf) > 0L) {
  for (r in seq_len(nrow(nf))) {
    fi <- fi + 1L
    id <- if (is.na(nf$Condition_id[r])) nf$Matched_condition_id[r] else nf$Condition_id[r]
    failure_rows[[fi]] <- data.frame(
      Analysis_stage = "Matched filled-ellipse PH", Condition_id = id,
      Shape_code = nf$Shape_code[r], Method = nf$Method[r], Repetition = nf$Null_replicate[r],
      Error_message = nf$Error_message[r], stringsAsFactors = FALSE
    )
  }
}

if (length(failure_rows) > 0L) {
  failure_table <- do.call(rbind, failure_rows)
} else {
  failure_table <- data.frame(
    Analysis_stage = character(0), Condition_id = character(0), Shape_code = character(0),
    Method = character(0), Repetition = integer(0), Error_message = character(0),
    stringsAsFactors = FALSE
  )
}
write_csv_safely(failure_table, failure_file)

# ============================================================
# Metadata and notes
# ============================================================

run_metadata <- list(
  analysis_settings_hash = analysis_settings_hash,
  analysis_settings = analysis_settings,
  sensitivity_design = sensitivity_design,
  counts = list(
    unique_conditions = nrow(sensitivity_design),
    new_fits_requested = sum(sensitivity_design$Requires_new_fit),
    successful_model_conditions = sum(model_registry$Success),
    geometry_conditions = nrow(geometry_summary),
    topology_condition_repetitions = length(topology_results),
    matched_reference_conditions = nrow(matched_reference_manifest),
    matched_reference_nulls_requested = nrow(matched_reference_manifest) * number_of_matched_reference_replicates
  ),
  completed_at = as.character(Sys.time())
)
saveRDS(run_metadata, run_metadata_file, version = 3)

analysis_notes <- c(
  "Revised 2D synthetic sensitivity analysis",
  "=========================================",
  "",
  paste0("n = ", sensitivity_sample_size),
  "",
  "QPH: sqrt-NB baseline; bandwidth multipliers 0.75, 1.00, 1.25; q = 0.950, 0.975, 0.990.",
  "Gaussian KDE: Silverman baseline; bandwidth multipliers 0.75, 1.00, 1.25; probability quantile = 0.925, 0.950, 0.975.",
  "Sampling effort retained at 25, 50, 100, 150 samples per point.",
  "SVM: nu = 0.010, 0.015 with gamma fixed 0.50; gamma = 0.50, 0.75 with nu fixed 0.010.",
  "",
  paste0("Geometry set-operation num.points.max = ", jaccard_num_points_max, "."),
  paste0("Topology = H0-H1, ", ph_sample_size, " points, ", number_of_topology_repetitions, " repetitions."),
  paste0("PH timeout = ", ph_timeout_seconds, " seconds per calculation."),
  paste0("Matched-reference nulls = ", number_of_matched_reference_replicates, " per condition, ", ph_sample_size, " points each."),
  "Matched-reference matching basis = full occurrence/hypervolume cloud centroid and covariance.",
  "Reported matched-reference statistic = exceedance proportion.",
  "",
  "No sensitivity plots are produced here. Plot-ready 2D tables are saved for later combination with the 3D results.",
  "",
  "Locked colours:",
  "  Gaussian KDE = #D7301F",
  "  SVM = #238B45",
  "  QPH = #2C7FB8",
  "  true region = #D9D9D9",
  "  occurrences = #111111",
  "",
  paste0("Completed: ", Sys.time())
)
writeLines(analysis_notes, analysis_notes_file)
capture.output(sessionInfo(), file = session_information_file)

message("\n============================================================")
message("04_2D_Synthetic_Sensitivity.R complete.")
message("Unique conditions: ", nrow(sensitivity_design))
message("Successful model conditions: ", sum(model_registry$Success), " / ", nrow(model_registry))
message("Geometry summary: ", normalizePath(geometry_summary_file, mustWork = FALSE))
message("Topology summary: ", normalizePath(topology_summary_file, mustWork = FALSE))
message("Matched-reference exceedance summary: ", normalizePath(matched_reference_exceedance_file, mustWork = FALSE))
message("Plot-ready geometry series: ", normalizePath(geometry_series_file, mustWork = FALSE))
message("Plot-ready topology series: ", normalizePath(topology_series_file, mustWork = FALSE))
message("Plot-ready matched-reference series: ", normalizePath(matched_reference_series_file, mustWork = FALSE))
message("Failure audit: ", normalizePath(failure_file, mustWork = FALSE))
message("============================================================")
