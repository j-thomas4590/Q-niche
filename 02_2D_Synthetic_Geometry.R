# ============================================================
# 02_2D_Synthetic_Geometry.R
# ============================================================
#
# Clean final geometrical analysis for the five two-dimensional
# synthetic benchmark niches used in the revised QPH manuscript.
#
# This script follows directly from:
#   00_QPH_Core_Functions.R
#   01_2D_Synthetic_Baseline_Fits.R
#


rm(list = ls())
gc()

# ============================================================
# Required packages
# ============================================================

required_packages <- c(
  "hypervolume",
  "ggplot2",
  "patchwork"
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
    "Install the following required package(s) before running Script 02: ",
    paste(missing_packages, collapse = ", ")
  )
}

library(hypervolume)
library(ggplot2)
library(patchwork)

# ============================================================
# Project paths
# ============================================================

# Run from the repository's root folder.
project_directory <- "."

analysis_root_directory <- file.path(
  project_directory,
  "Results",
  "2D_Synthetic_sqrtNB_q099"
)

locked_input_directory <- file.path(
  analysis_root_directory,
  "00_Locked_Inputs"
)

baseline_output_directory <- file.path(
  analysis_root_directory,
  "01_Baseline_Fits"
)

geometry_output_directory <- file.path(
  analysis_root_directory,
  "02_Geometry"
)

dir.create(
  geometry_output_directory,
  showWarnings = FALSE,
  recursive = TRUE
)

# ============================================================
# Locked analysis settings
# ============================================================

expected_shape_names <- c(
  "spiral",
  "ellipse",
  "annulus",
  "banana",
  "two_balls"
)

expected_sample_sizes <- c(
  300L,
  900L,
  1500L
)

method_order <- c(
  "Gaussian KDE",
  "SVM",
  "QPH"
)

representative_sample_size <- 900L
expected_samples_per_point <- 100L

# Revised QPH values that Script 01 must contain.
expected_qph_q <- 0.99
expected_qph_bandwidth_method <- (
  "Nasios-Bors-derived square-root local-distance bandwidth"
)

# Comparator settings retained from the original benchmark.
expected_kde_probability_quantile <- 0.95
expected_svm_nu <- 0.01
expected_svm_gamma <- 0.50
expected_svm_scale_factor <- 1

# Number of uniformly sampled points used to represent each analytically
# known continuous niche. Retained from the previous analysis.
true_reference_points_per_shape <- 100000L
true_reference_seed_base <- 30123L

# Maximum number of points from each input hypervolume used by
# hypervolume_set(). The package places both inputs at a common point
# density before calculating intersection and union.
jaccard_num_points_max <- 10000L

# Set-operation distance factor. Retained unchanged.
jaccard_distance_factor <- 1

# Set TRUE to continue a compatible geometry checkpoint.
resume_from_checkpoint <- TRUE

# Figure settings. These affect display only, not any reported metric.
figure_grid_resolution <- 180L
figure_hypervolume_points_max <- 15000L
figure_point_size <- 0.22
figure_point_alpha <- 0.75
figure_raster_alpha <- 0.72

# Publication file dimensions.
figure_width_inches <- 7.5
figure_height_inches <- 11.2
figure_tiff_dpi <- 600L

# Fixed colours retained from the previous Figure 2.
method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"

)

method_shapes <- c(
  "Gaussian KDE" = 16,
  "SVM" = 15,
  "QPH" = 17
)

true_region_colour <- "#D9D9D9"
occurrence_colour <- "#111111"

# ============================================================
# Input and output files
# ============================================================

occurrence_archive_file <- file.path(
  locked_input_directory,
  "synthetic_occurrence_clouds_authoritative.rds"
)

baseline_results_file <- file.path(
  baseline_output_directory,
  "baseline_fit_results_sqrtNB_q099.rds"
)

baseline_summary_file <- file.path(
  baseline_output_directory,
  "baseline_fit_summary_sqrtNB_q099.csv"
)

# Compatibility aliases used only by inherited plotting/checkpoint helpers.
# Both point to the same unified Script 01 result file.
qph_gaussian_results_file <- baseline_results_file
svm_results_file <- baseline_results_file

# QPH-independent true-region reference archive.
true_reference_file <- file.path(
  locked_input_directory,
  "true_region_reference_clouds_2D.rds"
)


true_reference_manifest_file <- file.path(
  geometry_output_directory,
  "true_region_reference_manifest.csv"
)

geometry_checkpoint_file <- file.path(
  geometry_output_directory,
  "synthetic_geometry_checkpoint_sqrtNB_q099.rds"
)

geometry_results_file <- file.path(
  geometry_output_directory,
  "synthetic_geometry_results_sqrtNB_q099.rds"
)

geometry_summary_file <- file.path(
  geometry_output_directory,
  "synthetic_geometry_summary_sqrtNB_q099.csv"
)

figure_raster_file <- file.path(
  geometry_output_directory,
  "Figure_2_panel_a_raster_data_sqrtNB_q099.rds"
)

figure_2_pdf <- file.path(
  geometry_output_directory,
  "Figure_2_synthetic_geometrical_recovery_sqrtNB_q099.pdf"
)

figure_2_tiff <- file.path(
  geometry_output_directory,
  "Figure_2_synthetic_geometrical_recovery_sqrtNB_q099.tiff"
)

figure_2_png <- file.path(
  geometry_output_directory,
  "Figure_2_synthetic_geometrical_recovery_sqrtNB_q099.png"
)

panel_a_pdf <- file.path(
  geometry_output_directory,
  "Figure_2a_representative_regions_n900_sqrtNB_q099.pdf"
)

panel_b_pdf <- file.path(
  geometry_output_directory,
  "Figure_2b_relative_area_error_sqrtNB_q099.pdf"
)

panel_c_pdf <- file.path(
  geometry_output_directory,
  "Figure_2c_jaccard_similarity_sqrtNB_q099.pdf"
)

centroid_pdf <- file.path(
  geometry_output_directory,
  "Supplementary_centroid_displacement_sqrtNB_q099.pdf"
)

analysis_notes_file <- file.path(
  geometry_output_directory,
  "GEOMETRICAL_ANALYSIS_NOTES_sqrtNB_q099.txt"
)

session_information_file <- file.path(
  geometry_output_directory,
  "geometry_session_information_sqrtNB_q099.txt"
)

# ============================================================
# Initial file checks
# ============================================================

required_input_files <- c(
  occurrence_archive_file,
  baseline_results_file,
  baseline_summary_file
)

missing_input_files <- required_input_files[
  !file.exists(required_input_files)
]

if (length(missing_input_files) > 0L) {
  stop(
    "One or more required inputs are missing:\n  ",
    paste(missing_input_files, collapse = "\n  "),
    "\nRun 01_2D_Synthetic_Baseline_Fits.R successfully before Script 02."
  )
}

# ============================================================
# General validation helpers
# ============================================================

validate_numeric_matrix <- function(x, object_name = "x") {
  x <- as.matrix(x)
  storage.mode(x) <- "double"

  if (nrow(x) < 1L) {
    stop(object_name, " must contain at least one row.")
  }

  if (ncol(x) != 2L) {
    stop(object_name, " must contain exactly two columns.")
  }

  if (any(!is.finite(x))) {
    stop(object_name, " contains missing or non-finite values.")
  }

  if (is.null(colnames(x))) {
    colnames(x) <- c(
      "Environmental axis 1",
      "Environmental axis 2"
    )
  }

  x
}

# Standardise coordinate names stored inside a Hypervolume object.
# hypervolume_set() combines internal point tables by name, so Data and
# RandomPoints must use identical names in both objects. This changes labels
# only; it does not change any coordinates, volumes, densities, or membership.
standardise_hypervolume_axis_names <- function(
    hv,
    axis_names = c(
      "Environmental axis 1",
      "Environmental axis 2"
    )
) {
  if (!methods::is(hv, "Hypervolume")) {
    stop("hv must be a Hypervolume object.")
  }

  if (length(axis_names) != hv@Dimensionality) {
    stop("axis_names must contain one name per dimension.")
  }

  if (ncol(hv@Data) != length(axis_names)) {
    stop("The Hypervolume Data slot has an unexpected number of columns.")
  }

  if (ncol(hv@RandomPoints) != length(axis_names)) {
    stop(
      "The Hypervolume RandomPoints slot has an unexpected number of columns."
    )
  }

  colnames(hv@Data) <- axis_names
  colnames(hv@RandomPoints) <- axis_names

  methods::validObject(hv)
  hv
}

# Convert any two-dimensional point object to a consistently named matrix.
# This prevents rbind.data.frame() errors when plotting limits are calculated.
standardise_xy_matrix <- function(x, object_name = "x") {
  x <- validate_numeric_matrix(x, object_name)
  colnames(x) <- c("x", "y")
  x
}

validate_hypervolume <- function(hv, object_name = "hv") {
  if (!methods::is(hv, "Hypervolume")) {
    stop(object_name, " is not a Hypervolume object.")
  }

  methods::validObject(hv)

  if (hv@Dimensionality != 2) {
    stop(object_name, " is not two-dimensional.")
  }

  if (!is.finite(hv@Volume) || hv@Volume <= 0) {
    stop(object_name, " has an invalid volume.")
  }

  if (nrow(hv@RandomPoints) < 1L) {
    stop(object_name, " contains no random points.")
  }

  invisible(TRUE)
}

safe_md5 <- function(path) {
  if (!file.exists(path)) {
    return(NA_character_)
  }

  unname(tools::md5sum(path))
}

safe_equal_numeric <- function(x, y, tolerance = 1e-10) {
  isTRUE(all.equal(
    as.numeric(x),
    as.numeric(y),
    tolerance = tolerance,
    check.attributes = FALSE
  ))
}

# ============================================================
# Load unified Script 01 baseline results
# ============================================================

message("Loading locked occurrence archive...")
occurrence_archive <- readRDS(
  occurrence_archive_file
)

if (!is.list(occurrence_archive)) {
  stop("The occurrence archive is not a list.")
}

required_archive_elements <- c(
  "metadata",
  "master_datasets",
  "occurrence_subsets"
)

if (!all(required_archive_elements %in% names(occurrence_archive))) {
  stop("The occurrence archive is missing required elements.")
}

if (!identical(
  names(occurrence_archive$master_datasets),
  expected_shape_names
)) {
  stop("The occurrence archive contains unexpected shape names or order.")
}

if (!identical(
  as.integer(occurrence_archive$metadata$sample_sizes),
  expected_sample_sizes
)) {
  stop("The occurrence archive contains unexpected sample sizes.")
}

message("Loading revised unified baseline fits...")
baseline_results <- readRDS(
  baseline_results_file
)

if (
  !is.list(baseline_results) ||
    !all(c(
      "metadata",
      "scenarios",
      "summary"
    ) %in% names(baseline_results))
) {
  stop(
    "The Script 01 baseline result file does not have the expected ",
    "revised structure."
  )
}

baseline_scenarios <- baseline_results$scenarios
baseline_summary <- read.csv(
  baseline_summary_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

expected_scenarios <- as.vector(
  outer(
    expected_shape_names,
    expected_sample_sizes,
    FUN = function(shape_name, sample_size) {
      paste(shape_name, sample_size, sep = "_")
    }
  )
)

if (!all(expected_scenarios %in% names(baseline_scenarios))) {
  stop(
    "Script 01 revised baseline results are missing one or more ",
    "expected scenarios."
  )
}

# ------------------------------------------------------------
# Build compatibility views of the unified Script 01 object.
#
# This lets the original geometry implementation be retained with minimal
# scientific change while all hypervolumes come from the new combined
# baseline script.
# ------------------------------------------------------------

qph_gaussian_results <- list()
svm_results <- list()

for (scenario_name in expected_scenarios) {

  scenario <- baseline_scenarios[[scenario_name]]

  shape_name <- scenario$shape_name
  sample_size <- as.integer(scenario$sample_size)
  size_key <- as.character(sample_size)

  # Use explicit intermediate objects for nested list indexing. Keeping
  # each [[...]] operator intact avoids accidental creation of the invalid
  # split-token pattern `[ [index]` when this script is edited or regenerated.
  shape_occurrence_subsets <- occurrence_archive$occurrence_subsets[[shape_name]]
  archived_subset <- shape_occurrence_subsets[[size_key]]

  if (is.null(archived_subset)) {
    stop(
      "The locked occurrence archive is missing scenario ",
      scenario_name,
      "."
    )
  }

  archived_points <- archived_subset$points

  qph_success <- isTRUE(scenario$qph$success)
  kde_success <- isTRUE(scenario$gaussian_kde$success)
  svm_success <- isTRUE(scenario$svm$success)

  qph_gaussian_results[[scenario_name]] <- list(
    success = qph_success && kde_success,
    occurrence_points = archived_points,
    hv_qph = if (qph_success) {
      scenario$qph$hypervolume
    } else {
      NULL
    },
    hv_gaussian = if (kde_success) {
      scenario$gaussian_kde$hypervolume
    } else {
      NULL
    },
    qph_audit = if (qph_success) {
      scenario$qph$audit
    } else {
      NULL
    },
    kde_bandwidth = if (kde_success) {
      scenario$gaussian_kde$bandwidth
    } else {
      NULL
    },
    kde_bandwidth_method = if (kde_success) {
      scenario$gaussian_kde$bandwidth_method
    } else {
      NA_character_
    },
    kde_probability_quantile = if (kde_success) {
      scenario$gaussian_kde$probability_quantile
    } else {
      NA_real_
    },
    summary = data.frame(
      Gaussian_runtime_seconds = if (kde_success) {
        scenario$gaussian_kde$runtime_seconds
      } else {
        NA_real_
      },
      QPH_runtime_seconds = if (qph_success) {
        scenario$qph$runtime_seconds
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  )

  svm_results[[scenario_name]] <- list(
    success = svm_success,
    occurrence_points = archived_points,
    hv_svm = if (svm_success) {
      scenario$svm$hypervolume
    } else {
      NULL
    },
    audit = if (svm_success) {
      scenario$svm$audit
    } else {
      NULL
    },
    summary = data.frame(
      SVM_hypervolume_runtime_seconds = if (svm_success) {
        scenario$svm$hypervolume_runtime_seconds
      } else {
        NA_real_
      },
      Sampling_effort_mode = "same_argument",
      stringsAsFactors = FALSE
    )
  )
}

# ============================================================
# Validate that every method used the exact archived occurrence cloud
# ============================================================

message("Validating occurrence-cloud identity across all saved results...")

for (shape_name in expected_shape_names) {
  for (sample_size in expected_sample_sizes) {
    scenario_name <- paste(shape_name, sample_size, sep = "_")
    size_key <- as.character(sample_size)

    archived_points <- validate_numeric_matrix(
      occurrence_archive$occurrence_subsets[[shape_name]][[size_key]]$points,
      paste0("archived occurrence points for ", scenario_name)
    )

    qg_result <- qph_gaussian_results[[scenario_name]]
    svm_result <- svm_results[[scenario_name]]

    if (!isTRUE(qg_result$success)) {
      stop(
        "Script 01 scenario failed and cannot be analysed: ",
        scenario_name
      )
    }

    if (!isTRUE(svm_result$success)) {
      stop(
        "Unified Script 01 SVM fit failed and cannot be analysed: ",
        scenario_name
      )
    }

    qg_points <- validate_numeric_matrix(
      qg_result$occurrence_points,
      paste0("Script 01 occurrence points for ", scenario_name)
    )

    svm_points <- validate_numeric_matrix(
      svm_result$occurrence_points,
      paste0("Script 02 occurrence points for ", scenario_name)
    )

    colnames(qg_points) <- colnames(archived_points)
    colnames(svm_points) <- colnames(archived_points)

    if (!identical(qg_points, archived_points)) {
      stop(
        "Script 01 occurrence points do not exactly match the archive for ",
        scenario_name,
        "."
      )
    }

    if (!identical(svm_points, archived_points)) {
      stop(
        "Script 02 occurrence points do not exactly match the archive for ",
        scenario_name,
        "."
      )
    }

    validate_hypervolume(
      qg_result$hv_gaussian,
      paste0("Gaussian hypervolume for ", scenario_name)
    )

    validate_hypervolume(
      qg_result$hv_qph,
      paste0("QPH hypervolume for ", scenario_name)
    )

    validate_hypervolume(
      svm_result$hv_svm,
      paste0("SVM hypervolume for ", scenario_name)
    )

    if (!identical(
      as.integer(qg_result$hv_gaussian@Parameters$samples.per.point),
      expected_samples_per_point
    )) {
      stop(
        "Gaussian KDE scenario ",
        scenario_name,
        " was not fitted with samples.per.point = ",
        expected_samples_per_point,
        "."
      )
    }

    if (!identical(
      as.integer(qg_result$hv_qph@Parameters$samples.per.point),
      expected_samples_per_point
    )) {
      stop(
        "QPH scenario ",
        scenario_name,
        " was not fitted with samples.per.point = ",
        expected_samples_per_point,
        "."
      )
    }

    if (!identical(
      as.integer(svm_result$hv_svm@Parameters$samples.per.point),
      expected_samples_per_point
    )) {
      stop(
        "SVM scenario ",
        scenario_name,
        " was not passed samples.per.point = ",
        expected_samples_per_point,
        "."
      )
    }

    if (!identical(
      as.character(svm_result$summary$Sampling_effort_mode),
      "same_argument"
    )) {
      stop(
        "SVM scenario ",
        scenario_name,
        " was not generated using package-preserving same_argument mode."
      )
    }

    # Revised QPH definition audit.
    qph_audit <- qg_result$qph_audit

    if (is.null(qph_audit)) {
      stop("Missing QPH audit for ", scenario_name, ".")
    }

    expected_k <- max(
      2L,
      min(
        as.integer(round(sqrt(sample_size))),
        sample_size - 1L
      )
    )

    if (!identical(
      as.integer(qph_audit$K),
      expected_k
    )) {
      stop(
        "QPH K does not equal round(sqrt(n)) for ",
        scenario_name,
        "."
      )
    }

    if (!isTRUE(all.equal(
      as.numeric(qph_audit$q),
      expected_qph_q,
      tolerance = 0
    ))) {
      stop(
        "QPH q is not 0.99 for ",
        scenario_name,
        "."
      )
    }

    if (!identical(
      as.character(qph_audit$bandwidth_method),
      expected_qph_bandwidth_method
    )) {
      stop(
        "Unexpected revised QPH bandwidth method for ",
        scenario_name,
        "."
      )
    }

    expected_h <- sqrt(
      mean(
        as.numeric(qph_audit$local_s)
      )
    )

    if (!isTRUE(all.equal(
      as.numeric(qph_audit$baseline_scalar_h),
      expected_h,
      tolerance = 1e-12
    ))) {
      stop(
        "QPH scalar h does not equal sqrt(mean(local_s)) for ",
        scenario_name,
        "."
      )
    }

    if (!isTRUE(all.equal(
      as.numeric(qph_audit$fitted_bandwidth),
      rep(expected_h, 2L),
      tolerance = 1e-12
    ))) {
      stop(
        "Baseline QPH bandwidth is not the expected isotropic sqrt-NB ",
        "bandwidth for ",
        scenario_name,
        "."
      )
    }

    # Comparator settings remain unchanged.
    if (!isTRUE(all.equal(
      as.numeric(qg_result$kde_probability_quantile),
      expected_kde_probability_quantile,
      tolerance = 0
    ))) {
      stop(
        "Gaussian KDE probability quantile is not 0.95 for ",
        scenario_name,
        "."
      )
    }

    if (!isTRUE(all.equal(
      as.numeric(svm_result$hv_svm@Parameters$svm.nu),
      expected_svm_nu
    ))) {
      stop("Unexpected SVM nu for ", scenario_name, ".")
    }

    if (!isTRUE(all.equal(
      as.numeric(svm_result$hv_svm@Parameters$svm.gamma),
      expected_svm_gamma
    ))) {
      stop("Unexpected SVM gamma for ", scenario_name, ".")
    }
  }
}

message(
  "All locked occurrence clouds and revised baseline fitted objects ",
  "were verified."
)

# ============================================================
# Coordinate helpers
# ============================================================

rotate_and_translate <- function(
    x,
    y,
    angle = 0,
    centre = c(0, 0)
) {
  cos_angle <- cos(angle)
  sin_angle <- sin(angle)

  cbind(
    x = cos_angle * x - sin_angle * y + centre[1],
    y = sin_angle * x + cos_angle * y + centre[2]
  )
}

inverse_rotate_and_translate <- function(
    points,
    angle = 0,
    centre = c(0, 0)
) {
  points <- validate_numeric_matrix(points, "points")

  centred_x <- points[, 1] - centre[1]
  centred_y <- points[, 2] - centre[2]

  cos_angle <- cos(angle)
  sin_angle <- sin(angle)

  cbind(
    x = cos_angle * centred_x + sin_angle * centred_y,
    y = -sin_angle * centred_x + cos_angle * centred_y
  )
}

# ============================================================
# Uniform sampling from each analytically known true region
# ============================================================

sample_true_spiral <- function(n, parameters) {
  inner_intercept <- parameters$inner_intercept
  radial_growth <- parameters$radial_growth
  band_width <- parameters$band_width
  theta_min <- parameters$theta_min
  theta_max <- parameters$theta_max
  rotation <- parameters$rotation

  if (is.null(rotation)) {
    rotation <- 0
  }

  inner_radius_function <- function(theta) {
    inner_intercept + radial_growth * theta
  }

  outer_radius_function <- function(theta) {
    inner_radius_function(theta) + band_width
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

  maximum_weight <- max(angular_weight(theta_grid))
  sampled_theta <- numeric(n)
  number_filled <- 0L

  while (number_filled < n) {
    number_needed <- n - number_filled
    number_proposed <- max(2000L, ceiling(number_needed * 2))

    proposed_theta <- runif(
      number_proposed,
      min = theta_min,
      max = theta_max
    )

    accepted_theta <- proposed_theta[
      runif(number_proposed) <=
        angular_weight(proposed_theta) / maximum_weight
    ]

    number_accepted <- min(
      length(accepted_theta),
      number_needed
    )

    if (number_accepted > 0L) {
      destination <- seq.int(
        from = number_filled + 1L,
        length.out = number_accepted
      )

      sampled_theta[destination] <- accepted_theta[
        seq_len(number_accepted)
      ]

      number_filled <- number_filled + number_accepted
    }
  }

  inner_radius <- inner_radius_function(sampled_theta)
  outer_radius <- outer_radius_function(sampled_theta)

  sampled_radius <- sqrt(
    inner_radius^2 +
      runif(n) * (outer_radius^2 - inner_radius^2)
  )

  points <- rotate_and_translate(
    x = sampled_radius * cos(sampled_theta),
    y = sampled_radius * sin(sampled_theta),
    angle = rotation,
    centre = c(0, 0)
  )

  colnames(points) <- c(
    "Environmental axis 1",
    "Environmental axis 2"
  )

  points
}

sample_true_ellipse <- function(n, parameters) {
  theta <- runif(n, min = 0, max = 2 * pi)
  radial_fraction <- sqrt(runif(n))

  points <- rotate_and_translate(
    x = parameters$semi_axis_1 * radial_fraction * cos(theta),
    y = parameters$semi_axis_2 * radial_fraction * sin(theta),
    angle = parameters$rotation,
    centre = c(0, 0)
  )

  colnames(points) <- c(
    "Environmental axis 1",
    "Environmental axis 2"
  )

  points
}

sample_true_annulus <- function(n, parameters) {
  theta <- runif(n, min = 0, max = 2 * pi)

  radius <- sqrt(
    parameters$inner_radius^2 +
      runif(n) * (
        parameters$outer_radius^2 -
          parameters$inner_radius^2
      )
  )

  points <- cbind(
    "Environmental axis 1" = radius * cos(theta),
    "Environmental axis 2" = radius * sin(theta)
  )

  points
}

sample_true_banana <- function(n, parameters) {
  theta <- runif(n, min = 0, max = 2 * pi)
  radial_fraction <- sqrt(runif(n))

  ellipse_x <- (
    parameters$semi_axis_1 *
      radial_fraction *
      cos(theta)
  )

  ellipse_y <- (
    parameters$semi_axis_2 *
      radial_fraction *
      sin(theta)
  )

  banana_x <- ellipse_x
  banana_y <- ellipse_y + parameters$curvature * (
    ellipse_x^2 - parameters$semi_axis_1^2 / 2
  )

  points <- rotate_and_translate(
    x = banana_x,
    y = banana_y,
    angle = parameters$rotation,
    centre = c(0, 0)
  )

  colnames(points) <- c(
    "Environmental axis 1",
    "Environmental axis 2"
  )

  points
}

sample_true_two_balls <- function(n, parameters) {
  number_in_first <- ceiling(n / 2)
  number_in_second <- floor(n / 2)

  sample_one_disk <- function(number_of_points, centre) {
    theta <- runif(number_of_points, min = 0, max = 2 * pi)
    radius <- parameters$radius * sqrt(runif(number_of_points))

    cbind(
      x = centre[1] + radius * cos(theta),
      y = centre[2] + radius * sin(theta)
    )
  }

  points <- rbind(
    sample_one_disk(number_in_first, parameters$centre_1),
    sample_one_disk(number_in_second, parameters$centre_2)
  )

  colnames(points) <- c(
    "Environmental axis 1",
    "Environmental axis 2"
  )

  points
}

sample_true_region <- function(shape_name, n, parameters) {
  switch(
    shape_name,
    spiral = sample_true_spiral(n, parameters),
    ellipse = sample_true_ellipse(n, parameters),
    annulus = sample_true_annulus(n, parameters),
    banana = sample_true_banana(n, parameters),
    two_balls = sample_true_two_balls(n, parameters),
    stop("Unknown shape_name: ", shape_name)
  )
}

# ============================================================
# Exact point-in-region tests used only for Figure 2 rasterisation
# ============================================================

inside_true_spiral <- function(points, parameters) {
  transformed <- inverse_rotate_and_translate(
    points,
    angle = ifelse(is.null(parameters$rotation), 0, parameters$rotation),
    centre = c(0, 0)
  )

  radial_distance <- sqrt(rowSums(transformed^2))
  base_angle <- atan2(transformed[, 2], transformed[, 1])
  base_angle[base_angle < 0] <- base_angle[base_angle < 0] + 2 * pi

  result <- rep(FALSE, nrow(transformed))

  candidate_turns <- seq.int(
    from = floor(parameters$theta_min / (2 * pi)) - 1L,
    to = ceiling(parameters$theta_max / (2 * pi)) + 1L
  )

  for (turn_index in candidate_turns) {
    candidate_theta <- base_angle + 2 * pi * turn_index

    theta_valid <- (
      candidate_theta >= parameters$theta_min - 1e-10 &
        candidate_theta <= parameters$theta_max + 1e-10
    )

    inner_radius <- (
      parameters$inner_intercept +
        parameters$radial_growth * candidate_theta
    )

    outer_radius <- inner_radius + parameters$band_width

    result <- result | (
      theta_valid &
        radial_distance >= inner_radius - 1e-10 &
        radial_distance <= outer_radius + 1e-10
    )
  }

  result
}

inside_true_ellipse <- function(points, parameters) {
  transformed <- inverse_rotate_and_translate(
    points,
    angle = parameters$rotation,
    centre = c(0, 0)
  )

  (
    transformed[, 1] / parameters$semi_axis_1
  )^2 + (
    transformed[, 2] / parameters$semi_axis_2
  )^2 <= 1 + 1e-10
}

inside_true_annulus <- function(points, parameters) {
  points <- validate_numeric_matrix(points, "points")
  radial_distance <- sqrt(rowSums(points^2))

  radial_distance >= parameters$inner_radius - 1e-10 &
    radial_distance <= parameters$outer_radius + 1e-10
}

inside_true_banana <- function(points, parameters) {
  transformed <- inverse_rotate_and_translate(
    points,
    angle = parameters$rotation,
    centre = c(0, 0)
  )

  ellipse_x <- transformed[, 1]
  ellipse_y <- transformed[, 2] - parameters$curvature * (
    ellipse_x^2 - parameters$semi_axis_1^2 / 2
  )

  (
    ellipse_x / parameters$semi_axis_1
  )^2 + (
    ellipse_y / parameters$semi_axis_2
  )^2 <= 1 + 1e-10
}

inside_true_two_balls <- function(points, parameters) {
  points <- validate_numeric_matrix(points, "points")

  distance_1 <- sqrt(
    (points[, 1] - parameters$centre_1[1])^2 +
      (points[, 2] - parameters$centre_1[2])^2
  )

  distance_2 <- sqrt(
    (points[, 1] - parameters$centre_2[1])^2 +
      (points[, 2] - parameters$centre_2[2])^2
  )

  distance_1 <= parameters$radius + 1e-10 |
    distance_2 <= parameters$radius + 1e-10
}

inside_true_region <- function(shape_name, points, parameters) {
  switch(
    shape_name,
    spiral = inside_true_spiral(points, parameters),
    ellipse = inside_true_ellipse(points, parameters),
    annulus = inside_true_annulus(points, parameters),
    banana = inside_true_banana(points, parameters),
    two_balls = inside_true_two_balls(points, parameters),
    stop("Unknown shape_name: ", shape_name)
  )
}


# ============================================================
# Construct or load dense true-region Hypervolume objects
# ============================================================

create_true_hypervolume <- function(
    points,
    true_area,
    shape_label
) {
  points <- validate_numeric_matrix(points, "true reference points")

  data_rows <- seq_len(min(1500L, nrow(points)))
  data_for_slot <- points[data_rows, , drop = FALSE]

  hv_true <- methods::new(
    "Hypervolume",
    Name = paste0("Known true region: ", shape_label),
    Method = "Known synthetic region",
    Data = data_for_slot,
    Dimensionality = 2,
    Volume = as.numeric(true_area),
    PointDensity = as.numeric(nrow(points) / true_area),
    Parameters = list(
      exact.area = true_area,
      reference.points = nrow(points),
      representation = "Uniform reference cloud from known region"
    ),
    RandomPoints = points,
    ValueAtRandomPoints = rep(
      1 / true_area,
      nrow(points)
    )
  )

  hv_true <- standardise_hypervolume_axis_names(hv_true)
  methods::validObject(hv_true)
  hv_true
}

reference_settings <- list(
  occurrence_archive_md5 = safe_md5(occurrence_archive_file),
  points_per_shape = true_reference_points_per_shape,
  expected_shape_names = expected_shape_names,
  reference_seed_base = true_reference_seed_base
)

reference_settings_hash <- paste(
  unlist(reference_settings),
  collapse = "|"
)

if (file.exists(true_reference_file)) {
  true_reference_archive <- readRDS(true_reference_file)

  if (
    is.list(true_reference_archive) &&
      identical(
        true_reference_archive$settings_hash,
        reference_settings_hash
      )
  ) {
    message("Loading compatible saved true-region reference clouds...")
    true_references <- true_reference_archive$references
  } else {
    warning(
      "The existing true-region reference archive is incompatible and ",
      "will be regenerated."
    )
    true_references <- NULL
  }
} else {
  true_references <- NULL
}

if (is.null(true_references)) {
  message("Generating fixed dense true-region reference clouds...")
  true_references <- list()
  reference_manifest_rows <- list()

  for (shape_index in seq_along(expected_shape_names)) {
    shape_name <- expected_shape_names[shape_index]
    master_object <- occurrence_archive$master_datasets[[shape_name]]
    reference_seed <- reference_settings$reference_seed_base + shape_index

    set.seed(reference_seed)

    reference_points <- sample_true_region(
      shape_name = shape_name,
      n = true_reference_points_per_shape,
      parameters = master_object$parameters
    )

    reference_hv <- create_true_hypervolume(
      points = reference_points,
      true_area = master_object$true_area,
      shape_label = master_object$shape_label
    )

    true_centroid <- colMeans(reference_points)

    true_references[[shape_name]] <- list(
      shape_name = shape_name,
      shape_label = master_object$shape_label,
      reference_seed = reference_seed,
      points = reference_points,
      hypervolume = reference_hv,
      true_area = master_object$true_area,
      true_centroid = true_centroid,
      boundary = master_object$boundary,
      parameters = master_object$parameters
    )

    reference_manifest_rows[[shape_index]] <- data.frame(
      Shape_code = shape_name,
      Shape = master_object$shape_label,
      Reference_seed = reference_seed,
      Reference_points = nrow(reference_points),
      Exact_true_area = master_object$true_area,
      True_centroid_axis_1 = true_centroid[1],
      True_centroid_axis_2 = true_centroid[2],
      Point_density = reference_hv@PointDensity,
      stringsAsFactors = FALSE
    )
  }

  true_reference_archive <- list(
    settings_hash = reference_settings_hash,
    settings = reference_settings,
    references = true_references,
    created_at = as.character(Sys.time())
  )

  saveRDS(
    true_reference_archive,
    file = true_reference_file,
    version = 3
  )

  reference_manifest <- do.call(
    rbind,
    reference_manifest_rows
  )

  write.csv(
    reference_manifest,
    file = true_reference_manifest_file,
    row.names = FALSE
  )
} else {
  reference_manifest <- do.call(
    rbind,
    lapply(
      true_references,
      function(reference) {
        data.frame(
          Shape_code = reference$shape_name,
          Shape = reference$shape_label,
          Reference_seed = reference$reference_seed,
          Reference_points = nrow(reference$points),
          Exact_true_area = reference$true_area,
          True_centroid_axis_1 = reference$true_centroid[1],
          True_centroid_axis_2 = reference$true_centroid[2],
          Point_density = reference$hypervolume@PointDensity,
          stringsAsFactors = FALSE
        )
      }
    )
  )

  rownames(reference_manifest) <- NULL

  write.csv(
    reference_manifest,
    file = true_reference_manifest_file,
    row.names = FALSE
  )
}

# ============================================================
# Extract a consistent method-specific record from saved results
# ============================================================

extract_method_record <- function(
    method,
    scenario_name,
    qg_result,
    svm_result
) {
  if (method == "Gaussian KDE") {
    list(
      hv = qg_result$hv_gaussian,
      volume = qg_result$hv_gaussian@Volume,
      random_points = nrow(qg_result$hv_gaussian@RandomPoints),
      runtime = as.numeric(
        qg_result$summary$Gaussian_runtime_seconds
      )
    )
  } else if (method == "QPH") {
    list(
      hv = qg_result$hv_qph,
      volume = qg_result$hv_qph@Volume,
      random_points = nrow(qg_result$hv_qph@RandomPoints),
      runtime = as.numeric(
        qg_result$summary$QPH_runtime_seconds
      )
    )
  } else if (method == "SVM") {
    list(
      hv = svm_result$hv_svm,
      volume = svm_result$hv_svm@Volume,
      random_points = nrow(svm_result$hv_svm@RandomPoints),
      runtime = as.numeric(
        svm_result$summary$SVM_hypervolume_runtime_seconds
      )
    )
  } else {
    stop("Unknown method: ", method)
  }
}

# ============================================================
# Jaccard and centroid analysis with checkpointing
# ============================================================

analysis_settings <- list(
  occurrence_archive_md5 = safe_md5(occurrence_archive_file),
  revised_baseline_results_md5 = safe_md5(baseline_results_file),
  revised_baseline_summary_md5 = safe_md5(baseline_summary_file),
  true_reference_md5 = safe_md5(true_reference_file),
  qph_q = expected_qph_q,
  qph_bandwidth_method = expected_qph_bandwidth_method,
  kde_probability_quantile = expected_kde_probability_quantile,
  svm_nu = expected_svm_nu,
  svm_gamma = expected_svm_gamma,
  svm_scale_factor = expected_svm_scale_factor,
  jaccard_num_points_max = jaccard_num_points_max,
  jaccard_distance_factor = jaccard_distance_factor,
  methods = method_order,
  shapes = expected_shape_names,
  sample_sizes = expected_sample_sizes
)

analysis_settings_hash <- paste(
  unlist(analysis_settings),
  collapse = "|"
)

if (
  resume_from_checkpoint &&
    file.exists(geometry_checkpoint_file)
) {
  geometry_checkpoint <- readRDS(geometry_checkpoint_file)

  if (!identical(
    geometry_checkpoint$analysis_settings_hash,
    analysis_settings_hash
  )) {
    stop(
      "The existing Script 02 checkpoint was produced using different ",
      "inputs or settings. Set resume_from_checkpoint = FALSE or use a ",
      "new geometry_output_directory."
    )
  }

  geometry_results <- geometry_checkpoint$results

  message(
    "Loaded compatible geometrical checkpoint containing ",
    length(geometry_results),
    " completed method-scenario comparison(s)."
  )
} else {
  geometry_results <- list()
}

comparison_index <- 0L

for (shape_name in expected_shape_names) {
  reference <- true_references[[shape_name]]

  for (sample_size in expected_sample_sizes) {
    scenario_name <- paste(shape_name, sample_size, sep = "_")
    qg_result <- qph_gaussian_results[[scenario_name]]
    svm_result <- svm_results[[scenario_name]]

    for (method_index in seq_along(method_order)) {
      method <- method_order[method_index]
      comparison_index <- comparison_index + 1L

      result_key <- paste(
        shape_name,
        sample_size,
        gsub(" ", "_", method),
        sep = "__"
      )

      if (result_key %in% names(geometry_results)) {
        if (isTRUE(geometry_results[[result_key]]$success)) {
          message("Skipping successful geometry comparison: ", result_key)
          next
        }

        message("Retrying previously failed geometry comparison: ", result_key)
        geometry_results[[result_key]] <- NULL
      }

      message(
        "Calculating geometry: ",
        reference$shape_label,
        ", n = ",
        sample_size,
        ", ",
        method,
        "..."
      )

      method_record <- extract_method_record(
        method = method,
        scenario_name = scenario_name,
        qg_result = qg_result,
        svm_result = svm_result
      )

      estimated_hv <- standardise_hypervolume_axis_names(
        method_record$hv
      )

      true_hv <- standardise_hypervolume_axis_names(
        reference$hypervolume
      )

      set_seed <- 50123L + comparison_index
      set.seed(set_seed)

      geometry_result <- tryCatch(
        {
          set_time <- system.time({
            hv_set <- hypervolume::hypervolume_set(
              hv1 = estimated_hv,
              hv2 = true_hv,
              num.points.max = jaccard_num_points_max,
              verbose = FALSE,
              check.memory = FALSE,
              distance.factor = jaccard_distance_factor
            )
          })

          overlap_statistics <- (
            hypervolume::hypervolume_overlap_statistics(hv_set)
          )

          intersection_volume <- (
            hv_set@HVList$Intersection@Volume
          )

          union_volume <- hv_set@HVList$Union@Volume

          jaccard_value <- as.numeric(
            overlap_statistics[["jaccard"]]
          )

          # Sorensen similarity is algebraically linked to Jaccard:
          #   S = 2J / (1 + J)
          # Calculating it from the same set-operation Jaccard ensures both
          # overlap metrics refer to the identical stochastic comparison.
          sorensen_value <- if (
            is.finite(jaccard_value)
          ) {
            2 * jaccard_value / (1 + jaccard_value)
          } else {
            NA_real_
          }

          estimated_centroid <- colMeans(
            estimated_hv@RandomPoints
          )

          true_centroid <- reference$true_centroid

          centroid_displacement <- sqrt(
            sum((estimated_centroid - true_centroid)^2)
          )

          estimated_area <- as.numeric(method_record$volume)
          true_area <- as.numeric(reference$true_area)
          signed_error <- estimated_area - true_area

          # Set-operation diagnostics requested for the clean rerun.
          true_region_coverage <- (
            intersection_volume /
              true_area
          )

          excess_estimated_area <- (
            estimated_area -
              intersection_volume
          )

          excess_estimated_fraction <- if (
            estimated_area > 0
          ) {
            excess_estimated_area / estimated_area
          } else {
            NA_real_
          }

          list(
            success = TRUE,
            summary = data.frame(
              Success = TRUE,
              Shape = reference$shape_label,
              Shape_code = shape_name,
              Sample_size = sample_size,
              Method = method,
              True_area = true_area,
              Estimated_area = estimated_area,
              Signed_area_error = signed_error,
              Absolute_area_error = abs(signed_error),
              Relative_area_error_percent = (
                100 * signed_error / true_area
              ),
              Intersection_area = intersection_volume,
              Union_area = union_volume,
              Jaccard_similarity = jaccard_value,
              Sorensen_similarity = sorensen_value,
              True_region_coverage = true_region_coverage,
              Excess_estimated_area = excess_estimated_area,
              Excess_estimated_fraction = excess_estimated_fraction,
              Estimated_centroid_axis_1 = estimated_centroid[1],
              Estimated_centroid_axis_2 = estimated_centroid[2],
              True_centroid_axis_1 = true_centroid[1],
              True_centroid_axis_2 = true_centroid[2],
              Centroid_displacement = centroid_displacement,
              Estimated_random_points = method_record$random_points,
              Estimator_runtime_seconds = method_record$runtime,
              Set_operation_runtime_seconds = unname(
                set_time["elapsed"]
              ),
              Jaccard_num_points_max = jaccard_num_points_max,
              Jaccard_distance_factor = jaccard_distance_factor,
              Set_operation_seed = set_seed,
              Error_message = NA_character_,
              stringsAsFactors = FALSE
            )
          )
        },
        error = function(error_condition) {
          error_message <- conditionMessage(error_condition)

          warning(
            "Geometry comparison failed for ",
            result_key,
            ": ",
            error_message
          )

          list(
            success = FALSE,
            summary = data.frame(
              Success = FALSE,
              Shape = reference$shape_label,
              Shape_code = shape_name,
              Sample_size = sample_size,
              Method = method,
              True_area = reference$true_area,
              Estimated_area = method_record$volume,
              Signed_area_error = NA_real_,
              Absolute_area_error = NA_real_,
              Relative_area_error_percent = NA_real_,
              Intersection_area = NA_real_,
              Union_area = NA_real_,
              Jaccard_similarity = NA_real_,
              Sorensen_similarity = NA_real_,
              True_region_coverage = NA_real_,
              Excess_estimated_area = NA_real_,
              Excess_estimated_fraction = NA_real_,
              Estimated_centroid_axis_1 = NA_real_,
              Estimated_centroid_axis_2 = NA_real_,
              True_centroid_axis_1 = reference$true_centroid[1],
              True_centroid_axis_2 = reference$true_centroid[2],
              Centroid_displacement = NA_real_,
              Estimated_random_points = method_record$random_points,
              Estimator_runtime_seconds = method_record$runtime,
              Set_operation_runtime_seconds = NA_real_,
              Jaccard_num_points_max = jaccard_num_points_max,
              Jaccard_distance_factor = jaccard_distance_factor,
              Set_operation_seed = set_seed,
              Error_message = error_message,
              stringsAsFactors = FALSE
            )
          )
        }
      )

      geometry_results[[result_key]] <- geometry_result

      geometry_checkpoint <- list(
        analysis_settings_hash = analysis_settings_hash,
        analysis_settings = analysis_settings,
        results = geometry_results,
        last_updated = as.character(Sys.time())
      )

      saveRDS(
        geometry_checkpoint,
        file = geometry_checkpoint_file,
        version = 3
      )
    }
  }
}

# ============================================================
# Combine and save the geometrical summary
# ============================================================

geometry_summary <- do.call(
  rbind,
  lapply(
    geometry_results,
    function(result) result$summary
  )
)

rownames(geometry_summary) <- NULL

geometry_summary$Shape_code <- factor(
  geometry_summary$Shape_code,
  levels = expected_shape_names
)

geometry_summary$Shape <- factor(
  geometry_summary$Shape,
  levels = vapply(
    expected_shape_names,
    function(shape_name) {
      occurrence_archive$master_datasets[[shape_name]]$shape_label
    },
    character(1)
  )
)

geometry_summary$Method <- factor(
  geometry_summary$Method,
  levels = method_order
)

geometry_summary <- geometry_summary[
  order(
    geometry_summary$Shape_code,
    geometry_summary$Sample_size,
    geometry_summary$Method
  ),
  ,
  drop = FALSE
]

# Convert factors back to readable text before writing CSV.
geometry_summary_csv <- geometry_summary
geometry_summary_csv$Shape_code <- as.character(
  geometry_summary_csv$Shape_code
)
geometry_summary_csv$Shape <- as.character(
  geometry_summary_csv$Shape
)
geometry_summary_csv$Method <- as.character(
  geometry_summary_csv$Method
)

write.csv(
  geometry_summary_csv,
  file = geometry_summary_file,
  row.names = FALSE
)

saveRDS(
  list(
    analysis_settings = analysis_settings,
    geometry_results = geometry_results,
    geometry_summary = geometry_summary,
    true_references = true_references,
    completed_at = as.character(Sys.time())
  ),
  file = geometry_results_file,
  version = 3
)

if (any(!geometry_summary$Success)) {
  warning(
    "One or more geometrical comparisons failed. Inspect Error_message in ",
    geometry_summary_file,
    "."
  )
}

successful_geometry <- geometry_summary[
  geometry_summary$Success,
  ,
  drop = FALSE
]

if (nrow(successful_geometry) == 0L) {
  stop("No geometrical comparisons completed successfully.")
}

print_columns <- c(
  "Shape",
  "Sample_size",
  "Method",
  "True_area",
  "Estimated_area",
  "Relative_area_error_percent",
  "Jaccard_similarity",
  "Sorensen_similarity",
  "True_region_coverage",
  "Excess_estimated_area",
  "Centroid_displacement"
)

print(
  successful_geometry[, print_columns, drop = FALSE],
  digits = 4,
  row.names = FALSE
)

# ============================================================
# Figure helpers
# ============================================================

boundary_to_data_frame <- function(boundary) {
  boundary_rows <- lapply(
    seq_along(boundary),
    function(segment_index) {
      segment <- validate_numeric_matrix(
        boundary[[segment_index]],
        paste0("boundary segment ", segment_index)
      )

      data.frame(
        x = segment[, 1],
        y = segment[, 2],
        group = paste0("boundary_", segment_index),
        stringsAsFactors = FALSE
      )
    }
  )

  do.call(rbind, boundary_rows)
}

get_method_hypervolume <- function(
    method,
    qg_result,
    svm_result
) {
  hv <- switch(
    method,
    "Gaussian KDE" = qg_result$hv_gaussian,
    "SVM" = svm_result$hv_svm,
    "QPH" = qg_result$hv_qph,
    stop("Unknown method: ", method)
  )

  standardise_hypervolume_axis_names(hv)
}

thin_hypervolume_for_figure <- function(
    hv,
    maximum_points,
    seed
) {
  hv <- standardise_hypervolume_axis_names(hv)

  if (nrow(hv@RandomPoints) <= maximum_points) {
    return(hv)
  }

  set.seed(seed)

  thinned_hv <- hypervolume::hypervolume_thin(
    hv,
    num.points = maximum_points
  )

  standardise_hypervolume_axis_names(thinned_hv)
}

calculate_shape_limits <- function(
    shape_name,
    sample_size
) {
  scenario_name <- paste(shape_name, sample_size, sep = "_")
  qg_result <- qph_gaussian_results[[scenario_name]]
  svm_result <- svm_results[[scenario_name]]
  master_object <- occurrence_archive$master_datasets[[shape_name]]

  boundary_points <- do.call(
    rbind,
    lapply(
      seq_along(master_object$boundary),
      function(segment_index) {
        standardise_xy_matrix(
          master_object$boundary[[segment_index]],
          paste0("boundary segment ", segment_index)
        )
      }
    )
  )

  all_points <- do.call(
    rbind,
    list(
      boundary_points,
      standardise_xy_matrix(
        qg_result$occurrence_points,
        "occurrence points"
      ),
      standardise_xy_matrix(
        qg_result$hv_gaussian@RandomPoints,
        "Gaussian KDE random points"
      ),
      standardise_xy_matrix(
        svm_result$hv_svm@RandomPoints,
        "SVM random points"
      ),
      standardise_xy_matrix(
        qg_result$hv_qph@RandomPoints,
        "QPH random points"
      )
    )
  )

  x_range <- range(all_points[, 1], finite = TRUE)
  y_range <- range(all_points[, 2], finite = TRUE)

  x_padding <- max(0.04 * diff(x_range), 0.05)
  y_padding <- max(0.04 * diff(y_range), 0.05)

  list(
    x = x_range + c(-x_padding, x_padding),
    y = y_range + c(-y_padding, y_padding)
  )
}

create_grid <- function(limits, resolution) {
  x_sequence <- seq(
    limits$x[1],
    limits$x[2],
    length.out = resolution
  )

  y_sequence <- seq(
    limits$y[1],
    limits$y[2],
    length.out = resolution
  )

  grid <- expand.grid(
    x = x_sequence,
    y = y_sequence,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )

  points <- as.matrix(grid[, c("x", "y")])

  colnames(points) <- c(
    "Environmental axis 1",
    "Environmental axis 2"
  )

  list(
    data = grid,
    points = points,
    tile_width = ifelse(
      length(x_sequence) > 1L,
      diff(x_sequence)[1],
      1
    ),
    tile_height = ifelse(
      length(y_sequence) > 1L,
      diff(y_sequence)[1],
      1
    )
  )
}

# ============================================================
# Prepare raster data for representative n = 900 regions
# ============================================================

if (file.exists(figure_raster_file)) {
  figure_raster_archive <- readRDS(figure_raster_file)

  figure_raster_settings <- list(
    revised_baseline_results_md5 = safe_md5(baseline_results_file),
    representative_sample_size = representative_sample_size,
    grid_resolution = figure_grid_resolution,
    hypervolume_points_max = figure_hypervolume_points_max
  )

  figure_raster_settings_hash <- paste(
    unlist(figure_raster_settings),
    collapse = "|"
  )

  if (identical(
    figure_raster_archive$settings_hash,
    figure_raster_settings_hash
  )) {
    message("Loading compatible saved Figure 2 raster data...")
    figure_rasters <- figure_raster_archive$rasters
    figure_limits <- figure_raster_archive$limits
  } else {
    figure_rasters <- NULL
    figure_limits <- NULL
  }
} else {
  figure_raster_settings <- list(
    revised_baseline_results_md5 = safe_md5(baseline_results_file),
    representative_sample_size = representative_sample_size,
    grid_resolution = figure_grid_resolution,
    hypervolume_points_max = figure_hypervolume_points_max
  )

  figure_raster_settings_hash <- paste(
    unlist(figure_raster_settings),
    collapse = "|"
  )

  figure_rasters <- NULL
  figure_limits <- NULL
}

if (is.null(figure_rasters)) {
  message("Rasterising representative regions for Figure 2a...")

  figure_rasters <- list()
  figure_limits <- list()
  figure_counter <- 0L

  for (shape_name in expected_shape_names) {
    scenario_name <- paste(
      shape_name,
      representative_sample_size,
      sep = "_"
    )

    qg_result <- qph_gaussian_results[[scenario_name]]
    svm_result <- svm_results[[scenario_name]]
    master_object <- occurrence_archive$master_datasets[[shape_name]]

    limits <- calculate_shape_limits(
      shape_name,
      representative_sample_size
    )

    figure_limits[[shape_name]] <- limits
    grid_object <- create_grid(limits, figure_grid_resolution)

    true_inside <- inside_true_region(
      shape_name = shape_name,
      points = grid_object$points,
      parameters = master_object$parameters
    )

    figure_rasters[[paste(shape_name, "Truth", sep = "__")]] <- list(
      data = transform(
        grid_object$data,
        inside = true_inside
      ),
      tile_width = grid_object$tile_width,
      tile_height = grid_object$tile_height
    )

    for (method_index in seq_along(method_order)) {
      method <- method_order[method_index]
      figure_counter <- figure_counter + 1L

      hv <- get_method_hypervolume(
        method = method,
        qg_result = qg_result,
        svm_result = svm_result
      )

      hv_for_figure <- thin_hypervolume_for_figure(
        hv = hv,
        maximum_points = figure_hypervolume_points_max,
        seed = 60123L + figure_counter
      )

      inside_estimated <- suppressWarnings(
        hypervolume::hypervolume_inclusion_test(
          hv = hv_for_figure,
          points = grid_object$points,
          reduction.factor = 1,
          fast.or.accurate = "fast",
          fast.method.distance.factor = 1,
          verbose = FALSE
        )
      )

      figure_rasters[[paste(shape_name, method, sep = "__")]] <- list(
        data = transform(
          grid_object$data,
          inside = as.logical(inside_estimated)
        ),
        tile_width = grid_object$tile_width,
        tile_height = grid_object$tile_height
      )
    }
  }

  figure_raster_archive <- list(
    settings_hash = figure_raster_settings_hash,
    settings = figure_raster_settings,
    rasters = figure_rasters,
    limits = figure_limits,
    created_at = as.character(Sys.time())
  )

  saveRDS(
    figure_raster_archive,
    file = figure_raster_file,
    version = 3
  )
}

# ============================================================
# Construct Figure 2a: representative regions at n = 900
# ============================================================

representative_rows <- c(
  "Truth + occurrences",
  method_order
)

representative_plots <- list()
plot_counter <- 0L

for (row_index in seq_along(representative_rows)) {
  row_label <- representative_rows[row_index]

  for (shape_index in seq_along(expected_shape_names)) {
    shape_name <- expected_shape_names[shape_index]
    scenario_name <- paste(
      shape_name,
      representative_sample_size,
      sep = "_"
    )

    qg_result <- qph_gaussian_results[[scenario_name]]
    master_object <- occurrence_archive$master_datasets[[shape_name]]
    limits <- figure_limits[[shape_name]]
    boundary_data <- boundary_to_data_frame(master_object$boundary)

    if (row_label == "Truth + occurrences") {
      raster_object <- figure_rasters[[paste(shape_name, "Truth", sep = "__")]]
      fill_colour <- true_region_colour
      occurrence_points <- as.data.frame(qg_result$occurrence_points)
      names(occurrence_points) <- c("x", "y")
    } else {
      raster_object <- figure_rasters[[paste(shape_name, row_label, sep = "__")]]
      fill_colour <- method_colours[[row_label]]
      occurrence_points <- NULL
    }

    inside_raster <- raster_object$data[
      raster_object$data$inside,
      ,
      drop = FALSE
    ]

    panel_plot <- ggplot() +
      geom_tile(
        data = inside_raster,
        mapping = aes(x = x, y = y),
        width = raster_object$tile_width,
        height = raster_object$tile_height,
        fill = fill_colour,
        alpha = figure_raster_alpha
      ) +
      geom_path(
        data = boundary_data,
        mapping = aes(x = x, y = y, group = group),
        colour = "black",
        linewidth = 0.28,
        lineend = "round"
      )

    if (!is.null(occurrence_points)) {
      panel_plot <- panel_plot +
        geom_point(
          data = occurrence_points,
          mapping = aes(x = x, y = y),
          colour = occurrence_colour,
          size = figure_point_size,
          alpha = figure_point_alpha
        )
    }

    y_axis_title <- NULL
    x_axis_title <- NULL

    if (shape_index == 1L) {
      y_axis_title <- paste0(row_label, "\nAxis 2")
    }

    if (row_index == length(representative_rows)) {
      x_axis_title <- "Axis 1"
    }

    panel_plot <- panel_plot +
      coord_fixed(
        ratio = 1,
        xlim = limits$x,
        ylim = limits$y,
        expand = FALSE,
        clip = "on"
      ) +
      labs(
        title = if (row_index == 1L) master_object$shape_label else NULL,
        x = x_axis_title,
        y = y_axis_title
      ) +
      theme_bw(base_size = 6.4) +
      theme(
        panel.grid = element_blank(),
        panel.border = element_rect(linewidth = 0.28),
        plot.title = element_text(
          size = 7.2,
          face = "bold",
          hjust = 0.5,
          margin = margin(b = 2)
        ),
        axis.title = element_text(size = 6.2),
        axis.text = element_text(size = 5.2),
        axis.ticks = element_line(linewidth = 0.25),
        plot.margin = margin(1.5, 1.5, 1.5, 1.5)
      )

    if (shape_index > 1L) {
      panel_plot <- panel_plot +
        theme(
          axis.text.y = element_blank(),
          axis.ticks.y = element_blank()
        )
    }

    if (row_index < length(representative_rows)) {
      panel_plot <- panel_plot +
        theme(
          axis.text.x = element_blank(),
          axis.ticks.x = element_blank()
        )
    }

    plot_counter <- plot_counter + 1L
    representative_plots[[plot_counter]] <- panel_plot
  }
}

panel_a <- wrap_plots(
  representative_plots,
  ncol = length(expected_shape_names),
  byrow = TRUE
) +
  plot_annotation(
    title = paste0(
      "a   Representative geometrical recovery (n = ",
      representative_sample_size,
      ")"
    ),
    theme = theme(
      plot.title = element_text(
        size = 9,
        face = "bold",
        hjust = 0
      )
    )
  )

# Freeze the annotated multi-panel object before nesting it inside the
# complete figure so that its panel title is retained by patchwork.
panel_a_for_composite <- patchwork::wrap_elements(full = panel_a)

# ============================================================
# Construct Figure 2b: signed relative area error
# ============================================================

plot_data <- successful_geometry
plot_data$Method <- factor(plot_data$Method, levels = method_order)
plot_data$Shape <- factor(
  plot_data$Shape,
  levels = vapply(
    expected_shape_names,
    function(shape_name) {
      occurrence_archive$master_datasets[[shape_name]]$shape_label
    },
    character(1)
  )
)

panel_b <- ggplot(
  plot_data,
  aes(
    x = Sample_size,
    y = Relative_area_error_percent,
    colour = Method,
    shape = Method,
    group = Method
  )
) +
  geom_hline(
    yintercept = 0,
    linewidth = 0.3,
    linetype = "dashed",
    colour = "grey35"
  ) +
  geom_line(linewidth = 0.55) +
  geom_point(size = 1.65, stroke = 0.25) +
  facet_wrap(
    ~Shape,
    nrow = 1,
    scales = "free_y"
  ) +
  scale_colour_manual(values = method_colours) +
  scale_shape_manual(values = method_shapes) +
  scale_x_continuous(
    breaks = expected_sample_sizes,
    labels = expected_sample_sizes
  ) +
  labs(
    title = "b   Relative area error",
    x = "Number of occurrence points",
    y = "Signed relative area error (%)",
    colour = NULL,
    shape = NULL
  ) +
  theme_bw(base_size = 7.2) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    strip.background = element_rect(
      fill = "grey94",
      linewidth = 0.3
    ),
    strip.text = element_text(size = 6.8, face = "bold"),
    plot.title = element_text(size = 9, face = "bold", hjust = 0),
    axis.title = element_text(size = 7),
    axis.text = element_text(size = 6),
    legend.text = element_text(size = 6.5),
    legend.key.width = grid::unit(10, "pt"),
    plot.margin = margin(3, 3, 3, 3)
  )

# ============================================================
# Construct Figure 2c: Jaccard similarity
# ============================================================

panel_c <- ggplot(
  plot_data,
  aes(
    x = Sample_size,
    y = Jaccard_similarity,
    colour = Method,
    shape = Method,
    group = Method
  )
) +
  geom_line(linewidth = 0.55) +
  geom_point(size = 1.65, stroke = 0.25) +
  facet_wrap(
    ~Shape,
    nrow = 1
  ) +
  scale_colour_manual(values = method_colours) +
  scale_shape_manual(values = method_shapes) +
  scale_x_continuous(
    breaks = expected_sample_sizes,
    labels = expected_sample_sizes
  ) +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.25),
    expand = expansion(mult = c(0.01, 0.03))
  ) +
  labs(
    title = "c   Jaccard similarity to the known niche",
    x = "Number of occurrence points",
    y = "Jaccard similarity",
    colour = NULL,
    shape = NULL
  ) +
  theme_bw(base_size = 7.2) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    strip.background = element_rect(
      fill = "grey94",
      linewidth = 0.3
    ),
    strip.text = element_text(size = 6.8, face = "bold"),
    plot.title = element_text(size = 9, face = "bold", hjust = 0),
    axis.title = element_text(size = 7),
    axis.text = element_text(size = 6),
    legend.text = element_text(size = 6.5),
    legend.key.width = grid::unit(10, "pt"),
    plot.margin = margin(3, 3, 3, 3)
  )

# ============================================================
# Supplementary centroid-displacement figure
# ============================================================

centroid_plot <- ggplot(
  plot_data,
  aes(
    x = Sample_size,
    y = Centroid_displacement,
    colour = Method,
    shape = Method,
    group = Method
  )
) +
  geom_line(linewidth = 0.65) +
  geom_point(size = 2) +
  facet_wrap(~Shape, nrow = 1, scales = "free_y") +
  scale_colour_manual(values = method_colours) +
  scale_shape_manual(values = method_shapes) +
  scale_x_continuous(
    breaks = expected_sample_sizes,
    labels = expected_sample_sizes
  ) +
  labs(
    x = "Number of occurrence points",
    y = "Centroid displacement",
    colour = NULL,
    shape = NULL
  ) +
  theme_bw(base_size = 8) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    strip.background = element_rect(fill = "grey94"),
    strip.text = element_text(face = "bold"),
    legend.position = "bottom"
  )

# ============================================================
# Combine and save publication-ready Figure 2
# ============================================================

figure_2 <- (
  panel_a_for_composite /
    panel_b /
    panel_c
) +
  plot_layout(
    heights = c(4.7, 1.35, 1.35),
    guides = "collect"
  ) &
  theme(
    legend.position = "bottom",
    legend.box = "horizontal"
  )

ggsave(
  filename = panel_a_pdf,
  plot = panel_a,
  width = figure_width_inches,
  height = 6.55,
  units = "in",
  device = cairo_pdf
)

ggsave(
  filename = panel_b_pdf,
  plot = panel_b,
  width = figure_width_inches,
  height = 2.25,
  units = "in",
  device = cairo_pdf
)

ggsave(
  filename = panel_c_pdf,
  plot = panel_c,
  width = figure_width_inches,
  height = 2.25,
  units = "in",
  device = cairo_pdf
)

ggsave(
  filename = centroid_pdf,
  plot = centroid_plot,
  width = figure_width_inches,
  height = 2.5,
  units = "in",
  device = cairo_pdf
)

ggsave(
  filename = figure_2_pdf,
  plot = figure_2,
  width = figure_width_inches,
  height = figure_height_inches,
  units = "in",
  device = cairo_pdf
)

ggsave(
  filename = figure_2_tiff,
  plot = figure_2,
  width = figure_width_inches,
  height = figure_height_inches,
  units = "in",
  dpi = figure_tiff_dpi,
  device = "tiff",
  compression = "lzw"
)

ggsave(
  filename = figure_2_png,
  plot = figure_2,
  width = figure_width_inches,
  height = figure_height_inches,
  units = "in",
  dpi = 300,
  device = "png"
)

# ============================================================
# Save analysis notes and session information
# ============================================================

writeLines(
  c(
    "Script 02: Revised 2D synthetic geometrical analysis",
    "===================================================",
    "",
    "Inputs:",
    paste0(
      "  Locked occurrence archive: ",
      normalizePath(occurrence_archive_file, mustWork = FALSE)
    ),
    paste0(
      "  Revised baseline fits: ",
      normalizePath(baseline_results_file, mustWork = FALSE)
    ),
    "",
    "Estimator baseline:",
    paste0(
      "  QPH bandwidth: ",
      expected_qph_bandwidth_method
    ),
    paste0(
      "  QPH potential quantile: ",
      expected_qph_q
    ),
    paste0(
      "  Gaussian KDE probability quantile: ",
      expected_kde_probability_quantile
    ),
    paste0(
      "  SVM nu/gamma/scale.factor: ",
      expected_svm_nu,
      " / ",
      expected_svm_gamma,
      " / ",
      expected_svm_scale_factor
    ),
    "",
    "Analysis design:",
    paste0(
      "  True-region reference points per shape: ",
      true_reference_points_per_shape
    ),
    paste0(
      "  Maximum points used by each set operation: ",
      jaccard_num_points_max
    ),
    paste0(
      "  Set-operation distance factor: ",
      jaccard_distance_factor
    ),
    "  Jaccard similarity was calculated using hypervolume_set() and",
    "  hypervolume_overlap_statistics() against a uniformly sampled",
    "  Hypervolume representation of the analytically known region.",
    "  Sorensen similarity was calculated algebraically from the same",
    "  Jaccard comparison as 2J/(1+J).",
    "  True-region coverage is intersection area divided by exact true area.",
    "  Excess estimated area is estimated area minus intersection area.",
    "  Exact analytical areas, rather than reference-cloud area estimates,",
    "  were used as true areas.",
    "  True centroids were estimated once from the fixed 100,000-point",
    "  reference clouds and then reused for every method and sample size.",
    "",
    "True-region references:",
    paste0(
      "  Reference archive: ",
      normalizePath(true_reference_file, mustWork = FALSE)
    ),
    "  The original reference archive was reused when compatible because",
    "  it is independent of the QPH bandwidth/threshold revision.",
    "",
    "Figure 2:",
    paste0(
      "  Representative sample size in Panel a: n = ",
      representative_sample_size
    ),
    paste0(
      "  Raster grid resolution per panel: ",
      figure_grid_resolution,
      " x ",
      figure_grid_resolution
    ),
    paste0(
      "  Maximum hypervolume points used for raster display: ",
      figure_hypervolume_points_max
    ),
    "  Raster inclusion was used for visualisation only and does not",
    "  affect any area, overlap, or centroid result.",
    "",
    paste0("Completed: ", Sys.time())
  ),
  con = analysis_notes_file
)

capture.output(
  sessionInfo(),
  file = session_information_file
)

# ============================================================
# Completion messages
# ============================================================

message("Script 02 complete.")
message(
  "Geometry summary: ",
  normalizePath(geometry_summary_file, mustWork = FALSE)
)
message(
  "Full geometry results: ",
  normalizePath(geometry_results_file, mustWork = FALSE)
)
message(
  "True-region references: ",
  normalizePath(true_reference_file, mustWork = FALSE)
)
message(
  "Paper Figure 2 PDF: ",
  normalizePath(figure_2_pdf, mustWork = FALSE)
)
message(
  "Paper Figure 2 TIFF: ",
  normalizePath(figure_2_tiff, mustWork = FALSE)
)
message(
  "Paper Figure 2 PNG: ",
  normalizePath(figure_2_png, mustWork = FALSE)
)
message(
  "Centroid supplementary figure: ",
  normalizePath(centroid_pdf, mustWork = FALSE)
)
