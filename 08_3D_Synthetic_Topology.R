# ============================================================
# 08_3D_Synthetic_Topology.R
# ============================================================
#
# Complete baseline topology analysis for the FINAL revised
# three-dimensional synthetic benchmark.
#
#


rm(list = ls())
gc()


# ============================================================
# Project paths
# ============================================================

# Run from the repository's root folder.
project_directory <- "."

analysis_root_directory <- file.path(
  project_directory,
  "Results",
  "3D_Synthetic_sqrtNB_q099"
)

baseline_output_directory <- file.path(
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

null_directory <- file.path(
  output_directory,
  "matched_ellipsoid_objects"
)

for (current_directory in c(
  output_directory,
  primary_ph_directory,
  null_directory
)) {
  dir.create(
    current_directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ============================================================
# Required packages
# ============================================================

required_packages <- c(
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

if (length(
  missing_packages
) > 0L) {
  stop(
    "Install the following required package(s) before running Script 08: ",
    paste(
      missing_packages,
      collapse = ", "
    )
  )
}

library(TDAstats)
library(TDA)
library(R.utils)


# ============================================================
# Locked analysis settings
# ============================================================

master_seed <- 812301L

shape_order <- c(
  "solid_ball",
  "solid_torus",
  "hollow_shell"
)

shape_labels <- c(
  solid_ball = "Solid ball",
  solid_torus = "Solid torus",
  hollow_shell = "Hollow spherical region"
)

expected_beta <- list(
  solid_ball = c(
    H0 = 1L,
    H1 = 0L,
    H2 = 0L
  ),
  solid_torus = c(
    H0 = 1L,
    H1 = 1L,
    H2 = 0L
  ),
  hollow_shell = c(
    H0 = 1L,
    H1 = 0L,
    H2 = 1L
  )
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

source_order <- c(
  "Occurrence",
  method_order
)

# PH settings.
ph_sample_size <- 300L
number_of_repetitions <- 10L
maximum_homology_dimension <- 2L
ph_threshold <- -1
ph_prime_field <- 2L
ph_standardize <- FALSE
ph_timeout_seconds <- 6 * 60

# Matched filled-ellipsoid references.
number_of_null_replicates <- 20L
null_master_seed <- 712331L

# Restart controls.
resume_from_checkpoints <- TRUE
retry_failed_persistence <- TRUE
retry_incomplete_nulls <- TRUE

# Expected revised baseline definitions.
expected_qph_core_version <- "sqrtNB_q099_v1"
expected_qph_q <- 0.99
expected_kde_quantile <- 0.95
expected_svm_nu <- 0.01
expected_svm_gamma <- 0.50
expected_svm_scale_factor <- 1

# Locked colours for downstream figures.
method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)

true_region_colour <- "#D9D9D9"
occurrence_colour <- "#111111"


# ============================================================
# Input/output files
# ============================================================

baseline_results_file <- file.path(
  baseline_output_directory,
  "baseline_fit_results_3D_sqrtNB_q099.rds"
)

ph_subsample_file <- file.path(
  output_directory,
  "topology_subsample_indices_3D_sqrtNB_q099.rds"
)

primary_ph_registry_file <- file.path(
  output_directory,
  "primary_ph_registry_3D_sqrtNB_q099.rds"
)

ph_log_file <- file.path(
  output_directory,
  "primary_ph_computational_log_3D_sqrtNB_q099.csv"
)

persistence_diagram_file <- file.path(
  output_directory,
  "persistence_diagrams_3D_sqrtNB_q099.csv"
)

maximum_persistence_replicate_file <- file.path(
  output_directory,
  "maximum_persistence_replicates_3D_sqrtNB_q099.csv"
)

maximum_persistence_summary_file <- file.path(
  output_directory,
  "maximum_persistence_mean_sd_3D_sqrtNB_q099.csv"
)

bottleneck_replicate_file <- file.path(
  output_directory,
  "bottleneck_replicates_3D_sqrtNB_q099.csv"
)

bottleneck_summary_file <- file.path(
  output_directory,
  "bottleneck_mean_sd_3D_sqrtNB_q099.csv"
)

null_replicate_file <- file.path(
  output_directory,
  "matched_ellipsoid_null_replicates_3D_sqrtNB_q099.csv"
)

null_observed_results_file <- file.path(
  output_directory,
  "matched_ellipsoid_observed_results_3D_sqrtNB_q099.csv"
)

null_summary_file <- file.path(
  output_directory,
  "matched_ellipsoid_exceedance_summary_3D_sqrtNB_q099.csv"
)

null_diagnostic_file <- file.path(
  output_directory,
  "matched_ellipsoid_generation_diagnostics_3D_sqrtNB_q099.csv"
)

topology_results_file <- file.path(
  output_directory,
  "synthetic_topology_results_3D_sqrtNB_q099.rds"
)

failure_file <- file.path(
  output_directory,
  "topology_failures_3D_sqrtNB_q099.csv"
)

analysis_settings_file <- file.path(
  output_directory,
  "topology_analysis_settings_3D_sqrtNB_q099.rds"
)

notes_file <- file.path(
  output_directory,
  "TOPOLOGY_ANALYSIS_NOTES_3D_sqrtNB_q099.txt"
)

session_information_file <- file.path(
  output_directory,
  "topology_session_information_3D_sqrtNB_q099.txt"
)

if (!file.exists(
  baseline_results_file
)) {
  stop(
    "Revised Script 06 baseline results were not found:\n  ",
    baseline_results_file,
    "\nRun 06_3D_Synthetic_Baseline_Fits.R first."
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
    pattern = "3d_topology_hash_",
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


write_csv_safely <- function(
    x,
    file
) {

  tryCatch(
    {
      utils::write.csv(
        x,
        file = file,
        row.names = FALSE
      )

      invisible(
        file
      )
    },
    error = function(error_condition) {

      alternative_file <- sub(
        "\\.csv$",
        paste0(
          "_new_",
          format(
            Sys.time(),
            "%Y%m%d_%H%M%S"
          ),
          ".csv"
        ),
        file
      )

      warning(
        "Could not overwrite ",
        basename(
          file
        ),
        "; writing ",
        basename(
          alternative_file
        ),
        " instead. Original error: ",
        conditionMessage(
          error_condition
        )
      )

      utils::write.csv(
        x,
        file = alternative_file,
        row.names = FALSE
      )

      invisible(
        alternative_file
      )
    }
  )
}


safe_mean <- function(x) {

  x <- x[
    is.finite(
      x
    )
  ]

  if (length(
    x
  ) == 0L) {
    return(
      NA_real_
    )
  }

  mean(
    x
  )
}


safe_sd <- function(x) {

  x <- x[
    is.finite(
      x
    )
  ]

  if (length(
    x
  ) <= 1L) {
    return(
      NA_real_
    )
  }

  stats::sd(
    x
  )
}


format_mean_sd <- function(
    mean_value,
    sd_value,
    digits = 4L
) {

  if (!is.finite(
    mean_value
  )) {
    return(
      NA_character_
    )
  }

  if (!is.finite(
    sd_value
  )) {
    return(
      formatC(
        mean_value,
        digits = digits,
        format = "fg"
      )
    )
  }

  paste0(
    formatC(
      mean_value,
      digits = digits,
      format = "fg"
    ),
    " +/- ",
    formatC(
      sd_value,
      digits = digits,
      format = "fg"
    )
  )
}


set_axis_names <- function(x) {

  x <- as.matrix(
    x
  )

  storage.mode(
    x
  ) <- "double"

  if (
    nrow(
      x
    ) < 1L ||
      ncol(
        x
      ) != 3L ||
      any(
        !is.finite(
          x
        )
      )
  ) {
    stop(
      "Expected a finite n x 3 point matrix."
    )
  }

  colnames(
    x
  ) <- c(
    "X1",
    "X2",
    "X3"
  )

  x
}


standardise_hv <- function(hv) {

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

  if (ncol(
    hv@Data
  ) == 3L) {
    colnames(
      hv@Data
    ) <- c(
      "X1",
      "X2",
      "X3"
    )
  }

  if (ncol(
    hv@RandomPoints
  ) == 3L) {
    colnames(
      hv@RandomPoints
    ) <- c(
      "X1",
      "X2",
      "X3"
    )
  }

  methods::validObject(
    hv
  )

  hv
}


method_key <- function(method_name) {

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

  if (identical(
    source_name,
    "Occurrence"
  )) {
    return(
      "occurrence"
    )
  }

  method_key(
    source_name
  )
}


scenario_name_for <- function(
    shape_name,
    sample_size
) {

  paste(
    shape_name,
    sample_size,
    sep = "_"
  )
}


ph_key <- function(
    shape_name,
    sample_size,
    repetition,
    source_name
) {

  paste(
    shape_name,
    paste0(
      "n",
      sample_size
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


# ============================================================
# Load and validate Script 06 baseline output
# ============================================================

baseline_results <- readRDS(
  baseline_results_file
)

if (
  !is.list(
    baseline_results
  ) ||
    is.null(
      baseline_results$metadata
    ) ||
    is.null(
      baseline_results$occurrence_archive
    ) ||
    is.null(
      baseline_results$scenarios
    )
) {
  stop(
    "The Script 06 baseline object has an unexpected structure."
  )
}

baseline_metadata <- baseline_results$metadata
occurrence_archive <- baseline_results$occurrence_archive
baseline_scenarios <- baseline_results$scenarios

if (!identical(
  as.character(
    baseline_metadata$script
  ),
  "06_3D_Synthetic_Baseline_Fits.R"
)) {
  stop(
    "The supplied baseline object was not created by revised Script 06."
  )
}

if (!identical(
  as.character(
    baseline_metadata$qph_core_version
  ),
  expected_qph_core_version
)) {
  stop(
    "The baseline object does not use the expected revised QPH core."
  )
}

if (!identical(
  as.integer(
    baseline_metadata$sample_sizes
  ),
  sample_sizes
)) {
  stop(
    "Unexpected sample sizes in the Script 06 baseline object."
  )
}

if (!identical(
  as.character(
    baseline_metadata$shape_order
  ),
  shape_order
)) {
  stop(
    "Unexpected shape order in the Script 06 baseline object."
  )
}

if (!isTRUE(all.equal(
  as.numeric(
    baseline_metadata$qph_q
  ),
  expected_qph_q
))) {
  stop(
    "The Script 06 baseline does not use QPH q = 0.99."
  )
}

if (!isTRUE(all.equal(
  as.numeric(
    baseline_metadata$kde_probability_quantile
  ),
  expected_kde_quantile
))) {
  stop(
    "The Script 06 baseline does not use KDE quantile = 0.95."
  )
}

if (!isTRUE(all.equal(
  as.numeric(
    baseline_metadata$svm_nu
  ),
  expected_svm_nu
))) {
  stop(
    "The Script 06 baseline does not use SVM nu = 0.01."
  )
}

if (!isTRUE(all.equal(
  as.numeric(
    baseline_metadata$svm_gamma
  ),
  expected_svm_gamma
))) {
  stop(
    "The Script 06 baseline does not use SVM gamma = 0.50."
  )
}

if (!isTRUE(all.equal(
  as.numeric(
    baseline_metadata$svm_scale_factor
  ),
  expected_svm_scale_factor
))) {
  stop(
    "The Script 06 baseline does not use SVM scale.factor = 1."
  )
}


# ============================================================
# Verify every expected scenario and source cloud
# ============================================================

for (shape_name in shape_order) {

  archived_beta <- occurrence_archive$master_datasets[[
    shape_name
  ]]$expected_beta

  if (!identical(
    as.integer(
      archived_beta
    ),
    as.integer(
      expected_beta[[
        shape_name
      ]]
    )
  )) {
    stop(
      "Expected Betti numbers do not match the locked design for ",
      shape_name,
      "."
    )
  }

  for (current_sample_size in sample_sizes) {

    scenario_name <- scenario_name_for(
      shape_name,
      current_sample_size
    )

    scenario <- baseline_scenarios[[
      scenario_name
    ]]

    if (is.null(
      scenario
    )) {
      stop(
        "Missing baseline scenario: ",
        scenario_name,
        "."
      )
    }

    occurrence_points <- set_axis_names(
      occurrence_archive$occurrence_subsets[[
        shape_name
      ]][[
        as.character(
          current_sample_size
        )
      ]]$points
    )

    if (!identical(
      nrow(
        occurrence_points
      ),
      as.integer(
        current_sample_size
      )
    )) {
      stop(
        "Occurrence sample-size mismatch in ",
        scenario_name,
        "."
      )
    }

    for (method_name in method_order) {

      fitted_record <- scenario[[
        method_key(
          method_name
        )
      ]]

      if (
        is.null(
          fitted_record
        ) ||
          !isTRUE(
            fitted_record$success
          )
      ) {
        warning(
          "Baseline fit unavailable for ",
          scenario_name,
          " / ",
          method_name,
          ". PH rows for this source will be recorded as failures."
        )
        next
      }

      hv <- standardise_hv(
        fitted_record$hypervolume
      )

      if (nrow(
        hv@RandomPoints
      ) < ph_sample_size) {
        stop(
          "Baseline hypervolume has fewer than ",
          ph_sample_size,
          " random points for ",
          scenario_name,
          " / ",
          method_name,
          "."
        )
      }
    }
  }
}

message(
  "Verified revised Script 06 inputs for the 3D topology analysis."
)


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

  if (is.null(
    diagram
  )) {
    return(
      empty_diagram()
    )
  }

  diagram <- as.matrix(
    diagram
  )

  if (nrow(
    diagram
  ) == 0L) {
    return(
      empty_diagram()
    )
  }

  if (ncol(
    diagram
  ) < 3L) {
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
    ] == dimension,
    ,
    drop = FALSE
  ]

  if (nrow(
    relevant_rows
  ) == 0L) {
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

  if (length(
    persistence
  ) == 0L) {
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

  if (nrow(
    points
  ) < 2L) {
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
# Analysis signature
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

installed_r_utils_version <- as.character(
  utils::packageVersion(
    "R.utils"
  )
)

analysis_settings <- list(
  script = "08_3D_Synthetic_Topology.R",
  baseline_results_file = baseline_results_file,
  baseline_results_md5 = safe_md5(
    baseline_results_file
  ),
  master_seed = master_seed,
  shape_order = shape_order,
  shape_labels = shape_labels,
  expected_beta = expected_beta,
  sample_sizes = sample_sizes,
  method_order = method_order,
  source_order = source_order,
  ph_sample_size = ph_sample_size,
  number_of_repetitions = number_of_repetitions,
  maximum_homology_dimension = maximum_homology_dimension,
  ph_threshold = ph_threshold,
  ph_prime_field = ph_prime_field,
  ph_standardize = ph_standardize,
  ph_timeout_seconds = ph_timeout_seconds,
  number_of_null_replicates = number_of_null_replicates,
  null_master_seed = null_master_seed,
  package_versions = list(
    TDAstats = installed_tda_stats_version,
    TDA = installed_tda_version,
    R.utils = installed_r_utils_version
  ),
  method_colours = method_colours,
  true_region_colour = true_region_colour,
  occurrence_colour = occurrence_colour
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

saveRDS(
  list(
    analysis_settings_hash = analysis_settings_hash,
    analysis_settings = analysis_settings,
    created_at = as.character(
      Sys.time()
    )
  ),
  analysis_settings_file,
  version = 3
)


# ============================================================
# Lock primary topology subsample indices
# ============================================================
#
# Original seed rule retained exactly:
#
# occurrence_seed = master_seed
#                   + 900000
#                   + shape_index * 10000
#                   + sample_size * 10
#                   + repetition
#
# Estimator source seed = occurrence_seed + source_index * 1000000
# where source_order = Occurrence, QPH, Gaussian KDE, SVM.
# ============================================================

subsample_settings <- list(
  baseline_results_md5 = safe_md5(
    baseline_results_file
  ),
  master_seed = master_seed,
  shape_order = shape_order,
  sample_sizes = sample_sizes,
  source_order = source_order,
  ph_sample_size = ph_sample_size,
  number_of_repetitions = number_of_repetitions
)

subsample_settings_hash <- hash_r_object(
  subsample_settings
)

if (file.exists(
  ph_subsample_file
)) {

  subsample_archive <- readRDS(
    ph_subsample_file
  )

  if (
    !is.list(
      subsample_archive
    ) ||
      !identical(
        subsample_archive$subsample_settings_hash,
        subsample_settings_hash
      )
  ) {
    stop(
      "Existing 3D topology subsample archive was produced with different ",
      "inputs or settings."
    )
  }

  ph_subsample_indices <- subsample_archive$indices

  message(
    "Loaded compatible locked primary PH subsample indices."
  )

} else {

  ph_subsample_indices <- list()

  for (
    shape_index in seq_along(
      shape_order
    )
  ) {

    shape_name <- shape_order[[
      shape_index
    ]]

    for (current_sample_size in sample_sizes) {

      scenario_name <- scenario_name_for(
        shape_name,
        current_sample_size
      )

      scenario <- baseline_scenarios[[
        scenario_name
      ]]

      for (
        repetition in seq_len(
          number_of_repetitions
        )
      ) {

        occurrence_seed <- as.integer(
          master_seed +
            900000L +
            shape_index * 10000L +
            current_sample_size * 10L +
            repetition
        )

        set.seed(
          occurrence_seed
        )

        occurrence_indices <- sample(
          seq_len(
            current_sample_size
          ),
          size = ph_sample_size,
          replace = FALSE
        )

        for (
          source_index in seq_along(
            source_order
          )
        ) {

          source_name <- source_order[[
            source_index
          ]]

          current_key <- ph_key(
            shape_name,
            current_sample_size,
            repetition,
            source_name
          )

          if (identical(
            source_name,
            "Occurrence"
          )) {

            selected_indices <- occurrence_indices
            source_seed <- occurrence_seed
            number_of_source_points <- current_sample_size

          } else {

            fitted_record <- scenario[[
              method_key(
                source_name
              )
            ]]

            if (
              is.null(
                fitted_record
              ) ||
                !isTRUE(
                  fitted_record$success
                ) ||
                is.null(
                  fitted_record$hypervolume
                )
            ) {
              next
            }

            number_of_source_points <- nrow(
              fitted_record$hypervolume@RandomPoints
            )

            if (number_of_source_points < ph_sample_size) {
              stop(
                "Hypervolume has fewer than ",
                ph_sample_size,
                " points for ",
                current_key,
                "."
              )
            }

            source_seed <- as.integer(
              occurrence_seed +
                source_index * 1000000L
            )

            set.seed(
              source_seed
            )

            selected_indices <- sample(
              seq_len(
                number_of_source_points
              ),
              size = ph_sample_size,
              replace = FALSE
            )
          }

          ph_subsample_indices[[current_key]] <- list(
            key = current_key,
            seed = source_seed,
            source_point_count = as.integer(
              number_of_source_points
            ),
            indices = as.integer(
              selected_indices
            )
          )
        }
      }
    }
  }

  saveRDS(
    list(
      subsample_settings_hash = subsample_settings_hash,
      subsample_settings = subsample_settings,
      indices = ph_subsample_indices,
      created_at = as.character(
        Sys.time()
      )
    ),
    ph_subsample_file,
    version = 3
  )
}


# ============================================================
# Primary PH calculations
# ============================================================
#
# 3 shapes x 3 sizes x 4 sources x 10 repetitions = 360 PH clouds.
# ============================================================

if (
  resume_from_checkpoints &&
    file.exists(
      primary_ph_registry_file
    )
) {

  primary_registry_archive <- readRDS(
    primary_ph_registry_file
  )

  if (!identical(
    primary_registry_archive$analysis_settings_hash,
    analysis_settings_hash
  )) {
    stop(
      "Existing primary PH registry was produced with different settings."
    )
  }

  primary_ph_registry <- primary_registry_archive$registry

} else {

  primary_ph_registry <- list()
}


save_primary_registry <- function() {

  saveRDS(
    list(
      analysis_settings_hash = analysis_settings_hash,
      registry = primary_ph_registry,
      last_updated = as.character(
        Sys.time()
      )
    ),
    primary_ph_registry_file,
    version = 3
  )
}


primary_ph_total <- (
  length(
    shape_order
  ) *
    length(
      sample_sizes
    ) *
    length(
      source_order
    ) *
    number_of_repetitions
)

primary_ph_counter <- 0L

for (shape_name in shape_order) {

  for (current_sample_size in sample_sizes) {

    scenario_name <- scenario_name_for(
      shape_name,
      current_sample_size
    )

    scenario <- baseline_scenarios[[
      scenario_name
    ]]

    occurrence_points <- set_axis_names(
      occurrence_archive$occurrence_subsets[[
        shape_name
      ]][[
        as.character(
          current_sample_size
        )
      ]]$points
    )

    for (
      repetition in seq_len(
        number_of_repetitions
      )
    ) {

      for (source_name in source_order) {

        primary_ph_counter <- primary_ph_counter +
          1L

        current_key <- ph_key(
          shape_name,
          current_sample_size,
          repetition,
          source_name
        )

        result_file <- file.path(
          primary_ph_directory,
          paste0(
            current_key,
            ".rds"
          )
        )

        use_saved_result <- FALSE

        if (
          resume_from_checkpoints &&
            file.exists(
              result_file
            )
        ) {

          saved_result <- readRDS(
            result_file
          )

          if (!identical(
            saved_result$analysis_settings_hash,
            analysis_settings_hash
          )) {
            stop(
              "Incompatible saved PH object: ",
              result_file
            )
          }

          if (
            isTRUE(
              saved_result$success
            ) ||
              !retry_failed_persistence
          ) {
            use_saved_result <- TRUE
          }
        }

        if (use_saved_result) {

          message(
            "Skipping PH [",
            primary_ph_counter,
            "/",
            primary_ph_total,
            "]: ",
            current_key
          )

          primary_ph_registry[[current_key]] <- list(
            key = current_key,
            success = saved_result$success,
            object_file = result_file,
            runtime_seconds = saved_result$runtime_seconds,
            failure_type = saved_result$failure_type,
            error_message = saved_result$error_message
          )

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

        index_object <- ph_subsample_indices[[
          current_key
        ]]

        if (is.null(
          index_object
        )) {

          saved_result <- list(
            analysis_settings_hash = analysis_settings_hash,
            key = current_key,
            shape_code = shape_name,
            shape = unname(
              shape_labels[[
                shape_name
              ]]
            ),
            sample_size = current_sample_size,
            repetition = repetition,
            source = source_name,
            subsample_seed = NA_integer_,
            sampled_indices = integer(0),
            sampled_points = NULL,
            point_cloud_diameter = NA_real_,
            success = FALSE,
            diagram = empty_diagram(),
            runtime_seconds = NA_real_,
            failure_type = "missing subsample",
            error_message = "No locked subsample indices were available."
          )

          saveRDS(
            saved_result,
            result_file,
            version = 3
          )

          primary_ph_registry[[current_key]] <- list(
            key = current_key,
            success = FALSE,
            object_file = result_file,
            runtime_seconds = NA_real_,
            failure_type = saved_result$failure_type,
            error_message = saved_result$error_message
          )

          save_primary_registry()

          next
        }

        if (identical(
          source_name,
          "Occurrence"
        )) {

          source_points <- occurrence_points

        } else {

          fitted_record <- scenario[[
            method_key(
              source_name
            )
          ]]

          if (
            is.null(
              fitted_record
            ) ||
              !isTRUE(
                fitted_record$success
              ) ||
              is.null(
                fitted_record$hypervolume
              )
          ) {

            saved_result <- list(
              analysis_settings_hash = analysis_settings_hash,
              key = current_key,
              shape_code = shape_name,
              shape = unname(
                shape_labels[[
                  shape_name
                ]]
              ),
              sample_size = current_sample_size,
              repetition = repetition,
              source = source_name,
              subsample_seed = index_object$seed,
              sampled_indices = index_object$indices,
              sampled_points = NULL,
              point_cloud_diameter = NA_real_,
              success = FALSE,
              diagram = empty_diagram(),
              runtime_seconds = NA_real_,
              failure_type = "model-fit failure",
              error_message = if (is.null(
                fitted_record
              )) {
                "Missing baseline fit record."
              } else {
                fitted_record$error_message
              }
            )

            saveRDS(
              saved_result,
              result_file,
              version = 3
            )

            primary_ph_registry[[current_key]] <- list(
              key = current_key,
              success = FALSE,
              object_file = result_file,
              runtime_seconds = NA_real_,
              failure_type = saved_result$failure_type,
              error_message = saved_result$error_message
            )

            save_primary_registry()

            next
          }

          source_points <- set_axis_names(
            fitted_record$hypervolume@RandomPoints
          )
        }

        if (max(
          index_object$indices
        ) > nrow(
          source_points
        )) {
          stop(
            "Locked PH subsample index exceeds current source-cloud size for ",
            current_key,
            "."
          )
        }

        sampled_points <- source_points[
          index_object$indices,
          ,
          drop = FALSE
        ]

        ph_result <- calculate_persistence_with_timeout(
          sampled_points,
          maximum_dimension = maximum_homology_dimension
        )

        saved_result <- c(
          list(
            analysis_settings_hash = analysis_settings_hash,
            key = current_key,
            shape_code = shape_name,
            shape = unname(
              shape_labels[[
                shape_name
              ]]
            ),
            sample_size = current_sample_size,
            repetition = repetition,
            source = source_name,
            subsample_seed = index_object$seed,
            sampled_indices = index_object$indices,
            sampled_points = sampled_points,
            point_cloud_diameter = point_cloud_diameter(
              sampled_points
            )
          ),
          ph_result
        )

        saveRDS(
          saved_result,
          result_file,
          version = 3
        )

        primary_ph_registry[[current_key]] <- list(
          key = current_key,
          success = saved_result$success,
          object_file = result_file,
          runtime_seconds = saved_result$runtime_seconds,
          failure_type = saved_result$failure_type,
          error_message = saved_result$error_message
        )

        save_primary_registry()
      }
    }
  }
}


# ============================================================
# Compile primary PH log, diagrams and maximum persistence
# ============================================================

ph_log_rows <- list()
diagram_rows <- list()
maximum_persistence_rows <- list()

ph_log_index <- 0L
diagram_index <- 0L
maximum_persistence_index <- 0L

for (shape_name in shape_order) {

  for (current_sample_size in sample_sizes) {

    for (
      repetition in seq_len(
        number_of_repetitions
      )
    ) {

      for (source_name in source_order) {

        current_key <- ph_key(
          shape_name,
          current_sample_size,
          repetition,
          source_name
        )

        registry_entry <- primary_ph_registry[[
          current_key
        ]]

        if (
          is.null(
            registry_entry
          ) ||
            !file.exists(
              registry_entry$object_file
            )
        ) {
          stop(
            "Primary PH registry is missing object file for ",
            current_key,
            "."
          )
        }

        result <- readRDS(
          registry_entry$object_file
        )

        ph_log_index <- ph_log_index +
          1L

        ph_log_rows[[ph_log_index]] <- data.frame(
          Key = current_key,
          Shape_code = shape_name,
          Shape = unname(
            shape_labels[[
              shape_name
            ]]
          ),
          Sample_size = current_sample_size,
          Repetition = repetition,
          Source = source_name,
          Subsample_seed = result$subsample_seed,
          Success = result$success,
          Runtime_seconds = result$runtime_seconds,
          Point_cloud_diameter = result$point_cloud_diameter,
          Failure_type = result$failure_type,
          Error_message = result$error_message,
          stringsAsFactors = FALSE
        )

        if (isTRUE(
          result$success
        )) {

          diagram <- standardize_diagram(
            result$diagram
          )

          if (nrow(
            diagram
          ) > 0L) {

            diagram_index <- diagram_index +
              1L

            diagram_rows[[diagram_index]] <- data.frame(
              Key = current_key,
              Shape_code = shape_name,
              Shape = unname(
                shape_labels[[
                  shape_name
                ]]
              ),
              Sample_size = current_sample_size,
              Repetition = repetition,
              Source = source_name,
              Homology_dimension = as.integer(
                diagram[
                  ,
                  "dimension"
                ]
              ),
              Birth = as.numeric(
                diagram[
                  ,
                  "birth"
                ]
              ),
              Death = as.numeric(
                diagram[
                  ,
                  "death"
                ]
              ),
              Persistence = as.numeric(
                diagram[
                  ,
                  "death"
                ] -
                  diagram[
                    ,
                    "birth"
                  ]
              ),
              Finite = is.finite(
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
              stringsAsFactors = FALSE
            )
          }
        }

        for (
          dimension in 0:maximum_homology_dimension
        ) {

          maximum_persistence_index <- maximum_persistence_index +
            1L

          maximum_persistence_rows[[maximum_persistence_index]] <- data.frame(
            Key = current_key,
            Shape_code = shape_name,
            Shape = unname(
              shape_labels[[
                shape_name
              ]]
            ),
            Sample_size = current_sample_size,
            Repetition = repetition,
            Source = source_name,
            Homology_dimension = dimension,
            Success = result$success,
            Maximum_finite_persistence = if (isTRUE(
              result$success
            )) {
              max_finite_persistence(
                result$diagram,
                dimension
              )
            } else {
              NA_real_
            },
            Point_cloud_diameter = result$point_cloud_diameter,
            Normalized_maximum_persistence = if (
              isTRUE(
                result$success
              ) &&
                is.finite(
                  result$point_cloud_diameter
                ) &&
                result$point_cloud_diameter > 0
            ) {
              max_finite_persistence(
                result$diagram,
                dimension
              ) /
                result$point_cloud_diameter
            } else {
              NA_real_
            },
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
}

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

if (length(
  diagram_rows
) > 0L) {

  persistence_diagrams <- do.call(
    rbind,
    diagram_rows
  )

} else {

  persistence_diagrams <- data.frame(
    Key = character(0),
    Shape_code = character(0),
    Shape = character(0),
    Sample_size = integer(0),
    Repetition = integer(0),
    Source = character(0),
    Homology_dimension = integer(0),
    Birth = numeric(0),
    Death = numeric(0),
    Persistence = numeric(0),
    Finite = logical(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  persistence_diagrams,
  persistence_diagram_file
)

maximum_persistence_replicates <- do.call(
  rbind,
  maximum_persistence_rows
)

rownames(
  maximum_persistence_replicates
) <- NULL

write_csv_safely(
  maximum_persistence_replicates,
  maximum_persistence_replicate_file
)


# ============================================================
# Maximum-persistence mean +/- SD summary
# ============================================================

maximum_persistence_group_keys <- unique(
  maximum_persistence_replicates[
    ,
    c(
      "Shape_code",
      "Shape",
      "Sample_size",
      "Source",
      "Homology_dimension"
    ),
    drop = FALSE
  ]
)

maximum_persistence_summary_rows <- vector(
  "list",
  nrow(
    maximum_persistence_group_keys
  )
)

for (
  row_index in seq_len(
    nrow(
      maximum_persistence_group_keys
    )
  )
) {

  key <- maximum_persistence_group_keys[
    row_index,
    ,
    drop = FALSE
  ]

  group <- maximum_persistence_replicates[
    maximum_persistence_replicates$Shape_code == key$Shape_code &
      maximum_persistence_replicates$Sample_size == key$Sample_size &
      maximum_persistence_replicates$Source == key$Source &
      maximum_persistence_replicates$Homology_dimension == key$Homology_dimension,
    ,
    drop = FALSE
  ]

  successful <- group[
    group$Success &
      is.finite(
        group$Maximum_finite_persistence
      ),
    ,
    drop = FALSE
  ]

  mean_raw <- safe_mean(
    successful$Maximum_finite_persistence
  )

  sd_raw <- safe_sd(
    successful$Maximum_finite_persistence
  )

  mean_normalized <- safe_mean(
    successful$Normalized_maximum_persistence
  )

  sd_normalized <- safe_sd(
    successful$Normalized_maximum_persistence
  )

  maximum_persistence_summary_rows[[row_index]] <- cbind(
    key,
    data.frame(
      Repetitions_requested = number_of_repetitions,
      Repetitions_successful = nrow(
        successful
      ),
      Mean_maximum_persistence = mean_raw,
      SD_maximum_persistence = sd_raw,
      Mean_maximum_persistence_plus_minus_SD = format_mean_sd(
        mean_raw,
        sd_raw
      ),
      Mean_normalized_maximum_persistence = mean_normalized,
      SD_normalized_maximum_persistence = sd_normalized,
      Mean_normalized_maximum_persistence_plus_minus_SD = format_mean_sd(
        mean_normalized,
        sd_normalized
      ),
      stringsAsFactors = FALSE
    )
  )
}

maximum_persistence_summary <- do.call(
  rbind,
  maximum_persistence_summary_rows
)

rownames(
  maximum_persistence_summary
) <- NULL

write_csv_safely(
  maximum_persistence_summary,
  maximum_persistence_summary_file
)


# ============================================================
# Bottleneck distances: each estimator vs paired occurrence cloud
# ============================================================

bottleneck_rows <- list()
bottleneck_index <- 0L

for (shape_name in shape_order) {

  for (current_sample_size in sample_sizes) {

    for (
      repetition in seq_len(
        number_of_repetitions
      )
    ) {

      occurrence_key <- ph_key(
        shape_name,
        current_sample_size,
        repetition,
        "Occurrence"
      )

      occurrence_entry <- primary_ph_registry[[
        occurrence_key
      ]]

      occurrence_result <- readRDS(
        occurrence_entry$object_file
      )

      for (method_name in method_order) {

        method_result_key <- ph_key(
          shape_name,
          current_sample_size,
          repetition,
          method_name
        )

        method_entry <- primary_ph_registry[[
          method_result_key
        ]]

        method_result <- readRDS(
          method_entry$object_file
        )

        for (
          dimension in 0:maximum_homology_dimension
        ) {

          bottleneck_index <- bottleneck_index +
            1L

          if (
            !isTRUE(
              occurrence_result$success
            ) ||
              !isTRUE(
                method_result$success
              )
          ) {

            bottleneck_rows[[bottleneck_index]] <- data.frame(
              Shape_code = shape_name,
              Shape = unname(
                shape_labels[[
                  shape_name
                ]]
              ),
              Sample_size = current_sample_size,
              Repetition = repetition,
              Method = method_name,
              Homology_dimension = dimension,
              Success = FALSE,
              Bottleneck_distance = NA_real_,
              Occurrence_diameter = occurrence_result$point_cloud_diameter,
              Normalized_bottleneck_distance = NA_real_,
              Occurrence_maximum_persistence = if (isTRUE(
                occurrence_result$success
              )) {
                max_finite_persistence(
                  occurrence_result$diagram,
                  dimension
                )
              } else {
                NA_real_
              },
              Method_maximum_persistence = if (isTRUE(
                method_result$success
              )) {
                max_finite_persistence(
                  method_result$diagram,
                  dimension
                )
              } else {
                NA_real_
              },
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
            occurrence_result$diagram,
            method_result$diagram,
            dimension
          )

          normalized_distance <- if (
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

          bottleneck_rows[[bottleneck_index]] <- data.frame(
            Shape_code = shape_name,
            Shape = unname(
              shape_labels[[
                shape_name
              ]]
            ),
            Sample_size = current_sample_size,
            Repetition = repetition,
            Method = method_name,
            Homology_dimension = dimension,
            Success = isTRUE(
              bottleneck_result$success
            ) &&
              is.finite(
                normalized_distance
              ),
            Bottleneck_distance = bottleneck_result$distance,
            Occurrence_diameter = occurrence_result$point_cloud_diameter,
            Normalized_bottleneck_distance = normalized_distance,
            Occurrence_maximum_persistence = max_finite_persistence(
              occurrence_result$diagram,
              dimension
            ),
            Method_maximum_persistence = max_finite_persistence(
              method_result$diagram,
              dimension
            ),
            Error_message = bottleneck_result$error_message,
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
}

bottleneck_replicates <- do.call(
  rbind,
  bottleneck_rows
)

rownames(
  bottleneck_replicates
) <- NULL

write_csv_safely(
  bottleneck_replicates,
  bottleneck_replicate_file
)


# ============================================================
# Bottleneck mean +/- SD summary
# ============================================================

bottleneck_group_keys <- unique(
  bottleneck_replicates[
    ,
    c(
      "Shape_code",
      "Shape",
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
    bottleneck_group_keys
  )
)

for (
  row_index in seq_len(
    nrow(
      bottleneck_group_keys
    )
  )
) {

  key <- bottleneck_group_keys[
    row_index,
    ,
    drop = FALSE
  ]

  group <- bottleneck_replicates[
    bottleneck_replicates$Shape_code == key$Shape_code &
      bottleneck_replicates$Sample_size == key$Sample_size &
      bottleneck_replicates$Method == key$Method &
      bottleneck_replicates$Homology_dimension == key$Homology_dimension,
    ,
    drop = FALSE
  ]

  successful <- group[
    group$Success &
      is.finite(
        group$Bottleneck_distance
      ) &
      is.finite(
        group$Normalized_bottleneck_distance
      ),
    ,
    drop = FALSE
  ]

  raw_mean <- safe_mean(
    successful$Bottleneck_distance
  )

  raw_sd <- safe_sd(
    successful$Bottleneck_distance
  )

  normalized_mean <- safe_mean(
    successful$Normalized_bottleneck_distance
  )

  normalized_sd <- safe_sd(
    successful$Normalized_bottleneck_distance
  )

  bottleneck_summary_rows[[row_index]] <- cbind(
    key,
    data.frame(
      Repetitions_requested = number_of_repetitions,
      Repetitions_successful = nrow(
        successful
      ),
      Mean_bottleneck_distance = raw_mean,
      SD_bottleneck_distance = raw_sd,
      Mean_bottleneck_plus_minus_SD = format_mean_sd(
        raw_mean,
        raw_sd
      ),
      Mean_normalized_bottleneck = normalized_mean,
      SD_normalized_bottleneck = normalized_sd,
      Mean_normalized_bottleneck_plus_minus_SD = format_mean_sd(
        normalized_mean,
        normalized_sd
      ),
      Mean_occurrence_maximum_persistence = safe_mean(
        successful$Occurrence_maximum_persistence
      ),
      Mean_method_maximum_persistence = safe_mean(
        successful$Method_maximum_persistence
      ),
      stringsAsFactors = FALSE
    )
  )
}

bottleneck_summary <- do.call(
  rbind,
  bottleneck_summary_rows
)

rownames(
  bottleneck_summary
) <- NULL

write_csv_safely(
  bottleneck_summary,
  bottleneck_summary_file
)


# ============================================================
# Matched filled-ellipsoid helpers
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
      number_of_points * d
    ),
    nrow = number_of_points,
    ncol = d
  )

  direction_norms <- sqrt(
    rowSums(
      directions^2
    )
  )

  while (any(
    direction_norms == 0
  )) {

    bad <- which(
      direction_norms == 0
    )

    directions[
      bad,
    ] <- matrix(
      stats::rnorm(
        length(
          bad
        ) * d
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
  )^(1 / d)

  unit_ball <- directions *
    radii

  # Match the FULL source cloud's realised centroid and covariance exactly
  # up to floating-point precision, while keeping the null cloud at n = 300.
  unit_ball <- sweep(
    unit_ball,
    2,
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
    2,
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
#
# CONDITION-LEVEL NULL DESIGN
# ---------------------------
# One shared set of 20 matched filled ellipsoids is constructed for each:
#
#   shape x sample size x source
#
# The matching target is the FULL underlying source cloud:
#   Occurrence   -> all n occurrence observations for that condition
#   QPH/KDE/SVM -> all stochastic Hypervolume @RandomPoints
#
# Each matched ellipsoid itself contains exactly ph_sample_size = 300 points.
# The same 20-null threshold is applied to all ten observed 300-point PH
# repetitions from that condition.
#
# Number of matched-reference conditions:
#   3 shapes x 3 sample sizes x 4 sources = 36
#
# Total requested matched-reference PH calls:
#   36 x 20 = 720
# ============================================================

null_settings <- list(
  analysis_settings_hash = analysis_settings_hash,
  null_design = "shared_condition_level_full_source_cloud",
  matching_target = "full_source_cloud_centroid_and_covariance",
  null_point_count = ph_sample_size,
  number_of_null_replicates = number_of_null_replicates,
  null_master_seed = null_master_seed,
  maximum_homology_dimension = maximum_homology_dimension,
  ph_threshold = ph_threshold,
  ph_prime_field = ph_prime_field,
  ph_standardize = ph_standardize,
  ph_timeout_seconds = ph_timeout_seconds
)

null_settings_hash <- hash_r_object(
  null_settings
)


null_condition_key <- function(
    shape_name,
    sample_size,
    source_name
) {

  paste(
    shape_name,
    paste0(
      "n",
      sample_size
    ),
    source_code(
      source_name
    ),
    "shared_nulls",
    sep = "__"
  )
}


get_full_source_cloud <- function(
    shape_name,
    sample_size,
    source_name
) {

  if (identical(
    source_name,
    "Occurrence"
  )) {

    return(
      set_axis_names(
        occurrence_archive$occurrence_subsets[[
          shape_name
        ]][[
          as.character(
            sample_size
          )
        ]]$points
      )
    )
  }

  scenario_name <- scenario_name_for(
    shape_name,
    sample_size
  )

  scenario <- baseline_scenarios[[
    scenario_name
  ]]

  fitted_record <- scenario[[
    method_key(
      source_name
    )
  ]]

  if (
    is.null(
      fitted_record
    ) ||
      !isTRUE(
        fitted_record$success
      ) ||
      is.null(
        fitted_record$hypervolume
      )
  ) {
    return(
      NULL
    )
  }

  set_axis_names(
    fitted_record$hypervolume@RandomPoints
  )
}


number_of_null_conditions <- (
  length(
    shape_order
  ) *
    length(
      sample_sizes
    ) *
    length(
      source_order
    )
)

null_condition_counter <- 0L

for (
  shape_index in seq_along(
    shape_order
  )
) {

  shape_name <- shape_order[[
    shape_index
  ]]

  for (current_sample_size in sample_sizes) {

    for (
      source_index in seq_along(
        source_order
      )
    ) {

      source_name <- source_order[[
        source_index
      ]]

      null_condition_counter <- null_condition_counter +
        1L

      condition_key <- null_condition_key(
        shape_name,
        current_sample_size,
        source_name
      )

      full_source_points <- get_full_source_cloud(
        shape_name = shape_name,
        sample_size = current_sample_size,
        source_name = source_name
      )

      if (is.null(
        full_source_points
      )) {

        warning(
          "Skipping matched-reference condition because the full source ",
          "cloud is unavailable: ",
          condition_key
        )

        next
      }

      full_source_points <- set_axis_names(
        full_source_points
      )

      null_object_file <- file.path(
        null_directory,
        paste0(
          condition_key,
          ".rds"
        )
      )

      if (file.exists(
        null_object_file
      )) {

        null_object <- readRDS(
          null_object_file
        )

        if (!identical(
          null_object$null_settings_hash,
          null_settings_hash
        )) {
          stop(
            "Incompatible matched-ellipsoid checkpoint: ",
            null_object_file
          )
        }

      } else {

        null_object <- list(
          null_settings_hash = null_settings_hash,
          condition_key = condition_key,
          shape_code = shape_name,
          sample_size = current_sample_size,
          source = source_name,
          full_source_point_count = nrow(
            full_source_points
          ),
          full_source_centroid = colMeans(
            full_source_points
          ),
          full_source_covariance = stats::cov(
            full_source_points
          ),
          null_results = vector(
            "list",
            number_of_null_replicates
          )
        )
      }

      message(
        "Matched ellipsoid condition [",
        null_condition_counter,
        "/",
        number_of_null_conditions,
        "]: ",
        condition_key
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

        # Condition-level seed: repetition is deliberately NOT included.
        # The same 20 null clouds are shared by all ten observed PH draws.
        null_seed <- as.integer(
          null_master_seed +
            shape_index * 10000000L +
            current_sample_size * 1000L +
            source_index * 10000L +
            null_repetition
        )

        generated_null <- generate_exact_matched_ellipsoid(
          target_points = full_source_points,
          number_of_points = ph_sample_size,
          seed = null_seed
        )

        null_ph <- calculate_persistence_with_timeout(
          generated_null$points,
          maximum_dimension = maximum_homology_dimension
        )

        null_object$null_results[[null_repetition]] <- c(
          list(
            null_repetition = null_repetition,
            seed = null_seed,
            target_point_count = generated_null$target_point_count,
            null_point_count = generated_null$null_point_count,
            target_centroid = generated_null$target_centroid,
            target_covariance = generated_null$target_covariance,
            centroid_error = generated_null$centroid_error,
            covariance_error = generated_null$covariance_error
          ),
          null_ph
        )

        # Save after every null replicate so an interrupted run resumes here.
        saveRDS(
          null_object,
          null_object_file,
          version = 3
        )
      }
    }
  }
}


# ============================================================
# Compile condition-level matched-reference tables
# ============================================================

null_rows <- list()
null_diagnostic_rows <- list()

null_index <- 0L
null_diagnostic_index <- 0L

for (
  shape_index in seq_along(
    shape_order
  )
) {

  shape_name <- shape_order[[
    shape_index
  ]]

  for (current_sample_size in sample_sizes) {

    for (
      source_index in seq_along(
        source_order
      )
    ) {

      source_name <- source_order[[
        source_index
      ]]

      condition_key <- null_condition_key(
        shape_name,
        current_sample_size,
        source_name
      )

      null_object_file <- file.path(
        null_directory,
        paste0(
          condition_key,
          ".rds"
        )
      )

      if (!file.exists(
        null_object_file
      )) {
        next
      }

      null_object <- readRDS(
        null_object_file
      )

      for (
        null_repetition in seq_len(
          number_of_null_replicates
        )
      ) {

        null_result <- null_object$null_results[[
          null_repetition
        ]]

        if (is.null(
          null_result
        )) {
          next
        }

        null_diagnostic_index <- null_diagnostic_index +
          1L

        null_diagnostic_rows[[null_diagnostic_index]] <- data.frame(
          Condition_key = condition_key,
          Shape_code = shape_name,
          Shape = unname(
            shape_labels[[
              shape_name
            ]]
          ),
          Sample_size = current_sample_size,
          Source = source_name,
          Full_source_point_count = null_result$target_point_count,
          Null_point_count = null_result$null_point_count,
          Null_repetition = null_repetition,
          Null_seed = null_result$seed,
          Null_success = null_result$success,
          Centroid_error = null_result$centroid_error,
          Covariance_error = null_result$covariance_error,
          Null_runtime_seconds = null_result$runtime_seconds,
          Null_failure_type = null_result$failure_type,
          Null_error_message = null_result$error_message,
          stringsAsFactors = FALSE
        )

        for (
          dimension in 0:maximum_homology_dimension
        ) {

          null_index <- null_index +
            1L

          null_rows[[null_index]] <- data.frame(
            Condition_key = condition_key,
            Shape_code = shape_name,
            Shape = unname(
              shape_labels[[
                shape_name
              ]]
            ),
            Sample_size = current_sample_size,
            Source = source_name,
            Homology_dimension = dimension,
            Full_source_point_count = null_result$target_point_count,
            Null_point_count = null_result$null_point_count,
            Null_repetition = null_repetition,
            Null_seed = null_result$seed,
            Null_success = null_result$success,
            Null_maximum_persistence = if (isTRUE(
              null_result$success
            )) {
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
}

if (length(
  null_rows
) > 0L) {

  null_replicates <- do.call(
    rbind,
    null_rows
  )

} else {

  null_replicates <- data.frame(
    Condition_key = character(0),
    Shape_code = character(0),
    Shape = character(0),
    Sample_size = integer(0),
    Source = character(0),
    Homology_dimension = integer(0),
    Full_source_point_count = integer(0),
    Null_point_count = integer(0),
    Null_repetition = integer(0),
    Null_seed = integer(0),
    Null_success = logical(0),
    Null_maximum_persistence = numeric(0),
    Null_runtime_seconds = numeric(0),
    Null_failure_type = character(0),
    Null_error_message = character(0),
    Centroid_error = numeric(0),
    Covariance_error = numeric(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  null_replicates,
  null_replicate_file
)

if (length(
  null_diagnostic_rows
) > 0L) {

  null_diagnostics <- do.call(
    rbind,
    null_diagnostic_rows
  )

} else {

  null_diagnostics <- data.frame(
    Condition_key = character(0),
    Shape_code = character(0),
    Shape = character(0),
    Sample_size = integer(0),
    Source = character(0),
    Full_source_point_count = integer(0),
    Null_point_count = integer(0),
    Null_repetition = integer(0),
    Null_seed = integer(0),
    Null_success = logical(0),
    Centroid_error = numeric(0),
    Covariance_error = numeric(0),
    Null_runtime_seconds = numeric(0),
    Null_failure_type = character(0),
    Null_error_message = character(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  null_diagnostics,
  null_diagnostic_file
)


# ============================================================
# Build ONE shared 20-null threshold per condition and dimension
# ============================================================

null_threshold_rows <- list()
null_threshold_index <- 0L

for (shape_name in shape_order) {

  for (current_sample_size in sample_sizes) {

    for (source_name in source_order) {

      condition_key <- null_condition_key(
        shape_name,
        current_sample_size,
        source_name
      )

      for (
        dimension in 0:maximum_homology_dimension
      ) {

        null_group <- null_replicates[
          null_replicates$Condition_key == condition_key &
            null_replicates$Homology_dimension == dimension &
            null_replicates$Null_success &
            is.finite(
              null_replicates$Null_maximum_persistence
            ),
          ,
          drop = FALSE
        ]

        successful_null_replicates <- length(
          unique(
            null_group$Null_repetition
          )
        )

        null_set_complete <- identical(
          as.integer(
            successful_null_replicates
          ),
          number_of_null_replicates
        )

        maximum_null_persistence <- if (null_set_complete) {
          max(
            null_group$Null_maximum_persistence
          )
        } else {
          NA_real_
        }

        null_threshold_index <- null_threshold_index +
          1L

        null_threshold_rows[[null_threshold_index]] <- data.frame(
          Condition_key = condition_key,
          Shape_code = shape_name,
          Shape = unname(
            shape_labels[[
              shape_name
            ]]
          ),
          Sample_size = current_sample_size,
          Source = source_name,
          Homology_dimension = dimension,
          Null_replicates_requested = number_of_null_replicates,
          Null_replicates_successful = successful_null_replicates,
          Null_set_complete = null_set_complete,
          Maximum_null_persistence = maximum_null_persistence,
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

null_thresholds <- do.call(
  rbind,
  null_threshold_rows
)

rownames(
  null_thresholds
) <- NULL


# ============================================================
# Compare all ten observed PH repetitions with the shared threshold
# ============================================================

null_observed_rows <- list()
null_observed_index <- 0L

for (shape_name in shape_order) {

  for (current_sample_size in sample_sizes) {

    for (source_name in source_order) {

      condition_key <- null_condition_key(
        shape_name,
        current_sample_size,
        source_name
      )

      for (
        repetition in seq_len(
          number_of_repetitions
        )
      ) {

        current_key <- ph_key(
          shape_name,
          current_sample_size,
          repetition,
          source_name
        )

        observed_entry <- primary_ph_registry[[
          current_key
        ]]

        if (
          is.null(
            observed_entry
          ) ||
            !file.exists(
              observed_entry$object_file
            )
        ) {
          next
        }

        observed_result <- readRDS(
          observed_entry$object_file
        )

        if (!isTRUE(
          observed_result$success
        )) {
          next
        }

        for (
          dimension in 0:maximum_homology_dimension
        ) {

          threshold_row <- null_thresholds[
            null_thresholds$Condition_key == condition_key &
              null_thresholds$Homology_dimension == dimension,
            ,
            drop = FALSE
          ]

          if (nrow(
            threshold_row
          ) != 1L) {
            stop(
              "Expected exactly one shared null threshold for ",
              condition_key,
              " H",
              dimension,
              "."
            )
          }

          observed_maximum <- max_finite_persistence(
            observed_result$diagram,
            dimension
          )

          maximum_null_persistence <- threshold_row$Maximum_null_persistence[[
            1L
          ]]

          null_set_complete <- threshold_row$Null_set_complete[[
            1L
          ]]

          exceeds_threshold <- if (
            isTRUE(
              null_set_complete
            ) &&
              is.finite(
                maximum_null_persistence
              )
          ) {
            observed_maximum >
              maximum_null_persistence
          } else {
            NA
          }

          null_observed_index <- null_observed_index +
            1L

          null_observed_rows[[null_observed_index]] <- data.frame(
            Condition_key = condition_key,
            Shape_code = shape_name,
            Shape = unname(
              shape_labels[[
                shape_name
              ]]
            ),
            Sample_size = current_sample_size,
            Repetition = repetition,
            Source = source_name,
            Homology_dimension = dimension,
            Null_replicates_requested = threshold_row$Null_replicates_requested[[
              1L
            ]],
            Null_replicates_successful = threshold_row$Null_replicates_successful[[
              1L
            ]],
            Null_set_complete = null_set_complete,
            Observed_maximum_persistence = observed_maximum,
            Maximum_null_persistence = maximum_null_persistence,
            Exceeds_matched_ellipsoid_null = exceeds_threshold,
            Persistence_ratio_observed_to_null_max = if (
              isTRUE(
                null_set_complete
              ) &&
                is.finite(
                  maximum_null_persistence
                ) &&
                maximum_null_persistence > 0
            ) {
              observed_maximum /
                maximum_null_persistence
            } else {
              NA_real_
            },
            Persistence_difference_observed_minus_null_max = if (
              isTRUE(
                null_set_complete
              ) &&
                is.finite(
                  maximum_null_persistence
                )
            ) {
              observed_maximum -
                maximum_null_persistence
            } else {
              NA_real_
            },
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
}

if (length(
  null_observed_rows
) > 0L) {

  null_observed_results <- do.call(
    rbind,
    null_observed_rows
  )

} else {

  null_observed_results <- data.frame(
    Condition_key = character(0),
    Shape_code = character(0),
    Shape = character(0),
    Sample_size = integer(0),
    Repetition = integer(0),
    Source = character(0),
    Homology_dimension = integer(0),
    Null_replicates_requested = integer(0),
    Null_replicates_successful = integer(0),
    Null_set_complete = logical(0),
    Observed_maximum_persistence = numeric(0),
    Maximum_null_persistence = numeric(0),
    Exceeds_matched_ellipsoid_null = logical(0),
    Persistence_ratio_observed_to_null_max = numeric(0),
    Persistence_difference_observed_minus_null_max = numeric(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  null_observed_results,
  null_observed_results_file
)


# ============================================================
# Exceedance proportion across ten observed repetitions
# ============================================================

null_aggregate_keys <- unique(
  null_observed_results[
    ,
    c(
      "Condition_key",
      "Shape_code",
      "Shape",
      "Sample_size",
      "Source",
      "Homology_dimension"
    ),
    drop = FALSE
  ]
)

null_aggregate_rows <- vector(
  "list",
  nrow(
    null_aggregate_keys
  )
)

for (
  row_index in seq_len(
    nrow(
      null_aggregate_keys
    )
  )
) {

  key <- null_aggregate_keys[
    row_index,
    ,
    drop = FALSE
  ]

  group <- null_observed_results[
    null_observed_results$Condition_key == key$Condition_key &
      null_observed_results$Homology_dimension == key$Homology_dimension,
    ,
    drop = FALSE
  ]

  complete <- group[
    group$Null_set_complete &
      !is.na(
        group$Exceeds_matched_ellipsoid_null
      ),
    ,
    drop = FALSE
  ]

  number_exceeding <- if (nrow(
    complete
  ) > 0L) {
    sum(
      complete$Exceeds_matched_ellipsoid_null
    )
  } else {
    0L
  }

  exceedance_proportion <- if (nrow(
    complete
  ) > 0L) {
    mean(
      complete$Exceeds_matched_ellipsoid_null
    )
  } else {
    NA_real_
  }

  null_aggregate_rows[[row_index]] <- cbind(
    key,
    data.frame(
      Repetitions_requested = number_of_repetitions,
      Repetitions_compared_with_complete_shared_null_set = nrow(
        complete
      ),
      Null_replicates_requested = if (nrow(
        group
      ) > 0L) {
        group$Null_replicates_requested[[
          1L
        ]]
      } else {
        number_of_null_replicates
      },
      Null_replicates_successful = if (nrow(
        group
      ) > 0L) {
        group$Null_replicates_successful[[
          1L
        ]]
      } else {
        0L
      },
      Number_exceeding_matched_ellipsoid_null = number_exceeding,
      Exceedance_proportion = exceedance_proportion,
      Mean_observed_maximum_persistence = safe_mean(
        complete$Observed_maximum_persistence
      ),
      SD_observed_maximum_persistence = safe_sd(
        complete$Observed_maximum_persistence
      ),
      Shared_maximum_null_persistence = if (nrow(
        complete
      ) > 0L) {
        complete$Maximum_null_persistence[[
          1L
        ]]
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  )
}

if (length(
  null_aggregate_rows
) > 0L) {

  null_summary <- do.call(
    rbind,
    null_aggregate_rows
  )

} else {

  null_summary <- data.frame()
}

rownames(
  null_summary
) <- NULL

write_csv_safely(
  null_summary,
  null_summary_file
)


# ============================================================
# Compile failures
# ============================================================

failure_rows <- list()
failure_index <- 0L

failed_primary <- ph_log[
  !ph_log$Success,
  ,
  drop = FALSE
]

if (nrow(
  failed_primary
) > 0L) {

  for (
    row_index in seq_len(
      nrow(
        failed_primary
      )
    )
  ) {

    failure_index <- failure_index +
      1L

    failure_rows[[failure_index]] <- data.frame(
      Stage = "Primary PH",
      Shape_code = failed_primary$Shape_code[[
        row_index
      ]],
      Sample_size = failed_primary$Sample_size[[
        row_index
      ]],
      Repetition = failed_primary$Repetition[[
        row_index
      ]],
      Source = failed_primary$Source[[
        row_index
      ]],
      Null_repetition = NA_integer_,
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

failed_nulls <- null_diagnostics[
  !null_diagnostics$Null_success,
  ,
  drop = FALSE
]

if (nrow(
  failed_nulls
) > 0L) {

  for (
    row_index in seq_len(
      nrow(
        failed_nulls
      )
    )
  ) {

    failure_index <- failure_index +
      1L

    failure_rows[[failure_index]] <- data.frame(
      Stage = "Matched ellipsoid PH",
      Shape_code = failed_nulls$Shape_code[[
        row_index
      ]],
      Sample_size = failed_nulls$Sample_size[[
        row_index
      ]],
      Repetition = NA_integer_,
      Source = failed_nulls$Source[[
        row_index
      ]],
      Null_repetition = failed_nulls$Null_repetition[[
        row_index
      ]],
      Failure_type = failed_nulls$Null_failure_type[[
        row_index
      ]],
      Error_message = failed_nulls$Null_error_message[[
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

if (nrow(
  failed_bottleneck
) > 0L) {

  for (
    row_index in seq_len(
      nrow(
        failed_bottleneck
      )
    )
  ) {

    failure_index <- failure_index +
      1L

    failure_rows[[failure_index]] <- data.frame(
      Stage = "Bottleneck",
      Shape_code = failed_bottleneck$Shape_code[[
        row_index
      ]],
      Sample_size = failed_bottleneck$Sample_size[[
        row_index
      ]],
      Repetition = failed_bottleneck$Repetition[[
        row_index
      ]],
      Source = failed_bottleneck$Method[[
        row_index
      ]],
      Null_repetition = NA_integer_,
      Failure_type = "bottleneck failure",
      Error_message = failed_bottleneck$Error_message[[
        row_index
      ]],
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
    Stage = character(0),
    Shape_code = character(0),
    Sample_size = integer(0),
    Repetition = integer(0),
    Source = character(0),
    Null_repetition = integer(0),
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
# Save authoritative topology result object
# ============================================================

topology_results <- list(
  metadata = list(
    script = "08_3D_Synthetic_Topology.R",
    analysis_settings_hash = analysis_settings_hash,
    baseline_results_file = baseline_results_file,
    baseline_results_md5 = safe_md5(
      baseline_results_file
    ),
    shape_order = shape_order,
    sample_sizes = sample_sizes,
    method_order = method_order,
    source_order = source_order,
    ph_sample_size = ph_sample_size,
    number_of_repetitions = number_of_repetitions,
    maximum_homology_dimension = maximum_homology_dimension,
    ph_threshold = ph_threshold,
    ph_prime_field = ph_prime_field,
    ph_standardize = ph_standardize,
    ph_timeout_seconds = ph_timeout_seconds,
    number_of_null_replicates = number_of_null_replicates,
    null_design = "shared_condition_level_full_source_cloud",
    null_point_count = ph_sample_size,
    null_master_seed = null_master_seed,
    method_colours = method_colours,
    true_region_colour = true_region_colour,
    occurrence_colour = occurrence_colour,
    completed_at = as.character(
      Sys.time()
    )
  ),
  ph_subsample_file = ph_subsample_file,
  ph_subsample_indices = ph_subsample_indices,
  primary_ph_registry = primary_ph_registry,
  ph_log = ph_log,
  maximum_persistence_replicates = maximum_persistence_replicates,
  maximum_persistence_summary = maximum_persistence_summary,
  bottleneck_replicates = bottleneck_replicates,
  bottleneck_summary = bottleneck_summary,
  matched_ellipsoid_null_thresholds = null_thresholds,
  matched_ellipsoid_observed_results = null_observed_results,
  matched_ellipsoid_exceedance_summary = null_summary,
  matched_ellipsoid_diagnostics = null_diagnostics
)

saveRDS(
  topology_results,
  topology_results_file,
  version = 3
)


# ============================================================
# Human-readable notes and session information
# ============================================================

writeLines(
  c(
    "Revised 3D synthetic topology analysis",
    "=====================================",
    "",
    "No estimators were refitted; all baseline clouds came from Script 06.",
    "",
    "Persistent homology:",
    paste0(
      "  PH sample size = ",
      ph_sample_size
    ),
    paste0(
      "  repetitions = ",
      number_of_repetitions
    ),
    "  homology dimensions = H0, H1, H2",
    paste0(
      "  threshold = ",
      ph_threshold
    ),
    paste0(
      "  prime field = ",
      ph_prime_field,
      " when supported"
    ),
    paste0(
      "  standardize = ",
      ph_standardize,
      " when supported"
    ),
    paste0(
      "  timeout per PH calculation = ",
      ph_timeout_seconds,
      " seconds"
    ),
    "",
    "Bottleneck distance:",
    "  estimator persistence diagram compared with paired occurrence diagram",
    "  separately for H0, H1 and H2",
    "  normalised by the paired occurrence-cloud diameter",
    "",
    "Matched filled-ellipsoid references:",
    paste0(
      "  shared nulls per shape x sample-size x source condition = ",
      number_of_null_replicates
    ),
    paste0(
      "  matched-reference conditions = ",
      number_of_null_conditions
    ),
    paste0(
      "  total requested matched-reference PH calls = ",
      number_of_null_conditions * number_of_null_replicates
    ),
    "  matching target = full underlying source-cloud centroid/covariance",
    paste0(
      "  points per matched ellipsoid = ",
      ph_sample_size
    ),
    "  the same 20-null threshold is shared across all ten observed PH repetitions",
    "  threshold = maximum persistence across the complete 20-null set",
    "  incomplete null sets are not used to declare threshold exceedance",
    "  aggregate reported quantity = exceedance proportion",
    "",
    "Interpretation emphasis:",
    "  solid ball H1/H2 = simple controls",
    "  solid torus H1 = expected non-trivial feature",
    "  hollow spherical region H2 = expected non-trivial feature",
    "  H0-H2 retained in all raw outputs",
    "",
    "Locked colours:",
    "  Gaussian KDE = #D7301F",
    "  SVM = #238B45",
    "  QPH = #2C7FB8",
    "  true region = #D9D9D9",
    "  occurrences = #111111",
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
      sum(
        null_diagnostics$Null_success
      ),
      " / ",
      nrow(
        null_diagnostics
      )
    ),
    "",
    paste0(
      "Completed: ",
      Sys.time()
    )
  ),
  notes_file
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
  "08_3D_Synthetic_Topology.R complete."
)

message(
  "============================================================"
)

message(
  "Authoritative topology object:\n  ",
  normalizePath(
    topology_results_file,
    mustWork = FALSE
  )
)

message(
  "Primary PH log:\n  ",
  normalizePath(
    ph_log_file,
    mustWork = FALSE
  )
)

message(
  "Bottleneck summary:\n  ",
  normalizePath(
    bottleneck_summary_file,
    mustWork = FALSE
  )
)

message(
  "Matched-ellipsoid exceedance summary:\n  ",
  normalizePath(
    null_summary_file,
    mustWork = FALSE
  )
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
  "Matched-reference PH successes: ",
  sum(
    null_diagnostics$Null_success
  ),
  " / ",
  nrow(
    null_diagnostics
  )
)

message(
  "Observed repetition/dimension comparisons using complete shared 20-null sets: ",
  sum(
    null_observed_results$Null_set_complete
  ),
  " / ",
  nrow(
    null_observed_results
  )
)

if (nrow(
  failure_table
) > 0L) {

  message(
    "Failures/computational-limit events recorded: ",
    nrow(
      failure_table
    ),
    ". See:\n  ",
    normalizePath(
      failure_file,
      mustWork = FALSE
    )
  )

} else {

  message(
    "No topology failures were recorded."
  )
}

message(
  "============================================================"
)
