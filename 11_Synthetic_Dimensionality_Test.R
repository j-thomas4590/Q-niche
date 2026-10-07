# ============================================================
# 11_Synthetic_Dimensionality_Test.R
# ============================================================
# Revised dimensionality benchmark for QPH, Gaussian KDE and one-class SVM.
#
#
# DESIGN
#   d = 2,...,8
#   n = 900 occurrences; 450 per component
#   two separated filled d-balls
#   total analytical truth volume fixed at 8*pi
#   centre offset/radius = 2, so centre distance = 4*r_d,
#     boundary gap = 2*r_d
#
# SAMPLING EFFORT
#   samples.per.point = 100, 200, 300, 400 for ALL estimators
#


rm(list = ls())
gc()

# ------------------------------------------------------------
# Project paths
# ------------------------------------------------------------


# Run from the repository's root folder.
project_directory <- "."
scripts_directory <- file.path(project_directory, "Scripts")
output_directory <- file.path(project_directory, "Results", "11_Dimensionality_Test_sqrtNB_q099")

truth_directory <- file.path(output_directory, "00_Truth")
fit_directory <- file.path(output_directory, "01_Fits")
fit_object_directory <- file.path(fit_directory, "objects")
geometry_directory <- file.path(output_directory, "02_Geometry")
topology_directory <- file.path(output_directory, "03_Topology")
matched_directory <- file.path(output_directory, "04_Matched_Reference")

for (d in c(output_directory, truth_directory, fit_directory, fit_object_directory,
            geometry_directory, topology_directory, matched_directory)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# ------------------------------------------------------------
# Authoritative revised QPH core
# ------------------------------------------------------------
qph_core_file <- file.path(scripts_directory, "00_QPH_Core_Functions.R")
if (!file.exists(qph_core_file)) stop("Missing QPH core: ", qph_core_file)
source(qph_core_file, local = FALSE)
if (!exists("QPH_CORE_VERSION") ||
    !identical(as.character(QPH_CORE_VERSION), "sqrtNB_q099_v1")) {
  stop("Unexpected QPH core version.")
}
qph_core_md5 <- unname(tools::md5sum(qph_core_file))

# ------------------------------------------------------------
# Packages
# ------------------------------------------------------------
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

# ------------------------------------------------------------
# Locked design
# ------------------------------------------------------------
dimensions <- 2:8
occurrence_sample_size <- 900L
samples_per_point_values <- c(100L, 200L, 300L, 400L)
method_order <- c("Gaussian KDE", "SVM", "QPH")

target_total_volume <- 8 * pi
centre_offset_to_radius_ratio <- 2

qph_q <- 0.99
qph_sd_count <- 3L

kde_probability_quantile <- 0.95
kde_sd_count <- 3L

svm_nu <- 0.010
svm_gamma <- 0.50
svm_scale_factor <- 1

shared_chunk_size <- 100L
potential_batch_size <- 500L
show_progress_messages <- FALSE

truth_reference_point_count <- 100000L
jaccard_num_points_max <- 10000L
jaccard_distance_factor <- 1

ph_sample_size <- 300L
number_of_topology_repetitions <- 10L
ph_threshold <- -1
ph_prime_field <- 2L
ph_standardize <- FALSE
ph_timeout_seconds <- 6 * 60

number_of_matched_reference_replicates <- 20L

master_seed <- 128001L
truth_reference_seed_base <- 138001L
fit_seed_base <- 148001L
geometry_seed_base <- 158001L
topology_occurrence_seed_base <- 168001L
topology_estimator_seed_base <- 178001L
matched_reference_seed_base <- 188001L

# ------------------------------------------------------------
# Output files
# ------------------------------------------------------------
truth_checkpoint_file <- file.path(truth_directory, "truth_checkpoint.rds")
truth_manifest_file <- file.path(truth_directory, "truth_manifest.csv")

fit_design_file <- file.path(fit_directory, "fit_design.csv")
fit_checkpoint_file <- file.path(fit_directory, "fit_checkpoint.rds")
fit_registry_file <- file.path(fit_directory, "fit_registry.csv")
qph_audit_file <- file.path(fit_directory, "QPH_audit_summary.csv")
qph_local_s_file <- file.path(fit_directory, "QPH_local_s.csv")

geometry_checkpoint_file <- file.path(geometry_directory, "geometry_checkpoint.rds")
geometry_results_file <- file.path(geometry_directory, "geometry_results.csv")

topology_subsample_file <- file.path(topology_directory, "topology_subsamples.rds")
topology_checkpoint_file <- file.path(topology_directory, "topology_checkpoint.rds")
topology_replicate_file <- file.path(topology_directory, "topology_replicates.csv")
topology_summary_file <- file.path(topology_directory, "topology_summary.csv")

matched_manifest_file <- file.path(matched_directory, "matched_reference_manifest.csv")
matched_checkpoint_file <- file.path(matched_directory, "matched_reference_checkpoint.rds")
matched_null_file <- file.path(matched_directory, "matched_reference_nulls.csv")
matched_threshold_file <- file.path(matched_directory, "matched_reference_thresholds.csv")
matched_observed_file <- file.path(matched_directory, "matched_reference_observed.csv")
matched_exceedance_file <- file.path(matched_directory, "matched_reference_exceedance.csv")

final_table_file <- file.path(output_directory, "dimensionality_combined_results.csv")
final_results_file <- file.path(output_directory, "synthetic_dimensionality_results_sqrtNB_q099.rds")
failure_file <- file.path(output_directory, "failures.csv")
settings_file <- file.path(output_directory, "analysis_settings.rds")
notes_file <- file.path(output_directory, "analysis_notes.txt")
session_file <- file.path(output_directory, "session_information.txt")

# ------------------------------------------------------------
# Generic helpers
# ------------------------------------------------------------
write_csv_safely <- function(x, file) {
  tryCatch(
    utils::write.csv(x, file, row.names = FALSE),
    error = function(e) {
      alt <- sub("\\.csv$", paste0("_new_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"), file)
      warning("Could not overwrite ", basename(file), "; writing ", basename(alt))
      utils::write.csv(x, alt, row.names = FALSE)
    }
  )
}

hash_r_object <- function(object) {
  tf <- tempfile(fileext = ".rds")
  on.exit(unlink(tf), add = TRUE)
  saveRDS(object, tf, version = 3)
  unname(tools::md5sum(tf))
}

name_axes <- function(x) {
  x <- as.matrix(x)
  storage.mode(x) <- "double"
  if (nrow(x) < 1L || ncol(x) < 1L || any(!is.finite(x))) stop("Invalid point matrix.")
  colnames(x) <- paste("Environmental axis", seq_len(ncol(x)))
  x
}

standardise_hv <- function(hv) {
  if (!methods::is(hv, "Hypervolume")) stop("Expected Hypervolume.")
  d <- as.integer(hv@Dimensionality)
  nm <- paste("Environmental axis", seq_len(d))
  if (ncol(hv@Data) == d) colnames(hv@Data) <- nm
  if (ncol(hv@RandomPoints) == d) colnames(hv@RandomPoints) <- nm
  methods::validObject(hv)
  hv
}

safe_mean <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0L) NA_real_ else mean(x)
}
safe_sd <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 2L) NA_real_ else stats::sd(x)
}
relative_error_percent <- function(estimate, truth) {
  if (!is.finite(estimate) || !is.finite(truth) || truth <= 0) return(NA_real_)
  100 * (estimate - truth) / truth
}
condition_id_for <- function(d, method, spp) {
  code <- switch(method, "Gaussian KDE" = "KDE", "SVM" = "SVM", "QPH" = "QPH")
  paste0("d", d, "__", code, "__spp", spp)
}

analysis_settings <- list(
  script = "11_Synthetic_Dimensionality_Test.R",
  qph_core_version = QPH_CORE_VERSION,
  qph_core_md5 = qph_core_md5,
  dimensions = dimensions,
  occurrence_sample_size = occurrence_sample_size,
  samples_per_point_values = samples_per_point_values,
  methods = method_order,
  target_total_volume = target_total_volume,
  centre_offset_to_radius_ratio = centre_offset_to_radius_ratio,
  qph_q = qph_q,
  kde_probability_quantile = kde_probability_quantile,
  svm_nu = svm_nu,
  svm_gamma = svm_gamma,
  ph_sample_size = ph_sample_size,
  topology_repetitions = number_of_topology_repetitions,
  null_replicates = number_of_matched_reference_replicates
)
analysis_settings_hash <- hash_r_object(analysis_settings)
saveRDS(list(hash = analysis_settings_hash, settings = analysis_settings), settings_file, version = 3)

# ------------------------------------------------------------
# Controlled two-ball truth
# ------------------------------------------------------------
d_ball_volume <- function(dimensionality, radius) {
  exp(dimensionality / 2 * log(pi) -
        lgamma(dimensionality / 2 + 1) +
        dimensionality * log(radius))
}

radius_for_constant_total_volume <- function(dimensionality, total_volume) {
  unit_ball_volume <- d_ball_volume(dimensionality, 1)
  (total_volume / (2 * unit_ball_volume))^(1 / dimensionality)
}

sample_uniform_d_ball <- function(n, dimensionality, radius, centre) {
  directions <- matrix(stats::rnorm(n * dimensionality), nrow = n, ncol = dimensionality)
  norms <- sqrt(rowSums(directions^2))
  while (any(norms == 0)) {
    bad <- which(norms == 0)
    directions[bad, ] <- matrix(stats::rnorm(length(bad) * dimensionality),
                                nrow = length(bad), ncol = dimensionality)
    norms[bad] <- sqrt(rowSums(directions[bad, , drop = FALSE]^2))
  }
  directions <- directions / norms
  radii <- radius * stats::runif(n)^(1 / dimensionality)
  sweep(directions * radii, 2, centre, FUN = "+")
}

generate_two_balls <- function(n, dimensionality, seed) {
  if (n %% 2L != 0L) stop("n must be even.")
  radius <- radius_for_constant_total_volume(dimensionality, target_total_volume)
  offset <- centre_offset_to_radius_ratio * radius
  centre_1 <- centre_2 <- rep(0, dimensionality)
  centre_1[[1L]] <- -offset
  centre_2[[1L]] <- offset
  centre_distance <- sqrt(sum((centre_1 - centre_2)^2))
  if (centre_distance <= 2 * radius) stop("Truth balls overlap.")
  set.seed(seed)
  m <- n / 2L
  b1 <- sample_uniform_d_ball(m, dimensionality, radius, centre_1)
  b2 <- sample_uniform_d_ball(m, dimensionality, radius, centre_2)
  points <- matrix(NA_real_, nrow = n, ncol = dimensionality)
  points[seq.int(1L, n, by = 2L), ] <- b1
  points[seq.int(2L, n, by = 2L), ] <- b2
  points <- name_axes(points)
  list(
    points = points,
    true_volume = 2 * d_ball_volume(dimensionality, radius),
    radius = radius,
    centre_1 = centre_1,
    centre_2 = centre_2,
    centre_offset = offset,
    centre_distance = centre_distance,
    boundary_gap = centre_distance - 2 * radius
  )
}

make_truth_reference <- function(dimensionality, truth, seed) {
  set.seed(seed)
  n1 <- floor(truth_reference_point_count / 2)
  n2 <- truth_reference_point_count - n1
  pts <- rbind(
    sample_uniform_d_ball(n1, dimensionality, truth$radius, truth$centre_1),
    sample_uniform_d_ball(n2, dimensionality, truth$radius, truth$centre_2)
  )
  pts <- name_axes(pts)
  hv <- methods::new(
    "Hypervolume",
    Name = paste0("Truth reference d=", dimensionality),
    Method = "Analytical truth reference",
    Data = truth$points,
    Dimensionality = as.numeric(dimensionality),
    Volume = as.numeric(truth$true_volume),
    PointDensity = nrow(pts) / truth$true_volume,
    Parameters = list(analytical.truth = TRUE, reference.points = truth_reference_point_count, seed = seed),
    RandomPoints = pts,
    ValueAtRandomPoints = rep(1 / truth$true_volume, nrow(pts))
  )
  methods::validObject(hv)
  list(hypervolume = hv, points = pts, exact_true_volume = truth$true_volume)
}

truth_hash <- hash_r_object(list(
  analysis_settings_hash, dimensions, occurrence_sample_size,
  target_total_volume, centre_offset_to_radius_ratio,
  truth_reference_point_count, master_seed, truth_reference_seed_base
))

if (file.exists(truth_checkpoint_file)) {
  cp <- readRDS(truth_checkpoint_file)
  if (!identical(cp$truth_hash, truth_hash)) stop("Incompatible truth checkpoint.")
  truth_archive <- cp$truth_archive
} else {
  truth_archive <- list()
}

truth_manifest_rows <- list()
for (d in dimensions) {
  key <- paste0("d", d)
  if (is.null(truth_archive[[key]])) {
    message("Generating truth d=", d)
    truth <- generate_two_balls(occurrence_sample_size, d, master_seed + d)
    reference <- make_truth_reference(d, truth, truth_reference_seed_base + d)
    truth_archive[[key]] <- list(truth = truth, reference = reference)
    saveRDS(list(truth_hash = truth_hash, truth_archive = truth_archive),
            truth_checkpoint_file, version = 3)
  }
  tr <- truth_archive[[key]]$truth
  truth_manifest_rows[[key]] <- data.frame(
    Dimension = d,
    Sample_size = occurrence_sample_size,
    Points_per_component = occurrence_sample_size / 2L,
    True_volume = tr$true_volume,
    Ball_radius = tr$radius,
    Centre_offset = tr$centre_offset,
    Centre_distance = tr$centre_distance,
    Boundary_gap = tr$boundary_gap,
    Truth_seed = master_seed + d,
    Truth_reference_points = truth_reference_point_count,
    Truth_reference_seed = truth_reference_seed_base + d,
    stringsAsFactors = FALSE
  )
}
truth_manifest <- do.call(rbind, truth_manifest_rows)
rownames(truth_manifest) <- NULL
write_csv_safely(truth_manifest, truth_manifest_file)


# ============================================================
# FIT DESIGN AND FULL-RUNTIME ESTIMATOR CONSTRUCTION
# ============================================================

fit_design_rows <- list()
ii <- 0L
for (d in dimensions) {
  for (method in method_order) {
    for (spp in samples_per_point_values) {
      ii <- ii + 1L
      fit_design_rows[[ii]] <- data.frame(
        Condition_id = condition_id_for(d, method, spp),
        Dimension = d,
        Method = method,
        Samples_per_point = spp,
        Fit_seed = fit_seed_base + d * 10000L +
          match(method, method_order) * 1000L + spp,
        stringsAsFactors = FALSE
      )
    }
  }
}
fit_design <- do.call(rbind, fit_design_rows)
rownames(fit_design) <- NULL
if (nrow(fit_design) != 84L) stop("Expected exactly 84 estimator conditions.")
write_csv_safely(fit_design, fit_design_file)

fit_object_path <- function(id) file.path(fit_object_directory, paste0(id, ".rds"))

fit_qph <- function(points, d, spp, seed) {
  start <- proc.time()[["elapsed"]]
  tryCatch({
    bandwidth_info <- estimate_qph_sqrt_nb_bandwidth(points)
    qph_result <- construct_qph(
      data = points,
      bandwidth = bandwidth_info$bandwidth,
      bandwidth_info = bandwidth_info,
      name = paste0("QPH d=", d, " spp=", spp),
      samples_per_point = spp,
      sd_count = qph_sd_count,
      q = qph_q,
      sampling_seed = seed,
      sampling_chunk_size = shared_chunk_size,
      potential_batch_size = potential_batch_size,
      verbose = show_progress_messages
    )
    hv <- standardise_hv(qph_result$hypervolume)
    list(
      success = TRUE,
      hv = hv,
      runtime = proc.time()[["elapsed"]] - start,
      qph_result = qph_result,
      error_message = NA_character_
    )
  }, error = function(e) {
    list(success = FALSE, hv = NULL,
         runtime = proc.time()[["elapsed"]] - start,
         qph_result = NULL, error_message = conditionMessage(e))
  })
}

fit_kde <- function(points, d, spp, seed) {
  start <- proc.time()[["elapsed"]]
  tryCatch({
    bandwidth <- hypervolume::estimate_bandwidth(points, method = "silverman")
    set.seed(seed)
    hv <- hypervolume::hypervolume_gaussian(
      data = points,
      name = paste0("Gaussian KDE d=", d, " spp=", spp),
      kde.bandwidth = bandwidth,
      samples.per.point = spp,
      sd.count = kde_sd_count,
      quantile.requested = kde_probability_quantile,
      quantile.requested.type = "probability",
      chunk.size = shared_chunk_size,
      verbose = show_progress_messages
    )
    hv <- standardise_hv(hv)
    list(success = TRUE, hv = hv,
         runtime = proc.time()[["elapsed"]] - start,
         bandwidth = bandwidth, error_message = NA_character_)
  }, error = function(e) {
    list(success = FALSE, hv = NULL,
         runtime = proc.time()[["elapsed"]] - start,
         bandwidth = NULL, error_message = conditionMessage(e))
  })
}

fit_svm <- function(points, d, spp, seed) {
  start <- proc.time()[["elapsed"]]
  tryCatch({
    set.seed(seed)
    hv <- hypervolume::hypervolume_svm(
      data = points,
      name = paste0("SVM d=", d, " spp=", spp),
      samples.per.point = spp,
      svm.nu = svm_nu,
      svm.gamma = svm_gamma,
      scale.factor = svm_scale_factor,
      chunk.size = shared_chunk_size,
      verbose = show_progress_messages
    )
    hv <- standardise_hv(hv)
    list(success = TRUE, hv = hv,
         runtime = proc.time()[["elapsed"]] - start,
         error_message = NA_character_)
  }, error = function(e) {
    list(success = FALSE, hv = NULL,
         runtime = proc.time()[["elapsed"]] - start,
         error_message = conditionMessage(e))
  })
}

empty_fit_registry <- function() {
  data.frame(
    Condition_id = character(),
    Dimension = integer(),
    Method = character(),
    Samples_per_point = integer(),
    Fit_seed = integer(),
    Success = logical(),
    Full_runtime_seconds = numeric(),
    Estimated_volume = numeric(),
    Hypervolume_random_points = integer(),
    Point_density = numeric(),
    QPH_K = integer(),
    QPH_mean_s = numeric(),
    QPH_scalar_h = numeric(),
    QPH_retained_fraction = numeric(),
    Object_file = character(),
    Error_message = character(),
    stringsAsFactors = FALSE
  )
}

fit_hash <- hash_r_object(list(analysis_settings_hash, fit_design))
if (file.exists(fit_checkpoint_file)) {
  cp <- readRDS(fit_checkpoint_file)
  if (!identical(cp$fit_hash, fit_hash)) stop("Incompatible fit checkpoint.")
  fit_registry <- cp$fit_registry
} else {
  fit_registry <- empty_fit_registry()
}

save_fit_checkpoint <- function() {
  saveRDS(list(fit_hash = fit_hash, fit_registry = fit_registry),
          fit_checkpoint_file, version = 3)
  write_csv_safely(fit_registry, fit_registry_file)
}
replace_fit_row <- function(row) {
  fit_registry <<- rbind(
    fit_registry[fit_registry$Condition_id != row$Condition_id[[1L]], , drop = FALSE],
    row
  )
  rownames(fit_registry) <<- NULL
}

for (i in seq_len(nrow(fit_design))) {
  dr <- fit_design[i, , drop = FALSE]
  id <- dr$Condition_id[[1L]]
  old <- fit_registry[fit_registry$Condition_id == id, , drop = FALSE]
  if (nrow(old) == 1L && isTRUE(old$Success[[1L]]) &&
      !is.na(old$Object_file[[1L]]) && file.exists(old$Object_file[[1L]])) next

  d <- dr$Dimension[[1L]]
  method <- dr$Method[[1L]]
  spp <- dr$Samples_per_point[[1L]]
  seed <- dr$Fit_seed[[1L]]
  points <- truth_archive[[paste0("d", d)]]$truth$points

  message("Fit ", i, "/84: d=", d, ", ", method, ", spp=", spp)

  result <- switch(
    method,
    "QPH" = fit_qph(points, d, spp, seed),
    "Gaussian KDE" = fit_kde(points, d, spp, seed),
    "SVM" = fit_svm(points, d, spp, seed)
  )

  object_file <- fit_object_path(id)
  if (isTRUE(result$success)) {
    qk <- qm <- qh <- qr <- NA_real_
    if (method == "QPH") {
      qk <- as.integer(result$qph_result$audit$K)
      qm <- as.numeric(result$qph_result$audit$mean_s)
      qh <- as.numeric(result$qph_result$audit$baseline_scalar_h)
      qr <- as.numeric(result$qph_result$retained_fraction)
    }
    saveRDS(list(
      condition = dr,
      hypervolume = result$hv,
      full_runtime_seconds = result$runtime,
      qph_result = if (method == "QPH") result$qph_result else NULL
    ), object_file, version = 3)

    row <- data.frame(
      Condition_id = id, Dimension = d, Method = method,
      Samples_per_point = spp, Fit_seed = seed, Success = TRUE,
      Full_runtime_seconds = result$runtime,
      Estimated_volume = as.numeric(result$hv@Volume),
      Hypervolume_random_points = nrow(result$hv@RandomPoints),
      Point_density = as.numeric(result$hv@PointDensity),
      QPH_K = qk, QPH_mean_s = qm, QPH_scalar_h = qh,
      QPH_retained_fraction = qr,
      Object_file = object_file, Error_message = NA_character_,
      stringsAsFactors = FALSE
    )
  } else {
    row <- data.frame(
      Condition_id = id, Dimension = d, Method = method,
      Samples_per_point = spp, Fit_seed = seed, Success = FALSE,
      Full_runtime_seconds = result$runtime,
      Estimated_volume = NA_real_, Hypervolume_random_points = NA_integer_,
      Point_density = NA_real_, QPH_K = NA_integer_, QPH_mean_s = NA_real_,
      QPH_scalar_h = NA_real_, QPH_retained_fraction = NA_real_,
      Object_file = NA_character_, Error_message = result$error_message,
      stringsAsFactors = FALSE
    )
  }
  replace_fit_row(row)
  save_fit_checkpoint()
}

fit_registry <- fit_registry[
  match(fit_design$Condition_id, fit_registry$Condition_id),
  , drop = FALSE
]
rownames(fit_registry) <- NULL
write_csv_safely(fit_registry, fit_registry_file)

get_hv <- function(id) {
  rr <- fit_registry[fit_registry$Condition_id == id, , drop = FALSE]
  if (nrow(rr) != 1L || !isTRUE(rr$Success[[1L]])) stop("Unavailable fit: ", id)
  standardise_hv(readRDS(rr$Object_file[[1L]])$hypervolume)
}

# ------------------------------------------------------------
# QPH audit exports
# ------------------------------------------------------------
qa <- list()
ql <- list()
qai <- 0L
qli <- 0L
for (i in which(fit_design$Method == "QPH")) {
  dr <- fit_design[i, , drop = FALSE]
  rr <- fit_registry[fit_registry$Condition_id == dr$Condition_id[[1L]], , drop = FALSE]
  if (nrow(rr) != 1L || !isTRUE(rr$Success[[1L]])) next
  obj <- readRDS(rr$Object_file[[1L]])
  a <- obj$qph_result$audit
  qai <- qai + 1L
  qa[[qai]] <- data.frame(
    Condition_id = dr$Condition_id[[1L]],
    Dimension = dr$Dimension[[1L]],
    Samples_per_point = dr$Samples_per_point[[1L]],
    n = a$n, d = a$d, K = a$K, Mean_s = a$mean_s,
    Baseline_scalar_h = a$baseline_scalar_h,
    q = a$q, SD_count = a$sd_count, Sampling_seed = a$sampling_seed,
    Retained_fraction = obj$qph_result$retained_fraction,
    Full_runtime_seconds = rr$Full_runtime_seconds[[1L]],
    stringsAsFactors = FALSE
  )
  qli <- qli + 1L
  ql[[qli]] <- data.frame(
    Condition_id = dr$Condition_id[[1L]],
    Dimension = dr$Dimension[[1L]],
    Samples_per_point = dr$Samples_per_point[[1L]],
    Occurrence_index = seq_along(a$local_s),
    K = a$K, s_i = as.numeric(a$local_s),
    Mean_s = a$mean_s, Baseline_scalar_h = a$baseline_scalar_h,
    stringsAsFactors = FALSE
  )
}
if (length(qa) > 0L) write_csv_safely(do.call(rbind, qa), qph_audit_file)
if (length(ql) > 0L) write_csv_safely(do.call(rbind, ql), qph_local_s_file)

# ============================================================
# GEOMETRY
# ============================================================

component_volume <- function(hv_set, candidates, required = FALSE) {
  available <- names(hv_set@HVList)
  idx <- match(tolower(candidates), tolower(available), nomatch = 0L)
  idx <- idx[idx > 0L]
  if (length(idx) == 0L) {
    if (required) stop("Missing HypervolumeSet component: ", paste(candidates, collapse = ", "))
    return(NA_real_)
  }
  obj <- hv_set@HVList[[idx[[1L]]]]
  if (!methods::is(obj, "Hypervolume")) {
    if (required) stop("Set component is not a Hypervolume.")
    return(NA_real_)
  }
  as.numeric(obj@Volume)
}

geometry_hash <- hash_r_object(list(
  fit_hash, truth_hash, truth_reference_point_count,
  jaccard_num_points_max, jaccard_distance_factor, geometry_seed_base
))
if (file.exists(geometry_checkpoint_file)) {
  cp <- readRDS(geometry_checkpoint_file)
  if (!identical(cp$geometry_hash, geometry_hash)) stop("Incompatible geometry checkpoint.")
  geometry_results <- cp$geometry_results
} else {
  geometry_results <- list()
}
save_geometry_checkpoint <- function() {
  saveRDS(list(geometry_hash = geometry_hash, geometry_results = geometry_results),
          geometry_checkpoint_file, version = 3)
}

for (i in seq_len(nrow(fit_design))) {
  dr <- fit_design[i, , drop = FALSE]
  id <- dr$Condition_id[[1L]]
  if (!is.null(geometry_results[[id]]) && isTRUE(geometry_results[[id]]$success)) next

  rr <- fit_registry[fit_registry$Condition_id == id, , drop = FALSE]
  d <- dr$Dimension[[1L]]
  if (nrow(rr) != 1L || !isTRUE(rr$Success[[1L]])) {
    geometry_results[[id]] <- list(success = FALSE, row = NULL,
                                   error_message = if (nrow(rr) == 1L) rr$Error_message[[1L]] else "Missing fit")
    save_geometry_checkpoint()
    next
  }

  message("Geometry ", i, "/84: ", id)
  result <- tryCatch({
    hv <- get_hv(id)
    true_hv <- truth_archive[[paste0("d", d)]]$reference$hypervolume
    true_volume <- truth_archive[[paste0("d", d)]]$truth$true_volume
    est_volume <- as.numeric(hv@Volume)
    signed_error <- relative_error_percent(est_volume, true_volume)

    set.seed(geometry_seed_base + i)
    timing <- system.time({
      hs <- hypervolume::hypervolume_set(
        hv1 = hv, hv2 = true_hv,
        num.points.max = jaccard_num_points_max,
        verbose = FALSE, check.memory = FALSE,
        distance.factor = jaccard_distance_factor
      )
    })
    overlap <- hypervolume::hypervolume_overlap_statistics(hs)
    intersection <- component_volume(hs, "Intersection", TRUE)
    union <- component_volume(hs, "Union", FALSE)
    if (!is.finite(union)) {
      u1 <- component_volume(hs, c("Unique_1", "Unique 1", "Unique1"))
      u2 <- component_volume(hs, c("Unique_2", "Unique 2", "Unique2"))
      if (is.finite(u1) && is.finite(u2)) union <- intersection + u1 + u2
    }
    jaccard <- if ("jaccard" %in% names(overlap)) {
      as.numeric(overlap[["jaccard"]])
    } else if (is.finite(union) && union > 0) {
      intersection / union
    } else NA_real_

    row <- data.frame(
      Condition_id = id, Dimension = d, Method = dr$Method[[1L]],
      Samples_per_point = dr$Samples_per_point[[1L]],
      True_volume = true_volume, Estimated_volume = est_volume,
      Signed_relative_volume_error_percent = signed_error,
      Absolute_relative_volume_error_percent = abs(signed_error),
      Intersection_volume = intersection, Union_volume = union,
      Jaccard_similarity = jaccard,
      Geometry_runtime_seconds = unname(timing[["elapsed"]]),
      Success = TRUE, Error_message = NA_character_,
      stringsAsFactors = FALSE
    )
    list(success = TRUE, row = row, error_message = NA_character_)
  }, error = function(e) {
    list(success = FALSE, row = NULL, error_message = conditionMessage(e))
  })
  geometry_results[[id]] <- result
  save_geometry_checkpoint()
}

geometry_rows <- list()
for (i in seq_len(nrow(fit_design))) {
  dr <- fit_design[i, , drop = FALSE]
  id <- dr$Condition_id[[1L]]
  g <- geometry_results[[id]]
  if (!is.null(g) && isTRUE(g$success)) {
    geometry_rows[[i]] <- g$row
  } else {
    d <- dr$Dimension[[1L]]
    geometry_rows[[i]] <- data.frame(
      Condition_id = id, Dimension = d, Method = dr$Method[[1L]],
      Samples_per_point = dr$Samples_per_point[[1L]],
      True_volume = truth_archive[[paste0("d", d)]]$truth$true_volume,
      Estimated_volume = NA_real_,
      Signed_relative_volume_error_percent = NA_real_,
      Absolute_relative_volume_error_percent = NA_real_,
      Intersection_volume = NA_real_, Union_volume = NA_real_,
      Jaccard_similarity = NA_real_, Geometry_runtime_seconds = NA_real_,
      Success = FALSE,
      Error_message = if (is.null(g)) "Missing geometry result" else g$error_message,
      stringsAsFactors = FALSE
    )
  }
}
geometry_summary <- do.call(rbind, geometry_rows)
rownames(geometry_summary) <- NULL
write_csv_safely(geometry_summary, geometry_results_file)

# ============================================================
# H0 HELPERS
# ============================================================

empty_diagram <- function() {
  m <- matrix(numeric(0), nrow = 0L, ncol = 3L)
  colnames(m) <- c("dimension", "birth", "death")
  m
}
standardize_diagram <- function(diagram) {
  if (is.null(diagram) || length(diagram) == 0L) return(empty_diagram())
  diagram <- as.matrix(diagram)
  if (nrow(diagram) == 0L) return(empty_diagram())
  diagram <- diagram[, seq_len(3L), drop = FALSE]
  storage.mode(diagram) <- "double"
  colnames(diagram) <- c("dimension", "birth", "death")
  diagram
}
finite_diagram <- function(diagram) {
  d <- standardize_diagram(diagram)
  d[is.finite(d[, "birth"]) & is.finite(d[, "death"]), , drop = FALSE]
}
max_finite_h0 <- function(diagram) {
  d <- finite_diagram(diagram)
  h0 <- d[d[, "dimension"] == 0, , drop = FALSE]
  if (nrow(h0) == 0L) return(0)
  p <- h0[, "death"] - h0[, "birth"]
  p <- p[is.finite(p) & p >= 0]
  if (length(p) == 0L) 0 else max(p)
}
point_cloud_diameter <- function(points) {
  points <- name_axes(points)
  if (nrow(points) < 2L) return(NA_real_)
  max(stats::dist(points))
}

tda_formals <- names(formals(TDAstats::calculate_homology))
tda_supports_p <- "p" %in% tda_formals

calculate_h0 <- function(points) {
  points <- name_axes(points)
  start <- proc.time()[["elapsed"]]
  tryCatch({
    args <- list(mat = points, dim = 0L, threshold = ph_threshold, format = "cloud")
    if ("standardize" %in% tda_formals) args$standardize <- ph_standardize
    if ("return_df" %in% tda_formals) args$return_df <- FALSE
    if (tda_supports_p) args$p <- ph_prime_field
    diagram <- R.utils::withTimeout(
      do.call(TDAstats::calculate_homology, args),
      timeout = ph_timeout_seconds, onTimeout = "error"
    )
    list(success = TRUE, diagram = standardize_diagram(diagram),
         runtime_seconds = proc.time()[["elapsed"]] - start,
         failure_type = NA_character_, error_message = NA_character_)
  }, error = function(e) {
    txt <- conditionMessage(e)
    list(success = FALSE, diagram = empty_diagram(),
         runtime_seconds = proc.time()[["elapsed"]] - start,
         failure_type = if (grepl("time limit|timeout|reached elapsed", txt, ignore.case = TRUE))
           "computational-limit failure" else "calculation failure",
         error_message = txt)
  })
}

h0_bottleneck <- function(diag1, diag2) {
  tryCatch({
    x <- TDA::bottleneck(
      Diag1 = finite_diagram(diag1),
      Diag2 = finite_diagram(diag2),
      dimension = 0L
    )
    list(success = TRUE, distance = as.numeric(x), error_message = NA_character_)
  }, error = function(e) {
    list(success = FALSE, distance = NA_real_, error_message = conditionMessage(e))
  })
}


# ============================================================
# TOPOLOGY SUBSAMPLES
# ============================================================

topology_subsample_hash <- hash_r_object(list(
  fit_hash, ph_sample_size, number_of_topology_repetitions,
  topology_occurrence_seed_base, topology_estimator_seed_base
))

create_topology_subsamples <- function() {
  archive <- list(occurrence = list(), estimators = list())

  for (d in dimensions) {
    key <- paste0("d", d)
    n_source <- nrow(truth_archive[[key]]$truth$points)
    reps <- list()
    for (rep in seq_len(number_of_topology_repetitions)) {
      seed <- topology_occurrence_seed_base + d * 100L + rep
      set.seed(seed)
      reps[[as.character(rep)]] <- list(
        available = n_source >= ph_sample_size,
        seed = seed,
        source_point_count = n_source,
        selected_row_indices = if (n_source >= ph_sample_size)
          sample.int(n_source, ph_sample_size, replace = FALSE) else integer(0)
      )
    }
    archive$occurrence[[key]] <- reps
  }

  for (i in seq_len(nrow(fit_design))) {
    dr <- fit_design[i, , drop = FALSE]
    id <- dr$Condition_id[[1L]]
    rr <- fit_registry[fit_registry$Condition_id == id, , drop = FALSE]
    reps <- list()
    if (nrow(rr) != 1L || !isTRUE(rr$Success[[1L]])) {
      for (rep in seq_len(number_of_topology_repetitions)) {
        reps[[as.character(rep)]] <- list(
          available = FALSE, seed = NA_integer_,
          source_point_count = NA_integer_,
          selected_row_indices = integer(0)
        )
      }
    } else {
      hv <- get_hv(id)
      n_source <- nrow(hv@RandomPoints)
      for (rep in seq_len(number_of_topology_repetitions)) {
        seed <- topology_estimator_seed_base + i * 100L + rep
        if (n_source >= ph_sample_size) {
          set.seed(seed)
          idx <- sample.int(n_source, ph_sample_size, replace = FALSE)
          available <- TRUE
        } else {
          idx <- integer(0)
          available <- FALSE
        }
        reps[[as.character(rep)]] <- list(
          available = available, seed = seed,
          source_point_count = n_source,
          selected_row_indices = idx
        )
      }
    }
    archive$estimators[[id]] <- reps
  }
  list(hash = topology_subsample_hash, archive = archive)
}

if (file.exists(topology_subsample_file)) {
  topology_subsamples <- readRDS(topology_subsample_file)
  if (!identical(topology_subsamples$hash, topology_subsample_hash)) {
    stop("Incompatible topology subsample archive.")
  }
} else {
  topology_subsamples <- create_topology_subsamples()
  saveRDS(topology_subsamples, topology_subsample_file, version = 3)
}

# ============================================================
# H0 CALCULATIONS
# ============================================================

topology_hash <- hash_r_object(list(
  topology_subsample_hash, ph_threshold, ph_prime_field,
  ph_standardize, ph_timeout_seconds
))
if (file.exists(topology_checkpoint_file)) {
  cp <- readRDS(topology_checkpoint_file)
  if (!identical(cp$topology_hash, topology_hash)) stop("Incompatible topology checkpoint.")
  topology_results <- cp$topology_results
} else {
  topology_results <- list()
}
save_topology_checkpoint <- function() {
  saveRDS(list(topology_hash = topology_hash, topology_results = topology_results),
          topology_checkpoint_file, version = 3)
}

occurrence_ph_key <- function(d, rep) paste0("Occurrence__d", d, "__rep", rep)
estimator_ph_key <- function(id, rep) paste0(id, "__rep", rep)

# Occurrence H0 once per dimension/repetition.
for (d in dimensions) {
  dkey <- paste0("d", d)
  points <- truth_archive[[dkey]]$truth$points
  for (rep in seq_len(number_of_topology_repetitions)) {
    key <- occurrence_ph_key(d, rep)
    if (!is.null(topology_results[[key]]) && isTRUE(topology_results[[key]]$success)) next
    entry <- topology_subsamples$archive$occurrence[[dkey]][[as.character(rep)]]
    if (!isTRUE(entry$available)) next
    sampled <- name_axes(points[entry$selected_row_indices, , drop = FALSE])
    message("Occurrence H0: d=", d, " rep=", rep)
    ph <- calculate_h0(sampled)
    topology_results[[key]] <- c(list(
      source_type = "Occurrence", dimensionality = d,
      condition_id = NA_character_, method = "Occurrence",
      samples_per_point = NA_integer_, repetition = rep,
      sampled_points = sampled,
      selected_row_indices = entry$selected_row_indices,
      subsample_seed = entry$seed,
      point_cloud_diameter = point_cloud_diameter(sampled)
    ), ph)
    save_topology_checkpoint()
  }
}

# Estimator H0.
for (i in seq_len(nrow(fit_design))) {
  dr <- fit_design[i, , drop = FALSE]
  id <- dr$Condition_id[[1L]]
  rr <- fit_registry[fit_registry$Condition_id == id, , drop = FALSE]
  for (rep in seq_len(number_of_topology_repetitions)) {
    key <- estimator_ph_key(id, rep)
    if (!is.null(topology_results[[key]]) && isTRUE(topology_results[[key]]$success)) next

    if (nrow(rr) != 1L || !isTRUE(rr$Success[[1L]])) {
      topology_results[[key]] <- list(
        source_type = "Estimator", dimensionality = dr$Dimension[[1L]],
        condition_id = id, method = dr$Method[[1L]],
        samples_per_point = dr$Samples_per_point[[1L]], repetition = rep,
        success = FALSE, diagram = empty_diagram(),
        runtime_seconds = NA_real_, point_cloud_diameter = NA_real_,
        failure_type = "fit failure",
        error_message = if (nrow(rr) == 1L) rr$Error_message[[1L]] else "Missing fit"
      )
      save_topology_checkpoint()
      next
    }

    entry <- topology_subsamples$archive$estimators[[id]][[as.character(rep)]]
    if (!isTRUE(entry$available)) {
      topology_results[[key]] <- list(
        source_type = "Estimator", dimensionality = dr$Dimension[[1L]],
        condition_id = id, method = dr$Method[[1L]],
        samples_per_point = dr$Samples_per_point[[1L]], repetition = rep,
        success = FALSE, diagram = empty_diagram(),
        runtime_seconds = NA_real_, point_cloud_diameter = NA_real_,
        failure_type = "not assessable",
        error_message = paste0("Only ", entry$source_point_count,
                               " random points; ", ph_sample_size, " required.")
      )
      save_topology_checkpoint()
      next
    }

    hv <- get_hv(id)
    sampled <- name_axes(hv@RandomPoints[entry$selected_row_indices, , drop = FALSE])
    message("Estimator H0: ", id, " rep=", rep)
    ph <- calculate_h0(sampled)
    topology_results[[key]] <- c(list(
      source_type = "Estimator", dimensionality = dr$Dimension[[1L]],
      condition_id = id, method = dr$Method[[1L]],
      samples_per_point = dr$Samples_per_point[[1L]], repetition = rep,
      sampled_points = sampled,
      selected_row_indices = entry$selected_row_indices,
      subsample_seed = entry$seed,
      point_cloud_diameter = point_cloud_diameter(sampled)
    ), ph)
    save_topology_checkpoint()
  }
}

# ------------------------------------------------------------
# Paired normalized H0 bottleneck table
# ------------------------------------------------------------
topology_rows <- list()
ti <- 0L
for (i in seq_len(nrow(fit_design))) {
  dr <- fit_design[i, , drop = FALSE]
  id <- dr$Condition_id[[1L]]
  d <- dr$Dimension[[1L]]
  for (rep in seq_len(number_of_topology_repetitions)) {
    ti <- ti + 1L
    occ <- topology_results[[occurrence_ph_key(d, rep)]]
    est <- topology_results[[estimator_ph_key(id, rep)]]
    ok <- !is.null(occ) && !is.null(est) && isTRUE(occ$success) && isTRUE(est$success)
    if (ok) {
      bn <- h0_bottleneck(occ$diagram, est$diagram)
      norm <- if (isTRUE(bn$success) && is.finite(occ$point_cloud_diameter) &&
                  occ$point_cloud_diameter > 0) {
        bn$distance / occ$point_cloud_diameter
      } else NA_real_
    } else {
      bn <- list(success = FALSE, distance = NA_real_, error_message = "Occurrence/estimator PH unavailable")
      norm <- NA_real_
    }

    topology_rows[[ti]] <- data.frame(
      Condition_id = id, Dimension = d, Method = dr$Method[[1L]],
      Samples_per_point = dr$Samples_per_point[[1L]], Repetition = rep,
      Success = isTRUE(bn$success) && is.finite(norm),
      Bottleneck_distance_H0 = bn$distance,
      Occurrence_diameter = if (!is.null(occ)) occ$point_cloud_diameter else NA_real_,
      Normalized_bottleneck_H0 = norm,
      Occurrence_maximum_H0_persistence = if (!is.null(occ) && isTRUE(occ$success))
        max_finite_h0(occ$diagram) else NA_real_,
      Estimator_maximum_H0_persistence = if (!is.null(est) && isTRUE(est$success))
        max_finite_h0(est$diagram) else NA_real_,
      Error_message = bn$error_message,
      stringsAsFactors = FALSE
    )
  }
}
topology_replicates <- do.call(rbind, topology_rows)
rownames(topology_replicates) <- NULL
write_csv_safely(topology_replicates, topology_replicate_file)

topology_summary_rows <- list()
for (i in seq_len(nrow(fit_design))) {
  dr <- fit_design[i, , drop = FALSE]
  id <- dr$Condition_id[[1L]]
  x <- topology_replicates[topology_replicates$Condition_id == id, , drop = FALSE]
  y <- x[x$Success & is.finite(x$Normalized_bottleneck_H0), , drop = FALSE]
  topology_summary_rows[[i]] <- data.frame(
    Condition_id = id, Dimension = dr$Dimension[[1L]], Method = dr$Method[[1L]],
    Samples_per_point = dr$Samples_per_point[[1L]],
    Repetitions_requested = number_of_topology_repetitions,
    Repetitions_successful = nrow(y),
    Mean_bottleneck_distance_H0 = safe_mean(y$Bottleneck_distance_H0),
    SD_bottleneck_distance_H0 = safe_sd(y$Bottleneck_distance_H0),
    Mean_normalized_bottleneck_H0 = safe_mean(y$Normalized_bottleneck_H0),
    SD_normalized_bottleneck_H0 = safe_sd(y$Normalized_bottleneck_H0),
    stringsAsFactors = FALSE
  )
}
topology_summary <- do.call(rbind, topology_summary_rows)
rownames(topology_summary) <- NULL
write_csv_safely(topology_summary, topology_summary_file)

# ============================================================
# MATCHED FILLED d-ELLIPSOID NULLS
# ============================================================

make_positive_definite <- function(m, epsilon = 1e-8) {
  m <- as.matrix(m)
  m <- (m + t(m)) / 2
  eig <- eigen(m, symmetric = TRUE)
  floor_value <- max(max(eig$values) * 1e-10, epsilon, .Machine$double.eps)
  eig$vectors %*% diag(pmax(eig$values, floor_value), nrow = length(eig$values)) %*%
    t(eig$vectors)
}

generate_matched_ellipsoid <- function(target_points, number_of_points, seed) {
  target_points <- name_axes(target_points)
  d <- ncol(target_points)
  if (number_of_points <= d) stop("Null point count must exceed dimensionality.")
  target_centroid <- colMeans(target_points)
  target_covariance <- make_positive_definite(stats::cov(target_points))

  set.seed(seed)
  directions <- matrix(stats::rnorm(number_of_points * d),
                       nrow = number_of_points, ncol = d)
  norms <- sqrt(rowSums(directions^2))
  while (any(norms == 0)) {
    bad <- which(norms == 0)
    directions[bad, ] <- matrix(stats::rnorm(length(bad) * d),
                                nrow = length(bad), ncol = d)
    norms[bad] <- sqrt(rowSums(directions[bad, , drop = FALSE]^2))
  }
  unit_ball <- (directions / norms) * stats::runif(number_of_points)^(1 / d)
  unit_ball <- sweep(unit_ball, 2, colMeans(unit_ball), FUN = "-")
  unit_cov <- make_positive_definite(stats::cov(unit_ball))
  whitened <- unit_ball %*% solve(chol(unit_cov))
  points <- whitened %*% chol(target_covariance)
  points <- sweep(points, 2, target_centroid, FUN = "+")
  points <- name_axes(points)

  list(
    points = points,
    centroid_error = max(abs(colMeans(points) - target_centroid)),
    covariance_error = max(abs(stats::cov(points) - target_covariance))
  )
}

# 7 occurrence source conditions + 84 estimator source conditions.
manifest_rows <- list()
mi <- 0L
for (d in dimensions) {
  mi <- mi + 1L
  manifest_rows[[mi]] <- data.frame(
    Source_condition_id = paste0("Occurrence__d", d),
    Source_type = "Occurrence", Condition_id = NA_character_,
    Dimension = d, Method = "Occurrence", Samples_per_point = NA_integer_,
    stringsAsFactors = FALSE
  )
}
for (i in seq_len(nrow(fit_design))) {
  dr <- fit_design[i, , drop = FALSE]
  mi <- mi + 1L
  manifest_rows[[mi]] <- data.frame(
    Source_condition_id = paste0("Estimator__", dr$Condition_id[[1L]]),
    Source_type = "Estimator", Condition_id = dr$Condition_id[[1L]],
    Dimension = dr$Dimension[[1L]], Method = dr$Method[[1L]],
    Samples_per_point = dr$Samples_per_point[[1L]],
    stringsAsFactors = FALSE
  )
}
matched_manifest <- do.call(rbind, manifest_rows)
rownames(matched_manifest) <- NULL
matched_manifest$Condition_number <- seq_len(nrow(matched_manifest))
matched_manifest$Null_replicates_requested <- number_of_matched_reference_replicates
matched_manifest$Null_point_count <- ph_sample_size
matched_manifest$Matching_basis <- "Full source cloud centroid and covariance"
if (nrow(matched_manifest) != 91L) stop("Expected 91 matched-reference source conditions.")
write_csv_safely(matched_manifest, matched_manifest_file)

get_full_source_points <- function(mr) {
  if (mr$Source_type[[1L]] == "Occurrence") {
    return(truth_archive[[paste0("d", mr$Dimension[[1L]])]]$truth$points)
  }
  hv <- get_hv(
    mr$Condition_id[[1L]]
  )

  name_axes(
    hv@RandomPoints
  )
}

matched_hash <- hash_r_object(list(
  topology_hash, matched_manifest,
  number_of_matched_reference_replicates, ph_sample_size,
  matched_reference_seed_base
))
if (file.exists(matched_checkpoint_file)) {
  cp <- readRDS(matched_checkpoint_file)
  if (!identical(cp$matched_hash, matched_hash)) stop("Incompatible matched-reference checkpoint.")
  matched_results <- cp$matched_results
} else {
  matched_results <- list()
}
save_matched_checkpoint <- function() {
  saveRDS(list(matched_hash = matched_hash, matched_results = matched_results),
          matched_checkpoint_file, version = 3)
}
matched_key <- function(source_id, rep) paste0(source_id, "__null", sprintf("%02d", rep))

for (cn in seq_len(nrow(matched_manifest))) {
  mr <- matched_manifest[cn, , drop = FALSE]
  source_id <- mr$Source_condition_id[[1L]]

  full_source <- tryCatch(
    list(success = TRUE, points = name_axes(get_full_source_points(mr)), error_message = NA_character_),
    error = function(e) list(success = FALSE, points = NULL, error_message = conditionMessage(e))
  )

  for (null_rep in seq_len(number_of_matched_reference_replicates)) {
    key <- matched_key(source_id, null_rep)
    if (!is.null(matched_results[[key]]) && isTRUE(matched_results[[key]]$success)) next

    if (!isTRUE(full_source$success)) {
      matched_results[[key]] <- list(
        success = FALSE, diagram = empty_diagram(), runtime_seconds = NA_real_,
        seed = NA_integer_, centroid_error = NA_real_, covariance_error = NA_real_,
        failure_type = "source unavailable", error_message = full_source$error_message
      )
      save_matched_checkpoint()
      next
    }

    seed <- matched_reference_seed_base + cn * 1000L + null_rep
    message("Matched H0 null ", cn, "/91; ", null_rep, "/20: ", source_id)
    result <- tryCatch({
      generated <- generate_matched_ellipsoid(full_source$points, ph_sample_size, seed)
      ph <- calculate_h0(generated$points)
      c(list(seed = seed, centroid_error = generated$centroid_error,
             covariance_error = generated$covariance_error), ph)
    }, error = function(e) {
      list(success = FALSE, diagram = empty_diagram(), runtime_seconds = NA_real_,
           seed = seed, centroid_error = NA_real_, covariance_error = NA_real_,
           failure_type = "null generation failure", error_message = conditionMessage(e))
    })
    matched_results[[key]] <- result
    save_matched_checkpoint()
  }
}

# ------------------------------------------------------------
# Null replicate and threshold tables
# ------------------------------------------------------------
null_rows <- list()
ni <- 0L
for (cn in seq_len(nrow(matched_manifest))) {
  mr <- matched_manifest[cn, , drop = FALSE]
  source_id <- mr$Source_condition_id[[1L]]
  for (null_rep in seq_len(number_of_matched_reference_replicates)) {
    res <- matched_results[[matched_key(source_id, null_rep)]]
    if (is.null(res)) next
    ni <- ni + 1L
    null_rows[[ni]] <- data.frame(
      Source_condition_id = source_id, Source_type = mr$Source_type[[1L]],
      Condition_id = mr$Condition_id[[1L]], Dimension = mr$Dimension[[1L]],
      Method = mr$Method[[1L]], Samples_per_point = mr$Samples_per_point[[1L]],
      Null_repetition = null_rep, Null_seed = res$seed, Success = res$success,
      Maximum_H0_persistence = if (isTRUE(res$success)) max_finite_h0(res$diagram) else NA_real_,
      Runtime_seconds = res$runtime_seconds,
      Centroid_error = res$centroid_error, Covariance_error = res$covariance_error,
      Failure_type = res$failure_type, Error_message = res$error_message,
      stringsAsFactors = FALSE
    )
  }
}
matched_nulls <- do.call(rbind, null_rows)
rownames(matched_nulls) <- NULL
write_csv_safely(matched_nulls, matched_null_file)

threshold_rows <- list()
for (cn in seq_len(nrow(matched_manifest))) {
  mr <- matched_manifest[cn, , drop = FALSE]
  source_id <- mr$Source_condition_id[[1L]]
  x <- matched_nulls[matched_nulls$Source_condition_id == source_id &
                       matched_nulls$Success &
                       is.finite(matched_nulls$Maximum_H0_persistence), , drop = FALSE]
  complete <- nrow(x) == number_of_matched_reference_replicates
  threshold_rows[[cn]] <- data.frame(
    Source_condition_id = source_id, Source_type = mr$Source_type[[1L]],
    Condition_id = mr$Condition_id[[1L]], Dimension = mr$Dimension[[1L]],
    Method = mr$Method[[1L]], Samples_per_point = mr$Samples_per_point[[1L]],
    Null_replicates_requested = number_of_matched_reference_replicates,
    Null_replicates_successful = nrow(x), Null_set_complete = complete,
    Matched_reference_threshold_H0 = if (complete) max(x$Maximum_H0_persistence) else NA_real_,
    Mean_null_maximum_H0_persistence = safe_mean(x$Maximum_H0_persistence),
    SD_null_maximum_H0_persistence = safe_sd(x$Maximum_H0_persistence),
    stringsAsFactors = FALSE
  )
}
matched_thresholds <- do.call(rbind, threshold_rows)
rownames(matched_thresholds) <- NULL
write_csv_safely(matched_thresholds, matched_threshold_file)


# ============================================================
# OBSERVED H0 VS SHARED MATCHED-REFERENCE THRESHOLD
# ============================================================

observed_rows <- list()
oi <- 0L
for (cn in seq_len(nrow(matched_manifest))) {
  mr <- matched_manifest[cn, , drop = FALSE]
  source_id <- mr$Source_condition_id[[1L]]
  threshold_row <- matched_thresholds[
    matched_thresholds$Source_condition_id == source_id, , drop = FALSE
  ]
  if (nrow(threshold_row) != 1L) stop("Expected one threshold row for ", source_id)

  for (rep in seq_len(number_of_topology_repetitions)) {
    if (mr$Source_type[[1L]] == "Occurrence") {
      observed <- topology_results[[occurrence_ph_key(mr$Dimension[[1L]], rep)]]
    } else {
      observed <- topology_results[[estimator_ph_key(mr$Condition_id[[1L]], rep)]]
    }

    observed_success <- !is.null(observed) && isTRUE(observed$success)
    observed_max <- if (observed_success) max_finite_h0(observed$diagram) else NA_real_
    threshold <- threshold_row$Matched_reference_threshold_H0[[1L]]
    exceeds <- if (observed_success &&
                   isTRUE(threshold_row$Null_set_complete[[1L]]) &&
                   is.finite(observed_max) && is.finite(threshold)) {
      observed_max > threshold
    } else NA

    oi <- oi + 1L
    observed_rows[[oi]] <- data.frame(
      Source_condition_id = source_id,
      Source_type = mr$Source_type[[1L]],
      Condition_id = mr$Condition_id[[1L]],
      Dimension = mr$Dimension[[1L]],
      Method = mr$Method[[1L]],
      Samples_per_point = mr$Samples_per_point[[1L]],
      Repetition = rep,
      Observed_success = observed_success,
      Observed_maximum_H0_persistence = observed_max,
      Null_replicates_successful = threshold_row$Null_replicates_successful[[1L]],
      Null_set_complete = threshold_row$Null_set_complete[[1L]],
      Matched_reference_threshold_H0 = threshold,
      Exceeds_matched_reference = exceeds,
      Error_message = if (is.null(observed)) "Observed PH unavailable" else observed$error_message,
      stringsAsFactors = FALSE
    )
  }
}
matched_observed <- do.call(rbind, observed_rows)
rownames(matched_observed) <- NULL
write_csv_safely(matched_observed, matched_observed_file)

# ------------------------------------------------------------
# Exceedance proportion
# ------------------------------------------------------------
exceedance_rows <- list()
for (cn in seq_len(nrow(matched_manifest))) {
  mr <- matched_manifest[cn, , drop = FALSE]
  source_id <- mr$Source_condition_id[[1L]]
  x <- matched_observed[
    matched_observed$Source_condition_id == source_id, , drop = FALSE
  ]
  y <- x[
    x$Observed_success &
      x$Null_set_complete &
      !is.na(x$Exceeds_matched_reference),
    , drop = FALSE
  ]
  n_exceed <- if (nrow(y) > 0L) sum(y$Exceeds_matched_reference) else 0L
  prop <- if (nrow(y) > 0L) n_exceed / nrow(y) else NA_real_
  tr <- matched_thresholds[
    matched_thresholds$Source_condition_id == source_id, , drop = FALSE
  ]

  exceedance_rows[[cn]] <- data.frame(
    Source_condition_id = source_id,
    Source_type = mr$Source_type[[1L]],
    Condition_id = mr$Condition_id[[1L]],
    Dimension = mr$Dimension[[1L]],
    Method = mr$Method[[1L]],
    Samples_per_point = mr$Samples_per_point[[1L]],
    Observed_repetitions_requested = number_of_topology_repetitions,
    Observed_repetitions_successful = nrow(y),
    Number_exceeding_matched_reference = n_exceed,
    Exceedance_proportion = prop,
    Matched_reference_threshold_H0 = tr$Matched_reference_threshold_H0[[1L]],
    Null_replicates_requested = tr$Null_replicates_requested[[1L]],
    Null_replicates_successful = tr$Null_replicates_successful[[1L]],
    Null_set_complete = tr$Null_set_complete[[1L]],
    stringsAsFactors = FALSE
  )
}
matched_exceedance <- do.call(rbind, exceedance_rows)
rownames(matched_exceedance) <- NULL
write_csv_safely(matched_exceedance, matched_exceedance_file)

# ============================================================
# COMBINED ESTIMATOR TABLE
# ============================================================

estimator_exceedance <- matched_exceedance[
  matched_exceedance$Source_type == "Estimator", , drop = FALSE
]

combined_results <- merge(
  fit_registry,
  geometry_summary[, c(
    "Condition_id", "True_volume",
    "Signed_relative_volume_error_percent",
    "Absolute_relative_volume_error_percent",
    "Jaccard_similarity", "Geometry_runtime_seconds", "Success"
  ), drop = FALSE],
  by = "Condition_id", all.x = TRUE, sort = FALSE,
  suffixes = c("_Fit", "_Geometry")
)

combined_results <- merge(
  combined_results,
  topology_summary[, c(
    "Condition_id", "Repetitions_requested", "Repetitions_successful",
    "Mean_bottleneck_distance_H0", "SD_bottleneck_distance_H0",
    "Mean_normalized_bottleneck_H0", "SD_normalized_bottleneck_H0"
  ), drop = FALSE],
  by = "Condition_id", all.x = TRUE, sort = FALSE
)

combined_results <- merge(
  combined_results,
  estimator_exceedance[, c(
    "Condition_id", "Observed_repetitions_successful",
    "Exceedance_proportion", "Matched_reference_threshold_H0",
    "Null_replicates_successful", "Null_set_complete"
  ), drop = FALSE],
  by = "Condition_id", all.x = TRUE, sort = FALSE
)

combined_results <- combined_results[
  match(fit_design$Condition_id, combined_results$Condition_id),
  , drop = FALSE
]
rownames(combined_results) <- NULL
write_csv_safely(combined_results, final_table_file)

# ============================================================
# FAILURE AUDIT
# ============================================================

failure_rows <- list()
fi <- 0L

add_failure <- function(stage, id, d, method, spp, rep, message_text) {
  fi <<- fi + 1L
  failure_rows[[fi]] <<- data.frame(
    Stage = stage, Condition_id = id, Dimension = d, Method = method,
    Samples_per_point = spp, Repetition = rep,
    Error_message = message_text, stringsAsFactors = FALSE
  )
}

failed <- fit_registry[!fit_registry$Success, , drop = FALSE]
if (nrow(failed) > 0L) {
  for (r in seq_len(nrow(failed))) {
    add_failure("Estimator fit", failed$Condition_id[r], failed$Dimension[r],
                failed$Method[r], failed$Samples_per_point[r], NA_integer_,
                failed$Error_message[r])
  }
}

failed <- geometry_summary[!geometry_summary$Success, , drop = FALSE]
if (nrow(failed) > 0L) {
  for (r in seq_len(nrow(failed))) {
    add_failure("Geometry", failed$Condition_id[r], failed$Dimension[r],
                failed$Method[r], failed$Samples_per_point[r], NA_integer_,
                failed$Error_message[r])
  }
}

failed <- topology_replicates[!topology_replicates$Success, , drop = FALSE]
if (nrow(failed) > 0L) {
  for (r in seq_len(nrow(failed))) {
    add_failure("Topology / bottleneck", failed$Condition_id[r], failed$Dimension[r],
                failed$Method[r], failed$Samples_per_point[r], failed$Repetition[r],
                failed$Error_message[r])
  }
}

failed <- matched_nulls[!matched_nulls$Success, , drop = FALSE]
if (nrow(failed) > 0L) {
  for (r in seq_len(nrow(failed))) {
    add_failure("Matched reference H0", failed$Condition_id[r], failed$Dimension[r],
                failed$Method[r], failed$Samples_per_point[r], failed$Null_repetition[r],
                failed$Error_message[r])
  }
}

failure_table <- if (length(failure_rows) > 0L) {
  do.call(rbind, failure_rows)
} else {
  data.frame(
    Stage = character(), Condition_id = character(), Dimension = integer(),
    Method = character(), Samples_per_point = integer(), Repetition = integer(),
    Error_message = character(), stringsAsFactors = FALSE
  )
}
write_csv_safely(failure_table, failure_file)

# ============================================================
# FINAL AUTHORITATIVE OBJECT
# ============================================================

final_results <- list(
  metadata = list(
    script = "11_Synthetic_Dimensionality_Test.R",
    analysis_settings_hash = analysis_settings_hash,
    qph_core_version = QPH_CORE_VERSION,
    qph_core_md5 = qph_core_md5,
    dimensions = dimensions,
    occurrence_sample_size = occurrence_sample_size,
    samples_per_point_values = samples_per_point_values,
    estimator_condition_count = nrow(fit_design),
    matched_reference_condition_count = nrow(matched_manifest),
    maximum_matched_null_ph_calls = nrow(matched_manifest) *
      number_of_matched_reference_replicates,
    completed_at = as.character(Sys.time())
  ),
  truth_manifest = truth_manifest,
  fit_design = fit_design,
  fit_registry = fit_registry,
  geometry_summary = geometry_summary,
  topology_replicates = topology_replicates,
  topology_summary = topology_summary,
  matched_reference_manifest = matched_manifest,
  matched_reference_nulls = matched_nulls,
  matched_reference_thresholds = matched_thresholds,
  matched_reference_observed = matched_observed,
  matched_reference_exceedance_summary = matched_exceedance,
  combined_results = combined_results,
  failures = failure_table
)
saveRDS(final_results, final_results_file, version = 3)

# ------------------------------------------------------------
# Notes and session
# ------------------------------------------------------------
writeLines(c(
  "Revised synthetic dimensionality benchmark",
  "==========================================",
  "",
  paste0("Project directory: ", project_directory),
  "Dimensions = 2:8",
  paste0("Occurrence n = ", occurrence_sample_size, " (450 per component)"),
  paste0("Constant analytical total volume = ", format(target_total_volume, digits = 10)),
  "Relative separation: centre offset / radius = 2",
  "",
  paste0("Sampling effort = ", paste(samples_per_point_values, collapse = ", "), " samples per point"),
  "",
  "QPH: revised sqrt-NB bandwidth; K=30; q=.99; sd.count=3",
  "KDE: own Silverman bandwidth; probability q=.95; sd.count=3",
  "SVM: nu=.010; gamma=.50; scale.factor=1",
  "",
  "Runtime = full end-to-end estimator construction.",
  "QPH runtime includes revised bandwidth estimation and complete Monte Carlo sampling.",
  "KDE runtime includes Silverman estimation and complete Monte Carlo sampling.",
  "SVM runtime includes model fitting and complete Monte Carlo sampling.",
  "Geometry and PH evaluation are excluded from estimator runtime.",
  "",
  "Geometry: fixed 100,000-point truth reference per dimension; Jaccard; signed/absolute relative volume error.",
  "Topology: H0 only; 10 x 300-point observed repetitions; paired normalized bottleneck.",
  "Matched reference: 20 shared full-source matched filled d-ellipsoid nulls per source condition.",
  "Exceedance statistic = Exceedance_proportion.",
  "",
  paste0("Estimator conditions = ", nrow(fit_design)),
  paste0("Matched-reference source conditions = ", nrow(matched_manifest)),
  paste0("Maximum matched-null PH calls = ",
         nrow(matched_manifest) * number_of_matched_reference_replicates),
  paste0("Failures recorded = ", nrow(failure_table)),
  paste0("Completed: ", Sys.time())
), notes_file)

capture.output(sessionInfo(), file = session_file)

message("\n============================================================")
message("11_Synthetic_Dimensionality_Test.R complete.")
message("Estimator conditions: ", nrow(fit_design), " (expected 84)")
message("Successful fits: ", sum(fit_registry$Success), " / ", nrow(fit_registry))
message("Matched-reference source conditions: ", nrow(matched_manifest), " (expected 91)")
message("Maximum matched-null H0 calls: ",
        nrow(matched_manifest) * number_of_matched_reference_replicates)
message("Failures recorded: ", nrow(failure_table))
message("Final result object:\n  ", normalizePath(final_results_file, mustWork = FALSE))
message("Combined table:\n  ", normalizePath(final_table_file, mustWork = FALSE))
message("Output directory:\n  ", normalizePath(output_directory, mustWork = FALSE))
message("============================================================")
