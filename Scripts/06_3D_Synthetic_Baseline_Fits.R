# ============================================================
# 06_3D_Synthetic_Baseline_Fits.R
# ============================================================
#
# Authoritative baseline fitting script for the FINAL revised
# three-dimensional synthetic benchmark.
#
# This script has one responsibility:
#   1. lock and verify the original nested 3D occurrence clouds;
#   2. fit baseline QPH, Gaussian KDE, and one-class radial SVM;
#   3. save restartable model objects and complete parameter audits.
#
# ============================================================
# LOCKED SYNTHETIC DESIGN
# ============================================================
#
# Three analytically controlled regions:
#
#   solid_ball
#     Solid ball
#     radius = 5
#     exact true volume = (4/3) * pi * 5^3
#     expected Betti numbers: beta0 = 1, beta1 = 0, beta2 = 0
#
#   solid_torus
#     Solid torus
#     major radius = 4
#     minor radius = 1.5
#     exact true volume = 2 * pi^2 * 4 * 1.5^2
#     expected Betti numbers: beta0 = 1, beta1 = 1, beta2 = 0
#
#   hollow_shell
#     Hollow spherical region
#     inner radius = 2.5
#     outer radius = 5
#     exact true volume = (4/3) * pi * (5^3 - 2.5^3)
#     expected Betti numbers: beta0 = 1, beta1 = 0, beta2 = 1
#
# Nested occurrence sample sizes:
#   n = 300, 900, 1500
#
# Original authoritative master seed:
#   812301
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
  "3D_Synthetic_sqrtNB_q099"
)

locked_input_directory <- file.path(
  analysis_root_directory,
  "00_Locked_Inputs"
)

output_directory <- file.path(
  analysis_root_directory,
  "01_Baseline_Fits"
)

occurrence_directory <- file.path(
  locked_input_directory,
  "synthetic_3d_occurrence_clouds"
)

scenario_directory <- file.path(
  output_directory,
  "scenario_objects"
)

for (current_directory in c(
  scripts_directory,
  locked_input_directory,
  output_directory,
  occurrence_directory,
  scenario_directory
)) {
  dir.create(
    current_directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ============================================================
# Source authoritative QPH core
# ============================================================

qph_core_file <- file.path(
  scripts_directory,
  "00_QPH_Core_Functions.R"
)

if (!file.exists(qph_core_file)) {
  stop(
    "Authoritative QPH core file not found:\n  ",
    qph_core_file
  )
}

source(
  qph_core_file,
  local = FALSE
)

expected_qph_core_version <- "sqrtNB_q099_v1"

if (
  !exists("QPH_CORE_VERSION", inherits = TRUE) ||
    !identical(
      as.character(QPH_CORE_VERSION),
      expected_qph_core_version
    )
) {
  stop(
    "The sourced QPH core is not the expected version ",
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
# Required packages
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
    "Install the following required package(s) before running Script 06: ",
    paste(
      missing_packages,
      collapse = ", "
    )
  )
}

library(hypervolume)
library(e1071)


# ============================================================
# Locked baseline settings
# ============================================================

master_seed <- 812301L

sample_sizes <- c(
  300L,
  900L,
  1500L
)

maximum_sample_size <- max(
  sample_sizes
)

expected_shape_names <- c(
  "solid_ball",
  "solid_torus",
  "hollow_shell"
)

shape_labels <- c(
  solid_ball = "Solid ball",
  solid_torus = "Solid torus",
  hollow_shell = "Hollow spherical region"
)

# Kept separately from display order because method_index is part of the
# original deterministic sampling-seed formula.
seed_method_order <- c(
  "QPH",
  "Gaussian KDE",
  "SVM"
)

# Revised QPH baseline.
qph_q <- 0.99
qph_samples_per_point <- 100L
qph_sd_count <- 3
qph_sampling_chunk_size <- 100L
qph_potential_batch_size <- 500L

# Gaussian KDE baseline.
kde_bandwidth_method <- "silverman"
kde_probability_quantile <- 0.95
kde_samples_per_point <- 100L
kde_sd_count <- 3
kde_chunk_size <- 100L

# SVM baseline.
svm_nu <- 0.01
svm_gamma <- 0.50
svm_scale_factor <- 1
svm_samples_per_point <- 100L
svm_chunk_size <- 100L

# Restart behaviour.
resume_from_checkpoint <- TRUE
retry_failed_fits <- TRUE
show_progress_messages <- TRUE

# Previous codebase package version recorded for audit only.
expected_hypervolume_version <- "3.1.6"

# Locked colours for all later figures.
method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)

true_region_colour <- "#D9D9D9"
occurrence_colour <- "#111111"


# ============================================================
# Locked analytical definitions used to validate the archive
# ============================================================

expected_shape_definitions <- list(
  solid_ball = list(
    true_volume = 4 / 3 * pi * 5^3,
    expected_beta = c(
      H0 = 1L,
      H1 = 0L,
      H2 = 0L
    ),
    parameters = list(
      radius = 5
    )
  ),
  solid_torus = list(
    true_volume = 2 * pi^2 * 4 * 1.5^2,
    expected_beta = c(
      H0 = 1L,
      H1 = 1L,
      H2 = 0L
    ),
    parameters = list(
      major_radius = 4,
      minor_radius = 1.5
    )
  ),
  hollow_shell = list(
    true_volume = 4 / 3 * pi * (
      5^3 -
        2.5^3
    ),
    expected_beta = c(
      H0 = 1L,
      H1 = 0L,
      H2 = 1L
    ),
    parameters = list(
      inner_radius = 2.5,
      outer_radius = 5
    )
  )
)


# ============================================================
# Locked occurrence archive
# ============================================================
#
# This archive is independent of QPH and is reused exactly.
# ============================================================

legacy_occurrence_archive_file <- paste0(
  "C:/Users/r02jt24/Desktop/Quantum Paper/",
  "Sythetic Results/qph_3d_topology_extension/",
  "synthetic_3d_occurrence_clouds_authoritative.rds"
)

occurrence_archive_file <- file.path(
  locked_input_directory,
  "synthetic_3d_occurrence_clouds_authoritative.rds"
)

occurrence_manifest_file <- file.path(
  occurrence_directory,
  "occurrence_cloud_manifest_3D.csv"
)

occurrence_summary_file <- file.path(
  locked_input_directory,
  "synthetic_3d_occurrence_summary.csv"
)

locked_input_source_file <- file.path(
  locked_input_directory,
  "LOCKED_INPUT_SOURCE_3D.txt"
)

if (!file.exists(
  occurrence_archive_file
)) {

  if (!file.exists(
    legacy_occurrence_archive_file
  )) {
    stop(
      "The authoritative 3D occurrence archive was not found.\n\n",
      "Expected revised location:\n  ",
      occurrence_archive_file,
      "\n\nExpected legacy location:\n  ",
      legacy_occurrence_archive_file,
      "\n\nThe 3D occurrence clouds are deliberately NOT regenerated by this ",
      "script. Restore the original authoritative archive and rerun."
    )
  }

  copied_successfully <- file.copy(
    from = legacy_occurrence_archive_file,
    to = occurrence_archive_file,
    overwrite = FALSE,
    copy.mode = TRUE,
    copy.date = TRUE
  )

  if (!isTRUE(
    copied_successfully
  )) {
    stop(
      "Failed to copy the legacy authoritative 3D occurrence archive into ",
      "the Final Quantum locked-input directory."
    )
  }

  message(
    "Copied the legacy authoritative 3D occurrence archive byte-for-byte:\n  ",
    occurrence_archive_file
  )
}


# ============================================================
# General helpers
# ============================================================

safe_md5 <- function(path) {

  if (!file.exists(
    path
  )) {
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


hash_r_object <- function(object) {

  temporary_file <- tempfile(
    pattern = "3d_baseline_hash_",
    fileext = ".rds"
  )

  on.exit(
    unlink(
      temporary_file
    ),
    add = TRUE
  )

  saveRDS(
    object,
    temporary_file,
    version = 3
  )

  safe_md5(
    temporary_file
  )
}


safe_axis_value <- function(
    x,
    index
) {

  if (length(x) < index) {
    return(
      NA_real_
    )
  }

  as.numeric(
    x[
      index
    ]
  )
}


set_3d_axis_names <- function(x) {

  x <- validate_numeric_matrix(
    x,
    "x"
  )

  if (ncol(x) != 3L) {
    stop(
      "The 3D synthetic benchmark requires exactly three coordinate columns."
    )
  }

  colnames(x) <- c(
    "X1",
    "X2",
    "X3"
  )

  x
}


standardise_3d_hypervolume_axis_names <- function(hv) {

  if (!methods::is(
    hv,
    "Hypervolume"
  )) {
    stop(
      "Expected a Hypervolume object."
    )
  }

  if (!identical(
    as.integer(
      hv@Dimensionality
    ),
    3L
  )) {
    stop(
      "Expected a three-dimensional Hypervolume object."
    )
  }

  axis_names <- c(
    "X1",
    "X2",
    "X3"
  )

  if (ncol(
    hv@Data
  ) == 3L) {
    colnames(
      hv@Data
    ) <- axis_names
  }

  if (ncol(
    hv@RandomPoints
  ) == 3L) {
    colnames(
      hv@RandomPoints
    ) <- axis_names
  }

  methods::validObject(
    hv
  )

  hv
}


prediction_to_inside <- function(prediction) {

  if (is.logical(
    prediction
  )) {
    return(
      prediction
    )
  }

  prediction_character <- tolower(
    trimws(
      as.character(
        prediction
      )
    )
  )

  prediction_character %in% c(
    "true",
    "1",
    "inside",
    "yes"
  )
}


extract_scale_component <- function(
    svm_model,
    component_name,
    dimensionality,
    axis_names
) {

  output <- rep(
    NA_real_,
    dimensionality
  )

  names(
    output
  ) <- axis_names

  if (is.null(
    svm_model$x.scale
  )) {
    return(
      output
    )
  }

  component <- svm_model$x.scale[[
    component_name
  ]]

  if (is.null(
    component
  )) {
    return(
      output
    )
  }

  component <- as.numeric(
    component
  )

  number_to_copy <- min(
    length(
      component
    ),
    dimensionality
  )

  output[
    seq_len(
      number_to_copy
    )
  ] <- component[
    seq_len(
      number_to_copy
    )
  ]

  output
}


method_key_from_label <- function(method_label) {

  switch(
    method_label,
    "QPH" = "qph",
    "Gaussian KDE" = "gaussian_kde",
    "SVM" = "svm",
    stop(
      "Unknown method label: ",
      method_label
    )
  )
}


sampling_seed_for <- function(
    shape_name,
    sample_size,
    method_label
) {

  shape_index <- match(
    shape_name,
    expected_shape_names
  )

  method_index <- match(
    method_label,
    seed_method_order
  )

  if (
    is.na(
      shape_index
    ) ||
      is.na(
        method_index
      )
  ) {
    stop(
      "Could not determine the locked sampling seed for ",
      shape_name,
      " / ",
      method_label,
      "."
    )
  }

  as.integer(
    master_seed +
      shape_index * 100000L +
      as.integer(
        sample_size
      ) * 10L +
      method_index
  )
}


# ============================================================
# Validate authoritative occurrence archive
# ============================================================

validate_occurrence_archive <- function(archive) {

  if (!is.list(
    archive
  )) {
    stop(
      "The occurrence archive is not a list."
    )
  }

  required_names <- c(
    "metadata",
    "master_datasets",
    "occurrence_subsets"
  )

  if (!all(
    required_names %in%
      names(
        archive
      )
  )) {
    stop(
      "The occurrence archive is missing one or more required elements: ",
      paste(
        required_names,
        collapse = ", "
      ),
      "."
    )
  }

  if (!identical(
    names(
      archive$master_datasets
    ),
    expected_shape_names
  )) {
    stop(
      "The archived shape names/order do not match the locked 3D benchmark."
    )
  }

  if (!identical(
    names(
      archive$occurrence_subsets
    ),
    expected_shape_names
  )) {
    stop(
      "The archived occurrence-subset shape names/order do not match the ",
      "locked 3D benchmark."
    )
  }

  if (
    is.null(
      archive$metadata$master_seed
    ) ||
      !identical(
        as.integer(
          archive$metadata$master_seed
        ),
        master_seed
      )
  ) {
    stop(
      "The occurrence archive master seed is not 812301."
    )
  }

  if (!identical(
    as.integer(
      archive$metadata$sample_sizes
    ),
    sample_sizes
  )) {
    stop(
      "The occurrence archive sample sizes do not match c(300, 900, 1500)."
    )
  }

  if (
    is.null(
      archive$metadata$dimensionality
    ) ||
      !identical(
        as.integer(
          archive$metadata$dimensionality
        ),
        3L
      )
  ) {
    stop(
      "The occurrence archive is not recorded as three-dimensional."
    )
  }

  for (
    shape_index in seq_along(
      expected_shape_names
    )
  ) {

    shape_name <- expected_shape_names[[
      shape_index
    ]]

    master_object <- archive$master_datasets[[
      shape_name
    ]]

    definition <- expected_shape_definitions[[
      shape_name
    ]]

    if (is.null(
      master_object
    )) {
      stop(
        "Occurrence archive is missing master cloud for ",
        shape_name,
        "."
      )
    }

    master_points <- set_3d_axis_names(
      master_object$points
    )

    if (!identical(
      nrow(
        master_points
      ),
      maximum_sample_size
    )) {
      stop(
        "Master occurrence cloud for ",
        shape_name,
        " does not contain ",
        maximum_sample_size,
        " points."
      )
    }

    expected_generation_seed <- as.integer(
      master_seed +
        shape_index * 10000L
    )

    if (!identical(
      as.integer(
        master_object$generation_seed
      ),
      expected_generation_seed
    )) {
      stop(
        "Unexpected generation seed for ",
        shape_name,
        "."
      )
    }

    if (!isTRUE(all.equal(
      as.numeric(
        master_object$true_volume
      ),
      as.numeric(
        definition$true_volume
      ),
      tolerance = 1e-12
    ))) {
      stop(
        "True-volume mismatch for ",
        shape_name,
        "."
      )
    }

    if (!identical(
      as.integer(
        master_object$expected_beta
      ),
      as.integer(
        definition$expected_beta
      )
    )) {
      stop(
        "Expected Betti numbers do not match the locked definition for ",
        shape_name,
        "."
      )
    }

    archived_parameter_names <- names(
      master_object$parameters
    )

    expected_parameter_names <- names(
      definition$parameters
    )

    if (!identical(
      archived_parameter_names,
      expected_parameter_names
    )) {
      stop(
        "Parameter names do not match the locked analytical definition for ",
        shape_name,
        "."
      )
    }

    for (parameter_name in expected_parameter_names) {

      if (!isTRUE(all.equal(
        as.numeric(
          master_object$parameters[[
            parameter_name
          ]]
        ),
        as.numeric(
          definition$parameters[[
            parameter_name
          ]]
        ),
        tolerance = 1e-12
      ))) {
        stop(
          "Parameter ",
          parameter_name,
          " does not match the locked definition for ",
          shape_name,
          "."
        )
      }
    }

    shape_subsets <- archive$occurrence_subsets[[
      shape_name
    ]]

    if (is.null(
      shape_subsets
    )) {
      stop(
        "Occurrence archive is missing nested subsets for ",
        shape_name,
        "."
      )
    }

    for (current_sample_size in sample_sizes) {

      size_key <- as.character(
        current_sample_size
      )

      subset_object <- shape_subsets[[
        size_key
      ]]

      if (is.null(
        subset_object
      )) {
        stop(
          "Occurrence archive is missing ",
          shape_name,
          " at n = ",
          current_sample_size,
          "."
        )
      }

      expected_indices <- seq_len(
        current_sample_size
      )

      if (!identical(
        as.integer(
          subset_object$master_row_index
        ),
        as.integer(
          expected_indices
        )
      )) {
        stop(
          "Incorrect master-row indices for ",
          shape_name,
          " at n = ",
          current_sample_size,
          "."
        )
      }

      expected_points <- master_points[
        expected_indices,
        ,
        drop = FALSE
      ]

      archived_points <- set_3d_axis_names(
        subset_object$points
      )

      colnames(
        archived_points
      ) <- colnames(
        expected_points
      )

      if (!identical(
        archived_points,
        expected_points
      )) {
        stop(
          "The archived n = ",
          current_sample_size,
          " occurrence cloud is not the exact nested prefix of the master ",
          "cloud for ",
          shape_name,
          "."
        )
      }

      if (!isTRUE(all.equal(
        as.numeric(
          subset_object$true_volume
        ),
        as.numeric(
          definition$true_volume
        ),
        tolerance = 1e-12
      ))) {
        stop(
          "Nested occurrence subset has an incorrect true volume for ",
          shape_name,
          " at n = ",
          current_sample_size,
          "."
        )
      }
    }
  }

  invisible(
    TRUE
  )
}


# ============================================================
# Load and verify locked occurrence archive
# ============================================================

occurrence_archive <- readRDS(
  occurrence_archive_file
)

validate_occurrence_archive(
  occurrence_archive
)

occurrence_archive_md5 <- safe_md5(
  occurrence_archive_file
)

legacy_occurrence_archive_md5 <- safe_md5(
  legacy_occurrence_archive_file
)

if (
  file.exists(
    legacy_occurrence_archive_file
  ) &&
    !identical(
      occurrence_archive_md5,
      legacy_occurrence_archive_md5
    )
) {
  stop(
    "The revised locked 3D occurrence archive does not have the same MD5 ",
    "checksum as the legacy authoritative archive."
  )
}

writeLines(
  c(
    "Locked 3D synthetic occurrence input",
    "====================================",
    "",
    paste0(
      "Revised archive: ",
      occurrence_archive_file
    ),
    paste0(
      "Revised archive MD5: ",
      occurrence_archive_md5
    ),
    paste0(
      "Legacy archive: ",
      legacy_occurrence_archive_file
    ),
    paste0(
      "Legacy archive exists: ",
      file.exists(
        legacy_occurrence_archive_file
      )
    ),
    paste0(
      "Legacy archive MD5: ",
      legacy_occurrence_archive_md5
    ),
    "",
    "The archive is QPH-independent and is reused exactly.",
    "The revised baseline script does not regenerate occurrence points."
  ),
  locked_input_source_file
)


# ============================================================
# Save transparent occurrence-cloud copies and manifest
# ============================================================

occurrence_manifest_rows <- list()
occurrence_manifest_index <- 0L

occurrence_summary_rows <- list()
occurrence_summary_index <- 0L

for (shape_name in expected_shape_names) {

  master_object <- occurrence_archive$master_datasets[[
    shape_name
  ]]

  shape_directory <- file.path(
    occurrence_directory,
    shape_name
  )

  dir.create(
    shape_directory,
    recursive = TRUE,
    showWarnings = FALSE
  )

  # Save a transparent copy of the locked master cloud.
  master_rds_file <- file.path(
    shape_directory,
    paste0(
      shape_name,
      "_master_n",
      maximum_sample_size,
      ".rds"
    )
  )

  master_csv_file <- file.path(
    shape_directory,
    paste0(
      shape_name,
      "_master_n",
      maximum_sample_size,
      ".csv"
    )
  )

  master_copy <- master_object
  master_copy$points <- set_3d_axis_names(
    master_copy$points
  )

  saveRDS(
    master_copy,
    master_rds_file,
    version = 3
  )

  utils::write.csv(
    data.frame(
      Master_row_index = seq_len(
        maximum_sample_size
      ),
      master_copy$points,
      check.names = FALSE
    ),
    master_csv_file,
    row.names = FALSE
  )

  occurrence_manifest_index <- occurrence_manifest_index +
    1L

  occurrence_manifest_rows[[occurrence_manifest_index]] <- data.frame(
    Shape_code = shape_name,
    Shape = unname(
      shape_labels[[
        shape_name
      ]]
    ),
    Cloud_type = "master",
    Sample_size = maximum_sample_size,
    Generation_seed = master_object$generation_seed,
    True_volume = master_object$true_volume,
    Expected_beta0 = unname(
      master_object$expected_beta[[
        "H0"
      ]]
    ),
    Expected_beta1 = unname(
      master_object$expected_beta[[
        "H1"
      ]]
    ),
    Expected_beta2 = unname(
      master_object$expected_beta[[
        "H2"
      ]]
    ),
    RDS_file = normalizePath(
      master_rds_file,
      mustWork = FALSE
    ),
    RDS_MD5 = safe_md5(
      master_rds_file
    ),
    CSV_file = normalizePath(
      master_csv_file,
      mustWork = FALSE
    ),
    CSV_MD5 = safe_md5(
      master_csv_file
    ),
    stringsAsFactors = FALSE
  )

  shape_subsets <- occurrence_archive$occurrence_subsets[[
    shape_name
  ]]

  for (current_sample_size in sample_sizes) {

    size_key <- as.character(
      current_sample_size
    )

    subset_object <- shape_subsets[[
      size_key
    ]]

    subset_points <- set_3d_axis_names(
      subset_object$points
    )

    subset_rds_file <- file.path(
      shape_directory,
      paste0(
        shape_name,
        "_occurrence_n",
        current_sample_size,
        ".rds"
      )
    )

    subset_csv_file <- file.path(
      shape_directory,
      paste0(
        shape_name,
        "_occurrence_n",
        current_sample_size,
        ".csv"
      )
    )

    subset_copy <- subset_object
    subset_copy$points <- subset_points

    saveRDS(
      subset_copy,
      subset_rds_file,
      version = 3
    )

    utils::write.csv(
      data.frame(
        Master_row_index = subset_object$master_row_index,
        subset_points,
        check.names = FALSE
      ),
      subset_csv_file,
      row.names = FALSE
    )

    occurrence_manifest_index <- occurrence_manifest_index +
      1L

    occurrence_manifest_rows[[occurrence_manifest_index]] <- data.frame(
      Shape_code = shape_name,
      Shape = unname(
        shape_labels[[
          shape_name
        ]]
      ),
      Cloud_type = "nested occurrence subset",
      Sample_size = current_sample_size,
      Generation_seed = subset_object$generation_seed,
      True_volume = subset_object$true_volume,
      Expected_beta0 = unname(
        subset_object$expected_beta[[
          "H0"
        ]]
      ),
      Expected_beta1 = unname(
        subset_object$expected_beta[[
          "H1"
        ]]
      ),
      Expected_beta2 = unname(
        subset_object$expected_beta[[
          "H2"
        ]]
      ),
      RDS_file = normalizePath(
        subset_rds_file,
        mustWork = FALSE
      ),
      RDS_MD5 = safe_md5(
        subset_rds_file
      ),
      CSV_file = normalizePath(
        subset_csv_file,
        mustWork = FALSE
      ),
      CSV_MD5 = safe_md5(
        subset_csv_file
      ),
      stringsAsFactors = FALSE
    )

    occurrence_summary_index <- occurrence_summary_index +
      1L

    occurrence_summary_rows[[occurrence_summary_index]] <- data.frame(
      Shape_code = shape_name,
      Shape = unname(
        shape_labels[[
          shape_name
        ]]
      ),
      Sample_size = current_sample_size,
      True_volume = subset_object$true_volume,
      Expected_beta0 = unname(
        subset_object$expected_beta[[
          "H0"
        ]]
      ),
      Expected_beta1 = unname(
        subset_object$expected_beta[[
          "H1"
        ]]
      ),
      Expected_beta2 = unname(
        subset_object$expected_beta[[
          "H2"
        ]]
      ),
      Generation_seed = subset_object$generation_seed,
      Master_row_start = min(
        subset_object$master_row_index
      ),
      Master_row_end = max(
        subset_object$master_row_index
      ),
      stringsAsFactors = FALSE
    )
  }
}

occurrence_manifest <- do.call(
  rbind,
  occurrence_manifest_rows
)

rownames(
  occurrence_manifest
) <- NULL

utils::write.csv(
  occurrence_manifest,
  occurrence_manifest_file,
  row.names = FALSE
)

occurrence_summary <- do.call(
  rbind,
  occurrence_summary_rows
)

rownames(
  occurrence_summary
) <- NULL

utils::write.csv(
  occurrence_summary,
  occurrence_summary_file,
  row.names = FALSE
)


# ============================================================
# Package-version audit
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

if (!identical(
  installed_hypervolume_version,
  expected_hypervolume_version
)) {
  warning(
    "Installed hypervolume version is ",
    installed_hypervolume_version,
    "; previous manuscript code recorded ",
    expected_hypervolume_version,
    ". The installed version is recorded in the run metadata."
  )
}


# ============================================================
# Capture current package defaults for audit only
# ============================================================

svm_formals <- formals(
  hypervolume::hypervolume_svm
)

runtime_default_nu <- tryCatch(
  eval(
    svm_formals$svm.nu
  ),
  error = function(error_condition) {
    NA_real_
  }
)

runtime_default_gamma <- tryCatch(
  eval(
    svm_formals$svm.gamma
  ),
  error = function(error_condition) {
    NA_real_
  }
)

runtime_default_scale_factor <- tryCatch(
  eval(
    svm_formals$scale.factor
  ),
  error = function(error_condition) {
    NA_real_
  }
)


# ============================================================
# Output files
# ============================================================

checkpoint_file <- file.path(
  output_directory,
  "baseline_fit_checkpoint_3D_sqrtNB_q099.rds"
)

results_file <- file.path(
  output_directory,
  "baseline_fit_results_3D_sqrtNB_q099.rds"
)

summary_file <- file.path(
  output_directory,
  "baseline_fit_summary_3D_sqrtNB_q099.csv"
)

qph_audit_file <- file.path(
  output_directory,
  "QPH_bandwidth_audit_3D_sqrtNB_q099.csv"
)

qph_local_s_file <- file.path(
  output_directory,
  "QPH_local_s_audit_3D_sqrtNB_q099.csv"
)

kde_audit_file <- file.path(
  output_directory,
  "KDE_bandwidth_audit_3D.csv"
)

svm_audit_file <- file.path(
  output_directory,
  "SVM_parameter_audit_3D.csv"
)

svm_support_vector_file <- file.path(
  output_directory,
  "SVM_support_vector_indices_3D.csv"
)

failure_file <- file.path(
  output_directory,
  "baseline_fit_failures_3D_sqrtNB_q099.csv"
)

run_metadata_file <- file.path(
  output_directory,
  "baseline_run_metadata_3D_sqrtNB_q099.rds"
)

session_information_file <- file.path(
  output_directory,
  "baseline_session_information_3D_sqrtNB_q099.txt"
)

hypervolume_svm_definition_file <- file.path(
  output_directory,
  "hypervolume_svm_runtime_definition_3D.txt"
)

hypervolume_gaussian_definition_file <- file.path(
  output_directory,
  "hypervolume_gaussian_runtime_definition_3D.txt"
)


# ============================================================
# Safe analysis signature
# ============================================================

analysis_settings <- list(
  script_name = "06_3D_Synthetic_Baseline_Fits.R",
  project_directory = project_directory,
  occurrence_archive_md5 = occurrence_archive_md5,
  occurrence_archive_metadata = occurrence_archive$metadata,
  sample_sizes = sample_sizes,
  shape_names = expected_shape_names,
  master_seed = master_seed,
  qph_core_version = QPH_CORE_VERSION,
  qph_core_md5 = qph_core_md5,
  qph_bandwidth_method = QPH_BANDWIDTH_METHOD,
  qph_q = qph_q,
  qph_samples_per_point = qph_samples_per_point,
  qph_sd_count = qph_sd_count,
  qph_sampling_chunk_size = qph_sampling_chunk_size,
  qph_potential_batch_size = qph_potential_batch_size,
  kde_bandwidth_method = kde_bandwidth_method,
  kde_probability_quantile = kde_probability_quantile,
  kde_samples_per_point = kde_samples_per_point,
  kde_sd_count = kde_sd_count,
  kde_chunk_size = kde_chunk_size,
  svm_nu = svm_nu,
  svm_gamma = svm_gamma,
  svm_scale_factor = svm_scale_factor,
  svm_samples_per_point = svm_samples_per_point,
  svm_chunk_size = svm_chunk_size,
  seed_method_order = seed_method_order,
  hypervolume_version = installed_hypervolume_version,
  e1071_version = installed_e1071_version,
  method_colours = method_colours,
  true_region_colour = true_region_colour,
  occurrence_colour = occurrence_colour
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

run_metadata <- list(
  analysis_settings = analysis_settings,
  analysis_settings_hash = analysis_settings_hash,
  started_at = as.character(
    Sys.time()
  ),
  occurrence_archive = list(
    revised_path = occurrence_archive_file,
    revised_md5 = occurrence_archive_md5,
    legacy_path = legacy_occurrence_archive_file,
    legacy_exists = file.exists(
      legacy_occurrence_archive_file
    ),
    legacy_md5 = legacy_occurrence_archive_md5
  ),
  runtime_hypervolume_svm_defaults = list(
    svm_nu = runtime_default_nu,
    svm_gamma = runtime_default_gamma,
    scale_factor = runtime_default_scale_factor,
    samples_per_point_expression = deparse(
      svm_formals$samples.per.point
    ),
    chunk_size_expression = deparse(
      svm_formals$chunk.size
    )
  )
)

saveRDS(
  run_metadata,
  run_metadata_file,
  version = 3
)

writeLines(
  capture.output(
    print(
      hypervolume::hypervolume_svm
    )
  ),
  con = hypervolume_svm_definition_file
)

writeLines(
  capture.output(
    print(
      hypervolume::hypervolume_gaussian
    )
  ),
  con = hypervolume_gaussian_definition_file
)


# ============================================================
# Revised QPH baseline fit
# ============================================================

fit_qph_baseline <- function(
    occurrence_points,
    shape_name,
    shape_label,
    sample_size,
    sampling_seed,
    verbose
) {

  occurrence_points <- set_3d_axis_names(
    occurrence_points
  )

  fit_time <- system.time({

    qph_result <- construct_qph(
      data = occurrence_points,
      name = paste0(
        "QPH: ",
        shape_label,
        ", n = ",
        sample_size
      ),
      samples_per_point = qph_samples_per_point,
      sd_count = qph_sd_count,
      q = qph_q,
      sampling_seed = sampling_seed,
      sampling_chunk_size = qph_sampling_chunk_size,
      potential_batch_size = qph_potential_batch_size,
      verbose = verbose
    )
  })

  hv_qph <- standardise_3d_hypervolume_axis_names(
    qph_result$hypervolume
  )

  qph_result$hypervolume <- hv_qph

  audit <- qph_result$audit

  expected_k <- as.integer(
    round(
      sqrt(
        sample_size
      )
    )
  )

  if (!identical(
    as.integer(
      audit$K
    ),
    expected_k
  )) {
    stop(
      "QPH audit K does not equal round(sqrt(n)) for ",
      shape_name,
      " at n = ",
      sample_size,
      "."
    )
  }

  if (!isTRUE(all.equal(
    as.numeric(
      audit$baseline_scalar_h
    ),
    sqrt(
      mean(
        audit$local_s
      )
    ),
    tolerance = 1e-12
  ))) {
    stop(
      "QPH audit h does not equal sqrt(mean(local_s)) for ",
      shape_name,
      " at n = ",
      sample_size,
      "."
    )
  }

  if (!isTRUE(
    audit$fitted_isotropic
  )) {
    stop(
      "The revised baseline QPH bandwidth is not isotropic."
    )
  }

  if (!isTRUE(all.equal(
    as.numeric(
      audit$fitted_bandwidth
    ),
    rep(
      audit$baseline_scalar_h,
      3L
    ),
    tolerance = 1e-12
  ))) {
    stop(
      "The revised baseline QPH bandwidth differs from the locked ",
      "sqrt-NB isotropic bandwidth."
    )
  }

  if (!isTRUE(all.equal(
    as.numeric(
      audit$q
    ),
    qph_q
  ))) {
    stop(
      "The revised baseline QPH fit does not use q = 0.99."
    )
  }

  list(
    success = TRUE,
    method = "QPH",
    hypervolume = hv_qph,
    audit = audit,
    audit_summary = qph_result$audit_summary,
    bandwidth_info = qph_result$bandwidth_info,
    occurrence_potential_raw = qph_result$occurrence_potential_raw,
    potential_threshold_raw = qph_result$potential_threshold_raw,
    potential_threshold_relative = qph_result$potential_threshold_relative,
    sampling_region_volume = qph_result$sampling_region_volume,
    retained_fraction = qph_result$retained_fraction,
    volume_standard_error_conditional = qph_result$qph_volume_se_conditional,
    runtime_seconds = unname(
      fit_time[[
        "elapsed"
      ]]
    ),
    sampling_seed = as.integer(
      sampling_seed
    ),
    error_message = NA_character_
  )
}


# ============================================================
# Gaussian KDE baseline fit
# ============================================================

fit_kde_baseline <- function(
    occurrence_points,
    shape_name,
    shape_label,
    sample_size,
    sampling_seed,
    verbose
) {

  occurrence_points <- set_3d_axis_names(
    occurrence_points
  )

  bandwidth_time <- system.time({

    kde_bandwidth <- hypervolume::estimate_bandwidth(
      data = occurrence_points,
      method = kde_bandwidth_method
    )
  })

  bandwidth_method_attribute <- attr(
    kde_bandwidth,
    "method"
  )

  set.seed(
    as.integer(
      sampling_seed
    )
  )

  fit_time <- system.time({

    hv_kde <- hypervolume::hypervolume_gaussian(
      data = occurrence_points,
      name = paste0(
        "Gaussian KDE: ",
        shape_label,
        ", n = ",
        sample_size
      ),
      kde.bandwidth = kde_bandwidth,
      samples.per.point = kde_samples_per_point,
      sd.count = kde_sd_count,
      quantile.requested = kde_probability_quantile,
      quantile.requested.type = "probability",
      chunk.size = kde_chunk_size,
      verbose = verbose
    )
  })

  hv_kde <- standardise_3d_hypervolume_axis_names(
    hv_kde
  )

  list(
    success = TRUE,
    method = "Gaussian KDE",
    hypervolume = hv_kde,
    bandwidth = as.numeric(
      kde_bandwidth
    ),
    bandwidth_names = names(
      kde_bandwidth
    ),
    bandwidth_method = if (
      is.null(
        bandwidth_method_attribute
      )
    ) {
      kde_bandwidth_method
    } else {
      as.character(
        bandwidth_method_attribute
      )
    },
    probability_quantile = kde_probability_quantile,
    bandwidth_runtime_seconds = unname(
      bandwidth_time[[
        "elapsed"
      ]]
    ),
    hypervolume_runtime_seconds = unname(
      fit_time[[
        "elapsed"
      ]]
    ),
    runtime_seconds = (
      unname(
        bandwidth_time[[
          "elapsed"
        ]]
      ) +
        unname(
          fit_time[[
            "elapsed"
          ]]
        )
    ),
    sampling_seed = as.integer(
      sampling_seed
    ),
    error_message = NA_character_
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

  occurrence_points <- set_3d_axis_names(
    occurrence_points
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
  )[1L]

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
      "The fitted SVM produced a non-positive derived squared sampling ",
      "distance."
    )
  }

  data_standard_deviation <- apply(
    occurrence_points,
    MARGIN = 2,
    FUN = stats::sd
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
    )
  )
}


# ============================================================
# SVM baseline fit
# ============================================================

fit_svm_baseline <- function(
    occurrence_points,
    shape_name,
    shape_label,
    sample_size,
    sampling_seed,
    verbose
) {

  occurrence_points <- set_3d_axis_names(
    occurrence_points
  )

  audit_model_time <- system.time({

    audit_svm_model <- fit_audit_svm_model(
      occurrence_points
    )
  })

  svm_audit <- calculate_svm_sampling_audit(
    occurrence_points = occurrence_points,
    svm_model = audit_svm_model
  )

  expected_random_points <- as.integer(
    svm_audit$number_of_support_vectors *
      svm_samples_per_point
  )

  set.seed(
    as.integer(
      sampling_seed
    )
  )

  hypervolume_time <- system.time({

    hv_svm <- hypervolume::hypervolume_svm(
      data = occurrence_points,
      name = paste0(
        "SVM: ",
        shape_label,
        ", n = ",
        sample_size
      ),
      samples.per.point = svm_samples_per_point,
      svm.nu = svm_nu,
      svm.gamma = svm_gamma,
      scale.factor = svm_scale_factor,
      chunk.size = svm_chunk_size,
      verbose = verbose
    )
  })

  hv_svm <- standardise_3d_hypervolume_axis_names(
    hv_svm
  )

  actual_random_points <- nrow(
    hv_svm@RandomPoints
  )

  if (!identical(
    as.integer(
      actual_random_points
    ),
    expected_random_points
  )) {
    warning(
      "SVM random-point count differs from support_vectors * ",
      "samples.per.point for ",
      shape_name,
      " at n = ",
      sample_size,
      ". Expected ",
      expected_random_points,
      "; observed ",
      actual_random_points,
      "."
    )
  }

  if (!isTRUE(all.equal(
    as.numeric(
      hv_svm@Parameters$svm.nu
    ),
    svm_nu
  ))) {
    stop(
      "The SVM Hypervolume object did not store the requested svm.nu."
    )
  }

  if (!isTRUE(all.equal(
    as.numeric(
      hv_svm@Parameters$svm.gamma
    ),
    svm_gamma
  ))) {
    stop(
      "The SVM Hypervolume object did not store the requested svm.gamma."
    )
  }

  if (!identical(
    as.integer(
      hv_svm@Parameters$samples.per.point
    ),
    as.integer(
      svm_samples_per_point
    )
  )) {
    stop(
      "The SVM Hypervolume object did not store samples.per.point = 100."
    )
  }

  list(
    success = TRUE,
    method = "SVM",
    hypervolume = hv_svm,
    audit_svm_model = audit_svm_model,
    audit = svm_audit,
    expected_random_points = expected_random_points,
    actual_random_points = actual_random_points,
    audit_model_runtime_seconds = unname(
      audit_model_time[[
        "elapsed"
      ]]
    ),
    hypervolume_runtime_seconds = unname(
      hypervolume_time[[
        "elapsed"
      ]]
    ),
    runtime_seconds = (
      unname(
        audit_model_time[[
          "elapsed"
        ]]
      ) +
        unname(
          hypervolume_time[[
            "elapsed"
          ]]
        )
    ),
    sampling_seed = as.integer(
      sampling_seed
    ),
    error_message = NA_character_
  )
}


# ============================================================
# Failure object
# ============================================================

make_fit_failure <- function(
    method,
    sampling_seed,
    error_message
) {

  list(
    success = FALSE,
    method = method,
    hypervolume = NULL,
    runtime_seconds = NA_real_,
    sampling_seed = as.integer(
      sampling_seed
    ),
    error_message = as.character(
      error_message
    )
  )
}


# ============================================================
# Initialise/resume checkpoint
# ============================================================

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
          "scenarios"
        ) %in%
          names(
            checkpoint_object
          )
      )
  ) {
    stop(
      "The existing baseline checkpoint is not a valid revised Script 06 ",
      "checkpoint."
    )
  }

  if (!identical(
    checkpoint_object$analysis_settings_hash,
    analysis_settings_hash
  )) {
    stop(
      "The existing 3D baseline checkpoint was produced with different ",
      "occurrence data, QPH core, estimator settings, seeds, or package ",
      "versions. Do not mix incompatible runs."
    )
  }

  scenario_results <- checkpoint_object$scenarios

  message(
    "Loaded compatible 3D baseline checkpoint containing ",
    length(
      scenario_results
    ),
    " scenario object(s)."
  )

} else {

  scenario_results <- list()
}


save_checkpoint <- function() {

  checkpoint_object <- list(
    analysis_settings_hash = analysis_settings_hash,
    analysis_settings = analysis_settings,
    scenarios = scenario_results,
    last_updated = as.character(
      Sys.time()
    )
  )

  saveRDS(
    checkpoint_object,
    checkpoint_file,
    version = 3
  )
}


# ============================================================
# Run all nine 3D baseline scenarios
# ============================================================

for (
  shape_index in seq_along(
    expected_shape_names
  )
) {

  shape_name <- expected_shape_names[[
    shape_index
  ]]

  shape_label <- unname(
    shape_labels[[
      shape_name
    ]]
  )

  master_object <- occurrence_archive$master_datasets[[
    shape_name
  ]]

  shape_subsets <- occurrence_archive$occurrence_subsets[[
    shape_name
  ]]

  for (current_sample_size in sample_sizes) {

    size_key <- as.character(
      current_sample_size
    )

    subset_object <- shape_subsets[[
      size_key
    ]]

    occurrence_points <- set_3d_axis_names(
      subset_object$points
    )

    expected_occurrence_points <- set_3d_axis_names(
      master_object$points[
        subset_object$master_row_index,
        ,
        drop = FALSE
      ]
    )

    if (!identical(
      occurrence_points,
      expected_occurrence_points
    )) {
      stop(
        "Occurrence-cloud integrity check failed immediately before model ",
        "fitting for ",
        shape_name,
        " at n = ",
        current_sample_size,
        "."
      )
    }

    scenario_name <- paste(
      shape_name,
      current_sample_size,
      sep = "_"
    )

    qph_seed <- sampling_seed_for(
      shape_name = shape_name,
      sample_size = current_sample_size,
      method_label = "QPH"
    )

    kde_seed <- sampling_seed_for(
      shape_name = shape_name,
      sample_size = current_sample_size,
      method_label = "Gaussian KDE"
    )

    svm_seed <- sampling_seed_for(
      shape_name = shape_name,
      sample_size = current_sample_size,
      method_label = "SVM"
    )

    if (is.null(
      scenario_results[[
        scenario_name
      ]]
    )) {

      scenario_results[[scenario_name]] <- list(
        scenario_name = scenario_name,
        shape_name = shape_name,
        shape_label = shape_label,
        sample_size = current_sample_size,
        dimensionality = 3L,
        true_volume = as.numeric(
          master_object$true_volume
        ),
        expected_beta = master_object$expected_beta,
        parameters = master_object$parameters,
        generation_seed = as.integer(
          master_object$generation_seed
        ),
        occurrence_master_row_index = as.integer(
          subset_object$master_row_index
        ),
        sampling_seeds = list(
          qph = qph_seed,
          gaussian_kde = kde_seed,
          svm = svm_seed
        ),
        qph = NULL,
        gaussian_kde = NULL,
        svm = NULL
      )
    }

    current_scenario <- scenario_results[[
      scenario_name
    ]]

    message(
      "\n============================================================"
    )

    message(
      "3D baseline scenario: ",
      shape_label,
      " | n = ",
      current_sample_size
    )

    message(
      "Seeds: QPH = ",
      qph_seed,
      "; KDE = ",
      kde_seed,
      "; SVM = ",
      svm_seed
    )

    message(
      "============================================================"
    )

    # --------------------------------------------------------
    # QPH
    # --------------------------------------------------------

    qph_needs_run <- (
      is.null(
        current_scenario$qph
      ) ||
        (
          retry_failed_fits &&
            !isTRUE(
              current_scenario$qph$success
            )
        )
    )

    if (qph_needs_run) {

      message(
        "Fitting revised QPH..."
      )

      qph_fit <- tryCatch(
        fit_qph_baseline(
          occurrence_points = occurrence_points,
          shape_name = shape_name,
          shape_label = shape_label,
          sample_size = current_sample_size,
          sampling_seed = qph_seed,
          verbose = show_progress_messages
        ),
        error = function(error_condition) {

          error_message <- conditionMessage(
            error_condition
          )

          message(
            "QPH fit failed:\n  ",
            error_message
          )

          make_fit_failure(
            method = "QPH",
            sampling_seed = qph_seed,
            error_message = error_message
          )
        }
      )

      current_scenario$qph <- qph_fit

      scenario_results[[scenario_name]] <- current_scenario

      saveRDS(
        current_scenario,
        file.path(
          scenario_directory,
          paste0(
            scenario_name,
            "_baseline_fits_3D.rds"
          )
        ),
        version = 3
      )

      save_checkpoint()

    } else {

      message(
        "Reusing completed revised QPH fit from checkpoint."
      )
    }

    # --------------------------------------------------------
    # Gaussian KDE
    # --------------------------------------------------------

    kde_needs_run <- (
      is.null(
        current_scenario$gaussian_kde
      ) ||
        (
          retry_failed_fits &&
            !isTRUE(
              current_scenario$gaussian_kde$success
            )
        )
    )

    if (kde_needs_run) {

      message(
        "Fitting Gaussian KDE with its own Silverman bandwidth..."
      )

      kde_fit <- tryCatch(
        fit_kde_baseline(
          occurrence_points = occurrence_points,
          shape_name = shape_name,
          shape_label = shape_label,
          sample_size = current_sample_size,
          sampling_seed = kde_seed,
          verbose = show_progress_messages
        ),
        error = function(error_condition) {

          error_message <- conditionMessage(
            error_condition
          )

          message(
            "Gaussian KDE fit failed:\n  ",
            error_message
          )

          make_fit_failure(
            method = "Gaussian KDE",
            sampling_seed = kde_seed,
            error_message = error_message
          )
        }
      )

      current_scenario$gaussian_kde <- kde_fit

      scenario_results[[scenario_name]] <- current_scenario

      saveRDS(
        current_scenario,
        file.path(
          scenario_directory,
          paste0(
            scenario_name,
            "_baseline_fits_3D.rds"
          )
        ),
        version = 3
      )

      save_checkpoint()

    } else {

      message(
        "Reusing completed Gaussian KDE fit from checkpoint."
      )
    }

    # --------------------------------------------------------
    # SVM
    # --------------------------------------------------------

    svm_needs_run <- (
      is.null(
        current_scenario$svm
      ) ||
        (
          retry_failed_fits &&
            !isTRUE(
              current_scenario$svm$success
            )
        )
    )

    if (svm_needs_run) {

      message(
        "Fitting one-class radial SVM..."
      )

      svm_fit <- tryCatch(
        fit_svm_baseline(
          occurrence_points = occurrence_points,
          shape_name = shape_name,
          shape_label = shape_label,
          sample_size = current_sample_size,
          sampling_seed = svm_seed,
          verbose = show_progress_messages
        ),
        error = function(error_condition) {

          error_message <- conditionMessage(
            error_condition
          )

          message(
            "SVM fit failed:\n  ",
            error_message
          )

          make_fit_failure(
            method = "SVM",
            sampling_seed = svm_seed,
            error_message = error_message
          )
        }
      )

      current_scenario$svm <- svm_fit

      scenario_results[[scenario_name]] <- current_scenario

      saveRDS(
        current_scenario,
        file.path(
          scenario_directory,
          paste0(
            scenario_name,
            "_baseline_fits_3D.rds"
          )
        ),
        version = 3
      )

      save_checkpoint()

    } else {

      message(
        "Reusing completed SVM fit from checkpoint."
      )
    }
  }
}


# ============================================================
# Build compact baseline summary
# ============================================================

summary_rows <- list()
summary_index <- 0L

add_summary_row <- function(
    scenario,
    method_key,
    method_label
) {

  method_result <- scenario[[
    method_key
  ]]

  summary_index <<- summary_index +
    1L

  success <- isTRUE(
    method_result$success
  )

  estimated_volume <- if (
    success
  ) {
    as.numeric(
      method_result$hypervolume@Volume
    )
  } else {
    NA_real_
  }

  signed_error <- (
    estimated_volume -
      scenario$true_volume
  )

  relative_error_percent <- (
    100 *
      signed_error /
      scenario$true_volume
  )

  random_points <- if (
    success
  ) {
    nrow(
      method_result$hypervolume@RandomPoints
    )
  } else {
    NA_integer_
  }

  point_density <- if (
    success
  ) {
    as.numeric(
      method_result$hypervolume@PointDensity
    )
  } else {
    NA_real_
  }

  qph_k <- NA_integer_
  qph_mean_s <- NA_real_
  qph_scalar_h <- NA_real_
  qph_q_value <- NA_real_

  bandwidth_axis_1 <- NA_real_
  bandwidth_axis_2 <- NA_real_
  bandwidth_axis_3 <- NA_real_
  bandwidth_method <- NA_character_

  kde_quantile_value <- NA_real_

  svm_nu_value <- NA_real_
  svm_gamma_value <- NA_real_
  svm_scale_factor_value <- NA_real_

  if (
    success &&
      identical(
        method_label,
        "QPH"
      )
  ) {

    qph_k <- as.integer(
      method_result$audit$K
    )

    qph_mean_s <- as.numeric(
      method_result$audit$mean_s
    )

    qph_scalar_h <- as.numeric(
      method_result$audit$baseline_scalar_h
    )

    qph_q_value <- as.numeric(
      method_result$audit$q
    )

    bandwidth_axis_1 <- safe_axis_value(
      method_result$audit$fitted_bandwidth,
      1L
    )

    bandwidth_axis_2 <- safe_axis_value(
      method_result$audit$fitted_bandwidth,
      2L
    )

    bandwidth_axis_3 <- safe_axis_value(
      method_result$audit$fitted_bandwidth,
      3L
    )

    bandwidth_method <- method_result$audit$bandwidth_method
  }

  if (
    success &&
      identical(
        method_label,
        "Gaussian KDE"
      )
  ) {

    bandwidth_axis_1 <- safe_axis_value(
      method_result$bandwidth,
      1L
    )

    bandwidth_axis_2 <- safe_axis_value(
      method_result$bandwidth,
      2L
    )

    bandwidth_axis_3 <- safe_axis_value(
      method_result$bandwidth,
      3L
    )

    bandwidth_method <- method_result$bandwidth_method
    kde_quantile_value <- method_result$probability_quantile
  }

  if (
    success &&
      identical(
        method_label,
        "SVM"
      )
  ) {

    svm_nu_value <- svm_nu
    svm_gamma_value <- svm_gamma
    svm_scale_factor_value <- svm_scale_factor
  }

  data.frame(
    Scenario = scenario$scenario_name,
    Shape_code = scenario$shape_name,
    Shape = scenario$shape_label,
    Dimensionality = scenario$dimensionality,
    Sample_size = scenario$sample_size,
    True_volume = scenario$true_volume,
    Expected_beta0 = unname(
      scenario$expected_beta[[
        "H0"
      ]]
    ),
    Expected_beta1 = unname(
      scenario$expected_beta[[
        "H1"
      ]]
    ),
    Expected_beta2 = unname(
      scenario$expected_beta[[
        "H2"
      ]]
    ),
    Method = method_label,
    Success = success,
    Estimated_volume = estimated_volume,
    Signed_volume_error = signed_error,
    Absolute_volume_error = abs(
      signed_error
    ),
    Relative_volume_error_percent = relative_error_percent,
    Absolute_relative_volume_error_percent = abs(
      relative_error_percent
    ),
    Random_points = random_points,
    Point_density = point_density,
    Runtime_seconds = if (
      success
    ) {
      as.numeric(
        method_result$runtime_seconds
      )
    } else {
      NA_real_
    },
    Sampling_seed = if (
      is.null(
        method_result$sampling_seed
      )
    ) {
      NA_integer_
    } else {
      as.integer(
        method_result$sampling_seed
      )
    },
    Bandwidth_method = bandwidth_method,
    Bandwidth_axis_1 = bandwidth_axis_1,
    Bandwidth_axis_2 = bandwidth_axis_2,
    Bandwidth_axis_3 = bandwidth_axis_3,
    QPH_K = qph_k,
    QPH_mean_s = qph_mean_s,
    QPH_scalar_h = qph_scalar_h,
    QPH_q = qph_q_value,
    KDE_probability_quantile = kde_quantile_value,
    SVM_nu = svm_nu_value,
    SVM_gamma = svm_gamma_value,
    SVM_scale_factor = svm_scale_factor_value,
    Error_message = if (
      success
    ) {
      NA_character_
    } else {
      method_result$error_message
    },
    stringsAsFactors = FALSE
  )
}


for (scenario_name in names(
  scenario_results
)) {

  scenario <- scenario_results[[
    scenario_name
  ]]

  summary_rows[[
    length(
      summary_rows
    ) +
      1L
  ]] <- add_summary_row(
    scenario,
    "qph",
    "QPH"
  )

  summary_rows[[
    length(
      summary_rows
    ) +
      1L
  ]] <- add_summary_row(
    scenario,
    "gaussian_kde",
    "Gaussian KDE"
  )

  summary_rows[[
    length(
      summary_rows
    ) +
      1L
  ]] <- add_summary_row(
    scenario,
    "svm",
    "SVM"
  )
}

baseline_summary <- do.call(
  rbind,
  summary_rows
)

rownames(
  baseline_summary
) <- NULL

baseline_summary$Shape_order <- match(
  baseline_summary$Shape_code,
  expected_shape_names
)

baseline_summary$Sample_order <- match(
  baseline_summary$Sample_size,
  sample_sizes
)

baseline_summary$Method_order <- match(
  baseline_summary$Method,
  seed_method_order
)

baseline_summary <- baseline_summary[
  order(
    baseline_summary$Shape_order,
    baseline_summary$Sample_order,
    baseline_summary$Method_order
  ),
  ,
  drop = FALSE
]

baseline_summary$Shape_order <- NULL
baseline_summary$Sample_order <- NULL
baseline_summary$Method_order <- NULL

utils::write.csv(
  baseline_summary,
  summary_file,
  row.names = FALSE
)


# ============================================================
# QPH audit outputs
# ============================================================

qph_audit_rows <- list()
qph_local_s_rows <- list()

for (scenario_name in names(
  scenario_results
)) {

  scenario <- scenario_results[[
    scenario_name
  ]]

  qph_result <- scenario$qph

  if (
    is.null(
      qph_result
    ) ||
      !isTRUE(
        qph_result$success
      )
  ) {
    next
  }

  audit <- qph_result$audit

  audit_summary <- qph_audit_summary(
    audit
  )

  audit_summary$Scenario <- scenario$scenario_name
  audit_summary$Shape_code <- scenario$shape_name
  audit_summary$Shape <- scenario$shape_label
  audit_summary$Sample_size <- scenario$sample_size
  audit_summary$True_volume <- scenario$true_volume

  audit_summary <- audit_summary[
    ,
    c(
      "Scenario",
      "Shape_code",
      "Shape",
      "Sample_size",
      "True_volume",
      setdiff(
        names(
          audit_summary
        ),
        c(
          "Scenario",
          "Shape_code",
          "Shape",
          "Sample_size",
          "True_volume"
        )
      )
    ),
    drop = FALSE
  ]

  qph_audit_rows[[
    length(
      qph_audit_rows
    ) +
      1L
  ]] <- audit_summary

  qph_local_s_rows[[
    length(
      qph_local_s_rows
    ) +
      1L
  ]] <- data.frame(
    Scenario = scenario$scenario_name,
    Shape_code = scenario$shape_name,
    Shape = scenario$shape_label,
    Sample_size = scenario$sample_size,
    Occurrence_index = seq_along(
      audit$local_s
    ),
    K = audit$K,
    s_i = as.numeric(
      audit$local_s
    ),
    Mean_s = audit$mean_s,
    Scalar_h = audit$baseline_scalar_h,
    Bandwidth_axis_1 = audit$fitted_bandwidth[
      1L
    ],
    Bandwidth_axis_2 = audit$fitted_bandwidth[
      2L
    ],
    Bandwidth_axis_3 = audit$fitted_bandwidth[
      3L
    ],
    q = audit$q,
    Samples_per_point = audit$samples_per_point,
    SD_count = audit$sd_count,
    Sampling_seed = audit$sampling_seed,
    stringsAsFactors = FALSE
  )
}

if (length(
  qph_audit_rows
) > 0L) {

  qph_audit_table <- do.call(
    rbind,
    qph_audit_rows
  )

  rownames(
    qph_audit_table
  ) <- NULL

  utils::write.csv(
    qph_audit_table,
    qph_audit_file,
    row.names = FALSE
  )
}

if (length(
  qph_local_s_rows
) > 0L) {

  qph_local_s_table <- do.call(
    rbind,
    qph_local_s_rows
  )

  rownames(
    qph_local_s_table
  ) <- NULL

  utils::write.csv(
    qph_local_s_table,
    qph_local_s_file,
    row.names = FALSE
  )
}


# ============================================================
# KDE bandwidth audit
# ============================================================

kde_audit_rows <- list()

for (scenario_name in names(
  scenario_results
)) {

  scenario <- scenario_results[[
    scenario_name
  ]]

  kde_result <- scenario$gaussian_kde

  if (
    is.null(
      kde_result
    ) ||
      !isTRUE(
        kde_result$success
      )
  ) {
    next
  }

  kde_audit_rows[[
    length(
      kde_audit_rows
    ) +
      1L
  ]] <- data.frame(
    Scenario = scenario$scenario_name,
    Shape_code = scenario$shape_name,
    Shape = scenario$shape_label,
    Sample_size = scenario$sample_size,
    Bandwidth_method = kde_result$bandwidth_method,
    Bandwidth_axis_1 = safe_axis_value(
      kde_result$bandwidth,
      1L
    ),
    Bandwidth_axis_2 = safe_axis_value(
      kde_result$bandwidth,
      2L
    ),
    Bandwidth_axis_3 = safe_axis_value(
      kde_result$bandwidth,
      3L
    ),
    Probability_quantile = kde_result$probability_quantile,
    Samples_per_point = kde_samples_per_point,
    SD_count = kde_sd_count,
    Sampling_seed = kde_result$sampling_seed,
    Runtime_seconds = kde_result$runtime_seconds,
    stringsAsFactors = FALSE
  )
}

if (length(
  kde_audit_rows
) > 0L) {

  kde_audit_table <- do.call(
    rbind,
    kde_audit_rows
  )

  rownames(
    kde_audit_table
  ) <- NULL

  utils::write.csv(
    kde_audit_table,
    kde_audit_file,
    row.names = FALSE
  )
}


# ============================================================
# SVM parameter audit
# ============================================================

svm_audit_rows <- list()
svm_support_vector_rows <- list()

for (scenario_name in names(
  scenario_results
)) {

  scenario <- scenario_results[[
    scenario_name
  ]]

  svm_result <- scenario$svm

  if (
    is.null(
      svm_result
    ) ||
      !isTRUE(
        svm_result$success
      )
  ) {
    next
  }

  audit <- svm_result$audit

  svm_audit_rows[[
    length(
      svm_audit_rows
    ) +
      1L
  ]] <- data.frame(
    Scenario = scenario$scenario_name,
    Shape_code = scenario$shape_name,
    Shape = scenario$shape_label,
    Sample_size = scenario$sample_size,
    SVM_nu = svm_nu,
    SVM_gamma = svm_gamma,
    Scale_factor = svm_scale_factor,
    Samples_per_point = svm_samples_per_point,
    Number_support_vectors = audit$number_of_support_vectors,
    Support_vector_fraction = audit$support_vector_fraction,
    Coefficient_sum = audit$coefficient_sum,
    Rho = audit$rho,
    Coefficient_to_rho_ratio = audit$coefficient_to_rho_ratio,
    Squared_scaled_distance = audit$squared_scaled_distance,
    Data_SD_axis_1 = safe_axis_value(
      audit$data_standard_deviation,
      1L
    ),
    Data_SD_axis_2 = safe_axis_value(
      audit$data_standard_deviation,
      2L
    ),
    Data_SD_axis_3 = safe_axis_value(
      audit$data_standard_deviation,
      3L
    ),
    Sampling_scale_axis_1 = safe_axis_value(
      audit$sampling_scales,
      1L
    ),
    Sampling_scale_axis_2 = safe_axis_value(
      audit$sampling_scales,
      2L
    ),
    Sampling_scale_axis_3 = safe_axis_value(
      audit$sampling_scales,
      3L
    ),
    Number_training_errors = audit$number_of_training_errors,
    Training_error_fraction = audit$training_error_fraction,
    Expected_random_points = svm_result$expected_random_points,
    Actual_random_points = svm_result$actual_random_points,
    Sampling_seed = svm_result$sampling_seed,
    Runtime_seconds = svm_result$runtime_seconds,
    stringsAsFactors = FALSE
  )

  support_indices <- audit$support_vector_indices

  svm_support_vector_rows[[
    length(
      svm_support_vector_rows
    ) +
      1L
  ]] <- data.frame(
    Scenario = scenario$scenario_name,
    Shape_code = scenario$shape_name,
    Shape = scenario$shape_label,
    Sample_size = scenario$sample_size,
    Support_vector_number = seq_along(
      support_indices
    ),
    Occurrence_row_index = support_indices,
    stringsAsFactors = FALSE
  )
}

if (length(
  svm_audit_rows
) > 0L) {

  svm_audit_table <- do.call(
    rbind,
    svm_audit_rows
  )

  rownames(
    svm_audit_table
  ) <- NULL

  utils::write.csv(
    svm_audit_table,
    svm_audit_file,
    row.names = FALSE
  )
}

if (length(
  svm_support_vector_rows
) > 0L) {

  svm_support_vector_table <- do.call(
    rbind,
    svm_support_vector_rows
  )

  rownames(
    svm_support_vector_table
  ) <- NULL

  utils::write.csv(
    svm_support_vector_table,
    svm_support_vector_file,
    row.names = FALSE
  )
}


# ============================================================
# Failure audit
# ============================================================

failure_rows <- list()

for (scenario_name in names(
  scenario_results
)) {

  scenario <- scenario_results[[
    scenario_name
  ]]

  for (method_key in c(
    "qph",
    "gaussian_kde",
    "svm"
  )) {

    method_result <- scenario[[
      method_key
    ]]

    if (
      is.null(
        method_result
      ) ||
        isTRUE(
          method_result$success
        )
    ) {
      next
    }

    failure_rows[[
      length(
        failure_rows
      ) +
        1L
    ]] <- data.frame(
      Scenario = scenario$scenario_name,
      Shape_code = scenario$shape_name,
      Shape = scenario$shape_label,
      Sample_size = scenario$sample_size,
      Method = method_result$method,
      Sampling_seed = method_result$sampling_seed,
      Error_message = method_result$error_message,
      stringsAsFactors = FALSE
    )
  }
}

if (length(
  failure_rows
) > 0L) {

  failure_table <- do.call(
    rbind,
    failure_rows
  )

} else {

  failure_table <- data.frame(
    Scenario = character(0),
    Shape_code = character(0),
    Shape = character(0),
    Sample_size = integer(0),
    Method = character(0),
    Sampling_seed = integer(0),
    Error_message = character(0),
    stringsAsFactors = FALSE
  )
}

utils::write.csv(
  failure_table,
  failure_file,
  row.names = FALSE
)


# ============================================================
# Save final authoritative baseline object
# ============================================================

expected_scenario_names <- as.vector(
  outer(
    expected_shape_names,
    sample_sizes,
    FUN = function(
        shape_name,
        sample_size
    ) {
      paste(
        shape_name,
        sample_size,
        sep = "_"
      )
    }
  )
)

if (!all(
  expected_scenario_names %in%
    names(
      scenario_results
    )
)) {
  stop(
    "Final revised 3D baseline object is missing one or more expected ",
    "shape x sample-size scenarios."
  )
}

final_results <- list(
  metadata = list(
    script = "06_3D_Synthetic_Baseline_Fits.R",
    qph_core_version = QPH_CORE_VERSION,
    qph_core_md5 = qph_core_md5,
    analysis_settings_hash = analysis_settings_hash,
    occurrence_archive_file = occurrence_archive_file,
    occurrence_archive_md5 = occurrence_archive_md5,
    legacy_occurrence_archive_file = legacy_occurrence_archive_file,
    legacy_occurrence_archive_md5 = legacy_occurrence_archive_md5,
    sample_sizes = sample_sizes,
    shape_order = expected_shape_names,
    dimensionality = 3L,
    master_seed = master_seed,
    qph_q = qph_q,
    qph_bandwidth_method = QPH_BANDWIDTH_METHOD,
    kde_probability_quantile = kde_probability_quantile,
    kde_bandwidth_method = kde_bandwidth_method,
    svm_nu = svm_nu,
    svm_gamma = svm_gamma,
    svm_scale_factor = svm_scale_factor,
    method_colours = method_colours,
    true_region_colour = true_region_colour,
    occurrence_colour = occurrence_colour,
    completed_at = as.character(
      Sys.time()
    )
  ),
  occurrence_archive = occurrence_archive,
  scenarios = scenario_results,
  baseline_summary = baseline_summary
)

saveRDS(
  final_results,
  results_file,
  version = 3
)


# ============================================================
# Update run metadata and save session information
# ============================================================

run_metadata$completed_at <- as.character(
  Sys.time()
)

run_metadata$results_file <- results_file
run_metadata$results_file_md5 <- safe_md5(
  results_file
)

run_metadata$counts <- list(
  expected_scenarios = length(
    expected_scenario_names
  ),
  expected_model_fits = length(
    expected_scenario_names
  ) * 3L,
  successful_model_fits = sum(
    baseline_summary$Success
  ),
  failed_model_fits = sum(
    !baseline_summary$Success
  )
)

saveRDS(
  run_metadata,
  run_metadata_file,
  version = 3
)

capture.output(
  sessionInfo(),
  file = session_information_file
)


# ============================================================
# Final console audit
# ============================================================

message(
  "\n============================================================"
)

message(
  "06_3D_Synthetic_Baseline_Fits.R complete."
)

message(
  "============================================================"
)

message(
  "Locked occurrence archive:\n  ",
  normalizePath(
    occurrence_archive_file,
    mustWork = FALSE
  )
)

message(
  "Authoritative baseline results:\n  ",
  normalizePath(
    results_file,
    mustWork = FALSE
  )
)

message(
  "Baseline summary:\n  ",
  normalizePath(
    summary_file,
    mustWork = FALSE
  )
)

message(
  "QPH bandwidth audit:\n  ",
  normalizePath(
    qph_audit_file,
    mustWork = FALSE
  )
)

message(
  "QPH local-s audit:\n  ",
  normalizePath(
    qph_local_s_file,
    mustWork = FALSE
  )
)

message(
  "Successful model fits: ",
  sum(
    baseline_summary$Success
  ),
  " / ",
  nrow(
    baseline_summary
  )
)

if (nrow(
  failure_table
) > 0L) {

  message(
    "WARNING: ",
    nrow(
      failure_table
    ),
    " baseline fit(s) failed. See:\n  ",
    normalizePath(
      failure_file,
      mustWork = FALSE
    )
  )

} else {

  message(
    "No baseline fitting failures were recorded."
  )
}

message(
  "============================================================"
)
