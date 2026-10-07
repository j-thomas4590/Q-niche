# ============================================================
# 01_2D_Synthetic_Baseline_Fits.R
# ============================================================
#
# Clean final baseline rerun for the five two-dimensional synthetic
# benchmark niches used in the QPH manuscript.
#
# This script:
#   1. Sources the authoritative revised QPH implementation from
#      00_QPH_Core_Functions.R.
#   2. Imports the locked occurrence-cloud archive from the previous
#      analysis 
#   3. Fits all three baseline estimators to the same nested occurrence
#      clouds at n = 300, 900, and 1500:
#
#        QPH:
#          - revised Nasios-Bors-derived square-root local-distance bandwidth
#          - K = round(sqrt(n))
#          - h = sqrt(mean(s_i))
#          - isotropic bandwidth vector (h, ..., h)
#          - q = 0.99
#          - samples.per.point = 100
#          - sd.count = 3
#
#        Gaussian KDE:
#          - Silverman bandwidth estimated independently from the same
#            occurrence cloud
#          - probability quantile = 0.95
#          - samples.per.point = 100
#          - sd.count = 3
#
#        One-class radial SVM:
#          - svm.nu = 0.01
#          - svm.gamma = 0.5
#          - scale.factor = 1
#          - samples.per.point = 100 passed directly to hypervolume_svm()



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
  "2D_Synthetic_sqrtNB_q099"
)

locked_input_directory <- file.path(
  analysis_root_directory,
  "00_Locked_Inputs"
)

output_directory <- file.path(
  analysis_root_directory,
  "01_Baseline_Fits"
)

scenario_directory <- file.path(
  output_directory,
  "scenario_objects"
)

for (current_directory in c(
  scripts_directory,
  analysis_root_directory,
  locked_input_directory,
  output_directory,
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
    qph_core_file,
    "\nSave 00_QPH_Core_Functions.R in the Scripts directory before ",
    "running this script."
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
  tools::md5sum(qph_core_file)
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
    "Install the following required package(s) before running Script 01: ",
    paste(missing_packages, collapse = ", ")
  )
}

library(hypervolume)
library(e1071)


# ============================================================
# Locked analysis settings
# ============================================================

sample_sizes <- c(
  300L,
  900L,
  1500L
)

expected_shape_names <- c(
  "spiral",
  "ellipse",
  "annulus",
  "banana",
  "two_balls"
)

# Labels used in new result tables. These labels do not alter any
# occurrence coordinates or analytical truth stored in the archive.
shape_labels <- c(
  spiral = "Spiral band",
  ellipse = "Filled ellipse",
  annulus = "Annulus",
  banana = "Concave banana",
  two_balls = "Two separated disks"
)

# Preserve the original seed structure.
master_seed <- 123L

# Revised QPH baseline.
qph_samples_per_point <- 100L
qph_sd_count <- 3
qph_q <- 0.99
qph_sampling_chunk_size <- 100L
qph_potential_batch_size <- 500L

# Gaussian KDE comparator: intentionally NOT changed to the QPH bandwidth.
kde_bandwidth_method <- "silverman"
kde_samples_per_point <- 100L
kde_sd_count <- 3
kde_probability_quantile <- 0.95
kde_chunk_size <- 100L

# Package-consistent one-class radial SVM comparator.
svm_samples_per_point <- 100L
svm_nu <- 0.01
svm_gamma <- 0.50
svm_scale_factor <- 1
svm_chunk_size <- 100L

# Restart behaviour.
resume_from_checkpoint <- TRUE
retry_failed_fits <- TRUE

# Package progress messages.
show_progress_messages <- TRUE

# Record expected package version used in the manuscript codebase.
# A mismatch is warned about and recorded rather than silently ignored.
expected_hypervolume_version <- "3.1.6"


# ============================================================
# Locked occurrence archive
# ============================================================
#
# The baseline synthetic occurrence clouds are independent of the revised
# QPH definition and must be reused exactly.
#
# On the first run in "Final Quantum", the legacy authoritative archive is
# copied byte-for-byte into the new locked-input directory. Subsequent runs
# use only the copied archive.
#
# If neither copy exists, this script STOPS rather than silently drawing a
# new occurrence realisation.
# ============================================================

legacy_occurrence_archive_file <- paste0(
  "C:/Users/r02jt24/Desktop/Quantum Paper/",
  "Sythetic Results/qph_shape_size_benchmark_five_shapes/",
  "synthetic_occurrence_clouds_authoritative.rds"
)

occurrence_archive_file <- file.path(
  locked_input_directory,
  "synthetic_occurrence_clouds_authoritative.rds"
)

occurrence_directory <- file.path(
  locked_input_directory,
  "synthetic_occurrence_clouds"
)

occurrence_manifest_file <- file.path(
  occurrence_directory,
  "occurrence_cloud_manifest.csv"
)

occurrence_readme_file <- file.path(
  occurrence_directory,
  "README.txt"
)

locked_input_source_file <- file.path(
  locked_input_directory,
  "LOCKED_INPUT_SOURCE.txt"
)

if (!file.exists(occurrence_archive_file)) {

  if (!file.exists(legacy_occurrence_archive_file)) {
    stop(
      "The locked occurrence archive was not found in either location.\n\n",
      "Expected new location:\n  ",
      occurrence_archive_file,
      "\n\nExpected legacy location:\n  ",
      legacy_occurrence_archive_file,
      "\n\nThe baseline occurrence clouds are intentionally NOT regenerated by ",
      "this script. Restore the original authoritative archive and rerun."
    )
  }

  copied_successfully <- file.copy(
    from = legacy_occurrence_archive_file,
    to = occurrence_archive_file,
    overwrite = FALSE,
    copy.mode = TRUE,
    copy.date = TRUE
  )

  if (!isTRUE(copied_successfully)) {
    stop(
      "Failed to copy the legacy occurrence archive into the new ",
      "Final Quantum locked-input directory."
    )
  }

  message(
    "Copied the legacy authoritative occurrence archive byte-for-byte to:\n  ",
    occurrence_archive_file
  )
}


# ============================================================
# General helpers
# ============================================================

hash_r_object <- function(object) {

  temporary_file <- tempfile(
    pattern = "object_hash_",
    fileext = ".rds"
  )

  on.exit(
    unlink(temporary_file),
    add = TRUE
  )

  saveRDS(
    object,
    file = temporary_file,
    version = 3
  )

  unname(
    tools::md5sum(temporary_file)
  )
}


safe_axis_value <- function(
    x,
    index
) {
  if (length(x) < index) {
    return(NA_real_)
  }

  as.numeric(x[index])
}


prediction_to_inside <- function(prediction) {

  if (is.logical(prediction)) {
    return(prediction)
  }

  prediction_character <- tolower(
    trimws(
      as.character(prediction)
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

  names(output) <- axis_names

  if (is.null(svm_model$x.scale)) {
    return(output)
  }

  component <- svm_model$x.scale[[component_name]]

  if (is.null(component)) {
    return(output)
  }

  component <- as.numeric(component)

  number_to_copy <- min(
    length(component),
    dimensionality
  )

  output[seq_len(number_to_copy)] <- component[
    seq_len(number_to_copy)
  ]

  output
}


# ============================================================
# Validate locked occurrence archive
# ============================================================

validate_occurrence_archive <- function(
    archive,
    expected_shape_names,
    expected_sample_sizes,
    expected_master_seed
) {

  if (!is.list(archive)) {
    stop("The occurrence archive is not a list.")
  }

  required_names <- c(
    "metadata",
    "master_datasets",
    "occurrence_subsets"
  )

  if (!all(required_names %in% names(archive))) {
    stop(
      "The occurrence archive is missing one or more required elements: ",
      paste(required_names, collapse = ", "),
      "."
    )
  }

  if (!identical(
    names(archive$master_datasets),
    expected_shape_names
  )) {
    stop(
      "The archived shape names do not match the locked five-shape ",
      "2D synthetic benchmark."
    )
  }

  archived_sample_sizes <- as.integer(
    archive$metadata$sample_sizes
  )

  if (!identical(
    archived_sample_sizes,
    as.integer(expected_sample_sizes)
  )) {
    stop(
      "The archived sample sizes do not match c(300, 900, 1500)."
    )
  }

  if (
    is.null(archive$metadata$master_seed) ||
      !identical(
        as.integer(archive$metadata$master_seed),
        as.integer(expected_master_seed)
      )
  ) {
    stop(
      "The occurrence archive master seed does not match the locked ",
      "baseline master seed."
    )
  }

  for (shape_name in expected_shape_names) {

    master_object <- archive$master_datasets[[shape_name]]

    master_points <- validate_numeric_matrix(
      master_object$points,
      paste0("master points for ", shape_name)
    )

    if (ncol(master_points) != 2L) {
      stop(
        "The locked 2D occurrence archive contains a non-2D master cloud ",
        "for ",
        shape_name,
        "."
      )
    }

    for (current_sample_size in expected_sample_sizes) {

      size_key <- as.character(
        current_sample_size
      )

      subset_object <- archive$occurrence_subsets[[shape_name]][[size_key]]

      if (is.null(subset_object)) {
        stop(
          "The occurrence archive is missing ",
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
        as.integer(subset_object$master_row_index),
        as.integer(expected_indices)
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

      archived_points <- validate_numeric_matrix(
        subset_object$points,
        paste0(
          "archived occurrence subset for ",
          shape_name,
          " at n = ",
          current_sample_size
        )
      )

      colnames(archived_points) <- colnames(
        expected_points
      )

      if (!identical(
        archived_points,
        expected_points
      )) {
        stop(
          "The archived occurrence cloud is not the exact nested subset ",
          "of its master cloud for ",
          shape_name,
          " at n = ",
          current_sample_size,
          "."
        )
      }
    }
  }

  invisible(TRUE)
}


# ============================================================
# Transparent copies of locked occurrence clouds
# ============================================================

write_occurrence_cloud_files <- function(
    archive,
    occurrence_directory,
    manifest_file,
    readme_file
) {

  dir.create(
    occurrence_directory,
    recursive = TRUE,
    showWarnings = FALSE
  )

  old_digits_option <- getOption("digits")

  options(
    digits = 17
  )

  on.exit(
    options(digits = old_digits_option),
    add = TRUE
  )

  manifest_rows <- list()
  manifest_index <- 0L

  add_manifest_entry <- function(
      shape_code,
      shape_label,
      cloud_type,
      sample_size,
      generation_seed,
      true_area,
      rds_path,
      csv_path
  ) {

    manifest_index <<- manifest_index + 1L

    manifest_rows[[manifest_index]] <<- data.frame(
      Shape_code = shape_code,
      Shape = shape_label,
      Cloud_type = cloud_type,
      Sample_size = sample_size,
      Generation_seed = generation_seed,
      True_area = true_area,
      RDS_file = normalizePath(
        rds_path,
        mustWork = FALSE
      ),
      RDS_MD5 = unname(
        tools::md5sum(rds_path)
      ),
      CSV_file = normalizePath(
        csv_path,
        mustWork = FALSE
      ),
      CSV_MD5 = unname(
        tools::md5sum(csv_path)
      ),
      stringsAsFactors = FALSE
    )
  }

  for (shape_name in names(
    archive$master_datasets
  )) {

    master_object <- archive$master_datasets[[shape_name]]

    output_shape_label <- unname(
      shape_labels[shape_name]
    )

    shape_directory <- file.path(
      occurrence_directory,
      shape_name
    )

    dir.create(
      shape_directory,
      recursive = TRUE,
      showWarnings = FALSE
    )

    master_points <- master_object$points
    master_size <- nrow(master_points)

    master_rds <- file.path(
      shape_directory,
      paste0(
        shape_name,
        "_master_n",
        master_size,
        ".rds"
      )
    )

    master_csv <- file.path(
      shape_directory,
      paste0(
        shape_name,
        "_master_n",
        master_size,
        ".csv"
      )
    )

    saveRDS(
      list(
        shape_code = shape_name,
        shape_label = output_shape_label,
        cloud_type = "master",
        sample_size = master_size,
        generation_seed = master_object$generation_seed,
        master_row_index = seq_len(master_size),
        points = master_points,
        true_area = master_object$true_area,
        boundary = master_object$boundary,
        parameters = master_object$parameters
      ),
      file = master_rds,
      version = 3
    )

    master_csv_data <- data.frame(
      Shape_code = shape_name,
      Shape = output_shape_label,
      Cloud_type = "master",
      Sample_size = master_size,
      Generation_seed = master_object$generation_seed,
      Master_row_index = seq_len(master_size),
      master_points,
      check.names = FALSE
    )

    write.csv(
      master_csv_data,
      file = master_csv,
      row.names = FALSE
    )

    add_manifest_entry(
      shape_code = shape_name,
      shape_label = output_shape_label,
      cloud_type = "master",
      sample_size = master_size,
      generation_seed = master_object$generation_seed,
      true_area = master_object$true_area,
      rds_path = master_rds,
      csv_path = master_csv
    )

    for (size_key in names(
      archive$occurrence_subsets[[shape_name]]
    )) {

      subset_object <- archive$occurrence_subsets[[shape_name]][[size_key]]

      subset_size <- subset_object$sample_size
      subset_points <- subset_object$points
      subset_indices <- subset_object$master_row_index

      subset_rds <- file.path(
        shape_directory,
        paste0(
          shape_name,
          "_occurrence_n",
          subset_size,
          ".rds"
        )
      )

      subset_csv <- file.path(
        shape_directory,
        paste0(
          shape_name,
          "_occurrence_n",
          subset_size,
          ".csv"
        )
      )

      # Save the occurrence subset itself without altering the coordinates.
      saveRDS(
        subset_object,
        file = subset_rds,
        version = 3
      )

      subset_csv_data <- data.frame(
        Shape_code = shape_name,
        Shape = output_shape_label,
        Cloud_type = "nested occurrence subset",
        Sample_size = subset_size,
        Generation_seed = master_object$generation_seed,
        Master_row_index = subset_indices,
        subset_points,
        check.names = FALSE
      )

      write.csv(
        subset_csv_data,
        file = subset_csv,
        row.names = FALSE
      )

      add_manifest_entry(
        shape_code = shape_name,
        shape_label = output_shape_label,
        cloud_type = "nested occurrence subset",
        sample_size = subset_size,
        generation_seed = master_object$generation_seed,
        true_area = master_object$true_area,
        rds_path = subset_rds,
        csv_path = subset_csv
      )
    }
  }

  occurrence_manifest <- do.call(
    rbind,
    manifest_rows
  )

  rownames(occurrence_manifest) <- NULL

  write.csv(
    occurrence_manifest,
    file = manifest_file,
    row.names = FALSE
  )

  readme_lines <- c(
    "Locked 2D synthetic occurrence-cloud archive",
    "============================================",
    "",
    "These are transparent copies of the authoritative occurrence clouds",
    "used in the original 2D synthetic benchmark.",
    "",
    "The authoritative archive itself was copied byte-for-byte into the",
    "Final Quantum project. The baseline occurrence clouds are NOT regenerated",
    "for the revised QPH rerun.",
    "",
    "The n = 300 and n = 900 occurrence clouds are exact nested subsets of",
    "the corresponding n = 1500 master cloud.",
    "",
    paste0(
      "Master seed: ",
      archive$metadata$master_seed
    ),
    paste0(
      "Sample sizes: ",
      paste(
        archive$metadata$sample_sizes,
        collapse = ", "
      )
    )
  )

  writeLines(
    readme_lines,
    con = readme_file
  )

  occurrence_manifest
}


# ============================================================
# Load and verify locked occurrence archive
# ============================================================

occurrence_archive <- readRDS(
  occurrence_archive_file
)

validate_occurrence_archive(
  archive = occurrence_archive,
  expected_shape_names = expected_shape_names,
  expected_sample_sizes = sample_sizes,
  expected_master_seed = master_seed
)

occurrence_archive_md5 <- unname(
  tools::md5sum(
    occurrence_archive_file
  )
)

legacy_occurrence_archive_md5 <- if (
  file.exists(legacy_occurrence_archive_file)
) {
  unname(
    tools::md5sum(
      legacy_occurrence_archive_file
    )
  )
} else {
  NA_character_
}

if (
  !is.na(legacy_occurrence_archive_md5) &&
    !identical(
      occurrence_archive_md5,
      legacy_occurrence_archive_md5
    )
) {
  stop(
    "The Final Quantum occurrence archive does not have the same MD5 ",
    "checksum as the legacy authoritative archive."
  )
}

master_datasets <- occurrence_archive$master_datasets
occurrence_subsets <- occurrence_archive$occurrence_subsets

occurrence_manifest <- write_occurrence_cloud_files(
  archive = occurrence_archive,
  occurrence_directory = occurrence_directory,
  manifest_file = occurrence_manifest_file,
  readme_file = occurrence_readme_file
)

writeLines(
  c(
    "Final Quantum locked input source",
    "================================",
    "",
    paste0(
      "New authoritative archive: ",
      normalizePath(
        occurrence_archive_file,
        mustWork = TRUE
      )
    ),
    paste0(
      "Archive MD5: ",
      occurrence_archive_md5
    ),
    paste0(
      "Legacy source path: ",
      legacy_occurrence_archive_file
    ),
    paste0(
      "Legacy MD5 when available: ",
      legacy_occurrence_archive_md5
    ),
    "",
    "The occurrence data were not regenerated for the revised QPH rerun."
  ),
  con = locked_input_source_file
)

message(
  "Locked occurrence archive verified."
)

message(
  "Occurrence archive MD5: ",
  occurrence_archive_md5
)


# ============================================================
# Package and runtime metadata
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
    "; the existing manuscript codebase recorded version ",
    expected_hypervolume_version,
    ". The run will continue, and the installed version is recorded."
  )
}

svm_formals <- formals(
  hypervolume::hypervolume_svm
)

runtime_default_nu <- eval(
  svm_formals$svm.nu,
  envir = baseenv()
)

runtime_default_gamma <- eval(
  svm_formals$svm.gamma,
  envir = baseenv()
)

runtime_default_scale_factor <- eval(
  svm_formals$scale.factor,
  envir = baseenv()
)

if (!isTRUE(all.equal(
  as.numeric(runtime_default_nu),
  svm_nu
))) {
  warning(
    "The installed hypervolume_svm() default svm.nu differs from ",
    "the explicitly locked value in this script."
  )
}

if (!isTRUE(all.equal(
  as.numeric(runtime_default_gamma),
  svm_gamma
))) {
  warning(
    "The installed hypervolume_svm() default svm.gamma differs from ",
    "the explicitly locked value in this script."
  )
}

if (!isTRUE(all.equal(
  as.numeric(runtime_default_scale_factor),
  svm_scale_factor
))) {
  warning(
    "The installed hypervolume_svm() default scale.factor differs from ",
    "the explicitly locked value in this script."
  )
}


# ============================================================
# Output files
# ============================================================

checkpoint_file <- file.path(
  output_directory,
  "baseline_fit_checkpoint_sqrtNB_q099.rds"
)

results_file <- file.path(
  output_directory,
  "baseline_fit_results_sqrtNB_q099.rds"
)

summary_file <- file.path(
  output_directory,
  "baseline_fit_summary_sqrtNB_q099.csv"
)

qph_audit_file <- file.path(
  output_directory,
  "QPH_bandwidth_audit_sqrtNB_q099.csv"
)

qph_local_s_file <- file.path(
  output_directory,
  "QPH_local_s_audit_sqrtNB_q099.csv"
)

kde_audit_file <- file.path(
  output_directory,
  "KDE_bandwidth_audit.csv"
)

svm_audit_file <- file.path(
  output_directory,
  "SVM_parameter_audit.csv"
)

svm_support_vector_file <- file.path(
  output_directory,
  "SVM_support_vector_indices.csv"
)

failure_file <- file.path(
  output_directory,
  "baseline_fit_failures_sqrtNB_q099.csv"
)

run_metadata_file <- file.path(
  output_directory,
  "baseline_run_metadata_sqrtNB_q099.rds"
)

session_information_file <- file.path(
  output_directory,
  "baseline_session_information_sqrtNB_q099.txt"
)

hypervolume_svm_definition_file <- file.path(
  output_directory,
  "hypervolume_svm_runtime_definition.txt"
)

hypervolume_gaussian_definition_file <- file.path(
  output_directory,
  "hypervolume_gaussian_runtime_definition.txt"
)


# ============================================================
# Analysis signature for safe checkpoint reuse
# ============================================================

analysis_settings <- list(
  script_name = "01_2D_Synthetic_Baseline_Fits.R",
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
  hypervolume_version = installed_hypervolume_version,
  e1071_version = installed_e1071_version
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

run_metadata <- list(
  analysis_settings = analysis_settings,
  analysis_settings_hash = analysis_settings_hash,
  started_at = as.character(Sys.time()),
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
  file = run_metadata_file,
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
# QPH baseline fit
# ============================================================

fit_qph_baseline <- function(
    occurrence_points,
    shape_name,
    shape_label,
    sample_size,
    sampling_seed,
    verbose
) {

  occurrence_points <- validate_numeric_matrix(
    occurrence_points,
    "occurrence_points"
  )

  occurrence_points <- set_environmental_axis_names(
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

  hv_qph <- qph_result$hypervolume

  methods::validObject(
    hv_qph
  )

  if (!isTRUE(
    all.equal(
      as.numeric(
        qph_result$audit$q
      ),
      qph_q
    )
  )) {
    stop(
      "QPH audit did not store q = 0.99."
    )
  }

  if (!isTRUE(
    qph_result$audit$fitted_isotropic
  )) {
    stop(
      "The baseline QPH bandwidth is not isotropic."
    )
  }

  if (!isTRUE(all.equal(
    as.numeric(
      qph_result$audit$fitted_bandwidth
    ),
    rep(
      qph_result$audit$baseline_scalar_h,
      ncol(occurrence_points)
    ),
    tolerance = 1e-12
  ))) {
    stop(
      "The fitted baseline QPH bandwidth differs from the locked ",
      "sqrt-NB isotropic bandwidth."
    )
  }

  list(
    success = TRUE,
    method = "QPH",
    hypervolume = hv_qph,
    audit = qph_result$audit,
    audit_summary = qph_result$audit_summary,
    occurrence_potential_raw = qph_result$occurrence_potential_raw,
    potential_threshold_raw = qph_result$potential_threshold_raw,
    potential_threshold_relative = (
      qph_result$potential_threshold_relative
    ),
    sampling_region_volume = qph_result$sampling_region_volume,
    retained_fraction = qph_result$retained_fraction,
    volume_standard_error_conditional = (
      qph_result$qph_volume_se_conditional
    ),
    runtime_seconds = unname(
      fit_time["elapsed"]
    ),
    sampling_seed = sampling_seed,
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

  occurrence_points <- validate_numeric_matrix(
    occurrence_points,
    "occurrence_points"
  )

  occurrence_points <- set_environmental_axis_names(
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
    sampling_seed
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

  methods::validObject(
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
      is.null(bandwidth_method_attribute)
    ) {
      kde_bandwidth_method
    } else {
      as.character(
        bandwidth_method_attribute
      )
    },
    probability_quantile = kde_probability_quantile,
    bandwidth_runtime_seconds = unname(
      bandwidth_time["elapsed"]
    ),
    hypervolume_runtime_seconds = unname(
      fit_time["elapsed"]
    ),
    runtime_seconds = (
      unname(
        bandwidth_time["elapsed"]
      ) +
        unname(
          fit_time["elapsed"]
        )
    ),
    sampling_seed = sampling_seed,
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

  occurrence_points <- validate_numeric_matrix(
    occurrence_points,
    "occurrence_points"
  )

  dimensionality <- ncol(
    occurrence_points
  )

  axis_names <- colnames(
    occurrence_points
  )

  if (is.null(axis_names)) {
    axis_names <- paste(
      "Environmental axis",
      seq_len(dimensionality)
    )
  }

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
  )[1]

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
      "The fitted SVM produced a non-positive derived squared ",
      "sampling distance."
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

  occurrence_points <- validate_numeric_matrix(
    occurrence_points,
    "occurrence_points"
  )

  occurrence_points <- set_environmental_axis_names(
    occurrence_points
  )

  audit_model_time <- system.time({

    audit_svm_model <- fit_audit_svm_model(
      occurrence_points = occurrence_points
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
    sampling_seed
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

  methods::validObject(
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
      "The SVM random-point count differs from support_vectors * ",
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
      audit_model_time["elapsed"]
    ),
    hypervolume_runtime_seconds = unname(
      hypervolume_time["elapsed"]
    ),
    runtime_seconds = (
      unname(
        audit_model_time["elapsed"]
      ) +
        unname(
          hypervolume_time["elapsed"]
        )
    ),
    sampling_seed = sampling_seed,
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
    sampling_seed = sampling_seed,
    error_message = as.character(
      error_message
    )
  )
}


# ============================================================
# Initialise or resume checkpoint
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
      !all(c(
        "analysis_settings_hash",
        "scenarios"
      ) %in% names(
        checkpoint_object
      ))
  ) {
    stop(
      "The existing baseline checkpoint is not a valid Script 01 checkpoint."
    )
  }

  if (!identical(
    checkpoint_object$analysis_settings_hash,
    analysis_settings_hash
  )) {
    stop(
      "The existing baseline checkpoint was produced with different ",
      "occurrence data, QPH core, estimator settings, or package versions. ",
      "Do not mix runs. Move/delete the incompatible checkpoint or use a ",
      "new output directory."
    )
  }

  scenario_results <- checkpoint_object$scenarios

  message(
    "Loaded compatible checkpoint containing ",
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
    file = checkpoint_file,
    version = 3
  )
}


# ============================================================
# Run all 15 baseline scenarios
# ============================================================

scenario_index <- 0L

for (shape_name in expected_shape_names) {

  master_object <- master_datasets[[shape_name]]

  shape_label <- unname(
    shape_labels[
      shape_name
    ]
  )

  for (
    current_sample_size in sample_sizes
  ) {

    scenario_index <- scenario_index + 1L

    scenario_name <- paste(
      shape_name,
      current_sample_size,
      sep = "_"
    )

    sampling_seed <- (
      master_seed +
        10000L +
        scenario_index
    )

    size_key <- as.character(
      current_sample_size
    )

    subset_object <- occurrence_subsets[[shape_name]][[size_key]]

    occurrence_points <- subset_object$points

    expected_occurrence_points <- master_object$points[
      subset_object$master_row_index,
      ,
      drop = FALSE
    ]

    if (!identical(
      occurrence_points,
      expected_occurrence_points
    )) {
      stop(
        "Occurrence-cloud integrity check failed immediately before ",
        "model fitting for ",
        scenario_name,
        "."
      )
    }

    if (
      is.null(
        scenario_results[[scenario_name]]
      )
    ) {

      scenario_results[[scenario_name]] <- list(
        scenario_name = scenario_name,
        shape_name = shape_name,
        shape_label = shape_label,
        sample_size = current_sample_size,
        true_area = as.numeric(
          master_object$true_area
        ),
        generation_seed = as.integer(
          master_object$generation_seed
        ),
        sampling_seed = as.integer(
          sampling_seed
        ),
        occurrence_master_row_index = as.integer(
          subset_object$master_row_index
        ),
        qph = NULL,
        gaussian_kde = NULL,
        svm = NULL
      )
    }

    current_scenario <- scenario_results[[scenario_name]]

    message(
      "\n============================================================"
    )
    message(
      "Baseline scenario: ",
      shape_label,
      " | n = ",
      current_sample_size
    )
    message(
      "Sampling seed: ",
      sampling_seed
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
          sampling_seed = sampling_seed,
          verbose = show_progress_messages
        ),
        error = function(
          error_condition
        ) {

          error_message <- conditionMessage(
            error_condition
          )

          message(
            "QPH fit failed:\n  ",
            error_message
          )

          make_fit_failure(
            method = "QPH",
            sampling_seed = sampling_seed,
            error_message = error_message
          )
        }
      )

      current_scenario$qph <- qph_fit

      scenario_results[[scenario_name]] <- current_scenario

      saveRDS(
        current_scenario,
        file = file.path(
          scenario_directory,
          paste0(
            scenario_name,
            "_baseline_fits.rds"
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
        "Fitting Gaussian KDE with Silverman bandwidth..."
      )

      kde_fit <- tryCatch(
        fit_kde_baseline(
          occurrence_points = occurrence_points,
          shape_name = shape_name,
          shape_label = shape_label,
          sample_size = current_sample_size,
          sampling_seed = sampling_seed,
          verbose = show_progress_messages
        ),
        error = function(
          error_condition
        ) {

          error_message <- conditionMessage(
            error_condition
          )

          message(
            "Gaussian KDE fit failed:\n  ",
            error_message
          )

          make_fit_failure(
            method = "Gaussian KDE",
            sampling_seed = sampling_seed,
            error_message = error_message
          )
        }
      )

      current_scenario$gaussian_kde <- kde_fit

      scenario_results[[scenario_name]] <- current_scenario

      saveRDS(
        current_scenario,
        file = file.path(
          scenario_directory,
          paste0(
            scenario_name,
            "_baseline_fits.rds"
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
          sampling_seed = sampling_seed,
          verbose = show_progress_messages
        ),
        error = function(
          error_condition
        ) {

          error_message <- conditionMessage(
            error_condition
          )

          message(
            "SVM fit failed:\n  ",
            error_message
          )

          make_fit_failure(
            method = "SVM",
            sampling_seed = sampling_seed,
            error_message = error_message
          )
        }
      )

      current_scenario$svm <- svm_fit

      scenario_results[[scenario_name]] <- current_scenario

      saveRDS(
        current_scenario,
        file = file.path(
          scenario_directory,
          paste0(
            scenario_name,
            "_baseline_fits.rds"
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

  method_result <- scenario[[method_key]]

  summary_index <<- summary_index + 1L

  success <- isTRUE(
    method_result$success
  )

  estimated_area <- if (
    success
  ) {
    as.numeric(
      method_result$hypervolume@Volume
    )
  } else {
    NA_real_
  }

  signed_error <- (
    estimated_area -
      scenario$true_area
  )

  absolute_error <- abs(
    signed_error
  )

  relative_error_percent <- (
    100 *
      signed_error /
      scenario$true_area
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
  bandwidth_method <- NA_character_

  kde_quantile_value <- NA_real_

  svm_nu_value <- NA_real_
  svm_gamma_value <- NA_real_
  svm_scale_factor_value <- NA_real_

  if (
    success &&
      identical(
        method_key,
        "qph"
      )
  ) {

    qph_k <- method_result$audit$K
    qph_mean_s <- method_result$audit$mean_s
    qph_scalar_h <- method_result$audit$baseline_scalar_h
    qph_q_value <- method_result$audit$q

    bandwidth_axis_1 <- safe_axis_value(
      method_result$audit$fitted_bandwidth,
      1L
    )

    bandwidth_axis_2 <- safe_axis_value(
      method_result$audit$fitted_bandwidth,
      2L
    )

    bandwidth_method <- method_result$audit$bandwidth_method
  }

  if (
    success &&
      identical(
        method_key,
        "gaussian_kde"
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

    bandwidth_method <- method_result$bandwidth_method
    kde_quantile_value <- method_result$probability_quantile
  }

  if (
    success &&
      identical(
        method_key,
        "svm"
      )
  ) {

    svm_nu_value <- svm_nu
    svm_gamma_value <- svm_gamma
    svm_scale_factor_value <- svm_scale_factor
  }

  summary_rows[[summary_index]] <<- data.frame(
    Shape_code = scenario$shape_name,
    Shape = scenario$shape_label,
    Sample_size = scenario$sample_size,
    Method = method_label,
    Success = success,
    True_area = scenario$true_area,
    Estimated_area = estimated_area,
    Signed_error = signed_error,
    Absolute_error = absolute_error,
    Relative_error_percent = relative_error_percent,
    Random_points = random_points,
    Point_density = point_density,
    Runtime_seconds = if (
      success
    ) {
      method_result$runtime_seconds
    } else {
      NA_real_
    },
    Sampling_seed = scenario$sampling_seed,
    Bandwidth_method = bandwidth_method,
    Bandwidth_axis_1 = bandwidth_axis_1,
    Bandwidth_axis_2 = bandwidth_axis_2,
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

  current_scenario <- scenario_results[[scenario_name]]

  add_summary_row(
    scenario = current_scenario,
    method_key = "qph",
    method_label = "QPH"
  )

  add_summary_row(
    scenario = current_scenario,
    method_key = "gaussian_kde",
    method_label = "Gaussian KDE"
  )

  add_summary_row(
    scenario = current_scenario,
    method_key = "svm",
    method_label = "SVM"
  )
}

baseline_summary <- do.call(
  rbind,
  summary_rows
)

rownames(
  baseline_summary
) <- NULL

baseline_summary <- baseline_summary[
  order(
    match(
      baseline_summary$Shape_code,
      expected_shape_names
    ),
    baseline_summary$Sample_size,
    match(
      baseline_summary$Method,
      c(
        "QPH",
        "Gaussian KDE",
        "SVM"
      )
    )
  ),
  ,
  drop = FALSE
]

write.csv(
  baseline_summary,
  file = summary_file,
  row.names = FALSE
)


# ============================================================
# QPH bandwidth audit tables
# ============================================================

qph_audit_rows <- list()
qph_local_s_rows <- list()

qph_audit_index <- 0L
qph_local_s_index <- 0L

for (scenario_name in names(
  scenario_results
)) {

  current_scenario <- scenario_results[[scenario_name]]

  qph_result <- current_scenario$qph

  if (!isTRUE(
    qph_result$success
  )) {
    next
  }

  qph_audit_index <- qph_audit_index + 1L

  current_audit_summary <- qph_result$audit_summary

  current_audit_summary <- cbind(
    data.frame(
      Shape_code = current_scenario$shape_name,
      Shape = current_scenario$shape_label,
      Sample_size = current_scenario$sample_size,
      stringsAsFactors = FALSE
    ),
    current_audit_summary
  )

  qph_audit_rows[[qph_audit_index]] <- current_audit_summary

  local_s <- as.numeric(
    qph_result$audit$local_s
  )

  qph_local_s_index <- qph_local_s_index + 1L

  qph_local_s_rows[[qph_local_s_index]] <- data.frame(
    Shape_code = current_scenario$shape_name,
    Shape = current_scenario$shape_label,
    Sample_size = current_scenario$sample_size,
    Occurrence_index = seq_along(
      local_s
    ),
    K = qph_result$audit$K,
    s_i = local_s,
    Mean_s = qph_result$audit$mean_s,
    Scalar_h = qph_result$audit$baseline_scalar_h,
    q = qph_result$audit$q,
    Sampling_seed = current_scenario$sampling_seed,
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

  write.csv(
    qph_audit_table,
    file = qph_audit_file,
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

  write.csv(
    qph_local_s_table,
    file = qph_local_s_file,
    row.names = FALSE
  )
}


# ============================================================
# KDE bandwidth audit table
# ============================================================

kde_audit_rows <- list()
kde_audit_index <- 0L

for (scenario_name in names(
  scenario_results
)) {

  current_scenario <- scenario_results[[scenario_name]]

  kde_result <- current_scenario$gaussian_kde

  if (!isTRUE(
    kde_result$success
  )) {
    next
  }

  kde_audit_index <- kde_audit_index + 1L

  kde_audit_rows[[kde_audit_index]] <- data.frame(
    Shape_code = current_scenario$shape_name,
    Shape = current_scenario$shape_label,
    Sample_size = current_scenario$sample_size,
    Bandwidth_method = kde_result$bandwidth_method,
    Bandwidth_axis_1 = safe_axis_value(
      kde_result$bandwidth,
      1L
    ),
    Bandwidth_axis_2 = safe_axis_value(
      kde_result$bandwidth,
      2L
    ),
    Probability_quantile = kde_result$probability_quantile,
    Samples_per_point = kde_samples_per_point,
    SD_count = kde_sd_count,
    Sampling_seed = current_scenario$sampling_seed,
    Bandwidth_runtime_seconds = (
      kde_result$bandwidth_runtime_seconds
    ),
    Hypervolume_runtime_seconds = (
      kde_result$hypervolume_runtime_seconds
    ),
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

  write.csv(
    kde_audit_table,
    file = kde_audit_file,
    row.names = FALSE
  )
}


# ============================================================
# SVM parameter and support-vector audits
# ============================================================

svm_audit_rows <- list()
svm_support_vector_rows <- list()

svm_audit_index <- 0L
svm_support_vector_index <- 0L

for (scenario_name in names(
  scenario_results
)) {

  current_scenario <- scenario_results[[scenario_name]]

  svm_result <- current_scenario$svm

  if (!isTRUE(
    svm_result$success
  )) {
    next
  }

  svm_audit <- svm_result$audit

  svm_audit_index <- svm_audit_index + 1L

  svm_audit_rows[[svm_audit_index]] <- data.frame(
    Shape_code = current_scenario$shape_name,
    Shape = current_scenario$shape_label,
    Sample_size = current_scenario$sample_size,
    SVM_nu = svm_nu,
    SVM_gamma = svm_gamma,
    SVM_scale_factor = svm_scale_factor,
    SVM_kernel = "radial",
    Internal_scaling = TRUE,
    Samples_per_point_argument = svm_samples_per_point,
    Number_support_vectors = svm_audit$number_of_support_vectors,
    Support_vector_fraction = svm_audit$support_vector_fraction,
    Expected_random_points = svm_result$expected_random_points,
    Actual_random_points = svm_result$actual_random_points,
    Number_training_errors = svm_audit$number_of_training_errors,
    Training_error_fraction = svm_audit$training_error_fraction,
    SVM_rho = svm_audit$rho,
    SVM_coefficient_sum = svm_audit$coefficient_sum,
    Coefficient_to_rho_ratio = svm_audit$coefficient_to_rho_ratio,
    Derived_squared_scaled_distance = svm_audit$squared_scaled_distance,
    Data_SD_axis_1 = safe_axis_value(
      svm_audit$data_standard_deviation,
      1L
    ),
    Data_SD_axis_2 = safe_axis_value(
      svm_audit$data_standard_deviation,
      2L
    ),
    Sampling_scale_axis_1 = safe_axis_value(
      svm_audit$sampling_scales,
      1L
    ),
    Sampling_scale_axis_2 = safe_axis_value(
      svm_audit$sampling_scales,
      2L
    ),
    Internal_scale_centre_axis_1 = safe_axis_value(
      svm_audit$internal_scale_center,
      1L
    ),
    Internal_scale_centre_axis_2 = safe_axis_value(
      svm_audit$internal_scale_center,
      2L
    ),
    Internal_scale_SD_axis_1 = safe_axis_value(
      svm_audit$internal_scale_sd,
      1L
    ),
    Internal_scale_SD_axis_2 = safe_axis_value(
      svm_audit$internal_scale_sd,
      2L
    ),
    Audit_model_runtime_seconds = (
      svm_result$audit_model_runtime_seconds
    ),
    Hypervolume_runtime_seconds = (
      svm_result$hypervolume_runtime_seconds
    ),
    Sampling_seed = current_scenario$sampling_seed,
    stringsAsFactors = FALSE
  )

  svm_support_vector_index <- svm_support_vector_index + 1L

  svm_support_vector_rows[[svm_support_vector_index]] <- data.frame(
    Shape_code = current_scenario$shape_name,
    Shape = current_scenario$shape_label,
    Sample_size = current_scenario$sample_size,
    Support_vector_order = seq_along(
      svm_audit$support_vector_indices
    ),
    Occurrence_index = svm_audit$support_vector_indices,
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

  write.csv(
    svm_audit_table,
    file = svm_audit_file,
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

  write.csv(
    svm_support_vector_table,
    file = svm_support_vector_file,
    row.names = FALSE
  )
}


# ============================================================
# Failure audit
# ============================================================

failure_rows <- list()
failure_index <- 0L

for (scenario_name in names(
  scenario_results
)) {

  current_scenario <- scenario_results[[scenario_name]]

  for (method_key in c(
    "qph",
    "gaussian_kde",
    "svm"
  )) {

    method_result <- current_scenario[[method_key]]

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

    failure_index <- failure_index + 1L

    failure_rows[[failure_index]] <- data.frame(
      Scenario = scenario_name,
      Shape_code = current_scenario$shape_name,
      Shape = current_scenario$shape_label,
      Sample_size = current_scenario$sample_size,
      Method = method_result$method,
      Sampling_seed = current_scenario$sampling_seed,
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

write.csv(
  failure_table,
  file = failure_file,
  row.names = FALSE
)


# ============================================================
# Save final authoritative baseline object
# ============================================================

final_results <- list(
  metadata = list(
    script_name = "01_2D_Synthetic_Baseline_Fits.R",
    completed_at = as.character(
      Sys.time()
    ),
    analysis_settings_hash = analysis_settings_hash,
    analysis_settings = analysis_settings,
    occurrence_archive_path = normalizePath(
      occurrence_archive_file,
      mustWork = TRUE
    ),
    occurrence_archive_md5 = occurrence_archive_md5,
    qph_core_path = normalizePath(
      qph_core_file,
      mustWork = TRUE
    ),
    qph_core_md5 = qph_core_md5,
    qph_core_version = QPH_CORE_VERSION,
    hypervolume_version = installed_hypervolume_version,
    e1071_version = installed_e1071_version
  ),
  scenarios = scenario_results,
  summary = baseline_summary
)

saveRDS(
  final_results,
  file = results_file,
  version = 3
)

run_metadata$completed_at <- as.character(
  Sys.time()
)

run_metadata$number_of_scenarios <- length(
  scenario_results
)

run_metadata$number_of_failed_fits <- nrow(
  failure_table
)

saveRDS(
  run_metadata,
  file = run_metadata_file,
  version = 3
)

writeLines(
  capture.output(
    sessionInfo()
  ),
  con = session_information_file
)


# ============================================================
# Final integrity checks
# ============================================================

expected_number_of_scenarios <- (
  length(
    expected_shape_names
  ) *
    length(
      sample_sizes
    )
)

if (!identical(
  length(
    scenario_results
  ),
  expected_number_of_scenarios
)) {
  warning(
    "Expected ",
    expected_number_of_scenarios,
    " scenario objects but found ",
    length(
      scenario_results
    ),
    "."
  )
}

successful_fit_count <- sum(
  baseline_summary$Success
)

expected_fit_count <- (
  expected_number_of_scenarios *
    3L
)

message(
  "\n============================================================"
)

message(
  "Script 01 complete."
)

message(
  "Successful estimator fits: ",
  successful_fit_count,
  " / ",
  expected_fit_count
)

message(
  "Failed estimator fits: ",
  nrow(
    failure_table
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
  "Baseline summary:\n  ",
  normalizePath(
    summary_file,
    mustWork = FALSE
  )
)

message(
  "============================================================"
)
