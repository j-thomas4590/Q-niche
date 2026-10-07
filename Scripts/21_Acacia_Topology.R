# ============================================================
# 21_Acacia_Topology.R
# ============================================================
#
# PURPOSE
# -------
# Persistent-homology analysis for the FIVE locked empirical Acacia species
# using the revised baseline hypervolumes from Script 19.
#


rm(list = ls())
gc()

# ============================================================
# Packages
# ============================================================

required_packages <- c(
  "hypervolume",
  "TDAstats",
  "TDA",
  "R.utils"
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
library(TDAstats)
library(TDA)
library(R.utils)

# ============================================================
# Project paths
# ============================================================

# Run from the repository's root folder.
project_directory <- "."

analysis_root_directory <- file.path(
  project_directory,
  "Results",
  "Acacia_sqrtNB_q099"
)

locked_input_directory <- file.path(
  analysis_root_directory,
  "00_Locked_Inputs"
)

baseline_fit_directory <- file.path(
  analysis_root_directory,
  "01_Baseline_Fits"
)

output_directory <- file.path(
  analysis_root_directory,
  "03_Topology"
)

primary_ph_directory <- file.path(
  output_directory,
  "primary_ph_objects"
)

matched_reference_directory <- file.path(
  output_directory,
  "matched_ellipsoid_objects"
)

table_directory <- file.path(
  output_directory,
  "tables"
)

for (directory in c(
  output_directory,
  primary_ph_directory,
  matched_reference_directory,
  table_directory
)) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}

# ============================================================
# Locked species, methods and colours
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

source_order <- c(
  "Occurrence",
  method_order
)

method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)

occurrence_colour <- "#111111"

source_colours <- c(
  "Occurrence" = occurrence_colour,
  method_colours
)

homology_labels <- c(
  "0" = "H0",
  "1" = "H1",
  "2" = "H2"
)

# ============================================================
# Locked topology settings
# ============================================================

ph_sample_size <- 300L
number_of_repetitions <- 10L
maximum_homology_dimension <- 2L
ph_threshold <- -1
ph_prime_field <- 2L
ph_standardize <- FALSE
ph_timeout_seconds <- 6 * 60
number_of_null_replicates <- 20L
topology_master_seed <- 93001L
null_master_seed <- 103001L
resume_from_checkpoint <- TRUE
retry_failed_persistence <- TRUE
retry_incomplete_nulls <- TRUE

# ============================================================
# Upstream files
# ============================================================

locked_archive_file <- file.path(
  locked_input_directory,
  "acacia_empirical_inputs_authoritative_LOCKED.rds"
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
  baseline_fit_directory,
  "acacia_baseline_fits_sqrtNB_q099.rds"
)

required_upstream_files <- c(
  locked_archive_file,
  locked_settings_file,
  baseline_settings_file,
  baseline_results_file
)

missing_upstream_files <- required_upstream_files[
  !file.exists(required_upstream_files)
]

if (length(missing_upstream_files) > 0L) {
  stop(
    "Missing required upstream file(s):\n  ",
    paste(
      missing_upstream_files,
      collapse = "\n  "
    ),
    "\nScripts 18 and 19 must finish successfully before Script 21."
  )
}

# ============================================================
# Output files
# ============================================================

analysis_settings_file <- file.path(
  output_directory,
  "analysis_settings.rds"
)

subsample_archive_file <- file.path(
  output_directory,
  "acacia_topology_subsample_indices.rds"
)

persistence_diagrams_file <- file.path(
  output_directory,
  "acacia_primary_persistence_diagrams.rds"
)

ph_log_file <- file.path(
  table_directory,
  "acacia_primary_PH_log.csv"
)

persistence_replicate_file <- file.path(
  table_directory,
  "acacia_maximum_persistence_replicates.csv"
)

persistence_summary_file <- file.path(
  table_directory,
  "acacia_maximum_persistence_mean_sd.csv"
)

bottleneck_replicate_file <- file.path(
  table_directory,
  "acacia_bottleneck_replicates.csv"
)

bottleneck_summary_file <- file.path(
  table_directory,
  "acacia_bottleneck_mean_sd.csv"
)

null_replicate_file <- file.path(
  table_directory,
  "acacia_matched_ellipsoid_replicates.csv"
)

null_threshold_file <- file.path(
  table_directory,
  "acacia_matched_ellipsoid_thresholds.csv"
)

null_observed_file <- file.path(
  table_directory,
  "acacia_matched_ellipsoid_observed_results.csv"
)

null_summary_file <- file.path(
  table_directory,
  "acacia_matched_ellipsoid_exceedance_summary.csv"
)

paired_classification_file <- file.path(
  table_directory,
  "acacia_paired_exceedance_classification_replicates.csv"
)

paired_summary_file <- file.path(
  table_directory,
  "acacia_paired_exceedance_classification_summary.csv"
)

input_qa_file <- file.path(
  table_directory,
  "acacia_topology_input_QA.csv"
)

failure_file <- file.path(
  table_directory,
  "acacia_topology_failures.csv"
)

run_metadata_file <- file.path(
  output_directory,
  "acacia_topology_metadata.rds"
)

final_results_file <- file.path(
  output_directory,
  "acacia_topology_sqrtNB_q099.rds"
)

analysis_notes_file <- file.path(
  output_directory,
  "ACACIA_TOPOLOGY_NOTES.txt"
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

source_code <- function(source_name) {
  if (identical(source_name, "Occurrence")) {
    return("occurrence")
  }
  method_code(
    source_name
  )
}

model_key <- function(
    species_name,
    method_name
) {
  paste(
    species_code(
      species_name
    ),
    method_code(
      method_name
    ),
    sep = "__"
  )
}

model_file_path <- function(
    species_name,
    method_name
) {
  file.path(
    baseline_fit_directory,
    "model_objects",
    paste0(
      model_key(
        species_name,
        method_name
      ),
      ".rds"
    )
  )
}

set_axis_names <- function(
    x,
    object_name = "point cloud"
) {
  x <- as.matrix(x)
  storage.mode(x) <- "double"

  if (nrow(x) < 1L) {
    stop(
      object_name,
      " has no rows."
    )
  }

  if (ncol(x) != 3L) {
    stop(
      object_name,
      " must have exactly three columns."
    )
  }

  if (any(!is.finite(x))) {
    stop(
      object_name,
      " contains non-finite values."
    )
  }

  colnames(x) <- expected_pc_names
  x
}

validate_source_points <- function(
    x,
    object_name
) {
  x <- set_axis_names(
    x,
    object_name
  )

  if (
    nrow(x) <
      ph_sample_size
  ) {
    stop(
      object_name,
      " contains only ",
      nrow(x),
      " points; at least ",
      ph_sample_size,
      " are required by the locked topology protocol."
    )
  }

  x
}

point_cloud_diameter <- function(points) {
  points <- set_axis_names(
    points
  )
  if (nrow(points) < 2L) {
    return(NA_real_)
  }
  max(
    stats::dist(
      points
    )
  )
}

safe_mean <- function(x) {
  x <- x[
    is.finite(
      x
    )
  ]
  if (length(x) == 0L) {
    return(NA_real_)
  }
  mean(x)
}

safe_sd <- function(x) {
  x <- x[
    is.finite(
      x
    )
  ]
  if (length(x) < 2L) {
    return(NA_real_)
  }
  stats::sd(x)
}

safe_max <- function(x) {
  x <- x[
    is.finite(
      x
    )
  ]
  if (length(x) == 0L) {
    return(NA_real_)
  }
  max(x)
}

# ============================================================
# Load and validate Scripts 18-19
# ============================================================

locked_inputs <- readRDS(
  locked_archive_file
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
baseline_analysis_hash <- baseline_settings_wrapper$analysis_settings_hash

if (
  is.null(locked_design_hash) ||
    is.null(baseline_analysis_hash)
) {
  stop(
    "Required Script-18/19 provenance hashes are missing."
  )
}

if (
  !identical(
    baseline_settings_wrapper$settings$locked_design_hash,
    locked_design_hash
  )
) {
  stop(
    "Script-19 settings do not correspond to the current Script-18 inputs."
  )
}

if (
  !identical(
    baseline_results$metadata$locked_design_hash,
    locked_design_hash
  ) ||
    !identical(
      baseline_results$metadata$analysis_settings_hash,
      baseline_analysis_hash
    )
) {
  stop(
    "Script-19 final object does not correspond to the current locked inputs."
  )
}

if (
  baseline_results$metadata$model_count_successful !=
    15L ||
    baseline_results$metadata$model_count_failed !=
      0L
) {
  stop(
    "Script 21 requires all 15 Script-19 baseline model fits to have succeeded."
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
    "Locked species order differs from the Script-21 design."
  )
}

# ============================================================
# Load and validate source point clouds
# ============================================================

species_matrices <- locked_inputs$species_pca_matrices

if (
  is.null(species_matrices) ||
    !identical(
      names(species_matrices),
      expected_species
    )
) {
  stop(
    "Locked species PC matrices are missing or out of order."
  )
}

for (
  species_name in expected_species
) {
  species_matrices[[species_name]] <- validate_source_points(
    species_matrices[[species_name]],
    paste0(
      species_name,
      " occurrence cloud"
    )
  )
}

model_bundle_cache <- new.env(
  parent = emptyenv()
)

get_model_bundle <- function(
    species_name,
    method_name
) {
  current_key <- model_key(
    species_name,
    method_name
  )

  if (
    exists(
      current_key,
      envir = model_bundle_cache,
      inherits = FALSE
    )
  ) {
    return(
      get(
        current_key,
        envir = model_bundle_cache,
        inherits = FALSE
      )
    )
  }

  current_file <- model_file_path(
    species_name,
    method_name
  )

  if (!file.exists(current_file)) {
    stop(
      "Missing baseline model object:\n  ",
      current_file
    )
  }

  bundle <- readRDS(
    current_file
  )

  if (
    !identical(
      bundle$metadata$species,
      species_name
    ) ||
      !identical(
        bundle$metadata$method,
        method_name
      ) ||
      !identical(
        bundle$metadata$locked_design_hash,
        locked_design_hash
      ) ||
      !identical(
        bundle$metadata$analysis_settings_hash,
        baseline_analysis_hash
      )
  ) {
    stop(
      "Model provenance mismatch for ",
      species_name,
      " / ",
      method_name,
      "."
    )
  }

  if (!methods::is(bundle$hypervolume, "Hypervolume")) {
    stop(
      "Saved model bundle lacks a valid Hypervolume object for ",
      species_name,
      " / ",
      method_name,
      "."
    )
  }

  methods::validObject(
    bundle$hypervolume
  )

  assign(
    current_key,
    bundle,
    envir = model_bundle_cache
  )

  bundle
}

get_source_points <- function(
    species_name,
    source_name
) {
  if (
    identical(
      source_name,
      "Occurrence"
    )
  ) {
    return(
      validate_source_points(
        species_matrices[[species_name]],
        paste0(
          species_name,
          " / Occurrence"
        )
      )
    )
  }

  bundle <- get_model_bundle(
    species_name,
    source_name
  )

  validate_source_points(
    bundle$hypervolume@RandomPoints,
    paste0(
      species_name,
      " / ",
      source_name
    )
  )
}

# ============================================================
# Method-specific baseline QA and source counts
# ============================================================

input_qa_rows <- list()
input_qa_index <- 0L
model_file_md5 <- character(0)

for (
  species_name in expected_species
) {
  for (
    source_name in source_order
  ) {
    points <- get_source_points(
      species_name,
      source_name
    )

    parameter_check <- TRUE
    parameter_note <- "Occurrence cloud"

    if (!identical(source_name, "Occurrence")) {
      bundle <- get_model_bundle(
        species_name,
        source_name
      )

      current_model_file <- model_file_path(
        species_name,
        source_name
      )

      model_file_md5[[
        model_key(
          species_name,
          source_name
        )
      ]] <- safe_md5(
        current_model_file
      )

      if (identical(source_name, "QPH")) {
        audit <- bundle$qph_result$audit

        parameter_check <- (
          isTRUE(
            all.equal(
              audit$q,
              0.99,
              tolerance = 1e-12
            )
          ) &&
            isTRUE(
              audit$fitted_isotropic
            ) &&
            audit$K ==
              round(
                sqrt(
                  nrow(
                    species_matrices[[
                      species_name
                    ]]
                  )
                )
              )
        )

        parameter_note <- (
          "revised sqrt-NB isotropic QPH; q=0.99"
        )
      } else if (
        identical(
          source_name,
          "Gaussian KDE"
        )
      ) {
        parameter_check <- (
          identical(
            bundle$projection_model$bandwidth_method,
            "Silverman"
          ) &&
            isTRUE(
              all.equal(
                bundle$projection_model$quantile_requested,
                0.95,
                tolerance = 1e-12
              )
            )
        )

        parameter_note <- (
          "independent Silverman KDE; probability quantile=0.95"
        )
      } else {
        parameter_check <- (
          isTRUE(
            all.equal(
              bundle$projection_model$svm_nu,
              0.01,
              tolerance = 1e-12
            )
          ) &&
            isTRUE(
              all.equal(
                bundle$projection_model$svm_gamma,
                0.50,
                tolerance = 1e-12
              )
            )
          )

        parameter_note <- (
          "one-class radial SVM; nu=0.01; gamma=0.50"
        )
      }

      if (!isTRUE(parameter_check)) {
        stop(
          "Baseline parameter QA failed for ",
          species_name,
          " / ",
          source_name,
          "."
        )
      }
    }

    input_qa_index <- input_qa_index + 1L

    input_qa_rows[[
      input_qa_index
    ]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Source = source_name,
      Full_source_point_count = nrow(
        points
      ),
      Dimensionality = ncol(
        points
      ),
      Parameter_check = parameter_check,
      Parameter_note = parameter_note,
      Full_source_centroid_PC1 = mean(
        points[
          ,
          "PC1"
        ]
      ),
      Full_source_centroid_PC2 = mean(
        points[
          ,
          "PC2"
        ]
      ),
      Full_source_centroid_PC3 = mean(
        points[
          ,
          "PC3"
        ]
      ),
      stringsAsFactors = FALSE
    )
  }
}

input_qa <- do.call(
  rbind,
  input_qa_rows
)

write_csv_safely(
  input_qa,
  input_qa_file
)

# ============================================================
# Package capabilities and analysis settings hash
# ============================================================

installed_tda_stats_version <- as.character(
  utils::packageVersion(
    "TDAstats"
  )
)

installed_tda_version <- as.character(
  utils::packageVersion(
    "TDA"
  )
)

installed_rutils_version <- as.character(
  utils::packageVersion(
    "R.utils"
  )
)

tda_calculate_homology_formals <- names(
  formals(
    TDAstats::calculate_homology
  )
)

tda_supports_prime_field <- (
  "p" %in%
    tda_calculate_homology_formals
)

tda_supports_standardize <- (
  "standardize" %in%
    tda_calculate_homology_formals
)

tda_supports_return_df <- (
  "return_df" %in%
    tda_calculate_homology_formals
)

analysis_settings <- list(
  script = "21_Acacia_Topology.R",
  analysis_branch = "Acacia_sqrtNB_q099",
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  model_file_md5 = model_file_md5,
  species = expected_species,
  sources = source_order,
  ph_sample_size = ph_sample_size,
  number_of_repetitions = number_of_repetitions,
  maximum_homology_dimension = maximum_homology_dimension,
  ph_threshold = ph_threshold,
  ph_prime_field = ph_prime_field,
  ph_standardize = ph_standardize,
  ph_timeout_seconds = ph_timeout_seconds,
  number_of_null_replicates = number_of_null_replicates,
  matched_reference_protocol = paste(
    "20 source-level matched filled ellipsoids per species x source,",
    "each n=300, matching full source centroid/covariance;",
    "one complete source-specific threshold shared across 10 observed repetitions"
  ),
  topology_master_seed = topology_master_seed,
  null_master_seed = null_master_seed,
  tda_stats_version = installed_tda_stats_version,
  tda_version = installed_tda_version,
  rutils_version = installed_rutils_version,
  tda_supports_prime_field = tda_supports_prime_field,
  tda_supports_standardize = tda_supports_standardize,
  tda_supports_return_df = tda_supports_return_df
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

if (file.exists(analysis_settings_file)) {
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
      "Existing Script-21 outputs were created with different inputs, model ",
      "files, package versions or topology settings. Archive/remove ",
      "03_Topology before starting the current analysis."
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
# Lock exact 300-point subsample indices
# ============================================================

create_subsample_archive <- function() {
  archive <- list(
    metadata = list(
      analysis_settings_hash = analysis_settings_hash,
      ph_sample_size = ph_sample_size,
      number_of_repetitions = number_of_repetitions,
      created_at = as.character(
        Sys.time()
      )
    ),
    indices = list()
  )

  for (
    species_index in seq_along(
      expected_species
    )
  ) {
    species_name <- expected_species[[
      species_index
    ]]

    species_key <- species_code(
      species_name
    )

    archive$indices[[species_key]] <- list()

    for (
      repetition in seq_len(
        number_of_repetitions
      )
    ) {
      repetition_key <- as.character(
        repetition
      )

      archive$indices[[species_key]][[
        repetition_key
      ]] <- list()

      for (
        source_index in seq_along(
          source_order
        )
      ) {
        source_name <- source_order[[
          source_index
        ]]

        source_points <- get_source_points(
          species_name,
          source_name
        )

        current_seed <- as.integer(
          topology_master_seed +
            species_index *
              100000L +
            repetition *
              1000L +
            source_index *
              10L
        )

        set.seed(
          current_seed
        )

        selected_indices <- sample.int(
          n = nrow(
            source_points
          ),
          size = ph_sample_size,
          replace = FALSE
        )

        archive$indices[[species_key]][[
          repetition_key
        ]][[source_name]] <- list(
          selected_row_indices = as.integer(
            selected_indices
          ),
          source_point_count = nrow(
            source_points
          ),
          seed = current_seed
        )
      }
    }
  }

  archive
}

validate_subsample_archive <- function(archive) {
  if (
    !is.list(
      archive
    ) ||
      !all(
        c(
          "metadata",
          "indices"
        ) %in%
          names(
            archive
          )
      )
  ) {
    stop(
      "Topology subsample archive has an unexpected structure."
    )
  }

  if (
    !identical(
      archive$metadata$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Existing topology subsample archive was created from different ",
      "inputs or settings."
    )
  }

  for (
    species_name in expected_species
  ) {
    species_key <- species_code(
      species_name
    )

    if (
      is.null(
        archive$indices[[
          species_key
        ]]
      )
    ) {
      stop(
        "Subsample archive is missing species ",
        species_name,
        "."
      )
    }

    for (
      repetition in seq_len(
        number_of_repetitions
      )
    ) {
      repetition_entry <- archive$indices[[
        species_key
      ]][[
        as.character(
          repetition
        )
      ]]

      if (is.null(repetition_entry)) {
        stop(
          "Subsample archive is missing repetition ",
          repetition,
          " for ",
          species_name,
          "."
        )
      }

      for (
        source_name in source_order
      ) {
        source_entry <- repetition_entry[[
          source_name
        ]]

        if (is.null(source_entry)) {
          stop(
            "Subsample archive is missing source ",
            source_name,
            " for ",
            species_name,
            " repetition ",
            repetition,
            "."
          )
        }

        selected_indices <- as.integer(
          source_entry$selected_row_indices
        )

        source_points <- get_source_points(
          species_name,
          source_name
        )

        if (
          length(
            selected_indices
          ) !=
            ph_sample_size
        ) {
          stop(
            "Saved PH subsample does not contain exactly 300 indices."
          )
        }

        if (anyDuplicated(selected_indices)) {
          stop(
            "Saved PH subsample contains duplicate indices."
          )
        }

        if (
          any(
            selected_indices <
              1L
          ) ||
            any(
              selected_indices >
                nrow(
                  source_points
                )
            )
        ) {
          stop(
            "Saved PH subsample contains invalid row indices."
          )
        }

        if (
          source_entry$source_point_count !=
            nrow(
              source_points
            )
        ) {
          stop(
            "Saved PH subsample source-point count no longer matches ",
            species_name,
            " / ",
            source_name,
            "."
          )
        }
      }
    }
  }

  invisible(TRUE)
}

if (
  file.exists(
    subsample_archive_file
  )
) {
  message(
    "Loading locked Acacia topology subsample indices..."
  )

  subsample_archive <- readRDS(
    subsample_archive_file
  )

  validate_subsample_archive(
    subsample_archive
  )
} else {
  message(
    "Creating and locking exact Acacia topology subsample indices..."
  )

  subsample_archive <- create_subsample_archive()

  validate_subsample_archive(
    subsample_archive
  )

  saveRDS(
    subsample_archive,
    subsample_archive_file,
    version = 3
  )
}

get_subsample_points <- function(
    species_name,
    repetition,
    source_name
) {
  source_points <- get_source_points(
    species_name,
    source_name
  )

  selected_indices <- subsample_archive$indices[[
    species_code(
      species_name
    )
  ]][[
    as.character(
      repetition
    )
  ]][[
    source_name
  ]]$selected_row_indices

  source_points[
    selected_indices,
    ,
    drop = FALSE
  ]
}

# ============================================================
# Persistence-diagram helpers
# ============================================================

empty_diagram <- function() {
  matrix(
    numeric(0),
    nrow = 0L,
    ncol = 3L,
    dimnames = list(
      NULL,
      c(
        "dimension",
        "birth",
        "death"
      )
    )
  )
}

standardize_diagram <- function(diagram) {
  diagram <- as.matrix(
    diagram
  )

  storage.mode(
    diagram
  ) <- "double"

  if (length(diagram) == 0L) {
    return(
      empty_diagram()
    )
  }

  if (ncol(diagram) != 3L) {
    stop(
      "Persistence diagram must contain exactly three columns."
    )
  }

  colnames(
    diagram
  ) <- c(
    "dimension",
    "birth",
    "death"
  )

  diagram
}

finite_diagram <- function(diagram) {
  diagram <- standardize_diagram(
    diagram
  )

  if (nrow(diagram) == 0L) {
    return(diagram)
  }

  diagram[
    is.finite(
      diagram[
        ,
        "birth"
      ]
    ) &
      is.finite(
        diagram[
          ,
          "death"
        ]
      ),
    ,
    drop = FALSE
  ]
}

max_finite_persistence <- function(
    diagram,
    dimension
) {
  diagram <- finite_diagram(
    diagram
  )

  dimension_rows <- diagram[
    diagram[
      ,
      "dimension"
    ] ==
      dimension,
    ,
    drop = FALSE
  ]

  if (nrow(dimension_rows) == 0L) {
    return(0)
  }

  persistence <- (
    dimension_rows[
      ,
      "death"
    ] -
      dimension_rows[
        ,
        "birth"
      ]
  )

  persistence <- persistence[
    is.finite(
      persistence
    ) &
      persistence >=
        0
  ]

  if (length(persistence) == 0L) {
    return(0)
  }

  max(persistence)
}

calculate_persistence_with_timeout <- function(
    points,
    maximum_dimension = maximum_homology_dimension
) {
  points <- set_axis_names(
    points
  )

  start_time <- proc.time()[[
    "elapsed"
  ]]

  result <- tryCatch(
    {
      homology_arguments <- list(
        mat = points,
        dim = maximum_dimension,
        threshold = ph_threshold,
        format = "cloud"
      )

      if (tda_supports_standardize) {
        homology_arguments$standardize <- ph_standardize
      }

      if (tda_supports_return_df) {
        homology_arguments$return_df <- FALSE
      }

      if (tda_supports_prime_field) {
        homology_arguments$p <- ph_prime_field
      }

      diagram <- R.utils::withTimeout(
        do.call(
          TDAstats::calculate_homology,
          homology_arguments
        ),
        timeout = ph_timeout_seconds,
        onTimeout = "error"
      )

      list(
        success = TRUE,
        diagram = standardize_diagram(
          diagram
        ),
        runtime_seconds = (
          proc.time()[[
            "elapsed"
          ]] -
            start_time
        ),
        failure_type = NA_character_,
        error_message = NA_character_,
        prime_field_requested = ph_prime_field,
        prime_field_argument_used = tda_supports_prime_field,
        standardize_argument_used = tda_supports_standardize
      )
    },
    TimeoutException = function(error_condition) {
      list(
        success = FALSE,
        diagram = empty_diagram(),
        runtime_seconds = (
          proc.time()[[
            "elapsed"
          ]] -
            start_time
        ),
        failure_type = "computational-limit failure",
        error_message = conditionMessage(
          error_condition
        ),
        prime_field_requested = ph_prime_field,
        prime_field_argument_used = tda_supports_prime_field,
        standardize_argument_used = tda_supports_standardize
      )
    },
    error = function(error_condition) {
      error_text <- conditionMessage(
        error_condition
      )

      is_timeout <- grepl(
        "time limit|timeout|reached elapsed",
        error_text,
        ignore.case = TRUE
      )

      list(
        success = FALSE,
        diagram = empty_diagram(),
        runtime_seconds = (
          proc.time()[[
            "elapsed"
          ]] -
            start_time
        ),
        failure_type = if (
          is_timeout
        ) {
          "computational-limit failure"
        } else {
          "calculation failure"
        },
        error_message = error_text,
        prime_field_requested = ph_prime_field,
        prime_field_argument_used = tda_supports_prime_field,
        standardize_argument_used = tda_supports_standardize
      )
    }
  )

  result
}

calculate_bottleneck_safe <- function(
    occurrence_diagram,
    method_diagram,
    dimension
) {
  occurrence_diagram <- finite_diagram(
    occurrence_diagram
  )

  method_diagram <- finite_diagram(
    method_diagram
  )

  tryCatch(
    {
      value <- TDA::bottleneck(
        Diag1 = occurrence_diagram,
        Diag2 = method_diagram,
        dimension = dimension
      )

      value <- as.numeric(
        value
      )

      if (
        length(
          value
        ) !=
          1L ||
          !is.finite(
            value
          )
      ) {
        stop(
          "TDA::bottleneck returned a non-finite or non-scalar distance."
        )
      }

      list(
        success = TRUE,
        distance = value,
        error_message = NA_character_
      )
    },
    error = function(error_condition) {
      list(
        success = FALSE,
        distance = NA_real_,
        error_message = conditionMessage(
          error_condition
        )
      )
    }
  )
}

# ============================================================
# Primary PH paths
# ============================================================

persistence_key <- function(
    species_name,
    repetition,
    source_name
) {
  paste(
    species_code(
      species_name
    ),
    paste0(
      "rep",
      repetition
    ),
    source_code(
      source_name
    ),
    sep = "__"
  )
}

persistence_file_path <- function(
    species_name,
    repetition,
    source_name
) {
  file.path(
    primary_ph_directory,
    paste0(
      persistence_key(
        species_name,
        repetition,
        source_name
      ),
      ".rds"
    )
  )
}

# ============================================================
# Calculate / resume 200 primary PH analyses
# ============================================================

message(
  "\nBeginning Acacia primary persistent-homology calculations..."
)

persistence_results <- list()

primary_total <- (
  length(
    expected_species
  ) *
    number_of_repetitions *
    length(
      source_order
    )
)

primary_counter <- 0L

for (
  species_name in expected_species
) {
  for (
    repetition in seq_len(
      number_of_repetitions
    )
  ) {
    for (
      source_name in source_order
    ) {
      primary_counter <- primary_counter + 1L

      current_key <- persistence_key(
        species_name,
        repetition,
        source_name
      )

      current_file <- persistence_file_path(
        species_name,
        repetition,
        source_name
      )

      if (
        resume_from_checkpoint &&
          file.exists(
            current_file
          )
      ) {
        existing_result <- readRDS(
          current_file
        )

        compatible <- (
          identical(
            existing_result$analysis_settings_hash,
            analysis_settings_hash
          ) &&
            identical(
              existing_result$key,
              current_key
            )
        )

        if (compatible) {
          if (
            isTRUE(
              existing_result$success
            ) ||
              !retry_failed_persistence
          ) {
            persistence_results[[
              current_key
            ]] <- existing_result

            message(
              "Skipping PH ",
              primary_counter,
              "/",
              primary_total,
              ": ",
              current_key
            )

            next
          }
        } else {
          stop(
            "Existing primary PH object is incompatible:\n  ",
            current_file
          )
        }
      }

      message(
        "PH ",
        primary_counter,
        "/",
        primary_total,
        ": ",
        current_key
      )

      current_points <- get_subsample_points(
        species_name = species_name,
        repetition = repetition,
        source_name = source_name
      )

      current_diameter <- point_cloud_diameter(
        current_points
      )

      current_seed <- subsample_archive$indices[[
        species_code(
          species_name
        )
      ]][[
        as.character(
          repetition
        )
      ]][[
        source_name
      ]]$seed

      ph_result <- calculate_persistence_with_timeout(
        current_points,
        maximum_dimension = maximum_homology_dimension
      )

      saved_result <- c(
        list(
          analysis_settings_hash = analysis_settings_hash,
          key = current_key,
          species = species_name,
          species_code = species_code(
            species_name
          ),
          repetition = repetition,
          source = source_name,
          sample_size = ph_sample_size,
          subsample_seed = current_seed,
          selected_row_indices = subsample_archive$indices[[
            species_code(
              species_name
            )
          ]][[
            as.character(
              repetition
            )
          ]][[
            source_name
          ]]$selected_row_indices,
          point_cloud_diameter = current_diameter
        ),
        ph_result
      )

      saveRDS(
        saved_result,
        current_file,
        version = 3
      )

      persistence_results[[
        current_key
      ]] <- saved_result

      gc()
    }
  }
}

saveRDS(
  persistence_results,
  persistence_diagrams_file,
  version = 3
)

# ============================================================
# Primary PH log and maximum persistence table
# ============================================================

ph_log_rows <- lapply(
  persistence_results,
  function(result) {
    data.frame(
      Key = result$key,
      Species = result$species,
      Species_code = result$species_code,
      Repetition = result$repetition,
      Source = result$source,
      Sample_size = result$sample_size,
      Success = result$success,
      Runtime_seconds = result$runtime_seconds,
      Point_cloud_diameter = result$point_cloud_diameter,
      Subsample_seed = result$subsample_seed,
      Failure_type = result$failure_type,
      Error_message = result$error_message,
      Prime_field_requested = result$prime_field_requested,
      Prime_field_argument_used = result$prime_field_argument_used,
      Standardize_argument_used = result$standardize_argument_used,
      stringsAsFactors = FALSE
    )
  }
)

ph_log <- do.call(
  rbind,
  ph_log_rows
)

rownames(
  ph_log
) <- NULL

write_csv_safely(
  ph_log,
  ph_log_file
)

persistence_rows <- list()
persistence_index <- 0L

for (
  current_result in persistence_results
) {
  for (
    dimension in 0:
      maximum_homology_dimension
  ) {
    persistence_index <- persistence_index + 1L

    maximum_value <- if (
      isTRUE(
        current_result$success
      )
    ) {
      max_finite_persistence(
        current_result$diagram,
        dimension
      )
    } else {
      NA_real_
    }

    persistence_rows[[
      persistence_index
    ]] <- data.frame(
      Species = current_result$species,
      Species_code = current_result$species_code,
      Repetition = current_result$repetition,
      Source = current_result$source,
      Homology_dimension = dimension,
      Homology_label = unname(
        homology_labels[[
          as.character(
            dimension
          )
        ]]
      ),
      PH_success = current_result$success,
      Maximum_finite_persistence = maximum_value,
      Point_cloud_diameter = current_result$point_cloud_diameter,
      Normalized_maximum_persistence = if (
        isTRUE(
          current_result$success
        ) &&
          is.finite(
            current_result$point_cloud_diameter
          ) &&
          current_result$point_cloud_diameter >
            0
      ) {
        maximum_value /
          current_result$point_cloud_diameter
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }
}

persistence_replicates <- do.call(
  rbind,
  persistence_rows
)

write_csv_safely(
  persistence_replicates,
  persistence_replicate_file
)

# ============================================================
# Persistence mean / SD summaries
# ============================================================

persistence_summary_rows <- list()
persistence_summary_index <- 0L

for (
  species_name in expected_species
) {
  for (
    source_name in source_order
  ) {
    for (
      dimension in 0:
        maximum_homology_dimension
    ) {
      group <- persistence_replicates[
        persistence_replicates$Species ==
          species_name &
          persistence_replicates$Source ==
            source_name &
          persistence_replicates$Homology_dimension ==
            dimension &
          persistence_replicates$PH_success,
        ,
        drop = FALSE
      ]

      persistence_summary_index <- (
        persistence_summary_index +
          1L
      )

      persistence_summary_rows[[
        persistence_summary_index
      ]] <- data.frame(
        Species = species_name,
        Species_code = species_code(
          species_name
        ),
        Source = source_name,
        Homology_dimension = dimension,
        Homology_label = unname(
          homology_labels[[
            as.character(
              dimension
            )
          ]]
        ),
        Repetitions_requested = number_of_repetitions,
        Repetitions_successful = nrow(
          group
        ),
        Mean_maximum_persistence = safe_mean(
          group$Maximum_finite_persistence
        ),
        SD_maximum_persistence = safe_sd(
          group$Maximum_finite_persistence
        ),
        Mean_normalized_maximum_persistence = safe_mean(
          group$Normalized_maximum_persistence
        ),
        SD_normalized_maximum_persistence = safe_sd(
          group$Normalized_maximum_persistence
        ),
        stringsAsFactors = FALSE
      )
    }
  }
}

persistence_summary <- do.call(
  rbind,
  persistence_summary_rows
)

write_csv_safely(
  persistence_summary,
  persistence_summary_file
)

# ============================================================
# Paired occurrence-to-estimator bottleneck distances
# ============================================================

message(
  "\nCalculating paired occurrence-to-estimator bottleneck distances..."
)

bottleneck_rows <- list()
bottleneck_index <- 0L

for (
  species_name in expected_species
) {
  for (
    repetition in seq_len(
      number_of_repetitions
    )
  ) {
    occurrence_result <- persistence_results[[
      persistence_key(
        species_name,
        repetition,
        "Occurrence"
      )
    ]]

    for (
      method_name in method_order
    ) {
      method_result <- persistence_results[[
        persistence_key(
          species_name,
          repetition,
          method_name
        )
      ]]

      for (
        dimension in 0:
          maximum_homology_dimension
      ) {
        bottleneck_index <- bottleneck_index + 1L

        if (
          !isTRUE(
            occurrence_result$success
          ) ||
            !isTRUE(
              method_result$success
            )
        ) {
          bottleneck_rows[[
            bottleneck_index
          ]] <- data.frame(
            Species = species_name,
            Species_code = species_code(
              species_name
            ),
            Repetition = repetition,
            Method = method_name,
            Homology_dimension = dimension,
            Homology_label = unname(
              homology_labels[[
                as.character(
                  dimension
                )
              ]]
            ),
            Success = FALSE,
            Bottleneck_distance = NA_real_,
            Occurrence_diameter = occurrence_result$point_cloud_diameter,
            Normalized_bottleneck_distance = NA_real_,
            Error_message = paste(
              na.omit(
                c(
                  occurrence_result$error_message,
                  method_result$error_message
                )
              ),
              collapse = " | "
            ),
            stringsAsFactors = FALSE
          )

          next
        }

        bottleneck_result <- calculate_bottleneck_safe(
          occurrence_diagram = occurrence_result$diagram,
          method_diagram = method_result$diagram,
          dimension = dimension
        )

        occurrence_diameter <- occurrence_result$point_cloud_diameter

        normalized_distance <- if (
          isTRUE(
            bottleneck_result$success
          ) &&
            is.finite(
              occurrence_diameter
            ) &&
            occurrence_diameter >
              0
        ) {
          bottleneck_result$distance /
            occurrence_diameter
        } else {
          NA_real_
        }

        bottleneck_rows[[
          bottleneck_index
        ]] <- data.frame(
          Species = species_name,
          Species_code = species_code(
            species_name
          ),
          Repetition = repetition,
          Method = method_name,
          Homology_dimension = dimension,
          Homology_label = unname(
            homology_labels[[
              as.character(
                dimension
              )
            ]]
          ),
          Success = bottleneck_result$success,
          Bottleneck_distance = bottleneck_result$distance,
          Occurrence_diameter = occurrence_diameter,
          Normalized_bottleneck_distance = normalized_distance,
          Error_message = bottleneck_result$error_message,
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

bottleneck_replicates <- do.call(
  rbind,
  bottleneck_rows
)

write_csv_safely(
  bottleneck_replicates,
  bottleneck_replicate_file
)

bottleneck_summary_rows <- list()
bottleneck_summary_index <- 0L

for (
  species_name in expected_species
) {
  for (
    method_name in method_order
  ) {
    for (
      dimension in 0:
        maximum_homology_dimension
    ) {
      group <- bottleneck_replicates[
        bottleneck_replicates$Species ==
          species_name &
          bottleneck_replicates$Method ==
            method_name &
          bottleneck_replicates$Homology_dimension ==
            dimension,
        ,
        drop = FALSE
      ]

      successful <- group[
        group$Success &
          is.finite(
            group$Normalized_bottleneck_distance
          ),
        ,
        drop = FALSE
      ]

      bottleneck_summary_index <- (
        bottleneck_summary_index +
          1L
      )

      bottleneck_summary_rows[[
        bottleneck_summary_index
      ]] <- data.frame(
        Species = species_name,
        Species_code = species_code(
          species_name
        ),
        Method = method_name,
        Homology_dimension = dimension,
        Homology_label = unname(
          homology_labels[[
            as.character(
              dimension
            )
          ]]
        ),
        Repetitions_requested = number_of_repetitions,
        Repetitions_successful = nrow(
          successful
        ),
        Mean_bottleneck = safe_mean(
          successful$Bottleneck_distance
        ),
        SD_bottleneck = safe_sd(
          successful$Bottleneck_distance
        ),
        Mean_normalized_bottleneck = safe_mean(
          successful$Normalized_bottleneck_distance
        ),
        SD_normalized_bottleneck = safe_sd(
          successful$Normalized_bottleneck_distance
        ),
        stringsAsFactors = FALSE
      )
    }
  }
}

bottleneck_summary <- do.call(
  rbind,
  bottleneck_summary_rows
)

write_csv_safely(
  bottleneck_summary,
  bottleneck_summary_file
)

# ============================================================
# Exact matched filled-ellipsoid helper
# ============================================================

make_positive_definite <- function(
    matrix_value,
    epsilon = 1e-8
) {
  matrix_value <- as.matrix(
    matrix_value
  )

  matrix_value <- (
    matrix_value +
      t(
        matrix_value
      )
  ) /
    2

  eig <- eigen(
    matrix_value,
    symmetric = TRUE
  )

  adjusted_values <- pmax(
    eig$values,
    epsilon
  )

  eig$vectors %*%
    diag(
      adjusted_values,
      nrow = length(
        adjusted_values
      )
    ) %*%
    t(
      eig$vectors
    )
}

generate_exact_matched_ellipsoid <- function(
    target_points,
    number_of_points,
    seed
) {
  target_points <- set_axis_names(
    target_points
  )

  number_of_points <- as.integer(
    number_of_points
  )

  if (number_of_points < 4L) {
    stop(
      "A three-dimensional matched ellipsoid requires at least four points."
    )
  }

  d <- ncol(
    target_points
  )

  target_centroid <- colMeans(
    target_points
  )

  target_covariance <- make_positive_definite(
    stats::cov(
      target_points
    )
  )

  set.seed(
    as.integer(
      seed
    )
  )

  directions <- matrix(
    stats::rnorm(
      number_of_points *
        d
    ),
    nrow = number_of_points,
    ncol = d
  )

  direction_norms <- sqrt(
    rowSums(
      directions^2
    )
  )

  while (
    any(
      direction_norms ==
        0
    )
  ) {
    bad <- which(
      direction_norms ==
        0
    )

    directions[
      bad,
    ] <- matrix(
      stats::rnorm(
        length(
          bad
        ) *
          d
      ),
      nrow = length(
        bad
      ),
      ncol = d
    )

    direction_norms <- sqrt(
      rowSums(
        directions^2
      )
    )
  }

  directions <- directions /
    direction_norms

  radii <- stats::runif(
    number_of_points
  )^(
    1 /
      d
  )

  unit_ball <- directions *
    radii

  unit_ball <- sweep(
    unit_ball,
    2L,
    colMeans(
      unit_ball
    ),
    FUN = "-"
  )

  unit_covariance <- make_positive_definite(
    stats::cov(
      unit_ball
    )
  )

  unit_cholesky <- chol(
    unit_covariance
  )

  whitened <- unit_ball %*%
    solve(
      unit_cholesky
    )

  target_cholesky <- chol(
    target_covariance
  )

  ellipsoid_points <- whitened %*%
    target_cholesky

  ellipsoid_points <- sweep(
    ellipsoid_points,
    2L,
    target_centroid,
    FUN = "+"
  )

  ellipsoid_points <- set_axis_names(
    ellipsoid_points
  )

  list(
    points = ellipsoid_points,
    target_centroid = target_centroid,
    target_covariance = target_covariance,
    target_point_count = nrow(
      target_points
    ),
    null_point_count = number_of_points,
    centroid_error = max(
      abs(
        colMeans(
          ellipsoid_points
        ) -
          target_centroid
      )
    ),
    covariance_error = max(
      abs(
        stats::cov(
          ellipsoid_points
        ) -
          target_covariance
      )
    )
  )
}

# ============================================================
# Source-level matched-reference paths
# ============================================================

matched_reference_key <- function(
    species_name,
    source_name
) {
  paste(
    species_code(
      species_name
    ),
    source_code(
      source_name
    ),
    "matched_ellipsoid",
    sep = "__"
  )
}

matched_reference_file_path <- function(
    species_name,
    source_name
) {
  file.path(
    matched_reference_directory,
    paste0(
      matched_reference_key(
        species_name,
        source_name
      ),
      ".rds"
    )
  )
}

# ============================================================
# 400 source-level matched-reference PH calculations
# ============================================================

message(
  "\nBeginning source-level matched filled-ellipsoid reference analysis..."
)

number_of_reference_conditions <- (
  length(
    expected_species
  ) *
    length(
      source_order
    )
)

reference_condition_counter <- 0L
matched_reference_results <- list()

for (
  species_index in seq_along(
    expected_species
  )
) {
  species_name <- expected_species[[
    species_index
  ]]

  for (
    source_index in seq_along(
      source_order
    )
  ) {
    source_name <- source_order[[
      source_index
    ]]

    reference_condition_counter <- (
      reference_condition_counter +
        1L
    )

    condition_key <- matched_reference_key(
      species_name,
      source_name
    )

    condition_file <- matched_reference_file_path(
      species_name,
      source_name
    )

    full_source_points <- get_source_points(
      species_name,
      source_name
    )

    current_condition <- list(
      analysis_settings_hash = analysis_settings_hash,
      condition_key = condition_key,
      species = species_name,
      species_code = species_code(
        species_name
      ),
      source = source_name,
      full_source_point_count = nrow(
        full_source_points
      ),
      null_point_count = ph_sample_size,
      target_centroid = colMeans(
        full_source_points
      ),
      target_covariance = make_positive_definite(
        stats::cov(
          full_source_points
        )
      ),
      null_replicates = vector(
        "list",
        number_of_null_replicates
      )
    )

    if (
      resume_from_checkpoint &&
        file.exists(
          condition_file
        )
    ) {
      existing_condition <- readRDS(
        condition_file
      )

      if (
        !identical(
          existing_condition$analysis_settings_hash,
          analysis_settings_hash
        ) ||
          !identical(
            existing_condition$condition_key,
            condition_key
          )
      ) {
        stop(
          "Existing matched-reference object is incompatible:\n  ",
          condition_file
        )
      }

      current_condition <- existing_condition

      if (
        length(
          current_condition$null_replicates
        ) !=
          number_of_null_replicates
      ) {
        stop(
          "Existing matched-reference object has an unexpected number of null slots."
        )
      }
    }

    message(
      "\nMatched reference ",
      reference_condition_counter,
      "/",
      number_of_reference_conditions,
      ": ",
      species_name,
      " / ",
      source_name
    )

    for (
      null_repetition in seq_len(
        number_of_null_replicates
      )
    ) {
      existing_null <- current_condition$null_replicates[[
        null_repetition
      ]]

      if (
        !is.null(
          existing_null
        ) &&
          (
            isTRUE(
              existing_null$success
            ) ||
              !retry_incomplete_nulls
          )
      ) {
        next
      }

      current_null_seed <- as.integer(
        null_master_seed +
          species_index *
            1000000L +
          source_index *
            10000L +
          null_repetition
      )

      null_generation <- tryCatch(
        generate_exact_matched_ellipsoid(
          target_points = full_source_points,
          number_of_points = ph_sample_size,
          seed = current_null_seed
        ),
        error = function(error_condition) {
          list(
            points = NULL,
            target_centroid = rep(
              NA_real_,
              3L
            ),
            target_covariance = matrix(
              NA_real_,
              nrow = 3L,
              ncol = 3L
            ),
            target_point_count = nrow(
              full_source_points
            ),
            null_point_count = ph_sample_size,
            centroid_error = NA_real_,
            covariance_error = NA_real_,
            generation_error = conditionMessage(
              error_condition
            )
          )
        }
      )

      if (is.null(null_generation$points)) {
        null_result <- list(
          null_repetition = null_repetition,
          seed = current_null_seed,
          success = FALSE,
          generation_success = FALSE,
          ph_success = FALSE,
          diagram = empty_diagram(),
          runtime_seconds = NA_real_,
          failure_type = "matched-reference generation failure",
          error_message = null_generation$generation_error,
          centroid_error = null_generation$centroid_error,
          covariance_error = null_generation$covariance_error
        )
      } else {
        ph_result <- calculate_persistence_with_timeout(
          null_generation$points,
          maximum_dimension = maximum_homology_dimension
        )

        null_result <- list(
          null_repetition = null_repetition,
          seed = current_null_seed,
          success = isTRUE(
            ph_result$success
          ),
          generation_success = TRUE,
          ph_success = ph_result$success,
          diagram = ph_result$diagram,
          runtime_seconds = ph_result$runtime_seconds,
          failure_type = ph_result$failure_type,
          error_message = ph_result$error_message,
          centroid_error = null_generation$centroid_error,
          covariance_error = null_generation$covariance_error
        )
      }

      current_condition$null_replicates[[
        null_repetition
      ]] <- null_result

      current_condition$last_saved_at <- as.character(
        Sys.time()
      )

      saveRDS(
        current_condition,
        condition_file,
        version = 3
      )

      gc()
    }

    matched_reference_results[[
      condition_key
    ]] <- current_condition
  }
}

# ============================================================
# Compile matched-reference replicate table
# ============================================================

null_rows <- list()
null_row_index <- 0L

for (
  condition in matched_reference_results
) {
  for (
    null_repetition in seq_len(
      number_of_null_replicates
    )
  ) {
    null_result <- condition$null_replicates[[
      null_repetition
    ]]

    if (is.null(null_result)) {
      for (
        dimension in 0:
          maximum_homology_dimension
      ) {
        null_row_index <- null_row_index + 1L

        null_rows[[
          null_row_index
        ]] <- data.frame(
          Species = condition$species,
          Species_code = condition$species_code,
          Source = condition$source,
          Full_source_point_count = condition$full_source_point_count,
          Null_point_count = ph_sample_size,
          Null_repetition = null_repetition,
          Null_seed = NA_integer_,
          Null_success = FALSE,
          Homology_dimension = dimension,
          Homology_label = unname(
            homology_labels[[
              as.character(
                dimension
              )
            ]]
          ),
          Null_maximum_persistence = NA_real_,
          Null_runtime_seconds = NA_real_,
          Centroid_error = NA_real_,
          Covariance_error = NA_real_,
          Failure_type = "not calculated",
          Error_message = "null replicate missing",
          stringsAsFactors = FALSE
        )
      }

      next
    }

    for (
      dimension in 0:
        maximum_homology_dimension
    ) {
      null_row_index <- null_row_index + 1L

      null_rows[[
        null_row_index
      ]] <- data.frame(
        Species = condition$species,
        Species_code = condition$species_code,
        Source = condition$source,
        Full_source_point_count = condition$full_source_point_count,
        Null_point_count = ph_sample_size,
        Null_repetition = null_repetition,
        Null_seed = null_result$seed,
        Null_success = isTRUE(
          null_result$success
        ),
        Homology_dimension = dimension,
        Homology_label = unname(
          homology_labels[[
            as.character(
              dimension
            )
          ]]
        ),
        Null_maximum_persistence = if (
          isTRUE(
            null_result$success
          )
        ) {
          max_finite_persistence(
            null_result$diagram,
            dimension
          )
        } else {
          NA_real_
        },
        Null_runtime_seconds = null_result$runtime_seconds,
        Centroid_error = null_result$centroid_error,
        Covariance_error = null_result$covariance_error,
        Failure_type = null_result$failure_type,
        Error_message = null_result$error_message,
        stringsAsFactors = FALSE
      )
    }
  }
}

null_replicates <- do.call(
  rbind,
  null_rows
)

write_csv_safely(
  null_replicates,
  null_replicate_file
)

# ============================================================
# Complete 20-null source-level thresholds
# ============================================================

null_threshold_rows <- list()
null_threshold_index <- 0L

for (
  species_name in expected_species
) {
  for (
    source_name in source_order
  ) {
    for (
      dimension in 0:
        maximum_homology_dimension
    ) {
      group <- null_replicates[
        null_replicates$Species ==
          species_name &
          null_replicates$Source ==
            source_name &
          null_replicates$Homology_dimension ==
            dimension,
        ,
        drop = FALSE
      ]

      successful <- group[
        group$Null_success &
          is.finite(
            group$Null_maximum_persistence
          ),
        ,
        drop = FALSE
      ]

      complete_reference <- (
        nrow(
          successful
        ) ==
          number_of_null_replicates
      )

      null_threshold_index <- (
        null_threshold_index +
          1L
      )

      null_threshold_rows[[
        null_threshold_index
      ]] <- data.frame(
        Species = species_name,
        Species_code = species_code(
          species_name
        ),
        Source = source_name,
        Homology_dimension = dimension,
        Homology_label = unname(
          homology_labels[[
            as.character(
              dimension
            )
          ]]
        ),
        Null_replicates_requested = number_of_null_replicates,
        Null_replicates_successful = nrow(
          successful
        ),
        Complete_20_null_reference = complete_reference,
        Mean_null_maximum_persistence = safe_mean(
          successful$Null_maximum_persistence
        ),
        SD_null_maximum_persistence = safe_sd(
          successful$Null_maximum_persistence
        ),
        Maximum_null_persistence = if (
          complete_reference
        ) {
          max(
            successful$Null_maximum_persistence
          )
        } else {
          NA_real_
        },
        Maximum_centroid_matching_error = safe_max(
          successful$Centroid_error
        ),
        Maximum_covariance_matching_error = safe_max(
          successful$Covariance_error
        ),
        stringsAsFactors = FALSE
      )
    }
  }
}

null_thresholds <- do.call(
  rbind,
  null_threshold_rows
)

write_csv_safely(
  null_thresholds,
  null_threshold_file
)

# ============================================================
# Observed repetitions versus complete matched reference
# ============================================================

null_observed_rows <- list()
null_observed_index <- 0L

for (
  species_name in expected_species
) {
  for (
    source_name in source_order
  ) {
    for (
      dimension in 0:
        maximum_homology_dimension
    ) {
      threshold_row <- null_thresholds[
        null_thresholds$Species ==
          species_name &
          null_thresholds$Source ==
            source_name &
          null_thresholds$Homology_dimension ==
            dimension,
        ,
        drop = FALSE
      ]

      if (nrow(threshold_row) != 1L) {
        stop(
          "Could not recover one matched-reference threshold for ",
          species_name,
          " / ",
          source_name,
          " / H",
          dimension,
          "."
        )
      }

      threshold <- threshold_row$Maximum_null_persistence[[
        1L
      ]]

      reference_complete <- isTRUE(
        threshold_row$Complete_20_null_reference[[
          1L
        ]]
      )

      for (
        repetition in seq_len(
          number_of_repetitions
        )
      ) {
        observed <- persistence_replicates[
          persistence_replicates$Species ==
            species_name &
            persistence_replicates$Source ==
              source_name &
            persistence_replicates$Repetition ==
              repetition &
            persistence_replicates$Homology_dimension ==
              dimension,
          ,
          drop = FALSE
        ]

        if (nrow(observed) != 1L) {
          stop(
            "Could not recover unique observed persistence result."
          )
        }

        evaluable <- (
          reference_complete &&
            isTRUE(
              observed$PH_success[[
                1L
              ]]
            ) &&
            is.finite(
              observed$Maximum_finite_persistence[[
                1L
              ]]
            ) &&
            is.finite(
              threshold
            )
        )

        observed_maximum <- observed$Maximum_finite_persistence[[
          1L
        ]]

        null_observed_index <- null_observed_index + 1L

        null_observed_rows[[
          null_observed_index
        ]] <- data.frame(
          Species = species_name,
          Species_code = species_code(
            species_name
          ),
          Source = source_name,
          Repetition = repetition,
          Homology_dimension = dimension,
          Homology_label = unname(
            homology_labels[[
              as.character(
                dimension
              )
            ]]
          ),
          Observed_PH_success = observed$PH_success[[
            1L
          ]],
          Observed_maximum_persistence = observed_maximum,
          Null_replicates_requested = number_of_null_replicates,
          Null_replicates_successful = threshold_row$Null_replicates_successful[[
            1L
          ]],
          Complete_20_null_reference = reference_complete,
          Maximum_null_persistence = threshold,
          Evaluable = evaluable,
          Exceeds_matched_ellipsoid_reference = if (
            evaluable
          ) {
            observed_maximum >
              threshold
          } else {
            NA
          },
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

null_observed_results <- do.call(
  rbind,
  null_observed_rows
)

write_csv_safely(
  null_observed_results,
  null_observed_file
)

# ============================================================
# Exceedance proportion summaries
# ============================================================

null_summary_rows <- list()
null_summary_index <- 0L

for (
  species_name in expected_species
) {
  for (
    source_name in source_order
  ) {
    for (
      dimension in 0:
        maximum_homology_dimension
    ) {
      group <- null_observed_results[
        null_observed_results$Species ==
          species_name &
          null_observed_results$Source ==
            source_name &
          null_observed_results$Homology_dimension ==
            dimension,
        ,
        drop = FALSE
      ]

      evaluable <- group[
        group$Evaluable &
          !is.na(
            group$Exceeds_matched_ellipsoid_reference
          ),
        ,
        drop = FALSE
      ]

      threshold_row <- null_thresholds[
        null_thresholds$Species ==
          species_name &
          null_thresholds$Source ==
            source_name &
          null_thresholds$Homology_dimension ==
            dimension,
        ,
        drop = FALSE
      ]

      null_summary_index <- null_summary_index + 1L

      null_summary_rows[[
        null_summary_index
      ]] <- data.frame(
        Species = species_name,
        Species_code = species_code(
          species_name
        ),
        Source = source_name,
        Homology_dimension = dimension,
        Homology_label = unname(
          homology_labels[[
            as.character(
              dimension
            )
          ]]
        ),
        Observed_repetitions_requested = number_of_repetitions,
        Observed_repetitions_evaluable = nrow(
          evaluable
        ),
        Null_replicates_requested = number_of_null_replicates,
        Null_replicates_successful = threshold_row$Null_replicates_successful[[
          1L
        ]],
        Complete_20_null_reference = threshold_row$Complete_20_null_reference[[
          1L
        ]],
        Number_exceeding_matched_ellipsoid_reference = sum(
          evaluable$Exceeds_matched_ellipsoid_reference
        ),
        Exceedance_proportion = if (
          nrow(
            evaluable
          ) >
            0L
        ) {
          mean(
            evaluable$Exceeds_matched_ellipsoid_reference
          )
        } else {
          NA_real_
        },
        Mean_observed_maximum_persistence = safe_mean(
          evaluable$Observed_maximum_persistence
        ),
        SD_observed_maximum_persistence = safe_sd(
          evaluable$Observed_maximum_persistence
        ),
        Maximum_null_persistence = threshold_row$Maximum_null_persistence[[
          1L
        ]],
        stringsAsFactors = FALSE
      )
    }
  }
}

null_summary <- do.call(
  rbind,
  null_summary_rows
)

write_csv_safely(
  null_summary,
  null_summary_file
)

# ============================================================
# Paired occurrence-estimator exceedance classification
# ============================================================

paired_rows <- list()
paired_index <- 0L

for (
  species_name in expected_species
) {
  for (
    method_name in method_order
  ) {
    for (
      repetition in seq_len(
        number_of_repetitions
      )
    ) {
      for (
        dimension in 0:
          maximum_homology_dimension
      ) {
        occurrence_row <- null_observed_results[
          null_observed_results$Species ==
            species_name &
            null_observed_results$Source ==
              "Occurrence" &
            null_observed_results$Repetition ==
              repetition &
            null_observed_results$Homology_dimension ==
              dimension,
          ,
          drop = FALSE
        ]

        estimator_row <- null_observed_results[
          null_observed_results$Species ==
            species_name &
            null_observed_results$Source ==
              method_name &
            null_observed_results$Repetition ==
              repetition &
            null_observed_results$Homology_dimension ==
              dimension,
          ,
          drop = FALSE
        ]

        if (
          nrow(
            occurrence_row
          ) !=
            1L ||
            nrow(
              estimator_row
            ) !=
              1L
        ) {
          stop(
            "Could not recover paired occurrence-estimator exceedance results."
          )
        }

        evaluable <- (
          occurrence_row$Evaluable[[
            1L
          ]] &&
            estimator_row$Evaluable[[
              1L
            ]]
        )

        occurrence_exceeds <- if (
          evaluable
        ) {
          occurrence_row$Exceeds_matched_ellipsoid_reference[[
            1L
          ]]
        } else {
          NA
        }

        estimator_exceeds <- if (
          evaluable
        ) {
          estimator_row$Exceeds_matched_ellipsoid_reference[[
            1L
          ]]
        } else {
          NA
        }

        classification <- if (
          !evaluable
        ) {
          NA_character_
        } else if (
          occurrence_exceeds &&
            estimator_exceeds
        ) {
          "Retained"
        } else if (
          occurrence_exceeds &&
            !estimator_exceeds
        ) {
          "Lost"
        } else if (
          !occurrence_exceeds &&
            estimator_exceeds
        ) {
          "Introduced"
        } else {
          "Joint absence"
        }

        paired_index <- paired_index + 1L

        paired_rows[[
          paired_index
        ]] <- data.frame(
          Species = species_name,
          Species_code = species_code(
            species_name
          ),
          Method = method_name,
          Repetition = repetition,
          Homology_dimension = dimension,
          Homology_label = unname(
            homology_labels[[
              as.character(
                dimension
              )
            ]]
          ),
          Evaluable = evaluable,
          Occurrence_exceeds_reference = occurrence_exceeds,
          Estimator_exceeds_reference = estimator_exceeds,
          Classification = classification,
          Classification_agreement = if (
            evaluable
          ) {
            occurrence_exceeds ==
              estimator_exceeds
          } else {
            NA
          },
          Joint_exceedance = if (
            evaluable
          ) {
            occurrence_exceeds &&
              estimator_exceeds
          } else {
            NA
          },
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

paired_classification <- do.call(
  rbind,
  paired_rows
)

write_csv_safely(
  paired_classification,
  paired_classification_file
)

# ============================================================
# Paired classification summaries
# ============================================================

paired_summary_rows <- list()
paired_summary_index <- 0L

for (
  species_name in expected_species
) {
  for (
    method_name in method_order
  ) {
    for (
      dimension in 0:
        maximum_homology_dimension
    ) {
      group <- paired_classification[
        paired_classification$Species ==
          species_name &
          paired_classification$Method ==
            method_name &
          paired_classification$Homology_dimension ==
            dimension,
        ,
        drop = FALSE
      ]

      evaluable <- group[
        group$Evaluable,
        ,
        drop = FALSE
      ]

      category_count <- function(category_name) {
        sum(
          evaluable$Classification ==
            category_name,
          na.rm = TRUE
        )
      }

      occurrence_positive <- evaluable[
        evaluable$Occurrence_exceeds_reference,
        ,
        drop = FALSE
      ]

      paired_summary_index <- paired_summary_index + 1L

      paired_summary_rows[[
        paired_summary_index
      ]] <- data.frame(
        Species = species_name,
        Species_code = species_code(
          species_name
        ),
        Method = method_name,
        Homology_dimension = dimension,
        Homology_label = unname(
          homology_labels[[
            as.character(
              dimension
            )
          ]]
        ),
        Repetitions_requested = number_of_repetitions,
        Repetitions_evaluable = nrow(
          evaluable
        ),
        Occurrence_exceedance_proportion = if (
          nrow(
            evaluable
          ) >
            0L
        ) {
          mean(
            evaluable$Occurrence_exceeds_reference
          )
        } else {
          NA_real_
        },
        Estimator_exceedance_proportion = if (
          nrow(
            evaluable
          ) >
            0L
        ) {
          mean(
            evaluable$Estimator_exceeds_reference
          )
        } else {
          NA_real_
        },
        Classification_agreement_proportion = if (
          nrow(
            evaluable
          ) >
            0L
        ) {
          mean(
            evaluable$Classification_agreement
          )
        } else {
          NA_real_
        },
        Joint_exceedance_proportion = if (
          nrow(
            evaluable
          ) >
            0L
        ) {
          mean(
            evaluable$Joint_exceedance
          )
        } else {
          NA_real_
        },
        Retained_count = category_count(
          "Retained"
        ),
        Lost_count = category_count(
          "Lost"
        ),
        Introduced_count = category_count(
          "Introduced"
        ),
        Joint_absence_count = category_count(
          "Joint absence"
        ),
        Occurrence_positive_repetitions = nrow(
          occurrence_positive
        ),
        Estimator_exceedance_given_occurrence_positive = if (
          nrow(
            occurrence_positive
          ) >
            0L
        ) {
          mean(
            occurrence_positive$Estimator_exceeds_reference
          )
        } else {
          NA_real_
        },
        stringsAsFactors = FALSE
      )
    }
  }
}

paired_summary <- do.call(
  rbind,
  paired_summary_rows
)

write_csv_safely(
  paired_summary,
  paired_summary_file
)

# ============================================================
# Failure audit
# ============================================================

failure_rows <- list()
failure_index <- 0L

failed_primary <- ph_log[
  !ph_log$Success,
  ,
  drop = FALSE
]

if (nrow(failed_primary) > 0L) {
  for (
    row_index in seq_len(
      nrow(
        failed_primary
      )
    )
  ) {
    failure_index <- failure_index + 1L

    failure_rows[[
      failure_index
    ]] <- data.frame(
      Stage = "Primary PH",
      Species = failed_primary$Species[[
        row_index
      ]],
      Source = failed_primary$Source[[
        row_index
      ]],
      Repetition = failed_primary$Repetition[[
        row_index
      ]],
      Homology_dimension = NA_integer_,
      Failure_type = failed_primary$Failure_type[[
        row_index
      ]],
      Error_message = failed_primary$Error_message[[
        row_index
      ]],
      stringsAsFactors = FALSE
    )
  }
}

failed_nulls <- unique(
  null_replicates[
    !null_replicates$Null_success,
    c(
      "Species",
      "Source",
      "Null_repetition",
      "Failure_type",
      "Error_message"
    ),
    drop = FALSE
  ]
)

if (nrow(failed_nulls) > 0L) {
  for (
    row_index in seq_len(
      nrow(
        failed_nulls
      )
    )
  ) {
    failure_index <- failure_index + 1L

    failure_rows[[
      failure_index
    ]] <- data.frame(
      Stage = "Matched reference PH",
      Species = failed_nulls$Species[[
        row_index
      ]],
      Source = failed_nulls$Source[[
        row_index
      ]],
      Repetition = failed_nulls$Null_repetition[[
        row_index
      ]],
      Homology_dimension = NA_integer_,
      Failure_type = failed_nulls$Failure_type[[
        row_index
      ]],
      Error_message = failed_nulls$Error_message[[
        row_index
      ]],
      stringsAsFactors = FALSE
    )
  }
}

failed_bottleneck <- bottleneck_replicates[
  !bottleneck_replicates$Success,
  ,
  drop = FALSE
]

if (nrow(failed_bottleneck) > 0L) {
  for (
    row_index in seq_len(
      nrow(
        failed_bottleneck
      )
    )
  ) {
    failure_index <- failure_index + 1L

    failure_rows[[
      failure_index
    ]] <- data.frame(
      Stage = "Bottleneck",
      Species = failed_bottleneck$Species[[
        row_index
      ]],
      Source = failed_bottleneck$Method[[
        row_index
      ]],
      Repetition = failed_bottleneck$Repetition[[
        row_index
      ]],
      Homology_dimension = failed_bottleneck$Homology_dimension[[
        row_index
      ]],
      Failure_type = "bottleneck failure",
      Error_message = failed_bottleneck$Error_message[[
        row_index
      ]],
      stringsAsFactors = FALSE
    )
  }
}

failure_table <- if (
  length(
    failure_rows
  ) >
    0L
) {
  do.call(
    rbind,
    failure_rows
  )
} else {
  data.frame(
    Stage = character(0),
    Species = character(0),
    Source = character(0),
    Repetition = integer(0),
    Homology_dimension = integer(0),
    Failure_type = character(0),
    Error_message = character(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  failure_table,
  failure_file
)

# ============================================================
# Final result object
# ============================================================

run_metadata <- list(
  script = "21_Acacia_Topology.R",
  analysis_settings_hash = analysis_settings_hash,
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  primary_ph_requested = primary_total,
  primary_ph_successful = sum(
    ph_log$Success
  ),
  matched_reference_conditions = number_of_reference_conditions,
  matched_reference_ph_requested = (
    number_of_reference_conditions *
      number_of_null_replicates
  ),
  matched_reference_ph_successful = length(
    unique(
      paste(
        null_replicates$Species[
          null_replicates$Null_success
        ],
        null_replicates$Source[
          null_replicates$Null_success
        ],
        null_replicates$Null_repetition[
          null_replicates$Null_success
        ],
        sep = "__"
      )
    )
  ),
  complete_source_level_references = sum(
    null_thresholds$Complete_20_null_reference[
      null_thresholds$Homology_dimension ==
        0L
    ]
  ),
  source_level_references_requested = number_of_reference_conditions,
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
  input_qa = input_qa,
  ph_log = ph_log,
  persistence_replicates = persistence_replicates,
  persistence_summary = persistence_summary,
  bottleneck_replicates = bottleneck_replicates,
  bottleneck_summary = bottleneck_summary,
  matched_ellipsoid_replicates = null_replicates,
  matched_ellipsoid_thresholds = null_thresholds,
  matched_ellipsoid_observed_results = null_observed_results,
  matched_ellipsoid_exceedance_summary = null_summary,
  paired_exceedance_classification_replicates = paired_classification,
  paired_exceedance_classification_summary = paired_summary,
  failures = failure_table
)

saveRDS(
  final_results,
  final_results_file,
  version = 3
)

# ============================================================
# Notes and session information
# ============================================================

analysis_notes <- c(
  "ACACIA TOPOLOGY",
  "===============",
  "",
  "Formal empirical topological reference:",
  "  occurrence cloud",
  "",
  "The occurrence cloud is not treated as complete biological truth.",
  "",
  "Primary PH:",
  "  5 species",
  "  4 sources: Occurrence, QPH, Gaussian KDE, SVM",
  "  10 reproducible repetitions",
  "  300 points per source and repetition",
  "  H0-H2",
  "  TDAstats::calculate_homology()",
  "  threshold = -1",
  "  p = 2 where supported",
  "  standardize = FALSE where supported",
  "  6-minute limit per PH calculation",
  "",
  "Bottleneck:",
  "  estimator diagram compared with paired occurrence diagram",
  "  H0-H2 separately",
  "  normalized by paired occurrence-cloud diameter",
  "",
  "Matched filled-ellipsoid reference:",
  "  one source-level reference per species x source",
  "  5 species x 4 sources = 20 source conditions",
  "  20 matched ellipsoid clouds per source condition",
  "  300 points per null cloud",
  "  400 requested matched-reference PH calculations",
  "  target centroid/covariance taken from the FULL source cloud",
  "  one complete 20-null maximum is shared across all 10 observed repetitions",
  "  incomplete 20-null references are not used for exceedance classification",
  "",
  "Reported matched-reference quantity:",
  "  Exceedance_proportion",
  "",
  "Do not interpret matched-reference exceedance as a general significance test.",
  "",
  "Paired occurrence-estimator classifications:",
  "  Retained",
  "  Lost",
  "  Introduced",
  "  Joint absence",
  "",
  "These labels describe agreement relative to the occurrence cloud and",
  "matched filled-ellipsoid reference; they do not identify true topology.",
  "",
  "No topology sensitivity analysis is performed.",
  "",
  paste0(
    "Primary PH successes: ",
    sum(
      ph_log$Success
    ),
    " / ",
    nrow(
      ph_log
    )
  ),
  paste0(
    "Complete source-level matched references: ",
    run_metadata$complete_source_level_references,
    " / ",
    number_of_reference_conditions
  ),
  paste0(
    "Failure records: ",
    nrow(
      failure_table
    )
  ),
  paste0(
    "Locked design hash: ",
    locked_design_hash
  ),
  paste0(
    "Baseline analysis hash: ",
    baseline_analysis_hash
  ),
  paste0(
    "Topology analysis settings hash: ",
    analysis_settings_hash
  ),
  paste0(
    "TDAstats version: ",
    installed_tda_stats_version
  ),
  paste0(
    "TDA version: ",
    installed_tda_version
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
# Console summaries
# ============================================================

message(
  "\n============================================================"
)

message(
  "21_Acacia_Topology.R complete."
)

message(
  "\nNORMALIZED BOTTLENECK SUMMARY:"
)

print(
  bottleneck_summary[
    ,
    c(
      "Species",
      "Method",
      "Homology_label",
      "Repetitions_successful",
      "Mean_normalized_bottleneck",
      "SD_normalized_bottleneck"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)

message(
  "\nMATCHED FILLED-ELLIPSOID EXCEEDANCE SUMMARY:"
)

print(
  null_summary[
    ,
    c(
      "Species",
      "Source",
      "Homology_label",
      "Observed_repetitions_evaluable",
      "Null_replicates_successful",
      "Exceedance_proportion",
      "Mean_observed_maximum_persistence",
      "Maximum_null_persistence"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)

message(
  "\nPAIRED OCCURRENCE-ESTIMATOR CLASSIFICATION SUMMARY:"
)

print(
  paired_summary[
    ,
    c(
      "Species",
      "Method",
      "Homology_label",
      "Repetitions_evaluable",
      "Occurrence_exceedance_proportion",
      "Estimator_exceedance_proportion",
      "Classification_agreement_proportion",
      "Joint_exceedance_proportion",
      "Retained_count",
      "Lost_count",
      "Introduced_count",
      "Joint_absence_count"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)

message(
  "\nFailure records: ",
  nrow(
    failure_table
  )
)

message(
  "Final topology object:\n  ",
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
# Completion warning rather than hard failure
# ============================================================
#
# A PH timeout is itself a recorded computational-limit result. Therefore
# Script 21 does not discard completed analyses or force replacement samples.
# Downstream scripts must respect the Success / Evaluable / Complete-reference
# fields rather than silently treating missing values as zero.
# ============================================================

if (
  nrow(
    failure_table
  ) >
    0L
) {
  warning(
    "Script 21 completed with ",
    nrow(
      failure_table
    ),
    " recorded failure(s)/computational-limit result(s). ",
    "No replacement sampling was performed. Inspect:\n  ",
    normalizePath(
      failure_file,
      winslash = "/",
      mustWork = FALSE
    )
  )
}
