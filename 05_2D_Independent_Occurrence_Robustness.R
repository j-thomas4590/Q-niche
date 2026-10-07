# ============================================================
# 05_2D_Independent_Occurrence_Robustness.R
# ============================================================
#
# Independent occurrence-draw robustness analysis for the FINAL revised
# two-dimensional synthetic QPH benchmark.
#
# PURPOSE
# -------
# Test whether the main 2D synthetic conclusions depend strongly on the
# single fixed occurrence realisation used in the primary benchmark.
#
# DESIGN
# ------
# - Five analytically controlled 2D niches:
#     spiral band
#     filled ellipse
#     annulus
#     concave banana
#     two separated disks
# - n = 900 occurrence observations per niche
# - 10 independent occurrence draws per niche
# - baseline estimator settings only
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
  "2D_Synthetic_sqrtNB_q099"
)

locked_input_directory <- file.path(
  analysis_root_directory,
  "00_Locked_Inputs"
)

geometry_output_directory <- file.path(
  analysis_root_directory,
  "02_Geometry"
)

output_directory <- file.path(
  analysis_root_directory,
  "05_Independent_Occurrence_Robustness"
)

occurrence_directory <- file.path(
  output_directory,
  "occurrence_clouds"
)

model_directory <- file.path(
  output_directory,
  "model_objects"
)

topology_directory <- file.path(
  output_directory,
  "topology_objects"
)

for (current_directory in c(
  output_directory,
  occurrence_directory,
  model_directory,
  topology_directory
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
  "e1071",
  "TDAstats",
  "TDA",
  "R.utils",
  "ggplot2"
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
    "Install the following required package(s) before running Script 05: ",
    paste(
      missing_packages,
      collapse = ", "
    )
  )
}

library(hypervolume)
library(e1071)
library(TDAstats)
library(TDA)
library(R.utils)
library(ggplot2)


# ============================================================
# Locked analysis settings
# ============================================================

shape_order <- c(
  "spiral",
  "ellipse",
  "annulus",
  "banana",
  "two_balls"
)

shape_labels <- c(
  spiral = "Spiral band",
  ellipse = "Filled ellipse",
  annulus = "Annulus",
  banana = "Concave banana",
  two_balls = "Two separated disks"
)

shape_dimensionality <- setNames(
  rep(
    2L,
    length(shape_order)
  ),
  shape_order
)

sample_size <- 900L
number_of_independent_draws <- 10L

# Revised QPH baseline.
qph_samples_per_point <- 100L
qph_sd_count <- 3
qph_q <- 0.99
qph_sampling_chunk_size <- 100L
qph_potential_batch_size <- 500L

# Gaussian KDE baseline.
kde_samples_per_point <- 100L
kde_sd_count <- 3
kde_quantile <- 0.95
kde_bandwidth_method <- "silverman"
kde_chunk_size <- 100L

# SVM baseline.
svm_samples_per_point <- 100L
svm_nu <- 0.01
svm_gamma <- 0.50
svm_scale_factor <- 1
svm_chunk_size <- 100L

# Geometry settings retained from the original robustness analysis.
jaccard_num_points_max <- 10000L
jaccard_distance_factor <- 1

# Topology positive controls retained from the original robustness analysis.
topology_target_dimension <- c(
  annulus = 1L,
  two_balls = 0L
)

topology_shape_order <- names(
  topology_target_dimension
)

ph_sample_size <- 300L
maximum_homology_dimension <- 1L
ph_threshold <- -1
ph_prime_field <- 2L
ph_standardize <- FALSE
ph_timeout_seconds <- 6 * 60

# Exact seed bases retained from the original independent-draw experiment.
occurrence_seed_base <- 910001L
qph_kde_sampling_seed_base <- 920001L
svm_sampling_seed_base <- 930001L
topology_sampling_seed_base <- 940001L
jaccard_seed_base <- 950001L

# The previous script used QPH, KDE, SVM ordering for method-indexed geometry
# seeds and Occurrence, QPH, KDE, SVM ordering for topology seeds. Preserve
# those seed indices even though display order now follows the manuscript
# colour/order convention.
legacy_method_seed_index <- c(
  "QPH" = 1L,
  "Gaussian KDE" = 2L,
  "SVM" = 3L
)

legacy_source_seed_index <- c(
  "Occurrence" = 1L,
  "QPH" = 2L,
  "Gaussian KDE" = 3L,
  "SVM" = 4L
)

method_order <- c(
  "Gaussian KDE",
  "SVM",
  "QPH"
)

source_order <- c(
  "Occurrence",
  method_order
)

resume_from_checkpoints <- TRUE
retry_failed_fits <- TRUE
retry_failed_geometry <- TRUE
retry_failed_persistence <- TRUE
verbose_hypervolume <- FALSE

expected_hypervolume_version <- "3.1.6"
expected_tda_stats_version <- "0.4.1"
expected_tda_version <- "1.9.4"

# Locked colours.
method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)

true_region_colour <- "#D9D9D9"
occurrence_colour <- "#111111"

method_shapes <- c(
  "Gaussian KDE" = 16,
  "SVM" = 15,
  "QPH" = 17
)


# ============================================================
# Required upstream inputs
# ============================================================

main_occurrence_archive_file <- file.path(
  locked_input_directory,
  "synthetic_occurrence_clouds_authoritative.rds"
)

geometry_results_file <- file.path(
  geometry_output_directory,
  "synthetic_geometry_results_sqrtNB_q099.rds"
)

required_input_files <- c(
  main_occurrence_archive_file,
  geometry_results_file
)

missing_input_files <- required_input_files[
  !file.exists(
    required_input_files
  )
]

if (length(missing_input_files) > 0L) {
  stop(
    "The following revised 2D input file(s) are missing:\n  ",
    paste(
      missing_input_files,
      collapse = "\n  "
    ),
    "\nRun revised Scripts 01 and 02 before the robustness analysis."
  )
}



# ============================================================
# Output files
# ============================================================

settings_file <- file.path(
  output_directory,
  "analysis_settings_2D_independent_draws_sqrtNB_q099.rds"
)

model_registry_file <- file.path(
  output_directory,
  "independent_draw_model_registry_2D_sqrtNB_q099.rds"
)

model_summary_file <- file.path(
  output_directory,
  "independent_draw_model_summary_2D_sqrtNB_q099.csv"
)

qph_audit_summary_file <- file.path(
  output_directory,
  "QPH_independent_draw_audit_summary_sqrtNB_q099.csv"
)

qph_local_s_file <- file.path(
  output_directory,
  "QPH_independent_draw_local_s_sqrtNB_q099.csv"
)

geometry_registry_file <- file.path(
  output_directory,
  "independent_draw_geometry_registry_2D_sqrtNB_q099.rds"
)

geometry_replicate_file <- file.path(
  output_directory,
  "independent_draw_geometry_replicates_2D_sqrtNB_q099.csv"
)

geometry_summary_file <- file.path(
  output_directory,
  "independent_draw_geometry_mean_sd_2D_sqrtNB_q099.csv"
)

geometry_winner_file <- file.path(
  output_directory,
  "independent_draw_geometry_winner_frequencies_2D_sqrtNB_q099.csv"
)

ph_registry_file <- file.path(
  output_directory,
  "independent_draw_persistence_registry_2D_sqrtNB_q099.rds"
)

topology_subsample_file <- file.path(
  output_directory,
  "independent_draw_topology_subsample_indices_2D_sqrtNB_q099.rds"
)

topology_replicate_file <- file.path(
  output_directory,
  "independent_draw_topology_bottleneck_replicates_2D_sqrtNB_q099.csv"
)

topology_summary_file <- file.path(
  output_directory,
  "independent_draw_topology_bottleneck_mean_sd_2D_sqrtNB_q099.csv"
)

topology_winner_file <- file.path(
  output_directory,
  "independent_draw_topology_winner_frequencies_2D_sqrtNB_q099.csv"
)

compact_summary_file <- file.path(
  output_directory,
  "independent_occurrence_draw_robustness_summary_2D_sqrtNB_q099.csv"
)

geometry_figure_file <- file.path(
  output_directory,
  "Independent_draw_geometry_absolute_error_2D_sqrtNB_q099.pdf"
)

topology_figure_file <- file.path(
  output_directory,
  "Independent_draw_topology_bottleneck_2D_sqrtNB_q099.pdf"
)

failure_file <- file.path(
  output_directory,
  "independent_draw_failures_2D_sqrtNB_q099.csv"
)

notes_file <- file.path(
  output_directory,
  "INDEPENDENT_DRAW_ROBUSTNESS_NOTES_2D_sqrtNB_q099.txt"
)

session_information_file <- file.path(
  output_directory,
  "session_information_2D_independent_draws_sqrtNB_q099.txt"
)


# ============================================================
# Utility helpers
# ============================================================

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

      invisible(file)
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
        basename(file),
        "; writing ",
        basename(alternative_file),
        " instead. Original error: ",
        conditionMessage(error_condition)
      )

      utils::write.csv(
        x,
        file = alternative_file,
        row.names = FALSE
      )

      invisible(alternative_file)
    }
  )
}


safe_md5 <- function(path) {

  if (!file.exists(path)) {
    return(
      NA_character_
    )
  }

  unname(
    tools::md5sum(path)
  )
}


hash_r_object <- function(object) {

  temporary_file <- tempfile(
    pattern = "independent_draw_hash_",
    fileext = ".rds"
  )

  on.exit(
    unlink(temporary_file),
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


safe_sd <- function(x) {

  x <- x[
    is.finite(x)
  ]

  if (length(x) <= 1L) {
    return(
      NA_real_
    )
  }

  stats::sd(x)
}


safe_mean <- function(x) {

  x <- x[
    is.finite(x)
  ]

  if (length(x) == 0L) {
    return(
      NA_real_
    )
  }

  mean(x)
}


set_axis_names <- function(x) {

  x <- as.matrix(x)
  storage.mode(x) <- "double"

  colnames(x) <- c(
    "Environmental axis 1",
    "Environmental axis 2"
  )

  x
}


standardise_points <- function(
    x,
    object_name = "points"
) {

  x <- validate_numeric_matrix(
    x,
    object_name
  )

  if (ncol(x) != 2L) {
    stop(
      object_name,
      " must contain exactly two columns."
    )
  }

  set_axis_names(
    x
  )
}


standardise_hypervolume_axis_names <- function(hv) {

  if (!methods::is(
    hv,
    "Hypervolume"
  )) {
    stop(
      "hv must be a Hypervolume object."
    )
  }

  if (as.integer(
    hv@Dimensionality
  ) != 2L) {
    stop(
      "Expected a two-dimensional Hypervolume object."
    )
  }

  axis_names <- c(
    "Environmental axis 1",
    "Environmental axis 2"
  )

  if (ncol(
    hv@Data
  ) == 2L) {
    colnames(
      hv@Data
    ) <- axis_names
  }

  if (ncol(
    hv@RandomPoints
  ) == 2L) {
    colnames(
      hv@RandomPoints
    ) <- axis_names
  }

  methods::validObject(
    hv
  )

  hv
}


make_key <- function(
    shape_code,
    repetition,
    source = NULL
) {

  base_key <- paste0(
    shape_code,
    "__rep",
    sprintf(
      "%02d",
      as.integer(
        repetition
      )
    )
  )

  if (is.null(
    source
  )) {
    return(
      base_key
    )
  }

  paste0(
    base_key,
    "__",
    gsub(
      "[^A-Za-z0-9]+",
      "_",
      source
    )
  )
}


point_cloud_diameter <- function(points) {

  points <- standardise_points(
    points,
    "points"
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


# ============================================================
# Load main 2D shape definitions and fixed true references
# ============================================================

main_occurrence_archive <- readRDS(
  main_occurrence_archive_file
)

if (
  !is.list(main_occurrence_archive) ||
    is.null(
      main_occurrence_archive$master_datasets
    )
) {
  stop(
    "The revised main occurrence archive has an unexpected structure."
  )
}

if (!identical(
  names(
    main_occurrence_archive$master_datasets
  ),
  shape_order
)) {
  stop(
    "The revised main occurrence archive does not contain the expected ",
    "five 2D shapes in the locked order."
  )
}

geometry_results <- readRDS(
  geometry_results_file
)

if (
  !is.list(geometry_results) ||
    is.null(
      geometry_results$true_references
    )
) {
  stop(
    "The revised geometry result object does not contain true_references."
  )
}

true_references <- geometry_results$true_references

if (!all(
  shape_order %in% names(
    true_references
  )
)) {
  stop(
    "The fixed true-region references are missing one or more 2D shapes."
  )
}

shape_true_area <- vapply(
  shape_order,
  function(shape_code) {
    as.numeric(
      main_occurrence_archive$master_datasets[[shape_code]]$true_area
    )
  },
  numeric(1)
)

shape_parameters <- lapply(
  shape_order,
  function(shape_code) {
    main_occurrence_archive$master_datasets[[shape_code]]$parameters
  }
)

names(
  shape_parameters
) <- shape_order

for (shape_code in shape_order) {

  if (!isTRUE(all.equal(
    as.numeric(
      true_references[[shape_code]]$true_area
    ),
    as.numeric(
      shape_true_area[[shape_code]]
    )
  ))) {
    stop(
      "True-area mismatch between main occurrence archive and fixed ",
      "geometry reference for ",
      shape_code,
      "."
    )
  }

  reference_hv <- standardise_hypervolume_axis_names(
    true_references[[shape_code]]$hypervolume
  )

  if (nrow(
    reference_hv@RandomPoints
  ) != 100000L) {
    warning(
      "Fixed true-region reference for ",
      shape_code,
      " contains ",
      nrow(
        reference_hv@RandomPoints
      ),
      " points rather than the expected 100000. The saved revised ",
      "reference will nevertheless be reused exactly."
    )
  }
}


# ============================================================
# Exact 2D generators retained from the main synthetic benchmark
# ============================================================

rotate_and_translate <- function(
    x,
    y,
    angle = 0,
    centre = c(0, 0)
) {

  cos_angle <- cos(
    angle
  )

  sin_angle <- sin(
    angle
  )

  cbind(
    x = cos_angle * x - sin_angle * y + centre[
      1L
    ],
    y = sin_angle * x + cos_angle * y + centre[
      2L
    ]
  )
}


generate_spiral_band_from_parameters <- function(
    n,
    parameters
) {

  inner_intercept <- parameters$inner_intercept
  radial_growth <- parameters$radial_growth
  band_width <- parameters$band_width
  theta_min <- parameters$theta_min
  theta_max <- parameters$theta_max
  rotation <- parameters$rotation

  if (is.null(
    rotation
  )) {
    rotation <- 0
  }

  inner_radius_function <- function(theta) {
    inner_intercept +
      radial_growth * theta
  }

  outer_radius_function <- function(theta) {
    inner_radius_function(
      theta
    ) +
      band_width
  }

  angular_weight <- function(theta) {
    outer_radius_function(theta)^2 -
      inner_radius_function(theta)^2
  }

  theta_grid <- seq(
    theta_min,
    theta_max,
    length.out = 5000L
  )

  maximum_weight <- max(
    angular_weight(
      theta_grid
    )
  )

  sampled_theta <- numeric(
    n
  )

  number_filled <- 0L

  while (
    number_filled <
      n
  ) {

    number_needed <- n -
      number_filled

    number_proposed <- max(
      1000L,
      ceiling(
        number_needed *
          2
      )
    )

    proposed_theta <- stats::runif(
      number_proposed,
      min = theta_min,
      max = theta_max
    )

    acceptance_probability <- (
      angular_weight(
        proposed_theta
      ) /
        maximum_weight
    )

    accepted_theta <- proposed_theta[
      stats::runif(
        number_proposed
      ) <= acceptance_probability
    ]

    number_accepted <- min(
      length(
        accepted_theta
      ),
      number_needed
    )

    if (
      number_accepted >
        0L
    ) {

      destination_indices <- seq.int(
        from = number_filled + 1L,
        length.out = number_accepted
      )

      sampled_theta[
        destination_indices
      ] <- accepted_theta[
        seq_len(
          number_accepted
        )
      ]

      number_filled <- number_filled +
        number_accepted
    }
  }

  inner_radius <- inner_radius_function(
    sampled_theta
  )

  outer_radius <- outer_radius_function(
    sampled_theta
  )

  sampled_radius <- sqrt(
    inner_radius^2 +
      stats::runif(n) * (
        outer_radius^2 -
          inner_radius^2
      )
  )

  points <- rotate_and_translate(
    x = sampled_radius *
      cos(
        sampled_theta
      ),
    y = sampled_radius *
      sin(
        sampled_theta
      ),
    angle = rotation,
    centre = c(
      0,
      0
    )
  )

  set_axis_names(
    points
  )
}


generate_ellipse_from_parameters <- function(
    n,
    parameters
) {

  theta <- stats::runif(
    n,
    min = 0,
    max = 2 * pi
  )

  radial_fraction <- sqrt(
    stats::runif(
      n
    )
  )

  points <- rotate_and_translate(
    x = parameters$semi_axis_1 *
      radial_fraction *
      cos(
        theta
      ),
    y = parameters$semi_axis_2 *
      radial_fraction *
      sin(
        theta
      ),
    angle = parameters$rotation,
    centre = c(
      0,
      0
    )
  )

  set_axis_names(
    points
  )
}


generate_annulus_from_parameters <- function(
    n,
    parameters
) {

  theta <- stats::runif(
    n,
    min = 0,
    max = 2 * pi
  )

  radius <- sqrt(
    parameters$inner_radius^2 +
      stats::runif(n) * (
        parameters$outer_radius^2 -
          parameters$inner_radius^2
      )
  )

  points <- cbind(
    "Environmental axis 1" = radius *
      cos(
        theta
      ),
    "Environmental axis 2" = radius *
      sin(
        theta
      )
  )

  set_axis_names(
    points
  )
}


generate_banana_from_parameters <- function(
    n,
    parameters
) {

  theta <- stats::runif(
    n,
    min = 0,
    max = 2 * pi
  )

  radial_fraction <- sqrt(
    stats::runif(
      n
    )
  )

  ellipse_x <- (
    parameters$semi_axis_1 *
      radial_fraction *
      cos(
        theta
      )
  )

  ellipse_y <- (
    parameters$semi_axis_2 *
      radial_fraction *
      sin(
        theta
      )
  )

  banana_x <- ellipse_x

  banana_y <- ellipse_y +
    parameters$curvature * (
      ellipse_x^2 -
        parameters$semi_axis_1^2 /
          2
    )

  points <- rotate_and_translate(
    x = banana_x,
    y = banana_y,
    angle = parameters$rotation,
    centre = c(
      0,
      0
    )
  )

  set_axis_names(
    points
  )
}


generate_two_disks_from_parameters <- function(
    n,
    parameters
) {

  number_in_first <- ceiling(
    n /
      2
  )

  number_in_second <- floor(
    n /
      2
  )

  sample_disk <- function(
      number_of_points,
      disk_centre
  ) {

    theta <- stats::runif(
      number_of_points,
      min = 0,
      max = 2 * pi
    )

    radial_distance <- (
      parameters$radius *
        sqrt(
          stats::runif(
            number_of_points
          )
        )
    )

    cbind(
      x = disk_centre[
        1L
      ] +
        radial_distance *
          cos(
            theta
          ),
      y = disk_centre[
        2L
      ] +
        radial_distance *
          sin(
            theta
          )
    )
  }

  first_disk <- sample_disk(
    number_in_first,
    parameters$centre_1
  )

  second_disk <- sample_disk(
    number_in_second,
    parameters$centre_2
  )

  # Retain the original interleaving rule so each even-size draw is exactly
  # balanced between components.
  points <- matrix(
    NA_real_,
    nrow = n,
    ncol = 2L
  )

  points[
    seq.int(
      1L,
      n,
      by = 2L
    ),
  ] <- first_disk

  if (
    number_in_second >
      0L
  ) {
    points[
      seq.int(
        2L,
        n,
        by = 2L
      ),
    ] <- second_disk
  }

  set_axis_names(
    points
  )
}


generate_occurrence_cloud <- function(
    shape_code,
    n,
    seed
) {

  parameters <- shape_parameters[[shape_code]]

  if (is.null(
    parameters
  )) {
    stop(
      "No locked parameters found for shape ",
      shape_code,
      "."
    )
  }

  set.seed(
    as.integer(
      seed
    )
  )

  if (identical(
    shape_code,
    "spiral"
  )) {
    return(
      generate_spiral_band_from_parameters(
        n,
        parameters
      )
    )
  }

  if (identical(
    shape_code,
    "ellipse"
  )) {
    return(
      generate_ellipse_from_parameters(
        n,
        parameters
      )
    )
  }

  if (identical(
    shape_code,
    "annulus"
  )) {
    return(
      generate_annulus_from_parameters(
        n,
        parameters
      )
    )
  }

  if (identical(
    shape_code,
    "banana"
  )) {
    return(
      generate_banana_from_parameters(
        n,
        parameters
      )
    )
  }

  if (identical(
    shape_code,
    "two_balls"
  )) {
    return(
      generate_two_disks_from_parameters(
        n,
        parameters
      )
    )
  }

  stop(
    "Unknown shape_code: ",
    shape_code
  )
}


# ============================================================
# Occurrence-archive validation
# ============================================================

expected_generation_seed <- function(
    shape_code,
    repetition
) {

  shape_index <- match(
    shape_code,
    shape_order
  )

  if (is.na(
    shape_index
  )) {
    stop(
      "Unknown shape code in seed function: ",
      shape_code
    )
  }

  as.integer(
    occurrence_seed_base +
      shape_index * 10000L +
      repetition
  )
}


validate_occurrence_draws <- function(
    draws
) {

  if (!is.list(
    draws
  )) {
    stop(
      "Independent occurrence draws must be stored as a list."
    )
  }

  for (shape_code in shape_order) {

    shape_draws <- draws[[shape_code]]

    if (is.null(
      shape_draws
    )) {
      stop(
        "Independent-draw archive is missing shape ",
        shape_code,
        "."
      )
    }

    for (
      repetition in seq_len(
        number_of_independent_draws
      )
    ) {

      repetition_key <- paste0(
        "rep",
        sprintf(
          "%02d",
          repetition
        )
      )

      draw <- shape_draws[[repetition_key]]

      if (is.null(
        draw
      )) {
        stop(
          "Independent-draw archive is missing ",
          shape_code,
          " ",
          repetition_key,
          "."
        )
      }

      if (!isTRUE(
        draw$success
      )) {
        stop(
          "Independent-draw archive contains an unsuccessful occurrence ",
          "draw for ",
          shape_code,
          " ",
          repetition_key,
          "."
        )
      }

      points <- standardise_points(
        draw$points,
        paste0(
          shape_code,
          " ",
          repetition_key
        )
      )

      if (!identical(
        nrow(points),
        sample_size
      )) {
        stop(
          "Independent occurrence draw has incorrect sample size for ",
          shape_code,
          " ",
          repetition_key,
          "."
        )
      }

      expected_seed <- expected_generation_seed(
        shape_code,
        repetition
      )

      if (
        !is.null(
          draw$generation_seed
        ) &&
          !identical(
            as.integer(
              draw$generation_seed
            ),
            expected_seed
          )
      ) {
        stop(
          "Independent occurrence draw has an unexpected generation seed ",
          "for ",
          shape_code,
          " ",
          repetition_key,
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
# Import legacy independent draws or generate them reproducibly
# ============================================================

if (
  resume_from_checkpoints &&
    file.exists(
      occurrence_archive_file
    )
) {

  occurrence_object <- readRDS(
    occurrence_archive_file
  )

  if (
    !is.list(
      occurrence_object
    ) ||
      is.null(
        occurrence_object$draws
      )
  ) {
    stop(
      "Existing revised independent-draw archive has an unexpected structure."
    )
  }

  occurrence_draws <- occurrence_object$draws

  validate_occurrence_draws(
    occurrence_draws
  )

  message(
    "Loaded and verified revised 2D independent occurrence-draw archive."
  )

} else if (file.exists(
  legacy_occurrence_archive_file
)) {

  message(
    "Importing exact QPH-independent 2D occurrence draws from the legacy ",
    "robustness archive..."
  )

  legacy_archive <- readRDS(
    legacy_occurrence_archive_file
  )

  occurrence_draws <- list()

  for (shape_code in shape_order) {

    legacy_shape <- legacy_archive[[shape_code]]

    if (is.null(
      legacy_shape
    )) {
      stop(
        "Legacy occurrence archive is missing shape ",
        shape_code,
        "."
      )
    }

    occurrence_draws[[shape_code]] <- list()

    for (
      repetition in seq_len(
        number_of_independent_draws
      )
    ) {

      repetition_key <- paste0(
        "rep",
        sprintf(
          "%02d",
          repetition
        )
      )

      legacy_draw <- legacy_shape[[repetition_key]]

      if (is.null(
        legacy_draw
      )) {
        stop(
          "Legacy occurrence archive is missing ",
          shape_code,
          " ",
          repetition_key,
          "."
        )
      }

      points <- standardise_points(
        legacy_draw$points,
        paste0(
          "legacy ",
          shape_code,
          " ",
          repetition_key
        )
      )

      occurrence_draws[[shape_code]][[repetition_key]] <- list(
        success = TRUE,
        shape_code = shape_code,
        shape = unname(
          shape_labels[[shape_code]]
        ),
        dimensionality = 2L,
        sample_size = sample_size,
        repetition = repetition,
        generation_seed = expected_generation_seed(
          shape_code,
          repetition
        ),
        points = points,
        source = "Imported from legacy QPH-independent robustness archive"
      )
    }
  }

  validate_occurrence_draws(
    occurrence_draws
  )

  saveRDS(
    list(
      metadata = list(
        sample_size = sample_size,
        number_of_independent_draws = number_of_independent_draws,
        shape_order = shape_order,
        occurrence_seed_base = occurrence_seed_base,
        source = "Legacy independent occurrence-draw robustness archive",
        legacy_archive_path = legacy_occurrence_archive_file,
        legacy_archive_md5 = safe_md5(
          legacy_occurrence_archive_file
        ),
        created_at = as.character(
          Sys.time()
        )
      ),
      draws = occurrence_draws
    ),
    occurrence_archive_file,
    version = 3
  )

} else {

  message(
    "Legacy independent occurrence-draw archive unavailable. Reproducing ",
    "the same 2D draws from the locked generators and original seeds..."
  )

  occurrence_draws <- list()

  for (
    shape_index in seq_along(
      shape_order
    )
  ) {

    shape_code <- shape_order[[shape_index]]

    occurrence_draws[[shape_code]] <- list()

    for (
      repetition in seq_len(
        number_of_independent_draws
      )
    ) {

      generation_seed <- expected_generation_seed(
        shape_code,
        repetition
      )

      repetition_key <- paste0(
        "rep",
        sprintf(
          "%02d",
          repetition
        )
      )

      points <- generate_occurrence_cloud(
        shape_code = shape_code,
        n = sample_size,
        seed = generation_seed
      )

      points <- standardise_points(
        points,
        paste0(
          shape_code,
          " ",
          repetition_key
        )
      )

      occurrence_draws[[shape_code]][[repetition_key]] <- list(
        success = TRUE,
        shape_code = shape_code,
        shape = unname(
          shape_labels[[shape_code]]
        ),
        dimensionality = 2L,
        sample_size = sample_size,
        repetition = repetition,
        generation_seed = generation_seed,
        points = points,
        source = "Regenerated from locked generator and original seed"
      )

      saveRDS(
        list(
          metadata = list(
            sample_size = sample_size,
            number_of_independent_draws = number_of_independent_draws,
            shape_order = shape_order,
            occurrence_seed_base = occurrence_seed_base,
            source = "Locked generator and original seed",
            created_at = as.character(
              Sys.time()
            )
          ),
          draws = occurrence_draws
        ),
        occurrence_archive_file,
        version = 3
      )
    }
  }

  validate_occurrence_draws(
    occurrence_draws
  )
}


# ============================================================
# Write transparent occurrence-cloud manifest and CSV copies
# ============================================================

occurrence_manifest_rows <- list()
occurrence_manifest_index <- 0L

for (
  shape_index in seq_along(
    shape_order
  )
) {

  shape_code <- shape_order[[shape_index]]
  shape_label <- unname(
    shape_labels[[shape_code]]
  )

  for (
    repetition in seq_len(
      number_of_independent_draws
    )
  ) {

    repetition_key <- paste0(
      "rep",
      sprintf(
        "%02d",
        repetition
      )
    )

    draw <- occurrence_draws[[shape_code]][[repetition_key]]

    occurrence_csv <- file.path(
      occurrence_directory,
      paste0(
        shape_code,
        "_rep",
        sprintf(
          "%02d",
          repetition
        ),
        "_n900.csv"
      )
    )

    utils::write.csv(
      draw$points,
      occurrence_csv,
      row.names = FALSE
    )

    occurrence_manifest_index <- occurrence_manifest_index +
      1L

    occurrence_manifest_rows[[occurrence_manifest_index]] <- data.frame(
      Shape_code = shape_code,
      Shape = shape_label,
      Repetition = repetition,
      Sample_size = sample_size,
      Generation_seed = draw$generation_seed,
      Source = draw$source,
      Occurrence_file = normalizePath(
        occurrence_csv,
        mustWork = FALSE
      ),
      Occurrence_file_MD5 = safe_md5(
        occurrence_csv
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

write_csv_safely(
  occurrence_manifest,
  occurrence_manifest_file
)

if (!identical(
  nrow(
    occurrence_manifest
  ),
  length(shape_order) *
    number_of_independent_draws
)) {
  stop(
    "Occurrence manifest does not contain the expected 50 independent draws."
  )
}

occurrence_archive_md5 <- safe_md5(
  occurrence_archive_file
)


# ============================================================
# Package-version checks
# ============================================================

installed_hypervolume_version <- as.character(
  utils::packageVersion(
    "hypervolume"
  )
)

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

if (!identical(
  installed_hypervolume_version,
  expected_hypervolume_version
)) {
  warning(
    "hypervolume version ",
    installed_hypervolume_version,
    " is installed; previous manuscript code recorded ",
    expected_hypervolume_version,
    "."
  )
}

if (!identical(
  installed_tda_stats_version,
  expected_tda_stats_version
)) {
  warning(
    "TDAstats version ",
    installed_tda_stats_version,
    " is installed; previous manuscript code recorded ",
    expected_tda_stats_version,
    "."
  )
}

if (!identical(
  installed_tda_version,
  expected_tda_version
)) {
  warning(
    "TDA version ",
    installed_tda_version,
    " is installed; previous manuscript code recorded ",
    expected_tda_version,
    "."
  )
}


# ============================================================
# Analysis settings and checkpoint signature
# ============================================================

analysis_settings <- list(
  script = "05_2D_Independent_Occurrence_Robustness.R",
  sample_size = sample_size,
  number_of_independent_draws = number_of_independent_draws,
  shape_order = shape_order,
  shape_labels = shape_labels,
  qph_core_version = QPH_CORE_VERSION,
  qph_core_md5 = qph_core_md5,
  qph_q = qph_q,
  qph_samples_per_point = qph_samples_per_point,
  qph_sd_count = qph_sd_count,
  kde_bandwidth_method = kde_bandwidth_method,
  kde_quantile = kde_quantile,
  kde_samples_per_point = kde_samples_per_point,
  kde_sd_count = kde_sd_count,
  svm_nu = svm_nu,
  svm_gamma = svm_gamma,
  svm_scale_factor = svm_scale_factor,
  svm_samples_per_point = svm_samples_per_point,
  jaccard_num_points_max = jaccard_num_points_max,
  jaccard_distance_factor = jaccard_distance_factor,
  topology_target_dimension = topology_target_dimension,
  ph_sample_size = ph_sample_size,
  maximum_homology_dimension = maximum_homology_dimension,
  ph_threshold = ph_threshold,
  ph_prime_field = ph_prime_field,
  ph_standardize = ph_standardize,
  ph_timeout_seconds = ph_timeout_seconds,
  seeds = list(
    occurrence_seed_base = occurrence_seed_base,
    qph_kde_sampling_seed_base = qph_kde_sampling_seed_base,
    svm_sampling_seed_base = svm_sampling_seed_base,
    topology_sampling_seed_base = topology_sampling_seed_base,
    jaccard_seed_base = jaccard_seed_base
  ),
  input_md5 = list(
    occurrence_archive = occurrence_archive_md5,
    main_occurrence_archive = safe_md5(
      main_occurrence_archive_file
    ),
    geometry_results = safe_md5(
      geometry_results_file
    )
  ),
  colours = list(
    method_colours = method_colours,
    true_region_colour = true_region_colour,
    occurrence_colour = occurrence_colour
  ),
  package_versions = list(
    hypervolume = installed_hypervolume_version,
    TDAstats = installed_tda_stats_version,
    TDA = installed_tda_version
  )
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
  settings_file,
  version = 3
)


# ============================================================
# Fit one baseline model to one independent draw
# ============================================================

fit_one_baseline_model <- function(
    occurrence_points,
    shape_code,
    repetition,
    method_name,
    qph_kde_seed,
    svm_seed
) {

  occurrence_points <- standardise_points(
    occurrence_points,
    "occurrence_points"
  )

  start_time <- proc.time()[[
    "elapsed"
  ]]

  fit_result <- tryCatch(
    {

      if (identical(
        method_name,
        "QPH"
      )) {

        bandwidth_info <- estimate_qph_sqrt_nb_bandwidth(
          occurrence_points
        )

        qph_result <- construct_qph(
          data = occurrence_points,
          bandwidth_info = bandwidth_info,
          name = paste0(
            "QPH: ",
            unname(
              shape_labels[[shape_code]]
            ),
            ", independent draw ",
            repetition
          ),
          samples_per_point = qph_samples_per_point,
          sd_count = qph_sd_count,
          q = qph_q,
          sampling_seed = qph_kde_seed,
          sampling_chunk_size = qph_sampling_chunk_size,
          potential_batch_size = qph_potential_batch_size,
          verbose = verbose_hypervolume
        )

        hv <- standardise_hypervolume_axis_names(
          qph_result$hypervolume
        )

        list(
          success = TRUE,
          hypervolume = hv,
          qph_result = qph_result,
          bandwidth = as.numeric(
            qph_result$audit$fitted_bandwidth
          ),
          bandwidth_method = qph_result$audit$bandwidth_method,
          error_message = NA_character_
        )

      } else if (identical(
        method_name,
        "Gaussian KDE"
      )) {

        kde_bandwidth <- hypervolume::estimate_bandwidth(
          data = occurrence_points,
          method = kde_bandwidth_method
        )

        bandwidth_method_attribute <- attr(
          kde_bandwidth,
          "method"
        )

        set.seed(
          as.integer(
            qph_kde_seed
          )
        )

        hv <- hypervolume::hypervolume_gaussian(
          data = occurrence_points,
          name = paste0(
            "Gaussian KDE: ",
            unname(
              shape_labels[[shape_code]]
            ),
            ", independent draw ",
            repetition
          ),
          kde.bandwidth = kde_bandwidth,
          samples.per.point = kde_samples_per_point,
          sd.count = kde_sd_count,
          quantile.requested = kde_quantile,
          quantile.requested.type = "probability",
          chunk.size = kde_chunk_size,
          verbose = verbose_hypervolume
        )

        hv <- standardise_hypervolume_axis_names(
          hv
        )

        list(
          success = TRUE,
          hypervolume = hv,
          qph_result = NULL,
          bandwidth = as.numeric(
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
          error_message = NA_character_
        )

      } else if (identical(
        method_name,
        "SVM"
      )) {

        set.seed(
          as.integer(
            svm_seed
          )
        )

        hv <- hypervolume::hypervolume_svm(
          data = occurrence_points,
          name = paste0(
            "SVM: ",
            unname(
              shape_labels[[shape_code]]
            ),
            ", independent draw ",
            repetition
          ),
          samples.per.point = svm_samples_per_point,
          svm.nu = svm_nu,
          svm.gamma = svm_gamma,
          scale.factor = svm_scale_factor,
          chunk.size = svm_chunk_size,
          verbose = verbose_hypervolume
        )

        hv <- standardise_hypervolume_axis_names(
          hv
        )

        list(
          success = TRUE,
          hypervolume = hv,
          qph_result = NULL,
          bandwidth = c(
            NA_real_,
            NA_real_
          ),
          bandwidth_method = NA_character_,
          error_message = NA_character_
        )

      } else {

        stop(
          "Unknown method_name: ",
          method_name
        )
      }
    },
    error = function(error_condition) {

      list(
        success = FALSE,
        hypervolume = NULL,
        qph_result = NULL,
        bandwidth = c(
          NA_real_,
          NA_real_
        ),
        bandwidth_method = NA_character_,
        error_message = conditionMessage(
          error_condition
        )
      )
    }
  )

  runtime_seconds <- proc.time()[[
    "elapsed"
  ]] -
    start_time

  list(
    success = fit_result$success,
    shape_code = shape_code,
    shape = unname(
      shape_labels[[shape_code]]
    ),
    dimensionality = 2L,
    repetition = as.integer(
      repetition
    ),
    sample_size = nrow(
      occurrence_points
    ),
    method = method_name,
    bandwidth = fit_result$bandwidth,
    bandwidth_method = fit_result$bandwidth_method,
    qph_kde_sampling_seed = as.integer(
      qph_kde_seed
    ),
    svm_sampling_seed = as.integer(
      svm_seed
    ),
    runtime_seconds = runtime_seconds,
    occurrence_points = occurrence_points,
    hypervolume = fit_result$hypervolume,
    qph_result = fit_result$qph_result,
    error_message = fit_result$error_message
  )
}


# ============================================================
# Fit/reuse all 150 baseline estimator objects
# ============================================================

if (
  resume_from_checkpoints &&
    file.exists(
      model_registry_file
    )
) {

  model_checkpoint <- readRDS(
    model_registry_file
  )

  if (
    !is.list(
      model_checkpoint
    ) ||
      !identical(
        model_checkpoint$analysis_settings_hash,
        analysis_settings_hash
      )
  ) {
    stop(
      "Existing independent-draw model checkpoint was produced with ",
      "different inputs or settings. Do not mix old-QPH and revised-QPH ",
      "results."
    )
  }

  model_registry <- model_checkpoint$registry

} else {

  model_registry <- list()
}


save_model_registry <- function() {

  saveRDS(
    list(
      analysis_settings_hash = analysis_settings_hash,
      registry = model_registry,
      last_updated = as.character(
        Sys.time()
      )
    ),
    model_registry_file,
    version = 3
  )
}


for (
  shape_index in seq_along(
    shape_order
  )
) {

  shape_code <- shape_order[[shape_index]]
  shape_label <- unname(
    shape_labels[[shape_code]]
  )

  for (
    repetition in seq_len(
      number_of_independent_draws
    )
  ) {

    occurrence_key <- paste0(
      "rep",
      sprintf(
        "%02d",
        repetition
      )
    )

    occurrence_points <- occurrence_draws[[shape_code]][[occurrence_key]]$points

    qph_kde_seed <- as.integer(
      qph_kde_sampling_seed_base +
        shape_index * 10000L +
        repetition
    )

    svm_seed <- as.integer(
      svm_sampling_seed_base +
        shape_index * 10000L +
        repetition
    )

    for (method_name in method_order) {

      model_key <- make_key(
        shape_code,
        repetition,
        method_name
      )

      model_file <- file.path(
        model_directory,
        paste0(
          model_key,
          ".rds"
        )
      )

      existing <- model_registry[[model_key]]

      should_run <- is.null(
        existing
      )

      if (!is.null(
        existing
      )) {

        if (
          isTRUE(
            existing$success
          ) &&
            !is.na(
              existing$model_file
            ) &&
            file.exists(
              existing$model_file
            )
        ) {
          should_run <- FALSE

        } else if (
          retry_failed_fits
        ) {
          should_run <- TRUE

        } else {
          should_run <- FALSE
        }
      }

      if (!should_run) {
        next
      }

      message(
        "Fitting ",
        method_name,
        ": ",
        shape_label,
        ", independent draw ",
        repetition,
        "/",
        number_of_independent_draws
      )

      fit <- fit_one_baseline_model(
        occurrence_points = occurrence_points,
        shape_code = shape_code,
        repetition = repetition,
        method_name = method_name,
        qph_kde_seed = qph_kde_seed,
        svm_seed = svm_seed
      )

      if (isTRUE(
        fit$success
      )) {
        saveRDS(
          fit,
          model_file,
          version = 3
        )
      }

      model_registry[[model_key]] <- list(
        success = fit$success,
        shape_code = shape_code,
        repetition = repetition,
        method = method_name,
        model_file = if (
          fit$success
        ) {
          model_file
        } else {
          NA_character_
        },
        runtime_seconds = fit$runtime_seconds,
        error_message = fit$error_message
      )

      save_model_registry()
    }
  }
}


# ============================================================
# Model summary and complete QPH bandwidth audits
# ============================================================

model_summary_rows <- list()
model_summary_index <- 0L

qph_audit_rows <- list()
qph_audit_index <- 0L

qph_local_s_rows <- list()
qph_local_s_index <- 0L

for (
  shape_index in seq_along(
    shape_order
  )
) {

  shape_code <- shape_order[[shape_index]]
  shape_label <- unname(
    shape_labels[[shape_code]]
  )

  for (
    repetition in seq_len(
      number_of_independent_draws
    )
  ) {

    for (method_name in method_order) {

      model_key <- make_key(
        shape_code,
        repetition,
        method_name
      )

      registry_entry <- model_registry[[model_key]]

      model_summary_index <- model_summary_index +
        1L

      if (
        !is.null(
          registry_entry
        ) &&
          isTRUE(
            registry_entry$success
          ) &&
          file.exists(
            registry_entry$model_file
          )
      ) {

        fit <- readRDS(
          registry_entry$model_file
        )

        hv <- fit$hypervolume

        bandwidth <- as.numeric(
          fit$bandwidth
        )

        model_summary_rows[[model_summary_index]] <- data.frame(
          Shape_code = shape_code,
          Shape = shape_label,
          Repetition = repetition,
          Method = method_name,
          Success = TRUE,
          Hypervolume_area = as.numeric(
            hv@Volume
          ),
          Random_points = nrow(
            hv@RandomPoints
          ),
          Runtime_seconds = fit$runtime_seconds,
          Bandwidth_method = fit$bandwidth_method,
          Bandwidth_axis_1 = bandwidth[
            1L
          ],
          Bandwidth_axis_2 = bandwidth[
            2L
          ],
          QPH_q = if (
            identical(
              method_name,
              "QPH"
            )
          ) {
            fit$qph_result$audit$q
          } else {
            NA_real_
          },
          QPH_K = if (
            identical(
              method_name,
              "QPH"
            )
          ) {
            fit$qph_result$audit$K
          } else {
            NA_integer_
          },
          Sampling_seed = if (
            identical(
              method_name,
              "SVM"
            )
          ) {
            fit$svm_sampling_seed
          } else {
            fit$qph_kde_sampling_seed
          },
          Error_message = NA_character_,
          stringsAsFactors = FALSE
        )

        if (identical(
          method_name,
          "QPH"
        )) {

          audit <- fit$qph_result$audit

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
              "Unexpected QPH K in independent-draw fit ",
              model_key,
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
              "QPH h != sqrt(mean(local_s)) for ",
              model_key,
              "."
            )
          }

          if (!isTRUE(all.equal(
            as.numeric(
              audit$fitted_bandwidth
            ),
            rep(
              audit$baseline_scalar_h,
              2L
            ),
            tolerance = 1e-12
          ))) {
            stop(
              "Independent-draw QPH bandwidth is not isotropic for ",
              model_key,
              "."
            )
          }

          if (!isTRUE(all.equal(
            as.numeric(
              audit$q
            ),
            qph_q
          ))) {
            stop(
              "Independent-draw QPH q is not 0.99 for ",
              model_key,
              "."
            )
          }

          qph_audit_index <- qph_audit_index +
            1L

          qph_audit_rows[[qph_audit_index]] <- data.frame(
            Shape_code = shape_code,
            Shape = shape_label,
            Repetition = repetition,
            n = audit$n,
            d = audit$d,
            K = audit$K,
            Mean_s = audit$mean_s,
            Scalar_h = audit$baseline_scalar_h,
            Bandwidth_axis_1 = audit$fitted_bandwidth[
              1L
            ],
            Bandwidth_axis_2 = audit$fitted_bandwidth[
              2L
            ],
            q = audit$q,
            Samples_per_point = audit$samples_per_point,
            SD_count = audit$sd_count,
            Sampling_seed = audit$sampling_seed,
            Retained_fraction = fit$qph_result$retained_fraction,
            stringsAsFactors = FALSE
          )

          qph_local_s_index <- qph_local_s_index +
            1L

          qph_local_s_rows[[qph_local_s_index]] <- data.frame(
            Shape_code = shape_code,
            Shape = shape_label,
            Repetition = repetition,
            Occurrence_index = seq_along(
              audit$local_s
            ),
            K = audit$K,
            s_i = as.numeric(
              audit$local_s
            ),
            Mean_s = audit$mean_s,
            Scalar_h = audit$baseline_scalar_h,
            q = audit$q,
            Sampling_seed = audit$sampling_seed,
            stringsAsFactors = FALSE
          )
        }

      } else {

        model_summary_rows[[model_summary_index]] <- data.frame(
          Shape_code = shape_code,
          Shape = shape_label,
          Repetition = repetition,
          Method = method_name,
          Success = FALSE,
          Hypervolume_area = NA_real_,
          Random_points = NA_integer_,
          Runtime_seconds = if (
            is.null(
              registry_entry
            )
          ) {
            NA_real_
          } else {
            registry_entry$runtime_seconds
          },
          Bandwidth_method = NA_character_,
          Bandwidth_axis_1 = NA_real_,
          Bandwidth_axis_2 = NA_real_,
          QPH_q = NA_real_,
          QPH_K = NA_integer_,
          Sampling_seed = NA_integer_,
          Error_message = if (
            is.null(
              registry_entry
            )
          ) {
            "Missing registry entry"
          } else {
            registry_entry$error_message
          },
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

model_summary <- do.call(
  rbind,
  model_summary_rows
)

rownames(
  model_summary
) <- NULL

model_summary <- model_summary[
  order(
    match(
      model_summary$Shape_code,
      shape_order
    ),
    model_summary$Repetition,
    match(
      model_summary$Method,
      method_order
    )
  ),
  ,
  drop = FALSE
]

write_csv_safely(
  model_summary,
  model_summary_file
)

if (length(
  qph_audit_rows
) > 0L) {

  qph_audit_summary <- do.call(
    rbind,
    qph_audit_rows
  )

  rownames(
    qph_audit_summary
  ) <- NULL

  write_csv_safely(
    qph_audit_summary,
    qph_audit_summary_file
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

  write_csv_safely(
    qph_local_s_table,
    qph_local_s_file
  )
}


# ============================================================
# Geometry calculations
# ============================================================

geometry_settings <- list(
  analysis_settings_hash = analysis_settings_hash,
  geometry_results_md5 = safe_md5(
    geometry_results_file
  ),
  jaccard_num_points_max = jaccard_num_points_max,
  jaccard_distance_factor = jaccard_distance_factor,
  jaccard_seed_base = jaccard_seed_base
)

geometry_settings_hash <- hash_r_object(
  geometry_settings
)

if (
  resume_from_checkpoints &&
    file.exists(
      geometry_registry_file
    )
) {

  geometry_checkpoint <- readRDS(
    geometry_registry_file
  )

  if (!identical(
    geometry_checkpoint$geometry_settings_hash,
    geometry_settings_hash
  )) {
    stop(
      "Existing independent-draw geometry checkpoint was produced with ",
      "different inputs or settings."
    )
  }

  geometry_registry <- geometry_checkpoint$registry

} else {

  geometry_registry <- list()
}


save_geometry_registry <- function() {

  saveRDS(
    list(
      geometry_settings_hash = geometry_settings_hash,
      registry = geometry_registry,
      last_updated = as.character(
        Sys.time()
      )
    ),
    geometry_registry_file,
    version = 3
  )
}


for (
  shape_index in seq_along(
    shape_order
  )
) {

  shape_code <- shape_order[[shape_index]]
  shape_label <- unname(
    shape_labels[[shape_code]]
  )

  true_area <- as.numeric(
    shape_true_area[[shape_code]]
  )

  reference <- true_references[[shape_code]]

  true_hv <- standardise_hypervolume_axis_names(
    reference$hypervolume
  )

  true_centroid <- as.numeric(
    reference$true_centroid
  )

  for (
    repetition in seq_len(
      number_of_independent_draws
    )
  ) {

    for (method_name in method_order) {

      model_key <- make_key(
        shape_code,
        repetition,
        method_name
      )

      geometry_key <- model_key

      existing <- geometry_registry[[geometry_key]]

      should_run <- is.null(
        existing
      )

      if (!is.null(
        existing
      )) {

        if (isTRUE(
          existing$success
        )) {
          should_run <- FALSE

        } else if (
          retry_failed_geometry
        ) {
          should_run <- TRUE

        } else {
          should_run <- FALSE
        }
      }

      if (!should_run) {
        next
      }

      model_entry <- model_registry[[model_key]]

      if (
        is.null(
          model_entry
        ) ||
          !isTRUE(
            model_entry$success
          ) ||
          !file.exists(
            model_entry$model_file
          )
      ) {

        geometry_registry[[geometry_key]] <- list(
          success = FALSE,
          summary = data.frame(
            Shape_code = shape_code,
            Shape = shape_label,
            Repetition = repetition,
            Method = method_name,
            Success = FALSE,
            True_area = true_area,
            Estimated_area = NA_real_,
            Signed_area_error = NA_real_,
            Absolute_area_error = NA_real_,
            Relative_area_error_percent = NA_real_,
            Absolute_relative_area_error_percent = NA_real_,
            Intersection_area = NA_real_,
            Union_area = NA_real_,
            Jaccard_similarity = NA_real_,
            Sorensen_similarity = NA_real_,
            True_region_coverage = NA_real_,
            Excess_estimated_area = NA_real_,
            Excess_estimated_fraction = NA_real_,
            Centroid_displacement = NA_real_,
            Runtime_seconds = NA_real_,
            Set_operation_runtime_seconds = NA_real_,
            Jaccard_seed = NA_integer_,
            Error_message = "Missing or failed model fit",
            stringsAsFactors = FALSE
          )
        )

        save_geometry_registry()

        next
      }

      fit <- readRDS(
        model_entry$model_file
      )

      hv <- standardise_hypervolume_axis_names(
        fit$hypervolume
      )

      method_seed_index <- unname(
        legacy_method_seed_index[[method_name]]
      )

      set_operation_seed <- as.integer(
        jaccard_seed_base +
          shape_index * 10000L +
          repetition * 100L +
          method_seed_index
      )

      message(
        "Geometry: ",
        shape_label,
        ", independent draw ",
        repetition,
        ", ",
        method_name
      )

      result <- tryCatch(
        {

          estimated_area <- as.numeric(
            hv@Volume
          )

          signed_error <- estimated_area -
            true_area

          relative_error_percent <- 100 *
            signed_error /
            true_area

          estimated_centroid <- colMeans(
            hv@RandomPoints
          )

          centroid_displacement <- sqrt(
            sum(
              (
                estimated_centroid -
                  true_centroid
              )^2
            )
          )

          set.seed(
            set_operation_seed
          )

          set_time <- system.time({

            hv_set <- hypervolume::hypervolume_set(
              hv1 = hv,
              hv2 = true_hv,
              num.points.max = jaccard_num_points_max,
              verbose = FALSE,
              check.memory = FALSE,
              distance.factor = jaccard_distance_factor
            )
          })

          overlap_statistics <- (
            hypervolume::hypervolume_overlap_statistics(
              hv_set
            )
          )

          intersection_area <- as.numeric(
            hv_set@HVList$Intersection@Volume
          )

          union_area <- as.numeric(
            hv_set@HVList$Union@Volume
          )

          jaccard_similarity <- as.numeric(
            overlap_statistics[[
              "jaccard"
            ]]
          )

          sorensen_similarity <- if (
            is.finite(
              jaccard_similarity
            )
          ) {
            2 *
              jaccard_similarity /
              (
                1 +
                  jaccard_similarity
              )
          } else {
            NA_real_
          }

          true_region_coverage <- (
            intersection_area /
              true_area
          )

          excess_estimated_area <- (
            estimated_area -
              intersection_area
          )

          excess_estimated_fraction <- if (
            estimated_area >
              0
          ) {
            excess_estimated_area /
              estimated_area
          } else {
            NA_real_
          }

          data.frame(
            Shape_code = shape_code,
            Shape = shape_label,
            Repetition = repetition,
            Method = method_name,
            Success = TRUE,
            True_area = true_area,
            Estimated_area = estimated_area,
            Signed_area_error = signed_error,
            Absolute_area_error = abs(
              signed_error
            ),
            Relative_area_error_percent = relative_error_percent,
            Absolute_relative_area_error_percent = abs(
              relative_error_percent
            ),
            Intersection_area = intersection_area,
            Union_area = union_area,
            Jaccard_similarity = jaccard_similarity,
            Sorensen_similarity = sorensen_similarity,
            True_region_coverage = true_region_coverage,
            Excess_estimated_area = excess_estimated_area,
            Excess_estimated_fraction = excess_estimated_fraction,
            Centroid_displacement = centroid_displacement,
            Runtime_seconds = fit$runtime_seconds,
            Set_operation_runtime_seconds = unname(
              set_time[[
                "elapsed"
              ]]
            ),
            Jaccard_seed = set_operation_seed,
            Error_message = NA_character_,
            stringsAsFactors = FALSE
          )

        },
        error = function(error_condition) {

          data.frame(
            Shape_code = shape_code,
            Shape = shape_label,
            Repetition = repetition,
            Method = method_name,
            Success = FALSE,
            True_area = true_area,
            Estimated_area = NA_real_,
            Signed_area_error = NA_real_,
            Absolute_area_error = NA_real_,
            Relative_area_error_percent = NA_real_,
            Absolute_relative_area_error_percent = NA_real_,
            Intersection_area = NA_real_,
            Union_area = NA_real_,
            Jaccard_similarity = NA_real_,
            Sorensen_similarity = NA_real_,
            True_region_coverage = NA_real_,
            Excess_estimated_area = NA_real_,
            Excess_estimated_fraction = NA_real_,
            Centroid_displacement = NA_real_,
            Runtime_seconds = fit$runtime_seconds,
            Set_operation_runtime_seconds = NA_real_,
            Jaccard_seed = set_operation_seed,
            Error_message = conditionMessage(
              error_condition
            ),
            stringsAsFactors = FALSE
          )
        }
      )

      geometry_registry[[geometry_key]] <- list(
        success = isTRUE(
          result$Success[[
            1L
          ]]
        ),
        summary = result
      )

      save_geometry_registry()
    }
  }
}


# ============================================================
# Geometry replicate table
# ============================================================

geometry_replicate_rows <- lapply(
  geometry_registry,
  function(x) {
    x$summary
  }
)

geometry_replicates <- do.call(
  rbind,
  geometry_replicate_rows
)

rownames(
  geometry_replicates
) <- NULL

geometry_replicates <- geometry_replicates[
  order(
    match(
      geometry_replicates$Shape_code,
      shape_order
    ),
    geometry_replicates$Repetition,
    match(
      geometry_replicates$Method,
      method_order
    )
  ),
  ,
  drop = FALSE
]

write_csv_safely(
  geometry_replicates,
  geometry_replicate_file
)


# ============================================================
# Geometry mean +/- SD summaries
# ============================================================

geometry_summary_rows <- list()
geometry_summary_index <- 0L

for (shape_code in shape_order) {

  for (method_name in method_order) {

    group <- geometry_replicates[
      geometry_replicates$Shape_code == shape_code &
        geometry_replicates$Method == method_name &
        geometry_replicates$Success,
      ,
      drop = FALSE
    ]

    geometry_summary_index <- geometry_summary_index +
      1L

    geometry_summary_rows[[geometry_summary_index]] <- data.frame(
      Shape_code = shape_code,
      Shape = unname(
        shape_labels[[shape_code]]
      ),
      Method = method_name,
      Independent_draws_requested = number_of_independent_draws,
      Independent_draws_successful = nrow(
        group
      ),
      True_area = as.numeric(
        shape_true_area[[shape_code]]
      ),
      Mean_estimated_area = safe_mean(
        group$Estimated_area
      ),
      SD_estimated_area = safe_sd(
        group$Estimated_area
      ),
      Mean_relative_area_error_percent = safe_mean(
        group$Relative_area_error_percent
      ),
      SD_relative_area_error_percent = safe_sd(
        group$Relative_area_error_percent
      ),
      Mean_absolute_relative_area_error_percent = safe_mean(
        group$Absolute_relative_area_error_percent
      ),
      SD_absolute_relative_area_error_percent = safe_sd(
        group$Absolute_relative_area_error_percent
      ),
      Mean_Jaccard_similarity = safe_mean(
        group$Jaccard_similarity
      ),
      SD_Jaccard_similarity = safe_sd(
        group$Jaccard_similarity
      ),
      Mean_Sorensen_similarity = safe_mean(
        group$Sorensen_similarity
      ),
      SD_Sorensen_similarity = safe_sd(
        group$Sorensen_similarity
      ),
      Mean_true_region_coverage = safe_mean(
        group$True_region_coverage
      ),
      SD_true_region_coverage = safe_sd(
        group$True_region_coverage
      ),
      Mean_excess_estimated_fraction = safe_mean(
        group$Excess_estimated_fraction
      ),
      SD_excess_estimated_fraction = safe_sd(
        group$Excess_estimated_fraction
      ),
      Mean_centroid_displacement = safe_mean(
        group$Centroid_displacement
      ),
      SD_centroid_displacement = safe_sd(
        group$Centroid_displacement
      ),
      Mean_runtime_seconds = safe_mean(
        group$Runtime_seconds
      ),
      SD_runtime_seconds = safe_sd(
        group$Runtime_seconds
      ),
      stringsAsFactors = FALSE
    )
  }
}

geometry_summary <- do.call(
  rbind,
  geometry_summary_rows
)

rownames(
  geometry_summary
) <- NULL

write_csv_safely(
  geometry_summary,
  geometry_summary_file
)


# ============================================================
# Geometry winner frequencies retained from the original robustness design
# ============================================================

geometry_winner_rows <- list()
geometry_winner_index <- 0L

for (shape_code in shape_order) {

  for (
    repetition in seq_len(
      number_of_independent_draws
    )
  ) {

    group <- geometry_replicates[
      geometry_replicates$Shape_code == shape_code &
        geometry_replicates$Repetition == repetition &
        geometry_replicates$Success,
      ,
      drop = FALSE
    ]

    if (nrow(
      group
    ) != length(
      method_order
    )) {
      next
    }

    minimum_error <- min(
      group$Absolute_relative_area_error_percent,
      na.rm = TRUE
    )

    error_winners <- group$Method[
      abs(
        group$Absolute_relative_area_error_percent -
          minimum_error
      ) <= 1e-12
    ]

    for (method_name in error_winners) {

      geometry_winner_index <- geometry_winner_index +
        1L

      geometry_winner_rows[[geometry_winner_index]] <- data.frame(
        Shape_code = shape_code,
        Shape = unname(
          shape_labels[[shape_code]]
        ),
        Repetition = repetition,
        Metric = "Smallest absolute relative area error",
        Method = method_name,
        stringsAsFactors = FALSE
      )
    }

    maximum_jaccard <- max(
      group$Jaccard_similarity,
      na.rm = TRUE
    )

    jaccard_winners <- group$Method[
      abs(
        group$Jaccard_similarity -
          maximum_jaccard
      ) <= 1e-12
    ]

    for (method_name in jaccard_winners) {

      geometry_winner_index <- geometry_winner_index +
        1L

      geometry_winner_rows[[geometry_winner_index]] <- data.frame(
        Shape_code = shape_code,
        Shape = unname(
          shape_labels[[shape_code]]
        ),
        Repetition = repetition,
        Metric = "Highest Jaccard similarity",
        Method = method_name,
        stringsAsFactors = FALSE
      )
    }
  }
}

if (length(
  geometry_winner_rows
) > 0L) {

  geometry_winner_replicates <- do.call(
    rbind,
    geometry_winner_rows
  )

  geometry_winner_frequency_rows <- list()
  geometry_frequency_index <- 0L

  for (shape_code in shape_order) {

    relevant_metrics <- unique(
      geometry_winner_replicates$Metric[
        geometry_winner_replicates$Shape_code ==
          shape_code
      ]
    )

    complete_replicates <- sum(
      vapply(
        seq_len(
          number_of_independent_draws
        ),
        function(repetition) {

          group <- geometry_replicates[
            geometry_replicates$Shape_code == shape_code &
              geometry_replicates$Repetition == repetition &
              geometry_replicates$Success,
            ,
            drop = FALSE
          ]

          nrow(group) ==
            length(
              method_order
            )
        },
        logical(1)
      )
    )

    for (metric_name in relevant_metrics) {

      for (method_name in method_order) {

        wins <- sum(
          geometry_winner_replicates$Shape_code == shape_code &
            geometry_winner_replicates$Metric == metric_name &
            geometry_winner_replicates$Method == method_name
        )

        geometry_frequency_index <- geometry_frequency_index +
          1L

        geometry_winner_frequency_rows[[geometry_frequency_index]] <- data.frame(
          Shape_code = shape_code,
          Shape = unname(
            shape_labels[[shape_code]]
          ),
          Metric = metric_name,
          Method = method_name,
          Complete_independent_draws = complete_replicates,
          Wins = wins,
          Win_proportion = if (
            complete_replicates >
              0L
          ) {
            wins /
              complete_replicates
          } else {
            NA_real_
          },
          stringsAsFactors = FALSE
        )
      }
    }
  }

  geometry_winner_frequency <- do.call(
    rbind,
    geometry_winner_frequency_rows
  )

} else {

  geometry_winner_frequency <- data.frame(
    Shape_code = character(0),
    Shape = character(0),
    Metric = character(0),
    Method = character(0),
    Complete_independent_draws = integer(0),
    Wins = integer(0),
    Win_proportion = numeric(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  geometry_winner_frequency,
  geometry_winner_file
)


# ============================================================
# Persistent-homology helpers
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

  if (length(
    diagram
  ) == 0L) {
    return(
      empty_diagram()
    )
  }

  if (ncol(
    diagram
  ) != 3L) {
    stop(
      "A persistence diagram must contain three columns."
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

  if (nrow(
    diagram
  ) == 0L) {
    return(
      diagram
    )
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


tda_calculate_homology_formals <- names(
  formals(
    TDAstats::calculate_homology
  )
)

tda_supports_prime_field <- (
  "p" %in%
    tda_calculate_homology_formals
)


calculate_persistence_with_timeout <- function(
    points
) {

  points <- standardise_points(
    points,
    "points"
  )

  start_time <- proc.time()[[
    "elapsed"
  ]]

  tryCatch(
    {

      homology_arguments <- list(
        mat = points,
        dim = maximum_homology_dimension,
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

      if (
        tda_supports_prime_field
      ) {
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
        failure_type = if (
          is_timeout
        ) {
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
# Persistent homology for the two 2D positive controls
# ============================================================

ph_settings <- list(
  analysis_settings_hash = analysis_settings_hash,
  topology_target_dimension = topology_target_dimension,
  ph_sample_size = ph_sample_size,
  maximum_homology_dimension = maximum_homology_dimension,
  ph_threshold = ph_threshold,
  ph_prime_field = ph_prime_field,
  ph_standardize = ph_standardize,
  ph_timeout_seconds = ph_timeout_seconds,
  topology_sampling_seed_base = topology_sampling_seed_base
)

ph_settings_hash <- hash_r_object(
  ph_settings
)

if (
  resume_from_checkpoints &&
    file.exists(
      ph_registry_file
    )
) {

  ph_checkpoint <- readRDS(
    ph_registry_file
  )

  if (!identical(
    ph_checkpoint$ph_settings_hash,
    ph_settings_hash
  )) {
    stop(
      "Existing independent-draw PH checkpoint was produced with different ",
      "inputs or settings."
    )
  }

  ph_registry <- ph_checkpoint$registry

} else {

  ph_registry <- list()
}


save_ph_registry <- function() {

  saveRDS(
    list(
      ph_settings_hash = ph_settings_hash,
      registry = ph_registry,
      last_updated = as.character(
        Sys.time()
      )
    ),
    ph_registry_file,
    version = 3
  )
}


for (
  topology_shape_index in seq_along(
    topology_shape_order
  )
) {

  shape_code <- topology_shape_order[[topology_shape_index]]
  shape_label <- unname(
    shape_labels[[shape_code]]
  )

  target_dimension <- as.integer(
    topology_target_dimension[[shape_code]]
  )

  # Preserve the original robustness topology seed's full-eight-shape index:
  # annulus was shape index 3; two_balls was shape index 5.
  original_shape_index <- match(
    shape_code,
    shape_order
  )

  for (
    repetition in seq_len(
      number_of_independent_draws
    )
  ) {

    occurrence_key <- paste0(
      "rep",
      sprintf(
        "%02d",
        repetition
      )
    )

    point_clouds <- list(
      Occurrence = occurrence_draws[[shape_code]][[occurrence_key]]$points
    )

    for (method_name in method_order) {

      model_key <- make_key(
        shape_code,
        repetition,
        method_name
      )

      model_entry <- model_registry[[model_key]]

      if (
        !is.null(
          model_entry
        ) &&
          isTRUE(
            model_entry$success
          ) &&
          file.exists(
            model_entry$model_file
          )
      ) {

        fit <- readRDS(
          model_entry$model_file
        )

        point_clouds[[method_name]] <- fit$hypervolume@RandomPoints
      }
    }

    for (source_name in source_order) {

      ph_key <- make_key(
        shape_code,
        repetition,
        source_name
      )

      existing <- ph_registry[[ph_key]]

      should_run <- is.null(
        existing
      )

      if (!is.null(
        existing
      )) {

        if (isTRUE(
          existing$success
        )) {
          should_run <- FALSE

        } else if (
          retry_failed_persistence
        ) {
          should_run <- TRUE

        } else {
          should_run <- FALSE
        }
      }

      if (!should_run) {
        next
      }

      source_points <- point_clouds[[source_name]]

      if (is.null(
        source_points
      )) {

        ph_registry[[ph_key]] <- list(
          success = FALSE,
          shape_code = shape_code,
          shape = shape_label,
          repetition = repetition,
          source = source_name,
          target_dimension = target_dimension,
          maximum_dimension = maximum_homology_dimension,
          sample_seed = NA_integer_,
          sampled_indices = integer(0),
          sampled_points = NULL,
          diagram = empty_diagram(),
          runtime_seconds = NA_real_,
          failure_type = "missing model",
          error_message = "Required fitted hypervolume was unavailable."
        )

        save_ph_registry()

        next
      }

      full_points <- standardise_points(
        source_points,
        paste0(
          shape_code,
          " ",
          repetition,
          " ",
          source_name
        )
      )

      if (nrow(
        full_points
      ) < ph_sample_size) {

        ph_registry[[ph_key]] <- list(
          success = FALSE,
          shape_code = shape_code,
          shape = shape_label,
          repetition = repetition,
          source = source_name,
          target_dimension = target_dimension,
          maximum_dimension = maximum_homology_dimension,
          sample_seed = NA_integer_,
          sampled_indices = integer(0),
          sampled_points = NULL,
          diagram = empty_diagram(),
          runtime_seconds = NA_real_,
          failure_type = "insufficient points",
          error_message = paste0(
            "Only ",
            nrow(
              full_points
            ),
            " points available; ",
            ph_sample_size,
            " required."
          )
        )

        save_ph_registry()

        next
      }

      source_seed_index <- unname(
        legacy_source_seed_index[[source_name]]
      )

      sample_seed <- as.integer(
        topology_sampling_seed_base +
          original_shape_index * 10000L +
          repetition * 100L +
          source_seed_index
      )

      set.seed(
        sample_seed
      )

      selected_indices <- sample.int(
        n = nrow(
          full_points
        ),
        size = ph_sample_size,
        replace = FALSE
      )

      sampled_points <- full_points[
        selected_indices,
        ,
        drop = FALSE
      ]

      message(
        "Persistent homology: ",
        shape_label,
        ", independent draw ",
        repetition,
        ", ",
        source_name,
        ", target H",
        target_dimension
      )

      ph_result <- calculate_persistence_with_timeout(
        sampled_points
      )

      ph_registry[[ph_key]] <- list(
        success = ph_result$success,
        shape_code = shape_code,
        shape = shape_label,
        repetition = repetition,
        source = source_name,
        target_dimension = target_dimension,
        maximum_dimension = maximum_homology_dimension,
        sample_seed = sample_seed,
        sampled_indices = selected_indices,
        sampled_points = sampled_points,
        point_cloud_diameter = point_cloud_diameter(
          sampled_points
        ),
        diagram = ph_result$diagram,
        runtime_seconds = ph_result$runtime_seconds,
        failure_type = ph_result$failure_type,
        error_message = ph_result$error_message
      )

      save_ph_registry()
    }
  }
}


# ============================================================
# Save exact topology subsample indices separately
# ============================================================

topology_subsample_rows <- list()
topology_subsample_index <- 0L

for (ph_key in names(
  ph_registry
)) {

  ph_result <- ph_registry[[ph_key]]

  topology_subsample_index <- topology_subsample_index +
    1L

  topology_subsample_rows[[topology_subsample_index]] <- list(
    key = ph_key,
    shape_code = ph_result$shape_code,
    repetition = ph_result$repetition,
    source = ph_result$source,
    sample_seed = ph_result$sample_seed,
    selected_row_indices = ph_result$sampled_indices
  )
}

saveRDS(
  list(
    ph_settings_hash = ph_settings_hash,
    indices = topology_subsample_rows,
    created_at = as.character(
      Sys.time()
    )
  ),
  topology_subsample_file,
  version = 3
)


# ============================================================
# Bottleneck distances for independent draws
# ============================================================

topology_rows <- list()
topology_index <- 0L

for (shape_code in topology_shape_order) {

  shape_label <- unname(
    shape_labels[[shape_code]]
  )

  target_dimension <- as.integer(
    topology_target_dimension[[shape_code]]
  )

  for (
    repetition in seq_len(
      number_of_independent_draws
    )
  ) {

    occurrence_ph_key <- make_key(
      shape_code,
      repetition,
      "Occurrence"
    )

    occurrence_result <- ph_registry[[occurrence_ph_key]]

    for (method_name in method_order) {

      method_ph_key <- make_key(
        shape_code,
        repetition,
        method_name
      )

      method_result <- ph_registry[[method_ph_key]]

      topology_index <- topology_index +
        1L

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

        topology_rows[[topology_index]] <- data.frame(
          Shape_code = shape_code,
          Shape = shape_label,
          Repetition = repetition,
          Method = method_name,
          Homology_dimension = target_dimension,
          Success = FALSE,
          Occurrence_cloud_diameter = if (
            !is.null(
              occurrence_result
            )
          ) {
            occurrence_result$point_cloud_diameter
          } else {
            NA_real_
          },
          Bottleneck_distance = NA_real_,
          Normalized_bottleneck_distance = NA_real_,
          Occurrence_maximum_persistence = if (
            !is.null(
              occurrence_result
            ) &&
              isTRUE(
                occurrence_result$success
              )
          ) {
            max_finite_persistence(
              occurrence_result$diagram,
              target_dimension
            )
          } else {
            NA_real_
          },
          Method_maximum_persistence = NA_real_,
          Occurrence_PH_runtime_seconds = if (
            !is.null(
              occurrence_result
            )
          ) {
            occurrence_result$runtime_seconds
          } else {
            NA_real_
          },
          Method_PH_runtime_seconds = if (
            !is.null(
              method_result
            )
          ) {
            method_result$runtime_seconds
          } else {
            NA_real_
          },
          Error_message = paste(
            "Occurrence PH:",
            if (
              is.null(
                occurrence_result
              )
            ) {
              "missing"
            } else {
              occurrence_result$error_message
            },
            "| Method PH:",
            if (
              is.null(
                method_result
              )
            ) {
              "missing"
            } else {
              method_result$error_message
            }
          ),
          stringsAsFactors = FALSE
        )

        next
      }

      occurrence_diameter <- point_cloud_diameter(
        occurrence_result$sampled_points
      )

      bottleneck <- calculate_bottleneck_safe(
        occurrence_diagram = occurrence_result$diagram,
        method_diagram = method_result$diagram,
        dimension = target_dimension
      )

      normalized_distance <- if (
        isTRUE(
          bottleneck$success
        ) &&
          is.finite(
            occurrence_diameter
          ) &&
          occurrence_diameter >
            0
      ) {
        bottleneck$distance /
          occurrence_diameter
      } else {
        NA_real_
      }

      topology_rows[[topology_index]] <- data.frame(
        Shape_code = shape_code,
        Shape = shape_label,
        Repetition = repetition,
        Method = method_name,
        Homology_dimension = target_dimension,
        Success = (
          isTRUE(
            bottleneck$success
          ) &&
            is.finite(
              normalized_distance
            )
        ),
        Occurrence_cloud_diameter = occurrence_diameter,
        Bottleneck_distance = bottleneck$distance,
        Normalized_bottleneck_distance = normalized_distance,
        Occurrence_maximum_persistence = max_finite_persistence(
          occurrence_result$diagram,
          target_dimension
        ),
        Method_maximum_persistence = max_finite_persistence(
          method_result$diagram,
          target_dimension
        ),
        Occurrence_PH_runtime_seconds = occurrence_result$runtime_seconds,
        Method_PH_runtime_seconds = method_result$runtime_seconds,
        Error_message = bottleneck$error_message,
        stringsAsFactors = FALSE
      )
    }
  }
}

topology_replicates <- do.call(
  rbind,
  topology_rows
)

rownames(
  topology_replicates
) <- NULL

topology_replicates <- topology_replicates[
  order(
    match(
      topology_replicates$Shape_code,
      topology_shape_order
    ),
    topology_replicates$Repetition,
    match(
      topology_replicates$Method,
      method_order
    )
  ),
  ,
  drop = FALSE
]

write_csv_safely(
  topology_replicates,
  topology_replicate_file
)


# ============================================================
# Topology mean +/- SD summaries
# ============================================================

topology_summary_rows <- list()
topology_summary_index <- 0L

for (shape_code in topology_shape_order) {

  for (method_name in method_order) {

    group <- topology_replicates[
      topology_replicates$Shape_code == shape_code &
        topology_replicates$Method == method_name &
        topology_replicates$Success,
      ,
      drop = FALSE
    ]

    topology_summary_index <- topology_summary_index +
      1L

    topology_summary_rows[[topology_summary_index]] <- data.frame(
      Shape_code = shape_code,
      Shape = unname(
        shape_labels[[shape_code]]
      ),
      Homology_dimension = as.integer(
        topology_target_dimension[[shape_code]]
      ),
      Method = method_name,
      Independent_draws_requested = number_of_independent_draws,
      Independent_draws_successful = nrow(
        group
      ),
      Mean_bottleneck_distance = safe_mean(
        group$Bottleneck_distance
      ),
      SD_bottleneck_distance = safe_sd(
        group$Bottleneck_distance
      ),
      Mean_normalized_bottleneck = safe_mean(
        group$Normalized_bottleneck_distance
      ),
      SD_normalized_bottleneck = safe_sd(
        group$Normalized_bottleneck_distance
      ),
      Mean_method_maximum_persistence = safe_mean(
        group$Method_maximum_persistence
      ),
      SD_method_maximum_persistence = safe_sd(
        group$Method_maximum_persistence
      ),
      Mean_occurrence_maximum_persistence = safe_mean(
        group$Occurrence_maximum_persistence
      ),
      SD_occurrence_maximum_persistence = safe_sd(
        group$Occurrence_maximum_persistence
      ),
      stringsAsFactors = FALSE
    )
  }
}

topology_summary <- do.call(
  rbind,
  topology_summary_rows
)

rownames(
  topology_summary
) <- NULL

write_csv_safely(
  topology_summary,
  topology_summary_file
)


# ============================================================
# Topology winner frequencies retained from the original robustness design
# ============================================================

topology_winner_rows <- list()
topology_winner_index <- 0L

for (shape_code in topology_shape_order) {

  for (
    repetition in seq_len(
      number_of_independent_draws
    )
  ) {

    group <- topology_replicates[
      topology_replicates$Shape_code == shape_code &
        topology_replicates$Repetition == repetition &
        topology_replicates$Success,
      ,
      drop = FALSE
    ]

    if (nrow(
      group
    ) != length(
      method_order
    )) {
      next
    }

    minimum_distance <- min(
      group$Normalized_bottleneck_distance,
      na.rm = TRUE
    )

    winners <- group$Method[
      abs(
        group$Normalized_bottleneck_distance -
          minimum_distance
      ) <= 1e-12
    ]

    for (method_name in winners) {

      topology_winner_index <- topology_winner_index +
        1L

      topology_winner_rows[[topology_winner_index]] <- data.frame(
        Shape_code = shape_code,
        Shape = unname(
          shape_labels[[shape_code]]
        ),
        Repetition = repetition,
        Method = method_name,
        stringsAsFactors = FALSE
      )
    }
  }
}

if (length(
  topology_winner_rows
) > 0L) {

  topology_winner_replicates <- do.call(
    rbind,
    topology_winner_rows
  )

  topology_winner_frequency_rows <- list()
  topology_frequency_index <- 0L

  for (shape_code in topology_shape_order) {

    complete_replicates <- sum(
      vapply(
        seq_len(
          number_of_independent_draws
        ),
        function(repetition) {

          group <- topology_replicates[
            topology_replicates$Shape_code == shape_code &
              topology_replicates$Repetition == repetition &
              topology_replicates$Success,
            ,
            drop = FALSE
          ]

          nrow(group) ==
            length(
              method_order
            )
        },
        logical(1)
      )
    )

    for (method_name in method_order) {

      wins <- sum(
        topology_winner_replicates$Shape_code == shape_code &
          topology_winner_replicates$Method == method_name
      )

      topology_frequency_index <- topology_frequency_index +
        1L

      topology_winner_frequency_rows[[topology_frequency_index]] <- data.frame(
        Shape_code = shape_code,
        Shape = unname(
          shape_labels[[shape_code]]
        ),
        Homology_dimension = as.integer(
          topology_target_dimension[[shape_code]]
        ),
        Method = method_name,
        Complete_independent_draws = complete_replicates,
        Wins = wins,
        Win_proportion = if (
          complete_replicates >
            0L
        ) {
          wins /
            complete_replicates
        } else {
          NA_real_
        },
        stringsAsFactors = FALSE
      )
    }
  }

  topology_winner_frequency <- do.call(
    rbind,
    topology_winner_frequency_rows
  )

} else {

  topology_winner_frequency <- data.frame(
    Shape_code = character(0),
    Shape = character(0),
    Homology_dimension = integer(0),
    Method = character(0),
    Complete_independent_draws = integer(0),
    Wins = integer(0),
    Win_proportion = numeric(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  topology_winner_frequency,
  topology_winner_file
)


# ============================================================
# Compact robustness summary
# ============================================================

compact_geometry <- geometry_summary[
  ,
  c(
    "Shape_code",
    "Shape",
    "Method",
    "Independent_draws_successful",
    "Mean_relative_area_error_percent",
    "SD_relative_area_error_percent",
    "Mean_absolute_relative_area_error_percent",
    "SD_absolute_relative_area_error_percent",
    "Mean_Jaccard_similarity",
    "SD_Jaccard_similarity",
    "Mean_Sorensen_similarity",
    "SD_Sorensen_similarity",
    "Mean_true_region_coverage",
    "SD_true_region_coverage",
    "Mean_excess_estimated_fraction",
    "SD_excess_estimated_fraction",
    "Mean_centroid_displacement",
    "SD_centroid_displacement"
  ),
  drop = FALSE
]

names(
  compact_geometry
)[names(
  compact_geometry
) == "Independent_draws_successful"] <- "Geometry_draws_successful"

compact_topology <- topology_summary[
  ,
  c(
    "Shape_code",
    "Method",
    "Homology_dimension",
    "Independent_draws_successful",
    "Mean_normalized_bottleneck",
    "SD_normalized_bottleneck",
    "Mean_method_maximum_persistence",
    "SD_method_maximum_persistence"
  ),
  drop = FALSE
]

names(
  compact_topology
)[names(
  compact_topology
) == "Independent_draws_successful"] <- "Topology_draws_successful"

compact_summary <- merge(
  compact_geometry,
  compact_topology,
  by = c(
    "Shape_code",
    "Method"
  ),
  all.x = TRUE,
  sort = FALSE
)

compact_summary$Shape_order <- match(
  compact_summary$Shape_code,
  shape_order
)

compact_summary$Method_order <- match(
  compact_summary$Method,
  method_order
)

compact_summary <- compact_summary[
  order(
    compact_summary$Shape_order,
    compact_summary$Method_order
  ),
  ,
  drop = FALSE
]

compact_summary$Shape_order <- NULL
compact_summary$Method_order <- NULL

write_csv_safely(
  compact_summary,
  compact_summary_file
)


# ============================================================
# Diagnostic robustness figures using the locked colour scheme
# ============================================================

geometry_plot_data <- geometry_replicates[
  geometry_replicates$Success,
  ,
  drop = FALSE
]

geometry_plot_data$Shape <- factor(
  geometry_plot_data$Shape,
  levels = unname(
    shape_labels[
      shape_order
    ]
  )
)

geometry_plot_data$Method <- factor(
  geometry_plot_data$Method,
  levels = method_order
)

geometry_plot <- ggplot(
  geometry_plot_data,
  aes(
    x = Method,
    y = Absolute_relative_area_error_percent,
    colour = Method,
    fill = Method
  )
) +
  geom_boxplot(
    outlier.shape = NA,
    width = 0.60,
    alpha = 0.16,
    linewidth = 0.45
  ) +
  geom_point(
    position = position_jitter(
      width = 0.12,
      height = 0,
      seed = 123
    ),
    size = 1.25,
    alpha = 0.72
  ) +
  facet_wrap(
    ~Shape,
    scales = "free_y",
    ncol = 3
  ) +
  scale_colour_manual(
    values = method_colours,
    drop = FALSE
  ) +
  scale_fill_manual(
    values = method_colours,
    drop = FALSE
  ) +
  labs(
    x = NULL,
    y = "Absolute relative area error (%)",
    title = "Independent occurrence-draw robustness at n = 900"
  ) +
  theme_bw(
    base_size = 9
  ) +
  theme(
    axis.text.x = element_text(
      angle = 35,
      hjust = 1
    ),
    panel.grid.minor = element_blank(),
    strip.text = element_text(
      face = "bold"
    ),
    legend.position = "none"
  )

ggsave(
  filename = geometry_figure_file,
  plot = geometry_plot,
  width = 8.0,
  height = 5.8,
  units = "in",
  device = grDevices::cairo_pdf
)

topology_plot_data <- topology_replicates[
  topology_replicates$Success,
  ,
  drop = FALSE
]

topology_plot_data$Shape <- factor(
  topology_plot_data$Shape,
  levels = unname(
    shape_labels[
      topology_shape_order
    ]
  )
)

topology_plot_data$Method <- factor(
  topology_plot_data$Method,
  levels = method_order
)

topology_plot <- ggplot(
  topology_plot_data,
  aes(
    x = Method,
    y = Normalized_bottleneck_distance,
    colour = Method,
    fill = Method
  )
) +
  geom_boxplot(
    outlier.shape = NA,
    width = 0.60,
    alpha = 0.16,
    linewidth = 0.45
  ) +
  geom_point(
    position = position_jitter(
      width = 0.12,
      height = 0,
      seed = 456
    ),
    size = 1.25,
    alpha = 0.72
  ) +
  facet_wrap(
    ~Shape,
    scales = "free_y",
    nrow = 1
  ) +
  scale_colour_manual(
    values = method_colours,
    drop = FALSE
  ) +
  scale_fill_manual(
    values = method_colours,
    drop = FALSE
  ) +
  labs(
    x = NULL,
    y = "Normalised bottleneck distance",
    title = "Topology across independent occurrence draws"
  ) +
  theme_bw(
    base_size = 9
  ) +
  theme(
    axis.text.x = element_text(
      angle = 35,
      hjust = 1
    ),
    panel.grid.minor = element_blank(),
    strip.text = element_text(
      face = "bold"
    ),
    legend.position = "none"
  )

ggsave(
  filename = topology_figure_file,
  plot = topology_plot,
  width = 7.2,
  height = 3.4,
  units = "in",
  device = grDevices::cairo_pdf
)


# ============================================================
# Failure summary
# ============================================================

failure_rows <- list()
failure_index <- 0L

failed_models <- model_summary[
  !model_summary$Success,
  ,
  drop = FALSE
]

if (nrow(
  failed_models
) > 0L) {

  for (
    row_number in seq_len(
      nrow(
        failed_models
      )
    )
  ) {

    failure_index <- failure_index +
      1L

    failure_rows[[failure_index]] <- data.frame(
      Stage = "Hypervolume fit",
      Shape_code = failed_models$Shape_code[
        row_number
      ],
      Repetition = failed_models$Repetition[
        row_number
      ],
      Method_or_source = failed_models$Method[
        row_number
      ],
      Error_message = failed_models$Error_message[
        row_number
      ],
      stringsAsFactors = FALSE
    )
  }
}

failed_geometry <- geometry_replicates[
  !geometry_replicates$Success,
  ,
  drop = FALSE
]

if (nrow(
  failed_geometry
) > 0L) {

  for (
    row_number in seq_len(
      nrow(
        failed_geometry
      )
    )
  ) {

    failure_index <- failure_index +
      1L

    failure_rows[[failure_index]] <- data.frame(
      Stage = "Geometry",
      Shape_code = failed_geometry$Shape_code[
        row_number
      ],
      Repetition = failed_geometry$Repetition[
        row_number
      ],
      Method_or_source = failed_geometry$Method[
        row_number
      ],
      Error_message = failed_geometry$Error_message[
        row_number
      ],
      stringsAsFactors = FALSE
    )
  }
}

for (ph_key in names(
  ph_registry
)) {

  ph_result <- ph_registry[[ph_key]]

  if (!isTRUE(
    ph_result$success
  )) {

    failure_index <- failure_index +
      1L

    failure_rows[[failure_index]] <- data.frame(
      Stage = "Persistent homology",
      Shape_code = ph_result$shape_code,
      Repetition = ph_result$repetition,
      Method_or_source = ph_result$source,
      Error_message = ph_result$error_message,
      stringsAsFactors = FALSE
    )
  }
}

failed_bottleneck <- topology_replicates[
  !topology_replicates$Success,
  ,
  drop = FALSE
]

if (nrow(
  failed_bottleneck
) > 0L) {

  for (
    row_number in seq_len(
      nrow(
        failed_bottleneck
      )
    )
  ) {

    failure_index <- failure_index +
      1L

    failure_rows[[failure_index]] <- data.frame(
      Stage = "Bottleneck",
      Shape_code = failed_bottleneck$Shape_code[
        row_number
      ],
      Repetition = failed_bottleneck$Repetition[
        row_number
      ],
      Method_or_source = failed_bottleneck$Method[
        row_number
      ],
      Error_message = failed_bottleneck$Error_message[
        row_number
      ],
      stringsAsFactors = FALSE
    )
  }
}

if (length(
  failure_rows
) > 0L) {

  failure_summary <- do.call(
    rbind,
    failure_rows
  )

} else {

  failure_summary <- data.frame(
    Stage = character(0),
    Shape_code = character(0),
    Repetition = integer(0),
    Method_or_source = character(0),
    Error_message = character(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  failure_summary,
  failure_file
)


# ============================================================
# Notes and session information
# ============================================================

writeLines(
  c(
    "Revised 2D independent occurrence-draw robustness analysis",
    "=========================================================",
    "",
    paste0(
      "Completed: ",
      Sys.time()
    ),
    paste0(
      "Independent draws per niche: ",
      number_of_independent_draws
    ),
    paste0(
      "Occurrence sample size: ",
      sample_size
    ),
    paste0(
      "Expected hypervolume fits: ",
      length(shape_order) *
        number_of_independent_draws *
        length(method_order)
    ),
    paste0(
      "Successful hypervolume fits: ",
      sum(
        model_summary$Success
      )
    ),
    paste0(
      "Successful geometry comparisons: ",
      sum(
        geometry_replicates$Success
      )
    ),
    "",
    "Occurrence draws:",
    paste0(
      "  Revised locked archive: ",
      occurrence_archive_file
    ),
    paste0(
      "  Revised archive MD5: ",
      occurrence_archive_md5
    ),
    paste0(
      "  Legacy archive available: ",
      file.exists(
        legacy_occurrence_archive_file
      )
    ),
    "",
    "Revised QPH baseline:",
    "  Nasios-Bors-derived square-root local-distance bandwidth",
    "  K = round(sqrt(n))",
    "  h = sqrt(mean(s_i)); isotropic bandwidth",
    paste0(
      "  q = ",
      qph_q
    ),
    paste0(
      "  samples.per.point = ",
      qph_samples_per_point
    ),
    paste0(
      "  sd.count = ",
      qph_sd_count
    ),
    "",
    "Gaussian KDE baseline:",
    "  Silverman bandwidth estimated independently for every occurrence draw",
    paste0(
      "  probability quantile = ",
      kde_quantile
    ),
    paste0(
      "  samples.per.point = ",
      kde_samples_per_point
    ),
    paste0(
      "  sd.count = ",
      kde_sd_count
    ),
    "",
    "SVM baseline:",
    paste0(
      "  nu = ",
      svm_nu
    ),
    paste0(
      "  gamma = ",
      svm_gamma
    ),
    paste0(
      "  scale.factor = ",
      svm_scale_factor
    ),
    paste0(
      "  samples.per.point = ",
      svm_samples_per_point
    ),
    "",
    "Geometry:",
    "  Fixed revised 100,000-point true-region references reused from Script 02",
    paste0(
      "  hypervolume_set num.points.max = ",
      jaccard_num_points_max
    ),
    paste0(
      "  hypervolume_set distance.factor = ",
      jaccard_distance_factor
    ),
    "",
    "Topology positive controls:",
    "  Annulus: H1",
    "  Two separated disks: finite H0",
    paste0(
      "  PH sample size = ",
      ph_sample_size
    ),
    paste0(
      "  PH timeout = ",
      ph_timeout_seconds,
      " seconds"
    ),
    "  No matched filled-ellipse null analysis was repeated.",
    "",
    "Locked colours:",
    "  Gaussian KDE = #D7301F",
    "  SVM = #238B45",
    "  QPH = #2C7FB8",
    "  true region = #D9D9D9",
    "  occurrences = #111111",
    "",
    "Interpretation:",
    "  This analysis measures robustness to independent occurrence sampling.",
    "  It is not parameter tuning and does not replace the fixed-seed main benchmark."
  ),
  notes_file
)

capture.output(
  sessionInfo(),
  file = session_information_file
)


# ============================================================
# Final console summary
# ============================================================

message(
  "\n============================================================"
)

message(
  "05_2D_Independent_Occurrence_Robustness.R complete."
)

message(
  "============================================================"
)

message(
  "Output directory:\n  ",
  normalizePath(
    output_directory,
    mustWork = FALSE
  )
)

message(
  "Occurrence archive:\n  ",
  normalizePath(
    occurrence_archive_file,
    mustWork = FALSE
  )
)

message(
  "QPH audit summary:\n  ",
  normalizePath(
    qph_audit_summary_file,
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
  "Geometry summary:\n  ",
  normalizePath(
    geometry_summary_file,
    mustWork = FALSE
  )
)

message(
  "Geometry winner frequencies:\n  ",
  normalizePath(
    geometry_winner_file,
    mustWork = FALSE
  )
)

message(
  "Topology summary:\n  ",
  normalizePath(
    topology_summary_file,
    mustWork = FALSE
  )
)

message(
  "Topology winner frequencies:\n  ",
  normalizePath(
    topology_winner_file,
    mustWork = FALSE
  )
)

message(
  "Compact robustness summary:\n  ",
  normalizePath(
    compact_summary_file,
    mustWork = FALSE
  )
)

message(
  "Failures:\n  ",
  normalizePath(
    failure_file,
    mustWork = FALSE
  )
)

message(
  "============================================================"
)
