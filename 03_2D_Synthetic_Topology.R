# ============================================================
# 03_2D_Synthetic_Topology.R
# ============================================================
#
# Clean final 2D synthetic topological analysis for the revised Q-niche paper.
#


rm(list = ls())
gc()

# ============================================================
# Required packages
# ============================================================

required_packages <- c(
  "hypervolume",
  "TDAstats",
  "TDA",
  "R.utils",
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
    "Install the following required package(s) before running Script 04: ",
    paste(missing_packages, collapse = ", ")
  )
}

library(hypervolume)
library(TDAstats)
library(TDA)
library(R.utils)
library(ggplot2)
library(patchwork)

# ============================================================
# User settings
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

topology_output_directory <- file.path(
  analysis_root_directory,
  "03_Topology"
)

dir.create(
  topology_output_directory,
  showWarnings = FALSE,
  recursive = TRUE
)

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

shape_labels <- c(
  spiral = "Spiral band",
  ellipse = "Filled ellipse",
  annulus = "Annulus",
  banana = "Concave banana",
  two_balls = "Two separated disks"
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

# Equal point-cloud size used for every PH calculation.
ph_sample_size <- 300L

# Number of repeated point-cloud subsamples.
number_of_repetitions <- 10L

# Homology is calculated through H1 for the two-dimensional datasets.
maximum_homology_dimension <- 1L

# Vietoris--Rips settings.
ph_threshold <- -1
ph_prime_field <- 2L
ph_standardize <- FALSE

# Maximum elapsed time for one persistent-homology calculation.
ph_timeout_seconds <- 6 * 60

# Matched filled-ellipse reference settings.
number_of_null_replicates <- 20L

# H1 is evaluated for the four H1 diagnostics; finite H0 is evaluated
# for the two separated disks.
null_target_dimensions <- c(
  spiral = 1L,
  ellipse = 1L,
  annulus = 1L,
  banana = 1L,
  two_balls = 0L
)

simple_control_shapes <- c(
  "spiral",
  "ellipse",
  "banana"
)

expected_feature_shapes <- c(
  "annulus",
  "two_balls"
)

null_target_labels <- c(
  spiral = "Spiral band: H1",
  ellipse = "Filled ellipse: H1",
  annulus = "Annulus: H1",
  banana = "Concave banana: H1",
  two_balls = "Two separated disks: finite H0"
)

# Preserve the original matched-reference seed allocation. This keeps the
# previous scientific seed design while all revised QPH-dependent values
# are recalculated in the new output directory.
null_seed_shape_block <- c(
  annulus = 0L,
  two_balls = 3L,
  spiral = 6L,
  ellipse = 9L,
  banana = 12L
)

null_scenario_index_for <- function(
    shape_name,
    sample_size
) {
  sample_index <- match(
    as.integer(sample_size),
    as.integer(expected_sample_sizes)
  )

  if (is.na(sample_index)) {
    stop(
      "Unexpected sample size in matched-reference analysis: ",
      sample_size
    )
  }

  if (!shape_name %in% names(null_seed_shape_block)) {
    stop(
      "Unexpected shape in matched-reference analysis: ",
      shape_name
    )
  }

  as.integer(
    null_seed_shape_block[[shape_name]] +
      sample_index
  )
}

# Fixed seeds retained from the previous topology analysis.
topology_master_seed <- 42001L
null_master_seed <- 52001L

# Restart behaviour.
resume_from_checkpoint <- TRUE
retry_failed_persistence <- TRUE
retry_incomplete_nulls <- TRUE

# Representative panels.
representative_sample_size <- 900L
representative_repetition <- 1L

# Publication/supplementary figure settings.
figure_width_inches <- 7.5
figure_height_inches <- 9.2
figure_tiff_dpi <- 600L

# Locked colour scheme used throughout the revised paper.
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

method_shapes <- c(
  "Gaussian KDE" = 16,
  "SVM" = 15,
  "QPH" = 17
)

source_shapes <- c(
  "Occurrence" = 4,
  method_shapes
)

# Package versions specified in the existing Methods. Mismatches are
# warned about and recorded rather than silently ignored.
expected_tda_stats_version <- "0.4.1"
expected_tda_version <- "1.9.4"

# ============================================================
# Input and output paths
# ============================================================

occurrence_archive_file <- file.path(
  locked_input_directory,
  "synthetic_occurrence_clouds_authoritative.rds"
)

baseline_results_file <- file.path(
  baseline_output_directory,
  "baseline_fit_results_sqrtNB_q099.rds"
)

subsample_archive_file <- file.path(
  topology_output_directory,
  "topology_subsample_indices_sqrtNB_q099.rds"
)

persistence_checkpoint_file <- file.path(
  topology_output_directory,
  "persistence_diagrams_checkpoint_sqrtNB_q099.rds"
)

persistence_diagrams_file <- file.path(
  topology_output_directory,
  "persistence_diagrams_sqrtNB_q099.rds"
)

persistence_log_file <- file.path(
  topology_output_directory,
  "persistence_calculation_log_sqrtNB_q099.csv"
)

bottleneck_replicate_file <- file.path(
  topology_output_directory,
  "bottleneck_distances_replicates_sqrtNB_q099.csv"
)

bottleneck_summary_file <- file.path(
  topology_output_directory,
  "bottleneck_distance_summary_mean_sd_sqrtNB_q099.csv"
)

bottleneck_overall_file <- file.path(
  topology_output_directory,
  "bottleneck_overall_mean_sd_sqrtNB_q099.csv"
)

null_checkpoint_file <- file.path(
  topology_output_directory,
  "matched_ellipse_checkpoint_sqrtNB_q099.rds"
)

null_replicate_file <- file.path(
  topology_output_directory,
  "matched_ellipse_replicates_sqrtNB_q099.csv"
)

null_observed_file <- file.path(
  topology_output_directory,
  "matched_ellipse_observed_sqrtNB_q099.csv"
)

matched_reference_exceedance_file <- file.path(
  topology_output_directory,
  "matched_reference_exceedance_summary_sqrtNB_q099.csv"
)

simple_control_exceedance_file <- file.path(
  topology_output_directory,
  "simple_control_H1_exceedance_summary_sqrtNB_q099.csv"
)

synthetic_topology_pdf <- file.path(
  topology_output_directory,
  "Synthetic_topology_summary_sqrtNB_q099.pdf"
)

synthetic_topology_tiff <- file.path(
  topology_output_directory,
  "Synthetic_topology_summary_sqrtNB_q099.tiff"
)

synthetic_topology_png <- file.path(
  topology_output_directory,
  "Synthetic_topology_summary_sqrtNB_q099.png"
)

panel_a_pdf <- file.path(
  topology_output_directory,
  "Synthetic_topology_panel_a_persistence_diagrams_sqrtNB_q099.pdf"
)

panel_b_pdf <- file.path(
  topology_output_directory,
  "Synthetic_topology_panel_b_bottleneck_sqrtNB_q099.pdf"
)

panel_c_pdf <- file.path(
  topology_output_directory,
  "Synthetic_topology_panel_c_exceedance_sqrtNB_q099.pdf"
)

supplementary_bottleneck_pdf <- file.path(
  topology_output_directory,
  "Supplementary_bottleneck_all_shapes_sqrtNB_q099.pdf"
)

supplementary_diagrams_pdf <- file.path(
  topology_output_directory,
  "Supplementary_persistence_diagrams_all_shapes_n900_sqrtNB_q099.pdf"
)

supplementary_null_pdf <- file.path(
  topology_output_directory,
  "Supplementary_matched_ellipse_references_sqrtNB_q099.pdf"
)

supplementary_simple_control_pdf <- file.path(
  topology_output_directory,
  "Supplementary_simple_control_H1_exceedance_sqrtNB_q099.pdf"
)

analysis_notes_file <- file.path(
  topology_output_directory,
  "TOPOLOGICAL_ANALYSIS_NOTES_sqrtNB_q099.txt"
)

session_information_file <- file.path(
  topology_output_directory,
  "session_information_sqrtNB_q099.txt"
)

run_metadata_file <- file.path(
  topology_output_directory,
  "topology_run_metadata_sqrtNB_q099.rds"
)

# ============================================================
# Initial file and package checks
# ============================================================

required_input_files <- c(
  occurrence_archive_file,
  baseline_results_file
)

missing_input_files <- required_input_files[
  !file.exists(required_input_files)
]

if (length(missing_input_files) > 0L) {
  stop(
    "One or more required input files are missing:\n  ",
    paste(missing_input_files, collapse = "\n  "),
    "\nRun 01_2D_Synthetic_Baseline_Fits.R successfully before Script 04."
  )
}

installed_tda_stats_version <- as.character(
  utils::packageVersion("TDAstats")
)

installed_tda_version <- as.character(
  utils::packageVersion("TDA")
)

installed_hypervolume_version <- as.character(
  utils::packageVersion("hypervolume")
)

if (!identical(
  installed_tda_stats_version,
  expected_tda_stats_version
)) {
  warning(
    "TDAstats version ",
    installed_tda_stats_version,
    " is installed; the existing Methods state version ",
    expected_tda_stats_version,
    ". Record the version actually used in the final manuscript."
  )
}

if (!identical(
  installed_tda_version,
  expected_tda_version
)) {
  warning(
    "TDA version ",
    installed_tda_version,
    " is installed; the existing Methods state version ",
    expected_tda_version,
    ". Record the version actually used in the final manuscript."
  )
}

# ============================================================
# General helpers
# ============================================================

safe_md5 <- function(path) {
  if (!file.exists(path)) {
    return(NA_character_)
  }

  unname(tools::md5sum(path))
}

validate_numeric_matrix <- function(x, object_name = "x") {
  x <- as.matrix(x)
  storage.mode(x) <- "double"

  if (nrow(x) < 1L) {
    stop(object_name, " must contain at least one row.")
  }

  if (ncol(x) < 1L) {
    stop(object_name, " must contain at least one column.")
  }

  if (any(!is.finite(x))) {
    stop(object_name, " contains missing or non-finite values.")
  }

  x
}

standardize_axis_names <- function(x) {
  x <- validate_numeric_matrix(x)
  colnames(x) <- paste(
    "Environmental axis",
    seq_len(ncol(x))
  )
  x
}

validate_hypervolume <- function(hv, object_name) {
  if (!methods::is(hv, "Hypervolume")) {
    stop(object_name, " is not a Hypervolume object.")
  }

  methods::validObject(hv)

  random_points <- validate_numeric_matrix(
    hv@RandomPoints,
    paste0(object_name, "@RandomPoints")
  )

  if (ncol(random_points) != 2L) {
    stop(object_name, " is not two-dimensional.")
  }

  invisible(TRUE)
}

make_settings_signature <- function() {
  paste(
    safe_md5(occurrence_archive_file),
    safe_md5(baseline_results_file),
    paste(expected_shape_names, collapse = ","),
    paste(expected_sample_sizes, collapse = ","),
    ph_sample_size,
    number_of_repetitions,
    maximum_homology_dimension,
    ph_threshold,
    ph_prime_field,
    ph_standardize,
    ph_timeout_seconds,
    number_of_null_replicates,
    paste(
      names(null_target_dimensions),
      null_target_dimensions,
      collapse = ","
    ),
    topology_master_seed,
    null_master_seed,
    installed_tda_stats_version,
    installed_tda_version,
    sep = "|"
  )
}

analysis_settings_signature <- make_settings_signature()

# Separate signature for the matched-reference configuration. This prevents
# a checkpoint produced with a different target-dimension or seed allocation
# from being reused silently.
null_settings_signature <- paste(
  analysis_settings_signature,
  paste(
    names(null_target_dimensions),
    null_target_dimensions,
    collapse = ","
  ),
  paste(
    names(null_seed_shape_block),
    null_seed_shape_block,
    collapse = ","
  ),
  sep = "|matched_reference="
)

# Detect which optional arguments are supported by the installed
# TDAstats::calculate_homology() implementation. TDAstats 0.4.1 does
# not expose p, whereas later versions do.
tda_calculate_homology_formals <- names(
  formals(TDAstats::calculate_homology)
)

tda_supports_prime_field <- (
  "p" %in% tda_calculate_homology_formals
)

message(
  "TDAstats::calculate_homology() supports p argument: ",
  tda_supports_prime_field
)

source_to_key <- function(source_name) {
  gsub(
    "[^A-Za-z0-9]+",
    "_",
    source_name
  )
}

scenario_repetition_source_key <- function(
    scenario_name,
    repetition,
    source_name
) {
  paste(
    scenario_name,
    paste0("rep", repetition),
    source_to_key(source_name),
    sep = "__"
  )
}

format_mean_sd <- function(mean_value, sd_value, digits = 4L) {
  if (!is.finite(mean_value)) {
    return(NA_character_)
  }

  if (!is.finite(sd_value)) {
    return(sprintf(paste0("%.", digits, "f"), mean_value))
  }

  sprintf(
    paste0("%.", digits, "f \u00b1 %.", digits, "f"),
    mean_value,
    sd_value
  )
}

safe_sd <- function(x) {
  x <- x[is.finite(x)]

  if (length(x) <= 1L) {
    return(NA_real_)
  }

  stats::sd(x)
}

# ============================================================
# Load and validate source objects
# ============================================================

message("Loading locked occurrence archive...")
occurrence_archive <- readRDS(
  occurrence_archive_file
)

message("Loading revised unified baseline fits...")
baseline_results <- readRDS(
  baseline_results_file
)

required_archive_names <- c(
  "metadata",
  "master_datasets",
  "occurrence_subsets"
)

if (!all(required_archive_names %in% names(occurrence_archive))) {
  stop(
    "The occurrence archive does not have the expected structure."
  )
}

if (!identical(
  names(occurrence_archive$master_datasets),
  expected_shape_names
)) {
  stop(
    "The occurrence archive contains unexpected shape names or order."
  )
}

if (!identical(
  as.integer(occurrence_archive$metadata$sample_sizes),
  expected_sample_sizes
)) {
  stop(
    "The occurrence archive contains unexpected sample sizes."
  )
}

if (
  !is.list(baseline_results) ||
    !all(c("metadata", "scenarios", "summary") %in% names(baseline_results))
) {
  stop(
    "The revised baseline results do not have the expected Script 01 structure."
  )
}

baseline_scenarios <- baseline_results$scenarios

expected_scenarios <- as.vector(
  outer(
    expected_shape_names,
    expected_sample_sizes,
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

if (!all(expected_scenarios %in% names(baseline_scenarios))) {
  stop(
    "Script 01 revised baseline results are missing one or more ",
    "expected scenarios."
  )
}

message(
  "Validating occurrence identity and revised estimator settings..."
)

for (shape_name in expected_shape_names) {
  for (sample_size in expected_sample_sizes) {

    scenario_name <- paste(
      shape_name,
      sample_size,
      sep = "_"
    )

    size_key <- as.character(
      sample_size
    )

    shape_occurrence_subsets <- occurrence_archive$occurrence_subsets[[shape_name]]
    archived_subset <- shape_occurrence_subsets[[size_key]]

    if (is.null(archived_subset)) {
      stop(
        "Locked occurrence archive is missing ",
        scenario_name,
        "."
      )
    }

    archived_points <- standardize_axis_names(
      archived_subset$points
    )

    scenario <- baseline_scenarios[[scenario_name]]

    if (!identical(
      as.character(scenario$shape_name),
      shape_name
    )) {
      stop(
        "Scenario shape identity mismatch for ",
        scenario_name,
        "."
      )
    }

    if (!identical(
      as.integer(scenario$sample_size),
      as.integer(sample_size)
    )) {
      stop(
        "Scenario sample-size mismatch for ",
        scenario_name,
        "."
      )
    }

    method_results <- list(
      "Gaussian KDE" = scenario$gaussian_kde,
      "SVM" = scenario$svm,
      "QPH" = scenario$qph
    )

    for (method_name in method_order) {
      method_result <- method_results[[method_name]]

      if (!isTRUE(method_result$success)) {
        stop(
          method_name,
          " baseline fit failed for ",
          scenario_name,
          ". Script 04 requires successful baseline fits."
        )
      }

      validate_hypervolume(
        method_result$hypervolume,
        paste0(
          method_name,
          " hypervolume for ",
          scenario_name
        )
      )

      if (!identical(
        standardize_axis_names(method_result$hypervolume@Data),
        archived_points
      )) {
        stop(
          method_name,
          " Hypervolume@Data does not match the locked occurrence cloud for ",
          scenario_name,
          "."
        )
      }
    }

    # Revised QPH audit checks.
    qph_result <- scenario$qph
    expected_k <- round(
      sqrt(
        nrow(archived_points)
      )
    )

    if (!identical(
      as.integer(qph_result$audit$K),
      as.integer(expected_k)
    )) {
      stop(
        "QPH K audit mismatch for ",
        scenario_name,
        "."
      )
    }

    if (!isTRUE(all.equal(
      as.numeric(qph_result$audit$q),
      0.99,
      tolerance = 1e-12
    ))) {
      stop(
        "QPH q is not 0.99 for ",
        scenario_name,
        "."
      )
    }

    recalculated_h <- sqrt(
      mean(
        as.numeric(
          qph_result$audit$local_s
        )
      )
    )

    if (!isTRUE(all.equal(
      as.numeric(qph_result$audit$baseline_scalar_h),
      recalculated_h,
      tolerance = 1e-12
    ))) {
      stop(
        "QPH sqrt-NB scalar bandwidth audit mismatch for ",
        scenario_name,
        "."
      )
    }

    fitted_bandwidth <- as.numeric(
      qph_result$audit$fitted_bandwidth
    )

    if (!isTRUE(all.equal(
      fitted_bandwidth,
      rep(recalculated_h, 2L),
      tolerance = 1e-12
    ))) {
      stop(
        "QPH fitted bandwidth is not the revised isotropic sqrt-NB ",
        "bandwidth for ",
        scenario_name,
        "."
      )
    }

    # KDE remains a separate Silverman comparator at its previous
    # probability quantile.
    kde_result <- scenario$gaussian_kde

    if (!isTRUE(all.equal(
      as.numeric(kde_result$probability_quantile),
      0.95,
      tolerance = 1e-12
    ))) {
      stop(
        "Gaussian KDE probability quantile is not 0.95 for ",
        scenario_name,
        "."
      )
    }

    # SVM remains the locked package-consistent baseline.
    svm_hv <- scenario$svm$hypervolume

    if (!isTRUE(all.equal(
      as.numeric(svm_hv@Parameters$svm.nu),
      0.01
    ))) {
      stop(
        "SVM nu mismatch for ",
        scenario_name,
        "."
      )
    }

    if (!isTRUE(all.equal(
      as.numeric(svm_hv@Parameters$svm.gamma),
      0.50
    ))) {
      stop(
        "SVM gamma mismatch for ",
        scenario_name,
        "."
      )
    }

    source_point_counts <- c(
      occurrence = nrow(archived_points),
      gaussian = nrow(scenario$gaussian_kde$hypervolume@RandomPoints),
      svm = nrow(scenario$svm$hypervolume@RandomPoints),
      qph = nrow(scenario$qph$hypervolume@RandomPoints)
    )

    if (any(source_point_counts < ph_sample_size)) {
      stop(
        "At least one point cloud contains fewer than ",
        ph_sample_size,
        " points for scenario ",
        scenario_name,
        ": ",
        paste(
          names(source_point_counts),
          source_point_counts,
          sep = "=",
          collapse = ", "
        )
      )
    }
  }
}

message(
  "All source objects, revised QPH audits, and comparator settings were verified."
)

# ============================================================
# Point-cloud extraction
# ============================================================

get_scenario_point_clouds <- function(
    shape_name,
    sample_size
) {

  scenario_name <- paste(
    shape_name,
    sample_size,
    sep = "_"
  )

  size_key <- as.character(
    sample_size
  )

  shape_occurrence_subsets <- occurrence_archive$occurrence_subsets[[shape_name]]
  archived_subset <- shape_occurrence_subsets[[size_key]]
  scenario <- baseline_scenarios[[scenario_name]]

  list(
    "Occurrence" = standardize_axis_names(
      archived_subset$points
    ),
    "Gaussian KDE" = standardize_axis_names(
      scenario$gaussian_kde$hypervolume@RandomPoints
    ),
    "SVM" = standardize_axis_names(
      scenario$svm$hypervolume@RandomPoints
    ),
    "QPH" = standardize_axis_names(
      scenario$qph$hypervolume@RandomPoints
    )
  )
}

# ============================================================
# Create or load exact subsample indices
# ============================================================

create_subsample_archive <- function() {
  archive_indices <- list()
  scenario_index <- 0L

  for (shape_name in expected_shape_names) {
    for (sample_size in expected_sample_sizes) {
      scenario_index <- scenario_index + 1L
      scenario_name <- paste(shape_name, sample_size, sep = "_")
      point_clouds <- get_scenario_point_clouds(
        shape_name,
        sample_size
      )

      archive_indices[[scenario_name]] <- list()

      for (repetition in seq_len(number_of_repetitions)) {
        repetition_entry <- list()

        for (source_index in seq_along(source_order)) {
          source_name <- source_order[source_index]
          source_points <- point_clouds[[source_name]]

          current_seed <- as.integer(
            topology_master_seed +
              scenario_index * 10000L +
              repetition * 100L +
              source_index
          )

          if (
            identical(source_name, "Occurrence") &&
              nrow(source_points) == ph_sample_size
          ) {
            selected_indices <- seq_len(ph_sample_size)
          } else {
            set.seed(current_seed)
            selected_indices <- sample.int(
              n = nrow(source_points),
              size = ph_sample_size,
              replace = FALSE
            )
          }

          repetition_entry[[source_name]] <- list(
            seed = current_seed,
            source_point_count = nrow(source_points),
            selected_row_indices = as.integer(selected_indices)
          )
        }

        archive_indices[[scenario_name]][[as.character(repetition)]] <- (
          repetition_entry
        )
      }
    }
  }

  list(
    metadata = list(
      analysis_settings_signature = analysis_settings_signature,
      ph_sample_size = ph_sample_size,
      number_of_repetitions = number_of_repetitions,
      topology_master_seed = topology_master_seed,
      occurrence_archive_md5 = safe_md5(occurrence_archive_file),
      baseline_results_md5 = safe_md5(baseline_results_file),
      created = as.character(Sys.time())
    ),
    indices = archive_indices
  )
}

validate_subsample_archive <- function(subsample_archive) {
  if (!is.list(subsample_archive)) {
    stop("The topology subsample archive is not a list.")
  }

  if (!all(c("metadata", "indices") %in% names(subsample_archive))) {
    stop("The topology subsample archive has an unexpected structure.")
  }

  if (!identical(
    subsample_archive$metadata$analysis_settings_signature,
    analysis_settings_signature
  )) {
    stop(
      "The existing topology subsample archive was created from different ",
      "inputs or settings. Use a new topology_output_directory or delete ",
      "the old Script 04 output before intentionally changing settings."
    )
  }

  for (scenario_name in expected_scenarios) {
    if (is.null(subsample_archive$indices[[scenario_name]])) {
      stop("Subsample archive is missing scenario ", scenario_name, ".")
    }

    for (repetition in seq_len(number_of_repetitions)) {
      repetition_entry <- subsample_archive$indices[[scenario_name]][[
        as.character(repetition)
      ]]

      if (is.null(repetition_entry)) {
        stop(
          "Subsample archive is missing repetition ",
          repetition,
          " for ",
          scenario_name,
          "."
        )
      }

      for (source_name in source_order) {
        source_entry <- repetition_entry[[source_name]]

        if (is.null(source_entry)) {
          stop(
            "Subsample archive is missing source ",
            source_name,
            " for ",
            scenario_name,
            ", repetition ",
            repetition,
            "."
          )
        }

        selected_indices <- as.integer(
          source_entry$selected_row_indices
        )

        if (length(selected_indices) != ph_sample_size) {
          stop("A saved PH subsample does not contain 300 indices.")
        }

        if (
          any(selected_indices < 1L) ||
            any(selected_indices > source_entry$source_point_count)
        ) {
          stop("A saved PH subsample contains invalid row indices.")
        }

        if (anyDuplicated(selected_indices)) {
          stop("A saved PH subsample contains duplicated row indices.")
        }
      }
    }
  }

  invisible(TRUE)
}

if (file.exists(subsample_archive_file)) {
  message("Loading saved topology subsample indices...")
  subsample_archive <- readRDS(
    subsample_archive_file
  )
  validate_subsample_archive(
    subsample_archive
  )
} else {
  message("Creating and locking exact topology subsample indices...")
  subsample_archive <- create_subsample_archive()
  validate_subsample_archive(
    subsample_archive
  )
  saveRDS(
    subsample_archive,
    file = subsample_archive_file,
    version = 3
  )
}

message(
  "Topology subsample indices are locked in: ",
  normalizePath(subsample_archive_file, mustWork = FALSE)
)

get_subsample_points <- function(
    shape_name,
    sample_size,
    repetition,
    source_name
) {
  scenario_name <- paste(shape_name, sample_size, sep = "_")
  point_clouds <- get_scenario_point_clouds(
    shape_name,
    sample_size
  )

  selected_indices <- subsample_archive$indices[[scenario_name]][[
    as.character(repetition)
  ]][[source_name]]$selected_row_indices

  point_clouds[[source_name]][
    selected_indices,
    ,
    drop = FALSE
  ]
}

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
      c("dimension", "birth", "death")
    )
  )
}

standardize_diagram <- function(diagram) {
  diagram <- as.matrix(diagram)
  storage.mode(diagram) <- "double"

  if (length(diagram) == 0L) {
    return(empty_diagram())
  }

  if (ncol(diagram) != 3L) {
    stop("A persistence diagram must contain three columns.")
  }

  colnames(diagram) <- c(
    "dimension",
    "birth",
    "death"
  )

  diagram
}

calculate_persistence_with_timeout <- function(
    points,
    maximum_dimension = maximum_homology_dimension
) {
  points <- standardize_axis_names(points)
  start_time <- proc.time()[["elapsed"]]

  result <- tryCatch(
    {
      homology_arguments <- list(
        mat = points,
        dim = maximum_dimension,
        threshold = ph_threshold,
        format = "cloud"
      )

      # These arguments are available in TDAstats 0.4.1 and later.
      if ("standardize" %in% tda_calculate_homology_formals) {
        homology_arguments$standardize <- ph_standardize
      }

      if ("return_df" %in% tda_calculate_homology_formals) {
        homology_arguments$return_df <- FALSE
      }

      # The p argument was added after TDAstats 0.4.1. Supply it only
      # when supported; otherwise the installed package default is used.
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
        diagram = standardize_diagram(diagram),
        runtime_seconds = (
          proc.time()[["elapsed"]] - start_time
        ),
        failure_type = NA_character_,
        error_message = NA_character_,
        prime_field_requested = ph_prime_field,
        prime_field_argument_used = tda_supports_prime_field
      )
    },
    TimeoutException = function(error_condition) {
      list(
        success = FALSE,
        diagram = empty_diagram(),
        runtime_seconds = (
          proc.time()[["elapsed"]] - start_time
        ),
        failure_type = "computational-limit failure",
        error_message = conditionMessage(error_condition),
        prime_field_requested = ph_prime_field,
        prime_field_argument_used = tda_supports_prime_field
      )
    },
    error = function(error_condition) {
      error_text <- conditionMessage(error_condition)
      is_timeout <- grepl(
        "time limit|timeout|reached elapsed",
        error_text,
        ignore.case = TRUE
      )

      list(
        success = FALSE,
        diagram = empty_diagram(),
        runtime_seconds = (
          proc.time()[["elapsed"]] - start_time
        ),
        failure_type = if (is_timeout) {
          "computational-limit failure"
        } else {
          "calculation failure"
        },
        error_message = error_text,
        prime_field_requested = ph_prime_field,
        prime_field_argument_used = tda_supports_prime_field
      )
    }
  )

  result
}

finite_diagram <- function(diagram) {
  diagram <- standardize_diagram(diagram)

  if (nrow(diagram) == 0L) {
    return(diagram)
  }

  diagram[
    is.finite(diagram[, "birth"]) &
      is.finite(diagram[, "death"]),
    ,
    drop = FALSE
  ]
}

max_finite_persistence <- function(diagram, dimension) {
  diagram <- finite_diagram(diagram)

  dimension_rows <- diagram[
    diagram[, "dimension"] == dimension,
    ,
    drop = FALSE
  ]

  if (nrow(dimension_rows) == 0L) {
    return(0)
  }

  persistence <- (
    dimension_rows[, "death"] -
      dimension_rows[, "birth"]
  )

  persistence <- persistence[
    is.finite(persistence) &
      persistence >= 0
  ]

  if (length(persistence) == 0L) {
    return(0)
  }

  max(persistence)
}

point_cloud_diameter <- function(points) {
  points <- standardize_axis_names(points)

  if (nrow(points) < 2L) {
    return(NA_real_)
  }

  max(stats::dist(points))
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

      list(
        success = TRUE,
        distance = as.numeric(value),
        error_message = NA_character_
      )
    },
    error = function(error_condition) {
      list(
        success = FALSE,
        distance = NA_real_,
        error_message = conditionMessage(error_condition)
      )
    }
  )
}

# ============================================================
# Calculate or resume all persistence diagrams
# ============================================================

if (
  resume_from_checkpoint &&
    file.exists(persistence_checkpoint_file)
) {
  persistence_checkpoint <- readRDS(
    persistence_checkpoint_file
  )

  if (!identical(
    persistence_checkpoint$analysis_settings_signature,
    analysis_settings_signature
  )) {
    stop(
      "The existing persistence checkpoint was produced from different ",
      "inputs or settings. Use a fresh output directory or remove the old ",
      "Script 04 checkpoint."
    )
  }

  persistence_results <- persistence_checkpoint$results

  message(
    "Loaded compatible persistence checkpoint containing ",
    length(persistence_results),
    " completed point-cloud calculation(s)."
  )
} else {
  persistence_results <- list()
}

scenario_index <- 0L

for (shape_name in expected_shape_names) {
  for (sample_size in expected_sample_sizes) {
    scenario_index <- scenario_index + 1L
    scenario_name <- paste(shape_name, sample_size, sep = "_")

    for (repetition in seq_len(number_of_repetitions)) {
      for (source_name in source_order) {
        result_key <- scenario_repetition_source_key(
          scenario_name,
          repetition,
          source_name
        )

        if (result_key %in% names(persistence_results)) {
          existing_result <- persistence_results[[result_key]]

          if (isTRUE(existing_result$success)) {
            message("Skipping successful PH calculation: ", result_key)
            next
          }

          if (!retry_failed_persistence) {
            message("Skipping previously failed PH calculation: ", result_key)
            next
          }

          message("Retrying previously failed PH calculation: ", result_key)
        }

        message(
          "Calculating PH: ",
          shape_labels[[shape_name]],
          ", n = ",
          sample_size,
          ", repetition ",
          repetition,
          ", ",
          source_name,
          "..."
        )

        points <- get_subsample_points(
          shape_name = shape_name,
          sample_size = sample_size,
          repetition = repetition,
          source_name = source_name
        )

        ph_result <- calculate_persistence_with_timeout(
          points = points,
          maximum_dimension = maximum_homology_dimension
        )

        source_seed <- subsample_archive$indices[[scenario_name]][[
          as.character(repetition)
        ]][[source_name]]$seed

        persistence_results[[result_key]] <- c(
          list(
            key = result_key,
            shape_code = shape_name,
            shape = unname(shape_labels[[shape_name]]),
            sample_size = sample_size,
            repetition = repetition,
            source = source_name,
            subsample_seed = source_seed,
            selected_row_indices = subsample_archive$indices[[
              scenario_name
            ]][[as.character(repetition)]][[
              source_name
            ]]$selected_row_indices,
            point_cloud_diameter = point_cloud_diameter(points)
          ),
          ph_result
        )

        persistence_checkpoint <- list(
          analysis_settings_signature = analysis_settings_signature,
          results = persistence_results,
          last_updated = as.character(Sys.time())
        )

        saveRDS(
          persistence_checkpoint,
          file = persistence_checkpoint_file,
          version = 3
        )
      }
    }
  }
}

saveRDS(
  persistence_results,
  file = persistence_diagrams_file,
  version = 3
)

# ============================================================
# Save PH calculation log
# ============================================================

persistence_log_rows <- lapply(
  persistence_results,
  function(result) {
    data.frame(
      Key = result$key,
      Shape_code = result$shape_code,
      Shape = result$shape,
      Sample_size = result$sample_size,
      Repetition = result$repetition,
      Source = result$source,
      Success = result$success,
      Runtime_seconds = result$runtime_seconds,
      Point_cloud_diameter = result$point_cloud_diameter,
      Subsample_seed = result$subsample_seed,
      Failure_type = result$failure_type,
      Error_message = result$error_message,
      Prime_field_requested = if (!is.null(result$prime_field_requested)) {
        result$prime_field_requested
      } else {
        ph_prime_field
      },
      Prime_field_argument_used = if (!is.null(
        result$prime_field_argument_used
      )) {
        result$prime_field_argument_used
      } else {
        tda_supports_prime_field
      },
      stringsAsFactors = FALSE
    )
  }
)

persistence_log <- do.call(
  rbind,
  persistence_log_rows
)

rownames(persistence_log) <- NULL

write.csv(
  persistence_log,
  file = persistence_log_file,
  row.names = FALSE
)

message("Persistent-homology success table:")
print(with(
  persistence_log,
  table(Source, Success, useNA = "ifany")
))

if (any(!persistence_log$Success)) {
  failed_messages <- unique(na.omit(
    persistence_log$Error_message[!persistence_log$Success]
  ))

  warning(
    "One or more persistent-homology calculations failed. ",
    "Inspect persistence_calculation_log.csv. Distinct messages: ",
    paste(failed_messages, collapse = " | ")
  )
}

# ============================================================
# Calculate paired bottleneck distances
# ============================================================

bottleneck_rows <- list()
bottleneck_index <- 0L

for (shape_name in expected_shape_names) {
  for (sample_size in expected_sample_sizes) {
    scenario_name <- paste(shape_name, sample_size, sep = "_")

    for (repetition in seq_len(number_of_repetitions)) {
      occurrence_key <- scenario_repetition_source_key(
        scenario_name,
        repetition,
        "Occurrence"
      )

      occurrence_result <- persistence_results[[occurrence_key]]

      for (method_name in method_order) {
        method_key <- scenario_repetition_source_key(
          scenario_name,
          repetition,
          method_name
        )

        method_result <- persistence_results[[method_key]]

        for (homology_dimension in 0:maximum_homology_dimension) {
          bottleneck_index <- bottleneck_index + 1L

          if (
            !isTRUE(occurrence_result$success) ||
              !isTRUE(method_result$success)
          ) {
            bottleneck_rows[[bottleneck_index]] <- data.frame(
              Shape_code = shape_name,
              Shape = unname(shape_labels[[shape_name]]),
              Sample_size = sample_size,
              Repetition = repetition,
              Method = method_name,
              Homology_dimension = homology_dimension,
              Success = FALSE,
              Bottleneck_distance = NA_real_,
              Occurrence_diameter = occurrence_result$point_cloud_diameter,
              Normalized_bottleneck_distance = NA_real_,
              Error_message = paste(
                na.omit(c(
                  occurrence_result$error_message,
                  method_result$error_message
                )),
                collapse = " | "
              ),
              stringsAsFactors = FALSE
            )
            next
          }

          bottleneck_result <- calculate_bottleneck_safe(
            occurrence_diagram = occurrence_result$diagram,
            method_diagram = method_result$diagram,
            dimension = homology_dimension
          )

          occurrence_diameter <- occurrence_result$point_cloud_diameter

          normalized_distance <- if (
            isTRUE(bottleneck_result$success) &&
              is.finite(occurrence_diameter) &&
              occurrence_diameter > 0
          ) {
            bottleneck_result$distance / occurrence_diameter
          } else {
            NA_real_
          }

          bottleneck_rows[[bottleneck_index]] <- data.frame(
            Shape_code = shape_name,
            Shape = unname(shape_labels[[shape_name]]),
            Sample_size = sample_size,
            Repetition = repetition,
            Method = method_name,
            Homology_dimension = homology_dimension,
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
}

bottleneck_replicates <- do.call(
  rbind,
  bottleneck_rows
)

rownames(bottleneck_replicates) <- NULL

write.csv(
  bottleneck_replicates,
  file = bottleneck_replicate_file,
  row.names = FALSE
)

# ============================================================
# Mean +/- SD summaries across the ten repetitions
# ============================================================

summarise_bottleneck_group <- function(group_data) {
  successful_data <- group_data[
    group_data$Success &
      is.finite(group_data$Bottleneck_distance),
    ,
    drop = FALSE
  ]

  raw_mean <- if (nrow(successful_data) > 0L) {
    mean(successful_data$Bottleneck_distance)
  } else {
    NA_real_
  }

  raw_sd <- safe_sd(
    successful_data$Bottleneck_distance
  )

  normalized_mean <- if (nrow(successful_data) > 0L) {
    mean(
      successful_data$Normalized_bottleneck_distance,
      na.rm = TRUE
    )
  } else {
    NA_real_
  }

  normalized_sd <- safe_sd(
    successful_data$Normalized_bottleneck_distance
  )

  data.frame(
    Repetitions_requested = number_of_repetitions,
    Repetitions_successful = nrow(successful_data),
    Mean_bottleneck_distance = raw_mean,
    SD_bottleneck_distance = raw_sd,
    Mean_plus_minus_SD = format_mean_sd(
      raw_mean,
      raw_sd
    ),
    Mean_normalized_bottleneck = normalized_mean,
    SD_normalized_bottleneck = normalized_sd,
    Mean_normalized_plus_minus_SD = format_mean_sd(
      normalized_mean,
      normalized_sd
    ),
    Minimum_bottleneck_distance = if (nrow(successful_data) > 0L) {
      min(successful_data$Bottleneck_distance)
    } else {
      NA_real_
    },
    Maximum_bottleneck_distance = if (nrow(successful_data) > 0L) {
      max(successful_data$Bottleneck_distance)
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
}

scenario_group_keys <- unique(
  bottleneck_replicates[
    ,
    c(
      "Shape_code",
      "Shape",
      "Sample_size",
      "Method",
      "Homology_dimension"
    )
  ]
)

bottleneck_summary_rows <- vector(
  mode = "list",
  length = nrow(scenario_group_keys)
)

for (group_index in seq_len(nrow(scenario_group_keys))) {
  group_key <- scenario_group_keys[group_index, , drop = FALSE]

  group_data <- bottleneck_replicates[
    bottleneck_replicates$Shape_code == group_key$Shape_code &
      bottleneck_replicates$Sample_size == group_key$Sample_size &
      bottleneck_replicates$Method == group_key$Method &
      bottleneck_replicates$Homology_dimension ==
        group_key$Homology_dimension,
    ,
    drop = FALSE
  ]

  bottleneck_summary_rows[[group_index]] <- cbind(
    group_key,
    summarise_bottleneck_group(group_data)
  )
}

bottleneck_summary <- do.call(
  rbind,
  bottleneck_summary_rows
)

rownames(bottleneck_summary) <- NULL

bottleneck_summary$Method <- factor(
  bottleneck_summary$Method,
  levels = method_order
)

bottleneck_summary <- bottleneck_summary[
  order(
    match(bottleneck_summary$Shape_code, expected_shape_names),
    bottleneck_summary$Sample_size,
    bottleneck_summary$Homology_dimension,
    bottleneck_summary$Method
  ),
  ,
  drop = FALSE
]

bottleneck_summary$Method <- as.character(
  bottleneck_summary$Method
)

write.csv(
  bottleneck_summary,
  file = bottleneck_summary_file,
  row.names = FALSE
)

# Pooled overall summaries by method and homology dimension. Raw values
# are retained, but the occurrence-diameter-normalised values are more
# suitable for pooling across shapes with different spatial scales.
overall_group_keys <- unique(
  bottleneck_replicates[
    ,
    c(
      "Method",
      "Homology_dimension"
    )
  ]
)

overall_summary_rows <- vector(
  mode = "list",
  length = nrow(overall_group_keys)
)

for (group_index in seq_len(nrow(overall_group_keys))) {
  group_key <- overall_group_keys[group_index, , drop = FALSE]

  group_data <- bottleneck_replicates[
    bottleneck_replicates$Method == group_key$Method &
      bottleneck_replicates$Homology_dimension ==
        group_key$Homology_dimension,
    ,
    drop = FALSE
  ]

  successful_data <- group_data[
    group_data$Success &
      is.finite(group_data$Bottleneck_distance),
    ,
    drop = FALSE
  ]

  raw_mean <- if (nrow(successful_data) > 0L) {
    mean(successful_data$Bottleneck_distance)
  } else {
    NA_real_
  }

  raw_sd <- safe_sd(
    successful_data$Bottleneck_distance
  )

  normalized_mean <- if (nrow(successful_data) > 0L) {
    mean(
      successful_data$Normalized_bottleneck_distance,
      na.rm = TRUE
    )
  } else {
    NA_real_
  }

  normalized_sd <- safe_sd(
    successful_data$Normalized_bottleneck_distance
  )

  overall_summary_rows[[group_index]] <- data.frame(
    Method = group_key$Method,
    Homology_dimension = group_key$Homology_dimension,
    Number_of_successful_comparisons = nrow(successful_data),
    Mean_raw_bottleneck = raw_mean,
    SD_raw_bottleneck = raw_sd,
    Mean_raw_plus_minus_SD = format_mean_sd(
      raw_mean,
      raw_sd
    ),
    Mean_normalized_bottleneck = normalized_mean,
    SD_normalized_bottleneck = normalized_sd,
    Mean_normalized_plus_minus_SD = format_mean_sd(
      normalized_mean,
      normalized_sd
    ),
    stringsAsFactors = FALSE
  )
}

bottleneck_overall_summary <- do.call(
  rbind,
  overall_summary_rows
)

rownames(bottleneck_overall_summary) <- NULL

write.csv(
  bottleneck_overall_summary,
  file = bottleneck_overall_file,
  row.names = FALSE
)

# ============================================================
# Matched filled-ellipse reference helpers
# ============================================================

make_positive_definite <- function(covariance_matrix) {
  covariance_matrix <- as.matrix(covariance_matrix)
  covariance_matrix <- (
    covariance_matrix + t(covariance_matrix)
  ) / 2

  eigen_decomposition <- eigen(
    covariance_matrix,
    symmetric = TRUE
  )

  largest_eigenvalue <- max(
    eigen_decomposition$values
  )

  eigenvalue_floor <- max(
    largest_eigenvalue * 1e-10,
    .Machine$double.eps
  )

  adjusted_values <- pmax(
    eigen_decomposition$values,
    eigenvalue_floor
  )

  eigen_decomposition$vectors %*%
    diag(adjusted_values, nrow = length(adjusted_values)) %*%
    t(eigen_decomposition$vectors)
}

generate_exact_matched_ellipse <- function(points, seed) {
  points <- standardize_axis_names(points)
  number_of_points <- nrow(points)
  dimensionality <- ncol(points)

  if (dimensionality != 2L) {
    stop("Matched filled-ellipse generation currently requires 2D data.")
  }

  target_centroid <- colMeans(points)
  target_covariance <- make_positive_definite(
    stats::cov(points)
  )

  set.seed(seed)

  theta <- stats::runif(
    number_of_points,
    min = 0,
    max = 2 * pi
  )

  radius <- sqrt(
    stats::runif(number_of_points)
  )

  unit_disk <- cbind(
    radius * cos(theta),
    radius * sin(theta)
  )

  # Centre exactly, then whiten using the realised sample covariance.
  # The subsequent linear transformation gives the null cloud the same
  # realised centroid and covariance as the observed cloud, up to
  # floating-point precision.
  unit_disk <- sweep(
    unit_disk,
    MARGIN = 2,
    STATS = colMeans(unit_disk),
    FUN = "-"
  )

  unit_covariance <- make_positive_definite(
    stats::cov(unit_disk)
  )

  unit_cholesky <- chol(unit_covariance)
  whitened_disk <- unit_disk %*% solve(unit_cholesky)

  target_cholesky <- chol(target_covariance)
  ellipse_points <- whitened_disk %*% target_cholesky

  ellipse_points <- sweep(
    ellipse_points,
    MARGIN = 2,
    STATS = target_centroid,
    FUN = "+"
  )

  ellipse_points <- standardize_axis_names(
    ellipse_points
  )

  centroid_error <- max(
    abs(colMeans(ellipse_points) - target_centroid)
  )

  covariance_error <- max(
    abs(stats::cov(ellipse_points) - target_covariance)
  )

  list(
    points = ellipse_points,
    target_centroid = target_centroid,
    target_covariance = target_covariance,
    centroid_error = centroid_error,
    covariance_error = covariance_error
  )
}

# ============================================================
# Run or resume matched-ellipse reference analysis
# ============================================================

if (
  resume_from_checkpoint &&
    file.exists(null_checkpoint_file)
) {
  null_checkpoint <- readRDS(
    null_checkpoint_file
  )

  if (!identical(
    null_checkpoint$analysis_settings_signature,
    analysis_settings_signature
  )) {
    stop(
      "The existing null checkpoint was produced from different inputs ",
      "or PH settings. Use a fresh output directory or remove it."
    )
  }

  if (
    is.null(null_checkpoint$null_settings_signature) ||
      !identical(
        null_checkpoint$null_settings_signature,
        null_settings_signature
      )
  ) {
    stop(
      "The existing null checkpoint was produced with a different ",
      "matched-reference target configuration."
    )
  }

  null_results <- null_checkpoint$results

  message(
    "Loaded compatible null checkpoint containing ",
    length(null_results),
    " completed observed-cloud null analyses."
  )
} else {
  null_results <- list()
}

for (shape_name in names(null_target_dimensions)) {
  target_dimension <- as.integer(
    null_target_dimensions[[shape_name]]
  )

  for (sample_size in expected_sample_sizes) {
    null_scenario_index <- null_scenario_index_for(
      shape_name = shape_name,
      sample_size = sample_size
    )
    scenario_name <- paste(shape_name, sample_size, sep = "_")

    for (source_name in source_order) {
      # When n = 300, every occurrence repetition is the same complete
      # occurrence cloud. Analyse that unique occurrence cloud once rather
      # than creating ten artificial copies. All estimator clouds retain
      # ten independently subsampled repetitions.
      repetitions_to_analyse <- if (
        identical(source_name, "Occurrence") &&
          sample_size == ph_sample_size
      ) {
        1L
      } else {
        seq_len(number_of_repetitions)
      }

      for (repetition in repetitions_to_analyse) {
        null_key <- paste(
          scenario_name,
          paste0("rep", repetition),
          source_to_key(source_name),
          paste0("H", target_dimension),
          sep = "__"
        )

        if (null_key %in% names(null_results)) {
          existing_null_result <- null_results[[null_key]]
          existing_null_complete <- (
            isTRUE(existing_null_result$observed_ph_success) &&
              isTRUE(existing_null_result$complete_null_set)
          )

          if (existing_null_complete) {
            message("Skipping successful null analysis: ", null_key)
            next
          }

          if (!retry_incomplete_nulls) {
            message("Skipping incomplete null analysis: ", null_key)
            next
          }

          message("Retrying incomplete null analysis: ", null_key)
        }

        message(
          "Matched-ellipse nulls: ",
          shape_labels[[shape_name]],
          ", n = ",
          sample_size,
          ", repetition ",
          repetition,
          ", ",
          source_name,
          ", H",
          target_dimension,
          "..."
        )

        observed_key <- scenario_repetition_source_key(
          scenario_name,
          repetition,
          source_name
        )

        observed_ph_result <- persistence_results[[observed_key]]
        observed_points <- get_subsample_points(
          shape_name = shape_name,
          sample_size = sample_size,
          repetition = repetition,
          source_name = source_name
        )

        observed_max_persistence <- if (
          isTRUE(observed_ph_result$success)
        ) {
          max_finite_persistence(
            observed_ph_result$diagram,
            target_dimension
          )
        } else {
          NA_real_
        }

        null_replicates <- vector(
          mode = "list",
          length = number_of_null_replicates
        )

        for (null_repetition in seq_len(number_of_null_replicates)) {
          current_null_seed <- as.integer(
            null_master_seed +
              null_scenario_index * 100000L +
              match(source_name, source_order) * 10000L +
              repetition * 100L +
              null_repetition
          )

          null_generation <- tryCatch(
            generate_exact_matched_ellipse(
              points = observed_points,
              seed = current_null_seed
            ),
            error = function(error_condition) {
              list(
                points = NULL,
                target_centroid = rep(NA_real_, 2L),
                target_covariance = matrix(
                  NA_real_,
                  nrow = 2L,
                  ncol = 2L
                ),
                centroid_error = NA_real_,
                covariance_error = NA_real_,
                generation_error = conditionMessage(error_condition)
              )
            }
          )

          if (is.null(null_generation$points)) {
            null_replicates[[null_repetition]] <- list(
              null_repetition = null_repetition,
              seed = current_null_seed,
              success = FALSE,
              max_persistence = NA_real_,
              runtime_seconds = NA_real_,
              centroid_error = null_generation$centroid_error,
              covariance_error = null_generation$covariance_error,
              failure_type = "null generation failure",
              error_message = null_generation$generation_error
            )
            next
          }

          null_ph_result <- calculate_persistence_with_timeout(
            points = null_generation$points,
            maximum_dimension = target_dimension
          )

          null_max_persistence <- if (isTRUE(null_ph_result$success)) {
            max_finite_persistence(
              null_ph_result$diagram,
              target_dimension
            )
          } else {
            NA_real_
          }

          null_replicates[[null_repetition]] <- list(
            null_repetition = null_repetition,
            seed = current_null_seed,
            success = null_ph_result$success,
            max_persistence = null_max_persistence,
            runtime_seconds = null_ph_result$runtime_seconds,
            centroid_error = null_generation$centroid_error,
            covariance_error = null_generation$covariance_error,
            failure_type = null_ph_result$failure_type,
            error_message = null_ph_result$error_message
          )
        }

        successful_nulls <- vapply(
          null_replicates,
          function(x) isTRUE(x$success),
          logical(1)
        )

        null_max_values <- vapply(
          null_replicates,
          function(x) x$max_persistence,
          numeric(1)
        )

        complete_null_set <- all(successful_nulls)

        largest_null_persistence <- if (complete_null_set) {
          max(null_max_values)
        } else {
          NA_real_
        }

        exceeds_all_nulls <- if (
          complete_null_set &&
            is.finite(observed_max_persistence)
        ) {
          observed_max_persistence > largest_null_persistence
        } else {
          NA
        }

        monte_carlo_p_value <- if (
          complete_null_set &&
            is.finite(observed_max_persistence)
        ) {
          (
            1 + sum(null_max_values >= observed_max_persistence)
          ) / (
            number_of_null_replicates + 1
          )
        } else {
          NA_real_
        }

        null_results[[null_key]] <- list(
          key = null_key,
          shape_code = shape_name,
          shape = unname(shape_labels[[shape_name]]),
          sample_size = sample_size,
          repetition = repetition,
          source = source_name,
          target_dimension = target_dimension,
          observed_ph_success = observed_ph_result$success,
          observed_max_persistence = observed_max_persistence,
          null_replicates = null_replicates,
          number_of_successful_nulls = sum(successful_nulls),
          complete_null_set = complete_null_set,
          largest_null_persistence = largest_null_persistence,
          exceeds_all_nulls = exceeds_all_nulls,
          monte_carlo_p_value = monte_carlo_p_value
        )

        null_checkpoint <- list(
          analysis_settings_signature = analysis_settings_signature,
          null_settings_signature = null_settings_signature,
          results = null_results,
          last_updated = as.character(Sys.time())
        )

        saveRDS(
          null_checkpoint,
          file = null_checkpoint_file,
          version = 3
        )
      }
    }
  }
}

# ============================================================
# Save matched-reference replicate and observed-cloud tables
# ============================================================

null_replicate_rows <- list()
null_observed_rows <- list()
null_replicate_index <- 0L
null_observed_index <- 0L

for (null_result in null_results) {
  null_observed_index <- null_observed_index + 1L

  null_observed_rows[[null_observed_index]] <- data.frame(
    Key = null_result$key,
    Shape_code = null_result$shape_code,
    Shape = null_result$shape,
    Sample_size = null_result$sample_size,
    Repetition = null_result$repetition,
    Source = null_result$source,
    Target_dimension = null_result$target_dimension,
    Observed_PH_success = null_result$observed_ph_success,
    Observed_max_persistence = null_result$observed_max_persistence,
    Number_of_successful_nulls = null_result$number_of_successful_nulls,
    Complete_null_set = null_result$complete_null_set,
    Largest_null_persistence = null_result$largest_null_persistence,
    Exceeds_all_nulls = null_result$exceeds_all_nulls,
    Monte_Carlo_p_value = null_result$monte_carlo_p_value,
    stringsAsFactors = FALSE
  )

  for (null_replicate in null_result$null_replicates) {
    null_replicate_index <- null_replicate_index + 1L

    null_replicate_rows[[null_replicate_index]] <- data.frame(
      Key = null_result$key,
      Shape_code = null_result$shape_code,
      Shape = null_result$shape,
      Sample_size = null_result$sample_size,
      Repetition = null_result$repetition,
      Source = null_result$source,
      Target_dimension = null_result$target_dimension,
      Null_repetition = null_replicate$null_repetition,
      Null_seed = null_replicate$seed,
      Success = null_replicate$success,
      Null_max_persistence = null_replicate$max_persistence,
      Runtime_seconds = null_replicate$runtime_seconds,
      Centroid_matching_error = null_replicate$centroid_error,
      Covariance_matching_error = null_replicate$covariance_error,
      Failure_type = null_replicate$failure_type,
      Error_message = null_replicate$error_message,
      stringsAsFactors = FALSE
    )
  }
}

null_replicate_table <- do.call(
  rbind,
  null_replicate_rows
)

null_observed_table <- do.call(
  rbind,
  null_observed_rows
)

rownames(null_replicate_table) <- NULL
rownames(null_observed_table) <- NULL

write.csv(
  null_replicate_table,
  file = null_replicate_file,
  row.names = FALSE
)

write.csv(
  null_observed_table,
  file = null_observed_file,
  row.names = FALSE
)

# ============================================================
# Matched-reference exceedance summaries
# ============================================================

exceedance_group_keys <- unique(
  null_observed_table[
    ,
    c(
      "Shape_code",
      "Shape",
      "Sample_size",
      "Source",
      "Target_dimension"
    )
  ]
)

exceedance_summary_rows <- vector(
  mode = "list",
  length = nrow(exceedance_group_keys)
)

for (group_index in seq_len(nrow(exceedance_group_keys))) {
  group_key <- exceedance_group_keys[group_index, , drop = FALSE]

  group_data <- null_observed_table[
    null_observed_table$Shape_code == group_key$Shape_code &
      null_observed_table$Sample_size == group_key$Sample_size &
      null_observed_table$Source == group_key$Source &
      null_observed_table$Target_dimension ==
        group_key$Target_dimension,
    ,
    drop = FALSE
  ]

  complete_data <- group_data[
    group_data$Complete_null_set &
      !is.na(group_data$Exceeds_all_nulls),
    ,
    drop = FALSE
  ]

  observed_mean <- if (nrow(complete_data) > 0L) {
    mean(complete_data$Observed_max_persistence)
  } else {
    NA_real_
  }

  observed_sd <- safe_sd(
    complete_data$Observed_max_persistence
  )

  null_threshold_mean <- if (nrow(complete_data) > 0L) {
    mean(complete_data$Largest_null_persistence)
  } else {
    NA_real_
  }

  null_threshold_sd <- safe_sd(
    complete_data$Largest_null_persistence
  )

  is_expected_feature <- (
    group_key$Shape_code %in% expected_feature_shapes
  )

  number_exceeding <- if (nrow(complete_data) > 0L) {
    sum(complete_data$Exceeds_all_nulls)
  } else {
    NA_integer_
  }

  exceedance_proportion <- if (nrow(complete_data) > 0L) {
    mean(complete_data$Exceeds_all_nulls)
  } else {
    NA_real_
  }

  exceedance_summary_rows[[group_index]] <- data.frame(
    Shape_code = group_key$Shape_code,
    Shape = group_key$Shape,
    Sample_size = group_key$Sample_size,
    Source = group_key$Source,
    Target_dimension = group_key$Target_dimension,
    Feature_status = if (is_expected_feature) {
      "expected non-trivial feature"
    } else {
      "unexpected feature in simple generating region"
    },
    Point_clouds_requested = nrow(group_data),
    Point_clouds_with_complete_nulls = nrow(complete_data),
    Number_exceeding_matched_null = number_exceeding,
    Exceedance_proportion = exceedance_proportion,
    Mean_observed_max_persistence = observed_mean,
    SD_observed_max_persistence = observed_sd,
    Observed_persistence_mean_plus_minus_SD = format_mean_sd(
      observed_mean,
      observed_sd
    ),
    Mean_largest_null_persistence = null_threshold_mean,
    SD_largest_null_persistence = null_threshold_sd,
    Null_threshold_mean_plus_minus_SD = format_mean_sd(
      null_threshold_mean,
      null_threshold_sd
    ),
    stringsAsFactors = FALSE
  )
}

matched_reference_exceedance_summary <- do.call(
  rbind,
  exceedance_summary_rows
)

rownames(matched_reference_exceedance_summary) <- NULL

matched_reference_exceedance_summary <- matched_reference_exceedance_summary[
  order(
    match(matched_reference_exceedance_summary$Shape_code, expected_shape_names),
    matched_reference_exceedance_summary$Sample_size,
    match(matched_reference_exceedance_summary$Source, source_order),
    matched_reference_exceedance_summary$Target_dimension
  ),
  ,
  drop = FALSE
]

write.csv(
  matched_reference_exceedance_summary,
  file = matched_reference_exceedance_file,
  row.names = FALSE
)

# Dedicated negative-control table: H1 exceedance in the three 2-D
# generating regions that are topologically simple in H1.
simple_control_exceedance_summary <- matched_reference_exceedance_summary[
  matched_reference_exceedance_summary$Shape_code %in% simple_control_shapes &
    matched_reference_exceedance_summary$Target_dimension == 1L,
  ,
  drop = FALSE
]

write.csv(
  simple_control_exceedance_summary,
  file = simple_control_exceedance_file,
  row.names = FALSE
)

# ============================================================
# Figure helpers
# ============================================================

make_diagram_data <- function(
    shape_name,
    sample_size,
    repetition,
    source_name,
    dimension,
    target_label
) {
  scenario_name <- paste(shape_name, sample_size, sep = "_")
  result_key <- scenario_repetition_source_key(
    scenario_name,
    repetition,
    source_name
  )

  result <- persistence_results[[result_key]]

  if (!isTRUE(result$success)) {
    return(data.frame(
      Target = character(0),
      Source = character(0),
      dimension = numeric(0),
      birth = numeric(0),
      death = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  diagram <- finite_diagram(
    result$diagram
  )

  diagram <- diagram[
    diagram[, "dimension"] == dimension,
    ,
    drop = FALSE
  ]

  if (nrow(diagram) == 0L) {
    return(data.frame(
      Target = character(0),
      Source = character(0),
      dimension = numeric(0),
      birth = numeric(0),
      death = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    Target = target_label,
    Source = source_name,
    dimension = diagram[, "dimension"],
    birth = diagram[, "birth"],
    death = diagram[, "death"],
    stringsAsFactors = FALSE
  )
}

build_representative_diagram_plot <- function() {
  target_definitions <- list(
    list(
      shape_name = "annulus",
      dimension = 1L,
      label = "Annulus: H1"
    ),
    list(
      shape_name = "two_balls",
      dimension = 0L,
      label = "Two separated disks: finite H0"
    )
  )

  # ggplot2 4.0 does not permit free facet scales together with
  # coord_equal(), because coord_equal() imposes a fixed aspect ratio.
  # We therefore construct one equal-axis faceted plot per topological
  # target and combine the two target plots vertically with patchwork.
  target_plots <- vector(
    mode = "list",
    length = length(target_definitions)
  )

  for (target_index in seq_along(target_definitions)) {
    target <- target_definitions[[target_index]]

    source_rows <- list()
    source_index <- 0L

    for (source_name in source_order) {
      source_index <- source_index + 1L

      source_rows[[source_index]] <- make_diagram_data(
        shape_name = target$shape_name,
        sample_size = representative_sample_size,
        repetition = representative_repetition,
        source_name = source_name,
        dimension = target$dimension,
        target_label = target$label
      )
    }

    target_data <- do.call(
      rbind,
      source_rows
    )

    # Preserve every source panel even when a source has no finite
    # feature in the selected homology dimension.
    if (is.null(target_data) || nrow(target_data) == 0L) {
      target_data <- data.frame(
        Target = character(0),
        Source = character(0),
        dimension = numeric(0),
        birth = numeric(0),
        death = numeric(0),
        stringsAsFactors = FALSE
      )
    }

    target_data$Source <- factor(
      target_data$Source,
      levels = source_order
    )

    finite_values <- c(
      target_data$birth,
      target_data$death
    )

    finite_values <- finite_values[
      is.finite(finite_values)
    ]

    maximum_value <- if (length(finite_values) > 0L) {
      max(finite_values)
    } else {
      1
    }

    maximum_value <- max(
      maximum_value * 1.05,
      1e-6
    )

    range_data <- expand.grid(
      Source = factor(
        source_order,
        levels = source_order
      ),
      point = c("minimum", "maximum"),
      stringsAsFactors = FALSE
    )

    range_data$birth <- rep(
      c(0, maximum_value),
      each = length(source_order)
    )

    range_data$death <- rep(
      c(0, maximum_value),
      each = length(source_order)
    )

    target_plot <- ggplot(
      target_data,
      aes(x = birth, y = death)
    ) +
      geom_blank(
        data = range_data,
        aes(x = birth, y = death)
      ) +
      geom_abline(
        slope = 1,
        intercept = 0,
        linewidth = 0.35,
        linetype = "dashed",
        colour = "grey45"
      ) +
      geom_point(
        aes(colour = Source),
        size = 1.15,
        alpha = 0.80,
        na.rm = TRUE
      ) +
      scale_colour_manual(
        values = source_colours,
        guide = "none",
        drop = FALSE
      ) +
      facet_grid(
        cols = vars(Source),
        drop = FALSE
      ) +
      coord_equal(
        xlim = c(0, maximum_value),
        ylim = c(0, maximum_value),
        expand = FALSE
      ) +
      labs(
        title = target$label,
        x = "Birth",
        y = "Death"
      ) +
      theme_bw(base_size = 8.5) +
      theme(
        plot.title = element_text(
          face = "bold",
          size = 8.5,
          hjust = 0
        ),
        strip.background = element_rect(fill = "grey92"),
        strip.text = element_text(face = "bold", size = 7.5),
        panel.grid = element_blank(),
        axis.text = element_text(size = 6.8),
        axis.title = element_text(size = 8)
      )

    target_plots[[target_index]] <- target_plot
  }

  patchwork::wrap_plots(
    target_plots,
    ncol = 1,
    guides = "collect"
  )
}

build_bottleneck_plot <- function() {
  target_summary <- bottleneck_summary[
    (
      bottleneck_summary$Shape_code == "annulus" &
        bottleneck_summary$Homology_dimension == 1L
    ) |
      (
        bottleneck_summary$Shape_code == "two_balls" &
          bottleneck_summary$Homology_dimension == 0L
      ),
    ,
    drop = FALSE
  ]

  target_summary$Target <- ifelse(
    target_summary$Shape_code == "annulus",
    "Annulus: H1",
    "Two separated disks: finite H0"
  )

  target_summary$Method <- factor(
    target_summary$Method,
    levels = method_order
  )

  target_summary$Lower_SD <- pmax(
    0,
    target_summary$Mean_bottleneck_distance -
      ifelse(
        is.finite(target_summary$SD_bottleneck_distance),
        target_summary$SD_bottleneck_distance,
        0
      )
  )

  target_summary$Upper_SD <- (
    target_summary$Mean_bottleneck_distance +
      ifelse(
        is.finite(target_summary$SD_bottleneck_distance),
        target_summary$SD_bottleneck_distance,
        0
      )
  )

  ggplot(
    target_summary,
    aes(
      x = Sample_size,
      y = Mean_bottleneck_distance,
      colour = Method,
      shape = Method,
      group = Method
    )
  ) +
    geom_errorbar(
      aes(
        ymin = Lower_SD,
        ymax = Upper_SD
      ),
      width = 45,
      linewidth = 0.45
    ) +
    geom_line(linewidth = 0.55) +
    geom_point(size = 2.0) +
    scale_colour_manual(values = method_colours) +
    scale_shape_manual(values = method_shapes) +
    scale_x_continuous(
      breaks = expected_sample_sizes
    ) +
    facet_wrap(
      vars(Target),
      scales = "free_y",
      nrow = 1
    ) +
    labs(
      x = "Occurrence sample size",
      y = "Bottleneck distance\n(mean +/- SD)",
      colour = NULL,
      shape = NULL
    ) +
    theme_bw(base_size = 9) +
    theme(
      strip.background = element_rect(fill = "grey92"),
      strip.text = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
}

build_exceedance_plot <- function() {
  exceedance_data <- matched_reference_exceedance_summary[
    matched_reference_exceedance_summary$Source %in% method_order &
      matched_reference_exceedance_summary$Shape_code %in% expected_feature_shapes,
    ,
    drop = FALSE
  ]

  exceedance_data$Target <- unname(
    null_target_labels[exceedance_data$Shape_code]
  )

  exceedance_data$Method <- factor(
    exceedance_data$Source,
    levels = method_order
  )

  ggplot(
    exceedance_data,
    aes(
      x = Sample_size,
      y = Exceedance_proportion,
      colour = Method,
      shape = Method,
      group = Method
    )
  ) +
    geom_line(linewidth = 0.55) +
    geom_point(size = 2.0) +
    scale_colour_manual(values = method_colours) +
    scale_shape_manual(values = method_shapes) +
    scale_x_continuous(
      breaks = expected_sample_sizes
    ) +
    scale_y_continuous(
      limits = c(0, 1),
      breaks = seq(0, 1, by = 0.25)
    ) +
    facet_wrap(
      vars(Target),
      nrow = 1
    ) +
    labs(
      x = "Occurrence sample size",
      y = "Matched-reference exceedance proportion",
      colour = NULL,
      shape = NULL
    ) +
    theme_bw(base_size = 9) +
    theme(
      strip.background = element_rect(fill = "grey92"),
      strip.text = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position = "bottom"
    )
}

# ============================================================
# Build and save synthetic topology summary figure
# ============================================================

message("Constructing synthetic topology summary figure...")

panel_a <- build_representative_diagram_plot()
panel_b <- build_bottleneck_plot()
panel_c <- build_exceedance_plot()

# Treat the internally nested Panel a as one graphical object.
panel_a_block <- patchwork::wrap_elements(
  full = panel_a
) +
  patchwork::plot_annotation(
    title = "a",
    theme = theme(
      plot.title = element_text(
        face = "bold",
        size = 12,
        hjust = 0
      ),
      plot.margin = margin(0, 0, 0, 0)
    )
  )

panel_b_tagged <- panel_b +
  labs(tag = "b") +
  theme(
    plot.tag = element_text(
      face = "bold",
      size = 12
    )
  )

panel_c_tagged <- panel_c +
  labs(tag = "c") +
  theme(
    plot.tag = element_text(
      face = "bold",
      size = 12
    )
  )

bottom_block <- patchwork::wrap_plots(
  panel_b_tagged,
  panel_c_tagged,
  ncol = 2,
  guides = "collect"
)

synthetic_topology_figure <- patchwork::wrap_plots(
  panel_a_block,
  bottom_block,
  ncol = 1,
  heights = c(1.55, 1),
  guides = "collect"
) &
  theme(
    legend.position = "bottom"
  )

ggsave(
  filename = synthetic_topology_pdf,
  plot = synthetic_topology_figure,
  width = figure_width_inches,
  height = figure_height_inches,
  units = "in",
  device = grDevices::cairo_pdf
)

ggsave(
  filename = synthetic_topology_tiff,
  plot = synthetic_topology_figure,
  width = figure_width_inches,
  height = figure_height_inches,
  units = "in",
  dpi = figure_tiff_dpi,
  compression = "lzw"
)

ggsave(
  filename = synthetic_topology_png,
  plot = synthetic_topology_figure,
  width = figure_width_inches,
  height = figure_height_inches,
  units = "in",
  dpi = 300
)
# ============================================================
# Supplementary bottleneck figure for all shapes and dimensions
# ============================================================

supplementary_bottleneck_data <- bottleneck_summary
supplementary_bottleneck_data$Method <- factor(
  supplementary_bottleneck_data$Method,
  levels = method_order
)

supplementary_bottleneck_data$Homology <- paste0(
  "H",
  supplementary_bottleneck_data$Homology_dimension
)

supplementary_bottleneck_data$Lower_SD <- pmax(
  0,
  supplementary_bottleneck_data$Mean_bottleneck_distance -
    ifelse(
      is.finite(supplementary_bottleneck_data$SD_bottleneck_distance),
      supplementary_bottleneck_data$SD_bottleneck_distance,
      0
    )
)

supplementary_bottleneck_data$Upper_SD <- (
  supplementary_bottleneck_data$Mean_bottleneck_distance +
    ifelse(
      is.finite(supplementary_bottleneck_data$SD_bottleneck_distance),
      supplementary_bottleneck_data$SD_bottleneck_distance,
      0
    )
)

supplementary_bottleneck_plot <- ggplot(
  supplementary_bottleneck_data,
  aes(
    x = Sample_size,
    y = Mean_bottleneck_distance,
    colour = Method,
    shape = Method,
    group = Method
  )
) +
  geom_errorbar(
    aes(
      ymin = Lower_SD,
      ymax = Upper_SD
    ),
    width = 45,
    linewidth = 0.35
  ) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 1.7) +
  scale_colour_manual(values = method_colours) +
  scale_shape_manual(values = method_shapes) +
  scale_x_continuous(breaks = expected_sample_sizes) +
  facet_grid(
    rows = vars(Shape),
    cols = vars(Homology),
    scales = "free_y"
  ) +
  labs(
    x = "Occurrence sample size",
    y = "Bottleneck distance (mean +/- SD)",
    colour = NULL,
    shape = NULL
  ) +
  theme_bw(base_size = 8.5) +
  theme(
    strip.background = element_rect(fill = "grey92"),
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    legend.position = "bottom"
  )

ggsave(
  filename = supplementary_bottleneck_pdf,
  plot = supplementary_bottleneck_plot,
  width = 8.2,
  height = 10.0,
  units = "in",
  device = grDevices::cairo_pdf
)

# ============================================================
# Supplementary representative diagrams for all shapes
# ============================================================

pdf(
  file = supplementary_diagrams_pdf,
  width = 10,
  height = 6.8,
  onefile = TRUE
)

for (shape_name in expected_shape_names) {
  page_rows <- list()
  page_index <- 0L

  for (homology_dimension in 0:1) {
    for (source_name in source_order) {
      page_index <- page_index + 1L
      page_rows[[page_index]] <- make_diagram_data(
        shape_name = shape_name,
        sample_size = representative_sample_size,
        repetition = representative_repetition,
        source_name = source_name,
        dimension = homology_dimension,
        target_label = paste0("H", homology_dimension)
      )
    }
  }

  page_data <- do.call(rbind, page_rows)
  page_data$Target <- factor(
    page_data$Target,
    levels = c("H0", "H1")
  )
  page_data$Source <- factor(
    page_data$Source,
    levels = source_order
  )

  maximum_value <- if (nrow(page_data) > 0L) {
    max(
      c(page_data$birth, page_data$death)[
        is.finite(c(page_data$birth, page_data$death))
      ]
    )
  } else {
    1
  }
  maximum_value <- max(maximum_value * 1.05, 1e-6)

  page_plot <- ggplot(
    page_data,
    aes(x = birth, y = death)
  ) +
    geom_blank(
      data = expand.grid(
        Target = factor(c("H0", "H1"), levels = c("H0", "H1")),
        Source = factor(source_order, levels = source_order),
        birth = c(0, maximum_value),
        death = c(0, maximum_value)
      ),
      aes(x = birth, y = death)
    ) +
    geom_abline(
      slope = 1,
      intercept = 0,
      linetype = "dashed",
      linewidth = 0.35,
      colour = "grey45"
    ) +
    geom_point(
      aes(colour = Source),
      size = 1.0,
      alpha = 0.8
    ) +
    scale_colour_manual(
      values = source_colours,
      guide = "none"
    ) +
    facet_grid(
      rows = vars(Target),
      cols = vars(Source)
    ) +
    coord_equal(
      xlim = c(0, maximum_value),
      ylim = c(0, maximum_value)
    ) +
    labs(
      title = paste0(
        shape_labels[[shape_name]],
        ": n = ",
        representative_sample_size,
        ", repetition ",
        representative_repetition
      ),
      x = "Birth",
      y = "Death"
    ) +
    theme_bw(base_size = 9) +
    theme(
      strip.background = element_rect(fill = "grey92"),
      strip.text = element_text(face = "bold"),
      panel.grid = element_blank()
    )

  print(page_plot)
}

dev.off()

# ============================================================
# Supplementary matched-reference figure
# ============================================================

null_plot_data <- null_observed_table[
  null_observed_table$Complete_null_set,
  ,
  drop = FALSE
]

null_plot_data$Target <- unname(
  null_target_labels[null_plot_data$Shape_code]
)

null_plot_data$Target <- factor(
  null_plot_data$Target,
  levels = unname(null_target_labels[names(null_target_dimensions)])
)

null_plot_data$Source <- factor(
  null_plot_data$Source,
  levels = source_order
)

supplementary_null_plot <- ggplot(
  null_plot_data,
  aes(
    x = Source,
    y = Observed_max_persistence,
    colour = Source
  )
) +
  geom_segment(
    aes(
      xend = Source,
      y = Largest_null_persistence,
      yend = Observed_max_persistence
    ),
    linewidth = 0.30,
    alpha = 0.45
  ) +
  geom_point(
    aes(y = Largest_null_persistence),
    shape = 1,
    size = 1.7
  ) +
  geom_point(size = 1.8) +
  scale_colour_manual(
    values = source_colours,
    guide = "none"
  ) +
  facet_grid(
    rows = vars(Target),
    cols = vars(Sample_size),
    scales = "free_y"
  ) +
  labs(
    x = NULL,
    y = "Maximum persistence",
    caption = paste(
      "Filled points: observed maximum persistence;",
      "open points: largest matched-ellipse null value."
    )
  ) +
  theme_bw(base_size = 8.5) +
  theme(
    strip.background = element_rect(fill = "grey92"),
    strip.text = element_text(face = "bold"),
    axis.text.x = element_text(angle = 35, hjust = 1),
    panel.grid.minor = element_blank()
  )

ggsave(
  filename = supplementary_null_pdf,
  plot = supplementary_null_plot,
  width = 9.0,
  height = 10.5,
  units = "in",
  device = grDevices::cairo_pdf
)

# ============================================================
# Supplementary simple-control H1 exceedance figure
# ============================================================

simple_control_plot_data <- simple_control_exceedance_summary

simple_control_plot_data$Source <- factor(
  simple_control_plot_data$Source,
  levels = source_order
)

simple_control_plot_data$Shape <- factor(
  simple_control_plot_data$Shape_code,
  levels = simple_control_shapes,
  labels = unname(shape_labels[simple_control_shapes])
)

supplementary_simple_control_plot <- ggplot(
  simple_control_plot_data,
  aes(
    x = Sample_size,
    y = Exceedance_proportion,
    colour = Source,
    shape = Source,
    group = Source
  )
) +
  geom_line(linewidth = 0.55) +
  geom_point(size = 2.0) +
  scale_colour_manual(values = source_colours) +
  scale_shape_manual(values = source_shapes) +
  scale_x_continuous(
    breaks = expected_sample_sizes
  ) +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.25)
  ) +
  facet_wrap(
    vars(Shape),
    nrow = 1
  ) +
  labs(
    x = "Occurrence sample size",
    y = "Unexpected H1 exceedance proportion",
    colour = NULL,
    shape = NULL,
    caption = paste(
      "An exceedance occurs when observed maximum H1 persistence is larger",
      "than the largest value from 20 matched filled-ellipse clouds."
    )
  ) +
  theme_bw(base_size = 9) +
  theme(
    strip.background = element_rect(fill = "grey92"),
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    legend.position = "bottom"
  )

ggsave(
  filename = supplementary_simple_control_pdf,
  plot = supplementary_simple_control_plot,
  width = 9.0,
  height = 3.5,
  units = "in",
  device = grDevices::cairo_pdf
)

# ============================================================
# Save metadata, notes, and session information
# ============================================================

run_metadata <- list(
  analysis_settings_signature = analysis_settings_signature,
  null_settings_signature = null_settings_signature,
  input_files = list(
    occurrence_archive_file = occurrence_archive_file,
    occurrence_archive_md5 = safe_md5(occurrence_archive_file),
    baseline_results_file = baseline_results_file,
    baseline_results_md5 = safe_md5(baseline_results_file)
  ),
  settings = list(
    ph_sample_size = ph_sample_size,
    number_of_repetitions = number_of_repetitions,
    maximum_homology_dimension = maximum_homology_dimension,
    ph_threshold = ph_threshold,
    ph_prime_field = ph_prime_field,
    ph_standardize = ph_standardize,
    ph_timeout_seconds = ph_timeout_seconds,
    number_of_null_replicates = number_of_null_replicates,
    null_target_dimensions = null_target_dimensions,
    simple_control_shapes = simple_control_shapes,
    expected_feature_shapes = expected_feature_shapes,
    null_seed_shape_block = null_seed_shape_block,
    topology_master_seed = topology_master_seed,
    null_master_seed = null_master_seed
  ),
  package_versions = list(
    R = R.version.string,
    hypervolume = installed_hypervolume_version,
    TDAstats = installed_tda_stats_version,
    TDA = installed_tda_version,
    R.utils = as.character(utils::packageVersion("R.utils")),
    ggplot2 = as.character(utils::packageVersion("ggplot2")),
    patchwork = as.character(utils::packageVersion("patchwork"))
  ),
  completed = as.character(Sys.time())
)

saveRDS(
  run_metadata,
  file = run_metadata_file,
  version = 3
)

analysis_notes <- c(
  "Synthetic topological analysis",
  "===============================",
  "",
  paste0("Equal PH sample size: ", ph_sample_size),
  paste0("Subsampling repetitions: ", number_of_repetitions),
  paste0("Matched-ellipse null replicates: ", number_of_null_replicates),
  paste0("PH timeout per calculation: ", ph_timeout_seconds, " seconds"),
  "",
  "Persistent homology was calculated on occurrence-cloud and fitted",
  "hypervolume point clouds. It was not calculated on a separate dense",
  "true-niche reference because synthetic niche topology is known by",
  "construction.",
  "",
  "For n = 300, the full occurrence cloud was used. For n = 900 and",
  "n = 1500, 300 occurrence points were sampled without replacement.",
  "Every fitted hypervolume was independently sampled to 300 points.",
  "All exact row indices are stored in topology_subsample_indices.rds.",
  "",
  "TDAstats::calculate_homology used Vietoris--Rips complexes, Euclidean",
  "distances, coefficient field Z/2Z, no coordinate standardisation, and",
  "the automatic full filtration threshold (threshold = -1).",
  "",
  "The single infinite H0 class was excluded before bottleneck distances",
  "and maximum finite persistence were calculated. Bottleneck distances",
  "were calculated separately for H0 and H1 using TDA::bottleneck.",
  "",
  "Mean +/- SD summaries are reported across the ten paired subsampling",
  "repetitions for each shape, sample size, method, and homology dimension.",
  "The pooled overall file includes raw and occurrence-diameter-normalised",
  "distances; the normalised values are preferable when pooling shapes with",
  "different spatial scales.",
  "",
  "Matched filled-ellipse diagnostics were run for all five 2-D shapes.",
  "H1 was evaluated for the spiral, ellipse, annulus, and banana, while",
  "finite H0 was evaluated for the two separated disks. Null clouds were",
  "transformed to match each observed cloud's realised centroid and",
  "covariance up to floating-point precision.",
  "",
  "For annulus H1 and two-disk finite H0, the matched-reference result is",
  "reported as an exceedance proportion. For the",
  "spiral, filled ellipse, and concave banana, H1 exceedance is an",
  "unexpected feature relative to the topologically simple generating",
  "region and is therefore reported as a negative-control diagnostic.",
  "The generic output columns Number_exceeding_matched_null and",
  "Exceedance_proportion apply to every shape. The term topological",
  "recovery is not used for these matched-reference results."
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
# Completion messages
# ============================================================

message("Script 04 synthetic topological analysis complete.")
message(
  "Subsample archive: ",
  normalizePath(subsample_archive_file, mustWork = FALSE)
)
message(
  "Persistence diagrams: ",
  normalizePath(persistence_diagrams_file, mustWork = FALSE)
)
message(
  "Bottleneck replicate table: ",
  normalizePath(bottleneck_replicate_file, mustWork = FALSE)
)
message(
  "Bottleneck mean +/- SD summary: ",
  normalizePath(bottleneck_summary_file, mustWork = FALSE)
)
message(
  "Overall mean +/- SD summary: ",
  normalizePath(bottleneck_overall_file, mustWork = FALSE)
)
message(
  "Matched-reference exceedance summary: ",
  normalizePath(matched_reference_exceedance_file, mustWork = FALSE)
)
message(
  "Simple-control H1 exceedance summary: ",
  normalizePath(simple_control_exceedance_file, mustWork = FALSE)
)
message(
  "Simple-control H1 figure: ",
  normalizePath(supplementary_simple_control_pdf, mustWork = FALSE)
)
message(
  "Synthetic topology figure PDF: ",
  normalizePath(synthetic_topology_pdf, mustWork = FALSE)
)
message(
  "Synthetic topology figure TIFF: ",
  normalizePath(synthetic_topology_tiff, mustWork = FALSE)
)
