# ============================================================
# 13_Virtual_Species_Baseline_Fits_and_Geography.R
# ============================================================
#
# PURPOSE
# -------
# Fit the revised baseline QPH, Gaussian KDE and one-class SVM to the TWO
# locked virtual species at n = 300, 900 and 1500, project every fitted
# environmental niche across the locked Australian PC1-PC3 landscape, and
# compare each binary geographic projection with known geographic truth.
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

baseline_output_directory <- file.path(
  analysis_root_directory,
  "01_Baseline_Fits"
)

geographic_output_directory <- file.path(
  analysis_root_directory,
  "02_Geographic_Validation"
)

model_object_directory <- file.path(
  baseline_output_directory,
  "model_objects"
)

projection_raster_directory <- file.path(
  geographic_output_directory,
  "projection_rasters"
)

table_directory <- file.path(
  geographic_output_directory,
  "tables"
)

for (directory in c(
  baseline_output_directory,
  geographic_output_directory,
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
  "hypervolume",
  "e1071"
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
library(e1071)


# ============================================================
# Locked input files
# ============================================================

master_locked_input_file <- file.path(
  locked_input_directory,
  "virtual_species_locked_inputs.rds"
)

locked_settings_file <- file.path(
  locked_input_directory,
  "locked_input_settings.rds"
)

if (!file.exists(master_locked_input_file)) {
  stop(
    "Missing Script-12 locked input archive:\n  ",
    master_locked_input_file,
    "\nRun 12_Virtual_Species_Locked_Inputs.R first."
  )
}

if (!file.exists(locked_settings_file)) {
  stop(
    "Missing Script-12 locked settings:\n  ",
    locked_settings_file
  )
}

locked_inputs <- readRDS(
  master_locked_input_file
)

locked_input_settings <- readRDS(
  locked_settings_file
)

locked_design_hash <- locked_input_settings$locked_design_hash

if (
  is.null(locked_design_hash) ||
    length(locked_design_hash) != 1L ||
    is.na(locked_design_hash)
) {
  stop(
    "Script-12 locked design hash is unavailable."
  )
}


# ============================================================
# Locked analysis settings
# ============================================================

species_order <- c(
  "Unimodal",
  "Disconnected"
)

species_labels <- c(
  Unimodal = "Unimodal Gaussian-PCA",
  Disconnected = "Disconnected bimodal"
)

sample_sizes <- c(
  300L,
  900L,
  1500L
)

method_order <- c(
  "QPH",
  "Gaussian KDE",
  "SVM"
)

# Baseline stochastic settings.
baseline_samples_per_point <- 100L
baseline_sd_count <- 3
qph_baseline_q <- 0.99
kde_baseline_quantile <- 0.95

# SVM baseline.
svm_nu <- 0.01
svm_gamma <- 0.5
svm_scale_factor <- 1

# Reuse the original virtual-species model-seed rule.
model_seed <- 914301L

# Computational batching.
shared_chunk_size <- 100L
qph_potential_batch_size <- 500L
projection_batch_size <- 500L
svm_prediction_batch_size <- 5000L

# Restart controls.
resume_model_fits <- TRUE
retry_failed_model_fits <- TRUE
resume_projections <- TRUE
retry_failed_projections <- TRUE
verbose_hypervolume <- FALSE

# Numerical tolerance.
projection_tolerance <- sqrt(
  .Machine$double.eps
)

# Disconnected geographic gap definition.
gap_corridor_radius_multiplier <- 1.0

method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)

true_region_colour <- "#D9D9D9"
occurrence_colour <- "#111111"


# ============================================================
# Output files
# ============================================================

analysis_settings_file <- file.path(
  baseline_output_directory,
  "analysis_settings.rds"
)

model_registry_file <- file.path(
  baseline_output_directory,
  "virtual_species_baseline_model_registry.rds"
)

model_summary_file <- file.path(
  baseline_output_directory,
  "virtual_species_baseline_model_summary.csv"
)

qph_audit_summary_file <- file.path(
  baseline_output_directory,
  "QPH_audit_summary.csv"
)

qph_local_s_file <- file.path(
  baseline_output_directory,
  "QPH_local_s.csv"
)

svm_classifier_qa_file <- file.path(
  baseline_output_directory,
  "SVM_hypervolume_classifier_QA.csv"
)

projection_registry_file <- file.path(
  geographic_output_directory,
  "virtual_species_projection_registry.rds"
)

geographic_metrics_file <- file.path(
  table_directory,
  "virtual_species_geographic_recovery_ALL_methods.csv"
)

disconnected_structural_file <- file.path(
  table_directory,
  "virtual_species_disconnected_geographic_structure.csv"
)

failure_file <- file.path(
  table_directory,
  "failures.csv"
)

final_results_file <- file.path(
  geographic_output_directory,
  "virtual_species_baseline_geographic_results_sqrtNB_q099.rds"
)

analysis_notes_file <- file.path(
  geographic_output_directory,
  "analysis_notes.txt"
)

session_information_file <- file.path(
  geographic_output_directory,
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
    return(NA_character_)
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

  result <- try(
    terra::rast(x),
    silent = TRUE
  )

  if (
    !inherits(result, "try-error") &&
      inherits(result, "SpatRaster")
  ) {
    return(result)
  }

  result <- try(
    terra::unwrap(x),
    silent = TRUE
  )

  if (
    !inherits(result, "try-error") &&
      inherits(result, "SpatRaster")
  ) {
    return(result)
  }

  stop(
    "Could not convert object to a terra SpatRaster."
  )
}


set_pc_names <- function(x) {

  x <- as.matrix(x)
  storage.mode(x) <- "double"

  if (nrow(x) < 1L) {
    stop(
      "PC matrix contains no rows."
    )
  }

  if (ncol(x) != 3L) {
    stop(
      "Expected exactly three PC columns."
    )
  }

  if (any(!is.finite(x))) {
    stop(
      "PC matrix contains non-finite values."
    )
  }

  colnames(x) <- c(
    "PC1",
    "PC2",
    "PC3"
  )

  x
}


method_code <- function(method_name) {

  switch(
    method_name,
    "QPH" = "qph",
    "Gaussian KDE" = "gaussian_kde",
    "SVM" = "svm",
    stop(
      "Unknown method: ",
      method_name
    )
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
    sample_size,
    method_name
) {

  paste0(
    species_code(
      species_name
    ),
    "__n",
    sample_size,
    "__",
    method_code(
      method_name
    )
  )
}


model_object_path <- function(condition_id) {

  file.path(
    model_object_directory,
    paste0(
      condition_id,
      ".rds"
    )
  )
}


projection_raster_path <- function(condition_id) {

  file.path(
    projection_raster_directory,
    paste0(
      condition_id,
      "__geographic_projection.tif"
    )
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
    lon2 - lon1
  ) * rad

  dlat <- (
    lat2 - lat1
  ) * rad

  a <- (
    sin(
      dlat / 2
    )^2 +
      cos(
        lat1 * rad
      ) *
        cos(
          lat2 * rad
        ) *
        sin(
          dlon / 2
        )^2
  )

  6371.0088 *
    2 *
    atan2(
      sqrt(a),
      sqrt(
        pmax(
          0,
          1 - a
        )
      )
    )
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


count_components <- function(binary_raster) {

  occupied <- binary_raster

  occupied[
    occupied == 0
  ] <- NA

  if (
    !any(
      terra::values(
        occupied,
        mat = FALSE
      ) == 1,
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

  max_patch <- terra::global(
    patch_raster,
    "max",
    na.rm = TRUE
  )[
    1L,
    1L
  ]

  if (!is.finite(max_patch)) {
    return(
      0L
    )
  }

  as.integer(
    max_patch
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


predict_svm_in_chunks <- function(
    model,
    evaluation_points,
    batch_size = 5000L
) {

  evaluation_points <- set_pc_names(
    evaluation_points
  )

  output <- logical(
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

    prediction <- stats::predict(
      model,
      newdata = evaluation_points[
        idx,
        ,
        drop = FALSE
      ]
    )

    output[
      idx
    ] <- as.logical(
      prediction
    )
  }

  output
}


# ============================================================
# Load and validate Script-12 inputs
# ============================================================

required_locked_species <- c(
  "Unimodal",
  "Disconnected"
)

if (
  !all(
    required_locked_species %in%
      names(
        locked_inputs$truth
      )
  )
) {
  stop(
    "Script-12 truth archive does not contain both locked species."
  )
}

if (
  !all(
    required_locked_species %in%
      names(
        locked_inputs$occurrences$species
      )
  )
) {
  stop(
    "Script-12 occurrence archive does not contain both locked species."
  )
}

if (
  !identical(
    as.integer(
      locked_inputs$occurrences$sample_sizes
    ),
    sample_sizes
  )
) {
  stop(
    "Script-12 locked sample sizes differ from 300, 900 and 1500."
  )
}


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

pc_values <- terra::values(
  pc_stack,
  mat = TRUE
)

valid_pc_cells <- which(
  apply(
    pc_values,
    1L,
    function(row) {
      all(
        is.finite(
          row
        )
      )
    }
  )
)

if (length(valid_pc_cells) == 0L) {
  stop(
    "Locked Australian PC1-PC3 landscape contains no valid cells."
  )
}

landscape_pc <- set_pc_names(
  pc_values[
    valid_pc_cells,
    ,
    drop = FALSE
  ]
)

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

if (
  any(
    !is.finite(
      cell_area_valid
    ) |
      cell_area_valid <= 0
  )
) {
  stop(
    "At least one valid Australian PC cell has invalid geographic area."
  )
}

xy_all <- terra::xyFromCell(
  pc_stack[[1L]],
  seq_len(
    terra::ncell(
      pc_stack[[1L]]
    )
  )
)


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

disconnected_definition <- locked_inputs$truth$Disconnected$generating_definition

names(
  disconnected_definition$mode_A_mean
) <- c(
  "PC1",
  "PC2",
  "PC3"
)

names(
  disconnected_definition$mode_B_mean
) <- c(
  "PC1",
  "PC2",
  "PC3"
)

names(
  disconnected_definition$mode_sds
) <- c(
  "PC1",
  "PC2",
  "PC3"
)


# ============================================================
# Analysis settings and checkpoint compatibility
# ============================================================

analysis_settings <- list(
  script = "13_Virtual_Species_Baseline_Fits_and_Geography.R",
  locked_design_hash = locked_design_hash,
  qph_core_version = QPH_CORE_VERSION,
  qph_core_md5 = qph_core_md5,
  species = species_order,
  sample_sizes = sample_sizes,
  methods = method_order,
  qph = list(
    bandwidth = "sqrtNB",
    k_rule = "round(sqrt(n))",
    q = qph_baseline_q,
    samples_per_point = baseline_samples_per_point,
    sd_count = baseline_sd_count
  ),
  gaussian_kde = list(
    bandwidth = "hypervolume current Silverman",
    quantile = kde_baseline_quantile,
    samples_per_point = baseline_samples_per_point,
    sd_count = baseline_sd_count
  ),
  svm = list(
    nu = svm_nu,
    gamma = svm_gamma,
    scale_factor = svm_scale_factor,
    samples_per_point = baseline_samples_per_point,
    projection_classifier_scale = TRUE
  ),
  seeds = list(
    model_seed = model_seed
  ),
  batching = list(
    shared_chunk_size = shared_chunk_size,
    qph_potential_batch_size = qph_potential_batch_size,
    projection_batch_size = projection_batch_size,
    svm_prediction_batch_size = svm_prediction_batch_size
  ),
  disconnected_gap_corridor_radius_multiplier = gap_corridor_radius_multiplier
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

if (
  file.exists(
    analysis_settings_file
  )
) {

  previous_settings <- readRDS(
    analysis_settings_file
  )

  if (
    !identical(
      previous_settings$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Existing Script-13 outputs were created under incompatible settings.\n",
      "Archive or remove 01_Baseline_Fits and 02_Geographic_Validation before ",
      "running the revised design."
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
# Fit design
# ============================================================

fit_design_rows <- list()
fit_design_index <- 0L

for (species_name in species_order) {

  for (sample_size in sample_sizes) {

    for (
      method_index in seq_along(
        method_order
      )
    ) {

      method_name <- method_order[[
        method_index
      ]]

      fit_design_index <- fit_design_index + 1L

      fit_design_rows[[fit_design_index]] <- data.frame(
        Condition_id = condition_id_for(
          species_name,
          sample_size,
          method_name
        ),
        Species = species_name,
        Species_label = unname(
          species_labels[
            species_name
          ]
        ),
        Sample_size = sample_size,
        Method = method_name,
        Method_index = method_index,
        Fit_seed = model_seed +
          sample_size * 10L +
          method_index,
        stringsAsFactors = FALSE
      )
    }
  }
}

fit_design <- do.call(
  rbind,
  fit_design_rows
)

rownames(
  fit_design
) <- NULL

if (nrow(fit_design) != 18L) {
  stop(
    "Expected exactly 18 baseline fit conditions."
  )
}


# ============================================================
# Estimator fitting
# ============================================================

fit_one_model <- function(
    occurrence_points,
    species_name,
    sample_size,
    method_name,
    sampling_seed
) {

  occurrence_points <- set_pc_names(
    occurrence_points
  )

  full_start_time <- proc.time()[[
    "elapsed"
  ]]

  hypervolume_runtime_seconds <- NA_real_
  projection_classifier_runtime_seconds <- 0

  result <- tryCatch(
    {

      set.seed(
        as.integer(
          sampling_seed
        )
      )

      if (
        identical(
          method_name,
          "QPH"
        )
      ) {

        hypervolume_start_time <- proc.time()[[
          "elapsed"
        ]]

        qph_result <- construct_qph(
          data = occurrence_points,
          bandwidth = NULL,
          bandwidth_info = NULL,
          name = paste0(
            species_name,
            " virtual species QPH n=",
            sample_size
          ),
          samples_per_point = baseline_samples_per_point,
          sd_count = baseline_sd_count,
          q = qph_baseline_q,
          sampling_seed = sampling_seed,
          sampling_chunk_size = shared_chunk_size,
          potential_batch_size = qph_potential_batch_size,
          verbose = verbose_hypervolume
        )

        hypervolume_runtime_seconds <- (
          proc.time()[[
            "elapsed"
          ]] -
            hypervolume_start_time
        )

        list(
          success = TRUE,
          hypervolume = qph_result$hypervolume,
          qph_result = qph_result,
          kde_bandwidth = NULL,
          svm_projection_model = NULL,
          error_message = NA_character_
        )

      } else if (
        identical(
          method_name,
          "Gaussian KDE"
        )
      ) {

        hypervolume_start_time <- proc.time()[[
          "elapsed"
        ]]

        kde_bandwidth <- hypervolume::estimate_bandwidth(
          data = occurrence_points,
          method = "silverman"
        )

        set.seed(
          as.integer(
            sampling_seed
          )
        )

        hv <- hypervolume::hypervolume_gaussian(
          data = occurrence_points,
          name = paste0(
            species_name,
            " virtual species Gaussian KDE n=",
            sample_size
          ),
          kde.bandwidth = kde_bandwidth,
          samples.per.point = baseline_samples_per_point,
          sd.count = baseline_sd_count,
          quantile.requested = kde_baseline_quantile,
          quantile.requested.type = "probability",
          chunk.size = shared_chunk_size,
          verbose = verbose_hypervolume
        )

        methods::validObject(
          hv
        )

        hypervolume_runtime_seconds <- (
          proc.time()[[
            "elapsed"
          ]] -
            hypervolume_start_time
        )

        list(
          success = TRUE,
          hypervolume = hv,
          qph_result = NULL,
          kde_bandwidth = kde_bandwidth,
          svm_projection_model = NULL,
          error_message = NA_character_
        )

      } else if (
        identical(
          method_name,
          "SVM"
        )
      ) {

        hypervolume_start_time <- proc.time()[[
          "elapsed"
        ]]

        hv <- hypervolume::hypervolume_svm(
          data = occurrence_points,
          name = paste0(
            species_name,
            " virtual species SVM n=",
            sample_size
          ),
          samples.per.point = baseline_samples_per_point,
          svm.nu = svm_nu,
          svm.gamma = svm_gamma,
          scale.factor = svm_scale_factor,
          chunk.size = shared_chunk_size,
          verbose = verbose_hypervolume
        )

        methods::validObject(
          hv
        )

        hypervolume_runtime_seconds <- (
          proc.time()[[
            "elapsed"
          ]] -
            hypervolume_start_time
        )

        classifier_start_time <- proc.time()[[
          "elapsed"
        ]]

        # This scale=TRUE classifier is the authoritative geographic projection
        # model corresponding to hypervolume_svm().
        svm_projection_model <- e1071::svm(
          x = occurrence_points,
          y = NULL,
          type = "one-classification",
          nu = svm_nu,
          gamma = svm_gamma,
          scale = TRUE,
          kernel = "radial"
        )

        projection_classifier_runtime_seconds <- (
          proc.time()[[
            "elapsed"
          ]] -
            classifier_start_time
        )

        list(
          success = TRUE,
          hypervolume = hv,
          qph_result = NULL,
          kde_bandwidth = NULL,
          svm_projection_model = svm_projection_model,
          error_message = NA_character_
        )

      } else {

        stop(
          "Unknown method: ",
          method_name
        )
      }
    },
    error = function(e) {

      list(
        success = FALSE,
        hypervolume = NULL,
        qph_result = NULL,
        kde_bandwidth = NULL,
        svm_projection_model = NULL,
        error_message = conditionMessage(
          e
        )
      )
    }
  )

  full_runtime_seconds <- (
    proc.time()[[
      "elapsed"
    ]] -
      full_start_time
  )

  result$species <- species_name
  result$sample_size <- sample_size
  result$method <- method_name
  result$sampling_seed <- as.integer(
    sampling_seed
  )
  result$hypervolume_runtime_seconds <- hypervolume_runtime_seconds
  result$projection_classifier_runtime_seconds <- (
    projection_classifier_runtime_seconds
  )
  result$full_fit_runtime_seconds <- full_runtime_seconds
  result$analysis_settings_hash <- analysis_settings_hash
  result$qph_core_version <- QPH_CORE_VERSION

  result
}


empty_model_registry <- function() {

  data.frame(
    Condition_id = character(0),
    Species = character(0),
    Species_label = character(0),
    Sample_size = integer(0),
    Method = character(0),
    Fit_seed = integer(0),
    Success = logical(0),
    Object_file = character(0),
    Hypervolume_runtime_seconds = numeric(0),
    Projection_classifier_runtime_seconds = numeric(0),
    Full_fit_runtime_seconds = numeric(0),
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

  model_checkpoint <- readRDS(
    model_registry_file
  )

  if (
    !identical(
      model_checkpoint$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Incompatible Script-13 model checkpoint."
    )
  }

  model_registry <- model_checkpoint$registry

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


get_registry_row <- function(
    condition_id
) {

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
      "Model registry contains duplicate condition: ",
      condition_id
    )
  }

  rows
}


replace_registry_row <- function(
    new_row
) {

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


for (
  fit_index in seq_len(
    nrow(
      fit_design
    )
  )
) {

  condition <- fit_design[
    fit_index,
    ,
    drop = FALSE
  ]

  condition_id <- condition$Condition_id[[1L]]
  species_name <- condition$Species[[1L]]
  sample_size <- condition$Sample_size[[1L]]
  method_name <- condition$Method[[1L]]
  fit_seed <- condition$Fit_seed[[1L]]

  existing <- get_registry_row(
    condition_id
  )

  object_file <- model_object_path(
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
        object_file
      )
  ) {

    message(
      "Reusing successful fit ",
      fit_index,
      "/",
      nrow(
        fit_design
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
    locked_inputs$occurrences$species[[
      species_name
    ]]$subsets[[
      as.character(
        sample_size
      )
    ]]$pc
  )

  message(
    "Fitting ",
    fit_index,
    "/",
    nrow(
      fit_design
    ),
    ": ",
    condition_id
  )

  fit <- fit_one_model(
    occurrence_points = occurrence_points,
    species_name = species_name,
    sample_size = sample_size,
    method_name = method_name,
    sampling_seed = fit_seed
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
    Species = species_name,
    Species_label = unname(
      species_labels[
        species_name
      ]
    ),
    Sample_size = sample_size,
    Method = method_name,
    Fit_seed = fit_seed,
    Success = isTRUE(
      fit$success
    ),
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
    Hypervolume_runtime_seconds = fit$hypervolume_runtime_seconds,
    Projection_classifier_runtime_seconds = (
      fit$projection_classifier_runtime_seconds
    ),
    Full_fit_runtime_seconds = fit$full_fit_runtime_seconds,
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

  replace_registry_row(
    registry_row
  )

  save_model_checkpoint()
}


model_registry <- model_registry[
  match(
    fit_design$Condition_id,
    model_registry$Condition_id
  ),
  ,
  drop = FALSE
]

save_model_checkpoint()


# ============================================================
# Model access and relocation-safe object paths
# ============================================================

get_model_fit <- function(
    condition_id
) {

  object_file <- model_object_path(
    condition_id
  )

  if (!file.exists(object_file)) {
    stop(
      "Missing model object:\n  ",
      object_file
    )
  }

  fit <- readRDS(
    object_file
  )

  if (
    !identical(
      fit$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Model object was created under incompatible Script-13 settings: ",
      condition_id
    )
  }

  fit
}


# ============================================================
# QPH audit exports
# ============================================================

qph_audit_rows <- list()
qph_local_s_rows <- list()
qph_audit_index <- 0L
qph_local_index <- 0L

qph_conditions <- fit_design[
  fit_design$Method ==
    "QPH",
  ,
  drop = FALSE
]

for (
  row_index in seq_len(
    nrow(
      qph_conditions
    )
  )
) {

  condition <- qph_conditions[
    row_index,
    ,
    drop = FALSE
  ]

  condition_id <- condition$Condition_id[[1L]]

  registry_row <- get_registry_row(
    condition_id
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

  fit <- get_model_fit(
    condition_id
  )

  audit <- fit$qph_result$audit

  qph_audit_index <- qph_audit_index + 1L

  qph_audit_rows[[qph_audit_index]] <- data.frame(
    Condition_id = condition_id,
    Species = condition$Species[[1L]],
    Sample_size = condition$Sample_size[[1L]],
    n = audit$n,
    d = audit$d,
    K = audit$K,
    mean_s = audit$mean_s,
    scalar_h = audit$baseline_scalar_h,
    bandwidth_axis_1 = audit$fitted_bandwidth[[1L]],
    bandwidth_axis_2 = audit$fitted_bandwidth[[2L]],
    bandwidth_axis_3 = audit$fitted_bandwidth[[3L]],
    q = audit$q,
    samples_per_point = audit$samples_per_point,
    sd_count = audit$sd_count,
    sampling_seed = audit$sampling_seed,
    retained_fraction = fit$qph_result$retained_fraction,
    qph_volume = fit$qph_result$qph_volume,
    Full_fit_runtime_seconds = fit$full_fit_runtime_seconds,
    stringsAsFactors = FALSE
  )

  for (
    occurrence_index in seq_along(
      audit$local_s
    )
  ) {

    qph_local_index <- qph_local_index + 1L

    qph_local_s_rows[[qph_local_index]] <- data.frame(
      Condition_id = condition_id,
      Species = condition$Species[[1L]],
      Sample_size = condition$Sample_size[[1L]],
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
    qph_audit_rows
  ) > 0L
) {
  do.call(
    rbind,
    qph_audit_rows
  )
} else {
  data.frame()
}

qph_local_s <- if (
  length(
    qph_local_s_rows
  ) > 0L
) {
  do.call(
    rbind,
    qph_local_s_rows
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
# SVM hypervolume / projection-classifier consistency QA
# ============================================================

svm_qa_rows <- list()
svm_qa_index <- 0L

svm_conditions <- fit_design[
  fit_design$Method ==
    "SVM",
  ,
  drop = FALSE
]

for (
  row_index in seq_len(
    nrow(
      svm_conditions
    )
  )
) {

  condition <- svm_conditions[
    row_index,
    ,
    drop = FALSE
  ]

  condition_id <- condition$Condition_id[[1L]]

  registry_row <- get_registry_row(
    condition_id
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

  fit <- get_model_fit(
    condition_id
  )

  svm_hv_points <- set_pc_names(
    fit$hypervolume@RandomPoints
  )

  svm_hv_inside <- predict_svm_in_chunks(
    fit$svm_projection_model,
    svm_hv_points,
    batch_size = svm_prediction_batch_size
  )

  inclusion_fraction <- mean(
    svm_hv_inside
  )

  svm_qa_index <- svm_qa_index + 1L

  svm_qa_rows[[svm_qa_index]] <- data.frame(
    Condition_id = condition_id,
    Species = condition$Species[[1L]],
    Sample_size = condition$Sample_size[[1L]],
    Random_points = nrow(
      svm_hv_points
    ),
    Random_points_predicted_inside = sum(
      svm_hv_inside
    ),
    Random_point_inclusion_fraction = inclusion_fraction,
    Projection_classifier_scale = TRUE,
    stringsAsFactors = FALSE
  )

  if (
    is.finite(
      inclusion_fraction
    ) &&
      inclusion_fraction < 0.99
  ) {
    warning(
      "SVM projection classifier accepted fewer than 99% of its Hypervolume ",
      "RandomPoints for ",
      condition_id,
      ": ",
      signif(
        inclusion_fraction,
        5
      )
    )
  }
}


svm_classifier_qa <- if (
  length(
    svm_qa_rows
  ) > 0L
) {
  do.call(
    rbind,
    svm_qa_rows
  )
} else {
  data.frame()
}

write_csv_safely(
  svm_classifier_qa,
  svm_classifier_qa_file
)


# ============================================================
# Model summary
# ============================================================

model_summary_rows <- list()

for (
  row_index in seq_len(
    nrow(
      fit_design
    )
  )
) {

  condition <- fit_design[
    row_index,
    ,
    drop = FALSE
  ]

  condition_id <- condition$Condition_id[[1L]]

  registry_row <- get_registry_row(
    condition_id
  )

  success <- (
    !is.null(
      registry_row
    ) &&
      isTRUE(
        registry_row$Success[[1L]]
      )
  )

  qph_k <- NA_integer_
  qph_mean_s <- NA_real_
  qph_scalar_h <- NA_real_
  qph_q <- NA_real_
  kde_bandwidth_1 <- NA_real_
  kde_bandwidth_2 <- NA_real_
  kde_bandwidth_3 <- NA_real_

  if (success) {

    fit <- get_model_fit(
      condition_id
    )

    if (
      identical(
        condition$Method[[1L]],
        "QPH"
      )
    ) {

      qph_k <- fit$qph_result$audit$K
      qph_mean_s <- fit$qph_result$audit$mean_s
      qph_scalar_h <- fit$qph_result$audit$baseline_scalar_h
      qph_q <- fit$qph_result$audit$q

    } else if (
      identical(
        condition$Method[[1L]],
        "Gaussian KDE"
      )
    ) {

      kde_bandwidth_numeric <- as.numeric(
        fit$kde_bandwidth
      )

      kde_bandwidth_1 <- kde_bandwidth_numeric[[1L]]
      kde_bandwidth_2 <- kde_bandwidth_numeric[[2L]]
      kde_bandwidth_3 <- kde_bandwidth_numeric[[3L]]
    }
  }

  model_summary_rows[[row_index]] <- data.frame(
    Condition_id = condition_id,
    Species = condition$Species[[1L]],
    Species_label = condition$Species_label[[1L]],
    Sample_size = condition$Sample_size[[1L]],
    Method = condition$Method[[1L]],
    Fit_seed = condition$Fit_seed[[1L]],
    Success = success,
    Hypervolume_volume = if (
      success
    ) {
      registry_row$Hypervolume_volume[[1L]]
    } else {
      NA_real_
    },
    Random_points = if (
      success
    ) {
      registry_row$Random_points[[1L]]
    } else {
      NA_integer_
    },
    Hypervolume_runtime_seconds = if (
      success
    ) {
      registry_row$Hypervolume_runtime_seconds[[1L]]
    } else {
      NA_real_
    },
    Projection_classifier_runtime_seconds = if (
      success
    ) {
      registry_row$Projection_classifier_runtime_seconds[[1L]]
    } else {
      NA_real_
    },
    Full_fit_runtime_seconds = if (
      success
    ) {
      registry_row$Full_fit_runtime_seconds[[1L]]
    } else {
      NA_real_
    },
    QPH_K = qph_k,
    QPH_mean_s = qph_mean_s,
    QPH_scalar_h = qph_scalar_h,
    QPH_q = qph_q,
    KDE_bandwidth_PC1 = kde_bandwidth_1,
    KDE_bandwidth_PC2 = kde_bandwidth_2,
    KDE_bandwidth_PC3 = kde_bandwidth_3,
    SVM_nu = if (
      identical(
        condition$Method[[1L]],
        "SVM"
      )
    ) {
      svm_nu
    } else {
      NA_real_
    },
    SVM_gamma = if (
      identical(
        condition$Method[[1L]],
        "SVM"
      )
    ) {
      svm_gamma
    } else {
      NA_real_
    },
    SVM_scale_factor = if (
      identical(
        condition$Method[[1L]],
        "SVM"
      )
    ) {
      svm_scale_factor
    } else {
      NA_real_
    },
    Error_message = if (
      !is.null(
        registry_row
      )
    ) {
      registry_row$Error_message[[1L]]
    } else {
      "No registry entry"
    },
    stringsAsFactors = FALSE
  )
}

model_summary <- do.call(
  rbind,
  model_summary_rows
)

rownames(
  model_summary
) <- NULL

write_csv_safely(
  model_summary,
  model_summary_file
)


# ============================================================
# Geographic projection helpers
# ============================================================

project_qph_to_landscape <- function(
    evaluation_points,
    occurrence_points,
    bandwidth,
    potential_threshold_raw,
    sd_count = 3,
    batch_size = 500L
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

  if (
    length(
      bandwidth
    ) != 3L ||
      any(
        !is.finite(
          bandwidth
        )
      ) ||
      any(
        bandwidth <= 0
      )
  ) {
    stop(
      "Invalid QPH projection bandwidth."
    )
  }

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

  potential <- rep(
    NA_real_,
    nrow(
      evaluation_points
    )
  )

  inside_candidate_region <- logical(
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

    batch_candidate <- (
      row_minimum <=
        sd_count^2
    )

    inside_candidate_region[
      idx
    ] <- batch_candidate

    if (any(batch_candidate)) {

      candidate_distance_squared <- distance_squared[
        batch_candidate,
        ,
        drop = FALSE
      ]

      candidate_row_minimum <- row_minimum[
        batch_candidate
      ]

      # Shifted weights avoid underflow without changing the weighted ratio.
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

      candidate_global_indices <- idx[
        batch_candidate
      ]

      potential[
        candidate_global_indices
      ] <- candidate_potential

      prediction[
        candidate_global_indices
      ] <- (
        candidate_potential <=
          potential_threshold_raw +
            projection_tolerance
      )
    }
  }

  list(
    prediction = prediction,
    potential = potential,
    inside_candidate_region = inside_candidate_region
  )
}


calculate_raw_gaussian_sum <- function(
    evaluation_points,
    occurrence_points,
    bandwidth,
    batch_size = 500L
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

  output <- numeric(
    nrow(
      evaluation_points
    )
  )

  inside_candidate_region <- logical(
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
        "Unexpected negative squared distances during KDE projection."
      )
    }

    row_minimum <- apply(
      distance_squared,
      1L,
      min
    )

    inside_candidate_region[
      idx
    ] <- (
      row_minimum <=
        baseline_sd_count^2
    )

    shifted_weights <- exp(
      -0.5 *
        sweep(
          distance_squared,
          1L,
          row_minimum,
          FUN = "-"
        )
    )

    output[
      idx
    ] <- (
      exp(
        -0.5 *
          row_minimum
      ) *
        rowSums(
          shifted_weights
        )
    )
  }

  list(
    raw_gaussian_sum = output,
    inside_candidate_region = inside_candidate_region
  )
}


calibrate_kde_raw_threshold <- function(
    hv,
    occurrence_points,
    bandwidth,
    n_calibration_points = 8L
) {

  occurrence_points <- set_pc_names(
    occurrence_points
  )

  bandwidth <- as.numeric(
    bandwidth
  )

  if (
    nrow(
      hv@RandomPoints
    ) < 1L
  ) {
    stop(
      "KDE hypervolume contains no retained random points."
    )
  }

  calculate_density_internal <- getFromNamespace(
    "calculate_density",
    "hypervolume"
  )

  order_index <- order(
    hv@ValueAtRandomPoints
  )

  chosen <- unique(
    round(
      seq(
        1,
        length(
          order_index
        ),
        length.out = min(
          n_calibration_points,
          length(
            order_index
          )
        )
      )
    )
  )

  chosen_rows <- order_index[
    chosen
  ]

  calibration_points <- set_pc_names(
    hv@RandomPoints[
      chosen_rows,
      ,
      drop = FALSE
    ]
  )

  raw_scores <- calculate_raw_gaussian_sum(
    evaluation_points = calibration_points,
    occurrence_points = occurrence_points,
    bandwidth = bandwidth,
    batch_size = max(
      1L,
      nrow(
        calibration_points
      )
    )
  )$raw_gaussian_sum

  n_occurrence <- nrow(
    occurrence_points
  )

  equal_weights <- rep(
    1 /
      n_occurrence,
    n_occurrence
  )

  exact_density <- vapply(
    seq_len(
      nrow(
        calibration_points
      )
    ),
    function(i) {

      calculate_density_internal(
        s = calibration_points[
          i,
        ],
        means = occurrence_points,
        kernel_sd = bandwidth,
        weight = equal_weights,
        chunksize = shared_chunk_size,
        verbose = FALSE
      )
    },
    numeric(1)
  )

  scale_factors <- (
    exact_density /
      raw_scores
  )

  scale_factors <- scale_factors[
    is.finite(
      scale_factors
    ) &
      scale_factors > 0
  ]

  if (
    length(
      scale_factors
    ) == 0L
  ) {
    stop(
      "Could not calibrate the Gaussian KDE projection threshold."
    )
  }

  scale_factor <- stats::median(
    scale_factors
  )

  relative_spread <- max(
    abs(
      scale_factors /
        scale_factor -
        1
    )
  )

  if (
    is.finite(
      relative_spread
    ) &&
      relative_spread >
        1e-6
  ) {
    warning(
      "KDE raw-score calibration was not perfectly proportional; ",
      "maximum relative spread = ",
      signif(
        relative_spread,
        4
      ),
      "."
    )
  }

  retained_density_threshold <- min(
    hv@ValueAtRandomPoints,
    na.rm = TRUE
  )

  raw_threshold <- (
    retained_density_threshold /
      scale_factor
  )

  list(
    raw_threshold = raw_threshold,
    density_threshold = retained_density_threshold,
    density_per_raw_score = scale_factor,
    calibration_relative_spread = relative_spread
  )
}


project_kde_to_landscape <- function(
    evaluation_points,
    occurrence_points,
    hv,
    bandwidth
) {

  calibration <- calibrate_kde_raw_threshold(
    hv = hv,
    occurrence_points = occurrence_points,
    bandwidth = bandwidth
  )

  scores <- calculate_raw_gaussian_sum(
    evaluation_points = evaluation_points,
    occurrence_points = occurrence_points,
    bandwidth = bandwidth,
    batch_size = projection_batch_size
  )

  prediction <- (
    scores$inside_candidate_region &
      scores$raw_gaussian_sum >
        calibration$raw_threshold
  )

  list(
    prediction = prediction,
    raw_gaussian_sum = scores$raw_gaussian_sum,
    inside_candidate_region = scores$inside_candidate_region,
    calibration = calibration
  )
}


# ============================================================
# Disconnected environmental gap classification
# ============================================================

classify_disconnected_environment <- function(points) {

  points <- set_pc_names(
    points
  )

  mode_sds <- as.numeric(
    disconnected_definition$mode_sds
  )

  mode_A_mean <- as.numeric(
    disconnected_definition$mode_A_mean
  )

  mode_B_mean <- as.numeric(
    disconnected_definition$mode_B_mean
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

  radius <- as.numeric(
    disconnected_definition$truth_radius_sd_units
  )

  separation <- as.numeric(
    disconnected_definition$mode_separation_sd_units
  )

  t_margin <- (
    radius /
      separation
  )

  inside_A <- (
    distance_A <=
      radius +
        projection_tolerance
  )

  inside_B <- (
    distance_B <=
      radius +
        projection_tolerance
  )

  inside_true <- (
    inside_A |
      inside_B
  )

  inside_gap <- (
    !inside_true &
      t_value >
        t_margin &
      t_value <
        (
          1 -
            t_margin
        ) &
      perpendicular_distance <=
        radius *
          gap_corridor_radius_multiplier
  )

  list(
    inside_A = inside_A,
    inside_B = inside_B,
    inside_true = inside_true,
    inside_gap = inside_gap
  )
}


disconnected_environment_class <- classify_disconnected_environment(
  landscape_pc
)

disconnected_gap_mask_valid <- disconnected_environment_class$inside_gap

disconnected_mode_values_all <- terra::values(
  disconnected_mode_raster,
  mat = FALSE
)

disconnected_mode_values_valid <- disconnected_mode_values_all[
  valid_pc_cells
]


# ============================================================
# Projection checkpoint registry
# ============================================================

empty_projection_registry <- function() {

  data.frame(
    Condition_id = character(0),
    Species = character(0),
    Species_label = character(0),
    Sample_size = integer(0),
    Method = character(0),
    Success = logical(0),
    Raster_file = character(0),
    Projection_runtime_seconds = numeric(0),
    Predicted_cells = integer(0),
    Candidate_cells = integer(0),
    KDE_calibration_relative_spread = numeric(0),
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

  projection_checkpoint <- readRDS(
    projection_registry_file
  )

  if (
    !identical(
      projection_checkpoint$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Incompatible Script-13 geographic projection checkpoint."
    )
  }

  projection_registry <- projection_checkpoint$registry

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


get_projection_registry_row <- function(
    condition_id
) {

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
      "Projection registry contains duplicate condition: ",
      condition_id
    )
  }

  rows
}


replace_projection_registry_row <- function(
    new_row
) {

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


# ============================================================
# Geographic projections
# ============================================================

for (
  fit_index in seq_len(
    nrow(
      fit_design
    )
  )
) {

  condition <- fit_design[
    fit_index,
    ,
    drop = FALSE
  ]

  condition_id <- condition$Condition_id[[1L]]
  species_name <- condition$Species[[1L]]
  sample_size <- condition$Sample_size[[1L]]
  method_name <- condition$Method[[1L]]

  fit_registry_row <- get_registry_row(
    condition_id
  )

  if (
    is.null(
      fit_registry_row
    ) ||
      !isTRUE(
        fit_registry_row$Success[[1L]]
      )
  ) {

    projection_row <- data.frame(
      Condition_id = condition_id,
      Species = species_name,
      Species_label = condition$Species_label[[1L]],
      Sample_size = sample_size,
      Method = method_name,
      Success = FALSE,
      Raster_file = NA_character_,
      Projection_runtime_seconds = NA_real_,
      Predicted_cells = NA_integer_,
      Candidate_cells = NA_integer_,
      KDE_calibration_relative_spread = NA_real_,
      Error_message = "Estimator fit unavailable",
      stringsAsFactors = FALSE
    )

    replace_projection_registry_row(
      projection_row
    )

    save_projection_checkpoint()

    next
  }

  raster_file <- projection_raster_path(
    condition_id
  )

  existing_projection <- get_projection_registry_row(
    condition_id
  )

  if (
    !is.null(
      existing_projection
    ) &&
      isTRUE(
        existing_projection$Success[[1L]]
      ) &&
      file.exists(
        raster_file
      )
  ) {

    message(
      "Reusing geographic projection ",
      fit_index,
      "/",
      nrow(
        fit_design
      ),
      ": ",
      condition_id
    )

    next
  }

  if (
    !is.null(
      existing_projection
    ) &&
      !isTRUE(
        existing_projection$Success[[1L]]
      ) &&
      !retry_failed_projections
  ) {
    next
  }

  fit <- get_model_fit(
    condition_id
  )

  occurrence_points <- set_pc_names(
    locked_inputs$occurrences$species[[
      species_name
    ]]$subsets[[
      as.character(
        sample_size
      )
    ]]$pc
  )

  message(
    "Projecting ",
    fit_index,
    "/",
    nrow(
      fit_design
    ),
    ": ",
    condition_id
  )

  projection_start_time <- proc.time()[[
    "elapsed"
  ]]

  projection_result <- tryCatch(
    {

      if (
        identical(
          method_name,
          "QPH"
        )
      ) {

        projected <- project_qph_to_landscape(
          evaluation_points = landscape_pc,
          occurrence_points = occurrence_points,
          bandwidth = fit$qph_result$bandwidth,
          potential_threshold_raw = fit$qph_result$potential_threshold_raw,
          sd_count = baseline_sd_count,
          batch_size = projection_batch_size
        )

        list(
          prediction = projected$prediction,
          candidate_cells = sum(
            projected$inside_candidate_region
          ),
          kde_calibration_relative_spread = NA_real_
        )

      } else if (
        identical(
          method_name,
          "Gaussian KDE"
        )
      ) {

        projected <- project_kde_to_landscape(
          evaluation_points = landscape_pc,
          occurrence_points = occurrence_points,
          hv = fit$hypervolume,
          bandwidth = fit$kde_bandwidth
        )

        list(
          prediction = projected$prediction,
          candidate_cells = sum(
            projected$inside_candidate_region
          ),
          kde_calibration_relative_spread = (
            projected$calibration$calibration_relative_spread
          )
        )

      } else if (
        identical(
          method_name,
          "SVM"
        )
      ) {

        prediction <- predict_svm_in_chunks(
          fit$svm_projection_model,
          landscape_pc,
          batch_size = svm_prediction_batch_size
        )

        list(
          prediction = prediction,
          candidate_cells = NA_integer_,
          kde_calibration_relative_spread = NA_real_
        )

      } else {

        stop(
          "Unknown method: ",
          method_name
        )
      }
    },
    error = function(e) {

      list(
        prediction = NULL,
        candidate_cells = NA_integer_,
        kde_calibration_relative_spread = NA_real_,
        error_message = conditionMessage(
          e
        )
      )
    }
  )

  projection_runtime_seconds <- (
    proc.time()[[
      "elapsed"
    ]] -
      projection_start_time
  )

  projection_success <- (
    !is.null(
      projection_result$prediction
    ) &&
      length(
        projection_result$prediction
      ) ==
        nrow(
          landscape_pc
        )
  )

  if (projection_success) {

    prediction_raster <- make_binary_raster(
      template = pc_stack[[1L]],
      valid_cells = valid_pc_cells,
      prediction_valid = projection_result$prediction
    )

    terra::writeRaster(
      prediction_raster,
      raster_file,
      overwrite = TRUE,
      datatype = "INT1U",
      wopt = list(
        gdal = c(
          "COMPRESS=LZW"
        )
      )
    )
  }

  projection_row <- data.frame(
    Condition_id = condition_id,
    Species = species_name,
    Species_label = condition$Species_label[[1L]],
    Sample_size = sample_size,
    Method = method_name,
    Success = projection_success,
    Raster_file = if (
      projection_success
    ) {
      normalizePath(
        raster_file,
        winslash = "/",
        mustWork = TRUE
      )
    } else {
      NA_character_
    },
    Projection_runtime_seconds = projection_runtime_seconds,
    Predicted_cells = if (
      projection_success
    ) {
      sum(
        projection_result$prediction
      )
    } else {
      NA_integer_
    },
    Candidate_cells = projection_result$candidate_cells,
    KDE_calibration_relative_spread = (
      projection_result$kde_calibration_relative_spread
    ),
    Error_message = if (
      projection_success
    ) {
      NA_character_
    } else if (
      !is.null(
        projection_result$error_message
      )
    ) {
      projection_result$error_message
    } else {
      "Projection failed without a recorded error."
    },
    stringsAsFactors = FALSE
  )

  replace_projection_registry_row(
    projection_row
  )

  save_projection_checkpoint()
}


projection_registry <- projection_registry[
  match(
    fit_design$Condition_id,
    projection_registry$Condition_id
  ),
  ,
  drop = FALSE
]

save_projection_checkpoint()


# ============================================================
# Geographic metric calculation
# ============================================================

calculate_recovery_metrics <- function(
    truth_raster,
    prediction_raster,
    occurrence_xy,
    species_name,
    sample_size,
    method_name
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

  jaccard <- (
    tp_area /
      (
        tp_area +
          fp_area +
          fn_area
      )
  )

  sorensen <- (
    2 *
      tp_area /
      (
        2 *
          tp_area +
          fp_area +
          fn_area
      )
  )

  omission <- if (
    true_area > 0
  ) {
    fn_area /
      true_area
  } else {
    NA_real_
  }

  commission <- if (
    predicted_area > 0
  ) {
    fp_area /
      predicted_area
  } else {
    NA_real_
  }

  sensitivity <- if (
    true_area > 0
  ) {
    tp_area /
      true_area
  } else {
    NA_real_
  }

  specificity <- if (
    (
      tn_area +
        fp_area
    ) > 0
  ) {
    tn_area /
      (
        tn_area +
          fp_area
      )
  } else {
    NA_real_
  }

  precision <- if (
    predicted_area > 0
  ) {
    tp_area /
      predicted_area
  } else {
    NA_real_
  }

  balanced_accuracy <- mean(
    c(
      sensitivity,
      specificity
    ),
    na.rm = TRUE
  )

  relative_area_error <- if (
    true_area > 0
  ) {
    (
      predicted_area -
        true_area
    ) /
      true_area
  } else {
    NA_real_
  }

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

  sampled_cell_mask <- (
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
      !sampled_cell_mask
  )

  sampled_true <- (
    valid &
      truth &
      sampled_cell_mask
  )

  unsampled_true_area <- sum(
    cell_area_all[
      unsampled_true
    ]
  )

  unsampled_true_recovered_area <- sum(
    cell_area_all[
      unsampled_true &
        prediction
    ]
  )

  unsampled_true_recovery <- if (
    unsampled_true_area > 0
  ) {
    unsampled_true_recovered_area /
      unsampled_true_area
  } else {
    NA_real_
  }

  sampled_true_area <- sum(
    cell_area_all[
      sampled_true
    ]
  )

  sampled_true_recovered_area <- sum(
    cell_area_all[
      sampled_true &
        prediction
    ]
  )

  sampled_cell_recovery <- if (
    sampled_true_area > 0
  ) {
    sampled_true_recovered_area /
      sampled_true_area
  } else {
    NA_real_
  }

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

  centroid_displacement_km <- haversine_km(
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
  )

  data.frame(
    Species = species_name,
    Species_label = unname(
      species_labels[
        species_name
      ]
    ),
    Sample_size = sample_size,
    Method = method_name,
    Jaccard_area_weighted = jaccard,
    Sorensen_area_weighted = sorensen,
    Omission_error_area_weighted = omission,
    Commission_error_area_weighted = commission,
    Sensitivity_area_weighted = sensitivity,
    Specificity_area_weighted = specificity,
    Precision_area_weighted = precision,
    Balanced_accuracy_area_weighted = balanced_accuracy,
    True_area_km2 = true_area,
    Predicted_area_km2 = predicted_area,
    Relative_geographic_area_error = relative_area_error,
    Geographic_centroid_displacement_km = centroid_displacement_km,
    True_component_count = count_components(
      truth_raster
    ),
    Predicted_component_count = count_components(
      prediction_raster
    ),
    Unsampled_true_area_km2 = unsampled_true_area,
    Unsampled_true_recovered_area_km2 = unsampled_true_recovered_area,
    Unsampled_true_recovery = unsampled_true_recovery,
    Sampled_occurrence_cell_recovery = sampled_cell_recovery,
    TP_area_km2 = tp_area,
    FP_area_km2 = fp_area,
    FN_area_km2 = fn_area,
    TN_area_km2 = tn_area,
    stringsAsFactors = FALSE
  )
}


metric_rows <- list()
metric_index <- 0L
structural_rows <- list()
structural_index <- 0L

for (
  fit_index in seq_len(
    nrow(
      fit_design
    )
  )
) {

  condition <- fit_design[
    fit_index,
    ,
    drop = FALSE
  ]

  condition_id <- condition$Condition_id[[1L]]
  species_name <- condition$Species[[1L]]
  sample_size <- condition$Sample_size[[1L]]
  method_name <- condition$Method[[1L]]

  projection_row <- get_projection_registry_row(
    condition_id
  )

  if (
    is.null(
      projection_row
    ) ||
      !isTRUE(
        projection_row$Success[[1L]]
      )
  ) {
    next
  }

  raster_file <- projection_raster_path(
    condition_id
  )

  if (!file.exists(raster_file)) {
    stop(
      "Projection registry says success but raster is missing:\n  ",
      raster_file
    )
  }

  prediction_raster <- terra::rast(
    raster_file
  )

  truth_raster <- truth_rasters[[
    species_name
  ]]

  occurrence_xy <- locked_inputs$occurrences$species[[
    species_name
  ]]$subsets[[
    as.character(
      sample_size
    )
  ]]$xy

  metric_index <- metric_index + 1L

  base_metrics <- calculate_recovery_metrics(
    truth_raster = truth_raster,
    prediction_raster = prediction_raster,
    occurrence_xy = occurrence_xy,
    species_name = species_name,
    sample_size = sample_size,
    method_name = method_name
  )

  base_metrics$Condition_id <- condition_id
  base_metrics$Projection_runtime_seconds <- (
    projection_row$Projection_runtime_seconds[[1L]]
  )

  metric_rows[[metric_index]] <- base_metrics

  if (
    identical(
      species_name,
      "Disconnected"
    )
  ) {

    prediction_values <- terra::values(
      prediction_raster,
      mat = FALSE
    )

    prediction_valid <- (
      prediction_values[
        valid_pc_cells
      ] == 1
    )

    mode_A_truth <- (
      disconnected_mode_values_valid == 1L
    )

    mode_B_truth <- (
      disconnected_mode_values_valid == 2L
    )

    weighted_recovery <- function(mask) {

      denominator <- sum(
        cell_area_valid[
          mask
        ],
        na.rm = TRUE
      )

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

      sum(
        cell_area_valid[
          mask &
            prediction_valid
        ],
        na.rm = TRUE
      ) /
        denominator
    }

    gap_area_total <- sum(
      cell_area_valid[
        disconnected_gap_mask_valid
      ],
      na.rm = TRUE
    )

    gap_area_predicted <- sum(
      cell_area_valid[
        disconnected_gap_mask_valid &
          prediction_valid
      ],
      na.rm = TRUE
    )

    gap_prediction_rate <- if (
      sum(
        disconnected_gap_mask_valid
      ) > 0L
    ) {
      mean(
        prediction_valid[
          disconnected_gap_mask_valid
        ]
      )
    } else {
      NA_real_
    }

    structural_index <- structural_index + 1L

    structural_rows[[structural_index]] <- data.frame(
      Condition_id = condition_id,
      Species = species_name,
      Sample_size = sample_size,
      Method = method_name,
      Mode_A_geographic_recovery = weighted_recovery(
        mode_A_truth
      ),
      Mode_B_geographic_recovery = weighted_recovery(
        mode_B_truth
      ),
      Environmental_gap_landscape_cells = sum(
        disconnected_gap_mask_valid
      ),
      Predicted_gap_landscape_cells = sum(
        disconnected_gap_mask_valid &
          prediction_valid
      ),
      Gap_prediction_rate = gap_prediction_rate,
      Environmental_gap_area_km2 = gap_area_total,
      Predicted_area_in_environmental_gap_km2 = gap_area_predicted,
      stringsAsFactors = FALSE
    )
  }
}


geographic_metrics <- if (
  length(
    metric_rows
  ) > 0L
) {
  do.call(
    rbind,
    metric_rows
  )
} else {
  data.frame()
}

if (
  nrow(
    geographic_metrics
  ) > 0L
) {

  geographic_metrics <- geographic_metrics[
    match(
      fit_design$Condition_id,
      geographic_metrics$Condition_id
    ),
    ,
    drop = FALSE
  ]

  geographic_metrics <- geographic_metrics[
    !is.na(
      geographic_metrics$Condition_id
    ),
    ,
    drop = FALSE
  ]
}

write_csv_safely(
  geographic_metrics,
  geographic_metrics_file
)


disconnected_structural_metrics <- if (
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
  disconnected_structural_metrics,
  disconnected_structural_file
)


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

    failure_index <- failure_index + 1L

    failure_rows[[failure_index]] <- data.frame(
      Analysis_stage = "Model fitting",
      Condition_id = failed_models$Condition_id[[
        row_index
      ]],
      Species = failed_models$Species[[
        row_index
      ]],
      Sample_size = failed_models$Sample_size[[
        row_index
      ]],
      Method = failed_models$Method[[
        row_index
      ]],
      Error_message = failed_models$Error_message[[
        row_index
      ]],
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

    failure_index <- failure_index + 1L

    failure_rows[[failure_index]] <- data.frame(
      Analysis_stage = "Geographic projection",
      Condition_id = failed_projections$Condition_id[[
        row_index
      ]],
      Species = failed_projections$Species[[
        row_index
      ]],
      Sample_size = failed_projections$Sample_size[[
        row_index
      ]],
      Method = failed_projections$Method[[
        row_index
      ]],
      Error_message = failed_projections$Error_message[[
        row_index
      ]],
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
    Species = character(0),
    Sample_size = integer(0),
    Method = character(0),
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
    script = "13_Virtual_Species_Baseline_Fits_and_Geography.R",
    analysis_settings_hash = analysis_settings_hash,
    locked_design_hash = locked_design_hash,
    qph_core_version = QPH_CORE_VERSION,
    qph_core_md5 = qph_core_md5,
    completed_at = as.character(
      Sys.time()
    ),
    method_colours = method_colours,
    true_region_colour = true_region_colour,
    occurrence_colour = occurrence_colour
  ),
  analysis_settings = analysis_settings,
  fit_design = fit_design,
  model_registry = model_registry,
  model_summary = model_summary,
  qph_audit_summary = qph_audit_summary,
  qph_local_s = qph_local_s,
  svm_classifier_qa = svm_classifier_qa,
  projection_registry = projection_registry,
  geographic_metrics = geographic_metrics,
  disconnected_structural_metrics = disconnected_structural_metrics,
  failures = failure_table
)

saveRDS(
  final_results,
  final_results_file,
  version = 3
)


# ============================================================
# Analysis notes and session information
# ============================================================

analysis_notes <- c(
  "Revised virtual-species baseline fits and geographic validation",
  "==============================================================",
  "",
  "Species:",
  "  Unimodal Gaussian-PCA",
  "  Disconnected bimodal",
  "",
  paste0(
    "Occurrence sample sizes: ",
    paste(
      sample_sizes,
      collapse = ", "
    )
  ),
  "",
  "QPH baseline:",
  "  sqrt-NB bandwidth",
  "  K = round(sqrt(n))",
  "  h = sqrt(mean(s_i))",
  "  q = 0.99",
  "  samples.per.point = 100",
  "  sd.count = 3",
  "",
  "Gaussian KDE baseline:",
  "  own current Silverman bandwidth",
  "  probability quantile = 0.95",
  "  samples.per.point = 100",
  "  sd.count = 3",
  "",
  "SVM baseline:",
  "  nu = 0.01",
  "  gamma = 0.5",
  "  scale.factor = 1",
  "  geographic classifier scale = TRUE",
  "",
  "QPH and KDE geographic score surfaces are calculated independently",
  "because they no longer share a bandwidth.",
  "",
  "Geographic truth metrics are area weighted.",
  "Disconnected structural diagnostics retain the two true mode recoveries",
  "and the deliberately unsuitable between-mode corridor diagnostic.",
  "",
  "Environmental geometry and persistent homology are NOT run in this script.",
  "",
  paste0(
    "Locked input design hash: ",
    locked_design_hash
  ),
  paste0(
    "Script-13 analysis hash: ",
    analysis_settings_hash
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
  "13_Virtual_Species_Baseline_Fits_and_Geography.R complete."
)

message(
  "Successful model fits: ",
  sum(
    model_registry$Success
  ),
  " / ",
  nrow(
    model_registry
  )
)

message(
  "Successful geographic projections: ",
  sum(
    projection_registry$Success
  ),
  " / ",
  nrow(
    projection_registry
  )
)

message(
  "QPH audit conditions: ",
  nrow(
    qph_audit_summary
  ),
  " / 6"
)

message(
  "Failures recorded: ",
  nrow(
    failure_table
  )
)

message(
  "Model summary:\n  ",
  normalizePath(
    model_summary_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "Geographic metrics:\n  ",
  normalizePath(
    geographic_metrics_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "Final results object:\n  ",
  normalizePath(
    final_results_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "============================================================"
)
