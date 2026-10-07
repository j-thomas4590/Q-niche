# ============================================================
# 12_Virtual_Species_Locked_Inputs.R
# ============================================================
#
# PURPOSE
# -------
# Create one authoritative, path-independent input package for the revised
# virtual-species analyses.
#


rm(list = ls())
gc()


# ============================================================
# Packages
# ============================================================

required_packages <- c(
  "terra"
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
    "Install required package(s) before running Script 12: ",
    paste(
      missing_packages,
      collapse = ", "
    )
  )
}

library(terra)


# ============================================================
# Project paths
# ============================================================

# Run from the repository's root folder.
project_directory <- "."

results_directory <- file.path(
  project_directory,
  "Results"
)

analysis_root_directory <- file.path(
  results_directory,
  "Virtual_Species_sqrtNB_q099"
)

locked_input_directory <- file.path(
  analysis_root_directory,
  "00_Locked_Inputs"
)

raster_directory <- file.path(
  locked_input_directory,
  "rasters"
)

table_directory <- file.path(
  locked_input_directory,
  "tables"
)

for (directory in c(
  analysis_root_directory,
  locked_input_directory,
  raster_directory,
  table_directory
)) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ============================================================
# Locate completed historical virtual-species inputs
# ============================================================


source_root_candidates <- unique(
  c(
    file.path(
      project_directory,
      "Sythetic Results"
    ),
    file.path(
      project_directory,
      "Synthetic Results"
    ),
    file.path(
      project_directory,
      "Legacy_Virtual_Species"
    ),
    file.path(
      results_directory,
      "Legacy_Virtual_Species"
    ),
    file.path(
      path.expand("~/Desktop/Quantum Paper"),
      "Sythetic Results"
    ),
    file.path(
      path.expand("~/Desktop/Quantum Paper"),
      "Synthetic Results"
    ),
    "C:/Users/r02jt24/Desktop/Quantum Paper/Sythetic Results",
    "C:/Users/r02jt24/Desktop/Quantum Paper/Synthetic Results"
  )
)

unimodal_directory_name <- "qph_virtual_species_geographic_validation"
disconnected_directory_name <- "qph_virtual_species_disconnected_validation"

required_source_basenames <- c(
  "virtual_species_truth_authoritative.rds",
  "virtual_species_occurrences_authoritative.rds"
)

source_root_is_valid <- function(root) {

  if (!dir.exists(root)) {
    return(FALSE)
  }

  unimodal_directory <- file.path(
    root,
    unimodal_directory_name
  )

  disconnected_directory <- file.path(
    root,
    disconnected_directory_name
  )

  if (
    !dir.exists(unimodal_directory) ||
      !dir.exists(disconnected_directory)
  ) {
    return(FALSE)
  }

  required_paths <- c(
    file.path(
      unimodal_directory,
      required_source_basenames
    ),
    file.path(
      disconnected_directory,
      required_source_basenames
    ),
    file.path(
      unimodal_directory,
      "virtual_species_environment_authoritative_2p5m.rds"
    )
  )

  all(
    file.exists(
      required_paths
    )
  )
}

valid_source_roots <- source_root_candidates[
  vapply(
    source_root_candidates,
    source_root_is_valid,
    logical(1)
  )
]

if (length(valid_source_roots) == 0L) {
  stop(
    "Could not locate the completed two-species virtual-species inputs.\n",
    "Expected both historical directories:\n  ",
    unimodal_directory_name,
    "\n  ",
    disconnected_directory_name,
    "\nwith their authoritative truth and occurrence RDS files.\n\n",
    "Searched:\n  ",
    paste(
      source_root_candidates,
      collapse = "\n  "
    )
  )
}

if (length(valid_source_roots) > 1L) {
  message(
    "Multiple complete historical virtual-species roots were found.\n",
    "Using the first candidate in the locked priority order:\n  ",
    valid_source_roots[[1L]]
  )
}

source_root_directory <- valid_source_roots[[1L]]

unimodal_source_directory <- file.path(
  source_root_directory,
  unimodal_directory_name
)

disconnected_source_directory <- file.path(
  source_root_directory,
  disconnected_directory_name
)

message(
  "Historical virtual-species inputs:\n  ",
  source_root_directory
)


# ============================================================
# Locked design
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

maximum_sample_size <- max(
  sample_sizes
)

expected_pc_names <- c(
  "PC1",
  "PC2",
  "PC3"
)

# Deterministic landscape comparison between the two historical truth archives.
landscape_comparison_seed <- 912001L
landscape_comparison_n <- 10000L

numeric_tolerance <- 1e-8


# ============================================================
# Output files
# ============================================================

shared_environment_file <- file.path(
  locked_input_directory,
  "virtual_species_shared_environment_locked.rds"
)

unimodal_truth_file <- file.path(
  locked_input_directory,
  "virtual_species_unimodal_truth_locked.rds"
)

disconnected_truth_file <- file.path(
  locked_input_directory,
  "virtual_species_disconnected_truth_locked.rds"
)

occurrence_archive_file <- file.path(
  locked_input_directory,
  "virtual_species_occurrences_locked.rds"
)

master_archive_file <- file.path(
  locked_input_directory,
  "virtual_species_locked_inputs.rds"
)

input_manifest_file <- file.path(
  table_directory,
  "locked_input_manifest.csv"
)

truth_summary_file <- file.path(
  table_directory,
  "locked_virtual_species_truth_summary.csv"
)

species_parameter_file <- file.path(
  table_directory,
  "locked_virtual_species_generating_parameters.csv"
)

occurrence_summary_file <- file.path(
  table_directory,
  "locked_virtual_species_occurrence_summary.csv"
)

unimodal_occurrence_csv_file <- file.path(
  table_directory,
  "locked_unimodal_occurrences_master.csv"
)

disconnected_occurrence_csv_file <- file.path(
  table_directory,
  "locked_disconnected_occurrences_master.csv"
)

input_audit_file <- file.path(
  table_directory,
  "locked_input_validation_audit.csv"
)

analysis_notes_file <- file.path(
  locked_input_directory,
  "analysis_notes.txt"
)

session_information_file <- file.path(
  locked_input_directory,
  "session_information.txt"
)

settings_file <- file.path(
  locked_input_directory,
  "locked_input_settings.rds"
)

pc_raster_file <- file.path(
  raster_directory,
  "Australia_PC1_PC3_locked.tif"
)

unimodal_suitability_raster_file <- file.path(
  raster_directory,
  "Unimodal_suitability_locked.tif"
)

unimodal_truth_raster_file <- file.path(
  raster_directory,
  "Unimodal_true_distribution_locked.tif"
)

disconnected_suitability_raster_file <- file.path(
  raster_directory,
  "Disconnected_suitability_locked.tif"
)

disconnected_truth_raster_file <- file.path(
  raster_directory,
  "Disconnected_true_distribution_locked.tif"
)

disconnected_mode_raster_file <- file.path(
  raster_directory,
  "Disconnected_true_mode_membership_locked.tif"
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


as_spatvector_safe <- function(x) {

  if (inherits(x, "SpatVector")) {
    return(x)
  }

  if (inherits(x, "PackedSpatVector")) {
    return(
      terra::unwrap(x)
    )
  }

  result <- try(
    terra::vect(x),
    silent = TRUE
  )

  if (
    !inherits(result, "try-error") &&
      inherits(result, "SpatVector")
  ) {
    return(result)
  }

  result <- try(
    terra::unwrap(x),
    silent = TRUE
  )

  if (
    !inherits(result, "try-error") &&
      inherits(result, "SpatVector")
  ) {
    return(result)
  }

  stop(
    "Could not convert object to a terra SpatVector."
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

  if (any(!is.finite(x))) {
    stop(
      "PC matrix contains non-finite values."
    )
  }

  colnames(x) <- expected_pc_names

  x
}


normalise_xy <- function(x) {

  x <- as.matrix(x)
  storage.mode(x) <- "double"

  if (ncol(x) != 2L) {
    stop(
      "Expected a two-column x/y coordinate matrix."
    )
  }

  if (any(!is.finite(x))) {
    stop(
      "Occurrence coordinates contain non-finite values."
    )
  }

  colnames(x) <- c(
    "x",
    "y"
  )

  x
}


extract_raster_values_at_xy <- function(
    raster_object,
    xy
) {

  xy <- normalise_xy(xy)

  extracted <- terra::extract(
    raster_object,
    xy
  )

  extracted <- as.data.frame(
    extracted,
    stringsAsFactors = FALSE
  )

  if (
    nrow(extracted) !=
      nrow(xy)
  ) {
    stop(
      "Raster extraction returned an unexpected number of rows."
    )
  }

  value_columns <- setdiff(
    names(extracted),
    "ID"
  )

  if (length(value_columns) < 1L) {
    stop(
      "Could not identify raster value columns after coordinate extraction."
    )
  }

  as.matrix(
    extracted[
      ,
      value_columns,
      drop = FALSE
    ]
  )
}


extract_single_raster_value_at_xy <- function(
    raster_object,
    xy
) {

  extracted <- extract_raster_values_at_xy(
    raster_object,
    xy
  )

  if (ncol(extracted) != 1L) {
    stop(
      "Expected exactly one raster value column."
    )
  }

  as.numeric(
    extracted[
      ,
      1L
    ]
  )
}


raster_geometry_matches <- function(
    x,
    y
) {

  result <- try(
    terra::compareGeom(
      x,
      y,
      stopOnError = FALSE
    ),
    silent = TRUE
  )

  isTRUE(result)
}


validate_binary_truth <- function(
    truth_raster,
    label
) {

  values <- terra::values(
    truth_raster,
    mat = FALSE
  )

  finite_values <- values[
    is.finite(
      values
    )
  ]

  unique_values <- sort(
    unique(
      finite_values
    )
  )

  if (
    length(unique_values) == 0L ||
      !all(
        unique_values %in%
          c(
            0,
            1
          )
      )
  ) {
    stop(
      label,
      " truth raster is not binary 0/1."
    )
  }

  invisible(TRUE)
}


canonicalise_occurrence_archive <- function(
    archive,
    species_name
) {

  required_names <- c(
    "occurrence_seed",
    "maximum_sample_size",
    "occurrence_table",
    "occurrence_xy",
    "occurrence_pc",
    "subsets"
  )

  missing_names <- setdiff(
    required_names,
    names(archive)
  )

  if (length(missing_names) > 0L) {
    stop(
      species_name,
      " occurrence archive is missing: ",
      paste(
        missing_names,
        collapse = ", "
      )
    )
  }

  xy <- normalise_xy(
    archive$occurrence_xy
  )

  pc <- set_pc_names(
    archive$occurrence_pc
  )

  if (
    nrow(xy) != maximum_sample_size ||
      nrow(pc) != maximum_sample_size
  ) {
    stop(
      species_name,
      " master occurrence archive does not contain exactly ",
      maximum_sample_size,
      " observations."
    )
  }

  if (
    as.integer(
      archive$maximum_sample_size
    ) != maximum_sample_size
  ) {
    stop(
      species_name,
      " maximum sample size differs from the locked value."
    )
  }

  subset_names <- names(
    archive$subsets
  )

  if (
    !all(
      as.character(
        sample_sizes
      ) %in%
        subset_names
    )
  ) {
    stop(
      species_name,
      " occurrence archive does not contain all locked nested samples."
    )
  }

  canonical_subsets <- list()

  for (sample_size in sample_sizes) {

    key <- as.character(
      sample_size
    )

    subset_object <- archive$subsets[[key]]

    if (is.null(subset_object)) {
      stop(
        "Missing ",
        species_name,
        " occurrence subset n=",
        sample_size
      )
    }

    subset_pc <- set_pc_names(
      subset_object$pc
    )

    subset_xy <- normalise_xy(
      subset_object$xy
    )

    if (
      nrow(subset_pc) != sample_size ||
        nrow(subset_xy) != sample_size
    ) {
      stop(
        species_name,
        " subset n=",
        sample_size,
        " has the wrong number of rows."
      )
    }

    if (
      !isTRUE(
        all.equal(
          subset_pc,
          pc[
            seq_len(sample_size),
            ,
            drop = FALSE
          ],
          tolerance = numeric_tolerance,
          check.attributes = FALSE
        )
      )
    ) {
      stop(
        species_name,
        " PC occurrence subsets are not exactly nested at n=",
        sample_size,
        "."
      )
    }

    if (
      !isTRUE(
        all.equal(
          subset_xy,
          xy[
            seq_len(sample_size),
            ,
            drop = FALSE
          ],
          tolerance = numeric_tolerance,
          check.attributes = FALSE
        )
      )
    ) {
      stop(
        species_name,
        " geographic occurrence subsets are not exactly nested at n=",
        sample_size,
        "."
      )
    }

    canonical_subsets[[key]] <- list(
      sample_size = sample_size,
      row_index = seq_len(
        sample_size
      ),
      xy = subset_xy,
      pc = subset_pc
    )

    if (
      identical(
        species_name,
        "Disconnected"
      )
    ) {

      if (is.null(subset_object$true_mode)) {
        stop(
          "Disconnected subset n=",
          sample_size,
          " lacks true mode labels."
        )
      }

      true_mode <- as.character(
        subset_object$true_mode
      )

      mode_table <- table(
        factor(
          true_mode,
          levels = c(
            "A",
            "B"
          )
        )
      )

      if (
        any(
          mode_table !=
            sample_size / 2L
        )
      ) {
        stop(
          "Disconnected subset n=",
          sample_size,
          " is not exactly balanced 50:50 across modes A and B."
        )
      }

      canonical_subsets[[key]]$true_mode <- true_mode

      if (!is.null(subset_object$raster_cell)) {
        canonical_subsets[[key]]$raster_cell <- as.integer(
          subset_object$raster_cell
        )
      }
    }
  }

  output <- list(
    species = species_name,
    occurrence_seed = as.integer(
      archive$occurrence_seed
    ),
    maximum_sample_size = maximum_sample_size,
    occurrence_table = archive$occurrence_table,
    occurrence_xy = xy,
    occurrence_pc = pc,
    subsets = canonical_subsets
  )

  if (
    identical(
      species_name,
      "Disconnected"
    )
  ) {

    if (is.null(archive$occurrence_mode)) {
      stop(
        "Disconnected master occurrence archive lacks occurrence_mode."
      )
    }

    output$sampling_design <- if (
      !is.null(
        archive$sampling_design
      )
    ) {
      as.character(
        archive$sampling_design
      )
    } else {
      "balanced 50:50 across two true environmental modes"
    }

    output$occurrence_mode <- as.character(
      archive$occurrence_mode
    )

    if (!is.null(archive$raster_cells)) {
      output$raster_cells <- as.integer(
        archive$raster_cells
      )
    }
  }

  output
}


make_occurrence_export <- function(
    occurrence_object,
    species_name
) {

  output <- data.frame(
    Row_index = seq_len(
      nrow(
        occurrence_object$occurrence_pc
      )
    ),
    x = occurrence_object$occurrence_xy[
      ,
      1L
    ],
    y = occurrence_object$occurrence_xy[
      ,
      2L
    ],
    PC1 = occurrence_object$occurrence_pc[
      ,
      1L
    ],
    PC2 = occurrence_object$occurrence_pc[
      ,
      2L
    ],
    PC3 = occurrence_object$occurrence_pc[
      ,
      3L
    ],
    In_n300 = seq_len(
      nrow(
        occurrence_object$occurrence_pc
      )
    ) <= 300L,
    In_n900 = seq_len(
      nrow(
        occurrence_object$occurrence_pc
      )
    ) <= 900L,
    In_n1500 = seq_len(
      nrow(
        occurrence_object$occurrence_pc
      )
    ) <= 1500L,
    stringsAsFactors = FALSE
  )

  if (
    identical(
      species_name,
      "Disconnected"
    )
  ) {
    output$True_mode <- occurrence_object$occurrence_mode
  }

  output
}


# ============================================================
# Historical source files
# ============================================================

source_files <- list(
  shared_environment = file.path(
    unimodal_source_directory,
    "virtual_species_environment_authoritative_2p5m.rds"
  ),
  unimodal_truth = file.path(
    unimodal_source_directory,
    "virtual_species_truth_authoritative.rds"
  ),
  unimodal_occurrences = file.path(
    unimodal_source_directory,
    "virtual_species_occurrences_authoritative.rds"
  ),
  unimodal_truth_summary = file.path(
    unimodal_source_directory,
    "virtual_species_truth_summary.csv"
  ),
  disconnected_truth = file.path(
    disconnected_source_directory,
    "virtual_species_truth_authoritative.rds"
  ),
  disconnected_occurrences = file.path(
    disconnected_source_directory,
    "virtual_species_occurrences_authoritative.rds"
  ),
  disconnected_truth_summary = file.path(
    disconnected_source_directory,
    "virtual_species_truth_summary.csv"
  ),
  disconnected_mode_definition = file.path(
    disconnected_source_directory,
    "disconnected_virtual_species_mode_definition.csv"
  )
)

required_source_keys <- c(
  "shared_environment",
  "unimodal_truth",
  "unimodal_occurrences",
  "disconnected_truth",
  "disconnected_occurrences"
)

missing_required_source_files <- required_source_keys[
  !vapply(
    source_files[
      required_source_keys
    ],
    file.exists,
    logical(1)
  )
]

if (length(missing_required_source_files) > 0L) {
  stop(
    "Missing required historical input file(s): ",
    paste(
      missing_required_source_files,
      collapse = ", "
    )
  )
}


# ============================================================
# Load authoritative historical inputs
# ============================================================

message(
  "Loading historical QPH-independent virtual-species inputs..."
)

source_environment_archive <- readRDS(
  source_files$shared_environment
)

source_unimodal_truth <- readRDS(
  source_files$unimodal_truth
)

source_unimodal_occurrences <- readRDS(
  source_files$unimodal_occurrences
)

source_disconnected_truth <- readRDS(
  source_files$disconnected_truth
)

source_disconnected_occurrences <- readRDS(
  source_files$disconnected_occurrences
)


# ============================================================
# Standardise shared environmental objects
# ============================================================

required_unimodal_truth_names <- c(
  "virtual_species_seed",
  "target_species_prevalence",
  "virtual_species_object",
  "virtual_species_pa_object",
  "virtual_species_suitability",
  "truth_raster",
  "pca_object",
  "pc_stack"
)

missing_unimodal_truth_names <- setdiff(
  required_unimodal_truth_names,
  names(
    source_unimodal_truth
  )
)

if (length(missing_unimodal_truth_names) > 0L) {
  stop(
    "Unimodal truth archive is missing: ",
    paste(
      missing_unimodal_truth_names,
      collapse = ", "
    )
  )
}

required_disconnected_truth_names <- c(
  "virtual_species_seed",
  "target_species_prevalence",
  "virtual_species_suitability",
  "virtual_species_pa_object",
  "truth_raster",
  "mode_membership_raster",
  "pca_object",
  "pc_stack",
  "definition"
)

missing_disconnected_truth_names <- setdiff(
  required_disconnected_truth_names,
  names(
    source_disconnected_truth
  )
)

if (length(missing_disconnected_truth_names) > 0L) {
  stop(
    "Disconnected truth archive is missing: ",
    paste(
      missing_disconnected_truth_names,
      collapse = ", "
    )
  )
}


unimodal_pc_stack <- as_spatraster_safe(
  source_unimodal_truth$pc_stack
)

disconnected_pc_stack <- as_spatraster_safe(
  source_disconnected_truth$pc_stack
)

names(
  unimodal_pc_stack
) <- expected_pc_names

names(
  disconnected_pc_stack
) <- expected_pc_names

if (
  !raster_geometry_matches(
    unimodal_pc_stack,
    disconnected_pc_stack
  )
) {
  stop(
    "The two historical virtual species do not use the same PC1-PC3 raster geometry."
  )
}

if (
  !identical(
    names(
      unimodal_pc_stack
    ),
    expected_pc_names
  )
) {
  stop(
    "Authoritative PC landscape does not have the expected PC1-PC3 names."
  )
}

unimodal_pc_values <- terra::values(
  unimodal_pc_stack,
  mat = TRUE
)

valid_pc_cells <- which(
  apply(
    unimodal_pc_values,
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
    "Authoritative Australian PC1-PC3 landscape contains no complete cells."
  )
}

set.seed(
  landscape_comparison_seed
)

comparison_cells <- sample(
  valid_pc_cells,
  size = min(
    landscape_comparison_n,
    length(
      valid_pc_cells
    )
  ),
  replace = FALSE
)

disconnected_comparison_values <- terra::values(
  disconnected_pc_stack,
  mat = TRUE
)[
  comparison_cells,
  ,
  drop = FALSE
]

unimodal_comparison_values <- unimodal_pc_values[
  comparison_cells,
  ,
  drop = FALSE
]

pc_landscapes_match <- isTRUE(
  all.equal(
    unimodal_comparison_values,
    disconnected_comparison_values,
    tolerance = numeric_tolerance,
    check.attributes = FALSE
  )
)

if (!pc_landscapes_match) {
  stop(
    "The two historical virtual species do not share the same PC1-PC3 values."
  )
}

pca_objects_all_equal <- isTRUE(
  all.equal(
    source_unimodal_truth$pca_object,
    source_disconnected_truth$pca_object,
    tolerance = numeric_tolerance
  )
)

if (!pca_objects_all_equal) {
  warning(
    "The saved PCA objects are not byte-for-byte/all.equal identical, ",
    "but the PC1-PC3 raster values match. The unimodal PCA object will be ",
    "locked as the shared authoritative transformation."
  )
}

if (
  is.null(
    source_environment_archive$australia_boundary
  )
) {
  stop(
    "Historical shared environment archive lacks the Australian boundary."
  )
}

australia_boundary <- as_spatvector_safe(
  source_environment_archive$australia_boundary
)


# ============================================================
# Standardise and validate truth rasters
# ============================================================

unimodal_suitability <- as_spatraster_safe(
  source_unimodal_truth$virtual_species_suitability
)

unimodal_truth_raster <- as_spatraster_safe(
  source_unimodal_truth$truth_raster
)

disconnected_suitability <- as_spatraster_safe(
  source_disconnected_truth$virtual_species_suitability
)

disconnected_truth_raster <- as_spatraster_safe(
  source_disconnected_truth$truth_raster
)

disconnected_mode_raster <- as_spatraster_safe(
  source_disconnected_truth$mode_membership_raster
)

if (
  !raster_geometry_matches(
    unimodal_truth_raster,
    unimodal_pc_stack
  )
) {
  stop(
    "Unimodal truth raster geometry differs from the shared PC landscape."
  )
}

if (
  !raster_geometry_matches(
    disconnected_truth_raster,
    unimodal_pc_stack
  )
) {
  stop(
    "Disconnected truth raster geometry differs from the shared PC landscape."
  )
}

if (
  !raster_geometry_matches(
    disconnected_mode_raster,
    unimodal_pc_stack
  )
) {
  stop(
    "Disconnected mode-membership raster geometry differs from the shared PC landscape."
  )
}

validate_binary_truth(
  unimodal_truth_raster,
  "Unimodal"
)

validate_binary_truth(
  disconnected_truth_raster,
  "Disconnected"
)

disconnected_mode_values <- terra::values(
  disconnected_mode_raster,
  mat = FALSE
)

finite_disconnected_modes <- sort(
  unique(
    disconnected_mode_values[
      is.finite(
        disconnected_mode_values
      )
    ]
  )
)

if (
  !all(
    finite_disconnected_modes %in%
      c(
        0,
        1,
        2
      )
  )
) {
  stop(
    "Disconnected mode-membership raster contains values other than 0, 1 and 2."
  )
}


# ============================================================
# Standardise and validate occurrence archives
# ============================================================

unimodal_occurrences <- canonicalise_occurrence_archive(
  source_unimodal_occurrences,
  "Unimodal"
)

disconnected_occurrences <- canonicalise_occurrence_archive(
  source_disconnected_occurrences,
  "Disconnected"
)

# Archived PC coordinates must equal the shared PC raster at the occurrence
# coordinates. This ensures we are not mixing occurrence samples with a
# different PCA or raster.
unimodal_extracted_pc <- set_pc_names(
  extract_raster_values_at_xy(
    unimodal_pc_stack,
    unimodal_occurrences$occurrence_xy
  )
)

disconnected_extracted_pc <- set_pc_names(
  extract_raster_values_at_xy(
    unimodal_pc_stack,
    disconnected_occurrences$occurrence_xy
  )
)

if (
  !isTRUE(
    all.equal(
      unimodal_extracted_pc,
      unimodal_occurrences$occurrence_pc,
      tolerance = numeric_tolerance,
      check.attributes = FALSE
    )
  )
) {
  stop(
    "Unimodal occurrence PC coordinates do not reproduce from the locked PC raster."
  )
}

if (
  !isTRUE(
    all.equal(
      disconnected_extracted_pc,
      disconnected_occurrences$occurrence_pc,
      tolerance = numeric_tolerance,
      check.attributes = FALSE
    )
  )
) {
  stop(
    "Disconnected occurrence PC coordinates do not reproduce from the locked PC raster."
  )
}

# Every archived occurrence must lie in the corresponding binary truth raster.
unimodal_truth_at_occurrences <- extract_single_raster_value_at_xy(
  unimodal_truth_raster,
  unimodal_occurrences$occurrence_xy
)

disconnected_truth_at_occurrences <- extract_single_raster_value_at_xy(
  disconnected_truth_raster,
  disconnected_occurrences$occurrence_xy
)

if (
  any(
    !is.finite(
      unimodal_truth_at_occurrences
    ) |
      unimodal_truth_at_occurrences != 1
  )
) {
  stop(
    "At least one unimodal occurrence falls outside the known geographic truth."
  )
}

if (
  any(
    !is.finite(
      disconnected_truth_at_occurrences
    ) |
      disconnected_truth_at_occurrences != 1
  )
) {
  stop(
    "At least one disconnected occurrence falls outside the known geographic truth."
  )
}

# The disconnected occurrence mode labels must also reproduce exactly from the
# authoritative mode-membership raster.
disconnected_mode_at_occurrences <- extract_single_raster_value_at_xy(
  disconnected_mode_raster,
  disconnected_occurrences$occurrence_xy
)

expected_disconnected_mode_numeric <- ifelse(
  disconnected_occurrences$occurrence_mode == "A",
  1,
  ifelse(
    disconnected_occurrences$occurrence_mode == "B",
    2,
    NA_real_
  )
)

if (
  any(
    !is.finite(
      expected_disconnected_mode_numeric
    )
  ) ||
    !isTRUE(
      all.equal(
        disconnected_mode_at_occurrences,
        expected_disconnected_mode_numeric,
        tolerance = numeric_tolerance,
        check.attributes = FALSE
      )
    )
) {
  stop(
    "Disconnected occurrence mode labels do not reproduce from the mode-membership raster."
  )
}


# ============================================================
# Derive transparent locked summaries
# ============================================================

summarise_truth <- function(
    species_name,
    truth_raster,
    target_prevalence
) {

  truth_values <- terra::values(
    truth_raster,
    mat = FALSE
  )

  valid <- is.finite(
    truth_values
  )

  occupied <- valid &
    truth_values == 1

  data.frame(
    Species = species_name,
    Species_label = unname(
      species_labels[
        species_name
      ]
    ),
    Target_prevalence = as.numeric(
      target_prevalence
    ),
    Valid_Australian_cells = sum(
      valid
    ),
    Occupied_truth_cells = sum(
      occupied
    ),
    Realised_prevalence = sum(
      occupied
    ) /
      sum(
        valid
      ),
    stringsAsFactors = FALSE
  )
}


truth_summary <- rbind(
  summarise_truth(
    "Unimodal",
    unimodal_truth_raster,
    source_unimodal_truth$target_species_prevalence
  ),
  summarise_truth(
    "Disconnected",
    disconnected_truth_raster,
    source_disconnected_truth$target_species_prevalence
  )
)

rownames(
  truth_summary
) <- NULL

write_csv_safely(
  truth_summary,
  truth_summary_file
)


unimodal_means <- as.numeric(
  source_unimodal_truth$virtual_species_object$details$means
)

unimodal_sds <- as.numeric(
  source_unimodal_truth$virtual_species_object$details$sds
)

if (
  length(unimodal_means) < 3L ||
    length(unimodal_sds) < 3L
) {
  stop(
    "Could not recover the unimodal PC1-PC3 generating means and SDs."
  )
}

unimodal_means <- unimodal_means[
  seq_len(
    3L
  )
]

unimodal_sds <- unimodal_sds[
  seq_len(
    3L
  )
]

disconnected_definition <- source_disconnected_truth$definition

required_definition_names <- c(
  "mode_A_mean",
  "mode_B_mean",
  "mode_sds",
  "selected_sd_fraction",
  "mode_separation_sd_units",
  "truth_radius_sd_units",
  "environmental_gap_width_sd_units",
  "environmental_truth_disconnected",
  "realised_raw_threshold"
)

missing_definition_names <- setdiff(
  required_definition_names,
  names(
    disconnected_definition
  )
)

if (length(missing_definition_names) > 0L) {
  stop(
    "Disconnected generating definition is missing: ",
    paste(
      missing_definition_names,
      collapse = ", "
    )
  )
}


parameter_rows <- list(
  data.frame(
    Species = "Unimodal",
    Parameter = c(
      "mean_PC1",
      "mean_PC2",
      "mean_PC3",
      "sd_PC1",
      "sd_PC2",
      "sd_PC3"
    ),
    Value = c(
      unimodal_means,
      unimodal_sds
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    Species = "Disconnected",
    Parameter = c(
      "mode_A_mean_PC1",
      "mode_A_mean_PC2",
      "mode_A_mean_PC3",
      "mode_B_mean_PC1",
      "mode_B_mean_PC2",
      "mode_B_mean_PC3",
      "mode_sd_PC1",
      "mode_sd_PC2",
      "mode_sd_PC3",
      "selected_sd_fraction",
      "mode_separation_sd_units",
      "truth_radius_sd_units",
      "environmental_gap_width_sd_units",
      "realised_raw_threshold"
    ),
    Value = c(
      as.numeric(
        disconnected_definition$mode_A_mean
      ),
      as.numeric(
        disconnected_definition$mode_B_mean
      ),
      as.numeric(
        disconnected_definition$mode_sds
      ),
      as.numeric(
        disconnected_definition$selected_sd_fraction
      ),
      as.numeric(
        disconnected_definition$mode_separation_sd_units
      ),
      as.numeric(
        disconnected_definition$truth_radius_sd_units
      ),
      as.numeric(
        disconnected_definition$environmental_gap_width_sd_units
      ),
      as.numeric(
        disconnected_definition$realised_raw_threshold
      )
    ),
    stringsAsFactors = FALSE
  )
)

species_parameters <- do.call(
  rbind,
  parameter_rows
)

rownames(
  species_parameters
) <- NULL

write_csv_safely(
  species_parameters,
  species_parameter_file
)


occurrence_summary_rows <- list()
occurrence_summary_index <- 0L

for (species_name in species_order) {

  occurrence_object <- if (
    identical(
      species_name,
      "Unimodal"
    )
  ) {
    unimodal_occurrences
  } else {
    disconnected_occurrences
  }

  for (sample_size in sample_sizes) {

    subset_object <- occurrence_object$subsets[[
      as.character(
        sample_size
      )
    ]]

    occurrence_summary_index <- occurrence_summary_index + 1L

    occurrence_summary_rows[[occurrence_summary_index]] <- data.frame(
      Species = species_name,
      Species_label = unname(
        species_labels[
          species_name
        ]
      ),
      Sample_size = sample_size,
      Occurrence_seed = occurrence_object$occurrence_seed,
      PC_dimensions = ncol(
        subset_object$pc
      ),
      Mode_A_count = if (
        identical(
          species_name,
          "Disconnected"
        )
      ) {
        sum(
          subset_object$true_mode == "A"
        )
      } else {
        NA_integer_
      },
      Mode_B_count = if (
        identical(
          species_name,
          "Disconnected"
        )
      ) {
        sum(
          subset_object$true_mode == "B"
        )
      } else {
        NA_integer_
      },
      stringsAsFactors = FALSE
    )
  }
}

occurrence_summary <- do.call(
  rbind,
  occurrence_summary_rows
)

rownames(
  occurrence_summary
) <- NULL

write_csv_safely(
  occurrence_summary,
  occurrence_summary_file
)


write_csv_safely(
  make_occurrence_export(
    unimodal_occurrences,
    "Unimodal"
  ),
  unimodal_occurrence_csv_file
)

write_csv_safely(
  make_occurrence_export(
    disconnected_occurrences,
    "Disconnected"
  ),
  disconnected_occurrence_csv_file
)


# ============================================================
# Persist path-independent raster copies
# ============================================================

message(
  "Writing locked raster copies..."
)

terra::writeRaster(
  unimodal_pc_stack,
  pc_raster_file,
  overwrite = TRUE,
  wopt = list(
    gdal = c(
      "COMPRESS=LZW"
    )
  )
)

terra::writeRaster(
  unimodal_suitability,
  unimodal_suitability_raster_file,
  overwrite = TRUE,
  wopt = list(
    gdal = c(
      "COMPRESS=LZW"
    )
  )
)

terra::writeRaster(
  unimodal_truth_raster,
  unimodal_truth_raster_file,
  overwrite = TRUE,
  datatype = "INT1U",
  wopt = list(
    gdal = c(
      "COMPRESS=LZW"
    )
  )
)

terra::writeRaster(
  disconnected_suitability,
  disconnected_suitability_raster_file,
  overwrite = TRUE,
  wopt = list(
    gdal = c(
      "COMPRESS=LZW"
    )
  )
)

terra::writeRaster(
  disconnected_truth_raster,
  disconnected_truth_raster_file,
  overwrite = TRUE,
  datatype = "INT1U",
  wopt = list(
    gdal = c(
      "COMPRESS=LZW"
    )
  )
)

terra::writeRaster(
  disconnected_mode_raster,
  disconnected_mode_raster_file,
  overwrite = TRUE,
  datatype = "INT1U",
  wopt = list(
    gdal = c(
      "COMPRESS=LZW"
    )
  )
)


# ============================================================
# Create canonical locked RDS objects
# ============================================================

shared_environment <- list(
  locked_by_script = "12_Virtual_Species_Locked_Inputs.R",
  source_root_directory = source_root_directory,
  worldclim_resolution_minutes = if (
    !is.null(
      source_environment_archive$worldclim_resolution_minutes
    )
  ) {
    source_environment_archive$worldclim_resolution_minutes
  } else {
    2.5
  },
  environmental_source_description = source_environment_archive$source,
  original_environment_variable_names = source_environment_archive$variable_names,
  australia_boundary = terra::wrap(
    australia_boundary
  ),
  pca_object = source_unimodal_truth$pca_object,
  pc_axes = expected_pc_names,
  pc_stack = terra::wrap(
    unimodal_pc_stack,
    proxy = FALSE
  ),
  valid_pc_cells = length(
    valid_pc_cells
  ),
  pc_raster_file = normalizePath(
    pc_raster_file,
    winslash = "/",
    mustWork = TRUE
  )
)

saveRDS(
  shared_environment,
  shared_environment_file,
  version = 3
)


unimodal_truth_locked <- list(
  locked_by_script = "12_Virtual_Species_Locked_Inputs.R",
  species = "Unimodal",
  species_label = unname(
    species_labels[
      "Unimodal"
    ]
  ),
  virtual_species_seed = source_unimodal_truth$virtual_species_seed,
  target_species_prevalence = source_unimodal_truth$target_species_prevalence,
  virtual_species_object = source_unimodal_truth$virtual_species_object,
  virtual_species_pa_object = source_unimodal_truth$virtual_species_pa_object,
  generating_definition = list(
    type = "single Gaussian response in PC1-PC3",
    pc_axes = expected_pc_names,
    means = stats::setNames(
      unimodal_means,
      expected_pc_names
    ),
    sds = stats::setNames(
      unimodal_sds,
      expected_pc_names
    )
  ),
  suitability = terra::wrap(
    unimodal_suitability,
    proxy = FALSE
  ),
  truth_raster = terra::wrap(
    unimodal_truth_raster,
    proxy = FALSE
  ),
  suitability_raster_file = normalizePath(
    unimodal_suitability_raster_file,
    winslash = "/",
    mustWork = TRUE
  ),
  truth_raster_file = normalizePath(
    unimodal_truth_raster_file,
    winslash = "/",
    mustWork = TRUE
  )
)

saveRDS(
  unimodal_truth_locked,
  unimodal_truth_file,
  version = 3
)


disconnected_truth_locked <- list(
  locked_by_script = "12_Virtual_Species_Locked_Inputs.R",
  species = "Disconnected",
  species_label = unname(
    species_labels[
      "Disconnected"
    ]
  ),
  virtual_species_seed = source_disconnected_truth$virtual_species_seed,
  target_species_prevalence = source_disconnected_truth$target_species_prevalence,
  virtual_species_pa_object = source_disconnected_truth$virtual_species_pa_object,
  generating_definition = disconnected_definition,
  suitability = terra::wrap(
    disconnected_suitability,
    proxy = FALSE
  ),
  truth_raster = terra::wrap(
    disconnected_truth_raster,
    proxy = FALSE
  ),
  mode_membership_raster = terra::wrap(
    disconnected_mode_raster,
    proxy = FALSE
  ),
  suitability_raster_file = normalizePath(
    disconnected_suitability_raster_file,
    winslash = "/",
    mustWork = TRUE
  ),
  truth_raster_file = normalizePath(
    disconnected_truth_raster_file,
    winslash = "/",
    mustWork = TRUE
  ),
  mode_membership_raster_file = normalizePath(
    disconnected_mode_raster_file,
    winslash = "/",
    mustWork = TRUE
  )
)

saveRDS(
  disconnected_truth_locked,
  disconnected_truth_file,
  version = 3
)


locked_occurrences <- list(
  locked_by_script = "12_Virtual_Species_Locked_Inputs.R",
  sample_sizes = sample_sizes,
  maximum_sample_size = maximum_sample_size,
  species = list(
    Unimodal = unimodal_occurrences,
    Disconnected = disconnected_occurrences
  )
)

saveRDS(
  locked_occurrences,
  occurrence_archive_file,
  version = 3
)


# ============================================================
# Source and locked-file manifest
# ============================================================

source_manifest_rows <- lapply(
  names(
    source_files
  ),
  function(source_key) {

    source_path <- source_files[[source_key]]

    data.frame(
      File_role = source_key,
      File_stage = "Historical source",
      File_path = normalizePath(
        source_path,
        winslash = "/",
        mustWork = FALSE
      ),
      Exists = file.exists(
        source_path
      ),
      MD5 = safe_md5(
        source_path
      ),
      stringsAsFactors = FALSE
    )
  }
)

locked_files <- list(
  shared_environment = shared_environment_file,
  unimodal_truth = unimodal_truth_file,
  disconnected_truth = disconnected_truth_file,
  occurrences = occurrence_archive_file,
  pc_raster = pc_raster_file,
  unimodal_suitability_raster = unimodal_suitability_raster_file,
  unimodal_truth_raster = unimodal_truth_raster_file,
  disconnected_suitability_raster = disconnected_suitability_raster_file,
  disconnected_truth_raster = disconnected_truth_raster_file,
  disconnected_mode_raster = disconnected_mode_raster_file
)

locked_manifest_rows <- lapply(
  names(
    locked_files
  ),
  function(file_key) {

    file_path <- locked_files[[file_key]]

    data.frame(
      File_role = file_key,
      File_stage = "Locked revised input",
      File_path = normalizePath(
        file_path,
        winslash = "/",
        mustWork = FALSE
      ),
      Exists = file.exists(
        file_path
      ),
      MD5 = safe_md5(
        file_path
      ),
      stringsAsFactors = FALSE
    )
  }
)

input_manifest <- do.call(
  rbind,
  c(
    source_manifest_rows,
    locked_manifest_rows
  )
)

rownames(
  input_manifest
) <- NULL

write_csv_safely(
  input_manifest,
  input_manifest_file
)


# ============================================================
# Validation audit
# ============================================================

validation_audit <- data.frame(
  Check = c(
    "Two species only",
    "Locked sample sizes are 300, 900, 1500",
    "Shared PC raster geometry",
    "Shared PC raster sampled values",
    "Saved PCA objects all.equal",
    "Unimodal truth is binary",
    "Disconnected truth is binary",
    "Unimodal occurrences reproduce from PC raster",
    "Disconnected occurrences reproduce from PC raster",
    "All unimodal occurrences lie in geographic truth",
    "All disconnected occurrences lie in geographic truth",
    "Disconnected occurrence mode labels reproduce from mode raster",
    "Disconnected n=300 balanced 50:50",
    "Disconnected n=900 balanced 50:50",
    "Disconnected n=1500 balanced 50:50"
  ),
  Passed = c(
    identical(
      species_order,
      c(
        "Unimodal",
        "Disconnected"
      )
    ),
    identical(
      sample_sizes,
      c(
        300L,
        900L,
        1500L
      )
    ),
    raster_geometry_matches(
      unimodal_pc_stack,
      disconnected_pc_stack
    ),
    pc_landscapes_match,
    pca_objects_all_equal,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    all(
      unimodal_truth_at_occurrences == 1
    ),
    all(
      disconnected_truth_at_occurrences == 1
    ),
    isTRUE(
      all.equal(
        disconnected_mode_at_occurrences,
        expected_disconnected_mode_numeric,
        tolerance = numeric_tolerance,
        check.attributes = FALSE
      )
    ),
    all(
      table(
        factor(
          disconnected_occurrences$subsets[["300"]]$true_mode,
          levels = c(
            "A",
            "B"
          )
        )
      ) == 150L
    ),
    all(
      table(
        factor(
          disconnected_occurrences$subsets[["900"]]$true_mode,
          levels = c(
            "A",
            "B"
          )
        )
      ) == 450L
    ),
    all(
      table(
        factor(
          disconnected_occurrences$subsets[["1500"]]$true_mode,
          levels = c(
            "A",
            "B"
          )
        )
      ) == 750L
    )
  ),
  stringsAsFactors = FALSE
)

if (
  any(
    !validation_audit$Passed
  )
) {

  failed_checks <- validation_audit$Check[
    !validation_audit$Passed
  ]

  stop(
    "One or more locked-input validation checks failed:\n  ",
    paste(
      failed_checks,
      collapse = "\n  "
    )
  )
}

write_csv_safely(
  validation_audit,
  input_audit_file
)


# ============================================================
# Master archive and settings hash
# ============================================================

locked_design <- list(
  script = "12_Virtual_Species_Locked_Inputs.R",
  species_order = species_order,
  species_labels = species_labels,
  sample_sizes = sample_sizes,
  maximum_sample_size = maximum_sample_size,
  pc_axes = expected_pc_names,
  source_root = normalizePath(
    source_root_directory,
    winslash = "/",
    mustWork = TRUE
  ),
  source_md5 = vapply(
    source_files[
      required_source_keys
    ],
    safe_md5,
    character(1)
  )
)

locked_design_hash <- hash_r_object(
  locked_design
)

locked_input_settings <- list(
  locked_design_hash = locked_design_hash,
  locked_design = locked_design,
  numeric_tolerance = numeric_tolerance,
  landscape_comparison_seed = landscape_comparison_seed,
  landscape_comparison_n = landscape_comparison_n,
  qph_dependency = FALSE,
  note = paste(
    "Truth, PCA, environmental landscape and occurrence samples are",
    "QPH-independent and are reused exactly from the completed virtual-species",
    "experiments."
  )
)

saveRDS(
  locked_input_settings,
  settings_file,
  version = 3
)


master_archive <- list(
  metadata = list(
    script = "12_Virtual_Species_Locked_Inputs.R",
    locked_design_hash = locked_design_hash,
    created = as.character(
      Sys.time()
    ),
    project_directory = normalizePath(
      project_directory,
      winslash = "/",
      mustWork = TRUE
    )
  ),
  shared_environment = shared_environment,
  truth = list(
    Unimodal = unimodal_truth_locked,
    Disconnected = disconnected_truth_locked
  ),
  occurrences = locked_occurrences,
  truth_summary = truth_summary,
  species_parameters = species_parameters,
  occurrence_summary = occurrence_summary,
  validation_audit = validation_audit,
  input_manifest = input_manifest
)

saveRDS(
  master_archive,
  master_archive_file,
  version = 3
)


# ============================================================
# Analysis notes and session information
# ============================================================

analysis_notes <- c(
  "Revised virtual-species locked inputs",
  "====================================",
  "",
  "Species:",
  "  Unimodal Gaussian-PCA",
  "  Disconnected bimodal",
  "",
  "Locked occurrence sample sizes:",
  paste0(
    "  ",
    paste(
      sample_sizes,
      collapse = ", "
    )
  ),
  "",
  "Reused without regeneration:",
  "  Australian PC1-PC3 landscape and PCA transformation",
  "  Australian boundary",
  "  virtual-species generating definitions",
  "  suitability rasters",
  "  binary geographic truth rasters",
  "  disconnected true mode-membership raster",
  "  exact nested occurrence samples",
  "",
  "No QPH, Gaussian KDE or SVM model is fitted in this script.",
  "No geographic projection, geometry calculation or persistent homology is run.",
  "",
  paste0(
    "Locked design hash: ",
    locked_design_hash
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
  "12_Virtual_Species_Locked_Inputs.R complete."
)

message(
  "Species locked: ",
  paste(
    species_order,
    collapse = ", "
  )
)

message(
  "Occurrence sample sizes: ",
  paste(
    sample_sizes,
    collapse = ", "
  )
)

message(
  "Shared valid Australian PC cells: ",
  length(
    valid_pc_cells
  )
)

message(
  "All validation checks passed: ",
  all(
    validation_audit$Passed
  )
)

message(
  "Locked design hash: ",
  locked_design_hash
)

message(
  "Master locked archive:\n  ",
  normalizePath(
    master_archive_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "============================================================"
)
