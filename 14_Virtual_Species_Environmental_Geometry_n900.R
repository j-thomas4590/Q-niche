# ============================================================
# 14_Virtual_Species_Environmental_Geometry_n900.R
# ============================================================
#
# PURPOSE
# -------
# Environmental-geometry validation for the TWO locked virtual species at the
# representative intermediate occurrence sample size n = 900.
#
#
rm(list = ls())
gc()


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
# Project paths
# ============================================================

# Run from the repository's root folder.
project_directory <- "."

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

output_directory <- file.path(
  analysis_root_directory,
  "03_Environmental_Geometry"
)

table_directory <- file.path(
  output_directory,
  "tables"
)

for (directory in c(
  output_directory,
  table_directory
)) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ============================================================
# Locked design
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

true_region_colour <- "#D9D9D9"
occurrence_colour <- "#111111"

numeric_tolerance <- 1e-8
classification_tolerance <- sqrt(
  .Machine$double.eps
)

# The same analytical gap corridor used by the original disconnected
# virtual-species validation.
gap_corridor_radius_multiplier <- 1.0


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

required_files <- c(
  locked_master_file,
  locked_settings_file,
  baseline_settings_file,
  baseline_results_file
)

missing_files <- required_files[
  !file.exists(
    required_files
  )
]

if (length(missing_files) > 0L) {
  stop(
    "Missing required upstream file(s):\n  ",
    paste(
      missing_files,
      collapse = "\n  "
    ),
    "\nRun Scripts 12 and 13 successfully before Script 14."
  )
}


# ============================================================
# Output files
# ============================================================

true_continuous_geometry_file <- file.path(
  table_directory,
  "Virtual_species_continuous_true_geometry_n900.csv"
)

occurrence_geometry_file <- file.path(
  table_directory,
  "Virtual_species_occurrence_environmental_geometry_n900.csv"
)

continuous_geometry_file <- file.path(
  table_directory,
  "Virtual_species_continuous_geometry_ALL_methods_n900.csv"
)

availability_geometry_file <- file.path(
  table_directory,
  "Virtual_species_availability_conditioned_geometry_n900.csv"
)

truth_truncation_file <- file.path(
  table_directory,
  "Virtual_species_truth_truncation_n900.csv"
)

disconnected_structural_file <- file.path(
  table_directory,
  "Virtual_species_disconnected_structural_geometry_n900.csv"
)

continuous_vs_available_file <- file.path(
  table_directory,
  "Virtual_species_continuous_VS_available_geometry_n900.csv"
)

input_qa_file <- file.path(
  table_directory,
  "Virtual_species_geometry_input_QA_n900.csv"
)

settings_file <- file.path(
  output_directory,
  "geometry_analysis_settings.rds"
)

final_results_file <- file.path(
  output_directory,
  "virtual_species_environmental_geometry_n900_sqrtNB_q099.rds"
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

  attempt <- try(
    terra::rast(x),
    silent = TRUE
  )

  if (
    !inherits(
      attempt,
      "try-error"
    ) &&
      inherits(
        attempt,
        "SpatRaster"
      )
  ) {
    return(
      attempt
    )
  }

  attempt <- try(
    terra::unwrap(x),
    silent = TRUE
  )

  if (
    !inherits(
      attempt,
      "try-error"
    ) &&
      inherits(
        attempt,
        "SpatRaster"
      )
  ) {
    return(
      attempt
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


euclidean_distance <- function(
    a,
    b
) {

  a <- as.numeric(a)
  b <- as.numeric(b)

  if (
    length(a) != length(b) ||
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
      "Invalid ellipsoid scales/radius."
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

  if (
    length(
      means
    ) != 3L ||
      length(
        sds
      ) != 3L ||
      any(
        !is.finite(
          c(
            means,
            sds
          )
        )
      ) ||
      any(
        sds <= 0
      )
  ) {
    stop(
      "Gaussian means/sds must contain three finite positive axis scales."
    )
  }

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


binary_metrics <- function(
    truth,
    prediction
) {

  truth <- as.logical(
    truth
  )

  prediction <- as.logical(
    prediction
  )

  if (
    length(
      truth
    ) != length(
      prediction
    ) ||
      anyNA(
        truth
      ) ||
      anyNA(
        prediction
      )
  ) {
    stop(
      "Truth/prediction vectors must be complete and equal length."
    )
  }

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

  union_n <- (
    tp +
      fp +
      fn
  )

  data.frame(
    True_available_environment_cells = true_n,
    Predicted_available_environment_cells = predicted_n,
    Intersection_available_environment_cells = tp,
    Union_available_environment_cells = union_n,
    False_positive_available_environment_cells = fp,
    False_negative_available_environment_cells = fn,
    True_negative_available_environment_cells = tn,

    Environmental_Jaccard_available = safe_fraction(
      tp,
      union_n
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

    stringsAsFactors = FALSE
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


model_object_path <- function(
    species_name,
    sample_size,
    method_name
) {

  condition_id <- condition_id_for(
    species_name,
    sample_size,
    method_name
  )

  file.path(
    baseline_fit_directory,
    "model_objects",
    paste0(
      condition_id,
      ".rds"
    )
  )
}


projection_raster_path <- function(
    species_name,
    sample_size,
    method_name
) {

  condition_id <- condition_id_for(
    species_name,
    sample_size,
    method_name
  )

  file.path(
    geographic_directory,
    "projection_rasters",
    paste0(
      condition_id,
      "__geographic_projection.tif"
    )
  )
}


# ============================================================
# Load upstream revised results
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
    "Could not recover upstream analysis hashes."
  )
}

if (
  !identical(
    baseline_settings$locked_design_hash,
    locked_design_hash
  )
) {
  stop(
    "Script-13 settings do not match the current Script-12 locked inputs."
  )
}

if (
  !identical(
    baseline_results$metadata$analysis_settings_hash,
    baseline_analysis_hash
  )
) {
  stop(
    "Script-13 final results and baseline settings hashes differ."
  )
}


# ============================================================
# Require the revised baseline design
# ============================================================

if (
  !identical(
    as.integer(
      baseline_settings$sample_sizes
    ),
    c(
      300L,
      900L,
      1500L
    )
  )
) {
  stop(
    "Unexpected Script-13 sample-size design."
  )
}

if (
  !identical(
    as.character(
      baseline_settings$species
    ),
    species_order
  )
) {
  stop(
    "Unexpected Script-13 species design."
  )
}

if (
  !identical(
    as.character(
      baseline_settings$methods
    ),
    method_order
  )
) {
  stop(
    "Unexpected Script-13 method design."
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
        0.99,
        tolerance = 1e-12
      )
    )
) {
  stop(
    "Script-13 QPH baseline is not the required sqrt-NB / q=0.99 design."
  )
}

if (
  !identical(
    as.character(
      baseline_settings$gaussian_kde$bandwidth
    ),
    "hypervolume current Silverman"
  ) ||
    !isTRUE(
      all.equal(
        as.numeric(
          baseline_settings$gaussian_kde$quantile
        ),
        0.95,
        tolerance = 1e-12
      )
    )
) {
  stop(
    "Script-13 Gaussian KDE baseline differs from the locked comparator."
  )
}

if (
  !isTRUE(
    all.equal(
      as.numeric(
        baseline_settings$svm$nu
      ),
      0.01,
      tolerance = 1e-12
    )
  ) ||
    !isTRUE(
      all.equal(
        as.numeric(
          baseline_settings$svm$gamma
        ),
        0.5,
        tolerance = 1e-12
      )
    )
) {
  stop(
    "Script-13 SVM baseline differs from the locked comparator."
  )
}


# ============================================================
# Shared Australian environmental-availability domain
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
    "No complete Australian PC1-PC3 cells are available."
  )
}


# ============================================================
# Locked truth and occurrence objects
# ============================================================

truth_rasters <- list(
  Unimodal = as_spatraster_safe(
    locked_inputs$truth$Unimodal$truth_raster
  ),
  Disconnected = as_spatraster_safe(
    locked_inputs$truth$Disconnected$truth_raster
  )
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

  if (
    is.null(
      occurrence_objects[[
        species_name
      ]]$pc
    )
  ) {
    stop(
      "Missing locked n=900 occurrence PC sample for ",
      species_name,
      "."
    )
  }

  occurrence_points <- set_pc_names(
    occurrence_objects[[
      species_name
    ]]$pc
  )

  if (
    nrow(
      occurrence_points
    ) != analysis_sample_size
  ) {
    stop(
      species_name,
      " occurrence sample has ",
      nrow(
        occurrence_points
      ),
      " rows rather than 900."
    )
  }

  if (
    !terra::compareGeom(
      truth_rasters[[
        species_name
      ]],
      pc_stack[[1L]],
      stopOnError = FALSE
    )
  ) {
    stop(
      species_name,
      " truth raster does not align with the locked PC landscape."
    )
  }
}


# ============================================================
# Continuous true environmental support: unimodal species
# ============================================================

unimodal_definition <- locked_inputs$truth$Unimodal$generating_definition

unimodal_means <- as.numeric(
  unimodal_definition$means
)

unimodal_sds <- as.numeric(
  unimodal_definition$sds
)

names(
  unimodal_means
) <- c(
  "PC1",
  "PC2",
  "PC3"
)

names(
  unimodal_sds
) <- c(
  "PC1",
  "PC2",
  "PC3"
)

unimodal_truth_values <- terra::values(
  truth_rasters$Unimodal,
  mat = FALSE
)[
  valid_pc_cells
]

if (
  any(
    !is.finite(
      unimodal_truth_values
    )
  ) ||
    !all(
      unimodal_truth_values %in%
        c(
          0,
          1
        )
    )
) {
  stop(
    "Unimodal truth raster is not complete binary data over the locked PC domain."
  )
}

unimodal_landscape_log_score <- gaussian_log_score(
  landscape_pc,
  unimodal_means,
  unimodal_sds
)

# Reconstruct the continuous Gaussian threshold from the minimum generating
# score among Australian cells classified as true presence.
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

if (
  !is.finite(
    unimodal_radius
  ) ||
    unimodal_radius <= 0
) {
  stop(
    "Could not reconstruct a positive continuous unimodal truth radius."
  )
}

unimodal_true_volume <- ellipsoid_volume(
  axis_scales = unimodal_sds,
  radius = unimodal_radius
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

  radius <- sqrt(
    rowSums(
      relative^2
    )
  )

  radius <=
    (
      unimodal_radius +
        classification_tolerance
    )
}


# ============================================================
# Continuous true environmental support: disconnected species
# ============================================================

disconnected_definition <- locked_inputs$truth$Disconnected$generating_definition

required_disconnected_fields <- c(
  "mode_A_mean",
  "mode_B_mean",
  "mode_sds",
  "truth_radius_sd_units",
  "mode_separation_sd_units",
  "environmental_truth_disconnected"
)

missing_disconnected_fields <- setdiff(
  required_disconnected_fields,
  names(
    disconnected_definition
  )
)

if (
  length(
    missing_disconnected_fields
  ) > 0L
) {
  stop(
    "Disconnected generating definition is missing: ",
    paste(
      missing_disconnected_fields,
      collapse = ", "
    )
  )
}

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

names(
  mode_A_mean
) <- c(
  "PC1",
  "PC2",
  "PC3"
)

names(
  mode_B_mean
) <- c(
  "PC1",
  "PC2",
  "PC3"
)

names(
  mode_sds
) <- c(
  "PC1",
  "PC2",
  "PC3"
)

if (
  !isTRUE(
    disconnected_definition$environmental_truth_disconnected
  )
) {
  stop(
    "Locked disconnected truth is not marked as analytically disconnected."
  )
}

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
    "Disconnected truth has no positive analytical between-mode gap."
  )
}

one_disconnected_component_volume <- ellipsoid_volume(
  axis_scales = mode_sds,
  radius = disconnected_radius
)

disconnected_true_volume <- (
  2 *
    one_disconnected_component_volume
)

disconnected_true_centroid <- (
  mode_A_mean +
    mode_B_mean
) /
  2


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
        classification_tolerance
  ) |
    (
      distance_B <=
        disconnected_radius +
          classification_tolerance
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


# Cylindrical corridor in standardised coordinates transformed back into raw
# PC units through the diagonal mode_sds Jacobian.
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


# ============================================================
# Bundle analytical continuous truth
# ============================================================

truth_definitions <- list(
  Unimodal = list(
    true_volume = unimodal_true_volume,
    true_centroid = unimodal_true_centroid,
    classify_true = classify_unimodal_true,
    definition = paste0(
      "Single Gaussian-threshold ellipsoid; scaled radius = ",
      signif(
        unimodal_radius,
        8
      )
    )
  ),
  Disconnected = list(
    true_volume = disconnected_true_volume,
    true_centroid = disconnected_true_centroid,
    classify_true = classify_disconnected_true,
    definition = paste0(
      "Union of two disjoint equal ellipsoids; scaled radius = ",
      signif(
        disconnected_radius,
        8
      ),
      "; scaled separation = ",
      signif(
        disconnected_separation,
        8
      )
    )
  )
)


# ============================================================
# Continuous true-geometry table
# ============================================================

true_geometry_rows <- list()

for (
  species_name in species_order
) {

  truth_definition <- truth_definitions[[
    species_name
  ]]

  true_geometry_rows[[
    species_name
  ]] <- data.frame(
    Virtual_species = species_name,
    Species_label = unname(
      species_labels[
        species_name
      ]
    ),
    Sample_size = analysis_sample_size,
    True_environmental_volume = truth_definition$true_volume,
    True_centroid_PC1 = truth_definition$true_centroid[[1L]],
    True_centroid_PC2 = truth_definition$true_centroid[[2L]],
    True_centroid_PC3 = truth_definition$true_centroid[[3L]],
    Equivalent_sphere_radius = equivalent_sphere_radius(
      truth_definition$true_volume
    ),
    Continuous_truth_definition = truth_definition$definition,
    stringsAsFactors = FALSE
  )
}

true_continuous_geometry <- do.call(
  rbind,
  true_geometry_rows
)

rownames(
  true_continuous_geometry
) <- NULL

write_csv_safely(
  true_continuous_geometry,
  true_continuous_geometry_file
)


# ============================================================
# Load and QA revised n=900 fitted Hypervolumes
# ============================================================

model_fits <- list()
input_qa_rows <- list()
input_qa_index <- 0L

for (
  species_name in species_order
) {

  model_fits[[
    species_name
  ]] <- list()

  for (
    method_name in method_order
  ) {

    condition_id <- condition_id_for(
      species_name,
      analysis_sample_size,
      method_name
    )

    model_file <- model_object_path(
      species_name,
      analysis_sample_size,
      method_name
    )

    projection_file <- projection_raster_path(
      species_name,
      analysis_sample_size,
      method_name
    )

    if (!file.exists(model_file)) {
      stop(
        "Missing revised n=900 model object:\n  ",
        model_file
      )
    }

    if (!file.exists(projection_file)) {
      stop(
        "Missing revised n=900 projection raster:\n  ",
        projection_file
      )
    }

    fit <- readRDS(
      model_file
    )

    if (
      !isTRUE(
        fit$success
      ) ||
        is.null(
          fit$hypervolume
        )
    ) {
      stop(
        "Revised n=900 model fit is unavailable for ",
        condition_id,
        "."
      )
    }

    if (
      !identical(
        fit$analysis_settings_hash,
        baseline_analysis_hash
      )
    ) {
      stop(
        "Model settings hash mismatch for ",
        condition_id,
        "."
      )
    }

    methods::validObject(
      fit$hypervolume
    )

    projection_raster <- terra::rast(
      projection_file
    )

    if (
      !terra::compareGeom(
        projection_raster,
        truth_rasters[[
          species_name
        ]],
        stopOnError = FALSE
      )
    ) {
      stop(
        "Projection raster geometry mismatch for ",
        condition_id,
        "."
      )
    }

    # Method-specific baseline QA.
    qph_q <- NA_real_
    qph_K <- NA_integer_
    qph_scalar_h <- NA_real_
    qph_isotropic <- NA
    kde_quantile <- NA_real_
    svm_scale_TRUE_QA <- NA

    if (
      identical(
        method_name,
        "QPH"
      )
    ) {

      if (
        is.null(
          fit$qph_result
        ) ||
          is.null(
            fit$qph_result$audit
          )
      ) {
        stop(
          "QPH audit is missing for ",
          condition_id,
          "."
        )
      }

      qph_q <- as.numeric(
        fit$qph_result$audit$q
      )

      qph_K <- as.integer(
        fit$qph_result$audit$K
      )

      qph_scalar_h <- as.numeric(
        fit$qph_result$audit$baseline_scalar_h
      )

      qph_bandwidth <- as.numeric(
        fit$qph_result$bandwidth
      )

      qph_isotropic <- (
        length(
          qph_bandwidth
        ) == 3L &&
          max(
            abs(
              qph_bandwidth -
                qph_bandwidth[[1L]]
            )
          ) <
            numeric_tolerance
      )

      if (
        !isTRUE(
          all.equal(
            qph_q,
            0.99,
            tolerance = 1e-12
          )
        ) ||
          qph_K !=
            round(
              sqrt(
                analysis_sample_size
              )
            ) ||
          !isTRUE(
            qph_isotropic
          )
      ) {
        stop(
          "QPH baseline QA failed for ",
          condition_id,
          "."
        )
      }
    }

    if (
      identical(
        method_name,
        "Gaussian KDE"
      )
    ) {

      q_candidate <- suppressWarnings(
        as.numeric(
          fit$hypervolume@Parameters$quantile.requested
        )
      )

      if (
        length(
          q_candidate
        ) == 1L &&
          is.finite(
            q_candidate
          )
      ) {
        kde_quantile <- q_candidate
      }

      if (
        is.finite(
          kde_quantile
        ) &&
          !isTRUE(
            all.equal(
              kde_quantile,
              0.95,
              tolerance = 1e-12
            )
          )
      ) {
        stop(
          "Gaussian KDE quantile QA failed for ",
          condition_id,
          "."
        )
      }
    }

    if (
      identical(
        method_name,
        "SVM"
      )
    ) {

      svm_qa <- baseline_results$svm_classifier_qa

      qa_match <- svm_qa[
        svm_qa$Condition_id ==
          condition_id,
        ,
        drop = FALSE
      ]

      if (
        nrow(
          qa_match
        ) != 1L
      ) {
        stop(
          "Could not recover one SVM projection-classifier QA row for ",
          condition_id,
          "."
        )
      }

      svm_scale_TRUE_QA <- isTRUE(
        qa_match$Projection_classifier_scale[[1L]]
      )

      if (!svm_scale_TRUE_QA) {
        stop(
          "SVM projection classifier is not recorded as scale=TRUE for ",
          condition_id,
          "."
        )
      }
    }

    input_qa_index <- input_qa_index + 1L

    input_qa_rows[[
      input_qa_index
    ]] <- data.frame(
      Condition_id = condition_id,
      Virtual_species = species_name,
      Sample_size = analysis_sample_size,
      Method = method_name,
      Model_success = TRUE,
      Model_file = normalizePath(
        model_file,
        winslash = "/",
        mustWork = TRUE
      ),
      Projection_file = normalizePath(
        projection_file,
        winslash = "/",
        mustWork = TRUE
      ),
      Model_MD5 = safe_md5(
        model_file
      ),
      Projection_MD5 = safe_md5(
        projection_file
      ),
      Hypervolume_random_points = nrow(
        fit$hypervolume@RandomPoints
      ),
      Hypervolume_volume = as.numeric(
        fit$hypervolume@Volume
      ),
      QPH_q = qph_q,
      QPH_K = qph_K,
      QPH_scalar_h = qph_scalar_h,
      QPH_isotropic = qph_isotropic,
      KDE_quantile = kde_quantile,
      SVM_projection_scale_TRUE = svm_scale_TRUE_QA,
      stringsAsFactors = FALSE
    )

    model_fits[[
      species_name
    ]][[
      method_name
    ]] <- fit
  }
}

input_qa <- do.call(
  rbind,
  input_qa_rows
)

rownames(
  input_qa
) <- NULL

write_csv_safely(
  input_qa,
  input_qa_file
)


# ============================================================
# Occurrence environmental geometry
# ============================================================

occurrence_geometry_rows <- list()

for (
  species_name in species_order
) {

  occurrence_points <- set_pc_names(
    occurrence_objects[[
      species_name
    ]]$pc
  )

  truth_definition <- truth_definitions[[
    species_name
  ]]

  occurrence_inside_truth <- truth_definition$classify_true(
    occurrence_points
  )

  if (
    !all(
      occurrence_inside_truth
    )
  ) {
    stop(
      species_name,
      ": one or more locked n=900 occurrences fall outside the reconstructed ",
      "continuous generating support."
    )
  }

  occurrence_centroid <- colMeans(
    occurrence_points
  )

  occurrence_geometry_rows[[
    species_name
  ]] <- data.frame(
    Virtual_species = species_name,
    Species_label = unname(
      species_labels[
        species_name
      ]
    ),
    Sample_size = analysis_sample_size,
    Occurrence_points = nrow(
      occurrence_points
    ),
    Occurrence_centroid_PC1 = occurrence_centroid[[1L]],
    Occurrence_centroid_PC2 = occurrence_centroid[[2L]],
    Occurrence_centroid_PC3 = occurrence_centroid[[3L]],
    True_continuous_centroid_PC1 = truth_definition$true_centroid[[1L]],
    True_continuous_centroid_PC2 = truth_definition$true_centroid[[2L]],
    True_continuous_centroid_PC3 = truth_definition$true_centroid[[3L]],
    Occurrence_to_continuous_true_centroid_displacement = euclidean_distance(
      occurrence_centroid,
      truth_definition$true_centroid
    ),
    Occurrence_to_continuous_true_centroid_displacement_normalized = safe_fraction(
      euclidean_distance(
        occurrence_centroid,
        truth_definition$true_centroid
      ),
      equivalent_sphere_radius(
        truth_definition$true_volume
      )
    ),
    Fraction_occurrences_inside_continuous_truth = mean(
      occurrence_inside_truth
    ),
    stringsAsFactors = FALSE
  )
}

occurrence_geometry <- do.call(
  rbind,
  occurrence_geometry_rows
)

rownames(
  occurrence_geometry
) <- NULL

write_csv_safely(
  occurrence_geometry,
  occurrence_geometry_file
)


# ============================================================
# SECONDARY: continuous-generating-truth geometry
# ============================================================

continuous_rows <- list()
continuous_index <- 0L
continuous_structural_rows <- list()
continuous_structural_index <- 0L

for (
  species_name in species_order
) {

  truth_definition <- truth_definitions[[
    species_name
  ]]

  occurrence_points <- set_pc_names(
    occurrence_objects[[
      species_name
    ]]$pc
  )

  occurrence_centroid <- colMeans(
    occurrence_points
  )

  true_volume <- as.numeric(
    truth_definition$true_volume
  )

  true_centroid <- as.numeric(
    truth_definition$true_centroid
  )

  true_equivalent_radius <- equivalent_sphere_radius(
    true_volume
  )

  for (
    method_name in method_order
  ) {

    fit <- model_fits[[
      species_name
    ]][[
      method_name
    ]]

    hv <- fit$hypervolume

    hv_points <- set_pc_names(
      hv@RandomPoints
    )

    estimated_volume <- as.numeric(
      hv@Volume
    )

    if (
      !is.finite(
        estimated_volume
      ) ||
        estimated_volume <= 0
    ) {
      stop(
        species_name,
        " / ",
        method_name,
        " has an invalid Hypervolume volume."
      )
    }

    fitted_centroid <- colMeans(
      hv_points
    )

    inside_truth <- truth_definition$classify_true(
      hv_points
    )

    fitted_precision <- mean(
      inside_truth
    )

    fitted_precision_mc_se <- sqrt(
      fitted_precision *
        (
          1 -
            fitted_precision
        ) /
        nrow(
          hv_points
        )
    )

    intersection_volume_raw <- (
      estimated_volume *
        fitted_precision
    )

    # Clamp Monte-Carlo overlap only to physical set-theoretic bounds.
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

    jaccard <- safe_fraction(
      intersection_volume,
      union_volume
    )

    sorensen <- safe_fraction(
      2 *
        intersection_volume,
      true_volume +
        estimated_volume
    )

    true_volume_recall <- safe_fraction(
      intersection_volume,
      true_volume
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

    fitted_true_centroid_displacement <- euclidean_distance(
      fitted_centroid,
      true_centroid
    )

    fitted_occurrence_centroid_displacement <- euclidean_distance(
      fitted_centroid,
      occurrence_centroid
    )

    occurrence_true_centroid_displacement <- euclidean_distance(
      occurrence_centroid,
      true_centroid
    )

    continuous_index <- continuous_index + 1L

    continuous_rows[[
      continuous_index
    ]] <- data.frame(
      Virtual_species = species_name,
      Species_label = unname(
        species_labels[
          species_name
        ]
      ),
      Sample_size = analysis_sample_size,
      Method = method_name,
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
      Occurrence_centroid_PC1 = occurrence_centroid[[1L]],
      Occurrence_centroid_PC2 = occurrence_centroid[[2L]],
      Occurrence_centroid_PC3 = occurrence_centroid[[3L]],
      Fitted_centroid_PC1 = fitted_centroid[[1L]],
      Fitted_centroid_PC2 = fitted_centroid[[2L]],
      Fitted_centroid_PC3 = fitted_centroid[[3L]],
      Centroid_displacement_fitted_to_true = fitted_true_centroid_displacement,
      Centroid_displacement_fitted_to_true_normalized = safe_fraction(
        fitted_true_centroid_displacement,
        true_equivalent_radius
      ),
      Centroid_displacement_fitted_to_occurrence = fitted_occurrence_centroid_displacement,
      Centroid_displacement_occurrence_to_true = occurrence_true_centroid_displacement,
      Hypervolume_random_points = nrow(
        hv_points
      ),
      Fraction_fitted_points_inside_true_support = fitted_precision,
      Fraction_fitted_points_inside_true_support_MC_SE = fitted_precision_mc_se,
      Intersection_volume_raw_MC = intersection_volume_raw,
      Intersection_volume = intersection_volume,
      Union_volume = union_volume,
      Environmental_Jaccard = jaccard,
      Environmental_Sorensen = sorensen,
      True_volume_recall = true_volume_recall,
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

    if (
      identical(
        species_name,
        "Disconnected"
      )
    ) {

      inside_gap <- classify_disconnected_gap(
        hv_points
      )

      fraction_in_gap <- mean(
        inside_gap
      )

      gap_invasion_volume_raw <- (
        estimated_volume *
          fraction_in_gap
      )

      gap_invasion_volume <- min(
        max(
          gap_invasion_volume_raw,
          0
        ),
        disconnected_gap_volume,
        estimated_volume
      )

      continuous_structural_index <- continuous_structural_index + 1L

      continuous_structural_rows[[
        continuous_structural_index
      ]] <- data.frame(
        Virtual_species = species_name,
        Sample_size = analysis_sample_size,
        Method = method_name,
        Continuous_structural_region = "Between-mode analytical gap corridor",
        Continuous_gap_true_volume = disconnected_gap_volume,
        Fraction_fitted_random_points_in_continuous_gap = fraction_in_gap,
        Continuous_gap_invasion_volume_raw_MC = gap_invasion_volume_raw,
        Continuous_gap_invasion_volume = gap_invasion_volume,
        Fraction_continuous_gap_filled = safe_fraction(
          gap_invasion_volume,
          disconnected_gap_volume
        ),
        stringsAsFactors = FALSE
      )
    }
  }
}

continuous_geometry <- do.call(
  rbind,
  continuous_rows
)

rownames(
  continuous_geometry
) <- NULL

write_csv_safely(
  continuous_geometry,
  continuous_geometry_file
)


# ============================================================
# PRIMARY: availability-conditioned environmental geometry
# ============================================================

availability_rows <- list()
availability_index <- 0L
truth_truncation_rows <- list()
truth_truncation_index <- 0L
available_structural_rows <- list()
available_structural_index <- 0L

# The analytical disconnected gap is evaluated on the same Australian
# PC1-PC3 availability points used by all estimator projections.
available_gap_mask <- classify_disconnected_gap(
  landscape_pc
)

for (
  species_name in species_order
) {

  truth_raster <- truth_rasters[[
    species_name
  ]]

  truth_values_full <- terra::values(
    truth_raster,
    mat = FALSE
  )

  truth_values <- truth_values_full[
    valid_pc_cells
  ]

  if (
    any(
      !is.finite(
        truth_values
      )
    ) ||
      !all(
        truth_values %in%
          c(
            0,
            1
          )
      )
  ) {
    stop(
      species_name,
      " truth raster is not complete binary data over the locked ",
      "Australian PC domain."
    )
  }

  truth_available <- (
    truth_values == 1
  )

  true_available_centroid <- pc_centroid(
    landscape_pc,
    truth_available
  )

  occurrence_points <- set_pc_names(
    occurrence_objects[[
      species_name
    ]]$pc
  )

  occurrence_centroid <- colMeans(
    occurrence_points
  )

  analytical_centroid <- truth_definitions[[
    species_name
  ]]$true_centroid

  truth_truncation_index <- truth_truncation_index + 1L

  truth_truncation_rows[[
    truth_truncation_index
  ]] <- data.frame(
    Virtual_species = species_name,
    Species_label = unname(
      species_labels[
        species_name
      ]
    ),
    Sample_size = analysis_sample_size,
    Analytical_continuous_true_volume = truth_definitions[[
      species_name
    ]]$true_volume,
    Analytical_continuous_centroid_PC1 = analytical_centroid[[1L]],
    Analytical_continuous_centroid_PC2 = analytical_centroid[[2L]],
    Analytical_continuous_centroid_PC3 = analytical_centroid[[3L]],
    Australian_environmental_availability_cells = nrow(
      landscape_pc
    ),
    Australian_true_niche_cells = sum(
      truth_available
    ),
    Australian_true_niche_fraction_of_available_cells = mean(
      truth_available
    ),
    Australian_true_centroid_PC1 = true_available_centroid[[1L]],
    Australian_true_centroid_PC2 = true_available_centroid[[2L]],
    Australian_true_centroid_PC3 = true_available_centroid[[3L]],
    Occurrence_centroid_PC1 = occurrence_centroid[[1L]],
    Occurrence_centroid_PC2 = occurrence_centroid[[2L]],
    Occurrence_centroid_PC3 = occurrence_centroid[[3L]],
    Analytical_to_Australian_true_centroid_displacement = euclidean_distance(
      analytical_centroid,
      true_available_centroid
    ),
    Occurrence_to_Australian_true_centroid_displacement = euclidean_distance(
      occurrence_centroid,
      true_available_centroid
    ),
    Occurrence_to_analytical_centroid_displacement = euclidean_distance(
      occurrence_centroid,
      analytical_centroid
    ),
    stringsAsFactors = FALSE
  )

  for (
    method_name in method_order
  ) {

    projection_file <- projection_raster_path(
      species_name,
      analysis_sample_size,
      method_name
    )

    prediction_raster <- terra::rast(
      projection_file
    )

    prediction_values_full <- terra::values(
      prediction_raster,
      mat = FALSE
    )

    prediction_values <- prediction_values_full[
      valid_pc_cells
    ]

    if (
      any(
        !is.finite(
          prediction_values
        )
      ) ||
        !all(
          prediction_values %in%
            c(
              0,
              1
            )
        )
    ) {
      stop(
        "Projection raster is not complete binary data over the locked PC domain for ",
        species_name,
        " / ",
        method_name,
        "."
      )
    }

    prediction_available <- (
      prediction_values == 1
    )

    metrics <- binary_metrics(
      truth = truth_available,
      prediction = prediction_available
    )

    predicted_available_centroid <- pc_centroid(
      landscape_pc,
      prediction_available
    )

    availability_index <- availability_index + 1L

    availability_rows[[
      availability_index
    ]] <- cbind(
      data.frame(
        Virtual_species = species_name,
        Species_label = unname(
          species_labels[
            species_name
          ]
        ),
        Sample_size = analysis_sample_size,
        Method = method_name,
        Australian_environmental_availability_cells = nrow(
          landscape_pc
        ),
        True_available_centroid_PC1 = true_available_centroid[[1L]],
        True_available_centroid_PC2 = true_available_centroid[[2L]],
        True_available_centroid_PC3 = true_available_centroid[[3L]],
        Predicted_available_centroid_PC1 = predicted_available_centroid[[1L]],
        Predicted_available_centroid_PC2 = predicted_available_centroid[[2L]],
        Predicted_available_centroid_PC3 = predicted_available_centroid[[3L]],
        Environmental_centroid_displacement_available = euclidean_distance(
          predicted_available_centroid,
          true_available_centroid
        ),
        Occurrence_to_true_available_centroid_displacement = euclidean_distance(
          occurrence_centroid,
          true_available_centroid
        ),
        Predicted_to_occurrence_centroid_displacement = euclidean_distance(
          predicted_available_centroid,
          occurrence_centroid
        ),
        stringsAsFactors = FALSE
      ),
      metrics
    )

    if (
      identical(
        species_name,
        "Disconnected"
      )
    ) {

      available_structural_index <- available_structural_index + 1L

      available_structural_rows[[
        available_structural_index
      ]] <- data.frame(
        Virtual_species = species_name,
        Sample_size = analysis_sample_size,
        Method = method_name,
        Available_structural_region = "Available Australian cells in between-mode gap",
        Available_gap_cells = sum(
          available_gap_mask
        ),
        Predicted_available_gap_cells = sum(
          available_gap_mask &
            prediction_available
        ),
        Available_gap_prediction_rate = if (
          any(
            available_gap_mask
          )
        ) {
          mean(
            prediction_available[
              available_gap_mask
            ]
          )
        } else {
          NA_real_
        },
        stringsAsFactors = FALSE
      )
    }
  }
}


availability_geometry <- do.call(
  rbind,
  availability_rows
)

rownames(
  availability_geometry
) <- NULL

truth_truncation <- do.call(
  rbind,
  truth_truncation_rows
)

rownames(
  truth_truncation
) <- NULL

write_csv_safely(
  availability_geometry,
  availability_geometry_file
)

write_csv_safely(
  truth_truncation,
  truth_truncation_file
)


# ============================================================
# Combined disconnected structural geometry
# ============================================================

continuous_structural_geometry <- if (
  length(
    continuous_structural_rows
  ) > 0L
) {
  do.call(
    rbind,
    continuous_structural_rows
  )
} else {
  data.frame()
}

available_structural_geometry <- if (
  length(
    available_structural_rows
  ) > 0L
) {
  do.call(
    rbind,
    available_structural_rows
  )
} else {
  data.frame()
}

if (
  nrow(
    continuous_structural_geometry
  ) != 3L ||
    nrow(
      available_structural_geometry
    ) != 3L
) {
  stop(
    "Expected exactly three disconnected structural rows in each geometry view."
  )
}

disconnected_structural_geometry <- merge(
  continuous_structural_geometry,
  available_structural_geometry,
  by = c(
    "Virtual_species",
    "Sample_size",
    "Method"
  ),
  all = TRUE,
  sort = FALSE
)

disconnected_structural_geometry <- disconnected_structural_geometry[
  match(
    method_order,
    disconnected_structural_geometry$Method
  ),
  ,
  drop = FALSE
]

write_csv_safely(
  disconnected_structural_geometry,
  disconnected_structural_file
)


# ============================================================
# Side-by-side continuous and availability-conditioned geometry
# ============================================================

continuous_keep <- continuous_geometry[
  ,
  c(
    "Virtual_species",
    "Species_label",
    "Sample_size",
    "Method",
    "True_environmental_volume",
    "Estimated_environmental_volume",
    "Relative_volume_error_percent",
    "Centroid_displacement_fitted_to_true",
    "Environmental_Jaccard",
    "Environmental_Sorensen",
    "Fitted_volume_precision",
    "True_volume_recall",
    "False_positive_fraction_of_fitted_volume",
    "False_negative_fraction_of_true_volume"
  ),
  drop = FALSE
]

names(
  continuous_keep
)[
  names(
    continuous_keep
  ) == "Centroid_displacement_fitted_to_true"
] <- "Continuous_truth_centroid_displacement"

names(
  continuous_keep
)[
  names(
    continuous_keep
  ) == "Environmental_Jaccard"
] <- "Continuous_truth_Environmental_Jaccard"

names(
  continuous_keep
)[
  names(
    continuous_keep
  ) == "Environmental_Sorensen"
] <- "Continuous_truth_Environmental_Sorensen"

continuous_vs_available <- merge(
  availability_geometry,
  continuous_keep,
  by = c(
    "Virtual_species",
    "Species_label",
    "Sample_size",
    "Method"
  ),
  all.x = TRUE,
  sort = FALSE
)

row_order_key <- paste(
  continuous_vs_available$Virtual_species,
  continuous_vs_available$Method,
  sep = "||"
)

expected_order_key <- as.vector(
  outer(
    species_order,
    method_order,
    paste,
    sep = "||"
  )
)

continuous_vs_available <- continuous_vs_available[
  match(
    expected_order_key,
    row_order_key
  ),
  ,
  drop = FALSE
]

write_csv_safely(
  continuous_vs_available,
  continuous_vs_available_file
)


# ============================================================
# Analysis settings
# ============================================================

analysis_settings <- list(
  script = "14_Virtual_Species_Environmental_Geometry_n900.R",
  sample_size = analysis_sample_size,
  species = species_order,
  methods = method_order,
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  primary_estimand = paste(
    "Known binary virtual-species truth evaluated over the actual Australian",
    "PC1-PC3 environmental-availability cells"
  ),
  primary_weighting = paste(
    "One environmental observation per valid Australian PC1-PC3 raster cell;",
    "no geographic cell-area weighting"
  ),
  secondary_estimand = paste(
    "Analytical continuous generating support in PC1-PC3; overlap estimated",
    "from fitted Hypervolume RandomPoints"
  ),
  structural_diagnostic = paste(
    "Disconnected between-mode gap evaluated continuously and over available",
    "Australian environmental cells"
  ),
  method_colours = method_colours,
  true_region_colour = true_region_colour,
  occurrence_colour = occurrence_colour,
  qph_baseline = list(
    bandwidth = "sqrtNB",
    q = 0.99
  ),
  kde_baseline = list(
    bandwidth = "current Silverman",
    quantile = 0.95
  ),
  svm_baseline = list(
    nu = 0.01,
    gamma = 0.5,
    geographic_classifier_scale = TRUE
  )
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

saveRDS(
  list(
    analysis_settings_hash = analysis_settings_hash,
    settings = analysis_settings
  ),
  settings_file,
  version = 3
)


# ============================================================
# Final results object
# ============================================================

final_results <- list(
  metadata = list(
    script = "14_Virtual_Species_Environmental_Geometry_n900.R",
    analysis_settings_hash = analysis_settings_hash,
    locked_design_hash = locked_design_hash,
    baseline_analysis_hash = baseline_analysis_hash,
    completed_at = as.character(
      Sys.time()
    )
  ),
  analysis_settings = analysis_settings,
  true_continuous_geometry = true_continuous_geometry,
  occurrence_geometry = occurrence_geometry,
  continuous_geometry = continuous_geometry,
  availability_conditioned_geometry = availability_geometry,
  truth_truncation = truth_truncation,
  disconnected_structural_geometry = disconnected_structural_geometry,
  continuous_vs_available = continuous_vs_available,
  input_qa = input_qa
)

saveRDS(
  final_results,
  final_results_file,
  version = 3
)


# ============================================================
# Console diagnostics
# ============================================================

message(
  "\nPRIMARY availability-conditioned environmental recovery:"
)

print(
  availability_geometry[
    ,
    c(
      "Virtual_species",
      "Method",
      "Environmental_Jaccard_available",
      "Environmental_Sorensen_available",
      "Omission_available",
      "Commission_available",
      "Relative_available_environment_count_error",
      "Environmental_centroid_displacement_available"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)

message(
  "\nSECONDARY continuous-generating-truth geometry:"
)

print(
  continuous_geometry[
    ,
    c(
      "Virtual_species",
      "Method",
      "True_environmental_volume",
      "Estimated_environmental_volume",
      "Relative_volume_error_percent",
      "Centroid_displacement_fitted_to_true",
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

message(
  "\nContinuous-generating truth versus Australian-realised truth:"
)

print(
  truth_truncation[
    ,
    c(
      "Virtual_species",
      "Analytical_continuous_true_volume",
      "Australian_true_niche_cells",
      "Australian_true_niche_fraction_of_available_cells",
      "Analytical_to_Australian_true_centroid_displacement",
      "Occurrence_to_Australian_true_centroid_displacement",
      "Occurrence_to_analytical_centroid_displacement"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)

message(
  "\nDisconnected between-mode gap:"
)

print(
  disconnected_structural_geometry,
  digits = 5,
  row.names = FALSE
)


# ============================================================
# Notes and session information
# ============================================================

analysis_notes <- c(
  "Revised virtual-species environmental geometry at n = 900",
  "========================================================",
  "",
  "Species:",
  "  Unimodal Gaussian-PCA",
  "  Disconnected bimodal",
  "",
  "No Hypervolumes are refitted in this script.",
  "All n=900 estimator objects and projection rasters come from Script 13.",
  "",
  "Primary environmental estimand:",
  "  Known binary truth over environmental combinations actually available",
  "  across the Australian PC1-PC3 landscape.",
  "  Each valid Australian PC raster cell contributes one environmental",
  "  observation; geographic area is not used as a weight.",
  "",
  "Secondary environmental estimand:",
  "  Analytical continuous generating support in PC1-PC3.",
  "  Continuous fitted/truth overlap is estimated using the uniform",
  "  Hypervolume RandomPoints and the fitted Hypervolume volume.",
  "",
  "Disconnected structural diagnostic:",
  "  Continuous fitted volume entering the between-mode gap plus the",
  "  prediction rate among Australian environmental cells lying in that gap.",
  "",
  "Baseline methods:",
  "  QPH: sqrt-NB bandwidth, q=0.99, spp=100, sd.count=3.",
  "  Gaussian KDE: own current Silverman bandwidth, q=0.95, spp=100, sd.count=3.",
  "  SVM: nu=0.01, gamma=0.5; Script-13 geographic classifier uses scale=TRUE.",
  "",
  "Publication figures are deferred to the final consolidation script.",
  "",
  paste0(
    "Locked input hash: ",
    locked_design_hash
  ),
  paste0(
    "Script-13 baseline hash: ",
    baseline_analysis_hash
  ),
  paste0(
    "Script-14 geometry hash: ",
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
  "14_Virtual_Species_Environmental_Geometry_n900.R complete."
)

message(
  "Availability-conditioned rows: ",
  nrow(
    availability_geometry
  ),
  " / 6"
)

message(
  "Continuous-truth rows: ",
  nrow(
    continuous_geometry
  ),
  " / 6"
)

message(
  "Disconnected structural rows: ",
  nrow(
    disconnected_structural_geometry
  ),
  " / 3"
)

message(
  "Input QA rows: ",
  nrow(
    input_qa
  ),
  " / 6"
)

message(
  "Primary availability-conditioned table:\n  ",
  normalizePath(
    availability_geometry_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "Secondary continuous-truth table:\n  ",
  normalizePath(
    continuous_geometry_file,
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
