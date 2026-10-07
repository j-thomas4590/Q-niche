# ============================================================
# 09_3D_Synthetic_Sensitivity.R
# ============================================================
# FINAL revised 3D synthetic sensitivity analysis at n = 900.
#
# OFAT ranges
# -----------
# QPH:
#   bandwidth multiplier = 0.75, 1.00, 1.25 x revised sqrt-NB h
#   q                    = 0.950, 0.975, 0.990
#   samples per point    = 25, 50, 100, 150
#   baseline             = 1.00 x sqrt-NB, q = 0.99, spp = 100
#
# Gaussian KDE:
#   bandwidth multiplier = 0.75, 1.00, 1.25 x own Silverman bandwidth
#   probability quantile = 0.925, 0.950, 0.975
#   samples per point    = 25, 50, 100, 150
#   baseline             = 1.00 x Silverman, q = 0.95, spp = 100
#
# SVM:
#   nu                   = 0.005, 0.010, 0.015; gamma fixed at 0.50
#   gamma                = 0.25, 0.50, 0.75; nu fixed at 0.010
#   samples per point    = 25, 50, 100, 150
#   baseline             = nu 0.010, gamma 0.50, spp 100
#   scale.factor         = 1
#


rm(list = ls())
gc()


# Run from the repository's root folder.
project_directory <- "."

scripts_directory <- file.path(project_directory, "Scripts")
analysis_root_directory <- file.path(project_directory, "Results", "3D_Synthetic_sqrtNB_q099")
baseline_output_directory <- file.path(analysis_root_directory, "01_Baseline_Fits")
geometry_output_directory <- file.path(analysis_root_directory, "02_Geometry")
topology_output_directory <- file.path(analysis_root_directory, "03_Topology")

baseline_primary_ph_directory <- file.path(
  topology_output_directory,
  "primary_ph_objects"
)

output_directory <- file.path(analysis_root_directory, "04_Sensitivity")
model_object_directory <- file.path(output_directory, "model_objects")
topology_object_directory <- file.path(output_directory, "topology_objects")
matched_reference_object_directory <- file.path(output_directory, "matched_ellipsoid_objects")

for (d in c(output_directory, model_object_directory, topology_object_directory, matched_reference_object_directory)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

qph_core_file <- file.path(scripts_directory, "00_QPH_Core_Functions.R")
if (!file.exists(qph_core_file)) stop("Missing authoritative QPH core: ", qph_core_file)
source(qph_core_file, local = FALSE)
expected_qph_core_version <- "sqrtNB_q099_v1"
if (!exists("QPH_CORE_VERSION") || !identical(as.character(QPH_CORE_VERSION), expected_qph_core_version)) {
  stop("Unexpected QPH core version.")
}
qph_core_md5 <- unname(tools::md5sum(qph_core_file))

required_packages <- c("hypervolume", "e1071", "TDAstats", "TDA", "R.utils")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0L) stop("Install required package(s): ", paste(missing_packages, collapse = ", "))
library(hypervolume)
library(e1071)
library(TDAstats)
library(TDA)
library(R.utils)

# ------------------------------------------------------------
# Locked design
# ------------------------------------------------------------
shape_order <- c("solid_ball", "solid_torus", "hollow_shell")
shape_labels <- c(
  solid_ball = "Solid ball",
  solid_torus = "Solid torus",
  hollow_shell = "Hollow spherical region"
)
method_order <- c("Gaussian KDE", "SVM", "QPH")

sensitivity_sample_size <- 900L
baseline_samples_per_point <- 100L
baseline_sd_count <- 3L

qph_bandwidth_multipliers <- c(0.75, 1.00, 1.25)
qph_baseline_q <- 0.99
qph_q_values <- c(0.950, 0.975, 0.990)

kde_bandwidth_multipliers <- c(0.75, 1.00, 1.25)
kde_baseline_quantile <- 0.95
kde_quantile_values <- c(0.925, 0.950, 0.975)

samples_per_point_values <- c(25L, 50L, 100L, 150L)

svm_baseline_nu <- 0.010
svm_nu_values <- c(0.005, 0.010, 0.015)
svm_baseline_gamma <- 0.50
svm_gamma_values <- c(0.25, 0.50, 0.75)
svm_scale_factor <- 1

shared_chunk_size <- 100L
potential_batch_size <- 500L
show_progress_messages <- TRUE

sensitivity_fit_seed_base <- 161001L
sensitivity_geometry_seed_base <- 171001L
sensitivity_topology_seed_base <- 181001L
matched_reference_seed_base <- 2310001L

jaccard_num_points_max <- 10000L
jaccard_distance_factor <- 1

ph_sample_size <- 300L
number_of_topology_repetitions <- 10L
maximum_homology_dimension <- 2L
ph_threshold <- -1
ph_prime_field <- 2L
ph_standardize <- FALSE
ph_timeout_seconds <- 6 * 60
number_of_matched_reference_replicates <- 20L

resume_model_fits <- TRUE
resume_geometry <- TRUE
resume_topology <- TRUE
resume_matched_reference <- TRUE
retry_failed_model_fits <- TRUE
retry_failed_geometry <- TRUE
retry_failed_topology <- TRUE
retry_failed_matched_reference <- TRUE

method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)
true_region_colour <- "#D9D9D9"
occurrence_colour <- "#111111"

# ------------------------------------------------------------
# Inputs / outputs
# ------------------------------------------------------------
baseline_results_file <- file.path(baseline_output_directory, "baseline_fit_results_3D_sqrtNB_q099.rds")
geometry_results_file <- file.path(geometry_output_directory, "synthetic_geometry_results_3D_sqrtNB_q099.rds")
topology_results_file <- file.path(topology_output_directory, "synthetic_topology_results_3D_sqrtNB_q099.rds")

for (f in c(baseline_results_file, geometry_results_file, topology_results_file)) {
  if (!file.exists(f)) stop("Required revised input missing: ", f)
}

sensitivity_design_file <- file.path(output_directory, "sensitivity_design_3D_sqrtNB_q099.csv")
analysis_settings_file <- file.path(output_directory, "sensitivity_analysis_settings_3D_sqrtNB_q099.rds")
model_checkpoint_file <- file.path(output_directory, "sensitivity_model_checkpoint_3D_sqrtNB_q099.rds")
model_registry_file <- file.path(output_directory, "sensitivity_model_registry_3D_sqrtNB_q099.csv")
model_results_file <- file.path(output_directory, "sensitivity_model_results_3D_sqrtNB_q099.rds")
qph_audit_summary_file <- file.path(output_directory, "QPH_sensitivity_audit_summary_3D_sqrtNB_q099.csv")
qph_local_s_file <- file.path(output_directory, "QPH_sensitivity_local_s_3D_sqrtNB_q099.csv")
geometry_checkpoint_file <- file.path(output_directory, "sensitivity_geometry_checkpoint_3D_sqrtNB_q099.rds")
geometry_summary_file <- file.path(output_directory, "sensitivity_geometry_summary_3D_sqrtNB_q099.csv")
geometry_series_file <- file.path(output_directory, "sensitivity_geometry_plot_series_3D_sqrtNB_q099.csv")
geometry_results_output_file <- file.path(output_directory, "sensitivity_geometry_results_3D_sqrtNB_q099.rds")
topology_subsample_file <- file.path(output_directory, "sensitivity_topology_subsample_indices_3D_sqrtNB_q099.rds")
topology_checkpoint_file <- file.path(output_directory, "sensitivity_topology_checkpoint_3D_sqrtNB_q099.rds")
topology_replicate_file <- file.path(output_directory, "sensitivity_topology_replicates_3D_sqrtNB_q099.csv")
topology_summary_file <- file.path(output_directory, "sensitivity_topology_mean_sd_3D_sqrtNB_q099.csv")
topology_series_file <- file.path(output_directory, "sensitivity_topology_plot_series_3D_sqrtNB_q099.csv")
matched_reference_manifest_file <- file.path(output_directory, "matched_reference_condition_manifest_3D_sqrtNB_q099.csv")
matched_reference_checkpoint_file <- file.path(output_directory, "matched_reference_checkpoint_3D_sqrtNB_q099.rds")
matched_reference_replicate_file <- file.path(output_directory, "matched_ellipsoid_null_replicates_3D_sqrtNB_q099.csv")
matched_reference_threshold_file <- file.path(output_directory, "matched_ellipsoid_thresholds_3D_sqrtNB_q099.csv")
matched_reference_observed_file <- file.path(output_directory, "matched_ellipsoid_observed_results_3D_sqrtNB_q099.csv")
matched_reference_exceedance_file <- file.path(output_directory, "matched_ellipsoid_exceedance_summary_3D_sqrtNB_q099.csv")
matched_reference_series_file <- file.path(output_directory, "matched_ellipsoid_plot_series_3D_sqrtNB_q099.csv")
failure_file <- file.path(output_directory, "sensitivity_failures_3D_sqrtNB_q099.csv")
final_results_file <- file.path(output_directory, "synthetic_sensitivity_results_3D_sqrtNB_q099.rds")
notes_file <- file.path(output_directory, "SENSITIVITY_ANALYSIS_NOTES_3D_sqrtNB_q099.txt")
session_information_file <- file.path(output_directory, "sensitivity_session_information_3D_sqrtNB_q099.txt")

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
safe_md5 <- function(path) if (file.exists(path)) unname(tools::md5sum(path)) else NA_character_

hash_r_object <- function(object) {
  tf <- tempfile(fileext = ".rds")
  on.exit(unlink(tf), add = TRUE)
  saveRDS(object, tf, version = 3)
  safe_md5(tf)
}

write_csv_safely <- function(x, file) {
  tryCatch(
    utils::write.csv(x, file, row.names = FALSE),
    error = function(e) {
      alt <- sub("\\.csv$", paste0("_new_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"), file)
      warning("Could not overwrite ", basename(file), "; writing ", basename(alt), ".")
      utils::write.csv(x, alt, row.names = FALSE)
    }
  )
}

safe_mean <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0L) NA_real_ else mean(x)
}

safe_sd <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) <= 1L) NA_real_ else stats::sd(x)
}

format_mean_sd <- function(m, s, digits = 4L) {
  if (!is.finite(m)) return(NA_character_)
  if (!is.finite(s)) return(formatC(m, digits = digits, format = "fg"))
  paste0(formatC(m, digits = digits, format = "fg"), " +/- ", formatC(s, digits = digits, format = "fg"))
}

value_label <- function(x) {
  if (length(x) != 1L || is.na(x)) return("NA")
  gsub("\\.", "p", format(x, scientific = FALSE, trim = TRUE, digits = 15))
}

make_safe_id <- function(x) gsub("[^A-Za-z0-9._-]+", "_", x)

set_axis_names <- function(x) {
  x <- as.matrix(x)
  storage.mode(x) <- "double"
  if (nrow(x) < 1L || ncol(x) != 3L || any(!is.finite(x))) stop("Expected finite n x 3 points.")
  colnames(x) <- c("X1", "X2", "X3")
  x
}

standardise_hv <- function(hv) {
  if (!methods::is(hv, "Hypervolume")) stop("Expected Hypervolume object.")
  if (as.integer(hv@Dimensionality) != 3L) stop("Expected 3D Hypervolume object.")
  if (ncol(hv@Data) == 3L) colnames(hv@Data) <- c("X1", "X2", "X3")
  if (ncol(hv@RandomPoints) == 3L) colnames(hv@RandomPoints) <- c("X1", "X2", "X3")
  methods::validObject(hv)
  hv
}

method_key <- function(method) switch(method, "QPH" = "qph", "Gaussian KDE" = "gaussian_kde", "SVM" = "svm", stop("Unknown method"))
source_code <- function(source) if (identical(source, "Occurrence")) "occurrence" else method_key(source)
scenario_name_for <- function(shape, n) paste(shape, n, sep = "_")
primary_ph_key <- function(shape, n, rep, source) paste(shape, paste0("n", n), paste0("rep", rep), source_code(source), sep = "__")

# ------------------------------------------------------------
# Load and validate upstream results
# ------------------------------------------------------------
baseline_results <- readRDS(baseline_results_file)
geometry_results <- readRDS(geometry_results_file)
topology_results <- readRDS(topology_results_file)

if (is.null(baseline_results$metadata) || is.null(baseline_results$occurrence_archive) || is.null(baseline_results$scenarios)) stop("Unexpected Script 06 output.")
if (is.null(geometry_results$true_references) || is.null(geometry_results$geometry_summary)) stop("Unexpected Script 07 output.")
if (is.null(topology_results$primary_ph_registry) || is.null(topology_results$matched_ellipsoid_null_thresholds)) stop("Unexpected Script 08 output.")

baseline_metadata <- baseline_results$metadata
occurrence_archive <- baseline_results$occurrence_archive
baseline_scenarios <- baseline_results$scenarios
true_references <- geometry_results$true_references
baseline_geometry_summary <- geometry_results$geometry_summary
baseline_topology_registry <- topology_results$primary_ph_registry
baseline_null_thresholds <- topology_results$matched_ellipsoid_null_thresholds

if (!identical(as.character(baseline_metadata$qph_core_version), expected_qph_core_version)) stop("Unexpected revised QPH core in Script 06.")
if (!identical(as.character(baseline_metadata$shape_order), shape_order)) stop("Unexpected shape order in Script 06.")
if (as.integer(topology_results$metadata$ph_sample_size) != ph_sample_size) stop("Script 08 PH sample size mismatch.")
if (as.integer(topology_results$metadata$number_of_repetitions) != number_of_topology_repetitions) stop("Script 08 repetition mismatch.")
if (as.integer(topology_results$metadata$maximum_homology_dimension) != maximum_homology_dimension) stop("Script 08 homology dimension mismatch.")
if (as.integer(topology_results$metadata$number_of_null_replicates) != number_of_matched_reference_replicates) stop("Script 08 null count mismatch.")
if (is.null(topology_results$metadata$null_design) || topology_results$metadata$null_design != "shared_condition_level_full_source_cloud") stop("Script 08 must be the revised shared-null version.")

get_occurrence_points <- function(shape) {
  set_axis_names(occurrence_archive$occurrence_subsets[[shape]][[as.character(sensitivity_sample_size)]]$points)
}
get_baseline_scenario <- function(shape) baseline_scenarios[[scenario_name_for(shape, sensitivity_sample_size)]]
get_baseline_hv <- function(shape, method) standardise_hv(get_baseline_scenario(shape)[[method_key(method)]]$hypervolume)
get_baseline_seed <- function(shape, method) as.integer(get_baseline_scenario(shape)[[method_key(method)]]$sampling_seed)

get_baseline_geometry_row <- function(shape, method) {
  x <- baseline_geometry_summary[
    baseline_geometry_summary$Shape_code == shape &
      baseline_geometry_summary$Sample_size == sensitivity_sample_size &
      baseline_geometry_summary$Method == method,
    , drop = FALSE
  ]
  if (nrow(x) != 1L) stop("Expected one Script 07 geometry row for ", shape, " / ", method)
  x
}

resolve_baseline_ph_object_file <- function(key, entry) {

  if (is.null(entry)) {
    stop("Script 08 PH registry has no entry for: ", key)
  }

  stored_path <- entry$object_file

  candidates <- c(
    if (!is.null(stored_path) &&
        length(stored_path) == 1L &&
        !is.na(stored_path) &&
        nzchar(stored_path)) {
      stored_path
    } else {
      character(0)
    },
    file.path(
      baseline_primary_ph_directory,
      paste0(key, ".rds")
    ),
    if (!is.null(stored_path) &&
        length(stored_path) == 1L &&
        !is.na(stored_path) &&
        nzchar(stored_path)) {
      file.path(
        baseline_primary_ph_directory,
        basename(stored_path)
      )
    } else {
      character(0)
    }
  )

  candidates <- unique(candidates)
  existing <- candidates[file.exists(candidates)]

  if (length(existing) == 0L) {
    stop(
      "Missing Script 08 PH object: ", key,
      "\nStored registry path may refer to the previous computer.",
      "\nExpected relocated object at:\n  ",
      file.path(
        baseline_primary_ph_directory,
        paste0(key, ".rds")
      )
    )
  }

  normalizePath(
    existing[[1L]],
    winslash = "/",
    mustWork = TRUE
  )
}


get_baseline_ph <- function(shape, rep, source) {

  key <- primary_ph_key(
    shape,
    sensitivity_sample_size,
    rep,
    source
  )

  entry <- baseline_topology_registry[[key]]

  object_file <- resolve_baseline_ph_object_file(
    key,
    entry
  )

  readRDS(object_file)
}

for (shape in shape_order) {
  if (nrow(get_occurrence_points(shape)) != sensitivity_sample_size) stop("Occurrence n mismatch for ", shape)
  sc <- get_baseline_scenario(shape)
  qa <- sc$qph$audit
  if (as.integer(qa$K) != round(sqrt(sensitivity_sample_size))) stop("QPH K mismatch for ", shape)
  if (!isTRUE(all.equal(as.numeric(qa$baseline_scalar_h), sqrt(mean(qa$local_s)), tolerance = 1e-12))) stop("QPH sqrt-NB audit mismatch for ", shape)
  if (!isTRUE(all.equal(as.numeric(qa$q), qph_baseline_q))) stop("QPH q mismatch for ", shape)
  if (!isTRUE(all.equal(as.numeric(sc$gaussian_kde$probability_quantile), kde_baseline_quantile))) stop("KDE q mismatch for ", shape)
  shv <- standardise_hv(sc$svm$hypervolume)
  if (!isTRUE(all.equal(as.numeric(shv@Parameters$svm.nu), svm_baseline_nu))) stop("SVM nu mismatch for ", shape)
  if (!isTRUE(all.equal(as.numeric(shv@Parameters$svm.gamma), svm_baseline_gamma))) stop("SVM gamma mismatch for ", shape)
}

# ------------------------------------------------------------
# Sensitivity design: 8 QPH + 8 KDE + 8 SVM per shape
# ------------------------------------------------------------
create_sensitivity_design <- function() {
  rows <- list(); i <- 0L
  add <- function(shape, method, family, bw = NA_real_, q = NA_real_, spp = baseline_samples_per_point,
                  nu = NA_real_, gamma = NA_real_, varied = NA_real_, baseline = FALSE) {
    i <<- i + 1L
    code <- if (identical(method, "Gaussian KDE")) "KDE" else method
    id <- paste(shape, code, gsub(" ", "_", family), paste0("bw", value_label(bw)), paste0("q", value_label(q)),
                paste0("spp", spp), paste0("nu", value_label(nu)), paste0("gamma", value_label(gamma)), sep = "__")
    rows[[i]] <<- data.frame(
      Condition_id = id, Shape_code = shape, Shape = unname(shape_labels[[shape]]), Sample_size = sensitivity_sample_size,
      Method = method, Variation_family = family, Bandwidth_multiplier = bw, Quantile_level = q,
      Samples_per_point = as.integer(spp), SVM_nu = nu, SVM_gamma = gamma, Varied_value = varied,
      Is_baseline = baseline, stringsAsFactors = FALSE
    )
  }

  for (shape in shape_order) {
    add(shape, "QPH", "Baseline", 1, qph_baseline_q, baseline = TRUE)
    for (v in setdiff(qph_bandwidth_multipliers, 1)) add(shape, "QPH", "Bandwidth", v, qph_baseline_q, varied = v)
    for (v in setdiff(qph_q_values, qph_baseline_q)) add(shape, "QPH", "Quantile", 1, v, varied = v)
    for (v in setdiff(samples_per_point_values, baseline_samples_per_point)) add(shape, "QPH", "Sampling effort", 1, qph_baseline_q, v, varied = v)

    add(shape, "Gaussian KDE", "Baseline", 1, kde_baseline_quantile, baseline = TRUE)
    for (v in setdiff(kde_bandwidth_multipliers, 1)) add(shape, "Gaussian KDE", "Bandwidth", v, kde_baseline_quantile, varied = v)
    for (v in setdiff(kde_quantile_values, kde_baseline_quantile)) add(shape, "Gaussian KDE", "Quantile", 1, v, varied = v)
    for (v in setdiff(samples_per_point_values, baseline_samples_per_point)) add(shape, "Gaussian KDE", "Sampling effort", 1, kde_baseline_quantile, v, varied = v)

    add(shape, "SVM", "Baseline", spp = baseline_samples_per_point, nu = svm_baseline_nu, gamma = svm_baseline_gamma, baseline = TRUE)
    for (v in setdiff(samples_per_point_values, baseline_samples_per_point)) add(shape, "SVM", "Sampling effort", spp = v, nu = svm_baseline_nu, gamma = svm_baseline_gamma, varied = v)
    for (v in setdiff(svm_nu_values, svm_baseline_nu)) add(shape, "SVM", "SVM nu", nu = v, gamma = svm_baseline_gamma, varied = v)
    for (v in setdiff(svm_gamma_values, svm_baseline_gamma)) add(shape, "SVM", "SVM gamma", nu = svm_baseline_nu, gamma = v, varied = v)
  }

  out <- do.call(rbind, rows); rownames(out) <- NULL
  out$Fit_seed <- sensitivity_fit_seed_base + seq_len(nrow(out))
  for (r in seq_len(nrow(out))) if (isTRUE(out$Is_baseline[r])) out$Fit_seed[r] <- get_baseline_seed(out$Shape_code[r], out$Method[r])
  out$Requires_new_fit <- !out$Is_baseline
  out
}

sensitivity_design <- create_sensitivity_design()
expected_total_conditions <- length(shape_order) * (8L + 8L + 8L)
expected_new_fits <- length(shape_order) * (7L + 7L + 7L)
if (nrow(sensitivity_design) != expected_total_conditions) stop("Unexpected condition count.")
if (sum(sensitivity_design$Requires_new_fit) != expected_new_fits) stop("Unexpected new-fit count.")
if (anyDuplicated(sensitivity_design$Condition_id)) stop("Duplicated condition IDs.")
write_csv_safely(sensitivity_design, sensitivity_design_file)

installed_hypervolume_version <- as.character(utils::packageVersion("hypervolume"))
installed_tda_stats_version <- as.character(utils::packageVersion("TDAstats"))
installed_tda_version <- as.character(utils::packageVersion("TDA"))

analysis_settings <- list(
  script = "09_3D_Synthetic_Sensitivity.R", qph_core_version = QPH_CORE_VERSION, qph_core_md5 = qph_core_md5,
  baseline_md5 = safe_md5(baseline_results_file), geometry_md5 = safe_md5(geometry_results_file), topology_md5 = safe_md5(topology_results_file),
  design = sensitivity_design[, setdiff(names(sensitivity_design), "Fit_seed"), drop = FALSE],
  ph_sample_size = ph_sample_size, topology_repetitions = number_of_topology_repetitions,
  maximum_homology_dimension = maximum_homology_dimension, ph_threshold = ph_threshold, ph_prime_field = ph_prime_field,
  ph_standardize = ph_standardize, ph_timeout_seconds = ph_timeout_seconds, null_replicates = number_of_matched_reference_replicates,
  seeds = c(sensitivity_fit_seed_base, sensitivity_geometry_seed_base, sensitivity_topology_seed_base, matched_reference_seed_base),
  colours = c(method_colours, true_region_colour, occurrence_colour),
  package_versions = c(hypervolume = installed_hypervolume_version, TDAstats = installed_tda_stats_version, TDA = installed_tda_version)
)
analysis_settings_hash <- hash_r_object(analysis_settings)
saveRDS(list(analysis_settings_hash = analysis_settings_hash, analysis_settings = analysis_settings), analysis_settings_file, version = 3)

# ------------------------------------------------------------
# Model fitting / reuse
# ------------------------------------------------------------
empty_model_registry <- function() data.frame(
  Condition_id = character(), Success = logical(), Shape_code = character(), Shape = character(), Sample_size = integer(), Method = character(),
  Variation_family = character(), Bandwidth_multiplier = numeric(), Quantile_level = numeric(), Samples_per_point = integer(), SVM_nu = numeric(),
  SVM_gamma = numeric(), Is_baseline = logical(), Fit_seed = integer(), Fit_source = character(), Object_file = character(), True_volume = numeric(),
  Estimated_volume = numeric(), Runtime_seconds = numeric(), Base_bandwidth_axis_1 = numeric(), Base_bandwidth_axis_2 = numeric(), Base_bandwidth_axis_3 = numeric(),
  Used_bandwidth_axis_1 = numeric(), Used_bandwidth_axis_2 = numeric(), Used_bandwidth_axis_3 = numeric(), QPH_K = integer(), QPH_mean_s = numeric(),
  QPH_scalar_h = numeric(), QPH_retained_fraction = numeric(), Error_message = character(), stringsAsFactors = FALSE
)

model_object_path <- function(id) file.path(model_object_directory, paste0(make_safe_id(id), ".rds"))

if (resume_model_fits && file.exists(model_checkpoint_file)) {
  cp <- readRDS(model_checkpoint_file)
  if (!identical(cp$analysis_settings_hash, analysis_settings_hash)) stop("Incompatible sensitivity model checkpoint.")
  model_registry <- cp$registry
} else model_registry <- empty_model_registry()


# Repair absolute model-object paths after moving the project between
# computers. Baseline rows intentionally have no sensitivity object file.
if (nrow(model_registry) > 0L) {

  for (row_index in seq_len(nrow(model_registry))) {

    if (isTRUE(model_registry$Is_baseline[[row_index]])) {
      next
    }

    condition_id <- model_registry$Condition_id[[row_index]]
    current_object_file <- model_object_path(condition_id)

    if (file.exists(current_object_file)) {
      model_registry$Object_file[[row_index]] <- normalizePath(
        current_object_file,
        winslash = "/",
        mustWork = TRUE
      )
    }
  }
}


registry_row <- function(id) {
  x <- model_registry[model_registry$Condition_id == id, , drop = FALSE]
  if (nrow(x) == 0L) return(NULL)
  if (nrow(x) > 1L) stop("Duplicate registry row: ", id)
  x
}
replace_registry_row <- function(row) {
  keep <- model_registry$Condition_id != row$Condition_id[1L]
  model_registry <<- rbind(model_registry[keep, , drop = FALSE], row)
  rownames(model_registry) <<- NULL
}
save_model_checkpoint <- function() {
  saveRDS(list(analysis_settings_hash = analysis_settings_hash, registry = model_registry), model_checkpoint_file, version = 3)
  write_csv_safely(model_registry, model_registry_file)
}

for (ci in seq_len(nrow(sensitivity_design))) {
  cnd <- sensitivity_design[ci, , drop = FALSE]
  id <- cnd$Condition_id[1L]
  existing <- registry_row(id)
  if (!is.null(existing) && isTRUE(existing$Success[1L]) && (isTRUE(existing$Is_baseline[1L]) || (!is.na(existing$Object_file[1L]) && file.exists(existing$Object_file[1L])))) next
  if (!is.null(existing) && !isTRUE(existing$Success[1L]) && !retry_failed_model_fits) next

  shape <- cnd$Shape_code[1L]; method <- cnd$Method[1L]; pts <- get_occurrence_points(shape)
  true_volume <- as.numeric(true_references[[shape]]$exact_true_volume)
  seed <- as.integer(cnd$Fit_seed[1L]); object_file <- model_object_path(id)
  message("Sensitivity fit ", ci, "/", nrow(sensitivity_design), ": ", id)

  if (isTRUE(cnd$Is_baseline[1L])) {
    sc <- get_baseline_scenario(shape); fr <- sc[[method_key(method)]]; hv <- standardise_hv(fr$hypervolume)
    base_bw <- used_bw <- c(NA_real_, NA_real_, NA_real_); qk <- NA_integer_; qm <- qh <- qr <- NA_real_
    if (method == "QPH") {
      base_bw <- as.numeric(fr$audit$baseline_isotropic_bandwidth); used_bw <- as.numeric(fr$audit$fitted_bandwidth)
      qk <- as.integer(fr$audit$K); qm <- as.numeric(fr$audit$mean_s); qh <- as.numeric(fr$audit$baseline_scalar_h); qr <- as.numeric(fr$retained_fraction)
    }
    if (method == "Gaussian KDE") base_bw <- used_bw <- as.numeric(fr$bandwidth)
    row <- data.frame(
      Condition_id = id, Success = TRUE, Shape_code = shape, Shape = cnd$Shape[1L], Sample_size = sensitivity_sample_size, Method = method,
      Variation_family = cnd$Variation_family[1L], Bandwidth_multiplier = cnd$Bandwidth_multiplier[1L], Quantile_level = cnd$Quantile_level[1L],
      Samples_per_point = cnd$Samples_per_point[1L], SVM_nu = cnd$SVM_nu[1L], SVM_gamma = cnd$SVM_gamma[1L], Is_baseline = TRUE,
      Fit_seed = seed, Fit_source = "Reused revised Script 06 baseline", Object_file = NA_character_, True_volume = true_volume,
      Estimated_volume = as.numeric(hv@Volume), Runtime_seconds = as.numeric(fr$runtime_seconds),
      Base_bandwidth_axis_1 = base_bw[1], Base_bandwidth_axis_2 = base_bw[2], Base_bandwidth_axis_3 = base_bw[3],
      Used_bandwidth_axis_1 = used_bw[1], Used_bandwidth_axis_2 = used_bw[2], Used_bandwidth_axis_3 = used_bw[3],
      QPH_K = qk, QPH_mean_s = qm, QPH_scalar_h = qh, QPH_retained_fraction = qr, Error_message = NA_character_, stringsAsFactors = FALSE
    )
    replace_registry_row(row); save_model_checkpoint(); next
  }

  start <- proc.time()[["elapsed"]]
  fit <- tryCatch({
    if (method == "QPH") {
      bi <- estimate_qph_sqrt_nb_bandwidth(pts)
      base <- get_baseline_scenario(shape)$qph
      if (!isTRUE(all.equal(as.numeric(bi$bandwidth), as.numeric(base$audit$baseline_isotropic_bandwidth), tolerance = 1e-12))) stop("QPH baseline bandwidth mismatch.")
      used <- bi$bandwidth * as.numeric(cnd$Bandwidth_multiplier[1L])
      qr <- construct_qph(data = pts, bandwidth = used, bandwidth_info = bi, name = paste0("QPH sensitivity: ", id),
                          samples_per_point = as.integer(cnd$Samples_per_point[1L]), sd_count = baseline_sd_count, q = as.numeric(cnd$Quantile_level[1L]),
                          sampling_seed = seed, sampling_chunk_size = shared_chunk_size, potential_batch_size = potential_batch_size, verbose = show_progress_messages)
      list(hv = standardise_hv(qr$hypervolume), qph = qr, base = as.numeric(bi$bandwidth), used = as.numeric(used),
           k = as.integer(qr$audit$K), mean_s = as.numeric(qr$audit$mean_s), h = as.numeric(qr$audit$baseline_scalar_h), retained = as.numeric(qr$retained_fraction))
    } else if (method == "Gaussian KDE") {

      # Preserve the exact intended numerical sensitivity bandwidth:
      #   h_used = multiplier * h_Silverman.
      #
      # Repackage that vector through estimate_bandwidth(method = "fixed")
      # so hypervolume_gaussian() receives the method metadata required by
      # current hypervolume versions.
      base <- as.numeric(
        get_baseline_scenario(shape)$gaussian_kde$bandwidth
      )

      used_numeric <- (
        base *
          as.numeric(cnd$Bandwidth_multiplier[1L])
      )

      used <- hypervolume::estimate_bandwidth(
        data = pts,
        method = "fixed",
        value = used_numeric
      )

      set.seed(seed)

      hv <- hypervolume::hypervolume_gaussian(
        data = pts,
        name = paste0("KDE sensitivity: ", id),
        kde.bandwidth = used,
        samples.per.point = as.integer(cnd$Samples_per_point[1L]),
        sd.count = baseline_sd_count,
        quantile.requested = as.numeric(cnd$Quantile_level[1L]),
        quantile.requested.type = "probability",
        chunk.size = shared_chunk_size,
        verbose = show_progress_messages
      )

      list(
        hv = standardise_hv(hv),
        qph = NULL,
        base = base,
        used = as.numeric(used),
        k = NA_integer_,
        mean_s = NA_real_,
        h = NA_real_,
        retained = NA_real_
      )
    } else {
      set.seed(seed)
      hv <- hypervolume::hypervolume_svm(data = pts, name = paste0("SVM sensitivity: ", id), samples.per.point = as.integer(cnd$Samples_per_point[1L]),
                                         svm.nu = as.numeric(cnd$SVM_nu[1L]), svm.gamma = as.numeric(cnd$SVM_gamma[1L]), scale.factor = svm_scale_factor,
                                         chunk.size = shared_chunk_size, verbose = show_progress_messages)
      list(hv = standardise_hv(hv), qph = NULL, base = c(NA_real_, NA_real_, NA_real_), used = c(NA_real_, NA_real_, NA_real_),
           k = NA_integer_, mean_s = NA_real_, h = NA_real_, retained = NA_real_)
    }
  }, error = function(e) list(error = TRUE, error_message = conditionMessage(e)))
  runtime <- proc.time()[["elapsed"]] - start

  if (isTRUE(fit$error)) {
    row <- data.frame(Condition_id = id, Success = FALSE, Shape_code = shape, Shape = cnd$Shape[1L], Sample_size = sensitivity_sample_size, Method = method,
      Variation_family = cnd$Variation_family[1L], Bandwidth_multiplier = cnd$Bandwidth_multiplier[1L], Quantile_level = cnd$Quantile_level[1L],
      Samples_per_point = cnd$Samples_per_point[1L], SVM_nu = cnd$SVM_nu[1L], SVM_gamma = cnd$SVM_gamma[1L], Is_baseline = FALSE,
      Fit_seed = seed, Fit_source = "New Script 09 fit", Object_file = NA_character_, True_volume = true_volume, Estimated_volume = NA_real_, Runtime_seconds = runtime,
      Base_bandwidth_axis_1 = NA_real_, Base_bandwidth_axis_2 = NA_real_, Base_bandwidth_axis_3 = NA_real_, Used_bandwidth_axis_1 = NA_real_,
      Used_bandwidth_axis_2 = NA_real_, Used_bandwidth_axis_3 = NA_real_, QPH_K = NA_integer_, QPH_mean_s = NA_real_, QPH_scalar_h = NA_real_,
      QPH_retained_fraction = NA_real_, Error_message = fit$error_message, stringsAsFactors = FALSE)
    replace_registry_row(row); save_model_checkpoint(); next
  }

  saveRDS(list(analysis_settings_hash = analysis_settings_hash, condition = cnd, hypervolume = fit$hv, qph_result = fit$qph, fit_seed = seed, runtime_seconds = runtime), object_file, version = 3)
  row <- data.frame(Condition_id = id, Success = TRUE, Shape_code = shape, Shape = cnd$Shape[1L], Sample_size = sensitivity_sample_size, Method = method,
    Variation_family = cnd$Variation_family[1L], Bandwidth_multiplier = cnd$Bandwidth_multiplier[1L], Quantile_level = cnd$Quantile_level[1L],
    Samples_per_point = cnd$Samples_per_point[1L], SVM_nu = cnd$SVM_nu[1L], SVM_gamma = cnd$SVM_gamma[1L], Is_baseline = FALSE,
    Fit_seed = seed, Fit_source = "New Script 09 fit", Object_file = object_file, True_volume = true_volume, Estimated_volume = as.numeric(fit$hv@Volume), Runtime_seconds = runtime,
    Base_bandwidth_axis_1 = fit$base[1], Base_bandwidth_axis_2 = fit$base[2], Base_bandwidth_axis_3 = fit$base[3],
    Used_bandwidth_axis_1 = fit$used[1], Used_bandwidth_axis_2 = fit$used[2], Used_bandwidth_axis_3 = fit$used[3],
    QPH_K = fit$k, QPH_mean_s = fit$mean_s, QPH_scalar_h = fit$h, QPH_retained_fraction = fit$retained, Error_message = NA_character_, stringsAsFactors = FALSE)
  replace_registry_row(row); save_model_checkpoint()
}

model_registry <- model_registry[match(sensitivity_design$Condition_id, model_registry$Condition_id), , drop = FALSE]
rownames(model_registry) <- NULL
write_csv_safely(model_registry, model_registry_file)
saveRDS(list(analysis_settings_hash = analysis_settings_hash, design = sensitivity_design, registry = model_registry), model_results_file, version = 3)

get_condition_model_object_file <- function(id) {

  current_file <- model_object_path(id)

  if (file.exists(current_file)) {
    return(
      normalizePath(
        current_file,
        winslash = "/",
        mustWork = TRUE
      )
    )
  }

  r <- model_registry[
    model_registry$Condition_id == id,
    ,
    drop = FALSE
  ]

  if (nrow(r) == 1L &&
      !is.na(r$Object_file[[1L]]) &&
      nzchar(r$Object_file[[1L]]) &&
      file.exists(r$Object_file[[1L]])) {
    return(
      normalizePath(
        r$Object_file[[1L]],
        winslash = "/",
        mustWork = TRUE
      )
    )
  }

  stop(
    "Missing Script 09 model object: ",
    id,
    "\nExpected relocated object at:\n  ",
    current_file
  )
}


get_condition_hv <- function(id) {

  d <- sensitivity_design[
    sensitivity_design$Condition_id == id,
    ,
    drop = FALSE
  ]

  r <- model_registry[
    model_registry$Condition_id == id,
    ,
    drop = FALSE
  ]

  if (nrow(d) != 1L ||
      nrow(r) != 1L ||
      !isTRUE(r$Success[[1L]])) {
    stop("Unavailable condition: ", id)
  }

  if (isTRUE(d$Is_baseline[[1L]])) {
    return(
      get_baseline_hv(
        d$Shape_code[[1L]],
        d$Method[[1L]]
      )
    )
  }

  object_file <- get_condition_model_object_file(id)

  standardise_hv(
    readRDS(object_file)$hypervolume
  )
}

# QPH audit exports.
qa_rows <- list(); qs_rows <- list(); qi <- 0L; qsi <- 0L
for (r in seq_len(nrow(sensitivity_design))) {
  cnd <- sensitivity_design[r, , drop = FALSE]
  if (cnd$Method[1L] != "QPH") next
  shape <- cnd$Shape_code[1L]
  if (isTRUE(cnd$Is_baseline[1L])) {
    qr <- get_baseline_scenario(shape)$qph
  } else {
    rr <- registry_row(cnd$Condition_id[1L]); if (is.null(rr) || !isTRUE(rr$Success[1L])) next
    qr <- readRDS(
      get_condition_model_object_file(
        cnd$Condition_id[1L]
      )
    )$qph_result
  }
  a <- qr$audit; qi <- qi + 1L
  qa_rows[[qi]] <- data.frame(Condition_id = cnd$Condition_id[1L], Shape_code = shape, Variation_family = cnd$Variation_family[1L], Is_baseline = cnd$Is_baseline[1L],
    n = a$n, d = a$d, K = a$K, Mean_s = a$mean_s, Baseline_scalar_h = a$baseline_scalar_h,
    Fitted_bandwidth_axis_1 = a$fitted_bandwidth[1], Fitted_bandwidth_axis_2 = a$fitted_bandwidth[2], Fitted_bandwidth_axis_3 = a$fitted_bandwidth[3],
    q = a$q, Samples_per_point = a$samples_per_point, SD_count = a$sd_count, Sampling_seed = a$sampling_seed,
    Retained_fraction = qr$retained_fraction, stringsAsFactors = FALSE)
  qsi <- qsi + 1L
  qs_rows[[qsi]] <- data.frame(Condition_id = cnd$Condition_id[1L], Shape_code = shape, Occurrence_index = seq_along(a$local_s), K = a$K,
    s_i = as.numeric(a$local_s), Mean_s = a$mean_s, Baseline_scalar_h = a$baseline_scalar_h, stringsAsFactors = FALSE)
}
if (length(qa_rows) > 0L) write_csv_safely(do.call(rbind, qa_rows), qph_audit_summary_file)
if (length(qs_rows) > 0L) write_csv_safely(do.call(rbind, qs_rows), qph_local_s_file)


# ============================================================
# Geometry sensitivity
# ============================================================
component_volume <- function(hv_set, candidates, required = FALSE) {
  available <- names(hv_set@HVList)
  idx <- match(tolower(candidates), tolower(available), nomatch = 0L)
  idx <- idx[idx > 0L]
  if (length(idx) == 0L) {
    if (required) stop("Missing HypervolumeSet component: ", paste(candidates, collapse = ", "))
    return(NA_real_)
  }
  obj <- hv_set@HVList[[idx[1L]]]
  if (!methods::is(obj, "Hypervolume")) {
    if (required) stop("Requested set component is not a Hypervolume.")
    return(NA_real_)
  }
  as.numeric(obj@Volume)
}

calculate_geometry_metrics <- function(hv, reference, seed) {
  hv <- standardise_hv(hv); true_hv <- standardise_hv(reference$hypervolume)
  true_volume <- as.numeric(reference$exact_true_volume); est_volume <- as.numeric(hv@Volume)
  est_centroid <- colMeans(hv@RandomPoints); ref_centroid <- as.numeric(reference$centroid)
  centroid_distance <- sqrt(sum((est_centroid - ref_centroid)^2))
  signed_error <- est_volume - true_volume
  set.seed(as.integer(seed))
  timing <- system.time({
    hs <- hypervolume::hypervolume_set(hv1 = hv, hv2 = true_hv, num.points.max = jaccard_num_points_max,
                                      verbose = FALSE, check.memory = FALSE, distance.factor = jaccard_distance_factor)
  })
  stats <- hypervolume::hypervolume_overlap_statistics(hs)
  inter <- component_volume(hs, "Intersection", TRUE)
  est_only <- component_volume(hs, c("Unique_1", "Unique 1", "Unique1"))
  true_only <- component_volume(hs, c("Unique_2", "Unique 2", "Unique2"))
  union <- component_volume(hs, "Union")
  if (!is.finite(est_only)) est_only <- max(est_volume - inter, 0)
  if (!is.finite(true_only)) true_only <- max(true_volume - inter, 0)
  if (!is.finite(union)) union <- inter + est_only + true_only
  jaccard <- if ("jaccard" %in% names(stats)) as.numeric(stats[["jaccard"]]) else inter / union
  sorensen <- if (is.finite(jaccard)) 2 * jaccard / (1 + jaccard) else NA_real_
  coverage <- inter / true_volume
  excess <- max(est_only, 0)
  data.frame(
    Exact_true_volume = true_volume, Estimated_volume = est_volume, Signed_volume_error = signed_error,
    Absolute_volume_error = abs(signed_error), Relative_volume_error_percent = 100 * signed_error / true_volume,
    Absolute_relative_volume_error_percent = abs(100 * signed_error / true_volume), Intersection_volume = inter,
    Estimated_only_volume = est_only, True_only_volume = true_only, Union_volume = union, Jaccard_similarity = jaccard,
    Sorensen_similarity = sorensen, True_region_coverage = coverage, True_region_coverage_percent = 100 * coverage,
    Excess_estimated_volume = excess, Excess_estimated_volume_percent_of_true = 100 * excess / true_volume,
    Excess_estimated_fraction = excess / est_volume, Estimated_centroid_X1 = est_centroid[1], Estimated_centroid_X2 = est_centroid[2],
    Estimated_centroid_X3 = est_centroid[3], Reference_centroid_X1 = ref_centroid[1], Reference_centroid_X2 = ref_centroid[2],
    Reference_centroid_X3 = ref_centroid[3], Centroid_displacement = centroid_distance,
    Set_operation_runtime_seconds = unname(timing[["elapsed"]]), Set_operation_seed = as.integer(seed), stringsAsFactors = FALSE
  )
}

geometry_analysis_hash <- hash_r_object(list(parent_hash = analysis_settings_hash, geometry_md5 = safe_md5(geometry_results_file),
                                              num_points_max = jaccard_num_points_max, distance_factor = jaccard_distance_factor,
                                              seed_base = sensitivity_geometry_seed_base))
if (resume_geometry && file.exists(geometry_checkpoint_file)) {
  cp <- readRDS(geometry_checkpoint_file)
  if (!identical(cp$geometry_analysis_hash, geometry_analysis_hash)) stop("Incompatible geometry sensitivity checkpoint.")
  sensitivity_geometry_results <- cp$results
} else sensitivity_geometry_results <- list()

save_geometry_checkpoint <- function() saveRDS(list(geometry_analysis_hash = geometry_analysis_hash, results = sensitivity_geometry_results),
                                               geometry_checkpoint_file, version = 3)

for (ci in seq_len(nrow(sensitivity_design))) {
  cnd <- sensitivity_design[ci, , drop = FALSE]; id <- cnd$Condition_id[1L]; shape <- cnd$Shape_code[1L]
  existing <- sensitivity_geometry_results[[id]]
  if (!is.null(existing) && isTRUE(existing$success)) next
  if (!is.null(existing) && !retry_failed_geometry) next
  rr <- model_registry[model_registry$Condition_id == id, , drop = FALSE]
  if (nrow(rr) != 1L || !isTRUE(rr$Success[1L])) {
    sensitivity_geometry_results[[id]] <- list(success = FALSE, summary = NULL, error_message = if (nrow(rr) == 1L) rr$Error_message[1L] else "Missing model row")
    save_geometry_checkpoint(); next
  }
  message("Geometry sensitivity ", ci, "/", nrow(sensitivity_design), ": ", id)
  result <- tryCatch({
    if (isTRUE(cnd$Is_baseline[1L])) {
      b <- get_baseline_geometry_row(shape, cnd$Method[1L])
      if (!isTRUE(b$Geometry_success[1L])) stop("Script 07 baseline geometry failed.")
      s <- data.frame(
        Condition_id = id, Success = TRUE, Shape_code = shape, Shape = cnd$Shape[1L], Method = cnd$Method[1L],
        Variation_family = cnd$Variation_family[1L], Bandwidth_multiplier = cnd$Bandwidth_multiplier[1L], Quantile_level = cnd$Quantile_level[1L],
        Samples_per_point = cnd$Samples_per_point[1L], SVM_nu = cnd$SVM_nu[1L], SVM_gamma = cnd$SVM_gamma[1L], Is_baseline = TRUE,
        Exact_true_volume = b$Exact_true_volume[1L], Estimated_volume = b$Estimated_volume[1L], Signed_volume_error = b$Signed_volume_error[1L],
        Absolute_volume_error = b$Absolute_volume_error[1L], Relative_volume_error_percent = b$Relative_volume_error_percent[1L],
        Absolute_relative_volume_error_percent = b$Absolute_relative_volume_error_percent[1L], Intersection_volume = b$Intersection_volume[1L],
        Estimated_only_volume = b$Estimated_only_volume[1L], True_only_volume = b$True_only_volume[1L], Union_volume = b$Union_volume[1L],
        Jaccard_similarity = b$Jaccard_similarity[1L], Sorensen_similarity = b$Sorensen_similarity[1L], True_region_coverage = b$True_region_coverage[1L],
        True_region_coverage_percent = b$True_region_coverage_percent[1L], Excess_estimated_volume = b$Excess_estimated_volume[1L],
        Excess_estimated_volume_percent_of_true = b$Excess_estimated_volume_percent_of_true[1L], Excess_estimated_fraction = b$Excess_estimated_fraction[1L],
        Estimated_centroid_X1 = b$Estimated_centroid_X1[1L], Estimated_centroid_X2 = b$Estimated_centroid_X2[1L], Estimated_centroid_X3 = b$Estimated_centroid_X3[1L],
        Reference_centroid_X1 = b$Reference_centroid_X1[1L], Reference_centroid_X2 = b$Reference_centroid_X2[1L], Reference_centroid_X3 = b$Reference_centroid_X3[1L],
        Centroid_displacement = b$Centroid_displacement[1L], Set_operation_runtime_seconds = b$Set_operation_runtime_seconds[1L],
        Set_operation_seed = b$Set_operation_seed[1L], Geometry_source = "Reused revised Script 07 baseline", Error_message = NA_character_, stringsAsFactors = FALSE
      )
    } else {
      m <- calculate_geometry_metrics(get_condition_hv(id), true_references[[shape]], sensitivity_geometry_seed_base + ci)
      s <- cbind(data.frame(Condition_id = id, Success = TRUE, Shape_code = shape, Shape = cnd$Shape[1L], Method = cnd$Method[1L],
                            Variation_family = cnd$Variation_family[1L], Bandwidth_multiplier = cnd$Bandwidth_multiplier[1L], Quantile_level = cnd$Quantile_level[1L],
                            Samples_per_point = cnd$Samples_per_point[1L], SVM_nu = cnd$SVM_nu[1L], SVM_gamma = cnd$SVM_gamma[1L], Is_baseline = FALSE,
                            stringsAsFactors = FALSE), m,
                 data.frame(Geometry_source = "New Script 09 geometry", Error_message = NA_character_, stringsAsFactors = FALSE))
    }
    list(success = TRUE, summary = s, error_message = NA_character_)
  }, error = function(e) list(success = FALSE, summary = NULL, error_message = conditionMessage(e)))
  sensitivity_geometry_results[[id]] <- result; save_geometry_checkpoint()
}

geometry_rows <- list()
for (ci in seq_len(nrow(sensitivity_design))) {
  cnd <- sensitivity_design[ci, , drop = FALSE]; id <- cnd$Condition_id[1L]; r <- sensitivity_geometry_results[[id]]
  if (!is.null(r) && isTRUE(r$success) && !is.null(r$summary)) geometry_rows[[ci]] <- r$summary else {
    geometry_rows[[ci]] <- data.frame(
      Condition_id = id, Success = FALSE, Shape_code = cnd$Shape_code[1L], Shape = cnd$Shape[1L], Method = cnd$Method[1L],
      Variation_family = cnd$Variation_family[1L], Bandwidth_multiplier = cnd$Bandwidth_multiplier[1L], Quantile_level = cnd$Quantile_level[1L],
      Samples_per_point = cnd$Samples_per_point[1L], SVM_nu = cnd$SVM_nu[1L], SVM_gamma = cnd$SVM_gamma[1L], Is_baseline = cnd$Is_baseline[1L],
      Exact_true_volume = as.numeric(true_references[[cnd$Shape_code[1L]]]$exact_true_volume), Estimated_volume = NA_real_, Signed_volume_error = NA_real_,
      Absolute_volume_error = NA_real_, Relative_volume_error_percent = NA_real_, Absolute_relative_volume_error_percent = NA_real_, Intersection_volume = NA_real_,
      Estimated_only_volume = NA_real_, True_only_volume = NA_real_, Union_volume = NA_real_, Jaccard_similarity = NA_real_, Sorensen_similarity = NA_real_,
      True_region_coverage = NA_real_, True_region_coverage_percent = NA_real_, Excess_estimated_volume = NA_real_, Excess_estimated_volume_percent_of_true = NA_real_,
      Excess_estimated_fraction = NA_real_, Estimated_centroid_X1 = NA_real_, Estimated_centroid_X2 = NA_real_, Estimated_centroid_X3 = NA_real_,
      Reference_centroid_X1 = NA_real_, Reference_centroid_X2 = NA_real_, Reference_centroid_X3 = NA_real_, Centroid_displacement = NA_real_,
      Set_operation_runtime_seconds = NA_real_, Set_operation_seed = NA_integer_, Geometry_source = NA_character_,
      Error_message = if (is.null(r)) "Missing geometry result" else r$error_message, stringsAsFactors = FALSE)
  }
}
geometry_summary <- do.call(rbind, geometry_rows); rownames(geometry_summary) <- NULL
write_csv_safely(geometry_summary, geometry_summary_file)
saveRDS(list(geometry_analysis_hash = geometry_analysis_hash, results = sensitivity_geometry_results, summary = geometry_summary), geometry_results_output_file, version = 3)

# Plot-ready OFAT expansion: baseline is represented in each family it anchors.
expand_sensitivity_series <- function(tab) {
  out <- list(); oi <- 0L
  add <- function(row, family, value) { oi <<- oi + 1L; row$Sensitivity_family <- family; row$Parameter_value <- value; out[[oi]] <<- row }
  for (r in seq_len(nrow(tab))) {
    row <- tab[r, , drop = FALSE]; method <- row$Method[1L]; family <- row$Variation_family[1L]; baseline <- isTRUE(row$Is_baseline[1L])
    if (baseline && method == "QPH") { add(row, "Bandwidth multiplier", 1); add(row, "Quantile", qph_baseline_q); add(row, "Sampling effort", baseline_samples_per_point) }
    else if (baseline && method == "Gaussian KDE") { add(row, "Bandwidth multiplier", 1); add(row, "Quantile", kde_baseline_quantile); add(row, "Sampling effort", baseline_samples_per_point) }
    else if (baseline && method == "SVM") { add(row, "Sampling effort", baseline_samples_per_point); add(row, "SVM nu", svm_baseline_nu); add(row, "SVM gamma", svm_baseline_gamma) }
    else if (family == "Bandwidth") add(row, "Bandwidth multiplier", row$Bandwidth_multiplier[1L])
    else if (family == "Quantile") add(row, "Quantile", row$Quantile_level[1L])
    else if (family == "Sampling effort") add(row, "Sampling effort", row$Samples_per_point[1L])
    else if (family == "SVM nu") add(row, "SVM nu", row$SVM_nu[1L])
    else if (family == "SVM gamma") add(row, "SVM gamma", row$SVM_gamma[1L])
  }
  if (length(out) == 0L) return(tab[FALSE, , drop = FALSE])
  ans <- do.call(rbind, out); rownames(ans) <- NULL; ans
}

geometry_series <- expand_sensitivity_series(geometry_summary)
write_csv_safely(geometry_series, geometry_series_file)


# ============================================================
# Persistent homology helpers
# ============================================================
tda_calculate_homology_formals <- names(formals(TDAstats::calculate_homology))
tda_supports_prime_field <- "p" %in% tda_calculate_homology_formals

empty_diagram <- function() matrix(numeric(0), nrow = 0L, ncol = 3L, dimnames = list(NULL, c("dimension", "birth", "death")))

standardize_diagram <- function(diagram) {
  if (is.null(diagram)) return(empty_diagram())
  diagram <- as.matrix(diagram)
  if (nrow(diagram) == 0L) return(empty_diagram())
  if (ncol(diagram) < 3L) stop("Persistence diagram has fewer than three columns.")
  diagram <- diagram[, seq_len(3L), drop = FALSE]
  colnames(diagram) <- c("dimension", "birth", "death")
  storage.mode(diagram) <- "double"
  diagram
}

finite_diagram <- function(diagram) {
  diagram <- standardize_diagram(diagram)
  diagram[is.finite(diagram[, "birth"]) & is.finite(diagram[, "death"]), , drop = FALSE]
}

max_finite_persistence <- function(diagram, dimension) {
  d <- finite_diagram(diagram); rows <- d[d[, "dimension"] == dimension, , drop = FALSE]
  if (nrow(rows) == 0L) return(0)
  p <- rows[, "death"] - rows[, "birth"]; p <- p[is.finite(p) & p >= 0]
  if (length(p) == 0L) 0 else max(p)
}

point_cloud_diameter <- function(points) {
  points <- set_axis_names(points)
  if (nrow(points) < 2L) return(NA_real_)
  max(stats::dist(points))
}

calculate_persistence_with_timeout <- function(points) {
  points <- set_axis_names(points); start <- proc.time()[["elapsed"]]
  tryCatch({
    args <- list(mat = points, dim = maximum_homology_dimension, threshold = ph_threshold, format = "cloud")
    if ("standardize" %in% tda_calculate_homology_formals) args$standardize <- ph_standardize
    if ("return_df" %in% tda_calculate_homology_formals) args$return_df <- FALSE
    if (tda_supports_prime_field) args$p <- ph_prime_field
    diagram <- R.utils::withTimeout(do.call(TDAstats::calculate_homology, args), timeout = ph_timeout_seconds, onTimeout = "error")
    list(success = TRUE, diagram = standardize_diagram(diagram), runtime_seconds = proc.time()[["elapsed"]] - start,
         failure_type = NA_character_, error_message = NA_character_)
  }, TimeoutException = function(e) {
    list(success = FALSE, diagram = empty_diagram(), runtime_seconds = proc.time()[["elapsed"]] - start,
         failure_type = "computational-limit failure", error_message = conditionMessage(e))
  }, error = function(e) {
    txt <- conditionMessage(e); timeout <- grepl("time limit|timeout|reached elapsed", txt, ignore.case = TRUE)
    list(success = FALSE, diagram = empty_diagram(), runtime_seconds = proc.time()[["elapsed"]] - start,
         failure_type = if (timeout) "computational-limit failure" else "calculation failure", error_message = txt)
  })
}

calculate_bottleneck_safe <- function(occurrence_diagram, method_diagram, dimension) {
  tryCatch({
    value <- TDA::bottleneck(Diag1 = finite_diagram(occurrence_diagram), Diag2 = finite_diagram(method_diagram), dimension = as.integer(dimension))
    list(success = TRUE, distance = as.numeric(value), error_message = NA_character_)
  }, error = function(e) list(success = FALSE, distance = NA_real_, error_message = conditionMessage(e)))
}

# ============================================================
# Lock 10 estimator PH subsamples for NEW sensitivity conditions
# ============================================================
topology_subsample_hash <- hash_r_object(list(parent_hash = analysis_settings_hash, ph_sample_size = ph_sample_size,
                                               repetitions = number_of_topology_repetitions, seed_base = sensitivity_topology_seed_base))

create_sensitivity_topology_subsamples <- function() {
  archive <- list(); new <- sensitivity_design[!sensitivity_design$Is_baseline, , drop = FALSE]
  for (ci in seq_len(nrow(new))) {
    cnd <- new[ci, , drop = FALSE]; id <- cnd$Condition_id[1L]; rr <- model_registry[model_registry$Condition_id == id, , drop = FALSE]; reps <- list()
    if (nrow(rr) != 1L || !isTRUE(rr$Success[1L])) {
      for (rep in seq_len(number_of_topology_repetitions)) reps[[as.character(rep)]] <- list(available = FALSE, seed = NA_integer_, source_point_count = NA_integer_, selected_row_indices = integer(0), error_message = if (nrow(rr) == 1L) rr$Error_message[1L] else "Missing model row")
      archive[[id]] <- reps; next
    }
    hv <- get_condition_hv(id); npoints <- nrow(hv@RandomPoints)
    for (rep in seq_len(number_of_topology_repetitions)) {
      seed <- sensitivity_topology_seed_base + ci * 100L + rep
      if (npoints < ph_sample_size) reps[[as.character(rep)]] <- list(available = FALSE, seed = seed, source_point_count = npoints, selected_row_indices = integer(0), error_message = "Too few stochastic points")
      else { set.seed(seed); idx <- sample.int(npoints, ph_sample_size, replace = FALSE); reps[[as.character(rep)]] <- list(available = TRUE, seed = seed, source_point_count = npoints, selected_row_indices = idx, error_message = NA_character_) }
    }
    archive[[id]] <- reps
  }
  list(topology_subsample_hash = topology_subsample_hash, indices = archive)
}

# Rebuild deterministically on every Script-09 restart.
#
# This prevents a stale archive created while KDE conditions were failed
# from continuing to mark those repaired conditions as unavailable. Seeds
# are unchanged, so already-successful conditions receive the same indices.
sensitivity_topology_subsamples <- create_sensitivity_topology_subsamples()

saveRDS(
  sensitivity_topology_subsamples,
  topology_subsample_file,
  version = 3
)

# ============================================================
# Sensitivity PH calculations: baseline PH is reused from Script 08
# ============================================================
topology_analysis_hash <- hash_r_object(list(parent_hash = analysis_settings_hash, topology_subsample_hash = topology_subsample_hash,
  topology_md5 = safe_md5(topology_results_file), max_dimension = maximum_homology_dimension, threshold = ph_threshold,
  prime_field = ph_prime_field, standardize = ph_standardize, timeout = ph_timeout_seconds,
  TDAstats = installed_tda_stats_version, TDA = installed_tda_version))

if (resume_topology && file.exists(topology_checkpoint_file)) {
  cp <- readRDS(topology_checkpoint_file)
  if (!identical(cp$topology_analysis_hash, topology_analysis_hash)) stop("Incompatible topology sensitivity checkpoint.")
  sensitivity_topology_results <- cp$results
} else sensitivity_topology_results <- list()

save_topology_checkpoint <- function() saveRDS(list(topology_analysis_hash = topology_analysis_hash, results = sensitivity_topology_results), topology_checkpoint_file, version = 3)
topology_result_key <- function(id, rep) paste(id, paste0("rep", rep), sep = "__")

for (ci in seq_len(nrow(sensitivity_design))) {
  cnd <- sensitivity_design[ci, , drop = FALSE]; id <- cnd$Condition_id[1L]; rr <- model_registry[model_registry$Condition_id == id, , drop = FALSE]
  for (rep in seq_len(number_of_topology_repetitions)) {
    key <- topology_result_key(id, rep); existing <- sensitivity_topology_results[[key]]
    if (!is.null(existing) && isTRUE(existing$success)) next
    if (!is.null(existing) && !retry_failed_topology) next
    if (nrow(rr) != 1L || !isTRUE(rr$Success[1L])) {
      sensitivity_topology_results[[key]] <- list(key = key, condition_id = id, shape_code = cnd$Shape_code[1L], shape = cnd$Shape[1L], method = cnd$Method[1L], repetition = rep,
        success = FALSE, diagram = empty_diagram(), runtime_seconds = NA_real_, point_cloud_diameter = NA_real_, selected_row_indices = integer(0), subsample_seed = NA_integer_,
        source = NA_character_, failure_type = "model-fit failure", error_message = if (nrow(rr) == 1L) rr$Error_message[1L] else "Missing model row")
      save_topology_checkpoint(); next
    }
    if (isTRUE(cnd$Is_baseline[1L])) {
      b <- get_baseline_ph(cnd$Shape_code[1L], rep, cnd$Method[1L])
      sensitivity_topology_results[[key]] <- list(key = key, condition_id = id, shape_code = cnd$Shape_code[1L], shape = cnd$Shape[1L], method = cnd$Method[1L], repetition = rep,
        success = b$success, diagram = b$diagram, runtime_seconds = b$runtime_seconds, point_cloud_diameter = b$point_cloud_diameter,
        selected_row_indices = b$sampled_indices, subsample_seed = b$subsample_seed, source = "Reused revised Script 08 baseline",
        failure_type = b$failure_type, error_message = b$error_message)
      save_topology_checkpoint(); next
    }
    entries <- sensitivity_topology_subsamples$indices[[id]]; entry <- if (is.null(entries)) NULL else entries[[as.character(rep)]]
    if (is.null(entry) || !isTRUE(entry$available)) {
      sensitivity_topology_results[[key]] <- list(key = key, condition_id = id, shape_code = cnd$Shape_code[1L], shape = cnd$Shape[1L], method = cnd$Method[1L], repetition = rep,
        success = FALSE, diagram = empty_diagram(), runtime_seconds = NA_real_, point_cloud_diameter = NA_real_, selected_row_indices = integer(0),
        subsample_seed = if (is.null(entry)) NA_integer_ else entry$seed, source = "New Script 09 condition", failure_type = "missing subsample",
        error_message = if (is.null(entry)) "Subsample unavailable" else entry$error_message)
      save_topology_checkpoint(); next
    }
    message("Sensitivity PH: ", id, " rep ", rep)
    hv <- get_condition_hv(id); points <- set_axis_names(hv@RandomPoints[entry$selected_row_indices, , drop = FALSE]); ph <- calculate_persistence_with_timeout(points)
    sensitivity_topology_results[[key]] <- c(list(key = key, condition_id = id, shape_code = cnd$Shape_code[1L], shape = cnd$Shape[1L], method = cnd$Method[1L], repetition = rep,
      point_cloud_diameter = point_cloud_diameter(points), sampled_points = points, selected_row_indices = entry$selected_row_indices, subsample_seed = entry$seed,
      source = "New Script 09 condition"), ph)
    save_topology_checkpoint()
  }
}

# ============================================================
# Bottleneck replicate table: H0-H2 vs paired occurrence PH
# ============================================================
topology_rows <- list(); ti <- 0L
for (ci in seq_len(nrow(sensitivity_design))) {
  cnd <- sensitivity_design[ci, , drop = FALSE]; id <- cnd$Condition_id[1L]; shape <- cnd$Shape_code[1L]
  for (rep in seq_len(number_of_topology_repetitions)) {
    mr <- sensitivity_topology_results[[topology_result_key(id, rep)]]
    or <- get_baseline_ph(shape, rep, "Occurrence")
    for (dim in 0:maximum_homology_dimension) {
      ti <- ti + 1L
      ok <- !is.null(mr) && isTRUE(mr$success) && isTRUE(or$success)
      if (ok) {
        bn <- calculate_bottleneck_safe(or$diagram, mr$diagram, dim)
        norm <- if (isTRUE(bn$success) && is.finite(or$point_cloud_diameter) && or$point_cloud_diameter > 0) bn$distance / or$point_cloud_diameter else NA_real_
      } else { bn <- list(success = FALSE, distance = NA_real_, error_message = "Observed/method PH failure"); norm <- NA_real_ }
      topology_rows[[ti]] <- data.frame(
        Condition_id = id, Shape_code = shape, Shape = cnd$Shape[1L], Method = cnd$Method[1L], Variation_family = cnd$Variation_family[1L],
        Bandwidth_multiplier = cnd$Bandwidth_multiplier[1L], Quantile_level = cnd$Quantile_level[1L], Samples_per_point = cnd$Samples_per_point[1L],
        SVM_nu = cnd$SVM_nu[1L], SVM_gamma = cnd$SVM_gamma[1L], Is_baseline = cnd$Is_baseline[1L], Repetition = rep, Homology_dimension = dim,
        Success = isTRUE(bn$success) && is.finite(norm), Bottleneck_distance = bn$distance, Occurrence_diameter = or$point_cloud_diameter,
        Normalized_bottleneck_distance = norm, Occurrence_maximum_persistence = if (isTRUE(or$success)) max_finite_persistence(or$diagram, dim) else NA_real_,
        Method_maximum_persistence = if (!is.null(mr) && isTRUE(mr$success)) max_finite_persistence(mr$diagram, dim) else NA_real_,
        Error_message = bn$error_message, stringsAsFactors = FALSE)
    }
  }
}

topology_replicates <- do.call(rbind, topology_rows); rownames(topology_replicates) <- NULL
write_csv_safely(topology_replicates, topology_replicate_file)

keys <- unique(topology_replicates[, c("Condition_id", "Shape_code", "Shape", "Method", "Variation_family", "Bandwidth_multiplier", "Quantile_level",
                                        "Samples_per_point", "SVM_nu", "SVM_gamma", "Is_baseline", "Homology_dimension"), drop = FALSE])
summary_rows <- vector("list", nrow(keys))
for (g in seq_len(nrow(keys))) {
  key <- keys[g, , drop = FALSE]
  x <- topology_replicates[topology_replicates$Condition_id == key$Condition_id[1L] & topology_replicates$Homology_dimension == key$Homology_dimension[1L], , drop = FALSE]
  y <- x[x$Success & is.finite(x$Normalized_bottleneck_distance), , drop = FALSE]
  mb <- safe_mean(y$Bottleneck_distance); sb <- safe_sd(y$Bottleneck_distance); mn <- safe_mean(y$Normalized_bottleneck_distance); sn <- safe_sd(y$Normalized_bottleneck_distance)
  mp <- safe_mean(y$Method_maximum_persistence); sp <- safe_sd(y$Method_maximum_persistence)
  summary_rows[[g]] <- cbind(key, data.frame(Repetitions_requested = number_of_topology_repetitions, Repetitions_successful = nrow(y),
    Mean_bottleneck_distance = mb, SD_bottleneck_distance = sb, Mean_bottleneck_plus_minus_SD = format_mean_sd(mb, sb),
    Mean_normalized_bottleneck = mn, SD_normalized_bottleneck = sn, Mean_normalized_plus_minus_SD = format_mean_sd(mn, sn),
    Mean_maximum_persistence = mp, SD_maximum_persistence = sp, Mean_persistence_plus_minus_SD = format_mean_sd(mp, sp), stringsAsFactors = FALSE))
}
topology_summary <- do.call(rbind, summary_rows); rownames(topology_summary) <- NULL
write_csv_safely(topology_summary, topology_summary_file)
topology_series <- expand_sensitivity_series(topology_summary)
write_csv_safely(topology_series, topology_series_file)


# ============================================================
# Shared condition-level matched filled-ellipsoid references
# ============================================================
make_positive_definite <- function(m, epsilon = 1e-8) {
  m <- as.matrix(m); m <- (m + t(m)) / 2
  eig <- eigen(m, symmetric = TRUE); vals <- pmax(eig$values, epsilon)
  eig$vectors %*% diag(vals, nrow = length(vals)) %*% t(eig$vectors)
}

generate_condition_matched_ellipsoid <- function(target_points, number_of_points, seed) {
  target_points <- set_axis_names(target_points); number_of_points <- as.integer(number_of_points)
  if (number_of_points < 4L) stop("number_of_points must be >= 4 in 3D.")
  d <- ncol(target_points); target_centroid <- colMeans(target_points); target_covariance <- make_positive_definite(stats::cov(target_points))
  set.seed(as.integer(seed))
  directions <- matrix(stats::rnorm(number_of_points * d), nrow = number_of_points, ncol = d)
  norms <- sqrt(rowSums(directions^2))
  while (any(norms == 0)) {
    bad <- which(norms == 0); directions[bad, ] <- matrix(stats::rnorm(length(bad) * d), nrow = length(bad), ncol = d); norms <- sqrt(rowSums(directions^2))
  }
  directions <- directions / norms; radii <- stats::runif(number_of_points)^(1 / d); unit_ball <- directions * radii
  unit_ball <- sweep(unit_ball, 2, colMeans(unit_ball), FUN = "-")
  whitened <- unit_ball %*% solve(chol(make_positive_definite(stats::cov(unit_ball))))
  points <- whitened %*% chol(target_covariance); points <- sweep(points, 2, target_centroid, FUN = "+"); points <- set_axis_names(points)
  list(points = points, target_centroid = target_centroid, target_covariance = target_covariance,
       centroid_error = max(abs(colMeans(points) - target_centroid)), covariance_error = max(abs(stats::cov(points) - target_covariance)))
}

# Occurrence + every estimator condition. Script-08 thresholds are reused for
# occurrence and baseline estimator conditions; only new estimator conditions
# generate new ellipsoid PH calculations.
manifest_rows <- list(); mi <- 0L
for (shape in shape_order) {
  mi <- mi + 1L
  manifest_rows[[mi]] <- data.frame(Matched_condition_id = paste0("Occurrence__", shape), Source_type = "Occurrence", Condition_id = NA_character_,
    Shape_code = shape, Shape = unname(shape_labels[[shape]]), Method = "Occurrence", Variation_family = "Occurrence", Bandwidth_multiplier = NA_real_,
    Quantile_level = NA_real_, Samples_per_point = NA_integer_, SVM_nu = NA_real_, SVM_gamma = NA_real_, Is_baseline = NA,
    Reuse_Script08_threshold = TRUE, stringsAsFactors = FALSE)
}
for (r in seq_len(nrow(sensitivity_design))) {
  cnd <- sensitivity_design[r, , drop = FALSE]; mi <- mi + 1L
  manifest_rows[[mi]] <- data.frame(Matched_condition_id = paste0("Estimator__", cnd$Condition_id[1L]), Source_type = "Estimator",
    Condition_id = cnd$Condition_id[1L], Shape_code = cnd$Shape_code[1L], Shape = cnd$Shape[1L], Method = cnd$Method[1L],
    Variation_family = cnd$Variation_family[1L], Bandwidth_multiplier = cnd$Bandwidth_multiplier[1L], Quantile_level = cnd$Quantile_level[1L],
    Samples_per_point = cnd$Samples_per_point[1L], SVM_nu = cnd$SVM_nu[1L], SVM_gamma = cnd$SVM_gamma[1L], Is_baseline = cnd$Is_baseline[1L],
    Reuse_Script08_threshold = isTRUE(cnd$Is_baseline[1L]), stringsAsFactors = FALSE)
}
matched_reference_manifest <- do.call(rbind, manifest_rows); rownames(matched_reference_manifest) <- NULL
matched_reference_manifest$Condition_number <- seq_len(nrow(matched_reference_manifest))
matched_reference_manifest$Null_replicates_requested <- number_of_matched_reference_replicates
matched_reference_manifest$Null_point_count <- ph_sample_size
matched_reference_manifest$Matching_basis <- "Full occurrence/hypervolume stochastic cloud centroid and covariance"
write_csv_safely(matched_reference_manifest, matched_reference_manifest_file)

get_full_matched_condition_points <- function(mr) {
  if (mr$Source_type[1L] == "Occurrence") return(get_occurrence_points(mr$Shape_code[1L]))
  set_axis_names(get_condition_hv(mr$Condition_id[1L])@RandomPoints)
}

lookup_script08_threshold <- function(shape, source, dim) {
  x <- baseline_null_thresholds[baseline_null_thresholds$Shape_code == shape & baseline_null_thresholds$Sample_size == sensitivity_sample_size &
                                  baseline_null_thresholds$Source == source & baseline_null_thresholds$Homology_dimension == dim, , drop = FALSE]
  if (nrow(x) != 1L) stop("Expected one Script 08 threshold for ", shape, " / ", source, " H", dim)
  x
}

matched_reference_hash <- hash_r_object(list(parent_hash = topology_analysis_hash,
  manifest = matched_reference_manifest[, setdiff(names(matched_reference_manifest), "Condition_number"), drop = FALSE],
  null_replicates = number_of_matched_reference_replicates, null_points = ph_sample_size, seed_base = matched_reference_seed_base,
  ph_threshold = ph_threshold, ph_prime_field = ph_prime_field, ph_standardize = ph_standardize, ph_timeout_seconds = ph_timeout_seconds,
  script08_md5 = safe_md5(topology_results_file)))

if (resume_matched_reference && file.exists(matched_reference_checkpoint_file)) {
  cp <- readRDS(matched_reference_checkpoint_file)
  if (!identical(cp$matched_reference_hash, matched_reference_hash)) stop("Incompatible matched-reference checkpoint.")
  matched_reference_results <- cp$results
} else matched_reference_results <- list()

save_matched_reference_checkpoint <- function() saveRDS(list(matched_reference_hash = matched_reference_hash, results = matched_reference_results), matched_reference_checkpoint_file, version = 3)
matched_null_key <- function(id, rep) paste(id, paste0("null", sprintf("%02d", rep)), sep = "__")

for (cn in seq_len(nrow(matched_reference_manifest))) {
  mr <- matched_reference_manifest[cn, , drop = FALSE]
  if (isTRUE(mr$Reuse_Script08_threshold[1L])) next
  if (mr$Source_type[1L] == "Estimator") {
    rr <- model_registry[model_registry$Condition_id == mr$Condition_id[1L], , drop = FALSE]
    if (nrow(rr) != 1L || !isTRUE(rr$Success[1L])) next
  }
  full_points <- get_full_matched_condition_points(mr); id <- mr$Matched_condition_id[1L]
  for (null_rep in seq_len(number_of_matched_reference_replicates)) {
    key <- matched_null_key(id, null_rep); existing <- matched_reference_results[[key]]
    if (!is.null(existing) && isTRUE(existing$success)) next
    if (!is.null(existing) && !retry_failed_matched_reference) next
    seed <- matched_reference_seed_base + cn * 1000L + null_rep
    message("Matched ellipsoid PH ", cn, "/", nrow(matched_reference_manifest), " null ", null_rep, "/", number_of_matched_reference_replicates, ": ", id)
    result <- tryCatch({
      generated <- generate_condition_matched_ellipsoid(full_points, ph_sample_size, seed); ph <- calculate_persistence_with_timeout(generated$points)
      c(list(key = key, matched_condition_id = id, condition_number = cn, null_repetition = null_rep, seed = seed,
             source_type = mr$Source_type[1L], condition_id = mr$Condition_id[1L], shape_code = mr$Shape_code[1L], shape = mr$Shape[1L], method = mr$Method[1L],
             target_full_point_count = nrow(full_points), null_point_count = ph_sample_size, centroid_error = generated$centroid_error,
             covariance_error = generated$covariance_error), ph)
    }, error = function(e) list(key = key, matched_condition_id = id, condition_number = cn, null_repetition = null_rep, seed = seed,
      source_type = mr$Source_type[1L], condition_id = mr$Condition_id[1L], shape_code = mr$Shape_code[1L], shape = mr$Shape[1L], method = mr$Method[1L],
      target_full_point_count = nrow(full_points), null_point_count = ph_sample_size, centroid_error = NA_real_, covariance_error = NA_real_,
      success = FALSE, diagram = empty_diagram(), runtime_seconds = NA_real_, failure_type = "null-generation failure", error_message = conditionMessage(e)))
    matched_reference_results[[key]] <- result; save_matched_reference_checkpoint()
  }
}

# New-condition null replicate table.
null_rows <- list(); ni <- 0L
for (cn in seq_len(nrow(matched_reference_manifest))) {
  mr <- matched_reference_manifest[cn, , drop = FALSE]
  if (isTRUE(mr$Reuse_Script08_threshold[1L])) next
  for (null_rep in seq_len(number_of_matched_reference_replicates)) {
    res <- matched_reference_results[[matched_null_key(mr$Matched_condition_id[1L], null_rep)]]
    if (is.null(res)) next
    for (dim in 0:maximum_homology_dimension) {
      ni <- ni + 1L
      null_rows[[ni]] <- data.frame(Matched_condition_id = mr$Matched_condition_id[1L], Source_type = mr$Source_type[1L], Condition_id = mr$Condition_id[1L],
        Shape_code = mr$Shape_code[1L], Shape = mr$Shape[1L], Method = mr$Method[1L], Homology_dimension = dim, Null_repetition = null_rep,
        Null_seed = res$seed, Success = res$success, Maximum_persistence = if (isTRUE(res$success)) max_finite_persistence(res$diagram, dim) else NA_real_,
        Runtime_seconds = res$runtime_seconds, Failure_type = res$failure_type, Error_message = res$error_message,
        Centroid_error = res$centroid_error, Covariance_error = res$covariance_error, stringsAsFactors = FALSE)
    }
  }
}
matched_reference_replicates <- if (length(null_rows) > 0L) do.call(rbind, null_rows) else data.frame(
  Matched_condition_id = character(), Source_type = character(), Condition_id = character(), Shape_code = character(), Shape = character(), Method = character(),
  Homology_dimension = integer(), Null_repetition = integer(), Null_seed = integer(), Success = logical(), Maximum_persistence = numeric(), Runtime_seconds = numeric(),
  Failure_type = character(), Error_message = character(), Centroid_error = numeric(), Covariance_error = numeric(), stringsAsFactors = FALSE)
write_csv_safely(matched_reference_replicates, matched_reference_replicate_file)

# Combined thresholds: exact Script-08 reuse for occurrence/baseline; new for all other conditions.
threshold_rows <- list(); thi <- 0L
for (cn in seq_len(nrow(matched_reference_manifest))) {
  mr <- matched_reference_manifest[cn, , drop = FALSE]
  for (dim in 0:maximum_homology_dimension) {
    thi <- thi + 1L
    if (isTRUE(mr$Reuse_Script08_threshold[1L])) {
      source <- if (mr$Source_type[1L] == "Occurrence") "Occurrence" else mr$Method[1L]
      b <- lookup_script08_threshold(mr$Shape_code[1L], source, dim)
      threshold_rows[[thi]] <- data.frame(Matched_condition_id = mr$Matched_condition_id[1L], Source_type = mr$Source_type[1L], Condition_id = mr$Condition_id[1L],
        Shape_code = mr$Shape_code[1L], Shape = mr$Shape[1L], Method = mr$Method[1L], Homology_dimension = dim,
        Threshold_source = "Reused revised Script 08 shared threshold", Null_replicates_requested = b$Null_replicates_requested[1L],
        Null_replicates_successful = b$Null_replicates_successful[1L], Null_set_complete = b$Null_set_complete[1L],
        Matched_reference_threshold = b$Maximum_null_persistence[1L], stringsAsFactors = FALSE)
    } else {
      good <- matched_reference_replicates[matched_reference_replicates$Matched_condition_id == mr$Matched_condition_id[1L] &
                                             matched_reference_replicates$Homology_dimension == dim & matched_reference_replicates$Success &
                                             is.finite(matched_reference_replicates$Maximum_persistence), , drop = FALSE]
      n_success <- length(unique(good$Null_repetition)); complete <- as.integer(n_success) == number_of_matched_reference_replicates
      threshold_rows[[thi]] <- data.frame(Matched_condition_id = mr$Matched_condition_id[1L], Source_type = mr$Source_type[1L], Condition_id = mr$Condition_id[1L],
        Shape_code = mr$Shape_code[1L], Shape = mr$Shape[1L], Method = mr$Method[1L], Homology_dimension = dim,
        Threshold_source = "New Script 09 shared threshold", Null_replicates_requested = number_of_matched_reference_replicates,
        Null_replicates_successful = n_success, Null_set_complete = complete,
        Matched_reference_threshold = if (complete) max(good$Maximum_persistence) else NA_real_, stringsAsFactors = FALSE)
    }
  }
}
matched_reference_thresholds <- do.call(rbind, threshold_rows); rownames(matched_reference_thresholds) <- NULL
write_csv_safely(matched_reference_thresholds, matched_reference_threshold_file)

# Ten observed PH repetitions compared with the same condition-level threshold.
observed_rows <- list(); oi <- 0L
for (cn in seq_len(nrow(matched_reference_manifest))) {
  mr <- matched_reference_manifest[cn, , drop = FALSE]; shape <- mr$Shape_code[1L]
  for (rep in seq_len(number_of_topology_repetitions)) {
    observed <- if (mr$Source_type[1L] == "Occurrence") get_baseline_ph(shape, rep, "Occurrence") else sensitivity_topology_results[[topology_result_key(mr$Condition_id[1L], rep)]]
    observed_ok <- !is.null(observed) && isTRUE(observed$success)
    for (dim in 0:maximum_homology_dimension) {
      tr <- matched_reference_thresholds[matched_reference_thresholds$Matched_condition_id == mr$Matched_condition_id[1L] & matched_reference_thresholds$Homology_dimension == dim, , drop = FALSE]
      if (nrow(tr) != 1L) stop("Expected one threshold row.")
      obs_max <- if (observed_ok) max_finite_persistence(observed$diagram, dim) else NA_real_; threshold <- tr$Matched_reference_threshold[1L]
      exceeds <- if (observed_ok && isTRUE(tr$Null_set_complete[1L]) && is.finite(obs_max) && is.finite(threshold)) obs_max > threshold else NA
      oi <- oi + 1L
      observed_rows[[oi]] <- data.frame(Matched_condition_id = mr$Matched_condition_id[1L], Source_type = mr$Source_type[1L], Condition_id = mr$Condition_id[1L],
        Shape_code = shape, Shape = mr$Shape[1L], Method = mr$Method[1L], Variation_family = mr$Variation_family[1L],
        Bandwidth_multiplier = mr$Bandwidth_multiplier[1L], Quantile_level = mr$Quantile_level[1L], Samples_per_point = mr$Samples_per_point[1L],
        SVM_nu = mr$SVM_nu[1L], SVM_gamma = mr$SVM_gamma[1L], Is_baseline = mr$Is_baseline[1L], Repetition = rep, Homology_dimension = dim,
        Observed_success = observed_ok, Observed_maximum_persistence = obs_max, Threshold_source = tr$Threshold_source[1L],
        Null_replicates_requested = tr$Null_replicates_requested[1L], Null_replicates_successful = tr$Null_replicates_successful[1L],
        Null_set_complete = tr$Null_set_complete[1L], Matched_reference_threshold = threshold, Exceeds_matched_reference = exceeds,
        Error_message = if (is.null(observed)) "Observed PH unavailable" else observed$error_message, stringsAsFactors = FALSE)
    }
  }
}
observed_vs_matched_reference <- do.call(rbind, observed_rows); rownames(observed_vs_matched_reference) <- NULL
write_csv_safely(observed_vs_matched_reference, matched_reference_observed_file)

# Exceedance proportion by condition and homology dimension.
keys <- unique(observed_vs_matched_reference[, c("Matched_condition_id", "Source_type", "Condition_id", "Shape_code", "Shape", "Method", "Variation_family",
  "Bandwidth_multiplier", "Quantile_level", "Samples_per_point", "SVM_nu", "SVM_gamma", "Is_baseline", "Homology_dimension", "Threshold_source",
  "Null_replicates_requested", "Null_replicates_successful", "Null_set_complete", "Matched_reference_threshold"), drop = FALSE])
exceedance_rows <- vector("list", nrow(keys))
for (g in seq_len(nrow(keys))) {
  key <- keys[g, , drop = FALSE]
  x <- observed_vs_matched_reference[observed_vs_matched_reference$Matched_condition_id == key$Matched_condition_id[1L] &
                                      observed_vs_matched_reference$Homology_dimension == key$Homology_dimension[1L], , drop = FALSE]
  y <- x[x$Observed_success & x$Null_set_complete & is.finite(x$Observed_maximum_persistence) & !is.na(x$Exceeds_matched_reference), , drop = FALSE]
  n_exceed <- if (nrow(y) > 0L) sum(y$Exceeds_matched_reference) else 0L; prop <- if (nrow(y) > 0L) n_exceed / nrow(y) else NA_real_
  exceedance_rows[[g]] <- cbind(key, data.frame(Observed_repetitions_requested = number_of_topology_repetitions, Observed_repetitions_successful = nrow(y),
    Number_exceeding_matched_reference = n_exceed, Exceedance_proportion = prop,
    Mean_observed_maximum_persistence = safe_mean(y$Observed_maximum_persistence), SD_observed_maximum_persistence = safe_sd(y$Observed_maximum_persistence),
    stringsAsFactors = FALSE))
}
matched_reference_exceedance_summary <- do.call(rbind, exceedance_rows); rownames(matched_reference_exceedance_summary) <- NULL
write_csv_safely(matched_reference_exceedance_summary, matched_reference_exceedance_file)
matched_reference_estimator_summary <- matched_reference_exceedance_summary[matched_reference_exceedance_summary$Source_type == "Estimator", , drop = FALSE]
matched_reference_series <- expand_sensitivity_series(matched_reference_estimator_summary)
write_csv_safely(matched_reference_series, matched_reference_series_file)

# ============================================================
# Failure audit
# ============================================================
failure_rows <- list(); fi <- 0L
failed <- model_registry[!model_registry$Success, , drop = FALSE]
if (nrow(failed) > 0L) for (r in seq_len(nrow(failed))) { fi <- fi + 1L; failure_rows[[fi]] <- data.frame(Stage = "Sensitivity model fit", Condition_id = failed$Condition_id[r], Shape_code = failed$Shape_code[r], Method = failed$Method[r], Repetition = NA_integer_, Homology_dimension = NA_integer_, Error_message = failed$Error_message[r], stringsAsFactors = FALSE) }
failed <- geometry_summary[!geometry_summary$Success, , drop = FALSE]
if (nrow(failed) > 0L) for (r in seq_len(nrow(failed))) { fi <- fi + 1L; failure_rows[[fi]] <- data.frame(Stage = "Sensitivity geometry", Condition_id = failed$Condition_id[r], Shape_code = failed$Shape_code[r], Method = failed$Method[r], Repetition = NA_integer_, Homology_dimension = NA_integer_, Error_message = failed$Error_message[r], stringsAsFactors = FALSE) }
failed <- topology_replicates[!topology_replicates$Success, , drop = FALSE]
if (nrow(failed) > 0L) for (r in seq_len(nrow(failed))) { fi <- fi + 1L; failure_rows[[fi]] <- data.frame(Stage = "Sensitivity bottleneck/PH", Condition_id = failed$Condition_id[r], Shape_code = failed$Shape_code[r], Method = failed$Method[r], Repetition = failed$Repetition[r], Homology_dimension = failed$Homology_dimension[r], Error_message = failed$Error_message[r], stringsAsFactors = FALSE) }
failed <- matched_reference_replicates[!matched_reference_replicates$Success, , drop = FALSE]
if (nrow(failed) > 0L) for (r in seq_len(nrow(failed))) { fi <- fi + 1L; failure_rows[[fi]] <- data.frame(Stage = "Sensitivity matched ellipsoid PH", Condition_id = failed$Condition_id[r], Shape_code = failed$Shape_code[r], Method = failed$Method[r], Repetition = failed$Null_repetition[r], Homology_dimension = failed$Homology_dimension[r], Error_message = failed$Error_message[r], stringsAsFactors = FALSE) }
failure_table <- if (length(failure_rows) > 0L) do.call(rbind, failure_rows) else data.frame(Stage = character(), Condition_id = character(), Shape_code = character(), Method = character(), Repetition = integer(), Homology_dimension = integer(), Error_message = character(), stringsAsFactors = FALSE)
write_csv_safely(failure_table, failure_file)

# ============================================================
# Final object, notes and console audit
# ============================================================
final_results <- list(
  metadata = list(script = "09_3D_Synthetic_Sensitivity.R", analysis_settings_hash = analysis_settings_hash, qph_core_version = QPH_CORE_VERSION,
    baseline_results_md5 = safe_md5(baseline_results_file), geometry_results_md5 = safe_md5(geometry_results_file), topology_results_md5 = safe_md5(topology_results_file),
    sensitivity_sample_size = sensitivity_sample_size, unique_conditions = nrow(sensitivity_design), new_fits_requested = sum(sensitivity_design$Requires_new_fit),
    ph_sample_size = ph_sample_size, topology_repetitions = number_of_topology_repetitions, maximum_homology_dimension = maximum_homology_dimension,
    matched_reference_replicates = number_of_matched_reference_replicates, matched_reference_design = "shared condition-level full source cloud",
    method_colours = method_colours, true_region_colour = true_region_colour, occurrence_colour = occurrence_colour, completed_at = as.character(Sys.time())),
  sensitivity_design = sensitivity_design, model_registry = model_registry, geometry_summary = geometry_summary, geometry_series = geometry_series,
  topology_replicates = topology_replicates, topology_summary = topology_summary, topology_series = topology_series,
  matched_reference_manifest = matched_reference_manifest, matched_reference_thresholds = matched_reference_thresholds,
  matched_reference_observed = observed_vs_matched_reference, matched_reference_exceedance_summary = matched_reference_exceedance_summary,
  matched_reference_series = matched_reference_series, failures = failure_table
)
saveRDS(final_results, final_results_file, version = 3)

number_of_new_matched_conditions <- sum(!matched_reference_manifest$Reuse_Script08_threshold)
writeLines(c(
  "Revised 3D synthetic sensitivity analysis", "=========================================", "",
  "QPH: bandwidth x 0.75/1.00/1.25; q 0.950/0.975/0.990; spp 25/50/100/150.",
  "KDE: Silverman bandwidth x 0.75/1.00/1.25; q 0.925/0.950/0.975; spp 25/50/100/150.",
  "SVM: nu 0.005/0.010/0.015; gamma 0.25/0.50/0.75; spp 25/50/100/150; scale.factor 1.",
  paste0("Unique estimator conditions = ", nrow(sensitivity_design)), paste0("New hypervolume fits = ", sum(sensitivity_design$Requires_new_fit)), "",
  "Geometry reuses fixed Script-07 100,000-point references.",
  "Topology: 10 x 300-point repetitions; H0-H2; paired occurrence bottleneck; six-minute timeout.",
  paste0("Shared matched ellipsoids = ", number_of_matched_reference_replicates, " per condition."),
  "Script-08 occurrence/baseline thresholds are reused exactly.",
  paste0("New sensitivity conditions requiring new null sets = ", number_of_new_matched_conditions),
  paste0("Maximum new matched-reference PH calls = ", number_of_new_matched_conditions * number_of_matched_reference_replicates),
  "Incomplete 20-null sets do not define an exceedance threshold.", "Reported statistic = Exceedance_proportion.", "",
  "Colours: KDE #D7301F; SVM #238B45; QPH #2C7FB8; true region #D9D9D9; occurrences #111111.",
  paste0("Completed: ", Sys.time())), notes_file)

capture.output(sessionInfo(), file = session_information_file)

message("\n============================================================")
message("09_3D_Synthetic_Sensitivity.R complete.")
message("Unique conditions: ", nrow(sensitivity_design), "; new fits: ", sum(sensitivity_design$Requires_new_fit))
message("New matched-reference conditions: ", number_of_new_matched_conditions,
        "; maximum new null PH calls: ", number_of_new_matched_conditions * number_of_matched_reference_replicates)
message("Final object:\n  ", normalizePath(final_results_file, mustWork = FALSE))
message("Geometry series:\n  ", normalizePath(geometry_series_file, mustWork = FALSE))
message("Topology series:\n  ", normalizePath(topology_series_file, mustWork = FALSE))
message("Matched-reference series:\n  ", normalizePath(matched_reference_series_file, mustWork = FALSE))
message("Failures recorded: ", nrow(failure_table))
message("============================================================")
