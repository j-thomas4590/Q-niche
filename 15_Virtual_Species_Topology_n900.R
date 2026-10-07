# ============================================================
# 15_Virtual_Species_Topology_n900.R
# ============================================================
#
# PURPOSE
# -------
# Persistent-homology validation for the TWO locked virtual species at the
# representative intermediate occurrence sample size n = 900.
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
  "04_Topology"
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
# Locked topology design
# ============================================================

analysis_sample_size <- 900L

ph_sample_size <- 300L
number_of_repetitions <- 10L
maximum_homology_dimension <- 2L

ph_threshold <- -1
ph_prime_field <- 2L
ph_standardize <- FALSE
ph_timeout_seconds <- 6 * 60

number_of_null_replicates <- 20L

# Preserve the original virtual-species PH/null seed families.
ph_master_seed <- 921331L
null_master_seed <- 922331L

resume_from_checkpoints <- TRUE
retry_failed_persistence <- TRUE
retry_incomplete_nulls <- TRUE

species_order <- c(
  "Unimodal",
  "Disconnected"
)

species_labels <- c(
  Unimodal = "Unimodal Gaussian-PCA",
  Disconnected = "Disconnected bimodal"
)

source_order <- c(
  "Occurrence",
  "QPH",
  "Gaussian KDE",
  "SVM"
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

source_colours <- c(
  "Occurrence" = occurrence_colour,
  method_colours
)

expected_topology <- data.frame(
  Virtual_species = c(
    "Unimodal",
    "Disconnected"
  ),
  Expected_beta0 = c(
    1L,
    2L
  ),
  Expected_beta1 = c(
    0L,
    0L
  ),
  Expected_beta2 = c(
    0L,
    0L
  ),
  Primary_topological_signal = c(
    "No non-trivial H1/H2",
    "Finite H0 component separation"
  ),
  stringsAsFactors = FALSE
)

target_feature_table <- data.frame(
  Virtual_species = c(
    "Unimodal",
    "Unimodal",
    "Disconnected"
  ),
  Homology_dimension = c(
    1L,
    2L,
    0L
  ),
  Feature = c(
    "Unimodal - H1 negative control",
    "Unimodal - H2 negative control",
    "Disconnected - finite H0 separation"
  ),
  Expected_signal = c(
    "Absent",
    "Absent",
    "Present"
  ),
  stringsAsFactors = FALSE
)


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

required_upstream_files <- c(
  locked_master_file,
  locked_settings_file,
  baseline_settings_file,
  baseline_results_file
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
    "\nRun Scripts 12 and 13 successfully before Script 15."
  )
}


# ============================================================
# Output files
# ============================================================

subsample_file <- file.path(
  output_directory,
  "virtual_species_topology_subsample_indices_n900.rds"
)

ph_log_file <- file.path(
  table_directory,
  "Virtual_species_persistence_calculation_log_n900.csv"
)

persistence_replicate_file <- file.path(
  table_directory,
  "Virtual_species_persistence_replicates_n900.csv"
)

persistence_summary_file <- file.path(
  table_directory,
  "Virtual_species_persistence_mean_sd_n900.csv"
)

bottleneck_replicate_file <- file.path(
  table_directory,
  "Virtual_species_bottleneck_replicates_n900.csv"
)

bottleneck_summary_file <- file.path(
  table_directory,
  "Virtual_species_bottleneck_mean_sd_n900.csv"
)

null_replicate_file <- file.path(
  table_directory,
  "Virtual_species_matched_ellipsoid_replicates_n900.csv"
)

null_threshold_file <- file.path(
  table_directory,
  "Virtual_species_matched_ellipsoid_thresholds_n900.csv"
)

null_observed_file <- file.path(
  table_directory,
  "Virtual_species_matched_ellipsoid_observed_results_n900.csv"
)

null_summary_file <- file.path(
  table_directory,
  "Virtual_species_matched_ellipsoid_exceedance_summary_n900.csv"
)

target_null_summary_file <- file.path(
  table_directory,
  "Virtual_species_TARGET_matched_ellipsoid_exceedance_summary_n900.csv"
)

feature_retention_replicate_file <- file.path(
  table_directory,
  "Virtual_species_feature_retention_replicates_n900.csv"
)

feature_retention_summary_file <- file.path(
  table_directory,
  "Virtual_species_feature_retention_summary_n900.csv"
)

occurrence_qa_file <- file.path(
  table_directory,
  "Virtual_species_OCCURRENCE_matched_ellipsoid_QA_n900.csv"
)

expected_topology_file <- file.path(
  table_directory,
  "Virtual_species_expected_generating_topology.csv"
)

failure_file <- file.path(
  table_directory,
  "Virtual_species_topology_failures_n900.csv"
)

input_qa_file <- file.path(
  table_directory,
  "Virtual_species_topology_input_QA_n900.csv"
)

settings_file <- file.path(
  output_directory,
  "topology_analysis_settings.rds"
)

final_results_file <- file.path(
  output_directory,
  "virtual_species_topology_n900_sqrtNB_q099.rds"
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


set_axis_names <- function(x) {

  x <- as.matrix(x)
  storage.mode(x) <- "double"

  if (ncol(x) != 3L) {
    stop(
      "Expected exactly three PC axes."
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
      "Point cloud contains no rows or non-finite coordinates."
    )
  }

  colnames(x) <- c(
    "PC1",
    "PC2",
    "PC3"
  )

  x
}


safe_mean <- function(x) {

  x <- x[
    is.finite(
      x
    )
  ]

  if (length(x) == 0L) {
    return(
      NA_real_
    )
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
    return(
      NA_real_
    )
  }

  stats::sd(
    x
  )
}


source_code <- function(source_name) {

  switch(
    source_name,
    "Occurrence" = "occurrence",
    "QPH" = "qph",
    "Gaussian KDE" = "gaussian_kde",
    "SVM" = "svm",
    stop(
      "Unknown source: ",
      source_name
    )
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
      "Unknown virtual species: ",
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

  file.path(
    baseline_fit_directory,
    "model_objects",
    paste0(
      condition_id_for(
        species_name,
        sample_size,
        method_name
      ),
      ".rds"
    )
  )
}


ph_key <- function(
    species_name,
    repetition,
    source_name
) {

  paste(
    species_code(
      species_name
    ),
    paste0(
      "n",
      analysis_sample_size
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


primary_ph_object_path <- function(
    species_name,
    repetition,
    source_name
) {

  file.path(
    primary_ph_directory,
    paste0(
      ph_key(
        species_name,
        repetition,
        source_name
      ),
      ".rds"
    )
  )
}


matched_reference_key <- function(
    species_name,
    source_name
) {

  paste(
    species_code(
      species_name
    ),
    paste0(
      "n",
      analysis_sample_size
    ),
    source_code(
      source_name
    ),
    "matched_ellipsoid",
    sep = "__"
  )
}


matched_reference_object_path <- function(
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
# Load and verify revised Script-12/13 inputs
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
    "Could not recover Script-12/13 analysis hashes."
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
    "Script-13 final results object and settings hash differ."
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
    "Unexpected Script-13 estimator design."
  )
}

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
    "Script-13 QPH baseline is not sqrt-NB / q=0.99."
  )
}


# ============================================================
# Cache source point clouds
# ============================================================

source_point_clouds <- list()
input_qa_rows <- list()
input_qa_index <- 0L

for (
  species_name in species_order
) {

  occurrence_object <- locked_inputs$occurrences$species[[
    species_name
  ]]$subsets[[
    as.character(
      analysis_sample_size
    )
  ]]

  if (
    is.null(
      occurrence_object
    ) ||
      is.null(
        occurrence_object$pc
      )
  ) {
    stop(
      "Missing locked n=900 occurrence PC cloud for ",
      species_name,
      "."
    )
  }

  occurrence_points <- set_axis_names(
    occurrence_object$pc
  )

  if (
    nrow(
      occurrence_points
    ) !=
      analysis_sample_size
  ) {
    stop(
      species_name,
      " occurrence cloud contains ",
      nrow(
        occurrence_points
      ),
      " points rather than ",
      analysis_sample_size,
      "."
    )
  }

  source_point_clouds[[
    paste(
      species_code(
        species_name
      ),
      "occurrence",
      sep = "__"
    )
  ]] <- occurrence_points

  input_qa_index <- input_qa_index + 1L

  input_qa_rows[[
    input_qa_index
  ]] <- data.frame(
    Virtual_species = species_name,
    Sample_size = analysis_sample_size,
    Source = "Occurrence",
    Full_source_points = nrow(
      occurrence_points
    ),
    Model_file = NA_character_,
    Model_MD5 = NA_character_,
    QPH_q = NA_real_,
    QPH_K = NA_integer_,
    stringsAsFactors = FALSE
  )

  for (
    method_name in method_order
  ) {

    model_file <- model_object_path(
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
        "Revised n=900 fit unavailable for ",
        species_name,
        " / ",
        method_name,
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
        "Script-13 settings hash mismatch for ",
        species_name,
        " / ",
        method_name,
        "."
      )
    }

    methods::validObject(
      fit$hypervolume
    )

    hv_points <- set_axis_names(
      fit$hypervolume@RandomPoints
    )

    source_point_clouds[[
      paste(
        species_code(
          species_name
        ),
        source_code(
          method_name
        ),
        sep = "__"
      )
    ]] <- hv_points

    qph_q <- NA_real_
    qph_K <- NA_integer_

    if (
      identical(
        method_name,
        "QPH"
      )
    ) {

      qph_q <- as.numeric(
        fit$qph_result$audit$q
      )

      qph_K <- as.integer(
        fit$qph_result$audit$K
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
            )
      ) {
        stop(
          "Revised QPH baseline QA failed for ",
          species_name,
          "."
        )
      }
    }

    input_qa_index <- input_qa_index + 1L

    input_qa_rows[[
      input_qa_index
    ]] <- data.frame(
      Virtual_species = species_name,
      Sample_size = analysis_sample_size,
      Source = method_name,
      Full_source_points = nrow(
        hv_points
      ),
      Model_file = normalizePath(
        model_file,
        winslash = "/",
        mustWork = TRUE
      ),
      Model_MD5 = safe_md5(
        model_file
      ),
      QPH_q = qph_q,
      QPH_K = qph_K,
      stringsAsFactors = FALSE
    )
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


get_source_points <- function(
    species_name,
    source_name
) {

  key <- paste(
    species_code(
      species_name
    ),
    source_code(
      source_name
    ),
    sep = "__"
  )

  points <- source_point_clouds[[
    key
  ]]

  if (is.null(points)) {
    stop(
      "Source point cloud not cached: ",
      key
    )
  }

  points
}


# ============================================================
# Persistence-diagram helpers
# ============================================================

tda_calculate_homology_formals <- names(
  formals(
    TDAstats::calculate_homology
  )
)

tda_supports_prime_field <- (
  "p" %in%
    tda_calculate_homology_formals
)

if (!tda_supports_prime_field) {
  warning(
    "Installed TDAstats::calculate_homology() does not expose argument p; ",
    "the package default coefficient field will be used."
  )
}


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

  if (is.null(diagram)) {
    return(
      empty_diagram()
    )
  }

  diagram <- as.matrix(
    diagram
  )

  if (nrow(diagram) == 0L) {
    return(
      empty_diagram()
    )
  }

  if (ncol(diagram) < 3L) {
    stop(
      "Persistence diagram has fewer than three columns."
    )
  }

  diagram <- diagram[
    ,
    seq_len(
      3L
    ),
    drop = FALSE
  ]

  colnames(
    diagram
  ) <- c(
    "dimension",
    "birth",
    "death"
  )

  storage.mode(
    diagram
  ) <- "double"

  diagram
}


finite_diagram <- function(diagram) {

  diagram <- standardize_diagram(
    diagram
  )

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

  relevant_rows <- diagram[
    diagram[
      ,
      "dimension"
    ] ==
      dimension,
    ,
    drop = FALSE
  ]

  if (nrow(relevant_rows) == 0L) {
    return(
      0
    )
  }

  persistence <- (
    relevant_rows[
      ,
      "death"
    ] -
      relevant_rows[
        ,
        "birth"
      ]
  )

  persistence <- persistence[
    is.finite(
      persistence
    ) &
      persistence >= 0
  ]

  if (length(persistence) == 0L) {
    return(
      0
    )
  }

  max(
    persistence
  )
}


point_cloud_diameter <- function(points) {

  points <- set_axis_names(
    points
  )

  if (nrow(points) < 2L) {
    return(
      NA_real_
    )
  }

  max(
    stats::dist(
      points
    )
  )
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

  tryCatch(
    {

      homology_arguments <- list(
        mat = points,
        dim = maximum_dimension,
        threshold = ph_threshold,
        format = "cloud"
      )

      if (
        "standardize" %in%
          tda_calculate_homology_formals
      ) {
        homology_arguments$standardize <- ph_standardize
      }

      if (
        "return_df" %in%
          tda_calculate_homology_formals
      ) {
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
        error_message = NA_character_
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
        )
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
        failure_type = if (is_timeout) {
          "computational-limit failure"
        } else {
          "calculation failure"
        },
        error_message = error_text
      )
    }
  )
}


calculate_bottleneck_safe <- function(
    occurrence_diagram,
    method_diagram,
    dimension
) {

  tryCatch(
    {

      value <- TDA::bottleneck(
        Diag1 = finite_diagram(
          occurrence_diagram
        ),
        Diag2 = finite_diagram(
          method_diagram
        ),
        dimension = as.integer(
          dimension
        )
      )

      list(
        success = TRUE,
        distance = as.numeric(
          value
        ),
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
# Topology settings hash
# ============================================================

analysis_settings <- list(
  script = "15_Virtual_Species_Topology_n900.R",
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  species = species_order,
  sample_size = analysis_sample_size,
  source_order = source_order,
  ph_sample_size = ph_sample_size,
  number_of_repetitions = number_of_repetitions,
  maximum_homology_dimension = maximum_homology_dimension,
  ph_threshold = ph_threshold,
  ph_prime_field = ph_prime_field,
  ph_standardize = ph_standardize,
  ph_timeout_seconds = ph_timeout_seconds,
  number_of_null_replicates = number_of_null_replicates,
  ph_master_seed = ph_master_seed,
  null_master_seed = null_master_seed,
  null_design = "source-level full-source-cloud matched filled ellipsoid",
  matched_reference_rule = paste(
    "observed maximum persistence must exceed the maximum across a complete",
    "20-null matched filled-ellipsoid reference set"
  ),
  method_colours = method_colours,
  occurrence_colour = occurrence_colour
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

if (file.exists(settings_file)) {

  previous_settings <- readRDS(
    settings_file
  )

  if (
    !identical(
      previous_settings$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Existing Script-15 outputs were created under incompatible settings.\n",
      "Archive or remove 04_Topology before running the current protocol."
    )
  }
}

saveRDS(
  list(
    analysis_settings_hash = analysis_settings_hash,
    settings = analysis_settings
  ),
  settings_file,
  version = 3
)

write_csv_safely(
  expected_topology,
  expected_topology_file
)


# ============================================================
# Lock reproducible 300-point subsamples
# ============================================================

subsample_settings <- list(
  analysis_settings_hash = analysis_settings_hash,
  ph_sample_size = ph_sample_size,
  number_of_repetitions = number_of_repetitions,
  ph_master_seed = ph_master_seed
)

subsample_settings_hash <- hash_r_object(
  subsample_settings
)

create_subsample_archive <- function() {

  archive <- list()

  for (
    species_index in seq_along(
      species_order
    )
  ) {

    species_name <- species_order[[
      species_index
    ]]

    for (
      repetition in seq_len(
        number_of_repetitions
      )
    ) {

      for (
        source_index in seq_along(
          source_order
        )
      ) {

        source_name <- source_order[[
          source_index
        ]]

        current_key <- ph_key(
          species_name,
          repetition,
          source_name
        )

        points <- get_source_points(
          species_name,
          source_name
        )

        if (
          nrow(
            points
          ) <
            ph_sample_size
        ) {

          archive[[
            current_key
          ]] <- list(
            available = FALSE,
            seed = NA_integer_,
            indices = integer(0),
            source_points = nrow(
              points
            ),
            reason = paste0(
              "Source contains fewer than ",
              ph_sample_size,
              " points."
            )
          )

          next
        }

        current_seed <- (
          ph_master_seed +
            species_index *
              1000000L +
            repetition *
              10000L +
            source_index *
              100L
        )

        set.seed(
          current_seed
        )

        archive[[
          current_key
        ]] <- list(
          available = TRUE,
          seed = current_seed,
          indices = sample(
            seq_len(
              nrow(
                points
              )
            ),
            ph_sample_size,
            replace = FALSE
          ),
          source_points = nrow(
            points
          ),
          reason = NA_character_
        )
      }
    }
  }

  list(
    subsample_settings_hash = subsample_settings_hash,
    indices = archive
  )
}


if (
  resume_from_checkpoints &&
    file.exists(
      subsample_file
    )
) {

  subsample_archive <- readRDS(
    subsample_file
  )

  if (
    !identical(
      subsample_archive$subsample_settings_hash,
      subsample_settings_hash
    )
  ) {
    stop(
      "Existing Script-15 topology-subsample archive is incompatible."
    )
  }

} else {

  subsample_archive <- create_subsample_archive()

  saveRDS(
    subsample_archive,
    subsample_file,
    version = 3
  )
}


# ============================================================
# Primary persistent homology
# ============================================================

primary_ph_results <- list()

primary_ph_total <- (
  length(
    species_order
  ) *
    number_of_repetitions *
    length(
      source_order
    )
)

primary_ph_counter <- 0L

for (
  species_name in species_order
) {

  for (
    repetition in seq_len(
      number_of_repetitions
    )
  ) {

    for (
      source_name in source_order
    ) {

      primary_ph_counter <- (
        primary_ph_counter +
          1L
      )

      current_key <- ph_key(
        species_name,
        repetition,
        source_name
      )

      object_file <- primary_ph_object_path(
        species_name,
        repetition,
        source_name
      )

      existing <- NULL

      if (
        resume_from_checkpoints &&
          file.exists(
            object_file
          )
      ) {

        existing <- try(
          readRDS(
            object_file
          ),
          silent = TRUE
        )

        if (
          inherits(
            existing,
            "try-error"
          ) ||
            !identical(
              existing$analysis_settings_hash,
              analysis_settings_hash
            )
        ) {
          existing <- NULL
        }
      }

      if (
        !is.null(
          existing
        ) &&
          (
            isTRUE(
              existing$success
            ) ||
              !retry_failed_persistence
          )
      ) {

        primary_ph_results[[
          current_key
        ]] <- existing

        next
      }

      message(
        "PH calculation [",
        primary_ph_counter,
        "/",
        primary_ph_total,
        "]: ",
        current_key
      )

      index_object <- subsample_archive$indices[[
        current_key
      ]]

      if (
        is.null(
          index_object
        ) ||
          !isTRUE(
            index_object$available
          )
      ) {

        saved <- list(
          analysis_settings_hash = analysis_settings_hash,
          key = current_key,
          virtual_species = species_name,
          sample_size = analysis_sample_size,
          repetition = repetition,
          source = source_name,
          subsample_seed = if (
            is.null(
              index_object
            )
          ) {
            NA_integer_
          } else {
            index_object$seed
          },
          source_points = if (
            is.null(
              index_object
            )
          ) {
            NA_integer_
          } else {
            index_object$source_points
          },
          sampled_points = 0L,
          point_cloud_diameter = NA_real_,
          success = FALSE,
          diagram = empty_diagram(),
          runtime_seconds = 0,
          failure_type = "insufficient points",
          error_message = if (
            is.null(
              index_object
            )
          ) {
            "Missing subsample-index object."
          } else {
            index_object$reason
          }
        )

      } else {

        source_points <- get_source_points(
          species_name,
          source_name
        )

        sampled_points <- set_axis_names(
          source_points[
            index_object$indices,
            ,
            drop = FALSE
          ]
        )

        diameter <- point_cloud_diameter(
          sampled_points
        )

        ph_result <- calculate_persistence_with_timeout(
          sampled_points,
          maximum_dimension = maximum_homology_dimension
        )

        saved <- c(
          list(
            analysis_settings_hash = analysis_settings_hash,
            key = current_key,
            virtual_species = species_name,
            sample_size = analysis_sample_size,
            repetition = repetition,
            source = source_name,
            subsample_seed = index_object$seed,
            source_points = nrow(
              source_points
            ),
            sampled_points = nrow(
              sampled_points
            ),
            point_cloud_diameter = diameter
          ),
          ph_result
        )
      }

      saveRDS(
        saved,
        object_file,
        version = 3
      )

      primary_ph_results[[
        current_key
      ]] <- saved
    }
  }
}


# ============================================================
# Compile PH log and persistence tables
# ============================================================

ph_log_rows <- list()
persistence_rows <- list()
ph_log_index <- 0L
persistence_index <- 0L

for (
  species_name in species_order
) {

  for (
    repetition in seq_len(
      number_of_repetitions
    )
  ) {

    occurrence_result <- primary_ph_results[[
      ph_key(
        species_name,
        repetition,
        "Occurrence"
      )
    ]]

    occurrence_diameter <- if (
      !is.null(
        occurrence_result
      )
    ) {
      occurrence_result$point_cloud_diameter
    } else {
      NA_real_
    }

    for (
      source_name in source_order
    ) {

      current_result <- primary_ph_results[[
        ph_key(
          species_name,
          repetition,
          source_name
        )
      ]]

      if (is.null(current_result)) {
        stop(
          "Missing in-memory PH result for ",
          species_name,
          " / repetition ",
          repetition,
          " / ",
          source_name,
          "."
        )
      }

      ph_log_index <- (
        ph_log_index +
          1L
      )

      ph_log_rows[[
        ph_log_index
      ]] <- data.frame(
        Virtual_species = species_name,
        Sample_size = analysis_sample_size,
        Repetition = repetition,
        Source = source_name,
        Source_points = current_result$source_points,
        PH_points = current_result$sampled_points,
        Subsample_seed = current_result$subsample_seed,
        Point_cloud_diameter = current_result$point_cloud_diameter,
        Paired_occurrence_diameter = occurrence_diameter,
        Success = current_result$success,
        Runtime_seconds = current_result$runtime_seconds,
        Failure_type = current_result$failure_type,
        Error_message = current_result$error_message,
        stringsAsFactors = FALSE
      )

      for (
        dimension in 0:
          maximum_homology_dimension
      ) {

        maximum_persistence <- if (
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

        normalized_persistence <- if (
          isTRUE(
            current_result$success
          ) &&
            is.finite(
              occurrence_diameter
            ) &&
            occurrence_diameter > 0
        ) {
          maximum_persistence /
            occurrence_diameter
        } else {
          NA_real_
        }

        persistence_index <- (
          persistence_index +
            1L
        )

        persistence_rows[[
          persistence_index
        ]] <- data.frame(
          Virtual_species = species_name,
          Sample_size = analysis_sample_size,
          Repetition = repetition,
          Source = source_name,
          Homology_dimension = dimension,
          Success = current_result$success,
          Maximum_persistence = maximum_persistence,
          Paired_occurrence_diameter = occurrence_diameter,
          Normalized_maximum_persistence = normalized_persistence,
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

ph_log <- do.call(
  rbind,
  ph_log_rows
)

persistence_replicates <- do.call(
  rbind,
  persistence_rows
)

write_csv_safely(
  ph_log,
  ph_log_file
)

write_csv_safely(
  persistence_replicates,
  persistence_replicate_file
)


persistence_keys <- unique(
  persistence_replicates[
    ,
    c(
      "Virtual_species",
      "Sample_size",
      "Source",
      "Homology_dimension"
    ),
    drop = FALSE
  ]
)

persistence_summary_rows <- vector(
  "list",
  nrow(
    persistence_keys
  )
)

for (
  row_index in seq_len(
    nrow(
      persistence_keys
    )
  )
) {

  key <- persistence_keys[
    row_index,
    ,
    drop = FALSE
  ]

  group <- persistence_replicates[
    persistence_replicates$Virtual_species ==
      key$Virtual_species &
      persistence_replicates$Sample_size ==
        key$Sample_size &
      persistence_replicates$Source ==
        key$Source &
      persistence_replicates$Homology_dimension ==
        key$Homology_dimension,
    ,
    drop = FALSE
  ]

  complete <- group[
    group$Success &
      is.finite(
        group$Maximum_persistence
      ),
    ,
    drop = FALSE
  ]

  persistence_summary_rows[[
    row_index
  ]] <- cbind(
    key,
    data.frame(
      Repetitions_requested = number_of_repetitions,
      Repetitions_successful = nrow(
        complete
      ),
      Mean_maximum_persistence = safe_mean(
        complete$Maximum_persistence
      ),
      SD_maximum_persistence = safe_sd(
        complete$Maximum_persistence
      ),
      Mean_normalized_maximum_persistence = safe_mean(
        complete$Normalized_maximum_persistence
      ),
      SD_normalized_maximum_persistence = safe_sd(
        complete$Normalized_maximum_persistence
      ),
      stringsAsFactors = FALSE
    )
  )
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
# Bottleneck distances: each estimator vs paired occurrence cloud
# ============================================================

bottleneck_rows <- list()
bottleneck_index <- 0L

for (
  species_name in species_order
) {

  for (
    repetition in seq_len(
      number_of_repetitions
    )
  ) {

    occurrence_result <- primary_ph_results[[
      ph_key(
        species_name,
        repetition,
        "Occurrence"
      )
    ]]

    for (
      method_name in method_order
    ) {

      method_result <- primary_ph_results[[
        ph_key(
          species_name,
          repetition,
          method_name
        )
      ]]

      for (
        dimension in 0:
          maximum_homology_dimension
      ) {

        bottleneck_index <- (
          bottleneck_index +
            1L
        )

        if (
          is.null(
            occurrence_result
          ) ||
            is.null(
              method_result
            ) ||
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
            Virtual_species = species_name,
            Sample_size = analysis_sample_size,
            Repetition = repetition,
            Method = method_name,
            Homology_dimension = dimension,
            Success = FALSE,
            Bottleneck_distance = NA_real_,
            Occurrence_diameter = if (
              !is.null(
                occurrence_result
              )
            ) {
              occurrence_result$point_cloud_diameter
            } else {
              NA_real_
            },
            Normalized_bottleneck_distance = NA_real_,
            Error_message = "Occurrence or estimator PH unavailable",
            stringsAsFactors = FALSE
          )

          next
        }

        bottleneck_result <- calculate_bottleneck_safe(
          occurrence_result$diagram,
          method_result$diagram,
          dimension
        )

        normalized <- if (
          isTRUE(
            bottleneck_result$success
          ) &&
            is.finite(
              occurrence_result$point_cloud_diameter
            ) &&
            occurrence_result$point_cloud_diameter > 0
        ) {
          bottleneck_result$distance /
            occurrence_result$point_cloud_diameter
        } else {
          NA_real_
        }

        bottleneck_rows[[
          bottleneck_index
        ]] <- data.frame(
          Virtual_species = species_name,
          Sample_size = analysis_sample_size,
          Repetition = repetition,
          Method = method_name,
          Homology_dimension = dimension,
          Success = bottleneck_result$success,
          Bottleneck_distance = bottleneck_result$distance,
          Occurrence_diameter = occurrence_result$point_cloud_diameter,
          Normalized_bottleneck_distance = normalized,
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


bottleneck_keys <- unique(
  bottleneck_replicates[
    ,
    c(
      "Virtual_species",
      "Sample_size",
      "Method",
      "Homology_dimension"
    ),
    drop = FALSE
  ]
)

bottleneck_summary_rows <- vector(
  "list",
  nrow(
    bottleneck_keys
  )
)

for (
  row_index in seq_len(
    nrow(
      bottleneck_keys
    )
  )
) {

  key <- bottleneck_keys[
    row_index,
    ,
    drop = FALSE
  ]

  group <- bottleneck_replicates[
    bottleneck_replicates$Virtual_species ==
      key$Virtual_species &
      bottleneck_replicates$Sample_size ==
        key$Sample_size &
      bottleneck_replicates$Method ==
        key$Method &
      bottleneck_replicates$Homology_dimension ==
        key$Homology_dimension,
    ,
    drop = FALSE
  ]

  complete <- group[
    group$Success &
      is.finite(
        group$Bottleneck_distance
      ),
    ,
    drop = FALSE
  ]

  bottleneck_summary_rows[[
    row_index
  ]] <- cbind(
    key,
    data.frame(
      Repetitions_requested = number_of_repetitions,
      Repetitions_successful = nrow(
        complete
      ),
      Mean_bottleneck_distance = safe_mean(
        complete$Bottleneck_distance
      ),
      SD_bottleneck_distance = safe_sd(
        complete$Bottleneck_distance
      ),
      Mean_normalized_bottleneck = safe_mean(
        complete$Normalized_bottleneck_distance
      ),
      SD_normalized_bottleneck = safe_sd(
        complete$Normalized_bottleneck_distance
      ),
      stringsAsFactors = FALSE
    )
  )
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
# Matched filled-ellipsoid helper
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
      direction_norms == 0
    )
  ) {

    bad <- which(
      direction_norms == 0
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

  # Exact realised matching: centre and whiten the sampled filled unit ball,
  # then recolour it to the full source cloud's realised covariance.
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
# Matched filled-ellipsoid reference analysis
# ============================================================

null_rows <- list()
null_row_index <- 0L

number_of_reference_conditions <- (
  length(
    species_order
  ) *
    length(
      source_order
    )
)

reference_condition_counter <- 0L

for (
  species_index in seq_along(
    species_order
  )
) {

  species_name <- species_order[[
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

    reference_points <- get_source_points(
      species_name,
      source_name
    )

    condition_key <- matched_reference_key(
      species_name,
      source_name
    )

    object_file <- matched_reference_object_path(
      species_name,
      source_name
    )

    null_object <- NULL

    if (
      resume_from_checkpoints &&
        file.exists(
          object_file
        )
    ) {

      candidate <- try(
        readRDS(
          object_file
        ),
        silent = TRUE
      )

      if (
        !inherits(
          candidate,
          "try-error"
        ) &&
          identical(
            candidate$analysis_settings_hash,
            analysis_settings_hash
          ) &&
          !is.null(
            candidate$null_results
          )
      ) {
        null_object <- candidate
      }
    }

    if (is.null(null_object)) {

      null_object <- list(
        analysis_settings_hash = analysis_settings_hash,
        condition_key = condition_key,
        virtual_species = species_name,
        source = source_name,
        full_source_point_count = nrow(
          reference_points
        ),
        full_source_centroid = colMeans(
          reference_points
        ),
        full_source_covariance = stats::cov(
          reference_points
        ),
        null_results = vector(
          "list",
          number_of_null_replicates
        )
      )
    }

    if (
      length(
        null_object$null_results
      ) <
        number_of_null_replicates
    ) {

      length(
        null_object$null_results
      ) <- number_of_null_replicates
    }

    message(
      "Matched ellipsoid condition [",
      reference_condition_counter,
      "/",
      number_of_reference_conditions,
      "]: ",
      condition_key,
      " (source n=",
      nrow(
        reference_points
      ),
      ", null n=",
      ph_sample_size,
      ")"
    )

    for (
      null_repetition in seq_len(
        number_of_null_replicates
      )
    ) {

      existing_null <- null_object$null_results[[
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

      null_seed <- (
        null_master_seed +
          species_index *
            10000000L +
          source_index *
            10000L +
          null_repetition
      )

      generated_null <- generate_exact_matched_ellipsoid(
        target_points = reference_points,
        number_of_points = ph_sample_size,
        seed = null_seed
      )

      null_ph <- calculate_persistence_with_timeout(
        generated_null$points,
        maximum_dimension = maximum_homology_dimension
      )

      null_object$null_results[[
        null_repetition
      ]] <- c(
        list(
          null_repetition = null_repetition,
          seed = null_seed,
          target_point_count = generated_null$target_point_count,
          null_point_count = generated_null$null_point_count,
          centroid_error = generated_null$centroid_error,
          covariance_error = generated_null$covariance_error
        ),
        null_ph
      )

      # Save after every null replicate for restartability.
      saveRDS(
        null_object,
        object_file,
        version = 3
      )
    }

    # Compile one row per null repetition x homology dimension.
    for (
      null_repetition in seq_len(
        number_of_null_replicates
      )
    ) {

      null_result <- null_object$null_results[[
        null_repetition
      ]]

      if (is.null(null_result)) {
        next
      }

      for (
        dimension in 0:
          maximum_homology_dimension
      ) {

        null_row_index <- (
          null_row_index +
            1L
        )

        null_rows[[
          null_row_index
        ]] <- data.frame(
          Condition_key = condition_key,
          Virtual_species = species_name,
          Sample_size = analysis_sample_size,
          Source = source_name,
          Full_source_point_count = null_result$target_point_count,
          Null_point_count = null_result$null_point_count,
          Null_repetition = null_repetition,
          Null_seed = null_result$seed,
          Homology_dimension = dimension,
          Null_success = null_result$success,
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
          Null_failure_type = null_result$failure_type,
          Null_error_message = null_result$error_message,
          Centroid_error = null_result$centroid_error,
          Covariance_error = null_result$covariance_error,
          stringsAsFactors = FALSE
        )
      }
    }
  }
}


null_replicates <- if (
  length(
    null_rows
  ) > 0L
) {
  do.call(
    rbind,
    null_rows
  )
} else {
  data.frame()
}

write_csv_safely(
  null_replicates,
  null_replicate_file
)


# ============================================================
# Complete 20-null thresholds
# ============================================================

null_threshold_rows <- list()
null_threshold_index <- 0L

for (
  species_name in species_order
) {

  for (
    source_name in source_order
  ) {

    for (
      dimension in 0:
        maximum_homology_dimension
    ) {

      group <- null_replicates[
        null_replicates$Virtual_species ==
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
        Virtual_species = species_name,
        Sample_size = analysis_sample_size,
        Source = source_name,
        Homology_dimension = dimension,
        Null_replicates_requested = number_of_null_replicates,
        Null_replicates_successful = nrow(
          successful
        ),
        Complete_20_null_reference = complete_reference,
        Mean_null_maximum_persistence = if (
          nrow(
            successful
          ) > 0L
        ) {
          mean(
            successful$Null_maximum_persistence
          )
        } else {
          NA_real_
        },
        SD_null_maximum_persistence = if (
          nrow(
            successful
          ) > 1L
        ) {
          stats::sd(
            successful$Null_maximum_persistence
          )
        } else {
          NA_real_
        },
        Maximum_null_persistence = if (
          complete_reference
        ) {
          max(
            successful$Null_maximum_persistence
          )
        } else {
          NA_real_
        },
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
  species_name in species_order
) {

  for (
    source_name in source_order
  ) {

    for (
      dimension in 0:
        maximum_homology_dimension
    ) {

      threshold_row <- null_thresholds[
        null_thresholds$Virtual_species ==
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

      threshold <- threshold_row$Maximum_null_persistence[[1L]]
      reference_complete <- isTRUE(
        threshold_row$Complete_20_null_reference[[1L]]
      )

      for (
        repetition in seq_len(
          number_of_repetitions
        )
      ) {

        observed_result <- primary_ph_results[[
          ph_key(
            species_name,
            repetition,
            source_name
          )
        ]]

        observed_success <- (
          !is.null(
            observed_result
          ) &&
            isTRUE(
              observed_result$success
            )
        )

        observed_max <- if (
          observed_success
        ) {
          max_finite_persistence(
            observed_result$diagram,
            dimension
          )
        } else {
          NA_real_
        }

        exceeds <- if (
          observed_success &&
            reference_complete &&
            is.finite(
              threshold
            )
        ) {
          observed_max >
            threshold
        } else {
          NA
        }

        null_observed_index <- (
          null_observed_index +
            1L
        )

        null_observed_rows[[
          null_observed_index
        ]] <- data.frame(
          Virtual_species = species_name,
          Sample_size = analysis_sample_size,
          Repetition = repetition,
          Source = source_name,
          Homology_dimension = dimension,
          Observed_PH_success = observed_success,
          Null_replicates_requested = number_of_null_replicates,
          Null_replicates_successful = threshold_row$Null_replicates_successful[[1L]],
          Complete_20_null_reference = reference_complete,
          Observed_maximum_persistence = observed_max,
          Maximum_null_persistence = threshold,
          Exceeds_matched_ellipsoid_reference = exceeds,
          Persistence_ratio_observed_to_null_max = if (
            observed_success &&
              reference_complete &&
              is.finite(
                threshold
              ) &&
              threshold > 0
          ) {
            observed_max /
              threshold
          } else {
            NA_real_
          },
          Persistence_difference_observed_minus_null_max = if (
            observed_success &&
              reference_complete &&
              is.finite(
                threshold
              )
          ) {
            observed_max -
              threshold
          } else {
            NA_real_
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
# Exceedance-proportion summary
# ============================================================

null_summary_rows <- list()
null_summary_index <- 0L

for (
  species_name in species_order
) {

  for (
    source_name in source_order
  ) {

    for (
      dimension in 0:
        maximum_homology_dimension
    ) {

      group <- null_observed_results[
        null_observed_results$Virtual_species ==
          species_name &
          null_observed_results$Source ==
            source_name &
          null_observed_results$Homology_dimension ==
            dimension,
        ,
        drop = FALSE
      ]

      complete <- group[
        !is.na(
          group$Exceeds_matched_ellipsoid_reference
        ),
        ,
        drop = FALSE
      ]

      null_summary_index <- (
        null_summary_index +
          1L
      )

      null_summary_rows[[
        null_summary_index
      ]] <- data.frame(
        Virtual_species = species_name,
        Sample_size = analysis_sample_size,
        Source = source_name,
        Homology_dimension = dimension,
        Observed_repetitions_requested = number_of_repetitions,
        Observed_repetitions_evaluable = nrow(
          complete
        ),
        Null_replicates_requested = number_of_null_replicates,
        Null_replicates_successful = if (
          nrow(
            group
          ) > 0L
        ) {
          group$Null_replicates_successful[[1L]]
        } else {
          NA_integer_
        },
        Complete_20_null_reference = if (
          nrow(
            group
          ) > 0L
        ) {
          group$Complete_20_null_reference[[1L]]
        } else {
          FALSE
        },
        Number_exceeding_matched_ellipsoid_reference = sum(
          complete$Exceeds_matched_ellipsoid_reference
        ),
        Exceedance_proportion = if (
          nrow(
            complete
          ) > 0L
        ) {
          mean(
            complete$Exceeds_matched_ellipsoid_reference
          )
        } else {
          NA_real_
        },
        Mean_observed_maximum_persistence = safe_mean(
          complete$Observed_maximum_persistence
        ),
        SD_observed_maximum_persistence = safe_sd(
          complete$Observed_maximum_persistence
        ),
        Maximum_null_persistence = if (
          nrow(
            group
          ) > 0L
        ) {
          group$Maximum_null_persistence[[1L]]
        } else {
          NA_real_
        },
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


target_null_summary <- merge(
  target_feature_table,
  null_summary,
  by = c(
    "Virtual_species",
    "Homology_dimension"
  ),
  all.x = TRUE,
  sort = FALSE
)

target_null_summary$Source <- factor(
  target_null_summary$Source,
  levels = source_order
)

target_null_summary <- target_null_summary[
  order(
    match(
      target_null_summary$Virtual_species,
      species_order
    ),
    target_null_summary$Homology_dimension,
    target_null_summary$Source
  ),
  ,
  drop = FALSE
]

target_null_summary$Source <- as.character(
  target_null_summary$Source
)

write_csv_safely(
  target_null_summary,
  target_null_summary_file
)


occurrence_qa <- target_null_summary[
  target_null_summary$Source ==
    "Occurrence",
  ,
  drop = FALSE
]

write_csv_safely(
  occurrence_qa,
  occurrence_qa_file
)


# ============================================================
# Joint occurrence + estimator feature retention
# ============================================================

feature_retention_rows <- list()
feature_retention_index <- 0L

for (
  feature_index in seq_len(
    nrow(
      target_feature_table
    )
  )
) {

  feature_row <- target_feature_table[
    feature_index,
    ,
    drop = FALSE
  ]

  species_name <- feature_row$Virtual_species[[1L]]
  dimension <- feature_row$Homology_dimension[[1L]]

  for (
    method_name in method_order
  ) {

    for (
      repetition in seq_len(
        number_of_repetitions
      )
    ) {

      occurrence_row <- null_observed_results[
        null_observed_results$Virtual_species ==
          species_name &
          null_observed_results$Source ==
            "Occurrence" &
          null_observed_results$Homology_dimension ==
            dimension &
          null_observed_results$Repetition ==
            repetition,
        ,
        drop = FALSE
      ]

      estimator_row <- null_observed_results[
        null_observed_results$Virtual_species ==
          species_name &
          null_observed_results$Source ==
            method_name &
          null_observed_results$Homology_dimension ==
            dimension &
          null_observed_results$Repetition ==
            repetition,
        ,
        drop = FALSE
      ]

      if (
        nrow(
          occurrence_row
        ) != 1L ||
          nrow(
            estimator_row
          ) != 1L
      ) {
        stop(
          "Could not uniquely pair matched-reference results for ",
          species_name,
          " / H",
          dimension,
          " / ",
          method_name,
          " / repetition ",
          repetition,
          "."
        )
      }

      occurrence_exceeds <- occurrence_row$Exceeds_matched_ellipsoid_reference[[1L]]
      estimator_exceeds <- estimator_row$Exceeds_matched_ellipsoid_reference[[1L]]

      evaluable <- (
        !is.na(
          occurrence_exceeds
        ) &&
          !is.na(
            estimator_exceeds
          )
      )

      feature_retained <- if (
        evaluable
      ) {
        isTRUE(
          occurrence_exceeds
        ) &&
          isTRUE(
            estimator_exceeds
          )
      } else {
        NA
      }

      feature_retention_index <- (
        feature_retention_index +
          1L
      )

      feature_retention_rows[[
        feature_retention_index
      ]] <- data.frame(
        Virtual_species = species_name,
        Sample_size = analysis_sample_size,
        Feature = feature_row$Feature[[1L]],
        Expected_signal = feature_row$Expected_signal[[1L]],
        Homology_dimension = dimension,
        Repetition = repetition,
        Method = method_name,
        Occurrence_exceeds_reference = occurrence_exceeds,
        Estimator_exceeds_reference = estimator_exceeds,
        Evaluable_pair = evaluable,
        Feature_retained = feature_retained,
        stringsAsFactors = FALSE
      )
    }
  }
}

feature_retention_replicates <- do.call(
  rbind,
  feature_retention_rows
)

write_csv_safely(
  feature_retention_replicates,
  feature_retention_replicate_file
)


retention_summary_rows <- list()
retention_summary_index <- 0L

for (
  feature_index in seq_len(
    nrow(
      target_feature_table
    )
  )
) {

  feature_row <- target_feature_table[
    feature_index,
    ,
    drop = FALSE
  ]

  for (
    method_name in method_order
  ) {

    group <- feature_retention_replicates[
      feature_retention_replicates$Virtual_species ==
        feature_row$Virtual_species[[1L]] &
        feature_retention_replicates$Homology_dimension ==
          feature_row$Homology_dimension[[1L]] &
        feature_retention_replicates$Method ==
          method_name,
      ,
      drop = FALSE
    ]

    evaluable <- group[
      group$Evaluable_pair,
      ,
      drop = FALSE
    ]

    retention_summary_index <- (
      retention_summary_index +
        1L
    )

    retention_summary_rows[[
      retention_summary_index
    ]] <- data.frame(
      Virtual_species = feature_row$Virtual_species[[1L]],
      Sample_size = analysis_sample_size,
      Feature = feature_row$Feature[[1L]],
      Expected_signal = feature_row$Expected_signal[[1L]],
      Homology_dimension = feature_row$Homology_dimension[[1L]],
      Method = method_name,
      Repetitions_requested = number_of_repetitions,
      Repetitions_evaluable = nrow(
        evaluable
      ),
      Occurrence_exceedance_proportion = if (
        nrow(
          evaluable
        ) > 0L
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
        ) > 0L
      ) {
        mean(
          evaluable$Estimator_exceeds_reference
        )
      } else {
        NA_real_
      },
      Joint_exceedance_proportion = if (
        nrow(
          evaluable
        ) > 0L
      ) {
        mean(
          evaluable$Feature_retained
        )
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }
}

feature_retention_summary <- do.call(
  rbind,
  retention_summary_rows
)

write_csv_safely(
  feature_retention_summary,
  feature_retention_summary_file
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

    failure_index <- (
      failure_index +
        1L
    )

    failure_rows[[
      failure_index
    ]] <- data.frame(
      Analysis_stage = "Primary PH",
      Virtual_species = failed_primary$Virtual_species[[row_index]],
      Source = failed_primary$Source[[row_index]],
      Repetition = failed_primary$Repetition[[row_index]],
      Homology_dimension = NA_integer_,
      Failure_type = failed_primary$Failure_type[[row_index]],
      Error_message = failed_primary$Error_message[[row_index]],
      stringsAsFactors = FALSE
    )
  }
}


failed_nulls <- null_replicates[
  !null_replicates$Null_success,
  ,
  drop = FALSE
]

if (nrow(failed_nulls) > 0L) {

  unique_failed_nulls <- failed_nulls[
    !duplicated(
      failed_nulls[
        ,
        c(
          "Virtual_species",
          "Source",
          "Null_repetition"
        ),
        drop = FALSE
      ]
    ),
    ,
    drop = FALSE
  ]

  for (
    row_index in seq_len(
      nrow(
        unique_failed_nulls
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
      Analysis_stage = "Matched ellipsoid PH",
      Virtual_species = unique_failed_nulls$Virtual_species[[row_index]],
      Source = unique_failed_nulls$Source[[row_index]],
      Repetition = unique_failed_nulls$Null_repetition[[row_index]],
      Homology_dimension = NA_integer_,
      Failure_type = unique_failed_nulls$Null_failure_type[[row_index]],
      Error_message = unique_failed_nulls$Null_error_message[[row_index]],
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

    failure_index <- (
      failure_index +
        1L
    )

    failure_rows[[
      failure_index
    ]] <- data.frame(
      Analysis_stage = "Bottleneck distance",
      Virtual_species = failed_bottleneck$Virtual_species[[row_index]],
      Source = failed_bottleneck$Method[[row_index]],
      Repetition = failed_bottleneck$Repetition[[row_index]],
      Homology_dimension = failed_bottleneck$Homology_dimension[[row_index]],
      Failure_type = "bottleneck failure",
      Error_message = failed_bottleneck$Error_message[[row_index]],
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
    Virtual_species = character(0),
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
# Final topology object
# ============================================================

final_results <- list(
  metadata = list(
    script = "15_Virtual_Species_Topology_n900.R",
    analysis_settings_hash = analysis_settings_hash,
    locked_design_hash = locked_design_hash,
    baseline_analysis_hash = baseline_analysis_hash,
    completed_at = as.character(
      Sys.time()
    )
  ),
  analysis_settings = analysis_settings,
  expected_topology = expected_topology,
  target_feature_table = target_feature_table,
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
  target_matched_ellipsoid_exceedance_summary = target_null_summary,
  occurrence_matched_ellipsoid_qa = occurrence_qa,
  feature_retention_replicates = feature_retention_replicates,
  feature_retention_summary = feature_retention_summary,
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
  "\nNORMALISED BOTTLENECK SUMMARY:"
)

print(
  bottleneck_summary[
    ,
    c(
      "Virtual_species",
      "Method",
      "Homology_dimension",
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
  "\nTARGET matched filled-ellipsoid exceedance summary:"
)

print(
  target_null_summary[
    ,
    c(
      "Virtual_species",
      "Feature",
      "Expected_signal",
      "Source",
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
  "\nFEATURE RETENTION / JOINT EXCEEDANCE:"
)

print(
  feature_retention_summary,
  digits = 5,
  row.names = FALSE
)


# ============================================================
# Notes and session information
# ============================================================

analysis_notes <- c(
  "Revised virtual-species topology at n = 900",
  "============================================",
  "",
  "Species:",
  "  Unimodal Gaussian-PCA",
  "  Disconnected bimodal",
  "",
  "Formal topological reference:",
  "  occurrence cloud",
  "",
  "Generating expectations:",
  "  Unimodal: beta0=1, beta1=0, beta2=0; H1/H2 negative controls.",
  "  Disconnected: beta0=2, beta1=0, beta2=0; finite H0 separation target.",
  "",
  "Primary persistent homology:",
  "  300 points per source",
  "  10 reproducible repetitions",
  "  H0-H2",
  "  TDAstats::calculate_homology()",
  "  threshold=-1",
  "  no coordinate standardisation when supported",
  "  p=2 when supported",
  "  6-minute limit per PH calculation",
  "",
  "Bottleneck:",
  "  estimator diagram compared with paired occurrence diagram",
  "  separately for H0, H1 and H2",
  "  divided by paired occurrence-cloud diameter",
  "",
  "Matched filled-ellipsoid reference:",
  "  20 reference clouds per species x source",
  "  8 source-level reference conditions",
  "  160 requested matched-reference PH calls",
  "  each reference contains 300 points",
  "  matching target is the full source-cloud centroid and covariance",
  "  one complete 20-null maximum is shared across the ten observed repetitions",
  "  incomplete 20-null sets are not used for exceedance classification",
  "  aggregate output is Exceedance_proportion",
  "",
  "Feature retention:",
  "  occurrence and estimator must both exceed their own matched-reference",
  "  thresholds in the same repetition.",
  "",
  "No topology sensitivity analysis is performed here.",
  "Publication figures are deferred to the final consolidation script.",
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
    "Matched-reference PH successes: ",
    length(
      unique(
        paste(
          null_replicates$Virtual_species[
            null_replicates$Null_success
          ],
          null_replicates$Source[
            null_replicates$Null_success
          ],
          null_replicates$Null_repetition[
            null_replicates$Null_success
          ],
          sep = "||"
        )
      )
    ),
    " / ",
    number_of_reference_conditions *
      number_of_null_replicates
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
  "15_Virtual_Species_Topology_n900.R complete."
)

message(
  "Primary PH successes: ",
  sum(
    ph_log$Success
  ),
  " / ",
  nrow(
    ph_log
  )
)

message(
  "Matched-reference PH condition-replicates successful: ",
  length(
    unique(
      paste(
        null_replicates$Virtual_species[
          null_replicates$Null_success
        ],
        null_replicates$Source[
          null_replicates$Null_success
        ],
        null_replicates$Null_repetition[
          null_replicates$Null_success
        ],
        sep = "||"
      )
    )
  ),
  " / ",
  number_of_reference_conditions *
    number_of_null_replicates
)

message(
  "Failures recorded: ",
  nrow(
    failure_table
  )
)

message(
  "Bottleneck summary:\n  ",
  normalizePath(
    bottleneck_summary_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "Matched-reference exceedance summary:\n  ",
  normalizePath(
    null_summary_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "Feature-retention summary:\n  ",
  normalizePath(
    feature_retention_summary_file,
    winslash = "/",
    mustWork = FALSE
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
