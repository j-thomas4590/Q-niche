# ============================================================
# 16_Virtual_Species_QPH_Sensitivity_n900.R
# ============================================================
#
# PURPOSE
# -------
# Revised QPH-only one-factor-at-a-time (OFAT) sensitivity analysis for the
# TWO locked virtual species at n = 900.
#


rm(list = ls())
gc()


# ============================================================
# Project paths
# ============================================================

# Run from the repository's root folder.
project_directory <- "."

scripts_directory <- file.path(
  project_directory,
  "Scripts"
)

analysis_root_directory <- file.path(
  project_directory,
  "Results",
  "Virtual_Species_sqrtNB_q099"
)

locked_input_directory <- file.path(
  analysis_root_directory,
  "00_Locked_Inputs"
)

baseline_fit_directory <- file.path(
  analysis_root_directory,
  "01_Baseline_Fits"
)

geographic_directory <- file.path(
  analysis_root_directory,
  "02_Geographic_Validation"
)

geometry_directory <- file.path(
  analysis_root_directory,
  "03_Environmental_Geometry"
)

output_directory <- file.path(
  analysis_root_directory,
  "05_QPH_Sensitivity"
)

model_object_directory <- file.path(
  output_directory,
  "model_objects"
)

projection_raster_directory <- file.path(
  output_directory,
  "projection_rasters"
)

table_directory <- file.path(
  output_directory,
  "tables"
)

for (directory in c(
  output_directory,
  model_object_directory,
  projection_raster_directory,
  table_directory
)) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ============================================================
# Authoritative QPH implementation
# ============================================================

qph_core_file <- file.path(
  scripts_directory,
  "00_QPH_Core_Functions.R"
)

if (!file.exists(qph_core_file)) {
  stop(
    "Missing authoritative QPH core:\n  ",
    qph_core_file
  )
}

source(
  qph_core_file,
  local = FALSE
)

expected_qph_core_version <- "sqrtNB_q099_v1"

if (
  !exists(
    "QPH_CORE_VERSION",
    inherits = TRUE
  ) ||
    !identical(
      as.character(
        QPH_CORE_VERSION
      ),
      expected_qph_core_version
    )
) {
  stop(
    "Unexpected QPH core version. Expected ",
    expected_qph_core_version,
    "."
  )
}

qph_core_md5 <- unname(
  tools::md5sum(
    qph_core_file
  )
)


# ============================================================
# Packages
# ============================================================

required_packages <- c(
  "terra",
  "hypervolume"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    logical(1),
    quietly = TRUE
  )
]

if (length(missing_packages) > 0L) {
  stop(
    "Install required package(s): ",
    paste(
      missing_packages,
      collapse = ", "
    )
  )
}

library(terra)
library(hypervolume)


# ============================================================
# Locked sensitivity settings
# ============================================================

analysis_sample_size <- 900L

species_order <- c(
  "Unimodal",
  "Disconnected"
)

species_labels <- c(
  Unimodal = "Unimodal Gaussian-PCA",
  Disconnected = "Disconnected bimodal"
)

baseline_bandwidth_multiplier <- 1.00
baseline_q <- 0.99
baseline_samples_per_point <- 100L
baseline_sd_count <- 3

bandwidth_multipliers <- c(
  0.75,
  1.00,
  1.25
)

q_levels <- c(
  0.950,
  0.975,
  0.990
)

samples_per_point_levels <- c(
  25L,
  50L,
  100L,
  150L
)

shared_chunk_size <- 100L
potential_batch_size <- 500L
projection_batch_size <- 500L

resume_model_fits <- TRUE
retry_failed_model_fits <- TRUE
resume_projections <- TRUE
retry_failed_projections <- TRUE
verbose_qph <- FALSE

numeric_tolerance <- 1e-8
projection_tolerance <- sqrt(
  .Machine$double.eps
)

gap_corridor_radius_multiplier <- 1.0

method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)

true_region_colour <- "#D9D9D9"
occurrence_colour <- "#111111"


# ============================================================
# Required upstream files
# ============================================================

locked_master_file <- file.path(
  locked_input_directory,
  "virtual_species_locked_inputs.rds"
)

locked_settings_file <- file.path(
  locked_input_directory,
  "locked_input_settings.rds"
)

baseline_settings_file <- file.path(
  baseline_fit_directory,
  "analysis_settings.rds"
)

baseline_results_file <- file.path(
  geographic_directory,
  "virtual_species_baseline_geographic_results_sqrtNB_q099.rds"
)

geometry_results_file <- file.path(
  geometry_directory,
  "virtual_species_environmental_geometry_n900_sqrtNB_q099.rds"
)

required_upstream_files <- c(
  locked_master_file,
  locked_settings_file,
  baseline_settings_file,
  baseline_results_file,
  geometry_results_file
)

missing_upstream_files <- required_upstream_files[
  !file.exists(
    required_upstream_files
  )
]

if (length(missing_upstream_files) > 0L) {
  stop(
    "Missing required upstream file(s):\n  ",
    paste(
      missing_upstream_files,
      collapse = "\n  "
    ),
    "\nRun Scripts 12-14 successfully before Script 16."
  )
}


# ============================================================
# Output files
# ============================================================

analysis_settings_file <- file.path(
  output_directory,
  "sensitivity_analysis_settings.rds"
)

sensitivity_design_file <- file.path(
  table_directory,
  "QPH_virtual_species_sensitivity_design_n900.csv"
)

model_registry_file <- file.path(
  output_directory,
  "QPH_sensitivity_model_registry.rds"
)

projection_registry_file <- file.path(
  output_directory,
  "QPH_sensitivity_projection_registry.rds"
)

qph_audit_summary_file <- file.path(
  table_directory,
  "QPH_sensitivity_audit_summary_n900.csv"
)

qph_local_s_file <- file.path(
  table_directory,
  "QPH_sensitivity_local_s_n900.csv"
)

geographic_metrics_file <- file.path(
  table_directory,
  "QPH_sensitivity_geographic_recovery_n900.csv"
)

availability_geometry_file <- file.path(
  table_directory,
  "QPH_sensitivity_availability_conditioned_geometry_n900.csv"
)

continuous_geometry_file <- file.path(
  table_directory,
  "QPH_sensitivity_continuous_geometry_n900.csv"
)

disconnected_structural_file <- file.path(
  table_directory,
  "QPH_sensitivity_disconnected_structural_metrics_n900.csv"
)

combined_condition_results_file <- file.path(
  table_directory,
  "QPH_sensitivity_combined_condition_results_n900.csv"
)

plot_ready_long_file <- file.path(
  table_directory,
  "QPH_sensitivity_plot_ready_long_n900.csv"
)

failure_file <- file.path(
  table_directory,
  "QPH_sensitivity_failures_n900.csv"
)

baseline_qa_file <- file.path(
  table_directory,
  "QPH_sensitivity_baseline_reuse_QA_n900.csv"
)

final_results_file <- file.path(
  output_directory,
  "virtual_species_QPH_sensitivity_n900_sqrtNB_q099.rds"
)

analysis_notes_file <- file.path(
  output_directory,
  "analysis_notes.txt"
)

session_information_file <- file.path(
  output_directory,
  "session_information.txt"
)


# ============================================================
# General helpers
# ============================================================

write_csv_safely <- function(
    x,
    file
) {

  dir.create(
    dirname(file),
    recursive = TRUE,
    showWarnings = FALSE
  )

  utils::write.csv(
    x,
    file = file,
    row.names = FALSE
  )

  invisible(file)
}


safe_md5 <- function(path) {

  if (
    length(path) != 1L ||
      is.na(path) ||
      !file.exists(path)
  ) {
    return(
      NA_character_
    )
  }

  unname(
    tools::md5sum(
      path
    )
  )
}


hash_r_object <- function(x) {

  temporary_file <- tempfile(
    fileext = ".rds"
  )

  on.exit(
    unlink(
      temporary_file
    ),
    add = TRUE
  )

  saveRDS(
    x,
    temporary_file,
    version = 3
  )

  safe_md5(
    temporary_file
  )
}


as_spatraster_safe <- function(x) {

  if (inherits(x, "SpatRaster")) {
    return(x)
  }

  if (inherits(x, "PackedSpatRaster")) {
    return(
      terra::unwrap(x)
    )
  }

  candidate <- try(
    terra::rast(x),
    silent = TRUE
  )

  if (
    !inherits(
      candidate,
      "try-error"
    ) &&
      inherits(
        candidate,
        "SpatRaster"
      )
  ) {
    return(
      candidate
    )
  }

  candidate <- try(
    terra::unwrap(x),
    silent = TRUE
  )

  if (
    !inherits(
      candidate,
      "try-error"
    ) &&
      inherits(
        candidate,
        "SpatRaster"
      )
  ) {
    return(
      candidate
    )
  }

  stop(
    "Could not convert object to terra::SpatRaster."
  )
}


set_pc_names <- function(x) {

  x <- as.matrix(x)
  storage.mode(x) <- "double"

  if (ncol(x) != 3L) {
    stop(
      "Expected exactly three PC columns."
    )
  }

  if (
    nrow(x) < 1L ||
      any(
        !is.finite(
          x
        )
      )
  ) {
    stop(
      "PC matrix contains no rows or non-finite values."
    )
  }

  colnames(x) <- c(
    "PC1",
    "PC2",
    "PC3"
  )

  x
}


safe_fraction <- function(
    numerator,
    denominator
) {

  if (
    !is.finite(
      denominator
    ) ||
      denominator <= 0
  ) {
    return(
      NA_real_
    )
  }

  numerator /
    denominator
}


euclidean_distance <- function(
    a,
    b
) {

  a <- as.numeric(a)
  b <- as.numeric(b)

  if (
    length(a) !=
      length(b) ||
      any(
        !is.finite(
          c(
            a,
            b
          )
        )
      )
  ) {
    return(
      NA_real_
    )
  }

  sqrt(
    sum(
      (
        a -
          b
      )^2
    )
  )
}


equivalent_sphere_radius <- function(volume) {

  if (
    !is.finite(
      volume
    ) ||
      volume <= 0
  ) {
    return(
      NA_real_
    )
  }

  (
    3 *
      volume /
      (
        4 *
          pi
      )
  )^(
    1 /
      3
  )
}


ellipsoid_volume <- function(
    axis_scales,
    radius
) {

  axis_scales <- as.numeric(
    axis_scales
  )

  radius <- as.numeric(
    radius
  )

  if (
    length(
      axis_scales
    ) != 3L ||
      any(
        !is.finite(
          axis_scales
        )
      ) ||
      any(
        axis_scales <= 0
      ) ||
      length(
        radius
      ) != 1L ||
      !is.finite(
        radius
      ) ||
      radius <= 0
  ) {
    stop(
      "Invalid ellipsoid scales or radius."
    )
  }

  4 /
    3 *
    pi *
    prod(
      axis_scales
    ) *
    radius^3
}


gaussian_log_score <- function(
    points,
    means,
    sds
) {

  points <- set_pc_names(
    points
  )

  means <- as.numeric(
    means
  )

  sds <- as.numeric(
    sds
  )

  output <- rep(
    0,
    nrow(
      points
    )
  )

  for (
    dimension_index in seq_len(
      3L
    )
  ) {

    output <- output +
      stats::dnorm(
        points[
          ,
          dimension_index
        ],
        mean = means[[
          dimension_index
        ]],
        sd = sds[[
          dimension_index
        ]],
        log = TRUE
      )
  }

  output
}


weighted_geographic_centroid <- function(
    mask,
    weights,
    xy
) {

  keep <- (
    mask &
      is.finite(
        weights
      ) &
      weights > 0
  )

  if (!any(keep)) {
    return(
      c(
        lon = NA_real_,
        lat = NA_real_
      )
    )
  }

  total_weight <- sum(
    weights[
      keep
    ]
  )

  c(
    lon = sum(
      xy[
        keep,
        1L
      ] *
        weights[
          keep
        ]
    ) /
      total_weight,
    lat = sum(
      xy[
        keep,
        2L
      ] *
        weights[
          keep
        ]
    ) /
      total_weight
  )
}


haversine_km <- function(
    lon1,
    lat1,
    lon2,
    lat2
) {

  if (
    any(
      !is.finite(
        c(
          lon1,
          lat1,
          lon2,
          lat2
        )
      )
    )
  ) {
    return(
      NA_real_
    )
  }

  rad <- pi / 180

  dlon <- (
    lon2 -
      lon1
  ) *
    rad

  dlat <- (
    lat2 -
      lat1
  ) *
    rad

  a <- (
    sin(
      dlat /
        2
    )^2 +
      cos(
        lat1 *
          rad
      ) *
        cos(
          lat2 *
            rad
        ) *
        sin(
          dlon /
            2
        )^2
  )

  6371.0088 *
    2 *
    atan2(
      sqrt(
        a
      ),
      sqrt(
        pmax(
          0,
          1 -
            a
        )
      )
    )
}


count_components <- function(binary_raster) {

  occupied <- binary_raster

  occupied[
    occupied == 0
  ] <- NA

  values <- terra::values(
    occupied,
    mat = FALSE
  )

  if (
    !any(
      values == 1,
      na.rm = TRUE
    )
  ) {
    return(
      0L
    )
  }

  patch_raster <- terra::patches(
    occupied,
    directions = 8
  )

  maximum_patch <- terra::global(
    patch_raster,
    "max",
    na.rm = TRUE
  )[
    1L,
    1L
  ]

  if (!is.finite(maximum_patch)) {
    return(
      0L
    )
  }

  as.integer(
    maximum_patch
  )
}


make_binary_raster <- function(
    template,
    valid_cells,
    prediction_valid
) {

  output <- template

  values <- rep(
    NA_real_,
    terra::ncell(
      template
    )
  )

  values[
    valid_cells
  ] <- as.numeric(
    prediction_valid
  )

  terra::values(
    output
  ) <- values

  names(
    output
  ) <- "presence"

  output
}


pc_centroid <- function(
    pc_matrix,
    mask
) {

  pc_matrix <- set_pc_names(
    pc_matrix
  )

  mask <- as.logical(
    mask
  )

  if (
    length(
      mask
    ) != nrow(
      pc_matrix
    ) ||
      !any(
        mask
      )
  ) {
    return(
      c(
        PC1 = NA_real_,
        PC2 = NA_real_,
        PC3 = NA_real_
      )
    )
  }

  colMeans(
    pc_matrix[
      mask,
      ,
      drop = FALSE
    ]
  )
}


species_code <- function(species_name) {

  switch(
    species_name,
    "Unimodal" = "unimodal",
    "Disconnected" = "disconnected",
    stop(
      "Unknown species: ",
      species_name
    )
  )
}


condition_id_for <- function(
    species_name,
    condition_code
) {

  paste(
    species_code(
      species_name
    ),
    paste0(
      "n",
      analysis_sample_size
    ),
    "qph",
    condition_code,
    sep = "__"
  )
}


baseline_model_file <- function(species_name) {

  file.path(
    baseline_fit_directory,
    "model_objects",
    paste0(
      species_code(
        species_name
      ),
      "__n",
      analysis_sample_size,
      "__qph.rds"
    )
  )
}


baseline_projection_file <- function(species_name) {

  file.path(
    geographic_directory,
    "projection_rasters",
    paste0(
      species_code(
        species_name
      ),
      "__n",
      analysis_sample_size,
      "__qph__geographic_projection.tif"
    )
  )
}


sensitivity_model_file <- function(
    species_name,
    condition_code
) {

  file.path(
    model_object_directory,
    paste0(
      condition_id_for(
        species_name,
        condition_code
      ),
      ".rds"
    )
  )
}


sensitivity_projection_file <- function(
    species_name,
    condition_code
) {

  file.path(
    projection_raster_directory,
    paste0(
      condition_id_for(
        species_name,
        condition_code
      ),
      "__geographic_projection.tif"
    )
  )
}


# ============================================================
# Load upstream revised objects
# ============================================================

locked_inputs <- readRDS(
  locked_master_file
)

locked_settings <- readRDS(
  locked_settings_file
)

baseline_settings_wrapper <- readRDS(
  baseline_settings_file
)

baseline_results <- readRDS(
  baseline_results_file
)

geometry_results <- readRDS(
  geometry_results_file
)

locked_design_hash <- locked_settings$locked_design_hash
baseline_settings <- baseline_settings_wrapper$settings
baseline_analysis_hash <- baseline_settings_wrapper$analysis_settings_hash

if (
  is.null(
    locked_design_hash
  ) ||
    is.null(
      baseline_analysis_hash
    )
) {
  stop(
    "Could not recover required upstream hashes."
  )
}

if (
  !identical(
    baseline_settings$locked_design_hash,
    locked_design_hash
  )
) {
  stop(
    "Script-13 baseline settings do not match the current Script-12 inputs."
  )
}

if (
  !identical(
    baseline_results$metadata$analysis_settings_hash,
    baseline_analysis_hash
  )
) {
  stop(
    "Script-13 result/settings hash mismatch."
  )
}

if (
  !identical(
    geometry_results$metadata$baseline_analysis_hash,
    baseline_analysis_hash
  )
) {
  stop(
    "Script-14 geometry object does not correspond to the current Script-13 baseline."
  )
}

if (
  !identical(
    as.character(
      baseline_settings$qph$bandwidth
    ),
    "sqrtNB"
  ) ||
    !isTRUE(
      all.equal(
        as.numeric(
          baseline_settings$qph$q
        ),
        baseline_q,
        tolerance = 1e-12
      )
    ) ||
    as.integer(
      baseline_settings$qph$samples_per_point
    ) !=
      baseline_samples_per_point ||
    as.numeric(
      baseline_settings$qph$sd_count
    ) !=
      baseline_sd_count
) {
  stop(
    "Script-13 QPH baseline does not match the locked revised sensitivity baseline."
  )
}


# ============================================================
# Shared Australian environmental landscape
# ============================================================

pc_stack <- as_spatraster_safe(
  locked_inputs$shared_environment$pc_stack
)

names(
  pc_stack
) <- c(
  "PC1",
  "PC2",
  "PC3"
)

pc_values_full <- terra::values(
  pc_stack,
  mat = TRUE
)

valid_pc_mask <- stats::complete.cases(
  pc_values_full
)

valid_pc_cells <- which(
  valid_pc_mask
)

landscape_pc <- set_pc_names(
  pc_values_full[
    valid_pc_cells,
    ,
    drop = FALSE
  ]
)

if (
  nrow(
    landscape_pc
  ) < 1L
) {
  stop(
    "No valid Australian PC1-PC3 cells are available."
  )
}

cell_area_raster <- terra::cellSize(
  pc_stack[[1L]],
  unit = "km"
)

cell_area_all <- terra::values(
  cell_area_raster,
  mat = FALSE
)

cell_area_valid <- cell_area_all[
  valid_pc_cells
]

xy_all <- terra::xyFromCell(
  pc_stack[[1L]],
  seq_len(
    terra::ncell(
      pc_stack[[1L]]
    )
  )
)


# ============================================================
# Locked species objects
# ============================================================

truth_rasters <- list(
  Unimodal = as_spatraster_safe(
    locked_inputs$truth$Unimodal$truth_raster
  ),
  Disconnected = as_spatraster_safe(
    locked_inputs$truth$Disconnected$truth_raster
  )
)

disconnected_mode_raster <- as_spatraster_safe(
  locked_inputs$truth$Disconnected$mode_membership_raster
)

occurrence_objects <- list(
  Unimodal = locked_inputs$occurrences$species$Unimodal$subsets[[
    as.character(
      analysis_sample_size
    )
  ]],
  Disconnected = locked_inputs$occurrences$species$Disconnected$subsets[[
    as.character(
      analysis_sample_size
    )
  ]]
)

for (
  species_name in species_order
) {

  occurrence_points <- set_pc_names(
    occurrence_objects[[
      species_name
    ]]$pc
  )

  if (
    nrow(
      occurrence_points
    ) !=
      analysis_sample_size
  ) {
    stop(
      species_name,
      " does not have exactly 900 locked occurrence points."
    )
  }
}


# ============================================================
# Build the UNIQUE 8-condition OFAT design
# ============================================================

unique_condition_template <- data.frame(
  Condition_code = c(
    "baseline",
    "bandwidth_0p75",
    "bandwidth_1p25",
    "q_0p950",
    "q_0p975",
    "spp_25",
    "spp_50",
    "spp_150"
  ),
  Sensitivity_family = c(
    "Baseline",
    "Bandwidth",
    "Bandwidth",
    "q",
    "q",
    "Samples_per_point",
    "Samples_per_point",
    "Samples_per_point"
  ),
  Bandwidth_multiplier = c(
    1.00,
    0.75,
    1.25,
    1.00,
    1.00,
    1.00,
    1.00,
    1.00
  ),
  q = c(
    0.99,
    0.99,
    0.99,
    0.950,
    0.975,
    0.99,
    0.99,
    0.99
  ),
  Samples_per_point = c(
    100L,
    100L,
    100L,
    100L,
    100L,
    25L,
    50L,
    150L
  ),
  Is_baseline = c(
    TRUE,
    FALSE,
    FALSE,
    FALSE,
    FALSE,
    FALSE,
    FALSE,
    FALSE
  ),
  Requires_new_fit = c(
    FALSE,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    TRUE
  ),
  stringsAsFactors = FALSE
)

design_rows <- list()
design_index <- 0L

for (
  species_name in species_order
) {

  baseline_file <- baseline_model_file(
    species_name
  )

  if (!file.exists(baseline_file)) {
    stop(
      "Missing Script-13 n=900 baseline QPH model:\n  ",
      baseline_file
    )
  }

  baseline_fit <- readRDS(
    baseline_file
  )

  if (
    !isTRUE(
      baseline_fit$success
    ) ||
      is.null(
        baseline_fit$qph_result
      )
  ) {
    stop(
      "Script-13 baseline QPH fit is unavailable for ",
      species_name,
      "."
    )
  }

  baseline_seed <- as.integer(
    baseline_fit$qph_result$audit$sampling_seed
  )

  for (
    condition_index in seq_len(
      nrow(
        unique_condition_template
      )
    )
  ) {

    row <- unique_condition_template[
      condition_index,
      ,
      drop = FALSE
    ]

    design_index <- (
      design_index +
        1L
    )

    design_rows[[
      design_index
    ]] <- data.frame(
      Condition_id = condition_id_for(
        species_name,
        row$Condition_code[[1L]]
      ),
      Virtual_species = species_name,
      Species_label = unname(
        species_labels[
          species_name
        ]
      ),
      Sample_size = analysis_sample_size,
      Condition_code = row$Condition_code[[1L]],
      Sensitivity_family = row$Sensitivity_family[[1L]],
      Bandwidth_multiplier = row$Bandwidth_multiplier[[1L]],
      q = row$q[[1L]],
      Samples_per_point = row$Samples_per_point[[1L]],
      SD_count = baseline_sd_count,
      Sampling_seed = baseline_seed,
      Is_baseline = row$Is_baseline[[1L]],
      Requires_new_fit = row$Requires_new_fit[[1L]],
      stringsAsFactors = FALSE
    )
  }
}

sensitivity_design <- do.call(
  rbind,
  design_rows
)

rownames(
  sensitivity_design
) <- NULL

if (
  nrow(
    sensitivity_design
  ) != 16L ||
    sum(
      sensitivity_design$Requires_new_fit
    ) != 14L
) {
  stop(
    "Sensitivity design must contain 16 unique conditions and 14 new fits."
  )
}

write_csv_safely(
  sensitivity_design,
  sensitivity_design_file
)


# ============================================================
# Verify baseline QPH bandwidth information
# ============================================================

bandwidth_info_by_species <- list()
baseline_qa_rows <- list()

for (
  species_name in species_order
) {

  occurrence_points <- set_pc_names(
    occurrence_objects[[
      species_name
    ]]$pc
  )

  baseline_file <- baseline_model_file(
    species_name
  )

  baseline_fit <- readRDS(
    baseline_file
  )

  saved_info <- baseline_fit$qph_result$bandwidth_info

  validate_qph_bandwidth_info(
    saved_info,
    occurrence_points
  )

  independently_estimated <- estimate_qph_sqrt_nb_bandwidth(
    occurrence_points
  )

  independent_matches_saved <- isTRUE(
    all.equal(
      as.numeric(
        independently_estimated$bandwidth
      ),
      as.numeric(
        saved_info$bandwidth
      ),
      tolerance = 1e-12
    )
  ) &&
    isTRUE(
      all.equal(
        independently_estimated$mean_s,
        saved_info$mean_s,
        tolerance = 1e-12
      )
    ) &&
    identical(
      as.integer(
        independently_estimated$k
      ),
      as.integer(
        saved_info$k
      )
    )

  if (!independent_matches_saved) {
    stop(
      "Recomputed sqrt-NB bandwidth does not match Script-13 baseline for ",
      species_name,
      "."
    )
  }

  if (
    !isTRUE(
      all.equal(
        as.numeric(
          baseline_fit$qph_result$bandwidth
        ),
        as.numeric(
          saved_info$bandwidth
        ),
        tolerance = 1e-12
      )
    ) ||
      !isTRUE(
        all.equal(
          baseline_fit$qph_result$audit$q,
          baseline_q,
          tolerance = 1e-12
        )
      ) ||
      baseline_fit$qph_result$audit$samples_per_point !=
        baseline_samples_per_point
  ) {
    stop(
      "Script-13 baseline QPH fit does not match the locked baseline for ",
      species_name,
      "."
    )
  }

  bandwidth_info_by_species[[
    species_name
  ]] <- saved_info

  baseline_projection <- baseline_projection_file(
    species_name
  )

  if (!file.exists(baseline_projection)) {
    stop(
      "Missing Script-13 baseline QPH projection:\n  ",
      baseline_projection
    )
  }

  baseline_qa_rows[[
    species_name
  ]] <- data.frame(
    Virtual_species = species_name,
    Baseline_model_file = normalizePath(
      baseline_file,
      winslash = "/",
      mustWork = TRUE
    ),
    Baseline_model_MD5 = safe_md5(
      baseline_file
    ),
    Baseline_projection_file = normalizePath(
      baseline_projection,
      winslash = "/",
      mustWork = TRUE
    ),
    Baseline_projection_MD5 = safe_md5(
      baseline_projection
    ),
    n = baseline_fit$qph_result$audit$n,
    d = baseline_fit$qph_result$audit$d,
    K = baseline_fit$qph_result$audit$K,
    Mean_s = baseline_fit$qph_result$audit$mean_s,
    Baseline_scalar_h = baseline_fit$qph_result$audit$baseline_scalar_h,
    q = baseline_fit$qph_result$audit$q,
    Samples_per_point = baseline_fit$qph_result$audit$samples_per_point,
    Sampling_seed = baseline_fit$qph_result$audit$sampling_seed,
    Independent_bandwidth_recalculation_matches = independent_matches_saved,
    stringsAsFactors = FALSE
  )
}

baseline_qa <- do.call(
  rbind,
  baseline_qa_rows
)

rownames(
  baseline_qa
) <- NULL

write_csv_safely(
  baseline_qa,
  baseline_qa_file
)


# ============================================================
# Analysis settings and checkpoint compatibility
# ============================================================

baseline_model_md5 <- stats::setNames(
  vapply(
    species_order,
    function(species_name) {
      safe_md5(
        baseline_model_file(
          species_name
        )
      )
    },
    character(1)
  ),
  species_order
)

analysis_settings <- list(
  script = "16_Virtual_Species_QPH_Sensitivity_n900.R",
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  qph_core_version = QPH_CORE_VERSION,
  qph_core_md5 = qph_core_md5,
  baseline_model_md5 = baseline_model_md5,
  species = species_order,
  sample_size = analysis_sample_size,
  design = unique_condition_template,
  baseline = list(
    bandwidth_multiplier = baseline_bandwidth_multiplier,
    q = baseline_q,
    samples_per_point = baseline_samples_per_point,
    sd_count = baseline_sd_count
  ),
  sensitivity = list(
    bandwidth_multipliers = bandwidth_multipliers,
    q_levels = q_levels,
    samples_per_point_levels = samples_per_point_levels,
    design_type = "OFAT"
  ),
  stochastic_rule = paste(
    "All sensitivity fits within a species reuse the Script-13 baseline",
    "QPH sampling seed."
  ),
  batching = list(
    shared_chunk_size = shared_chunk_size,
    potential_batch_size = potential_batch_size,
    projection_batch_size = projection_batch_size
  ),
  topology_sensitivity = FALSE
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

if (
  file.exists(
    analysis_settings_file
  )
) {

  previous <- readRDS(
    analysis_settings_file
  )

  if (
    !identical(
      previous$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Existing Script-16 outputs were created under incompatible settings.\n",
      "Archive or remove 05_QPH_Sensitivity before running this design."
    )
  }
}

saveRDS(
  list(
    analysis_settings_hash = analysis_settings_hash,
    settings = analysis_settings
  ),
  analysis_settings_file,
  version = 3
)


# ============================================================
# Model fitting registry
# ============================================================

empty_model_registry <- function() {

  data.frame(
    Condition_id = character(0),
    Virtual_species = character(0),
    Condition_code = character(0),
    Success = logical(0),
    Reused_baseline = logical(0),
    Object_file = character(0),
    Runtime_seconds = numeric(0),
    Hypervolume_volume = numeric(0),
    Random_points = integer(0),
    Error_message = character(0),
    stringsAsFactors = FALSE
  )
}


if (
  resume_model_fits &&
    file.exists(
      model_registry_file
    )
) {

  checkpoint <- readRDS(
    model_registry_file
  )

  if (
    !identical(
      checkpoint$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Incompatible Script-16 model checkpoint."
    )
  }

  model_registry <- checkpoint$registry

} else {

  model_registry <- empty_model_registry()
}


save_model_checkpoint <- function() {

  saveRDS(
    list(
      analysis_settings_hash = analysis_settings_hash,
      registry = model_registry
    ),
    model_registry_file,
    version = 3
  )
}


replace_model_registry_row <- function(new_row) {

  keep <- (
    model_registry$Condition_id !=
      new_row$Condition_id[[1L]]
  )

  model_registry <<- rbind(
    model_registry[
      keep,
      ,
      drop = FALSE
    ],
    new_row
  )

  rownames(
    model_registry
  ) <<- NULL
}


get_model_registry_row <- function(condition_id) {

  rows <- model_registry[
    model_registry$Condition_id ==
      condition_id,
    ,
    drop = FALSE
  ]

  if (nrow(rows) == 0L) {
    return(
      NULL
    )
  }

  if (nrow(rows) != 1L) {
    stop(
      "Duplicate model-registry condition: ",
      condition_id
    )
  }

  rows
}


fit_new_sensitivity_qph <- function(
    occurrence_points,
    bandwidth_info,
    bandwidth_multiplier,
    q,
    samples_per_point,
    sampling_seed,
    species_name,
    condition_code
) {

  occurrence_points <- set_pc_names(
    occurrence_points
  )

  fitted_bandwidth <- (
    as.numeric(
      bandwidth_info$bandwidth
    ) *
      as.numeric(
        bandwidth_multiplier
      )
  )

  start_time <- proc.time()[[
    "elapsed"
  ]]

  fit <- tryCatch(
    {

      result <- construct_qph(
        data = occurrence_points,
        bandwidth = fitted_bandwidth,
        bandwidth_info = bandwidth_info,
        name = paste0(
          species_name,
          " virtual species QPH sensitivity ",
          condition_code
        ),
        samples_per_point = as.integer(
          samples_per_point
        ),
        sd_count = baseline_sd_count,
        q = as.numeric(
          q
        ),
        sampling_seed = as.integer(
          sampling_seed
        ),
        sampling_chunk_size = shared_chunk_size,
        potential_batch_size = potential_batch_size,
        verbose = verbose_qph
      )

      list(
        success = TRUE,
        hypervolume = result$hypervolume,
        qph_result = result,
        error_message = NA_character_
      )
    },
    error = function(error_condition) {

      list(
        success = FALSE,
        hypervolume = NULL,
        qph_result = NULL,
        error_message = conditionMessage(
          error_condition
        )
      )
    }
  )

  fit$runtime_seconds <- (
    proc.time()[[
      "elapsed"
    ]] -
      start_time
  )

  fit$analysis_settings_hash <- analysis_settings_hash
  fit$qph_core_version <- QPH_CORE_VERSION
  fit$species <- species_name
  fit$condition_code <- condition_code
  fit$bandwidth_multiplier <- bandwidth_multiplier
  fit$q <- q
  fit$samples_per_point <- samples_per_point
  fit$sampling_seed <- sampling_seed

  fit
}


for (
  design_index in seq_len(
    nrow(
      sensitivity_design
    )
  )
) {

  condition <- sensitivity_design[
    design_index,
    ,
    drop = FALSE
  ]

  condition_id <- condition$Condition_id[[1L]]
  species_name <- condition$Virtual_species[[1L]]
  condition_code <- condition$Condition_code[[1L]]

  existing <- get_model_registry_row(
    condition_id
  )

  if (isTRUE(condition$Is_baseline[[1L]])) {

    source_file <- baseline_model_file(
      species_name
    )

    fit <- readRDS(
      source_file
    )

    if (
      !isTRUE(
        fit$success
      ) ||
        is.null(
          fit$qph_result
        )
    ) {
      stop(
        "Baseline QPH object is unavailable for ",
        species_name,
        "."
      )
    }

    registry_row <- data.frame(
      Condition_id = condition_id,
      Virtual_species = species_name,
      Condition_code = condition_code,
      Success = TRUE,
      Reused_baseline = TRUE,
      Object_file = normalizePath(
        source_file,
        winslash = "/",
        mustWork = TRUE
      ),
      Runtime_seconds = fit$full_fit_runtime_seconds,
      Hypervolume_volume = as.numeric(
        fit$hypervolume@Volume
      ),
      Random_points = nrow(
        fit$hypervolume@RandomPoints
      ),
      Error_message = NA_character_,
      stringsAsFactors = FALSE
    )

    replace_model_registry_row(
      registry_row
    )

    save_model_checkpoint()

    next
  }

  object_file <- sensitivity_model_file(
    species_name,
    condition_code
  )

  if (
    !is.null(
      existing
    ) &&
      isTRUE(
        existing$Success[[1L]]
      ) &&
      file.exists(
        object_file
      )
  ) {

    message(
      "Reusing successful QPH sensitivity fit ",
      design_index,
      "/",
      nrow(
        sensitivity_design
      ),
      ": ",
      condition_id
    )

    next
  }

  if (
    !is.null(
      existing
    ) &&
      !isTRUE(
        existing$Success[[1L]]
      ) &&
      !retry_failed_model_fits
  ) {
    next
  }

  occurrence_points <- set_pc_names(
    occurrence_objects[[
      species_name
    ]]$pc
  )

  bandwidth_info <- bandwidth_info_by_species[[
    species_name
  ]]

  message(
    "Fitting QPH sensitivity ",
    design_index,
    "/",
    nrow(
      sensitivity_design
    ),
    ": ",
    condition_id
  )

  fit <- fit_new_sensitivity_qph(
    occurrence_points = occurrence_points,
    bandwidth_info = bandwidth_info,
    bandwidth_multiplier = condition$Bandwidth_multiplier[[1L]],
    q = condition$q[[1L]],
    samples_per_point = condition$Samples_per_point[[1L]],
    sampling_seed = condition$Sampling_seed[[1L]],
    species_name = species_name,
    condition_code = condition_code
  )

  if (isTRUE(fit$success)) {

    saveRDS(
      fit,
      object_file,
      version = 3
    )
  }

  registry_row <- data.frame(
    Condition_id = condition_id,
    Virtual_species = species_name,
    Condition_code = condition_code,
    Success = isTRUE(
      fit$success
    ),
    Reused_baseline = FALSE,
    Object_file = if (
      isTRUE(
        fit$success
      )
    ) {
      normalizePath(
        object_file,
        winslash = "/",
        mustWork = TRUE
      )
    } else {
      NA_character_
    },
    Runtime_seconds = fit$runtime_seconds,
    Hypervolume_volume = if (
      isTRUE(
        fit$success
      )
    ) {
      as.numeric(
        fit$hypervolume@Volume
      )
    } else {
      NA_real_
    },
    Random_points = if (
      isTRUE(
        fit$success
      )
    ) {
      nrow(
        fit$hypervolume@RandomPoints
      )
    } else {
      NA_integer_
    },
    Error_message = fit$error_message,
    stringsAsFactors = FALSE
  )

  replace_model_registry_row(
    registry_row
  )

  save_model_checkpoint()
}


# Ensure registry follows design order.
model_registry <- model_registry[
  match(
    sensitivity_design$Condition_id,
    model_registry$Condition_id
  ),
  ,
  drop = FALSE
]

save_model_checkpoint()


# ============================================================
# Relocation-safe fit loader
# ============================================================

load_condition_fit <- function(
    species_name,
    condition_code
) {

  if (
    identical(
      condition_code,
      "baseline"
    )
  ) {

    file <- baseline_model_file(
      species_name
    )

  } else {

    file <- sensitivity_model_file(
      species_name,
      condition_code
    )
  }

  if (!file.exists(file)) {
    stop(
      "Missing QPH sensitivity model object:\n  ",
      file
    )
  }

  fit <- readRDS(
    file
  )

  if (
    !isTRUE(
      fit$success
    )
  ) {
    stop(
      "Requested QPH sensitivity fit was not successful: ",
      species_name,
      " / ",
      condition_code,
      "."
    )
  }

  if (
    !identical(
      condition_code,
      "baseline"
    ) &&
      !identical(
        fit$analysis_settings_hash,
        analysis_settings_hash
      )
  ) {
    stop(
      "Sensitivity fit hash mismatch: ",
      species_name,
      " / ",
      condition_code,
      "."
    )
  }

  fit
}


# ============================================================
# QPH audit outputs
# ============================================================

audit_rows <- list()
audit_index <- 0L
local_s_rows <- list()
local_s_index <- 0L

for (
  design_index in seq_len(
    nrow(
      sensitivity_design
    )
  )
) {

  condition <- sensitivity_design[
    design_index,
    ,
    drop = FALSE
  ]

  registry_row <- get_model_registry_row(
    condition$Condition_id[[1L]]
  )

  if (
    is.null(
      registry_row
    ) ||
      !isTRUE(
        registry_row$Success[[1L]]
      )
  ) {
    next
  }

  fit <- load_condition_fit(
    condition$Virtual_species[[1L]],
    condition$Condition_code[[1L]]
  )

  audit <- fit$qph_result$audit

  fitted_bandwidth <- as.numeric(
    audit$fitted_bandwidth
  )

  audit_index <- (
    audit_index +
      1L
  )

  audit_rows[[
    audit_index
  ]] <- data.frame(
    Condition_id = condition$Condition_id[[1L]],
    Virtual_species = condition$Virtual_species[[1L]],
    Condition_code = condition$Condition_code[[1L]],
    Sensitivity_family = condition$Sensitivity_family[[1L]],
    Is_baseline = condition$Is_baseline[[1L]],
    n = audit$n,
    d = audit$d,
    K = audit$K,
    Mean_s = audit$mean_s,
    Baseline_scalar_h = audit$baseline_scalar_h,
    Bandwidth_multiplier = condition$Bandwidth_multiplier[[1L]],
    Fitted_bandwidth_PC1 = fitted_bandwidth[[1L]],
    Fitted_bandwidth_PC2 = fitted_bandwidth[[2L]],
    Fitted_bandwidth_PC3 = fitted_bandwidth[[3L]],
    Fitted_isotropic = audit$fitted_isotropic,
    q = audit$q,
    Samples_per_point = audit$samples_per_point,
    SD_count = audit$sd_count,
    Sampling_seed = audit$sampling_seed,
    Retained_fraction = fit$qph_result$retained_fraction,
    QPH_volume = fit$qph_result$qph_volume,
    Random_points = nrow(
      fit$hypervolume@RandomPoints
    ),
    Runtime_seconds = registry_row$Runtime_seconds[[1L]],
    stringsAsFactors = FALSE
  )

  for (
    occurrence_index in seq_along(
      audit$local_s
    )
  ) {

    local_s_index <- (
      local_s_index +
        1L
    )

    local_s_rows[[
      local_s_index
    ]] <- data.frame(
      Condition_id = condition$Condition_id[[1L]],
      Virtual_species = condition$Virtual_species[[1L]],
      Condition_code = condition$Condition_code[[1L]],
      Occurrence_index = occurrence_index,
      Local_s = audit$local_s[[
        occurrence_index
      ]],
      stringsAsFactors = FALSE
    )
  }
}

qph_audit_summary <- if (
  length(
    audit_rows
  ) > 0L
) {
  do.call(
    rbind,
    audit_rows
  )
} else {
  data.frame()
}

qph_local_s <- if (
  length(
    local_s_rows
  ) > 0L
) {
  do.call(
    rbind,
    local_s_rows
  )
} else {
  data.frame()
}

write_csv_safely(
  qph_audit_summary,
  qph_audit_summary_file
)

write_csv_safely(
  qph_local_s,
  qph_local_s_file
)


# ============================================================
# QPH geographic projection helper
# ============================================================

project_qph_to_landscape <- function(
    evaluation_points,
    occurrence_points,
    bandwidth,
    potential_threshold_raw,
    sd_count,
    batch_size
) {

  evaluation_points <- set_pc_names(
    evaluation_points
  )

  occurrence_points <- set_pc_names(
    occurrence_points
  )

  bandwidth <- as.numeric(
    bandwidth
  )

  occurrence_scaled <- sweep(
    occurrence_points,
    2L,
    bandwidth,
    FUN = "/"
  )

  occurrence_squared_norm <- rowSums(
    occurrence_scaled^2
  )

  prediction <- logical(
    nrow(
      evaluation_points
    )
  )

  inside_candidate_region <- logical(
    nrow(
      evaluation_points
    )
  )

  potential <- rep(
    NA_real_,
    nrow(
      evaluation_points
    )
  )

  for (
    start_index in seq.int(
      1L,
      nrow(
        evaluation_points
      ),
      by = batch_size
    )
  ) {

    end_index <- min(
      start_index +
        batch_size -
        1L,
      nrow(
        evaluation_points
      )
    )

    idx <- start_index:end_index

    evaluation_batch <- sweep(
      evaluation_points[
        idx,
        ,
        drop = FALSE
      ],
      2L,
      bandwidth,
      FUN = "/"
    )

    distance_squared <- outer(
      rowSums(
        evaluation_batch^2
      ),
      occurrence_squared_norm,
      FUN = "+"
    ) -
      2 *
        tcrossprod(
          evaluation_batch,
          occurrence_scaled
        )

    distance_squared[
      distance_squared < 0 &
        distance_squared >
          -1e-8
    ] <- 0

    if (
      any(
        distance_squared < 0
      )
    ) {
      stop(
        "Unexpected negative squared distances during QPH projection."
      )
    }

    row_minimum <- apply(
      distance_squared,
      1L,
      min
    )

    candidate <- (
      row_minimum <=
        sd_count^2
    )

    inside_candidate_region[
      idx
    ] <- candidate

    if (any(candidate)) {

      candidate_distance_squared <- distance_squared[
        candidate,
        ,
        drop = FALSE
      ]

      candidate_row_minimum <- row_minimum[
        candidate
      ]

      shifted_weights <- exp(
        -0.5 *
          sweep(
            candidate_distance_squared,
            1L,
            candidate_row_minimum,
            FUN = "-"
          )
      )

      shifted_sum <- rowSums(
        shifted_weights
      )

      candidate_potential <- (
        -ncol(
          occurrence_points
        ) /
          2 +
          0.5 *
            rowSums(
              shifted_weights *
                candidate_distance_squared
            ) /
            shifted_sum
      )

      global_indices <- idx[
        candidate
      ]

      potential[
        global_indices
      ] <- candidate_potential

      prediction[
        global_indices
      ] <- (
        candidate_potential <=
          potential_threshold_raw +
            projection_tolerance
      )
    }
  }

  list(
    prediction = prediction,
    inside_candidate_region = inside_candidate_region,
    potential = potential
  )
}


# ============================================================
# Projection checkpoint registry
# ============================================================

empty_projection_registry <- function() {

  data.frame(
    Condition_id = character(0),
    Virtual_species = character(0),
    Condition_code = character(0),
    Success = logical(0),
    Reused_baseline = logical(0),
    Raster_file = character(0),
    Runtime_seconds = numeric(0),
    Predicted_cells = integer(0),
    Candidate_cells = integer(0),
    Error_message = character(0),
    stringsAsFactors = FALSE
  )
}


if (
  resume_projections &&
    file.exists(
      projection_registry_file
    )
) {

  checkpoint <- readRDS(
    projection_registry_file
  )

  if (
    !identical(
      checkpoint$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Incompatible Script-16 projection checkpoint."
    )
  }

  projection_registry <- checkpoint$registry

} else {

  projection_registry <- empty_projection_registry()
}


save_projection_checkpoint <- function() {

  saveRDS(
    list(
      analysis_settings_hash = analysis_settings_hash,
      registry = projection_registry
    ),
    projection_registry_file,
    version = 3
  )
}


replace_projection_registry_row <- function(new_row) {

  keep <- (
    projection_registry$Condition_id !=
      new_row$Condition_id[[1L]]
  )

  projection_registry <<- rbind(
    projection_registry[
      keep,
      ,
      drop = FALSE
    ],
    new_row
  )

  rownames(
    projection_registry
  ) <<- NULL
}


get_projection_registry_row <- function(condition_id) {

  rows <- projection_registry[
    projection_registry$Condition_id ==
      condition_id,
    ,
    drop = FALSE
  ]

  if (nrow(rows) == 0L) {
    return(
      NULL
    )
  }

  if (nrow(rows) != 1L) {
    stop(
      "Duplicate projection-registry condition: ",
      condition_id
    )
  }

  rows
}


# ============================================================
# Geographic projections
# ============================================================

for (
  design_index in seq_len(
    nrow(
      sensitivity_design
    )
  )
) {

  condition <- sensitivity_design[
    design_index,
    ,
    drop = FALSE
  ]

  condition_id <- condition$Condition_id[[1L]]
  species_name <- condition$Virtual_species[[1L]]
  condition_code <- condition$Condition_code[[1L]]

  model_row <- get_model_registry_row(
    condition_id
  )

  if (
    is.null(
      model_row
    ) ||
      !isTRUE(
        model_row$Success[[1L]]
      )
  ) {

    replace_projection_registry_row(
      data.frame(
        Condition_id = condition_id,
        Virtual_species = species_name,
        Condition_code = condition_code,
        Success = FALSE,
        Reused_baseline = FALSE,
        Raster_file = NA_character_,
        Runtime_seconds = NA_real_,
        Predicted_cells = NA_integer_,
        Candidate_cells = NA_integer_,
        Error_message = "QPH model unavailable",
        stringsAsFactors = FALSE
      )
    )

    save_projection_checkpoint()

    next
  }

  if (isTRUE(condition$Is_baseline[[1L]])) {

    source_file <- baseline_projection_file(
      species_name
    )

    if (!file.exists(source_file)) {
      stop(
        "Missing Script-13 baseline QPH projection:\n  ",
        source_file
      )
    }

    baseline_raster <- terra::rast(
      source_file
    )

    baseline_values <- terra::values(
      baseline_raster,
      mat = FALSE
    )[
      valid_pc_cells
    ]

    replace_projection_registry_row(
      data.frame(
        Condition_id = condition_id,
        Virtual_species = species_name,
        Condition_code = condition_code,
        Success = TRUE,
        Reused_baseline = TRUE,
        Raster_file = normalizePath(
          source_file,
          winslash = "/",
          mustWork = TRUE
        ),
        Runtime_seconds = NA_real_,
        Predicted_cells = sum(
          baseline_values == 1,
          na.rm = TRUE
        ),
        Candidate_cells = NA_integer_,
        Error_message = NA_character_,
        stringsAsFactors = FALSE
      )
    )

    save_projection_checkpoint()

    next
  }

  output_file <- sensitivity_projection_file(
    species_name,
    condition_code
  )

  existing <- get_projection_registry_row(
    condition_id
  )

  if (
    !is.null(
      existing
    ) &&
      isTRUE(
        existing$Success[[1L]]
      ) &&
      file.exists(
        output_file
      )
  ) {

    message(
      "Reusing successful QPH projection ",
      design_index,
      "/",
      nrow(
        sensitivity_design
      ),
      ": ",
      condition_id
    )

    next
  }

  if (
    !is.null(
      existing
    ) &&
      !isTRUE(
        existing$Success[[1L]]
      ) &&
      !retry_failed_projections
  ) {
    next
  }

  fit <- load_condition_fit(
    species_name,
    condition_code
  )

  occurrence_points <- set_pc_names(
    occurrence_objects[[
      species_name
    ]]$pc
  )

  message(
    "Projecting QPH sensitivity ",
    design_index,
    "/",
    nrow(
      sensitivity_design
    ),
    ": ",
    condition_id
  )

  start_time <- proc.time()[[
    "elapsed"
  ]]

  projection <- tryCatch(
    {

      result <- project_qph_to_landscape(
        evaluation_points = landscape_pc,
        occurrence_points = occurrence_points,
        bandwidth = fit$qph_result$bandwidth,
        potential_threshold_raw = fit$qph_result$potential_threshold_raw,
        sd_count = baseline_sd_count,
        batch_size = projection_batch_size
      )

      list(
        success = TRUE,
        result = result,
        error_message = NA_character_
      )
    },
    error = function(error_condition) {

      list(
        success = FALSE,
        result = NULL,
        error_message = conditionMessage(
          error_condition
        )
      )
    }
  )

  runtime_seconds <- (
    proc.time()[[
      "elapsed"
    ]] -
      start_time
  )

  if (isTRUE(projection$success)) {

    prediction_raster <- make_binary_raster(
      template = pc_stack[[1L]],
      valid_cells = valid_pc_cells,
      prediction_valid = projection$result$prediction
    )

    terra::writeRaster(
      prediction_raster,
      output_file,
      overwrite = TRUE,
      datatype = "INT1U",
      wopt = list(
        gdal = c(
          "COMPRESS=LZW"
        )
      )
    )
  }

  replace_projection_registry_row(
    data.frame(
      Condition_id = condition_id,
      Virtual_species = species_name,
      Condition_code = condition_code,
      Success = isTRUE(
        projection$success
      ),
      Reused_baseline = FALSE,
      Raster_file = if (
        isTRUE(
          projection$success
        )
      ) {
        normalizePath(
          output_file,
          winslash = "/",
          mustWork = TRUE
        )
      } else {
        NA_character_
      },
      Runtime_seconds = runtime_seconds,
      Predicted_cells = if (
        isTRUE(
          projection$success
        )
      ) {
        sum(
          projection$result$prediction
        )
      } else {
        NA_integer_
      },
      Candidate_cells = if (
        isTRUE(
          projection$success
        )
      ) {
        sum(
          projection$result$inside_candidate_region
        )
      } else {
        NA_integer_
      },
      Error_message = projection$error_message,
      stringsAsFactors = FALSE
    )
  )

  save_projection_checkpoint()
}


projection_registry <- projection_registry[
  match(
    sensitivity_design$Condition_id,
    projection_registry$Condition_id
  ),
  ,
  drop = FALSE
]

save_projection_checkpoint()


get_condition_projection_file <- function(
    species_name,
    condition_code
) {

  if (
    identical(
      condition_code,
      "baseline"
    )
  ) {
    baseline_projection_file(
      species_name
    )
  } else {
    sensitivity_projection_file(
      species_name,
      condition_code
    )
  }
}


# ============================================================
# Continuous generating truth definitions
# ============================================================

unimodal_definition <- locked_inputs$truth$Unimodal$generating_definition

unimodal_means <- as.numeric(
  unimodal_definition$means
)

unimodal_sds <- as.numeric(
  unimodal_definition$sds
)

unimodal_truth_values <- terra::values(
  truth_rasters$Unimodal,
  mat = FALSE
)[
  valid_pc_cells
]

unimodal_landscape_log_score <- gaussian_log_score(
  landscape_pc,
  unimodal_means,
  unimodal_sds
)

unimodal_log_threshold <- min(
  unimodal_landscape_log_score[
    unimodal_truth_values == 1
  ],
  na.rm = TRUE
)

unimodal_log_peak <- sum(
  -log(
    sqrt(
      2 *
        pi
    ) *
      unimodal_sds
  )
)

unimodal_radius <- sqrt(
  max(
    0,
    2 *
      (
        unimodal_log_peak -
          unimodal_log_threshold
      )
  )
)

unimodal_true_volume <- ellipsoid_volume(
  unimodal_sds,
  unimodal_radius
)

unimodal_true_centroid <- unimodal_means


classify_unimodal_true <- function(points) {

  points <- set_pc_names(
    points
  )

  relative <- sweep(
    points,
    2L,
    unimodal_means,
    FUN = "-"
  )

  relative <- sweep(
    relative,
    2L,
    unimodal_sds,
    FUN = "/"
  )

  sqrt(
    rowSums(
      relative^2
    )
  ) <=
    (
      unimodal_radius +
        projection_tolerance
    )
}


disconnected_definition <- locked_inputs$truth$Disconnected$generating_definition

mode_A_mean <- as.numeric(
  disconnected_definition$mode_A_mean
)

mode_B_mean <- as.numeric(
  disconnected_definition$mode_B_mean
)

mode_sds <- as.numeric(
  disconnected_definition$mode_sds
)

disconnected_radius <- as.numeric(
  disconnected_definition$truth_radius_sd_units
)

disconnected_separation <- as.numeric(
  disconnected_definition$mode_separation_sd_units
)

disconnected_true_volume <- (
  2 *
    ellipsoid_volume(
      mode_sds,
      disconnected_radius
    )
)

disconnected_true_centroid <- (
  mode_A_mean +
    mode_B_mean
) /
  2

disconnected_gap_width <- (
  disconnected_separation -
    2 *
      disconnected_radius
)

if (
  !is.finite(
    disconnected_gap_width
  ) ||
    disconnected_gap_width <= 0
) {
  stop(
    "Disconnected generating definition does not contain a positive gap."
  )
}


classify_disconnected_true <- function(points) {

  points <- set_pc_names(
    points
  )

  scaled_points <- sweep(
    points,
    2L,
    mode_sds,
    FUN = "/"
  )

  centre_A_scaled <- (
    mode_A_mean /
      mode_sds
  )

  centre_B_scaled <- (
    mode_B_mean /
      mode_sds
  )

  distance_A <- sqrt(
    rowSums(
      sweep(
        scaled_points,
        2L,
        centre_A_scaled,
        FUN = "-"
      )^2
    )
  )

  distance_B <- sqrt(
    rowSums(
      sweep(
        scaled_points,
        2L,
        centre_B_scaled,
        FUN = "-"
      )^2
    )
  )

  (
    distance_A <=
      disconnected_radius +
        projection_tolerance
  ) |
    (
      distance_B <=
        disconnected_radius +
          projection_tolerance
    )
}


classify_disconnected_gap <- function(points) {

  points <- set_pc_names(
    points
  )

  scaled_points <- sweep(
    points,
    2L,
    mode_sds,
    FUN = "/"
  )

  centre_A_scaled <- (
    mode_A_mean /
      mode_sds
  )

  centre_B_scaled <- (
    mode_B_mean /
      mode_sds
  )

  line_vector <- (
    centre_B_scaled -
      centre_A_scaled
  )

  line_length_squared <- sum(
    line_vector^2
  )

  relative <- sweep(
    scaled_points,
    2L,
    centre_A_scaled,
    FUN = "-"
  )

  t_value <- as.numeric(
    relative %*%
      line_vector
  ) /
    line_length_squared

  projection <- sweep(
    t_value %o%
      line_vector,
    2L,
    centre_A_scaled,
    FUN = "+"
  )

  perpendicular_distance <- sqrt(
    rowSums(
      (
        scaled_points -
          projection
      )^2
    )
  )

  inside_true <- classify_disconnected_true(
    points
  )

  t_margin <- (
    disconnected_radius /
      disconnected_separation
  )

  (
    !inside_true &
      t_value >
        t_margin &
      t_value <
        (
          1 -
            t_margin
        ) &
      perpendicular_distance <=
        disconnected_radius *
          gap_corridor_radius_multiplier
  )
}


disconnected_gap_volume <- (
  pi *
    (
      disconnected_radius *
        gap_corridor_radius_multiplier
    )^2 *
    disconnected_gap_width *
    prod(
      mode_sds
    )
)


truth_definitions <- list(
  Unimodal = list(
    true_volume = unimodal_true_volume,
    true_centroid = unimodal_true_centroid,
    classify_true = classify_unimodal_true
  ),
  Disconnected = list(
    true_volume = disconnected_true_volume,
    true_centroid = disconnected_true_centroid,
    classify_true = classify_disconnected_true
  )
)


# ============================================================
# Geographic truth metrics helper
# ============================================================

calculate_geographic_metrics <- function(
    truth_raster,
    prediction_raster,
    occurrence_xy,
    species_name,
    condition_id
) {

  truth_values <- terra::values(
    truth_raster,
    mat = FALSE
  )

  prediction_values <- terra::values(
    prediction_raster,
    mat = FALSE
  )

  valid <- (
    is.finite(
      truth_values
    ) &
      is.finite(
        prediction_values
      ) &
      is.finite(
        cell_area_all
      ) &
      cell_area_all > 0
  )

  truth <- (
    truth_values == 1
  )

  prediction <- (
    prediction_values == 1
  )

  tp <- (
    valid &
      truth &
      prediction
  )

  fp <- (
    valid &
      !truth &
      prediction
  )

  fn <- (
    valid &
      truth &
      !prediction
  )

  tn <- (
    valid &
      !truth &
      !prediction
  )

  tp_area <- sum(
    cell_area_all[
      tp
    ]
  )

  fp_area <- sum(
    cell_area_all[
      fp
    ]
  )

  fn_area <- sum(
    cell_area_all[
      fn
    ]
  )

  tn_area <- sum(
    cell_area_all[
      tn
    ]
  )

  true_area <- (
    tp_area +
      fn_area
  )

  predicted_area <- (
    tp_area +
      fp_area
  )

  sampled_cells <- unique(
    terra::cellFromXY(
      truth_raster,
      as.matrix(
        occurrence_xy
      )
    )
  )

  sampled_cells <- sampled_cells[
    is.finite(
      sampled_cells
    )
  ]

  sampled_mask <- (
    seq_len(
      terra::ncell(
        truth_raster
      )
    ) %in%
      sampled_cells
  )

  unsampled_true <- (
    valid &
      truth &
      !sampled_mask
  )

  sampled_true <- (
    valid &
      truth &
      sampled_mask
  )

  truth_centroid <- weighted_geographic_centroid(
    truth &
      valid,
    cell_area_all,
    xy_all
  )

  prediction_centroid <- weighted_geographic_centroid(
    prediction &
      valid,
    cell_area_all,
    xy_all
  )

  data.frame(
    Condition_id = condition_id,
    Virtual_species = species_name,
    Jaccard_area_weighted = safe_fraction(
      tp_area,
      tp_area +
        fp_area +
        fn_area
    ),
    Sorensen_area_weighted = safe_fraction(
      2 *
        tp_area,
      2 *
        tp_area +
        fp_area +
        fn_area
    ),
    Omission_error_area_weighted = safe_fraction(
      fn_area,
      true_area
    ),
    Commission_error_area_weighted = safe_fraction(
      fp_area,
      predicted_area
    ),
    Sensitivity_area_weighted = safe_fraction(
      tp_area,
      true_area
    ),
    Specificity_area_weighted = safe_fraction(
      tn_area,
      tn_area +
        fp_area
    ),
    Precision_area_weighted = safe_fraction(
      tp_area,
      predicted_area
    ),
    Balanced_accuracy_area_weighted = mean(
      c(
        safe_fraction(
          tp_area,
          true_area
        ),
        safe_fraction(
          tn_area,
          tn_area +
            fp_area
        )
      ),
      na.rm = TRUE
    ),
    True_area_km2 = true_area,
    Predicted_area_km2 = predicted_area,
    Relative_geographic_area_error = safe_fraction(
      predicted_area -
        true_area,
      true_area
    ),
    Geographic_centroid_displacement_km = haversine_km(
      truth_centroid[[
        "lon"
      ]],
      truth_centroid[[
        "lat"
      ]],
      prediction_centroid[[
        "lon"
      ]],
      prediction_centroid[[
        "lat"
      ]]
    ),
    True_component_count = count_components(
      truth_raster
    ),
    Predicted_component_count = count_components(
      prediction_raster
    ),
    Unsampled_true_recovery = safe_fraction(
      sum(
        cell_area_all[
          unsampled_true &
            prediction
        ]
      ),
      sum(
        cell_area_all[
          unsampled_true
        ]
      )
    ),
    Sampled_occurrence_cell_recovery = safe_fraction(
      sum(
        cell_area_all[
          sampled_true &
            prediction
        ]
      ),
      sum(
        cell_area_all[
          sampled_true
        ]
      )
    ),
    TP_area_km2 = tp_area,
    FP_area_km2 = fp_area,
    FN_area_km2 = fn_area,
    TN_area_km2 = tn_area,
    stringsAsFactors = FALSE
  )
}


# ============================================================
# Availability-conditioned environmental metrics helper
# ============================================================

calculate_available_environment_metrics <- function(
    truth_raster,
    prediction_raster,
    species_name,
    condition_id,
    occurrence_points
) {

  truth_values <- terra::values(
    truth_raster,
    mat = FALSE
  )[
    valid_pc_cells
  ]

  prediction_values <- terra::values(
    prediction_raster,
    mat = FALSE
  )[
    valid_pc_cells
  ]

  if (
    any(
      !is.finite(
        truth_values
      )
    ) ||
      any(
        !is.finite(
          prediction_values
        )
      )
  ) {
    stop(
      "Non-finite values found in availability-conditioned geometry."
    )
  }

  truth <- (
    truth_values == 1
  )

  prediction <- (
    prediction_values == 1
  )

  tp <- sum(
    truth &
      prediction
  )

  fp <- sum(
    !truth &
      prediction
  )

  fn <- sum(
    truth &
      !prediction
  )

  tn <- sum(
    !truth &
      !prediction
  )

  true_n <- (
    tp +
      fn
  )

  predicted_n <- (
    tp +
      fp
  )

  true_centroid <- pc_centroid(
    landscape_pc,
    truth
  )

  predicted_centroid <- pc_centroid(
    landscape_pc,
    prediction
  )

  occurrence_centroid <- colMeans(
    set_pc_names(
      occurrence_points
    )
  )

  data.frame(
    Condition_id = condition_id,
    Virtual_species = species_name,
    Australian_environmental_availability_cells = nrow(
      landscape_pc
    ),
    True_available_environment_cells = true_n,
    Predicted_available_environment_cells = predicted_n,
    Intersection_available_environment_cells = tp,
    Union_available_environment_cells = (
      tp +
        fp +
        fn
    ),
    False_positive_available_environment_cells = fp,
    False_negative_available_environment_cells = fn,
    Environmental_Jaccard_available = safe_fraction(
      tp,
      tp +
        fp +
        fn
    ),
    Environmental_Sorensen_available = safe_fraction(
      2 *
        tp,
      2 *
        tp +
        fp +
        fn
    ),
    Omission_available = safe_fraction(
      fn,
      true_n
    ),
    Commission_available = safe_fraction(
      fp,
      predicted_n
    ),
    Sensitivity_available = safe_fraction(
      tp,
      true_n
    ),
    Precision_available = safe_fraction(
      tp,
      predicted_n
    ),
    Specificity_available = safe_fraction(
      tn,
      tn +
        fp
    ),
    Relative_available_environment_count_error = safe_fraction(
      predicted_n -
        true_n,
      true_n
    ),
    True_available_centroid_PC1 = true_centroid[[1L]],
    True_available_centroid_PC2 = true_centroid[[2L]],
    True_available_centroid_PC3 = true_centroid[[3L]],
    Predicted_available_centroid_PC1 = predicted_centroid[[1L]],
    Predicted_available_centroid_PC2 = predicted_centroid[[2L]],
    Predicted_available_centroid_PC3 = predicted_centroid[[3L]],
    Environmental_centroid_displacement_available = euclidean_distance(
      predicted_centroid,
      true_centroid
    ),
    Occurrence_to_true_available_centroid_displacement = euclidean_distance(
      occurrence_centroid,
      true_centroid
    ),
    stringsAsFactors = FALSE
  )
}


# ============================================================
# Continuous generating-truth geometry helper
# ============================================================

calculate_continuous_geometry <- function(
    fit,
    species_name,
    condition_id,
    occurrence_points
) {

  hv <- fit$hypervolume

  hv_points <- set_pc_names(
    hv@RandomPoints
  )

  estimated_volume <- as.numeric(
    hv@Volume
  )

  truth_definition <- truth_definitions[[
    species_name
  ]]

  true_volume <- truth_definition$true_volume
  true_centroid <- truth_definition$true_centroid

  occurrence_centroid <- colMeans(
    set_pc_names(
      occurrence_points
    )
  )

  fitted_centroid <- colMeans(
    hv_points
  )

  inside_truth <- truth_definition$classify_true(
    hv_points
  )

  fitted_precision <- mean(
    inside_truth
  )

  intersection_volume_raw <- (
    estimated_volume *
      fitted_precision
  )

  intersection_volume <- min(
    max(
      intersection_volume_raw,
      0
    ),
    true_volume,
    estimated_volume
  )

  union_volume <- (
    true_volume +
      estimated_volume -
      intersection_volume
  )

  false_positive_volume <- max(
    0,
    estimated_volume -
      intersection_volume
  )

  false_negative_volume <- max(
    0,
    true_volume -
      intersection_volume
  )

  signed_volume_error <- (
    estimated_volume -
      true_volume
  )

  data.frame(
    Condition_id = condition_id,
    Virtual_species = species_name,
    True_environmental_volume = true_volume,
    Estimated_environmental_volume = estimated_volume,
    Signed_volume_error = signed_volume_error,
    Absolute_volume_error = abs(
      signed_volume_error
    ),
    Relative_volume_error = safe_fraction(
      signed_volume_error,
      true_volume
    ),
    Relative_volume_error_percent = 100 *
      safe_fraction(
        signed_volume_error,
        true_volume
      ),
    True_centroid_PC1 = true_centroid[[1L]],
    True_centroid_PC2 = true_centroid[[2L]],
    True_centroid_PC3 = true_centroid[[3L]],
    Fitted_centroid_PC1 = fitted_centroid[[1L]],
    Fitted_centroid_PC2 = fitted_centroid[[2L]],
    Fitted_centroid_PC3 = fitted_centroid[[3L]],
    Centroid_displacement_fitted_to_true = euclidean_distance(
      fitted_centroid,
      true_centroid
    ),
    Centroid_displacement_fitted_to_true_normalized = safe_fraction(
      euclidean_distance(
        fitted_centroid,
        true_centroid
      ),
      equivalent_sphere_radius(
        true_volume
      )
    ),
    Centroid_displacement_fitted_to_occurrence = euclidean_distance(
      fitted_centroid,
      occurrence_centroid
    ),
    Hypervolume_random_points = nrow(
      hv_points
    ),
    Fraction_fitted_points_inside_true_support = fitted_precision,
    Intersection_volume = intersection_volume,
    Union_volume = union_volume,
    Environmental_Jaccard = safe_fraction(
      intersection_volume,
      union_volume
    ),
    Environmental_Sorensen = safe_fraction(
      2 *
        intersection_volume,
      true_volume +
        estimated_volume
    ),
    True_volume_recall = safe_fraction(
      intersection_volume,
      true_volume
    ),
    Fitted_volume_precision = fitted_precision,
    False_positive_environmental_volume = false_positive_volume,
    False_negative_environmental_volume = false_negative_volume,
    False_positive_fraction_of_fitted_volume = safe_fraction(
      false_positive_volume,
      estimated_volume
    ),
    False_negative_fraction_of_true_volume = safe_fraction(
      false_negative_volume,
      true_volume
    ),
    stringsAsFactors = FALSE
  )
}


# ============================================================
# Disconnected structural masks
# ============================================================

disconnected_mode_values_valid <- terra::values(
  disconnected_mode_raster,
  mat = FALSE
)[
  valid_pc_cells
]

available_gap_mask <- classify_disconnected_gap(
  landscape_pc
)


# ============================================================
# Calculate all sensitivity endpoints
# ============================================================

geographic_rows <- list()
availability_rows <- list()
continuous_rows <- list()
structural_rows <- list()

geographic_index <- 0L
availability_index <- 0L
continuous_index <- 0L
structural_index <- 0L

for (
  design_index in seq_len(
    nrow(
      sensitivity_design
    )
  )
) {

  condition <- sensitivity_design[
    design_index,
    ,
    drop = FALSE
  ]

  condition_id <- condition$Condition_id[[1L]]
  species_name <- condition$Virtual_species[[1L]]
  condition_code <- condition$Condition_code[[1L]]

  model_row <- get_model_registry_row(
    condition_id
  )

  projection_row <- get_projection_registry_row(
    condition_id
  )

  if (
    is.null(
      model_row
    ) ||
      is.null(
        projection_row
      ) ||
      !isTRUE(
        model_row$Success[[1L]]
      ) ||
      !isTRUE(
        projection_row$Success[[1L]]
      )
  ) {
    next
  }

  fit <- load_condition_fit(
    species_name,
    condition_code
  )

  projection_file <- get_condition_projection_file(
    species_name,
    condition_code
  )

  prediction_raster <- terra::rast(
    projection_file
  )

  occurrence_points <- set_pc_names(
    occurrence_objects[[
      species_name
    ]]$pc
  )

  occurrence_xy <- occurrence_objects[[
    species_name
  ]]$xy

  geographic_index <- (
    geographic_index +
      1L
  )

  geographic_rows[[
    geographic_index
  ]] <- calculate_geographic_metrics(
    truth_raster = truth_rasters[[
      species_name
    ]],
    prediction_raster = prediction_raster,
    occurrence_xy = occurrence_xy,
    species_name = species_name,
    condition_id = condition_id
  )

  availability_index <- (
    availability_index +
      1L
  )

  availability_rows[[
    availability_index
  ]] <- calculate_available_environment_metrics(
    truth_raster = truth_rasters[[
      species_name
    ]],
    prediction_raster = prediction_raster,
    species_name = species_name,
    condition_id = condition_id,
    occurrence_points = occurrence_points
  )

  continuous_index <- (
    continuous_index +
      1L
  )

  continuous_rows[[
    continuous_index
  ]] <- calculate_continuous_geometry(
    fit = fit,
    species_name = species_name,
    condition_id = condition_id,
    occurrence_points = occurrence_points
  )

  if (
    identical(
      species_name,
      "Disconnected"
    )
  ) {

    prediction_values_valid <- terra::values(
      prediction_raster,
      mat = FALSE
    )[
      valid_pc_cells
    ] ==
      1

    mode_A_mask <- (
      disconnected_mode_values_valid == 1L
    )

    mode_B_mask <- (
      disconnected_mode_values_valid == 2L
    )

    mode_A_recovery <- safe_fraction(
      sum(
        cell_area_valid[
          mode_A_mask &
            prediction_values_valid
        ],
        na.rm = TRUE
      ),
      sum(
        cell_area_valid[
          mode_A_mask
        ],
        na.rm = TRUE
      )
    )

    mode_B_recovery <- safe_fraction(
      sum(
        cell_area_valid[
          mode_B_mask &
            prediction_values_valid
        ],
        na.rm = TRUE
      ),
      sum(
        cell_area_valid[
          mode_B_mask
        ],
        na.rm = TRUE
      )
    )

    geographic_gap_rate <- if (
      any(
        available_gap_mask
      )
    ) {
      mean(
        prediction_values_valid[
          available_gap_mask
        ]
      )
    } else {
      NA_real_
    }

    geographic_gap_area <- sum(
      cell_area_valid[
        available_gap_mask &
          prediction_values_valid
      ],
      na.rm = TRUE
    )

    hv_points <- set_pc_names(
      fit$hypervolume@RandomPoints
    )

    inside_continuous_gap <- classify_disconnected_gap(
      hv_points
    )

    fraction_hv_in_gap <- mean(
      inside_continuous_gap
    )

    continuous_gap_invasion_raw <- (
      as.numeric(
        fit$hypervolume@Volume
      ) *
        fraction_hv_in_gap
    )

    continuous_gap_invasion <- min(
      max(
        continuous_gap_invasion_raw,
        0
      ),
      disconnected_gap_volume,
      as.numeric(
        fit$hypervolume@Volume
      )
    )

    structural_index <- (
      structural_index +
        1L
    )

    structural_rows[[
      structural_index
    ]] <- data.frame(
      Condition_id = condition_id,
      Virtual_species = species_name,
      Mode_A_geographic_recovery = mode_A_recovery,
      Mode_B_geographic_recovery = mode_B_recovery,
      Available_gap_cells = sum(
        available_gap_mask
      ),
      Predicted_available_gap_cells = sum(
        available_gap_mask &
          prediction_values_valid
      ),
      Available_gap_prediction_rate = geographic_gap_rate,
      Predicted_geographic_area_in_environmental_gap_km2 = geographic_gap_area,
      Continuous_gap_true_volume = disconnected_gap_volume,
      Fraction_fitted_random_points_in_continuous_gap = fraction_hv_in_gap,
      Continuous_gap_invasion_volume = continuous_gap_invasion,
      Fraction_continuous_gap_filled = safe_fraction(
        continuous_gap_invasion,
        disconnected_gap_volume
      ),
      stringsAsFactors = FALSE
    )
  }
}


geographic_metrics <- if (
  length(
    geographic_rows
  ) > 0L
) {
  do.call(
    rbind,
    geographic_rows
  )
} else {
  data.frame()
}

availability_geometry <- if (
  length(
    availability_rows
  ) > 0L
) {
  do.call(
    rbind,
    availability_rows
  )
} else {
  data.frame()
}

continuous_geometry <- if (
  length(
    continuous_rows
  ) > 0L
) {
  do.call(
    rbind,
    continuous_rows
  )
} else {
  data.frame()
}

disconnected_structural <- if (
  length(
    structural_rows
  ) > 0L
) {
  do.call(
    rbind,
    structural_rows
  )
} else {
  data.frame()
}

write_csv_safely(
  geographic_metrics,
  geographic_metrics_file
)

write_csv_safely(
  availability_geometry,
  availability_geometry_file
)

write_csv_safely(
  continuous_geometry,
  continuous_geometry_file
)

write_csv_safely(
  disconnected_structural,
  disconnected_structural_file
)


# ============================================================
# Merge one row per UNIQUE QPH condition
# ============================================================

combined_condition_results <- sensitivity_design

combined_condition_results <- merge(
  combined_condition_results,
  qph_audit_summary,
  by = c(
    "Condition_id",
    "Virtual_species",
    "Condition_code",
    "Sensitivity_family",
    "Is_baseline",
    "Bandwidth_multiplier",
    "q",
    "Samples_per_point"
  ),
  all.x = TRUE,
  sort = FALSE
)

combined_condition_results <- merge(
  combined_condition_results,
  geographic_metrics,
  by = c(
    "Condition_id",
    "Virtual_species"
  ),
  all.x = TRUE,
  sort = FALSE
)

combined_condition_results <- merge(
  combined_condition_results,
  availability_geometry,
  by = c(
    "Condition_id",
    "Virtual_species"
  ),
  all.x = TRUE,
  sort = FALSE
)

combined_condition_results <- merge(
  combined_condition_results,
  continuous_geometry,
  by = c(
    "Condition_id",
    "Virtual_species"
  ),
  all.x = TRUE,
  sort = FALSE
)

if (
  nrow(
    disconnected_structural
  ) > 0L
) {

  combined_condition_results <- merge(
    combined_condition_results,
    disconnected_structural,
    by = c(
      "Condition_id",
      "Virtual_species"
    ),
    all.x = TRUE,
    sort = FALSE
  )
}

combined_condition_results <- combined_condition_results[
  match(
    sensitivity_design$Condition_id,
    combined_condition_results$Condition_id
  ),
  ,
  drop = FALSE
]

write_csv_safely(
  combined_condition_results,
  combined_condition_results_file
)


# ============================================================
# Plot-ready long series with baseline duplicated by family
# ============================================================

plot_series_rows <- list()
plot_series_index <- 0L

for (
  species_name in species_order
) {

  species_results <- combined_condition_results[
    combined_condition_results$Virtual_species ==
      species_name,
    ,
    drop = FALSE
  ]

  baseline_row <- species_results[
    species_results$Is_baseline,
    ,
    drop = FALSE
  ]

  if (nrow(baseline_row) != 1L) {
    stop(
      "Expected exactly one baseline sensitivity row for ",
      species_name,
      "."
    )
  }

  # Bandwidth series.
  bandwidth_rows <- species_results[
    species_results$Condition_code %in%
      c(
        "bandwidth_0p75",
        "bandwidth_1p25"
      ),
    ,
    drop = FALSE
  ]

  bandwidth_series <- rbind(
    bandwidth_rows,
    baseline_row
  )

  bandwidth_series$Plot_family <- "Bandwidth_multiplier"
  bandwidth_series$Plot_value <- bandwidth_series$Bandwidth_multiplier

  plot_series_index <- (
    plot_series_index +
      1L
  )

  plot_series_rows[[
    plot_series_index
  ]] <- bandwidth_series

  # q series.
  q_rows <- species_results[
    species_results$Condition_code %in%
      c(
        "q_0p950",
        "q_0p975"
      ),
    ,
    drop = FALSE
  ]

  q_series <- rbind(
    q_rows,
    baseline_row
  )

  q_series$Plot_family <- "q"
  q_series$Plot_value <- q_series$q

  plot_series_index <- (
    plot_series_index +
      1L
  )

  plot_series_rows[[
    plot_series_index
  ]] <- q_series

  # Sampling-effort series.
  spp_rows <- species_results[
    species_results$Condition_code %in%
      c(
        "spp_25",
        "spp_50",
        "spp_150"
      ),
    ,
    drop = FALSE
  ]

  spp_series <- rbind(
    spp_rows,
    baseline_row
  )

  spp_series$Plot_family <- "Samples_per_point"
  spp_series$Plot_value <- spp_series$Samples_per_point

  plot_series_index <- (
    plot_series_index +
      1L
  )

  plot_series_rows[[
    plot_series_index
  ]] <- spp_series
}

plot_ready_long <- do.call(
  rbind,
  plot_series_rows
)

plot_ready_long <- plot_ready_long[
  order(
    match(
      plot_ready_long$Virtual_species,
      species_order
    ),
    match(
      plot_ready_long$Plot_family,
      c(
        "Bandwidth_multiplier",
        "q",
        "Samples_per_point"
      )
    ),
    plot_ready_long$Plot_value
  ),
  ,
  drop = FALSE
]

rownames(
  plot_ready_long
) <- NULL

write_csv_safely(
  plot_ready_long,
  plot_ready_long_file
)


# ============================================================
# Baseline numerical QA against Scripts 13 and 14
# ============================================================

baseline_comparison_rows <- list()
baseline_comparison_index <- 0L

for (
  species_name in species_order
) {

  sensitivity_baseline <- combined_condition_results[
    combined_condition_results$Virtual_species ==
      species_name &
      combined_condition_results$Is_baseline,
    ,
    drop = FALSE
  ]

  script13_row <- baseline_results$geographic_metrics[
    baseline_results$geographic_metrics$Species ==
      species_name &
      baseline_results$geographic_metrics$Sample_size ==
        analysis_sample_size &
      baseline_results$geographic_metrics$Method ==
        "QPH",
    ,
    drop = FALSE
  ]

  script14_available <- geometry_results$availability_conditioned_geometry[
    geometry_results$availability_conditioned_geometry$Virtual_species ==
      species_name &
      geometry_results$availability_conditioned_geometry$Method ==
        "QPH",
    ,
    drop = FALSE
  ]

  script14_continuous <- geometry_results$continuous_geometry[
    geometry_results$continuous_geometry$Virtual_species ==
      species_name &
      geometry_results$continuous_geometry$Method ==
        "QPH",
    ,
    drop = FALSE
  ]

  if (
    nrow(
      sensitivity_baseline
    ) != 1L ||
      nrow(
        script13_row
      ) != 1L ||
      nrow(
        script14_available
      ) != 1L ||
      nrow(
        script14_continuous
      ) != 1L
  ) {
    stop(
      "Could not recover unique upstream baseline QA rows for ",
      species_name,
      "."
    )
  }

  comparisons <- list(
    Geographic_Jaccard = c(
      sensitivity_baseline$Jaccard_area_weighted,
      script13_row$Jaccard_area_weighted
    ),
    Available_environmental_Jaccard = c(
      sensitivity_baseline$Environmental_Jaccard_available,
      script14_available$Environmental_Jaccard_available
    ),
    Continuous_environmental_Jaccard = c(
      sensitivity_baseline$Environmental_Jaccard,
      script14_continuous$Environmental_Jaccard
    ),
    QPH_volume = c(
      sensitivity_baseline$Estimated_environmental_volume,
      script14_continuous$Estimated_environmental_volume
    )
  )

  for (
    metric_name in names(
      comparisons
    )
  ) {

    values <- comparisons[[
      metric_name
    ]]

    difference <- (
      values[[1L]] -
        values[[2L]]
    )

    matches <- isTRUE(
      all.equal(
        values[[1L]],
        values[[2L]],
        tolerance = 1e-10
      )
    )

    baseline_comparison_index <- (
      baseline_comparison_index +
        1L
    )

    baseline_comparison_rows[[
      baseline_comparison_index
    ]] <- data.frame(
      Virtual_species = species_name,
      Metric = metric_name,
      Script16_value = values[[1L]],
      Upstream_value = values[[2L]],
      Difference = difference,
      Matches = matches,
      stringsAsFactors = FALSE
    )
  }
}

baseline_metric_qa <- do.call(
  rbind,
  baseline_comparison_rows
)

write_csv_safely(
  rbind(
    data.frame(
      Virtual_species = baseline_qa$Virtual_species,
      Metric = "Independent_sqrtNB_recalculation_matches",
      Script16_value = as.numeric(
        baseline_qa$Independent_bandwidth_recalculation_matches
      ),
      Upstream_value = 1,
      Difference = as.numeric(
        baseline_qa$Independent_bandwidth_recalculation_matches
      ) -
        1,
      Matches = baseline_qa$Independent_bandwidth_recalculation_matches,
      stringsAsFactors = FALSE
    ),
    baseline_metric_qa
  ),
  baseline_qa_file
)

if (
  any(
    !baseline_metric_qa$Matches
  )
) {
  warning(
    "At least one recalculated Script-16 baseline metric differs from the ",
    "corresponding Script-13/14 baseline. Inspect ",
    baseline_qa_file,
    "."
  )
}


# ============================================================
# Failure audit
# ============================================================

failure_rows <- list()
failure_index <- 0L

failed_models <- model_registry[
  !model_registry$Success,
  ,
  drop = FALSE
]

if (nrow(failed_models) > 0L) {

  for (
    row_index in seq_len(
      nrow(
        failed_models
      )
    )
  ) {

    failure_index <- (
      failure_index +
        1L
    )

    failure_rows[[
      failure_index
    ]] <- data.frame(
      Analysis_stage = "QPH sensitivity model fit",
      Condition_id = failed_models$Condition_id[[row_index]],
      Virtual_species = failed_models$Virtual_species[[row_index]],
      Condition_code = failed_models$Condition_code[[row_index]],
      Error_message = failed_models$Error_message[[row_index]],
      stringsAsFactors = FALSE
    )
  }
}


failed_projections <- projection_registry[
  !projection_registry$Success,
  ,
  drop = FALSE
]

if (nrow(failed_projections) > 0L) {

  for (
    row_index in seq_len(
      nrow(
        failed_projections
      )
    )
  ) {

    failure_index <- (
      failure_index +
        1L
    )

    failure_rows[[
      failure_index
    ]] <- data.frame(
      Analysis_stage = "QPH sensitivity geographic projection",
      Condition_id = failed_projections$Condition_id[[row_index]],
      Virtual_species = failed_projections$Virtual_species[[row_index]],
      Condition_code = failed_projections$Condition_code[[row_index]],
      Error_message = failed_projections$Error_message[[row_index]],
      stringsAsFactors = FALSE
    )
  }
}


failure_table <- if (
  length(
    failure_rows
  ) > 0L
) {
  do.call(
    rbind,
    failure_rows
  )
} else {
  data.frame(
    Analysis_stage = character(0),
    Condition_id = character(0),
    Virtual_species = character(0),
    Condition_code = character(0),
    Error_message = character(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  failure_table,
  failure_file
)


# ============================================================
# Final results object
# ============================================================

final_results <- list(
  metadata = list(
    script = "16_Virtual_Species_QPH_Sensitivity_n900.R",
    analysis_settings_hash = analysis_settings_hash,
    locked_design_hash = locked_design_hash,
    baseline_analysis_hash = baseline_analysis_hash,
    qph_core_version = QPH_CORE_VERSION,
    qph_core_md5 = qph_core_md5,
    completed_at = as.character(
      Sys.time()
    )
  ),
  analysis_settings = analysis_settings,
  sensitivity_design = sensitivity_design,
  model_registry = model_registry,
  projection_registry = projection_registry,
  qph_audit_summary = qph_audit_summary,
  qph_local_s = qph_local_s,
  geographic_metrics = geographic_metrics,
  availability_conditioned_geometry = availability_geometry,
  continuous_geometry = continuous_geometry,
  disconnected_structural_metrics = disconnected_structural,
  combined_condition_results = combined_condition_results,
  plot_ready_long = plot_ready_long,
  baseline_metric_qa = baseline_metric_qa,
  failures = failure_table
)

saveRDS(
  final_results,
  final_results_file,
  version = 3
)


# ============================================================
# Console summaries
# ============================================================

message(
  "\nQPH SENSITIVITY — geographic recovery:"
)

print(
  combined_condition_results[
    ,
    c(
      "Virtual_species",
      "Condition_code",
      "Bandwidth_multiplier",
      "q",
      "Samples_per_point",
      "Jaccard_area_weighted",
      "Omission_error_area_weighted",
      "Commission_error_area_weighted",
      "Relative_geographic_area_error"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)

message(
  "\nQPH SENSITIVITY — available environmental geometry:"
)

print(
  combined_condition_results[
    ,
    c(
      "Virtual_species",
      "Condition_code",
      "Environmental_Jaccard_available",
      "Environmental_Sorensen_available",
      "Relative_available_environment_count_error",
      "Environmental_centroid_displacement_available"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)

message(
  "\nQPH SENSITIVITY — continuous generating-niche geometry:"
)

print(
  combined_condition_results[
    ,
    c(
      "Virtual_species",
      "Condition_code",
      "Estimated_environmental_volume",
      "Relative_volume_error_percent",
      "Environmental_Jaccard",
      "Environmental_Sorensen",
      "False_positive_fraction_of_fitted_volume",
      "False_negative_fraction_of_true_volume"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)


# ============================================================
# Notes and session information
# ============================================================

analysis_notes <- c(
  "Revised virtual-species QPH sensitivity at n = 900",
  "==================================================",
  "",
  "Species:",
  "  Unimodal Gaussian-PCA",
  "  Disconnected bimodal",
  "",
  "QPH baseline:",
  "  sqrt-NB bandwidth",
  "  K = round(sqrt(n))",
  "  h = sqrt(mean(s_i))",
  "  q = 0.99",
  "  samples.per.point = 100",
  "  sd.count = 3",
  "",
  "OFAT sensitivity:",
  "  bandwidth multiplier = 0.75, 1.00, 1.25",
  "  q = 0.950, 0.975, 0.990",
  "  samples.per.point = 25, 50, 100, 150",
  "",
  "Unique conditions per species = 8.",
  "Unique conditions overall = 16.",
  "Script-13 baselines reused = 2.",
  "New QPH fits requested = 14.",
  "",
  "All sensitivity conditions use the corresponding Script-13 baseline",
  "QPH sampling seed to reduce avoidable Monte-Carlo differences.",
  "",
  "Repeated endpoints:",
  "  geographic recovery against known Australian distribution",
  "  availability-conditioned environmental geometry",
  "  continuous generating-niche geometry",
  "  disconnected between-mode structural diagnostics",
  "",
  "No topology sensitivity analysis is performed.",
  "Gaussian KDE and SVM are not refitted or varied.",
  "Publication figures are deferred to Script 17.",
  "",
  paste0(
    "Successful unique QPH conditions: ",
    sum(
      model_registry$Success
    ),
    " / ",
    nrow(
      model_registry
    )
  ),
  paste0(
    "Successful geographic projections: ",
    sum(
      projection_registry$Success
    ),
    " / ",
    nrow(
      projection_registry
    )
  ),
  paste0(
    "Failures recorded: ",
    nrow(
      failure_table
    )
  ),
  paste0(
    "Completed: ",
    Sys.time()
  )
)

writeLines(
  analysis_notes,
  con = analysis_notes_file
)

capture.output(
  sessionInfo(),
  file = session_information_file
)


# ============================================================
# Completion audit
# ============================================================

message(
  "\n============================================================"
)

message(
  "16_Virtual_Species_QPH_Sensitivity_n900.R complete."
)

message(
  "Unique QPH conditions: ",
  nrow(
    sensitivity_design
  ),
  " / 16"
)

message(
  "New QPH fits requested: ",
  sum(
    sensitivity_design$Requires_new_fit
  ),
  " / 14"
)

message(
  "Successful model conditions: ",
  sum(
    model_registry$Success
  ),
  " / ",
  nrow(
    model_registry
  )
)

message(
  "Successful projections: ",
  sum(
    projection_registry$Success
  ),
  " / ",
  nrow(
    projection_registry
  )
)

message(
  "Failures recorded: ",
  nrow(
    failure_table
  )
)

message(
  "Combined condition results:\n  ",
  normalizePath(
    combined_condition_results_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "Plot-ready long table:\n  ",
  normalizePath(
    plot_ready_long_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "Final sensitivity object:\n  ",
  normalizePath(
    final_results_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "============================================================"
)
