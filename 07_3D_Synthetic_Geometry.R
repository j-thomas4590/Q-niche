# ============================================================
# 07_3D_Synthetic_Geometry.R
# ============================================================
#
# Complete baseline geometry analysis for the FINAL revised
# three-dimensional synthetic benchmark.
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

locked_input_directory <- file.path(
  analysis_root_directory,
  "00_Locked_Inputs"
)

baseline_output_directory <- file.path(
  analysis_root_directory,
  "01_Baseline_Fits"
)

output_directory <- file.path(
  analysis_root_directory,
  "02_Geometry"
)

dir.create(
  output_directory,
  recursive = TRUE,
  showWarnings = FALSE
)


# ============================================================
# Required package
# ============================================================

if (!requireNamespace(
  "hypervolume",
  quietly = TRUE
)) {
  stop(
    "Install package 'hypervolume' before running Script 07."
  )
}

library(hypervolume)


# ============================================================
# Locked analysis settings
# ============================================================

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

sample_sizes <- c(
  300L,
  900L,
  1500L
)

# Keep this order because it is part of the original deterministic
# set-operation seed sequence.
method_order <- c(
  "QPH",
  "Gaussian KDE",
  "SVM"
)

reference_points_per_shape <- 100000L
reference_seed_base <- 130123L

jaccard_num_points_max <- 10000L
jaccard_distance_factor <- 1

set_seed_base <- 220001L

resume_from_checkpoint <- TRUE
retry_failed_overlap <- TRUE

# Expected revised baseline definitions.
expected_qph_core_version <- "sqrtNB_q099_v1"
expected_qph_q <- 0.99
expected_kde_quantile <- 0.95
expected_svm_nu <- 0.01
expected_svm_gamma <- 0.50
expected_svm_scale_factor <- 1
expected_samples_per_point <- 100L
expected_sd_count <- 3

# Locked colours.
method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)

true_region_colour <- "#D9D9D9"
occurrence_colour <- "#111111"


# ============================================================
# Analytical truth definitions
# ============================================================

true_volume <- function(shape_name) {

  switch(
    shape_name,
    solid_ball = 4 / 3 * pi * 5^3,
    solid_torus = 2 * pi^2 * 4 * 1.5^2,
    hollow_shell = 4 / 3 * pi * (
      5^3 -
        2.5^3
    ),
    stop(
      "Unknown shape: ",
      shape_name
    )
  )
}


true_centroid <- function(shape_name) {

  if (!shape_name %in% shape_order) {
    stop(
      "Unknown shape: ",
      shape_name
    )
  }

  c(
    X1 = 0,
    X2 = 0,
    X3 = 0
  )
}


# ============================================================
# Input/output files
# ============================================================

baseline_results_file <- file.path(
  baseline_output_directory,
  "baseline_fit_results_3D_sqrtNB_q099.rds"
)

legacy_reference_file <- paste0(
  "C:/Users/r02jt24/Desktop/Quantum Paper/",
  "Sythetic Results/qph_3d_topology_extension/",
  "20_complete_3D_geometry_overlap_metrics/",
  "synthetic_3d_true_region_reference_clouds.rds"
)

reference_file <- file.path(
  locked_input_directory,
  "synthetic_3d_true_region_reference_clouds.rds"
)

reference_manifest_file <- file.path(
  locked_input_directory,
  "synthetic_3d_true_region_reference_manifest.csv"
)

reference_source_file <- file.path(
  locked_input_directory,
  "LOCKED_TRUE_REGION_REFERENCE_SOURCE_3D.txt"
)

checkpoint_file <- file.path(
  output_directory,
  "geometry_checkpoint_3D_sqrtNB_q099.rds"
)

geometry_results_file <- file.path(
  output_directory,
  "synthetic_geometry_results_3D_sqrtNB_q099.rds"
)

geometry_summary_file <- file.path(
  output_directory,
  "synthetic_geometry_summary_3D_sqrtNB_q099.csv"
)

geometry_overlap_diagnostic_file <- file.path(
  output_directory,
  "synthetic_geometry_overlap_diagnostics_3D_sqrtNB_q099.csv"
)

failure_file <- file.path(
  output_directory,
  "synthetic_geometry_failures_3D_sqrtNB_q099.csv"
)

run_metadata_file <- file.path(
  output_directory,
  "geometry_run_metadata_3D_sqrtNB_q099.rds"
)

notes_file <- file.path(
  output_directory,
  "GEOMETRY_ANALYSIS_NOTES_3D_sqrtNB_q099.txt"
)

session_information_file <- file.path(
  output_directory,
  "geometry_session_information_3D_sqrtNB_q099.txt"
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
    pattern = "3d_geometry_hash_",
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
      "Object is not a Hypervolume."
    )
  }

  if (!identical(
    as.integer(
      hv@Dimensionality
    ),
    3L
  )) {
    stop(
      "Hypervolume is not three-dimensional."
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


safe_ratio <- function(
    numerator,
    denominator
) {

  if (
    !is.finite(
      numerator
    ) ||
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


# ============================================================
# Load and verify the revised Script 06 baseline object
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

if (!identical(
  as.integer(
    baseline_metadata$dimensionality
  ),
  3L
)) {
  stop(
    "The Script 06 baseline object is not three-dimensional."
  )
}

if (!isTRUE(all.equal(
  as.numeric(
    baseline_metadata$qph_q
  ),
  expected_qph_q
))) {
  stop(
    "The Script 06 baseline object does not record QPH q = 0.99."
  )
}

if (!isTRUE(all.equal(
  as.numeric(
    baseline_metadata$kde_probability_quantile
  ),
  expected_kde_quantile
))) {
  stop(
    "The Script 06 baseline object does not record KDE quantile = 0.95."
  )
}

if (!isTRUE(all.equal(
  as.numeric(
    baseline_metadata$svm_nu
  ),
  expected_svm_nu
))) {
  stop(
    "The Script 06 baseline object does not record SVM nu = 0.01."
  )
}

if (!isTRUE(all.equal(
  as.numeric(
    baseline_metadata$svm_gamma
  ),
  expected_svm_gamma
))) {
  stop(
    "The Script 06 baseline object does not record SVM gamma = 0.50."
  )
}

if (!isTRUE(all.equal(
  as.numeric(
    baseline_metadata$svm_scale_factor
  ),
  expected_svm_scale_factor
))) {
  stop(
    "The Script 06 baseline object does not record SVM scale.factor = 1."
  )
}


# ============================================================
# Validate every baseline scenario before geometry
# ============================================================

expected_scenario_names <- as.vector(
  outer(
    shape_order,
    sample_sizes,
    FUN = function(
        shape_name,
        sample_size
    ) {
      scenario_name_for(
        shape_name,
        sample_size
      )
    }
  )
)

if (!all(
  expected_scenario_names %in%
    names(
      baseline_scenarios
    )
)) {
  stop(
    "The Script 06 baseline object is missing one or more expected 3D ",
    "shape x sample-size scenarios."
  )
}

for (shape_name in shape_order) {

  shape_subsets <- occurrence_archive$occurrence_subsets[[
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

    scenario_name <- scenario_name_for(
      shape_name,
      current_sample_size
    )

    scenario <- baseline_scenarios[[
      scenario_name
    ]]

    if (!identical(
      as.character(
        scenario$shape_name
      ),
      shape_name
    )) {
      stop(
        "Shape-code mismatch in baseline scenario ",
        scenario_name,
        "."
      )
    }

    if (!identical(
      as.integer(
        scenario$sample_size
      ),
      as.integer(
        current_sample_size
      )
    )) {
      stop(
        "Sample-size mismatch in baseline scenario ",
        scenario_name,
        "."
      )
    }

    exact_true_volume <- true_volume(
      shape_name
    )

    if (!isTRUE(all.equal(
      as.numeric(
        scenario$true_volume
      ),
      exact_true_volume,
      tolerance = 1e-12
    ))) {
      stop(
        "True-volume mismatch in baseline scenario ",
        scenario_name,
        "."
      )
    }

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
        scenario_name,
        "."
      )
    }

    occurrence_points <- set_axis_names(
      subset_object$points
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
        "Occurrence count mismatch for ",
        scenario_name,
        "."
      )
    }

    # --------------------------------------------------------
    # Revised QPH audit
    # --------------------------------------------------------

    qph_result <- scenario$qph

    if (
      !is.null(
        qph_result
      ) &&
        isTRUE(
          qph_result$success
        )
    ) {

      qph_audit <- qph_result$audit

      expected_k <- as.integer(
        round(
          sqrt(
            current_sample_size
          )
        )
      )

      if (!identical(
        as.integer(
          qph_audit$K
        ),
        expected_k
      )) {
        stop(
          "Unexpected QPH K in ",
          scenario_name,
          "."
        )
      }

      if (!isTRUE(all.equal(
        as.numeric(
          qph_audit$baseline_scalar_h
        ),
        sqrt(
          mean(
            qph_audit$local_s
          )
        ),
        tolerance = 1e-12
      ))) {
        stop(
          "QPH h != sqrt(mean(local_s)) in ",
          scenario_name,
          "."
        )
      }

      if (!isTRUE(all.equal(
        as.numeric(
          qph_audit$fitted_bandwidth
        ),
        rep(
          qph_audit$baseline_scalar_h,
          3L
        ),
        tolerance = 1e-12
      ))) {
        stop(
          "QPH bandwidth is not the locked isotropic sqrt-NB bandwidth in ",
          scenario_name,
          "."
        )
      }

      if (!isTRUE(all.equal(
        as.numeric(
          qph_audit$q
        ),
        expected_qph_q
      ))) {
        stop(
          "QPH q is not 0.99 in ",
          scenario_name,
          "."
        )
      }

      if (!identical(
        as.integer(
          qph_audit$samples_per_point
        ),
        expected_samples_per_point
      )) {
        stop(
          "QPH samples.per.point mismatch in ",
          scenario_name,
          "."
        )
      }

      if (!isTRUE(all.equal(
        as.numeric(
          qph_audit$sd_count
        ),
        as.numeric(
          expected_sd_count
        )
      ))) {
        stop(
          "QPH sd.count mismatch in ",
          scenario_name,
          "."
        )
      }

      standardise_hv(
        qph_result$hypervolume
      )
    }

    # --------------------------------------------------------
    # KDE audit
    # --------------------------------------------------------

    kde_result <- scenario$gaussian_kde

    if (
      !is.null(
        kde_result
      ) &&
        isTRUE(
          kde_result$success
        )
    ) {

      if (!isTRUE(all.equal(
        as.numeric(
          kde_result$probability_quantile
        ),
        expected_kde_quantile
      ))) {
        stop(
          "KDE probability quantile mismatch in ",
          scenario_name,
          "."
        )
      }

      if (length(
        kde_result$bandwidth
      ) != 3L) {
        stop(
          "KDE bandwidth does not contain three components in ",
          scenario_name,
          "."
        )
      }

      standardise_hv(
        kde_result$hypervolume
      )
    }

    # --------------------------------------------------------
    # SVM audit
    # --------------------------------------------------------

    svm_result <- scenario$svm

    if (
      !is.null(
        svm_result
      ) &&
        isTRUE(
          svm_result$success
        )
    ) {

      hv_svm <- standardise_hv(
        svm_result$hypervolume
      )

      if (!isTRUE(all.equal(
        as.numeric(
          hv_svm@Parameters$svm.nu
        ),
        expected_svm_nu
      ))) {
        stop(
          "SVM nu mismatch in ",
          scenario_name,
          "."
        )
      }

      if (!isTRUE(all.equal(
        as.numeric(
          hv_svm@Parameters$svm.gamma
        ),
        expected_svm_gamma
      ))) {
        stop(
          "SVM gamma mismatch in ",
          scenario_name,
          "."
        )
      }

      if (!identical(
        as.integer(
          hv_svm@Parameters$samples.per.point
        ),
        expected_samples_per_point
      )) {
        stop(
          "SVM samples.per.point mismatch in ",
          scenario_name,
          "."
        )
      }
    }
  }
}

message(
  "Verified revised Script 06 baseline object and all available fitted models."
)


# ============================================================
# Uniform samplers for the analytically known 3D regions
# ============================================================
#
# These reproduce the original fixed true-region reference design exactly.
# ============================================================

generate_unit_directions <- function(n) {

  directions <- matrix(
    stats::rnorm(
      n * 3L
    ),
    nrow = n,
    ncol = 3L
  )

  norms <- sqrt(
    rowSums(
      directions^2
    )
  )

  while (any(
    norms == 0
  )) {

    bad <- which(
      norms == 0
    )

    directions[
      bad,
    ] <- matrix(
      stats::rnorm(
        length(
          bad
        ) * 3L
      ),
      nrow = length(
        bad
      ),
      ncol = 3L
    )

    norms <- sqrt(
      rowSums(
        directions^2
      )
    )
  }

  directions /
    norms
}


generate_ball <- function(
    n,
    seed
) {

  set.seed(
    seed
  )

  directions <- generate_unit_directions(
    n
  )

  radii <- 5 *
    stats::runif(
      n
    )^(1 / 3)

  set_axis_names(
    directions *
      radii
  )
}


generate_shell <- function(
    n,
    seed
) {

  set.seed(
    seed
  )

  directions <- generate_unit_directions(
    n
  )

  u <- stats::runif(
    n
  )

  radii <- (
    2.5^3 +
      u * (
        5^3 -
          2.5^3
      )
  )^(1 / 3)

  set_axis_names(
    directions *
      radii
  )
}


generate_torus <- function(
    n,
    seed
) {

  set.seed(
    seed
  )

  major_radius <- 4
  minor_radius <- 1.5

  accepted <- matrix(
    numeric(0),
    ncol = 3L
  )

  batch_size <- max(
    2000L,
    ceiling(
      n * 2.5
    )
  )

  while (nrow(
    accepted
  ) < n) {

    x <- stats::runif(
      batch_size,
      min = -(
        major_radius +
          minor_radius
      ),
      max = major_radius +
        minor_radius
    )

    y <- stats::runif(
      batch_size,
      min = -(
        major_radius +
          minor_radius
      ),
      max = major_radius +
        minor_radius
    )

    z <- stats::runif(
      batch_size,
      min = -minor_radius,
      max = minor_radius
    )

    inside <- (
      (
        sqrt(
          x^2 +
            y^2
        ) -
          major_radius
      )^2 +
        z^2 <=
        minor_radius^2
    )

    if (any(
      inside
    )) {
      accepted <- rbind(
        accepted,
        cbind(
          x[
            inside
          ],
          y[
            inside
          ],
          z[
            inside
          ]
        )
      )
    }
  }

  set_axis_names(
    accepted[
      seq_len(
        n
      ),
      ,
      drop = FALSE
    ]
  )
}


sample_true_region <- function(
    shape_name,
    n,
    seed
) {

  switch(
    shape_name,
    solid_ball = generate_ball(
      n,
      seed
    ),
    solid_torus = generate_torus(
      n,
      seed
    ),
    hollow_shell = generate_shell(
      n,
      seed
    ),
    stop(
      "Unknown shape: ",
      shape_name
    )
  )
}


create_true_hv <- function(
    points,
    volume,
    label
) {

  points <- set_axis_names(
    points
  )

  data_for_slot <- points[
    seq_len(
      min(
        1500L,
        nrow(
          points
        )
      )
    ),
    ,
    drop = FALSE
  ]

  hv <- methods::new(
    "Hypervolume",
    Name = paste0(
      "Known true region: ",
      label
    ),
    Method = "Known synthetic region",
    Data = data_for_slot,
    Dimensionality = as.numeric(
      3
    ),
    Volume = as.numeric(
      volume
    ),
    PointDensity = as.numeric(
      nrow(
        points
      ) /
        volume
    ),
    Parameters = list(
      exact.volume = volume,
      reference.points = nrow(
        points
      ),
      representation = "Uniform reference cloud from known 3D region"
    ),
    RandomPoints = points,
    ValueAtRandomPoints = rep(
      1 /
        volume,
      nrow(
        points
      )
    )
  )

  standardise_hv(
    hv
  )
}


# ============================================================
# Build/copy/load fixed true-region reference archive
# ============================================================

reference_signature <- paste(
  paste(
    shape_order,
    collapse = ","
  ),
  reference_points_per_shape,
  reference_seed_base,
  paste(
    vapply(
      shape_order,
      true_volume,
      numeric(1)
    ),
    collapse = ","
  ),
  sep = "|"
)

reference_source <- NA_character_

if (!file.exists(
  reference_file
)) {

  if (file.exists(
    legacy_reference_file
  )) {

    copied_successfully <- file.copy(
      from = legacy_reference_file,
      to = reference_file,
      overwrite = FALSE,
      copy.mode = TRUE,
      copy.date = TRUE
    )

    if (!isTRUE(
      copied_successfully
    )) {
      stop(
        "Failed to copy the legacy fixed 3D true-region reference archive."
      )
    }

    reference_source <- "Copied byte-for-byte from legacy QPH-independent reference archive"

    message(
      "Copied legacy fixed 3D true-region reference archive."
    )

  } else {

    message(
      "Legacy 3D true-reference archive unavailable. Deterministically ",
      "recreating the original fixed references from the same generators ",
      "and seeds..."
    )

    references <- list()

    for (
      shape_index in seq_along(
        shape_order
      )
    ) {

      shape_name <- shape_order[[
        shape_index
      ]]

      reference_seed <- as.integer(
        reference_seed_base +
          shape_index
      )

      reference_points <- sample_true_region(
        shape_name = shape_name,
        n = reference_points_per_shape,
        seed = reference_seed
      )

      exact_true_volume <- true_volume(
        shape_name
      )

      true_hv <- create_true_hv(
        points = reference_points,
        volume = exact_true_volume,
        label = unname(
          shape_labels[[
            shape_name
          ]]
        )
      )

      references[[shape_name]] <- list(
        shape = shape_name,
        label = unname(
          shape_labels[[
            shape_name
          ]]
        ),
        seed = reference_seed,
        points = reference_points,
        hypervolume = true_hv,
        exact_true_volume = exact_true_volume,
        centroid = colMeans(
          reference_points
        ),
        analytical_centroid = true_centroid(
          shape_name
        )
      )
    }

    reference_archive <- list(
      signature = reference_signature,
      references = references,
      created_at = as.character(
        Sys.time()
      ),
      source = "Deterministically recreated from original fixed-reference design"
    )

    saveRDS(
      reference_archive,
      reference_file,
      version = 3
    )

    reference_source <- "Deterministically recreated from original fixed-reference design"
  }
}


reference_archive <- readRDS(
  reference_file
)

if (
  !is.list(
    reference_archive
  ) ||
    is.null(
      reference_archive$signature
    ) ||
    is.null(
      reference_archive$references
    )
) {
  stop(
    "The fixed 3D true-reference archive has an unexpected structure."
  )
}

if (!identical(
  reference_archive$signature,
  reference_signature
)) {
  stop(
    "The fixed 3D true-reference archive uses different settings."
  )
}

references <- reference_archive$references

if (!all(
  shape_order %in%
    names(
      references
    )
)) {
  stop(
    "The fixed true-reference archive is missing one or more 3D shapes."
  )
}


# ============================================================
# Validate and normalise fixed references
# ============================================================

reference_manifest_rows <- list()

for (
  shape_index in seq_along(
    shape_order
  )
) {

  shape_name <- shape_order[[
    shape_index
  ]]

  reference <- references[[
    shape_name
  ]]

  reference_points <- set_axis_names(
    reference$points
  )

  reference_hv <- standardise_hv(
    reference$hypervolume
  )

  expected_seed <- as.integer(
    reference_seed_base +
      shape_index
  )

  exact_true_volume <- true_volume(
    shape_name
  )

  if (!identical(
    nrow(
      reference_points
    ),
    reference_points_per_shape
  )) {
    stop(
      "Fixed true-reference cloud for ",
      shape_name,
      " does not contain exactly ",
      reference_points_per_shape,
      " points."
    )
  }

  if (!identical(
    as.integer(
      reference$seed
    ),
    expected_seed
  )) {
    stop(
      "Unexpected fixed-reference seed for ",
      shape_name,
      "."
    )
  }

  if (!isTRUE(all.equal(
    as.numeric(
      reference$exact_true_volume
    ),
    exact_true_volume,
    tolerance = 1e-12
  ))) {
    stop(
      "Exact true-volume mismatch in fixed reference for ",
      shape_name,
      "."
    )
  }

  if (!isTRUE(all.equal(
    as.numeric(
      reference_hv@Volume
    ),
    exact_true_volume,
    tolerance = 1e-12
  ))) {
    stop(
      "True-reference Hypervolume does not store the exact analytical ",
      "volume for ",
      shape_name,
      "."
    )
  }

  if (!identical(
    nrow(
      reference_hv@RandomPoints
    ),
    reference_points_per_shape
  )) {
    stop(
      "True-reference Hypervolume has an unexpected random-point count for ",
      shape_name,
      "."
    )
  }

  # Normalise the archive in memory without changing its identity on disk.
  reference$points <- reference_points
  reference$hypervolume <- reference_hv
  reference$centroid <- colMeans(
    reference_points
  )
  reference$analytical_centroid <- true_centroid(
    shape_name
  )
  reference$label <- unname(
    shape_labels[[
      shape_name
    ]]
  )

  references[[shape_name]] <- reference

  reference_manifest_rows[[shape_index]] <- data.frame(
    Shape_code = shape_name,
    Shape = unname(
      shape_labels[[
        shape_name
      ]]
    ),
    Reference_seed = expected_seed,
    Reference_points = reference_points_per_shape,
    Exact_true_volume = exact_true_volume,
    Reference_point_density = reference_hv@PointDensity,
    Reference_centroid_X1 = reference$centroid[[
      1L
    ]],
    Reference_centroid_X2 = reference$centroid[[
      2L
    ]],
    Reference_centroid_X3 = reference$centroid[[
      3L
    ]],
    Analytical_centroid_X1 = 0,
    Analytical_centroid_X2 = 0,
    Analytical_centroid_X3 = 0,
    stringsAsFactors = FALSE
  )
}

reference_manifest <- do.call(
  rbind,
  reference_manifest_rows
)

rownames(
  reference_manifest
) <- NULL

write_csv_safely(
  reference_manifest,
  reference_manifest_file
)

reference_file_md5 <- safe_md5(
  reference_file
)

legacy_reference_md5 <- safe_md5(
  legacy_reference_file
)

if (
  file.exists(
    legacy_reference_file
  ) &&
    !identical(
      reference_file_md5,
      legacy_reference_md5
    )
) {
  stop(
    "The new locked true-reference archive does not have the same MD5 ",
    "checksum as the available legacy authoritative archive."
  )
}

if (is.na(
  reference_source
)) {

  if (
    file.exists(
      legacy_reference_file
    ) &&
      identical(
        reference_file_md5,
        legacy_reference_md5
      )
  ) {
    reference_source <- "Existing locked copy identical to legacy QPH-independent reference archive"
  } else {
    reference_source <- if (!is.null(
      reference_archive$source
    )) {
      as.character(
        reference_archive$source
      )
    } else {
      "Existing validated fixed-reference archive"
    }
  }
}

writeLines(
  c(
    "Locked 3D true-region reference archive",
    "=======================================",
    "",
    paste0(
      "Reference source: ",
      reference_source
    ),
    paste0(
      "Locked reference file: ",
      reference_file
    ),
    paste0(
      "Locked reference MD5: ",
      reference_file_md5
    ),
    paste0(
      "Legacy reference file: ",
      legacy_reference_file
    ),
    paste0(
      "Legacy reference exists: ",
      file.exists(
        legacy_reference_file
      )
    ),
    paste0(
      "Legacy reference MD5: ",
      legacy_reference_md5
    ),
    "",
    paste0(
      "Points per shape: ",
      reference_points_per_shape
    ),
    paste0(
      "Reference seed base: ",
      reference_seed_base
    ),
    "",
    "These true-region references are independent of the QPH bandwidth definition."
  ),
  reference_source_file
)

message(
  "Verified fixed 100,000-point true-region references."
)


# ============================================================
# hypervolume_set component helper
# ============================================================

component_volume <- function(
    hv_set,
    candidates,
    required = FALSE
) {

  available <- names(
    hv_set@HVList
  )

  component_index <- match(
    tolower(
      candidates
    ),
    tolower(
      available
    ),
    nomatch = 0L
  )

  component_index <- component_index[
    component_index > 0L
  ]

  if (length(
    component_index
  ) == 0L) {

    if (required) {
      stop(
        "Missing HypervolumeSet component. Wanted one of: ",
        paste(
          candidates,
          collapse = ", "
        ),
        "; available: ",
        paste(
          available,
          collapse = ", "
        )
      )
    }

    return(
      NA_real_
    )
  }

  component_object <- hv_set@HVList[[
    component_index[[
      1L
    ]]
  ]]

  if (!methods::is(
    component_object,
    "Hypervolume"
  )) {

    if (required) {
      stop(
        "Requested HypervolumeSet component is not a Hypervolume object."
      )
    }

    return(
      NA_real_
    )
  }

  as.numeric(
    component_object@Volume
  )
}


# ============================================================
# Calculate all geometry metrics for one fitted hypervolume
# ============================================================

calculate_geometry_metrics <- function(
    estimated_hv,
    occurrence_points,
    reference,
    shape_name,
    set_seed
) {

  estimated_hv <- standardise_hv(
    estimated_hv
  )

  occurrence_points <- set_axis_names(
    occurrence_points
  )

  true_hv <- standardise_hv(
    reference$hypervolume
  )

  exact_true_volume <- as.numeric(
    reference$exact_true_volume
  )

  estimated_volume <- as.numeric(
    estimated_hv@Volume
  )

  if (
    !is.finite(
      estimated_volume
    ) ||
      estimated_volume <= 0
  ) {
    stop(
      "Estimated hypervolume is not positive and finite."
    )
  }

  estimated_centroid <- colMeans(
    set_axis_names(
      estimated_hv@RandomPoints
    )
  )

  reference_centroid <- as.numeric(
    reference$centroid
  )

  analytical_centroid <- as.numeric(
    true_centroid(
      shape_name
    )
  )

  occurrence_centroid <- colMeans(
    occurrence_points
  )

  centroid_displacement_reference <- sqrt(
    sum(
      (
        estimated_centroid -
          reference_centroid
      )^2
    )
  )

  centroid_displacement_analytical <- sqrt(
    sum(
      (
        estimated_centroid -
          analytical_centroid
      )^2
    )
  )

  centroid_displacement_occurrence <- sqrt(
    sum(
      (
        estimated_centroid -
          occurrence_centroid
      )^2
    )
  )

  signed_volume_error <- (
    estimated_volume -
      exact_true_volume
  )

  relative_volume_error_percent <- (
    100 *
      signed_volume_error /
      exact_true_volume
  )

  set.seed(
    as.integer(
      set_seed
    )
  )

  set_operation_time <- system.time({

    hv_set <- hypervolume::hypervolume_set(
      hv1 = estimated_hv,
      hv2 = true_hv,
      num.points.max = jaccard_num_points_max,
      verbose = FALSE,
      check.memory = FALSE,
      distance.factor = jaccard_distance_factor
    )
  })

  overlap_statistics <- hypervolume::hypervolume_overlap_statistics(
    hv_set
  )

  intersection_volume <- component_volume(
    hv_set,
    "Intersection",
    required = TRUE
  )

  estimated_only_volume <- component_volume(
    hv_set,
    c(
      "Unique_1",
      "Unique 1",
      "Unique1"
    )
  )

  true_only_volume <- component_volume(
    hv_set,
    c(
      "Unique_2",
      "Unique 2",
      "Unique2"
    )
  )

  union_volume_stored <- component_volume(
    hv_set,
    "Union"
  )

  if (
    is.finite(
      estimated_only_volume
    ) &&
      is.finite(
        true_only_volume
      )
  ) {

    set_estimated_volume <- (
      intersection_volume +
        estimated_only_volume
    )

    set_true_volume <- (
      intersection_volume +
        true_only_volume
    )

    set_union_volume <- (
      intersection_volume +
        estimated_only_volume +
        true_only_volume
    )

    decomposition_source <- "Intersection + Unique_1 + Unique_2"

  } else {

    # Compatibility fallback for hypervolume versions that do not expose
    # Unique_1 / Unique_2 explicitly.
    estimated_only_volume <- max(
      estimated_volume -
        intersection_volume,
      0
    )

    true_only_volume <- max(
      exact_true_volume -
        intersection_volume,
      0
    )

    set_estimated_volume <- estimated_volume
    set_true_volume <- exact_true_volume

    set_union_volume <- (
      intersection_volume +
        estimated_only_volume +
        true_only_volume
    )

    decomposition_source <- "Fallback from input volumes and intersection"
  }

  union_volume <- if (is.finite(
    union_volume_stored
  )) {
    union_volume_stored
  } else {
    set_union_volume
  }

  jaccard_from_components <- safe_ratio(
    intersection_volume,
    set_union_volume
  )

  jaccard_from_package <- if (
    "jaccard" %in%
      names(
        overlap_statistics
      )
  ) {
    as.numeric(
      overlap_statistics[[
        "jaccard"
      ]]
    )
  } else {
    NA_real_
  }

  jaccard_similarity <- if (is.finite(
    jaccard_from_package
  )) {
    jaccard_from_package
  } else {
    jaccard_from_components
  }

  sorensen_similarity <- if (
    is.finite(
      jaccard_similarity
    ) &&
      jaccard_similarity >= 0
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

  # ----------------------------------------------------------
  # Primary coverage/excess metrics use the analytically exact
  # true volume so 2D and 3D sensitivity outputs share a common
  # denominator in the final robustness figures.
  # ----------------------------------------------------------

  true_region_coverage <- safe_ratio(
    intersection_volume,
    exact_true_volume
  )

  true_region_coverage_percent <- 100 *
    true_region_coverage

  missed_true_region_volume_exact <- max(
    exact_true_volume -
      intersection_volume,
    0
  )

  missed_true_region_percent_exact <- 100 *
    safe_ratio(
      missed_true_region_volume_exact,
      exact_true_volume
    )

  # Prefer the set-operation Unique_1 component when available because it
  # corresponds to the estimated-only region under the same stochastic set
  # operation used for Jaccard. The fallback above provides a compatible
  # value otherwise.
  excess_estimated_volume <- max(
    estimated_only_volume,
    0
  )

  excess_estimated_volume_percent_of_true <- 100 *
    safe_ratio(
      excess_estimated_volume,
      exact_true_volume
    )

  excess_estimated_fraction <- safe_ratio(
    excess_estimated_volume,
    estimated_volume
  )

  # Retain the previous set-based definitions as explicit diagnostics.
  set_based_true_region_coverage_percent <- 100 *
    safe_ratio(
      intersection_volume,
      set_true_volume
    )

  set_based_missed_true_region_percent <- 100 *
    safe_ratio(
      true_only_volume,
      set_true_volume
    )

  set_based_excess_predicted_percent_of_true <- 100 *
    safe_ratio(
      estimated_only_volume,
      set_true_volume
    )

  set_true_volume_relative_difference_from_exact_percent <- 100 *
    safe_ratio(
      set_true_volume -
        exact_true_volume,
      exact_true_volume
    )

  # safe_ratio() rejects negative numerators. The set-volume difference can
  # legitimately be negative, so calculate this diagnostic directly.
  set_true_volume_relative_difference_from_exact_percent <- if (
    is.finite(
      set_true_volume
    ) &&
      exact_true_volume > 0
  ) {
    100 *
      (
        set_true_volume -
          exact_true_volume
      ) /
      exact_true_volume
  } else {
    NA_real_
  }

  data.frame(
    Exact_true_volume = exact_true_volume,
    Estimated_volume = estimated_volume,
    Signed_volume_error = signed_volume_error,
    Absolute_volume_error = abs(
      signed_volume_error
    ),
    Relative_volume_error_percent = relative_volume_error_percent,
    Absolute_relative_volume_error_percent = abs(
      relative_volume_error_percent
    ),
    Intersection_volume = intersection_volume,
    Estimated_only_volume = estimated_only_volume,
    True_only_volume = true_only_volume,
    Union_volume = union_volume,
    Set_estimated_volume = set_estimated_volume,
    Set_true_volume = set_true_volume,
    Jaccard_similarity = jaccard_similarity,
    Jaccard_from_components = jaccard_from_components,
    Sorensen_similarity = sorensen_similarity,
    True_region_coverage = true_region_coverage,
    True_region_coverage_percent = true_region_coverage_percent,
    Missed_true_region_volume = missed_true_region_volume_exact,
    Missed_true_region_percent = missed_true_region_percent_exact,
    Excess_estimated_volume = excess_estimated_volume,
    Excess_estimated_volume_percent_of_true = (
      excess_estimated_volume_percent_of_true
    ),
    Excess_estimated_fraction = excess_estimated_fraction,
    Set_based_true_region_coverage_percent = (
      set_based_true_region_coverage_percent
    ),
    Set_based_missed_true_region_percent = (
      set_based_missed_true_region_percent
    ),
    Set_based_excess_predicted_percent_of_true = (
      set_based_excess_predicted_percent_of_true
    ),
    Set_true_volume_relative_difference_from_exact_percent = (
      set_true_volume_relative_difference_from_exact_percent
    ),
    Estimated_centroid_X1 = estimated_centroid[[
      1L
    ]],
    Estimated_centroid_X2 = estimated_centroid[[
      2L
    ]],
    Estimated_centroid_X3 = estimated_centroid[[
      3L
    ]],
    Reference_centroid_X1 = reference_centroid[[
      1L
    ]],
    Reference_centroid_X2 = reference_centroid[[
      2L
    ]],
    Reference_centroid_X3 = reference_centroid[[
      3L
    ]],
    Analytical_centroid_X1 = analytical_centroid[[
      1L
    ]],
    Analytical_centroid_X2 = analytical_centroid[[
      2L
    ]],
    Analytical_centroid_X3 = analytical_centroid[[
      3L
    ]],
    Occurrence_centroid_X1 = occurrence_centroid[[
      1L
    ]],
    Occurrence_centroid_X2 = occurrence_centroid[[
      2L
    ]],
    Occurrence_centroid_X3 = occurrence_centroid[[
      3L
    ]],
    Centroid_displacement = centroid_displacement_reference,
    Centroid_displacement_from_reference = (
      centroid_displacement_reference
    ),
    Centroid_displacement_from_analytical_truth = (
      centroid_displacement_analytical
    ),
    Centroid_displacement_from_occurrence = (
      centroid_displacement_occurrence
    ),
    Estimated_random_points = nrow(
      estimated_hv@RandomPoints
    ),
    Set_operation_runtime_seconds = unname(
      set_operation_time[[
        "elapsed"
      ]]
    ),
    Set_operation_seed = as.integer(
      set_seed
    ),
    Jaccard_num_points_max = jaccard_num_points_max,
    Jaccard_distance_factor = jaccard_distance_factor,
    Decomposition_source = decomposition_source,
    stringsAsFactors = FALSE
  )
}


# ============================================================
# Geometry analysis signature
# ============================================================

installed_hypervolume_version <- as.character(
  utils::packageVersion(
    "hypervolume"
  )
)

geometry_settings <- list(
  script = "07_3D_Synthetic_Geometry.R",
  baseline_results_md5 = safe_md5(
    baseline_results_file
  ),
  reference_file_md5 = reference_file_md5,
  reference_signature = reference_signature,
  reference_points_per_shape = reference_points_per_shape,
  reference_seed_base = reference_seed_base,
  shape_order = shape_order,
  sample_sizes = sample_sizes,
  method_order = method_order,
  jaccard_num_points_max = jaccard_num_points_max,
  jaccard_distance_factor = jaccard_distance_factor,
  set_seed_base = set_seed_base,
  expected_qph_q = expected_qph_q,
  expected_kde_quantile = expected_kde_quantile,
  expected_svm_nu = expected_svm_nu,
  expected_svm_gamma = expected_svm_gamma,
  expected_svm_scale_factor = expected_svm_scale_factor,
  hypervolume_version = installed_hypervolume_version,
  method_colours = method_colours,
  true_region_colour = true_region_colour,
  occurrence_colour = occurrence_colour
)

geometry_settings_hash <- hash_r_object(
  geometry_settings
)


# ============================================================
# Initialise/resume restartable geometry checkpoint
# ============================================================

if (
  resume_from_checkpoint &&
    file.exists(
      checkpoint_file
    )
) {

  geometry_checkpoint <- readRDS(
    checkpoint_file
  )

  if (
    !is.list(
      geometry_checkpoint
    ) ||
      !identical(
        geometry_checkpoint$geometry_settings_hash,
        geometry_settings_hash
      )
  ) {
    stop(
      "Existing 3D geometry checkpoint was produced using different ",
      "baseline fits, true-reference clouds, set-operation settings, or ",
      "package versions. Do not mix incompatible runs."
    )
  }

  geometry_results <- geometry_checkpoint$results

  message(
    "Loaded compatible geometry checkpoint containing ",
    length(
      geometry_results
    ),
    " comparison result(s)."
  )

} else {

  geometry_results <- list()
}


save_geometry_checkpoint <- function() {

  saveRDS(
    list(
      geometry_settings_hash = geometry_settings_hash,
      geometry_settings = geometry_settings,
      results = geometry_results,
      last_updated = as.character(
        Sys.time()
      )
    ),
    checkpoint_file,
    version = 3
  )
}


# ============================================================
# Run all 27 baseline geometry comparisons
# ============================================================

comparison_index <- 0L
number_of_comparisons <- (
  length(
    shape_order
  ) *
    length(
      sample_sizes
    ) *
    length(
      method_order
    )
)

for (shape_name in shape_order) {

  shape_subsets <- occurrence_archive$occurrence_subsets[[
    shape_name
  ]]

  reference <- references[[
    shape_name
  ]]

  for (current_sample_size in sample_sizes) {

    scenario_name <- scenario_name_for(
      shape_name,
      current_sample_size
    )

    scenario <- baseline_scenarios[[
      scenario_name
    ]]

    size_key <- as.character(
      current_sample_size
    )

    subset_object <- shape_subsets[[
      size_key
    ]]

    occurrence_points <- set_axis_names(
      subset_object$points
    )

    for (method_name in method_order) {

      comparison_index <- comparison_index +
        1L

      result_key <- paste(
        scenario_name,
        method_key(
          method_name
        ),
        sep = "__"
      )

      set_operation_seed <- as.integer(
        set_seed_base +
          comparison_index
      )

      existing_result <- geometry_results[[
        result_key
      ]]

      if (!is.null(
        existing_result
      )) {

        if (isTRUE(
          existing_result$success
        )) {
          message(
            "Skipping successful geometry comparison [",
            comparison_index,
            "/",
            number_of_comparisons,
            "]: ",
            result_key
          )
          next
        }

        if (!retry_failed_overlap) {
          message(
            "Skipping previously failed geometry comparison: ",
            result_key
          )
          next
        }
      }

      message(
        "Geometry comparison [",
        comparison_index,
        "/",
        number_of_comparisons,
        "]: ",
        result_key
      )

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
          ) ||
          is.null(
            fitted_record$hypervolume
          )
      ) {

        geometry_results[[result_key]] <- list(
          success = FALSE,
          result_key = result_key,
          scenario_name = scenario_name,
          shape_code = shape_name,
          shape = unname(
            shape_labels[[
              shape_name
            ]]
          ),
          sample_size = current_sample_size,
          method = method_name,
          set_operation_seed = set_operation_seed,
          metrics = NULL,
          error_message = if (
            is.null(
              fitted_record
            )
          ) {
            "Missing baseline fit record."
          } else {
            fitted_record$error_message
          }
        )

        save_geometry_checkpoint()

        next
      }

      calculation <- tryCatch(
        {

          metrics <- calculate_geometry_metrics(
            estimated_hv = fitted_record$hypervolume,
            occurrence_points = occurrence_points,
            reference = reference,
            shape_name = shape_name,
            set_seed = set_operation_seed
          )

          list(
            success = TRUE,
            metrics = metrics,
            error_message = NA_character_
          )
        },
        error = function(error_condition) {

          list(
            success = FALSE,
            metrics = NULL,
            error_message = conditionMessage(
              error_condition
            )
          )
        }
      )

      geometry_results[[result_key]] <- list(
        success = calculation$success,
        result_key = result_key,
        scenario_name = scenario_name,
        shape_code = shape_name,
        shape = unname(
          shape_labels[[
            shape_name
          ]]
        ),
        sample_size = current_sample_size,
        method = method_name,
        model_runtime_seconds = fitted_record$runtime_seconds,
        set_operation_seed = set_operation_seed,
        metrics = calculation$metrics,
        error_message = calculation$error_message
      )

      save_geometry_checkpoint()
    }
  }
}


# ============================================================
# Compile final geometry table
# ============================================================

geometry_rows <- list()
geometry_row_index <- 0L

for (shape_name in shape_order) {

  for (current_sample_size in sample_sizes) {

    scenario_name <- scenario_name_for(
      shape_name,
      current_sample_size
    )

    scenario <- baseline_scenarios[[
      scenario_name
    ]]

    for (method_name in method_order) {

      geometry_row_index <- geometry_row_index +
        1L

      result_key <- paste(
        scenario_name,
        method_key(
          method_name
        ),
        sep = "__"
      )

      result <- geometry_results[[
        result_key
      ]]

      fitted_record <- scenario[[
        method_key(
          method_name
        )
      ]]

      model_success <- (
        !is.null(
          fitted_record
        ) &&
          isTRUE(
            fitted_record$success
          ) &&
          !is.null(
            fitted_record$hypervolume
          )
      )

      if (
        !is.null(
          result
        ) &&
          isTRUE(
            result$success
          ) &&
          !is.null(
            result$metrics
          )
      ) {

        geometry_rows[[geometry_row_index]] <- cbind(
          data.frame(
            Result_key = result_key,
            Shape_code = shape_name,
            Shape = unname(
              shape_labels[[
                shape_name
              ]]
            ),
            Dimensionality = 3L,
            Sample_size = current_sample_size,
            Method = method_name,
            Model_success = TRUE,
            Geometry_success = TRUE,
            Model_runtime_seconds = as.numeric(
              fitted_record$runtime_seconds
            ),
            Geometry_error = NA_character_,
            stringsAsFactors = FALSE
          ),
          result$metrics
        )

      } else {

        estimated_volume <- if (
          model_success
        ) {
          as.numeric(
            fitted_record$hypervolume@Volume
          )
        } else {
          NA_real_
        }

        exact_true_volume <- true_volume(
          shape_name
        )

        signed_volume_error <- (
          estimated_volume -
            exact_true_volume
        )

        relative_volume_error_percent <- if (
          is.finite(
            estimated_volume
          )
        ) {
          100 *
            signed_volume_error /
            exact_true_volume
        } else {
          NA_real_
        }

        geometry_rows[[geometry_row_index]] <- data.frame(
          Result_key = result_key,
          Shape_code = shape_name,
          Shape = unname(
            shape_labels[[
              shape_name
            ]]
          ),
          Dimensionality = 3L,
          Sample_size = current_sample_size,
          Method = method_name,
          Model_success = model_success,
          Geometry_success = FALSE,
          Model_runtime_seconds = if (
            model_success
          ) {
            as.numeric(
              fitted_record$runtime_seconds
            )
          } else {
            NA_real_
          },
          Geometry_error = if (
            is.null(
              result
            )
          ) {
            "Missing geometry result."
          } else {
            result$error_message
          },
          Exact_true_volume = exact_true_volume,
          Estimated_volume = estimated_volume,
          Signed_volume_error = signed_volume_error,
          Absolute_volume_error = abs(
            signed_volume_error
          ),
          Relative_volume_error_percent = relative_volume_error_percent,
          Absolute_relative_volume_error_percent = abs(
            relative_volume_error_percent
          ),
          Intersection_volume = NA_real_,
          Estimated_only_volume = NA_real_,
          True_only_volume = NA_real_,
          Union_volume = NA_real_,
          Set_estimated_volume = NA_real_,
          Set_true_volume = NA_real_,
          Jaccard_similarity = NA_real_,
          Jaccard_from_components = NA_real_,
          Sorensen_similarity = NA_real_,
          True_region_coverage = NA_real_,
          True_region_coverage_percent = NA_real_,
          Missed_true_region_volume = NA_real_,
          Missed_true_region_percent = NA_real_,
          Excess_estimated_volume = NA_real_,
          Excess_estimated_volume_percent_of_true = NA_real_,
          Excess_estimated_fraction = NA_real_,
          Set_based_true_region_coverage_percent = NA_real_,
          Set_based_missed_true_region_percent = NA_real_,
          Set_based_excess_predicted_percent_of_true = NA_real_,
          Set_true_volume_relative_difference_from_exact_percent = NA_real_,
          Estimated_centroid_X1 = NA_real_,
          Estimated_centroid_X2 = NA_real_,
          Estimated_centroid_X3 = NA_real_,
          Reference_centroid_X1 = references[[shape_name]]$centroid[[
            1L
          ]],
          Reference_centroid_X2 = references[[shape_name]]$centroid[[
            2L
          ]],
          Reference_centroid_X3 = references[[shape_name]]$centroid[[
            3L
          ]],
          Analytical_centroid_X1 = 0,
          Analytical_centroid_X2 = 0,
          Analytical_centroid_X3 = 0,
          Occurrence_centroid_X1 = NA_real_,
          Occurrence_centroid_X2 = NA_real_,
          Occurrence_centroid_X3 = NA_real_,
          Centroid_displacement = NA_real_,
          Centroid_displacement_from_reference = NA_real_,
          Centroid_displacement_from_analytical_truth = NA_real_,
          Centroid_displacement_from_occurrence = NA_real_,
          Estimated_random_points = if (
            model_success
          ) {
            nrow(
              fitted_record$hypervolume@RandomPoints
            )
          } else {
            NA_integer_
          },
          Set_operation_runtime_seconds = NA_real_,
          Set_operation_seed = if (
            is.null(
              result
            )
          ) {
            NA_integer_
          } else {
            result$set_operation_seed
          },
          Jaccard_num_points_max = jaccard_num_points_max,
          Jaccard_distance_factor = jaccard_distance_factor,
          Decomposition_source = NA_character_,
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

geometry_summary <- do.call(
  rbind,
  geometry_rows
)

rownames(
  geometry_summary
) <- NULL


# ============================================================
# Final table integrity checks
# ============================================================

if (!identical(
  nrow(
    geometry_summary
  ),
  27L
)) {
  stop(
    "Expected 27 baseline 3D geometry rows but compiled ",
    nrow(
      geometry_summary
    ),
    "."
  )
}

if (anyDuplicated(
  geometry_summary$Result_key
)) {
  stop(
    "Final 3D geometry summary contains duplicated result keys."
  )
}


# ============================================================
# Save final CSV outputs
# ============================================================

write_csv_safely(
  geometry_summary,
  geometry_summary_file
)

geometry_overlap_diagnostics <- geometry_summary[
  ,
  c(
    "Result_key",
    "Shape_code",
    "Shape",
    "Sample_size",
    "Method",
    "Geometry_success",
    "Exact_true_volume",
    "Estimated_volume",
    "Intersection_volume",
    "Estimated_only_volume",
    "True_only_volume",
    "Union_volume",
    "Set_estimated_volume",
    "Set_true_volume",
    "Set_true_volume_relative_difference_from_exact_percent",
    "Jaccard_similarity",
    "Jaccard_from_components",
    "True_region_coverage_percent",
    "Set_based_true_region_coverage_percent",
    "Excess_estimated_volume_percent_of_true",
    "Set_based_excess_predicted_percent_of_true",
    "Set_operation_seed",
    "Set_operation_runtime_seconds",
    "Decomposition_source",
    "Geometry_error"
  ),
  drop = FALSE
]

write_csv_safely(
  geometry_overlap_diagnostics,
  geometry_overlap_diagnostic_file
)

geometry_failures <- geometry_summary[
  !geometry_summary$Geometry_success,
  c(
    "Result_key",
    "Shape_code",
    "Shape",
    "Sample_size",
    "Method",
    "Model_success",
    "Geometry_success",
    "Geometry_error"
  ),
  drop = FALSE
]

if (nrow(
  geometry_failures
) == 0L) {
  geometry_failures <- data.frame(
    Result_key = character(0),
    Shape_code = character(0),
    Shape = character(0),
    Sample_size = integer(0),
    Method = character(0),
    Model_success = logical(0),
    Geometry_success = logical(0),
    Geometry_error = character(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  geometry_failures,
  failure_file
)


# ============================================================
# Save authoritative geometry RDS for Scripts 09 and 10
# ============================================================

geometry_output <- list(
  metadata = list(
    script = "07_3D_Synthetic_Geometry.R",
    geometry_settings_hash = geometry_settings_hash,
    baseline_results_file = baseline_results_file,
    baseline_results_md5 = safe_md5(
      baseline_results_file
    ),
    reference_file = reference_file,
    reference_file_md5 = reference_file_md5,
    reference_signature = reference_signature,
    shape_order = shape_order,
    sample_sizes = sample_sizes,
    method_order = method_order,
    reference_points_per_shape = reference_points_per_shape,
    reference_seed_base = reference_seed_base,
    jaccard_num_points_max = jaccard_num_points_max,
    jaccard_distance_factor = jaccard_distance_factor,
    set_seed_base = set_seed_base,
    method_colours = method_colours,
    true_region_colour = true_region_colour,
    occurrence_colour = occurrence_colour,
    hypervolume_version = installed_hypervolume_version,
    completed_at = as.character(
      Sys.time()
    )
  ),
  true_references = references,
  reference_manifest = reference_manifest,
  geometry_results = geometry_results,
  geometry_summary = geometry_summary
)

saveRDS(
  geometry_output,
  geometry_results_file,
  version = 3
)


# ============================================================
# Save run metadata
# ============================================================

run_metadata <- list(
  geometry_settings_hash = geometry_settings_hash,
  geometry_settings = geometry_settings,
  input_files = list(
    baseline_results_file = baseline_results_file,
    baseline_results_md5 = safe_md5(
      baseline_results_file
    ),
    reference_file = reference_file,
    reference_file_md5 = reference_file_md5,
    legacy_reference_file = legacy_reference_file,
    legacy_reference_md5 = legacy_reference_md5
  ),
  reference_source = reference_source,
  counts = list(
    expected_comparisons = number_of_comparisons,
    successful_geometry_comparisons = sum(
      geometry_summary$Geometry_success
    ),
    failed_geometry_comparisons = sum(
      !geometry_summary$Geometry_success
    )
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


# ============================================================
# Human-readable analysis notes
# ============================================================

writeLines(
  c(
    "Revised 3D synthetic geometry analysis",
    "=====================================",
    "",
    "Baseline estimator fits were reused from Script 06; no estimator was refitted.",
    "",
    "Shapes:",
    "  Solid ball",
    "  Solid torus",
    "  Hollow spherical region",
    "",
    "Occurrence sample sizes:",
    "  n = 300, 900, 1500",
    "",
    "Fixed true-region references:",
    paste0(
      "  points per shape = ",
      reference_points_per_shape
    ),
    paste0(
      "  reference seed base = ",
      reference_seed_base
    ),
    paste0(
      "  source = ",
      reference_source
    ),
    "",
    "hypervolume_set settings:",
    paste0(
      "  num.points.max = ",
      jaccard_num_points_max
    ),
    paste0(
      "  distance.factor = ",
      jaccard_distance_factor
    ),
    paste0(
      "  set-operation seed base = ",
      set_seed_base
    ),
    "",
    "Primary geometry metrics:",
    "  exact/estimated volume and signed/absolute relative error",
    "  Jaccard and Sorensen similarity",
    "  true-region coverage",
    "  missed true-region volume",
    "  excess estimated volume as percentage of exact true volume",
    "  centroid displacement",
    "",
    "Coverage/excess denominator:",
    "  Analytically exact true volume for primary reported values.",
    "  Set-based equivalents are retained as stochastic set-operation diagnostics.",
    "",
    "Centroid displacement:",
    "  Primary Centroid_displacement uses the fixed true-reference centroid,",
    "  matching the revised 2D geometry workflow.",
    "  Analytical-truth and legacy occurrence-centroid displacements are also saved.",
    "",
    "Locked colours:",
    "  Gaussian KDE = #D7301F",
    "  SVM = #238B45",
    "  QPH = #2C7FB8",
    "  true region = #D9D9D9",
    "  occurrences = #111111",
    "",
    paste0(
      "Successful geometry comparisons: ",
      sum(
        geometry_summary$Geometry_success
      ),
      " / ",
      nrow(
        geometry_summary
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
  "07_3D_Synthetic_Geometry.R complete."
)

message(
  "============================================================"
)

message(
  "Authoritative geometry object:\n  ",
  normalizePath(
    geometry_results_file,
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
  "Overlap diagnostics:\n  ",
  normalizePath(
    geometry_overlap_diagnostic_file,
    mustWork = FALSE
  )
)

message(
  "Fixed true-region references:\n  ",
  normalizePath(
    reference_file,
    mustWork = FALSE
  )
)

message(
  "Successful geometry comparisons: ",
  sum(
    geometry_summary$Geometry_success
  ),
  " / ",
  nrow(
    geometry_summary
  )
)

if (nrow(
  geometry_failures
) > 0L) {

  message(
    "WARNING: ",
    nrow(
      geometry_failures
    ),
    " geometry comparison(s) failed. See:\n  ",
    normalizePath(
      failure_file,
      mustWork = FALSE
    )
  )

} else {

  message(
    "No geometry comparison failures were recorded."
  )
}

message(
  "============================================================"
)
