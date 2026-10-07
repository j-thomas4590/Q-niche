# ============================================================
# 19_Acacia_Baseline_Fits.R
# ============================================================
#
# PURPOSE
# -------
# Fit the revised baseline environmental hypervolumes for the FIVE locked
# empirical Acacia species in the exact shared PC1-PC3 occurrence space
# established by Script 18.
#


rm(list = ls())
gc()


# ============================================================
# Packages
# ============================================================

required_packages <- c(
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

library(hypervolume)
library(e1071)


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
  "Acacia_sqrtNB_q099"
)

locked_input_directory <- file.path(
  analysis_root_directory,
  "00_Locked_Inputs"
)

output_directory <- file.path(
  analysis_root_directory,
  "01_Baseline_Fits"
)

model_directory <- file.path(
  output_directory,
  "model_objects"
)

table_directory <- file.path(
  output_directory,
  "tables"
)

for (directory in c(
  output_directory,
  model_directory,
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
      as.character(QPH_CORE_VERSION),
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
# Locked input files
# ============================================================

locked_archive_file <- file.path(
  locked_input_directory,
  "acacia_empirical_inputs_authoritative_LOCKED.rds"
)

locked_settings_file <- file.path(
  locked_input_directory,
  "locked_input_settings.rds"
)

required_input_files <- c(
  locked_archive_file,
  locked_settings_file
)

missing_input_files <- required_input_files[
  !file.exists(required_input_files)
]

if (length(missing_input_files) > 0L) {
  stop(
    "Missing Script-18 locked input file(s):\n  ",
    paste(
      missing_input_files,
      collapse = "\n  "
    ),
    "\nRun 18_Acacia_Locked_Inputs.R first."
  )
}


# ============================================================
# Locked empirical design
# ============================================================

expected_species <- c(
  "Acacia georginae",
  "Acacia tumida",
  "Acacia kempeana",
  "Acacia calamifolia",
  "Acacia saligna"
)

expected_species_codes <- c(
  "Acacia georginae" = "georginae",
  "Acacia tumida" = "tumida",
  "Acacia kempeana" = "kempeana",
  "Acacia calamifolia" = "calamifolia",
  "Acacia saligna" = "saligna"
)

expected_pc_names <- c(
  "PC1",
  "PC2",
  "PC3"
)

method_order <- c(
  "QPH",
  "Gaussian KDE",
  "SVM"
)

method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)

occurrence_colour <- "#111111"


# ============================================================
# Baseline estimator settings
# ============================================================

baseline_samples_per_point <- 100L
baseline_sd_count <- 3

qph_baseline_q <- 0.99

kde_baseline_quantile <- 0.95
kde_bandwidth_method <- "silverman"

svm_nu <- 0.01
svm_gamma <- 0.50
svm_scale_factor <- 1

# The package's SVM sampler uses support vectors as sampling centres.
# We pass samples.per.point = 100 directly without trying to compensate for
# the number of support vectors.
svm_sampling_effort_mode <- "same_argument"

# Computational batching only.
shared_chunk_size <- 100L
potential_batch_size <- 500L

# Preserve the original empirical seed family.
master_seed <- 260806L

resume_from_checkpoint <- TRUE
retry_failed_fits <- TRUE

show_progress_messages <- TRUE

expected_hypervolume_version <- "3.1.6"


# ============================================================
# Output files
# ============================================================

checkpoint_file <- file.path(
  output_directory,
  "acacia_baseline_fit_checkpoint.rds"
)

registry_file <- file.path(
  output_directory,
  "acacia_baseline_model_registry.rds"
)

registry_csv_file <- file.path(
  table_directory,
  "acacia_baseline_model_registry.csv"
)

fit_summary_file <- file.path(
  table_directory,
  "acacia_baseline_fit_summary.csv"
)

failure_file <- file.path(
  table_directory,
  "acacia_baseline_fit_failures.csv"
)

bandwidth_file <- file.path(
  table_directory,
  "acacia_baseline_bandwidths.csv"
)

qph_audit_file <- file.path(
  table_directory,
  "acacia_QPH_audit_summary.csv"
)

qph_local_s_file <- file.path(
  table_directory,
  "acacia_QPH_local_s.csv"
)

qph_threshold_file <- file.path(
  table_directory,
  "acacia_QPH_thresholds.csv"
)

kde_audit_file <- file.path(
  table_directory,
  "acacia_KDE_audit.csv"
)

svm_audit_file <- file.path(
  table_directory,
  "acacia_SVM_parameter_audit.csv"
)

svm_support_vector_file <- file.path(
  table_directory,
  "acacia_SVM_support_vectors.csv"
)

model_manifest_file <- file.path(
  table_directory,
  "acacia_baseline_model_manifest.csv"
)

analysis_settings_file <- file.path(
  output_directory,
  "analysis_settings.rds"
)

run_metadata_file <- file.path(
  output_directory,
  "acacia_baseline_fits_run_metadata.rds"
)

final_results_file <- file.path(
  output_directory,
  "acacia_baseline_fits_sqrtNB_q099.rds"
)

parameter_notes_file <- file.path(
  output_directory,
  "ACACIA_BASELINE_PARAMETER_NOTES.txt"
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
    return(NA_character_)
  }

  unname(
    tools::md5sum(path)
  )
}


hash_r_object <- function(x) {

  temporary_file <- tempfile(
    fileext = ".rds"
  )

  on.exit(
    unlink(temporary_file),
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


validate_pc_matrix <- function(
    x,
    object_name
) {

  x <- as.matrix(x)
  storage.mode(x) <- "double"

  if (nrow(x) < 3L) {
    stop(
      object_name,
      " must contain at least three observations."
    )
  }

  if (ncol(x) != 3L) {
    stop(
      object_name,
      " must contain exactly three columns."
    )
  }

  if (any(!is.finite(x))) {
    stop(
      object_name,
      " contains missing or non-finite values."
    )
  }

  if (!identical(colnames(x), expected_pc_names)) {
    stop(
      object_name,
      " columns must be exactly PC1, PC2 and PC3."
    )
  }

  x
}


species_code <- function(species_name) {

  if (!species_name %in% expected_species) {
    stop(
      "Unknown species: ",
      species_name
    )
  }

  unname(
    expected_species_codes[[species_name]]
  )
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


model_key <- function(
    species_name,
    method_name
) {

  paste(
    species_code(species_name),
    method_code(method_name),
    sep = "__"
  )
}


model_file_path <- function(
    species_name,
    method_name
) {

  file.path(
    model_directory,
    paste0(
      model_key(
        species_name,
        method_name
      ),
      ".rds"
    )
  )
}


prediction_to_inside <- function(prediction) {

  if (is.logical(prediction)) {
    return(
      as.logical(prediction)
    )
  }

  if (is.factor(prediction)) {
    prediction <- as.character(prediction)
  }

  if (is.character(prediction)) {

    lower_prediction <- tolower(
      prediction
    )

    inside <- lower_prediction %in%
      c(
        "true",
        "1",
        "inside",
        "in",
        "yes"
      )

    outside <- lower_prediction %in%
      c(
        "false",
        "0",
        "outside",
        "out",
        "no"
      )

    if (!all(inside | outside)) {
      stop(
        "Could not interpret one-class SVM predictions."
      )
    }

    return(inside)
  }

  numeric_prediction <- suppressWarnings(
    as.numeric(prediction)
  )

  if (
    any(!is.finite(numeric_prediction)) ||
      !all(
        numeric_prediction %in%
          c(
            0,
            1
          )
      )
  ) {
    stop(
      "Could not interpret one-class SVM predictions."
    )
  }

  numeric_prediction == 1
}


extract_scale_component <- function(
    svm_model,
    component_name,
    dimensionality,
    axis_names
) {

  value <- svm_model[[component_name]]

  if (is.null(value)) {
    return(
      stats::setNames(
        rep(
          NA_real_,
          dimensionality
        ),
        axis_names
      )
    )
  }

  value <- as.numeric(value)

  if (length(value) != dimensionality) {
    return(
      stats::setNames(
        rep(
          NA_real_,
          dimensionality
        ),
        axis_names
      )
    )
  }

  stats::setNames(
    value,
    axis_names
  )
}


# ============================================================
# Load and validate Script-18 locked inputs
# ============================================================

locked_inputs <- readRDS(
  locked_archive_file
)

locked_settings <- readRDS(
  locked_settings_file
)

locked_design_hash <- locked_settings$locked_design_hash
locked_archive_md5 <- locked_settings$locked_archive_md5

if (
  is.null(locked_design_hash) ||
    is.null(locked_archive_md5)
) {
  stop(
    "Script-18 locked settings are missing required provenance hashes."
  )
}

if (
  !identical(
    safe_md5(
      locked_archive_file
    ),
    locked_archive_md5
  )
) {
  stop(
    "The locked Acacia archive MD5 no longer matches Script-18 settings."
  )
}

if (
  !identical(
    as.character(
      locked_settings$selected_species
    ),
    expected_species
  )
) {
  stop(
    "Script-18 species order differs from the locked empirical design."
  )
}

if (
  !identical(
    as.character(
      locked_settings$retained_pcs
    ),
    expected_pc_names
  )
) {
  stop(
    "Script-18 retained PCA axes are not exactly PC1-PC3."
  )
}

if (isTRUE(locked_settings$qph_parameter_dependence)) {
  stop(
    "Script-18 unexpectedly records QPH parameter dependence."
  )
}

species_matrices <- locked_inputs$species_pca_matrices

if (
  is.null(species_matrices) ||
    !identical(
      names(species_matrices),
      expected_species
    )
) {
  stop(
    "Locked species PCA matrices are missing or out of order."
  )
}

for (species_name in expected_species) {

  species_matrices[[species_name]] <- validate_pc_matrix(
    species_matrices[[species_name]],
    paste0(
      species_name,
      " locked PC matrix"
    )
  )
}

locked_counts <- vapply(
  expected_species,
  function(species_name) {
    nrow(
      species_matrices[[species_name]]
    )
  },
  integer(1)
)

if (
  !identical(
    as.integer(locked_counts),
    as.integer(
      locked_settings$final_species_counts_named[
        expected_species
      ]
    )
  )
) {
  stop(
    "Species PC-matrix row counts differ from Script-18 locked counts."
  )
}


# ============================================================
# Package / environment information
# ============================================================

installed_hypervolume_version <- as.character(
  utils::packageVersion(
    "hypervolume"
  )
)

installed_e1071_version <- as.character(
  utils::packageVersion(
    "e1071"
  )
)

if (
  !identical(
    installed_hypervolume_version,
    expected_hypervolume_version
  )
) {
  warning(
    "Installed hypervolume version is ",
    installed_hypervolume_version,
    "; the manuscript environment previously recorded ",
    expected_hypervolume_version,
    ". The actual installed version is recorded in all outputs."
  )
}


# ============================================================
# Locked baseline settings hash
# ============================================================

analysis_settings <- list(
  script = "19_Acacia_Baseline_Fits.R",
  analysis_branch = "Acacia_sqrtNB_q099",
  locked_design_hash = locked_design_hash,
  locked_archive_md5 = locked_archive_md5,
  qph_core_version = QPH_CORE_VERSION,
  qph_core_md5 = qph_core_md5,
  species = expected_species,
  methods = method_order,
  dimensionality = 3L,
  samples_per_point = baseline_samples_per_point,
  qph = list(
    bandwidth = "sqrtNB",
    bandwidth_label = (
      "Nasios-Bors-derived square-root local-distance bandwidth"
    ),
    q = qph_baseline_q,
    sd_count = baseline_sd_count,
    sampling_chunk_size = shared_chunk_size,
    potential_batch_size = potential_batch_size
  ),
  gaussian_kde = list(
    bandwidth = "hypervolume current Silverman",
    quantile = kde_baseline_quantile,
    quantile_type = "probability",
    sd_count = baseline_sd_count,
    chunk_size = shared_chunk_size
  ),
  svm = list(
    nu = svm_nu,
    gamma = svm_gamma,
    scale_factor = svm_scale_factor,
    samples_per_point = baseline_samples_per_point,
    sampling_effort_mode = svm_sampling_effort_mode,
    audit_model_internal_scaling = TRUE,
    kernel = "radial"
  ),
  master_seed = master_seed,
  seed_rule = paste(
    "QPH and Gaussian KDE share master_seed + species_index*1000 + 10;",
    "SVM uses master_seed + species_index*1000 + 20"
  ),
  method_colours = method_colours,
  occurrence_colour = occurrence_colour
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

if (file.exists(analysis_settings_file)) {

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
      "Existing Script-19 outputs were created with different inputs or ",
      "baseline settings. Archive/remove 01_Baseline_Fits before starting ",
      "the current revised analysis."
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
# Fit-design table and fixed seeds
# ============================================================

fit_design_rows <- list()
fit_design_index <- 0L

for (
  species_index in seq_along(
    expected_species
  )
) {

  species_name <- expected_species[[species_index]]

  matched_qph_kde_seed <- as.integer(
    master_seed +
      species_index *
        1000L +
      10L
  )

  svm_seed <- as.integer(
    master_seed +
      species_index *
        1000L +
      20L
  )

  for (
    method_name in method_order
  ) {

    fit_design_index <- fit_design_index + 1L

    fit_design_rows[[fit_design_index]] <- data.frame(
      Condition_id = model_key(
        species_name,
        method_name
      ),
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Method = method_name,
      Occurrence_count = nrow(
        species_matrices[[species_name]]
      ),
      Sampling_seed = if (
        method_name %in%
          c(
            "QPH",
            "Gaussian KDE"
          )
      ) {
        matched_qph_kde_seed
      } else {
        svm_seed
      },
      stringsAsFactors = FALSE
    )
  }
}

fit_design <- do.call(
  rbind,
  fit_design_rows
)

rownames(fit_design) <- NULL

if (nrow(fit_design) != 15L) {
  stop(
    "Expected exactly 15 Acacia baseline species-method conditions."
  )
}


# ============================================================
# SVM audit helpers
# ============================================================

fit_audit_svm_model <- function(
    occurrence_points
) {

  e1071::svm(
    x = occurrence_points,
    y = NULL,
    type = "one-classification",
    nu = svm_nu,
    gamma = svm_gamma,
    scale = TRUE,
    kernel = "radial"
  )
}


calculate_svm_sampling_audit <- function(
    occurrence_points,
    svm_model
) {

  occurrence_points <- validate_pc_matrix(
    occurrence_points,
    "occurrence_points"
  )

  dimensionality <- ncol(
    occurrence_points
  )

  axis_names <- colnames(
    occurrence_points
  )

  support_vector_indices <- as.integer(
    svm_model$index
  )

  number_of_support_vectors <- length(
    support_vector_indices
  )

  coefficient_sum <- sum(
    as.numeric(
      svm_model$coefs
    )
  )

  rho <- as.numeric(
    svm_model$rho
  )[[1L]]

  coefficient_to_rho_ratio <- (
    coefficient_sum /
      rho
  )

  if (
    !is.finite(
      coefficient_to_rho_ratio
    ) ||
      coefficient_to_rho_ratio <= 0
  ) {
    stop(
      "The fitted SVM produced an invalid coefficient-to-rho ratio."
    )
  }

  squared_scaled_distance <- (
    log(
      coefficient_to_rho_ratio
    ) /
      svm_gamma
  )

  if (
    !is.finite(
      squared_scaled_distance
    ) ||
      squared_scaled_distance <= 0
  ) {
    stop(
      "The fitted SVM produced an invalid derived squared sampling distance."
    )
  }

  data_standard_deviation <- apply(
    occurrence_points,
    2L,
    stats::sd
  )

  sampling_scales <- (
    svm_scale_factor *
      data_standard_deviation *
      sqrt(
        squared_scaled_distance
      )
  )

  names(
    data_standard_deviation
  ) <- axis_names

  names(
    sampling_scales
  ) <- axis_names

  internal_scale_center <- extract_scale_component(
    svm_model = svm_model,
    component_name = "scaled:center",
    dimensionality = dimensionality,
    axis_names = axis_names
  )

  internal_scale_sd <- extract_scale_component(
    svm_model = svm_model,
    component_name = "scaled:scale",
    dimensionality = dimensionality,
    axis_names = axis_names
  )

  training_prediction <- predict(
    svm_model,
    occurrence_points
  )

  training_inside <- prediction_to_inside(
    training_prediction
  )

  number_of_training_errors <- sum(
    !training_inside
  )

  list(
    support_vector_indices = support_vector_indices,
    support_vector_points = occurrence_points[
      support_vector_indices,
      ,
      drop = FALSE
    ],
    number_of_support_vectors = number_of_support_vectors,
    support_vector_fraction = (
      number_of_support_vectors /
        nrow(
          occurrence_points
        )
    ),
    coefficient_sum = coefficient_sum,
    rho = rho,
    coefficient_to_rho_ratio = coefficient_to_rho_ratio,
    squared_scaled_distance = squared_scaled_distance,
    data_standard_deviation = data_standard_deviation,
    sampling_scales = sampling_scales,
    internal_scale_center = internal_scale_center,
    internal_scale_sd = internal_scale_sd,
    number_of_training_errors = number_of_training_errors,
    training_error_fraction = (
      number_of_training_errors /
        nrow(
          occurrence_points
        )
    ),
    training_prediction = training_prediction,
    training_inside = training_inside
  )
}


# ============================================================
# Shared fit-summary constructor
# ============================================================

empty_summary_row <- function(
    species_name,
    method_name,
    sampling_seed,
    success,
    error_message = NA_character_
) {

  data.frame(
    Condition_id = model_key(
      species_name,
      method_name
    ),
    Species = species_name,
    Species_code = species_code(
      species_name
    ),
    Method = method_name,
    Success = success,
    Occurrence_count = nrow(
      species_matrices[[species_name]]
    ),
    Dimensionality = 3L,
    Hypervolume_volume = NA_real_,
    Point_density = NA_real_,
    Random_point_count = NA_integer_,
    Samples_per_point_argument = baseline_samples_per_point,
    SD_count = if (
      method_name %in%
        c(
          "QPH",
          "Gaussian KDE"
        )
    ) {
      baseline_sd_count
    } else {
      NA_real_
    },
    Quantile = if (
      identical(
        method_name,
        "QPH"
      )
    ) {
      qph_baseline_q
    } else if (
      identical(
        method_name,
        "Gaussian KDE"
      )
    ) {
      kde_baseline_quantile
    } else {
      NA_real_
    },
    Quantile_type = if (
      identical(
        method_name,
        "QPH"
      )
    ) {
      "Occurrence-potential quantile"
    } else if (
      identical(
        method_name,
        "Gaussian KDE"
      )
    ) {
      "Probability-mass quantile"
    } else {
      NA_character_
    },
    Bandwidth_method = if (
      identical(
        method_name,
        "QPH"
      )
    ) {
      "sqrtNB"
    } else if (
      identical(
        method_name,
        "Gaussian KDE"
      )
    ) {
      "Silverman"
    } else {
      NA_character_
    },
    Bandwidth_PC1 = NA_real_,
    Bandwidth_PC2 = NA_real_,
    Bandwidth_PC3 = NA_real_,
    Sampling_seed = as.integer(
      sampling_seed
    ),
    Runtime_seconds = NA_real_,
    QPH_K = NA_integer_,
    QPH_mean_s = NA_real_,
    QPH_scalar_h = NA_real_,
    QPH_potential_threshold_raw = NA_real_,
    QPH_potential_threshold_relative = NA_real_,
    QPH_sampling_region_volume = NA_real_,
    QPH_retained_fraction = NA_real_,
    QPH_volume_SE_conditional = NA_real_,
    Gaussian_minimum_retained_density = NA_real_,
    Gaussian_maximum_retained_density = NA_real_,
    SVM_nu = if (
      identical(
        method_name,
        "SVM"
      )
    ) {
      svm_nu
    } else {
      NA_real_
    },
    SVM_gamma = if (
      identical(
        method_name,
        "SVM"
      )
    ) {
      svm_gamma
    } else {
      NA_real_
    },
    SVM_scale_factor = if (
      identical(
        method_name,
        "SVM"
      )
    ) {
      svm_scale_factor
    } else {
      NA_real_
    },
    SVM_number_support_vectors = NA_integer_,
    SVM_support_vector_fraction = NA_real_,
    SVM_training_error_fraction = NA_real_,
    SVM_random_points_inside_audit_fraction = NA_real_,
    Error_message = error_message,
    stringsAsFactors = FALSE
  )
}


# ============================================================
# Fit one revised QPH model
# ============================================================

fit_qph_species <- function(
    species_name,
    occurrence_points,
    sampling_seed
) {

  occurrence_points <- validate_pc_matrix(
    occurrence_points,
    "occurrence_points"
  )

  start_time <- proc.time()[[
    "elapsed"
  ]]

  qph_result <- construct_qph(
    data = occurrence_points,
    bandwidth = NULL,
    bandwidth_info = NULL,
    name = paste0(
      "QPH: ",
      species_name
    ),
    samples_per_point = baseline_samples_per_point,
    sd_count = baseline_sd_count,
    q = qph_baseline_q,
    sampling_seed = as.integer(
      sampling_seed
    ),
    sampling_chunk_size = shared_chunk_size,
    potential_batch_size = potential_batch_size,
    verbose = show_progress_messages
  )

  runtime_seconds <- (
    proc.time()[[
      "elapsed"
    ]] -
      start_time
  )

  hv_qph <- qph_result$hypervolume

  methods::validObject(
    hv_qph
  )

  audit <- qph_result$audit

  if (
    audit$K !=
      round(
        sqrt(
          nrow(
            occurrence_points
          )
        )
      )
  ) {
    stop(
      "QPH K audit failed for ",
      species_name,
      "."
    )
  }

  if (
    !isTRUE(
      all.equal(
        audit$q,
        qph_baseline_q,
        tolerance = 1e-12
      )
    )
  ) {
    stop(
      "QPH q audit failed for ",
      species_name,
      "."
    )
  }

  if (!isTRUE(audit$fitted_isotropic)) {
    stop(
      "Baseline QPH bandwidth is not isotropic for ",
      species_name,
      "."
    )
  }

  bandwidth <- as.numeric(
    qph_result$bandwidth
  )

  names(
    bandwidth
  ) <- expected_pc_names

  potential_minimum <- min(
    c(
      qph_result$occurrence_potential_raw,
      qph_result$candidate_potential_raw
    )
  )

  projection_model <- list(
    model_type = "QPH",
    formula_version = paste(
      "V(y) = -d/2 + 0.5 * weighted mean",
      "bandwidth-standardised squared distance"
    ),
    occurrence_points = occurrence_points,
    bandwidth = bandwidth,
    bandwidth_names = expected_pc_names,
    bandwidth_method = "sqrtNB",
    dimensionality = 3L,
    potential_quantile = qph_baseline_q,
    potential_threshold_raw = qph_result$potential_threshold_raw,
    potential_threshold_relative = qph_result$potential_threshold_relative,
    potential_minimum = potential_minimum,
    energy_constant = 0,
    candidate_sd_count = baseline_sd_count,
    potential_batch_size = potential_batch_size,
    inclusion_rule = "potential <= potential_threshold_raw",
    qph_core_version = QPH_CORE_VERSION
  )

  compact_qph_result <- list(
    audit = qph_result$audit,
    audit_summary = qph_result$audit_summary,
    bandwidth_info = qph_result$bandwidth_info,
    bandwidth = qph_result$bandwidth,
    ellipsoid_scales = qph_result$ellipsoid_scales,
    occurrence_potential_raw = qph_result$occurrence_potential_raw,
    occurrence_potential_relative = qph_result$occurrence_potential_relative,
    potential_threshold_raw = qph_result$potential_threshold_raw,
    potential_threshold_relative = qph_result$potential_threshold_relative,
    sampling_region_volume = qph_result$sampling_region_volume,
    retained_fraction = qph_result$retained_fraction,
    qph_volume = qph_result$qph_volume,
    qph_volume_se_conditional = qph_result$qph_volume_se_conditional
  )

  model_bundle <- list(
    metadata = list(
      species = species_name,
      species_code = species_code(
        species_name
      ),
      method = "QPH",
      occurrence_count = nrow(
        occurrence_points
      ),
      dimensionality = 3L,
      sampling_seed = as.integer(
        sampling_seed
      ),
      locked_design_hash = locked_design_hash,
      locked_archive_md5 = locked_archive_md5,
      analysis_settings_hash = analysis_settings_hash,
      qph_core_version = QPH_CORE_VERSION,
      qph_core_md5 = qph_core_md5,
      fitted_at = as.character(
        Sys.time()
      ),
      hypervolume_version = installed_hypervolume_version
    ),
    hypervolume = hv_qph,
    projection_model = projection_model,
    qph_result = compact_qph_result,
    diagnostics = list(
      retained_fraction = qph_result$retained_fraction,
      sampling_region_volume = qph_result$sampling_region_volume,
      qph_volume_se_conditional = qph_result$qph_volume_se_conditional,
      candidate_point_count = length(
        qph_result$inside_qph
      ),
      retained_point_count = sum(
        qph_result$inside_qph
      )
    )
  )

  summary_row <- empty_summary_row(
    species_name = species_name,
    method_name = "QPH",
    sampling_seed = sampling_seed,
    success = TRUE
  )

  summary_row$Hypervolume_volume <- as.numeric(
    hv_qph@Volume
  )

  summary_row$Point_density <- as.numeric(
    hv_qph@PointDensity
  )

  summary_row$Random_point_count <- nrow(
    hv_qph@RandomPoints
  )

  summary_row$Bandwidth_PC1 <- bandwidth[[1L]]
  summary_row$Bandwidth_PC2 <- bandwidth[[2L]]
  summary_row$Bandwidth_PC3 <- bandwidth[[3L]]

  summary_row$Runtime_seconds <- runtime_seconds

  summary_row$QPH_K <- as.integer(
    audit$K
  )

  summary_row$QPH_mean_s <- as.numeric(
    audit$mean_s
  )

  summary_row$QPH_scalar_h <- as.numeric(
    audit$baseline_scalar_h
  )

  summary_row$QPH_potential_threshold_raw <- (
    qph_result$potential_threshold_raw
  )

  summary_row$QPH_potential_threshold_relative <- (
    qph_result$potential_threshold_relative
  )

  summary_row$QPH_sampling_region_volume <- (
    qph_result$sampling_region_volume
  )

  summary_row$QPH_retained_fraction <- (
    qph_result$retained_fraction
  )

  summary_row$QPH_volume_SE_conditional <- (
    qph_result$qph_volume_se_conditional
  )

  list(
    success = TRUE,
    summary = summary_row,
    model_bundle = model_bundle
  )
}


# ============================================================
# Fit one Gaussian KDE model
# ============================================================

fit_gaussian_species <- function(
    species_name,
    occurrence_points,
    sampling_seed
) {

  occurrence_points <- validate_pc_matrix(
    occurrence_points,
    "occurrence_points"
  )

  kde_bandwidth_object <- hypervolume::estimate_bandwidth(
    data = occurrence_points,
    method = kde_bandwidth_method
  )

  kde_bandwidth_numeric <- as.numeric(
    kde_bandwidth_object
  )

  if (
    length(
      kde_bandwidth_numeric
    ) !=
      3L ||
      any(
        !is.finite(
          kde_bandwidth_numeric
        )
      ) ||
      any(
        kde_bandwidth_numeric <= 0
      )
  ) {
    stop(
      "Invalid Silverman KDE bandwidth for ",
      species_name,
      "."
    )
  }

  names(
    kde_bandwidth_numeric
  ) <- expected_pc_names

  set.seed(
    as.integer(
      sampling_seed
    )
  )

  start_time <- proc.time()[[
    "elapsed"
  ]]

  hv_gaussian <- hypervolume::hypervolume_gaussian(
    data = occurrence_points,
    name = paste0(
      "Gaussian KDE: ",
      species_name
    ),
    kde.bandwidth = kde_bandwidth_object,
    samples.per.point = baseline_samples_per_point,
    sd.count = baseline_sd_count,
    quantile.requested = kde_baseline_quantile,
    quantile.requested.type = "probability",
    chunk.size = shared_chunk_size,
    verbose = show_progress_messages
  )

  runtime_seconds <- (
    proc.time()[[
      "elapsed"
    ]] -
      start_time
  )

  methods::validObject(
    hv_gaussian
  )

  retained_density <- as.numeric(
    hv_gaussian@ValueAtRandomPoints
  )

  retained_density <- retained_density[
    is.finite(
      retained_density
    )
  ]

  approximate_density_threshold <- if (
    length(
      retained_density
    ) > 0L
  ) {
    min(
      retained_density
    )
  } else {
    NA_real_
  }

  projection_model <- list(
    model_type = "Gaussian KDE",
    occurrence_points = occurrence_points,
    bandwidth = kde_bandwidth_numeric,
    bandwidth_names = expected_pc_names,
    bandwidth_method = "Silverman",
    dimensionality = 3L,
    quantile_requested = kde_baseline_quantile,
    quantile_requested_type = "probability",
    candidate_sd_count = baseline_sd_count,
    approximate_minimum_retained_density = (
      approximate_density_threshold
    ),
    note = paste(
      "The saved Hypervolume object is authoritative for binary inclusion.",
      "The stored occurrence points and Silverman bandwidth permit",
      "continuous Gaussian KDE evaluation at new PC coordinates."
    )
  )

  model_bundle <- list(
    metadata = list(
      species = species_name,
      species_code = species_code(
        species_name
      ),
      method = "Gaussian KDE",
      occurrence_count = nrow(
        occurrence_points
      ),
      dimensionality = 3L,
      sampling_seed = as.integer(
        sampling_seed
      ),
      locked_design_hash = locked_design_hash,
      locked_archive_md5 = locked_archive_md5,
      analysis_settings_hash = analysis_settings_hash,
      fitted_at = as.character(
        Sys.time()
      ),
      hypervolume_version = installed_hypervolume_version
    ),
    hypervolume = hv_gaussian,
    projection_model = projection_model,
    diagnostics = list(
      silverman_bandwidth = kde_bandwidth_numeric,
      retained_density_summary = if (
        length(
          retained_density
        ) > 0L
      ) {
        summary(
          retained_density
        )
      } else {
        numeric(0)
      },
      hypervolume_parameters = hv_gaussian@Parameters
    )
  )

  summary_row <- empty_summary_row(
    species_name = species_name,
    method_name = "Gaussian KDE",
    sampling_seed = sampling_seed,
    success = TRUE
  )

  summary_row$Hypervolume_volume <- as.numeric(
    hv_gaussian@Volume
  )

  summary_row$Point_density <- as.numeric(
    hv_gaussian@PointDensity
  )

  summary_row$Random_point_count <- nrow(
    hv_gaussian@RandomPoints
  )

  summary_row$Bandwidth_PC1 <- kde_bandwidth_numeric[[1L]]
  summary_row$Bandwidth_PC2 <- kde_bandwidth_numeric[[2L]]
  summary_row$Bandwidth_PC3 <- kde_bandwidth_numeric[[3L]]

  summary_row$Runtime_seconds <- runtime_seconds

  summary_row$Gaussian_minimum_retained_density <- if (
    length(
      retained_density
    ) > 0L
  ) {
    min(
      retained_density
    )
  } else {
    NA_real_
  }

  summary_row$Gaussian_maximum_retained_density <- if (
    length(
      retained_density
    ) > 0L
  ) {
    max(
      retained_density
    )
  } else {
    NA_real_
  }

  list(
    success = TRUE,
    summary = summary_row,
    model_bundle = model_bundle
  )
}


# ============================================================
# Fit one SVM model
# ============================================================

fit_svm_species <- function(
    species_name,
    occurrence_points,
    sampling_seed
) {

  occurrence_points <- validate_pc_matrix(
    occurrence_points,
    "occurrence_points"
  )

  audit_start <- proc.time()[[
    "elapsed"
  ]]

  audit_svm_model <- fit_audit_svm_model(
    occurrence_points
  )

  audit_runtime_seconds <- (
    proc.time()[[
      "elapsed"
    ]] -
      audit_start
  )

  svm_audit <- calculate_svm_sampling_audit(
    occurrence_points = occurrence_points,
    svm_model = audit_svm_model
  )

  expected_random_points <- as.integer(
    baseline_samples_per_point *
      svm_audit$number_of_support_vectors
  )

  set.seed(
    as.integer(
      sampling_seed
    )
  )

  hv_start <- proc.time()[[
    "elapsed"
  ]]

  hv_svm <- hypervolume::hypervolume_svm(
    data = occurrence_points,
    name = paste0(
      "SVM: ",
      species_name
    ),
    samples.per.point = baseline_samples_per_point,
    svm.nu = svm_nu,
    svm.gamma = svm_gamma,
    scale.factor = svm_scale_factor,
    chunk.size = shared_chunk_size,
    verbose = show_progress_messages
  )

  hv_runtime_seconds <- (
    proc.time()[[
      "elapsed"
    ]] -
      hv_start
  )

  methods::validObject(
    hv_svm
  )

  actual_random_points <- nrow(
    hv_svm@RandomPoints
  )

  if (
    actual_random_points !=
      expected_random_points
  ) {
    warning(
      "SVM random-point count for ",
      species_name,
      " was ",
      actual_random_points,
      ", whereas support-vector sampling implied ",
      expected_random_points,
      ". The observed count is retained."
    )
  }

  random_point_prediction <- predict(
    audit_svm_model,
    hv_svm@RandomPoints
  )

  random_points_inside <- prediction_to_inside(
    random_point_prediction
  )

  random_points_inside_fraction <- mean(
    random_points_inside
  )

  if (
    is.finite(
      random_points_inside_fraction
    ) &&
      random_points_inside_fraction <
        0.999
  ) {
    warning(
      "Only ",
      round(
        100 *
          random_points_inside_fraction,
        3
      ),
      "% of saved SVM Hypervolume RandomPoints were classified inside by ",
      "the independently fitted projection classifier for ",
      species_name,
      ". Inspect the SVM audit before geographic projection."
    )
  }

  projection_model <- list(
    model_type = "One-class radial SVM",
    e1071_model = audit_svm_model,
    occurrence_points = occurrence_points,
    dimensionality = 3L,
    svm_nu = svm_nu,
    svm_gamma = svm_gamma,
    svm_scale_factor = svm_scale_factor,
    kernel = "radial",
    internal_scaling = TRUE,
    inclusion_rule = paste(
      "predict(e1071_model, newdata) interpreted as",
      "one-class inside/outside classification"
    )
  )

  total_runtime_seconds <- (
    audit_runtime_seconds +
      hv_runtime_seconds
  )

  model_bundle <- list(
    metadata = list(
      species = species_name,
      species_code = species_code(
        species_name
      ),
      method = "SVM",
      occurrence_count = nrow(
        occurrence_points
      ),
      dimensionality = 3L,
      sampling_seed = as.integer(
        sampling_seed
      ),
      locked_design_hash = locked_design_hash,
      locked_archive_md5 = locked_archive_md5,
      analysis_settings_hash = analysis_settings_hash,
      fitted_at = as.character(
        Sys.time()
      ),
      hypervolume_version = installed_hypervolume_version,
      e1071_version = installed_e1071_version
    ),
    hypervolume = hv_svm,
    projection_model = projection_model,
    diagnostics = list(
      svm_audit = svm_audit,
      expected_random_points = expected_random_points,
      actual_random_points = actual_random_points,
      random_points_inside_audit_fraction = (
        random_points_inside_fraction
      ),
      hypervolume_parameters = hv_svm@Parameters,
      audit_model_runtime_seconds = audit_runtime_seconds,
      hypervolume_runtime_seconds = hv_runtime_seconds
    )
  )

  summary_row <- empty_summary_row(
    species_name = species_name,
    method_name = "SVM",
    sampling_seed = sampling_seed,
    success = TRUE
  )

  summary_row$Hypervolume_volume <- as.numeric(
    hv_svm@Volume
  )

  summary_row$Point_density <- as.numeric(
    hv_svm@PointDensity
  )

  summary_row$Random_point_count <- actual_random_points

  summary_row$Runtime_seconds <- total_runtime_seconds

  summary_row$SVM_number_support_vectors <- (
    svm_audit$number_of_support_vectors
  )

  summary_row$SVM_support_vector_fraction <- (
    svm_audit$support_vector_fraction
  )

  summary_row$SVM_training_error_fraction <- (
    svm_audit$training_error_fraction
  )

  summary_row$SVM_random_points_inside_audit_fraction <- (
    random_points_inside_fraction
  )

  list(
    success = TRUE,
    summary = summary_row,
    model_bundle = model_bundle
  )
}


# ============================================================
# Restartable registry
# ============================================================

empty_registry <- function() {

  data.frame(
    Condition_id = character(0),
    Species = character(0),
    Species_code = character(0),
    Method = character(0),
    Success = logical(0),
    Sampling_seed = integer(0),
    Model_file = character(0),
    Model_MD5 = character(0),
    Runtime_seconds = numeric(0),
    Error_message = character(0),
    Completed_at = character(0),
    stringsAsFactors = FALSE
  )
}


if (
  resume_from_checkpoint &&
    file.exists(
      checkpoint_file
    )
) {

  checkpoint_object <- readRDS(
    checkpoint_file
  )

  if (
    !is.list(
      checkpoint_object
    ) ||
      !all(
        c(
          "analysis_settings_hash",
          "registry"
        ) %in%
          names(
            checkpoint_object
          )
      )
  ) {
    stop(
      "Existing Script-19 checkpoint has an unexpected structure."
    )
  }

  if (
    !identical(
      checkpoint_object$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Existing Script-19 checkpoint was created from different locked ",
      "inputs or baseline settings."
    )
  }

  fit_registry <- checkpoint_object$registry

} else {

  fit_registry <- empty_registry()
}


save_checkpoint <- function() {

  saveRDS(
    list(
      analysis_settings_hash = analysis_settings_hash,
      analysis_settings = analysis_settings,
      registry = fit_registry,
      last_saved_at = as.character(
        Sys.time()
      )
    ),
    checkpoint_file,
    version = 3
  )

  saveRDS(
    fit_registry,
    registry_file,
    version = 3
  )

  write_csv_safely(
    fit_registry,
    registry_csv_file
  )
}


replace_registry_row <- function(new_row) {

  if (nrow(fit_registry) > 0L) {

    keep <- fit_registry$Condition_id !=
      new_row$Condition_id[[1L]]

    fit_registry <<- fit_registry[
      keep,
      ,
      drop = FALSE
    ]
  }

  fit_registry <<- rbind(
    fit_registry,
    new_row
  )

  rownames(
    fit_registry
  ) <<- NULL
}


registry_row <- function(condition_id) {

  if (nrow(fit_registry) == 0L) {
    return(NULL)
  }

  rows <- fit_registry[
    fit_registry$Condition_id ==
      condition_id,
    ,
    drop = FALSE
  ]

  if (nrow(rows) == 0L) {
    return(NULL)
  }

  if (nrow(rows) != 1L) {
    stop(
      "Duplicate registry rows for ",
      condition_id,
      "."
    )
  }

  rows
}


# ============================================================
# Fit all 15 species-method baseline models
# ============================================================

for (
  condition_index in seq_len(
    nrow(
      fit_design
    )
  )
) {

  condition <- fit_design[
    condition_index,
    ,
    drop = FALSE
  ]

  condition_id <- condition$Condition_id[[1L]]
  species_name <- condition$Species[[1L]]
  method_name <- condition$Method[[1L]]
  sampling_seed <- condition$Sampling_seed[[1L]]

  current_model_file <- model_file_path(
    species_name,
    method_name
  )

  existing <- registry_row(
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
        current_model_file
      )
  ) {

    current_md5 <- safe_md5(
      current_model_file
    )

    if (
      identical(
        current_md5,
        existing$Model_MD5[[1L]]
      )
    ) {

      message(
        "Skipping successful fit ",
        condition_index,
        "/",
        nrow(
          fit_design
        ),
        ": ",
        condition_id
      )

      next
    }

    warning(
      "Saved model MD5 changed for ",
      condition_id,
      "; the model will be refitted."
    )
  }

  if (
    !is.null(
      existing
    ) &&
      !isTRUE(
        existing$Success[[1L]]
      ) &&
      !retry_failed_fits
  ) {
    next
  }

  occurrence_points <- species_matrices[[
    species_name
  ]]

  message(
    "\nFitting ",
    condition_index,
    "/",
    nrow(
      fit_design
    ),
    ": ",
    species_name,
    " / ",
    method_name,
    " (n = ",
    nrow(
      occurrence_points
    ),
    ")"
  )

  fit_result <- tryCatch(
    {

      if (
        identical(
          method_name,
          "QPH"
        )
      ) {

        fit_qph_species(
          species_name = species_name,
          occurrence_points = occurrence_points,
          sampling_seed = sampling_seed
        )

      } else if (
        identical(
          method_name,
          "Gaussian KDE"
        )
      ) {

        fit_gaussian_species(
          species_name = species_name,
          occurrence_points = occurrence_points,
          sampling_seed = sampling_seed
        )

      } else {

        fit_svm_species(
          species_name = species_name,
          occurrence_points = occurrence_points,
          sampling_seed = sampling_seed
        )
      }
    },
    error = function(error_condition) {

      list(
        success = FALSE,
        summary = empty_summary_row(
          species_name = species_name,
          method_name = method_name,
          sampling_seed = sampling_seed,
          success = FALSE,
          error_message = conditionMessage(
            error_condition
          )
        ),
        model_bundle = NULL
      )
    }
  )

  if (isTRUE(fit_result$success)) {

    saveRDS(
      fit_result$model_bundle,
      current_model_file,
      version = 3
    )

    model_md5 <- safe_md5(
      current_model_file
    )

    new_registry_row <- data.frame(
      Condition_id = condition_id,
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Method = method_name,
      Success = TRUE,
      Sampling_seed = as.integer(
        sampling_seed
      ),
      Model_file = normalizePath(
        current_model_file,
        winslash = "/",
        mustWork = TRUE
      ),
      Model_MD5 = model_md5,
      Runtime_seconds = fit_result$summary$Runtime_seconds[[1L]],
      Error_message = NA_character_,
      Completed_at = as.character(
        Sys.time()
      ),
      stringsAsFactors = FALSE
    )

    message(
      "Saved: ",
      basename(
        current_model_file
      )
    )

  } else {

    new_registry_row <- data.frame(
      Condition_id = condition_id,
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Method = method_name,
      Success = FALSE,
      Sampling_seed = as.integer(
        sampling_seed
      ),
      Model_file = normalizePath(
        current_model_file,
        winslash = "/",
        mustWork = FALSE
      ),
      Model_MD5 = NA_character_,
      Runtime_seconds = fit_result$summary$Runtime_seconds[[1L]],
      Error_message = fit_result$summary$Error_message[[1L]],
      Completed_at = as.character(
        Sys.time()
      ),
      stringsAsFactors = FALSE
    )

    warning(
      "Fit failed for ",
      species_name,
      " / ",
      method_name,
      ": ",
      fit_result$summary$Error_message[[1L]]
    )
  }

  replace_registry_row(
    new_registry_row
  )

  save_checkpoint()

  gc()
}


# ============================================================
# Canonical registry order
# ============================================================

missing_registry_conditions <- setdiff(
  fit_design$Condition_id,
  fit_registry$Condition_id
)

if (length(missing_registry_conditions) > 0L) {
  stop(
    "Registry is missing condition(s): ",
    paste(
      missing_registry_conditions,
      collapse = ", "
    )
  )
}

fit_registry <- fit_registry[
  match(
    fit_design$Condition_id,
    fit_registry$Condition_id
  ),
  ,
  drop = FALSE
]

# Rewrite canonical current paths so the final registry is relocation-safe
# when copied to another computer.
for (
  row_index in seq_len(
    nrow(
      fit_registry
    )
  )
) {

  fit_registry$Model_file[[row_index]] <- normalizePath(
    model_file_path(
      fit_registry$Species[[row_index]],
      fit_registry$Method[[row_index]]
    ),
    winslash = "/",
    mustWork = FALSE
  )
}

save_checkpoint()


# ============================================================
# Reload successful objects and compile authoritative summaries
# ============================================================

fit_summary_rows <- list()
qph_audit_rows <- list()
qph_local_s_rows <- list()
qph_threshold_rows <- list()
kde_audit_rows <- list()
svm_audit_rows <- list()
svm_support_vector_rows <- list()

fit_summary_index <- 0L
qph_audit_index <- 0L
qph_local_s_index <- 0L
qph_threshold_index <- 0L
kde_audit_index <- 0L
svm_audit_index <- 0L
svm_support_vector_index <- 0L

successful_model_bundles <- list()

for (
  row_index in seq_len(
    nrow(
      fit_registry
    )
  )
) {

  registry_entry <- fit_registry[
    row_index,
    ,
    drop = FALSE
  ]

  species_name <- registry_entry$Species[[1L]]
  method_name <- registry_entry$Method[[1L]]
  condition_id <- registry_entry$Condition_id[[1L]]

  if (!isTRUE(registry_entry$Success[[1L]])) {

    fit_summary_index <- fit_summary_index + 1L

    fit_summary_rows[[fit_summary_index]] <- empty_summary_row(
      species_name = species_name,
      method_name = method_name,
      sampling_seed = registry_entry$Sampling_seed[[1L]],
      success = FALSE,
      error_message = registry_entry$Error_message[[1L]]
    )

    next
  }

  current_model_file <- model_file_path(
    species_name,
    method_name
  )

  if (!file.exists(current_model_file)) {
    stop(
      "Registry records a successful fit but model file is missing:\n  ",
      current_model_file
    )
  }

  current_bundle <- readRDS(
    current_model_file
  )

  if (
    !identical(
      current_bundle$metadata$analysis_settings_hash,
      analysis_settings_hash
    ) ||
      !identical(
        current_bundle$metadata$locked_design_hash,
        locked_design_hash
      )
  ) {
    stop(
      "Saved model provenance mismatch for ",
      condition_id,
      "."
    )
  }

  methods::validObject(
    current_bundle$hypervolume
  )

  successful_model_bundles[[condition_id]] <- current_bundle

  summary_row <- empty_summary_row(
    species_name = species_name,
    method_name = method_name,
    sampling_seed = registry_entry$Sampling_seed[[1L]],
    success = TRUE
  )

  summary_row$Hypervolume_volume <- as.numeric(
    current_bundle$hypervolume@Volume
  )

  summary_row$Point_density <- as.numeric(
    current_bundle$hypervolume@PointDensity
  )

  summary_row$Random_point_count <- nrow(
    current_bundle$hypervolume@RandomPoints
  )

  summary_row$Runtime_seconds <- registry_entry$Runtime_seconds[[1L]]

  if (identical(method_name, "QPH")) {

    qph_result <- current_bundle$qph_result
    audit <- qph_result$audit
    bandwidth <- as.numeric(
      qph_result$bandwidth
    )

    summary_row$Bandwidth_PC1 <- bandwidth[[1L]]
    summary_row$Bandwidth_PC2 <- bandwidth[[2L]]
    summary_row$Bandwidth_PC3 <- bandwidth[[3L]]
    summary_row$QPH_K <- audit$K
    summary_row$QPH_mean_s <- audit$mean_s
    summary_row$QPH_scalar_h <- audit$baseline_scalar_h
    summary_row$QPH_potential_threshold_raw <- (
      qph_result$potential_threshold_raw
    )
    summary_row$QPH_potential_threshold_relative <- (
      qph_result$potential_threshold_relative
    )
    summary_row$QPH_sampling_region_volume <- (
      qph_result$sampling_region_volume
    )
    summary_row$QPH_retained_fraction <- (
      qph_result$retained_fraction
    )
    summary_row$QPH_volume_SE_conditional <- (
      qph_result$qph_volume_se_conditional
    )

    audit_row <- qph_audit_summary(
      audit
    )

    qph_audit_index <- qph_audit_index + 1L

    qph_audit_rows[[qph_audit_index]] <- cbind(
      data.frame(
        Species = species_name,
        Species_code = species_code(
          species_name
        ),
        Condition_id = condition_id,
        stringsAsFactors = FALSE
      ),
      audit_row
    )

    for (
      occurrence_index in seq_along(
        audit$local_s
      )
    ) {

      qph_local_s_index <- qph_local_s_index + 1L

      qph_local_s_rows[[qph_local_s_index]] <- data.frame(
        Species = species_name,
        Species_code = species_code(
          species_name
        ),
        Occurrence_index = occurrence_index,
        Local_s = audit$local_s[[occurrence_index]],
        stringsAsFactors = FALSE
      )
    }

    qph_threshold_index <- qph_threshold_index + 1L

    qph_threshold_rows[[qph_threshold_index]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      q = audit$q,
      Potential_threshold_raw = qph_result$potential_threshold_raw,
      Potential_threshold_relative = (
        qph_result$potential_threshold_relative
      ),
      Retained_fraction = qph_result$retained_fraction,
      Sampling_region_volume = qph_result$sampling_region_volume,
      QPH_volume = qph_result$qph_volume,
      QPH_volume_SE_conditional = (
        qph_result$qph_volume_se_conditional
      ),
      stringsAsFactors = FALSE
    )

  } else if (
    identical(
      method_name,
      "Gaussian KDE"
    )
  ) {

    bandwidth <- as.numeric(
      current_bundle$projection_model$bandwidth
    )

    summary_row$Bandwidth_PC1 <- bandwidth[[1L]]
    summary_row$Bandwidth_PC2 <- bandwidth[[2L]]
    summary_row$Bandwidth_PC3 <- bandwidth[[3L]]

    retained_density <- as.numeric(
      current_bundle$hypervolume@ValueAtRandomPoints
    )

    retained_density <- retained_density[
      is.finite(
        retained_density
      )
    ]

    summary_row$Gaussian_minimum_retained_density <- if (
      length(
        retained_density
      ) > 0L
    ) {
      min(
        retained_density
      )
    } else {
      NA_real_
    }

    summary_row$Gaussian_maximum_retained_density <- if (
      length(
        retained_density
      ) > 0L
    ) {
      max(
        retained_density
      )
    } else {
      NA_real_
    }

    kde_audit_index <- kde_audit_index + 1L

    kde_audit_rows[[kde_audit_index]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Occurrence_count = current_bundle$metadata$occurrence_count,
      Bandwidth_method = current_bundle$projection_model$bandwidth_method,
      Bandwidth_PC1 = bandwidth[[1L]],
      Bandwidth_PC2 = bandwidth[[2L]],
      Bandwidth_PC3 = bandwidth[[3L]],
      Probability_quantile = (
        current_bundle$projection_model$quantile_requested
      ),
      Samples_per_point = baseline_samples_per_point,
      SD_count = baseline_sd_count,
      Sampling_seed = current_bundle$metadata$sampling_seed,
      Random_point_count = nrow(
        current_bundle$hypervolume@RandomPoints
      ),
      Hypervolume_volume = as.numeric(
        current_bundle$hypervolume@Volume
      ),
      Minimum_retained_density = (
        current_bundle$projection_model$approximate_minimum_retained_density
      ),
      stringsAsFactors = FALSE
    )

  } else {

    svm_audit <- current_bundle$diagnostics$svm_audit

    summary_row$SVM_number_support_vectors <- (
      svm_audit$number_of_support_vectors
    )

    summary_row$SVM_support_vector_fraction <- (
      svm_audit$support_vector_fraction
    )

    summary_row$SVM_training_error_fraction <- (
      svm_audit$training_error_fraction
    )

    summary_row$SVM_random_points_inside_audit_fraction <- (
      current_bundle$diagnostics$random_points_inside_audit_fraction
    )

    svm_audit_index <- svm_audit_index + 1L

    svm_audit_rows[[svm_audit_index]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Occurrence_count = current_bundle$metadata$occurrence_count,
      Nu = svm_nu,
      Gamma = svm_gamma,
      Scale_factor = svm_scale_factor,
      Internal_scaling = current_bundle$projection_model$internal_scaling,
      Kernel = current_bundle$projection_model$kernel,
      Sampling_seed = current_bundle$metadata$sampling_seed,
      Number_support_vectors = svm_audit$number_of_support_vectors,
      Support_vector_fraction = svm_audit$support_vector_fraction,
      Training_error_fraction = svm_audit$training_error_fraction,
      Rho = svm_audit$rho,
      Sampling_scale_PC1 = svm_audit$sampling_scales[[1L]],
      Sampling_scale_PC2 = svm_audit$sampling_scales[[2L]],
      Sampling_scale_PC3 = svm_audit$sampling_scales[[3L]],
      Expected_random_points = (
        current_bundle$diagnostics$expected_random_points
      ),
      Actual_random_points = (
        current_bundle$diagnostics$actual_random_points
      ),
      Random_points_inside_audit_fraction = (
        current_bundle$diagnostics$random_points_inside_audit_fraction
      ),
      stringsAsFactors = FALSE
    )

    support_points <- svm_audit$support_vector_points

    for (
      support_index in seq_len(
        nrow(
          support_points
        )
      )
    ) {

      svm_support_vector_index <- (
        svm_support_vector_index +
          1L
      )

      svm_support_vector_rows[[svm_support_vector_index]] <- data.frame(
        Species = species_name,
        Species_code = species_code(
          species_name
        ),
        Support_vector_number = support_index,
        Original_occurrence_index = (
          svm_audit$support_vector_indices[[support_index]]
        ),
        PC1 = support_points[
          support_index,
          "PC1"
        ],
        PC2 = support_points[
          support_index,
          "PC2"
        ],
        PC3 = support_points[
          support_index,
          "PC3"
        ],
        stringsAsFactors = FALSE
      )
    }
  }

  fit_summary_index <- fit_summary_index + 1L
  fit_summary_rows[[fit_summary_index]] <- summary_row
}


fit_summary <- do.call(
  rbind,
  fit_summary_rows
)

rownames(
  fit_summary
) <- NULL

fit_summary <- fit_summary[
  match(
    fit_design$Condition_id,
    fit_summary$Condition_id
  ),
  ,
  drop = FALSE
]


qph_audit_summary_table <- if (
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


qph_local_s_table <- if (
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


qph_threshold_table <- if (
  length(
    qph_threshold_rows
  ) > 0L
) {
  do.call(
    rbind,
    qph_threshold_rows
  )
} else {
  data.frame()
}


kde_audit_table <- if (
  length(
    kde_audit_rows
  ) > 0L
) {
  do.call(
    rbind,
    kde_audit_rows
  )
} else {
  data.frame()
}


svm_audit_table <- if (
  length(
    svm_audit_rows
  ) > 0L
) {
  do.call(
    rbind,
    svm_audit_rows
  )
} else {
  data.frame()
}


svm_support_vector_table <- if (
  length(
    svm_support_vector_rows
  ) > 0L
) {
  do.call(
    rbind,
    svm_support_vector_rows
  )
} else {
  data.frame()
}


# ============================================================
# Combined method-specific bandwidth audit
# ============================================================

bandwidth_rows <- list()
bandwidth_index <- 0L

for (
  species_name in expected_species
) {

  qph_row <- fit_summary[
    fit_summary$Species ==
      species_name &
      fit_summary$Method ==
        "QPH",
    ,
    drop = FALSE
  ]

  kde_row <- fit_summary[
    fit_summary$Species ==
      species_name &
      fit_summary$Method ==
        "Gaussian KDE",
    ,
    drop = FALSE
  ]

  if (
    nrow(
      qph_row
    ) != 1L ||
      nrow(
        kde_row
      ) != 1L
  ) {
    stop(
      "Could not recover unique QPH/KDE summary rows for ",
      species_name,
      "."
    )
  }

  bandwidth_index <- bandwidth_index + 1L

  bandwidth_rows[[bandwidth_index]] <- data.frame(
    Species = species_name,
    Species_code = species_code(
      species_name
    ),
    Occurrence_count = nrow(
      species_matrices[[species_name]]
    ),
    QPH_bandwidth_method = "sqrtNB",
    QPH_K = qph_row$QPH_K[[1L]],
    QPH_mean_s = qph_row$QPH_mean_s[[1L]],
    QPH_scalar_h = qph_row$QPH_scalar_h[[1L]],
    QPH_bandwidth_PC1 = qph_row$Bandwidth_PC1[[1L]],
    QPH_bandwidth_PC2 = qph_row$Bandwidth_PC2[[1L]],
    QPH_bandwidth_PC3 = qph_row$Bandwidth_PC3[[1L]],
    KDE_bandwidth_method = "Silverman",
    KDE_bandwidth_PC1 = kde_row$Bandwidth_PC1[[1L]],
    KDE_bandwidth_PC2 = kde_row$Bandwidth_PC2[[1L]],
    KDE_bandwidth_PC3 = kde_row$Bandwidth_PC3[[1L]],
    QPH_KDE_bandwidth_vectors_identical = isTRUE(
      all.equal(
        as.numeric(
          qph_row[
            1L,
            c(
              "Bandwidth_PC1",
              "Bandwidth_PC2",
              "Bandwidth_PC3"
            )
          ]
        ),
        as.numeric(
          kde_row[
            1L,
            c(
              "Bandwidth_PC1",
              "Bandwidth_PC2",
              "Bandwidth_PC3"
            )
          ]
        ),
        tolerance = 1e-12
      )
    ),
    stringsAsFactors = FALSE
  )
}

bandwidth_table <- do.call(
  rbind,
  bandwidth_rows
)

rownames(
  bandwidth_table
) <- NULL


# ============================================================
# Strong baseline QA
# ============================================================

successful_qph <- fit_summary[
  fit_summary$Method ==
    "QPH" &
    fit_summary$Success,
  ,
  drop = FALSE
]

if (
  nrow(
    successful_qph
  ) ==
    length(
      expected_species
    )
) {

  expected_K <- round(
    sqrt(
      successful_qph$Occurrence_count
    )
  )

  if (
    !identical(
      as.integer(
        successful_qph$QPH_K
      ),
      as.integer(
        expected_K
      )
    )
  ) {
    stop(
      "At least one QPH K value differs from round(sqrt(n))."
    )
  }

  qph_bw_matrix <- as.matrix(
    successful_qph[
      ,
      c(
        "Bandwidth_PC1",
        "Bandwidth_PC2",
        "Bandwidth_PC3"
      ),
      drop = FALSE
    ]
  )

  if (
    any(
      apply(
        qph_bw_matrix,
        1L,
        function(x) {
          max(
            abs(
              x -
                x[[1L]]
            )
          ) >
            1e-12
        }
      )
    )
  ) {
    stop(
      "At least one baseline QPH bandwidth is not isotropic."
    )
  }
}


successful_kde <- fit_summary[
  fit_summary$Method ==
    "Gaussian KDE" &
    fit_summary$Success,
  ,
  drop = FALSE
]

for (
  row_index in seq_len(
    nrow(
      successful_kde
    )
  )
) {

  species_name <- successful_kde$Species[[row_index]]

  independently_estimated <- hypervolume::estimate_bandwidth(
    data = species_matrices[[species_name]],
    method = "silverman"
  )

  independently_estimated <- as.numeric(
    independently_estimated
  )

  saved_bandwidth <- as.numeric(
    successful_kde[
      row_index,
      c(
        "Bandwidth_PC1",
        "Bandwidth_PC2",
        "Bandwidth_PC3"
      )
    ]
  )

  if (
    !isTRUE(
      all.equal(
        saved_bandwidth,
        independently_estimated,
        tolerance = 1e-10
      )
    )
  ) {
    stop(
      "Saved Gaussian KDE bandwidth differs from a fresh Silverman estimate for ",
      species_name,
      "."
    )
  }
}


# ============================================================
# Write audit and summary tables
# ============================================================

write_csv_safely(
  fit_summary,
  fit_summary_file
)

write_csv_safely(
  bandwidth_table,
  bandwidth_file
)

write_csv_safely(
  qph_audit_summary_table,
  qph_audit_file
)

write_csv_safely(
  qph_local_s_table,
  qph_local_s_file
)

write_csv_safely(
  qph_threshold_table,
  qph_threshold_file
)

write_csv_safely(
  kde_audit_table,
  kde_audit_file
)

write_csv_safely(
  svm_audit_table,
  svm_audit_file
)

write_csv_safely(
  svm_support_vector_table,
  svm_support_vector_file
)


# ============================================================
# Failure table
# ============================================================

failure_table <- fit_summary[
  !fit_summary$Success,
  c(
    "Condition_id",
    "Species",
    "Species_code",
    "Method",
    "Occurrence_count",
    "Sampling_seed",
    "Error_message"
  ),
  drop = FALSE
]

write_csv_safely(
  failure_table,
  failure_file
)


# ============================================================
# Model manifest
# ============================================================

model_manifest_rows <- list()
model_manifest_index <- 0L

for (
  species_name in expected_species
) {

  for (
    method_name in method_order
  ) {

    current_file <- model_file_path(
      species_name,
      method_name
    )

    model_manifest_index <- model_manifest_index + 1L

    model_manifest_rows[[model_manifest_index]] <- data.frame(
      Condition_id = model_key(
        species_name,
        method_name
      ),
      Species = species_name,
      Method = method_name,
      File_name = basename(
        current_file
      ),
      File_exists = file.exists(
        current_file
      ),
      File_size_bytes = if (
        file.exists(
          current_file
        )
      ) {
        as.numeric(
          file.info(
            current_file
          )$size
        )
      } else {
        NA_real_
      },
      MD5 = safe_md5(
        current_file
      ),
      stringsAsFactors = FALSE
    )
  }
}

model_manifest <- do.call(
  rbind,
  model_manifest_rows
)

write_csv_safely(
  model_manifest,
  model_manifest_file
)


# ============================================================
# Final results object and run metadata
# ============================================================

run_metadata <- list(
  script = "19_Acacia_Baseline_Fits.R",
  analysis_settings_hash = analysis_settings_hash,
  locked_design_hash = locked_design_hash,
  locked_archive_md5 = locked_archive_md5,
  qph_core_version = QPH_CORE_VERSION,
  qph_core_md5 = qph_core_md5,
  hypervolume_version = installed_hypervolume_version,
  e1071_version = installed_e1071_version,
  model_count_requested = nrow(
    fit_design
  ),
  model_count_successful = sum(
    fit_registry$Success
  ),
  model_count_failed = sum(
    !fit_registry$Success
  ),
  completed_at = as.character(
    Sys.time()
  )
)

saveRDS(
  run_metadata,
  run_metadata_file,
  version = 3
)


final_results <- list(
  metadata = run_metadata,
  analysis_settings = analysis_settings,
  fit_design = fit_design,
  model_registry = fit_registry,
  fit_summary = fit_summary,
  bandwidth_table = bandwidth_table,
  qph_audit_summary = qph_audit_summary_table,
  qph_local_s = qph_local_s_table,
  qph_thresholds = qph_threshold_table,
  kde_audit = kde_audit_table,
  svm_audit = svm_audit_table,
  svm_support_vectors = svm_support_vector_table,
  model_manifest = model_manifest,
  failures = failure_table
)

saveRDS(
  final_results,
  final_results_file,
  version = 3
)


# ============================================================
# Parameter notes
# ============================================================

parameter_notes <- c(
  "ACACIA REVISED BASELINE HYPERVOLUME FITS",
  "========================================",
  "",
  "Locked empirical inputs:",
  "  Five Acacia species in the shared occurrence-derived PC1-PC3 space.",
  "  No occurrence or PCA regeneration occurs in this script.",
  "",
  "QPH baseline:",
  "  Nasios-Bors-derived square-root local-distance bandwidth.",
  "  K = round(sqrt(n)).",
  "  For each occurrence, K squared distances to nearest OTHER occurrences",
  "  are summed and divided by K - 1.",
  "  The statistic is averaged over occurrences and square-rooted.",
  "  The resulting scalar h is used isotropically on PC1-PC3.",
  "  q = 0.99.",
  "  samples.per.point = 100.",
  "  sd.count = 3.",
  "",
  "Gaussian KDE baseline:",
  "  Species-specific hypervolume Silverman bandwidth.",
  "  This bandwidth is estimated independently from the QPH bandwidth.",
  "  Probability-mass quantile = 0.95.",
  "  samples.per.point = 100.",
  "  sd.count = 3.",
  "",
  "SVM baseline:",
  "  one-class radial SVM",
  "  nu = 0.01",
  "  gamma = 0.50",
  "  scale.factor = 1",
  "  samples.per.point = 100",
  "  projection/audit e1071 classifier uses scale = TRUE.",
  "",
  "Seeds:",
  "  QPH and Gaussian KDE share the same fixed seed within species.",
  "  SVM uses its own fixed seed within species.",
  paste0(
    "  Master seed = ",
    master_seed,
    "."
  ),
  "",
  paste0(
    "Locked design hash: ",
    locked_design_hash
  ),
  paste0(
    "Analysis settings hash: ",
    analysis_settings_hash
  ),
  paste0(
    "QPH core version: ",
    QPH_CORE_VERSION
  ),
  paste0(
    "QPH core MD5: ",
    qph_core_md5
  ),
  paste0(
    "hypervolume version: ",
    installed_hypervolume_version
  ),
  paste0(
    "e1071 version: ",
    installed_e1071_version
  ),
  "",
  paste0(
    "Successful models: ",
    sum(
      fit_registry$Success
    ),
    " / ",
    nrow(
      fit_registry
    )
  ),
  paste0(
    "Completed: ",
    Sys.time()
  )
)

writeLines(
  parameter_notes,
  con = parameter_notes_file
)

capture.output(
  sessionInfo(),
  file = session_information_file
)


# ============================================================
# Console summary
# ============================================================

message(
  "\n============================================================"
)

message(
  "19_Acacia_Baseline_Fits.R complete."
)

message(
  "Successful fits: ",
  sum(
    fit_registry$Success
  ),
  " / ",
  nrow(
    fit_registry
  )
)

message(
  "\nBaseline bandwidths:"
)

print(
  bandwidth_table,
  digits = 6,
  row.names = FALSE
)

message(
  "\nQPH audit summary:"
)

if (nrow(qph_audit_summary_table) > 0L) {
  print(
    qph_audit_summary_table[
      ,
      c(
        "Species",
        "n",
        "K",
        "Mean_s",
        "Baseline_scalar_h",
        "q",
        "Samples_per_point",
        "SD_count",
        "Sampling_seed"
      ),
      drop = FALSE
    ],
    digits = 6,
    row.names = FALSE
  )
}

message(
  "\nSVM QA:"
)

if (nrow(svm_audit_table) > 0L) {
  print(
    svm_audit_table[
      ,
      c(
        "Species",
        "Nu",
        "Gamma",
        "Internal_scaling",
        "Number_support_vectors",
        "Training_error_fraction",
        "Random_points_inside_audit_fraction"
      ),
      drop = FALSE
    ],
    digits = 6,
    row.names = FALSE
  )
}

message(
  "\nFinal results object:\n  ",
  normalizePath(
    final_results_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "============================================================"
)


# ============================================================
# Require complete baseline before downstream analyses
# ============================================================

if (
  nrow(
    failure_table
  ) > 0L
) {
  stop(
    "One or more Acacia baseline fits failed. Successful fits and checkpoint ",
    "objects were retained. Re-run Script 19 after addressing the failures; ",
    "do not proceed to Script 20 until all 15 fits succeed.\nFailure table:\n  ",
    normalizePath(
      failure_file,
      winslash = "/",
      mustWork = FALSE
    )
  )
}
