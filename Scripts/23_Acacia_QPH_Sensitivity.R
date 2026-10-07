# ============================================================
# 23_Acacia_QPH_Sensitivity.R
# ============================================================
#
# PURPOSE
# -------
# Final revised QPH-only one-factor-at-a-time (OFAT) sensitivity analysis for
# the FIVE locked empirical Acacia species.
#


rm(list = ls())
gc()


# ============================================================
# Packages
# ============================================================

required_packages <- c(
  "hypervolume",
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
    "Install required package(s): ",
    paste(
      missing_packages,
      collapse = ", "
    )
  )
}

library(hypervolume)
library(terra)


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

geometry_directory <- file.path(
  analysis_root_directory,
  "02_Environmental_Geometry"
)

geographic_directory <- file.path(
  analysis_root_directory,
  "04_Geographic_Projection"
)

output_directory <- file.path(
  analysis_root_directory,
  "05_QPH_Sensitivity"
)

model_directory <- file.path(
  output_directory,
  "model_objects"
)

projection_raster_directory <- file.path(
  output_directory,
  "projection_rasters"
)

table_directory <- file.path(
  output_directory,
  "tables"
)

checkpoint_directory <- file.path(
  output_directory,
  "checkpoints"
)

for (
  directory in c(
    output_directory,
    model_directory,
    projection_raster_directory,
    table_directory,
    checkpoint_directory
  )
) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ============================================================
# Authoritative revised QPH implementation
# ============================================================

qph_core_file <- file.path(
  scripts_directory,
  "00_QPH_Core_Functions.R"
)

if (!file.exists(qph_core_file)) {
  stop(
    "Missing authoritative QPH core:\n  ",
    qph_core_file
  )
}

source(
  qph_core_file,
  local = FALSE
)

expected_qph_core_version <- "sqrtNB_q099_v1"

if (
  !exists(
    "QPH_CORE_VERSION",
    inherits = TRUE
  ) ||
    !identical(
      as.character(
        QPH_CORE_VERSION
      ),
      expected_qph_core_version
    )
) {
  stop(
    "Unexpected QPH core version. Expected ",
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
# Locked species and PC space
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

method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)

occurrence_colour <- "#111111"


# ============================================================
# Locked revised baseline and sensitivity settings
# ============================================================

baseline_bandwidth_multiplier <- 1.00
baseline_q <- 0.99
baseline_samples_per_point <- 100L
baseline_sd_count <- 3

bandwidth_multipliers <- c(
  0.75,
  1.00,
  1.25
)

q_levels <- c(
  0.950,
  0.975,
  0.990
)

shared_chunk_size <- 100L
potential_batch_size <- 500L
projection_batch_size <- 1000L

# hypervolume_set() settings are retained from Script 20 / the completed
# empirical geometry analysis.
overlap_num_points_max <- 10000L
overlap_distance_factor <- 1

# Preserve the completed empirical sensitivity overlap seed family.
overlap_master_seed <- 261106L

resume_model_fits <- TRUE
retry_failed_model_fits <- TRUE
resume_overlap_comparisons <- TRUE
retry_failed_overlap_comparisons <- TRUE
resume_geographic_projections <- TRUE
retry_failed_geographic_projections <- TRUE

# Failed rows are deliberately retried on restart. This means a run that
# stopped after a downstream audit failure can be resumed without deleting
# the complete 05_QPH_Sensitivity directory; successful baseline work and
# compatible checkpoints are retained while failed model/overlap/projection
# conditions are recalculated.

show_progress_messages <- TRUE

projection_tolerance <- sqrt(
  .Machine$double.eps
)


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

geometry_results_file <- file.path(
  geometry_directory,
  "acacia_environmental_geometry_sqrtNB_q099.rds"
)

geographic_settings_file <- file.path(
  geographic_directory,
  "analysis_settings.rds"
)

geographic_results_file <- file.path(
  geographic_directory,
  "acacia_geographic_projection_sqrtNB_q099.rds"
)

pc_raster_file <- file.path(
  geographic_directory,
  "projection_rasters",
  "Australia_occurrence_PCA_PC1_PC3.tif"
)

cell_area_file <- file.path(
  geographic_directory,
  "projection_rasters",
  "Australia_cell_area_km2.tif"
)

required_upstream_files <- c(
  locked_archive_file,
  locked_settings_file,
  baseline_settings_file,
  baseline_results_file,
  geometry_results_file,
  geographic_settings_file,
  geographic_results_file,
  pc_raster_file,
  cell_area_file
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
    "\nScripts 18-20 and 22 must complete successfully before Script 23."
  )
}


# ============================================================
# Output files
# ============================================================

analysis_settings_file <- file.path(
  output_directory,
  "analysis_settings.rds"
)

model_registry_file <- file.path(
  checkpoint_directory,
  "acacia_qph_sensitivity_model_registry.rds"
)

overlap_checkpoint_file <- file.path(
  checkpoint_directory,
  "acacia_qph_sensitivity_overlap_checkpoint.rds"
)

projection_registry_file <- file.path(
  checkpoint_directory,
  "acacia_qph_sensitivity_projection_registry.rds"
)

sensitivity_design_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_design.csv"
)

plot_design_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_plot_design.csv"
)

baseline_qa_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_baseline_QA.csv"
)

qph_audit_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_audit.csv"
)

model_summary_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_model_summary.csv"
)

geometry_summary_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_geometry_summary.csv"
)

rank_summary_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_niche_breadth_rankings.csv"
)

overlap_summary_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_between_species_overlap.csv"
)

overlap_change_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_overlap_change_vs_baseline.csv"
)

geographic_area_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_geographic_area.csv"
)

summary_vs_baseline_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_summary_vs_baseline.csv"
)

stability_summary_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_stability_summary.csv"
)

plot_ready_species_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_plot_ready_species.csv"
)

plot_ready_overlap_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_plot_ready_overlap.csv"
)

failure_file <- file.path(
  table_directory,
  "acacia_qph_sensitivity_failures.csv"
)

run_metadata_file <- file.path(
  output_directory,
  "acacia_qph_sensitivity_metadata.rds"
)

final_results_file <- file.path(
  output_directory,
  "acacia_qph_sensitivity_sqrtNB_q099.rds"
)

analysis_notes_file <- file.path(
  output_directory,
  "ACACIA_QPH_SENSITIVITY_NOTES.txt"
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
    dirname(
      file
    ),
    recursive = TRUE,
    showWarnings = FALSE
  )

  utils::write.csv(
    x,
    file = file,
    row.names = FALSE
  )

  invisible(
    file
  )
}


safe_md5 <- function(path) {
  if (
    length(
      path
    ) !=
      1L ||
      is.na(
        path
      ) ||
      !file.exists(
        path
      )
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


species_code <- function(species_name) {
  if (!species_name %in% expected_species) {
    stop(
      "Unknown species: ",
      species_name
    )
  }

  unname(
    expected_species_codes[[
      species_name
    ]]
  )
}


format_number_code <- function(
    x,
    digits = 2L
) {
  formatted <- formatC(
    x,
    format = "f",
    digits = digits
  )

  gsub(
    "\\.",
    "p",
    formatted
  )
}


validate_pc_matrix <- function(
    x,
    object_name = "x"
) {
  x <- as.matrix(
    x
  )

  storage.mode(
    x
  ) <- "double"

  if (
    nrow(
      x
    ) <
      1L
  ) {
    stop(
      object_name,
      " must contain at least one row."
    )
  }

  if (
    ncol(
      x
    ) !=
      3L
  ) {
    stop(
      object_name,
      " must contain exactly three columns."
    )
  }

  if (
    any(
      !is.finite(
        x
      )
    )
  ) {
    stop(
      object_name,
      " contains non-finite values."
    )
  }

  colnames(
    x
  ) <- expected_pc_names

  x
}


validate_hypervolume <- function(
    hv,
    object_name = "hv"
) {
  if (
    !methods::is(
      hv,
      "Hypervolume"
    )
  ) {
    stop(
      object_name,
      " is not a Hypervolume object."
    )
  }

  methods::validObject(
    hv
  )

  if (
    as.integer(
      hv@Dimensionality
    ) !=
      3L
  ) {
    stop(
      object_name,
      " must be three-dimensional."
    )
  }

  if (
    !is.finite(
      hv@Volume
    ) ||
      hv@Volume <=
        0
  ) {
    stop(
      object_name,
      " has invalid volume."
    )
  }

  if (
    nrow(
      hv@RandomPoints
    ) <
      1L
  ) {
    stop(
      object_name,
      " contains no RandomPoints."
    )
  }

  invisible(
    TRUE
  )
}


standardise_hypervolume_axis_names <- function(hv) {
  validate_hypervolume(
    hv
  )

  colnames(
    hv@Data
  ) <- expected_pc_names

  colnames(
    hv@RandomPoints
  ) <- expected_pc_names

  methods::validObject(
    hv
  )

  hv
}


centroid_distance <- function(
    x,
    y
) {
  x <- as.numeric(
    x
  )

  y <- as.numeric(
    y
  )

  if (
    length(
      x
    ) !=
      length(
        y
      ) ||
      any(
        !is.finite(
          x
        )
      ) ||
      any(
        !is.finite(
          y
        )
      )
  ) {
    return(
      NA_real_
    )
  }

  sqrt(
    sum(
      (
        x -
          y
      )^2
    )
  )
}


safe_ratio <- function(
    numerator,
    denominator
) {
  if (
    length(
      numerator
    ) !=
      1L ||
      length(
        denominator
      ) !=
        1L ||
      !is.finite(
        numerator
      ) ||
      !is.finite(
        denominator
      ) ||
      denominator ==
        0
  ) {
    return(
      NA_real_
    )
  }

  numerator /
    denominator
}


safe_percent_change <- function(
    value,
    baseline
) {
  ratio <- safe_ratio(
    value,
    baseline
  )

  if (
    !is.finite(
      ratio
    )
  ) {
    return(
      NA_real_
    )
  }

  100 *
    (
      ratio -
        1
    )
}


safe_mean <- function(x) {
  x <- x[
    is.finite(
      x
    )
  ]

  if (
    length(
      x
    ) ==
      0L
  ) {
    return(
      NA_real_
    )
  }

  mean(
    x
  )
}


safe_max <- function(x) {
  x <- x[
    is.finite(
      x
    )
  ]

  if (
    length(
      x
    ) ==
      0L
  ) {
    return(
      NA_real_
    )
  }

  max(
    x
  )
}


# ============================================================
# Sensitivity design
# ============================================================
#
# Five UNIQUE configurations. The baseline is later duplicated into the
# two OFAT plotting families so that each family includes its reference value
# without refitting the baseline.
# ============================================================

unique_configurations <- data.frame(
  Configuration_ID = c(
    "baseline",
    "bandwidth_0p75",
    "bandwidth_1p25",
    "q_0p950",
    "q_0p975"
  ),
  Configuration_family = c(
    "Baseline",
    "Bandwidth",
    "Bandwidth",
    "Potential q",
    "Potential q"
  ),
  Bandwidth_multiplier = c(
    1.00,
    0.75,
    1.25,
    1.00,
    1.00
  ),
  q = c(
    0.990,
    0.990,
    0.990,
    0.950,
    0.975
  ),
  Samples_per_point = rep(
    baseline_samples_per_point,
    5L
  ),
  Is_baseline = c(
    TRUE,
    rep(
      FALSE,
      4L
    )
  ),
  Requires_new_fit = c(
    FALSE,
    rep(
      TRUE,
      4L
    )
  ),
  stringsAsFactors = FALSE
)


plot_design <- rbind(
  data.frame(
    Sensitivity_family = "Bandwidth multiplier",
    Parameter_value = bandwidth_multipliers,
    Parameter_label = format(
      bandwidth_multipliers,
      trim = TRUE,
      scientific = FALSE
    ),
    Configuration_ID = c(
      "bandwidth_0p75",
      "baseline",
      "bandwidth_1p25"
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    Sensitivity_family = "Potential q",
    Parameter_value = q_levels,
    Parameter_label = formatC(
      q_levels,
      format = "f",
      digits = 3
    ),
    Configuration_ID = c(
      "q_0p950",
      "q_0p975",
      "baseline"
    ),
    stringsAsFactors = FALSE
  )
)

plot_design$Is_baseline <- (
  plot_design$Configuration_ID ==
    "baseline"
)

plot_design <- merge(
  plot_design,
  unique_configurations[
    ,
    c(
      "Configuration_ID",
      "Bandwidth_multiplier",
      "q",
      "Samples_per_point"
    ),
    drop = FALSE
  ],
  by = "Configuration_ID",
  all.x = TRUE,
  sort = FALSE
)

write_csv_safely(
  plot_design,
  plot_design_file
)


sensitivity_design_rows <- list()
sensitivity_design_index <- 0L

for (
  species_name in expected_species
) {
  for (
    configuration_index in seq_len(
      nrow(
        unique_configurations
      )
    )
  ) {
    configuration <- unique_configurations[
      configuration_index,
      ,
      drop = FALSE
    ]

    sensitivity_design_index <- (
      sensitivity_design_index +
        1L
    )

    sensitivity_design_rows[[
      sensitivity_design_index
    ]] <- data.frame(
      Condition_ID = paste(
        species_code(
          species_name
        ),
        configuration$Configuration_ID[[1L]],
        sep = "__"
      ),
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Configuration_ID = configuration$Configuration_ID[[1L]],
      Configuration_family = configuration$Configuration_family[[1L]],
      Bandwidth_multiplier = configuration$Bandwidth_multiplier[[1L]],
      q = configuration$q[[1L]],
      Samples_per_point = configuration$Samples_per_point[[1L]],
      SD_count = baseline_sd_count,
      Is_baseline = configuration$Is_baseline[[1L]],
      Requires_new_fit = configuration$Requires_new_fit[[1L]],
      stringsAsFactors = FALSE
    )
  }
}

sensitivity_design <- do.call(
  rbind,
  sensitivity_design_rows
)

write_csv_safely(
  sensitivity_design,
  sensitivity_design_file
)


# ============================================================
# Load and validate upstream provenance
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

geometry_results <- readRDS(
  geometry_results_file
)

geographic_settings_wrapper <- readRDS(
  geographic_settings_file
)

geographic_results <- readRDS(
  geographic_results_file
)

locked_design_hash <- locked_settings$locked_design_hash
baseline_analysis_hash <- baseline_settings_wrapper$analysis_settings_hash
geographic_analysis_hash <- geographic_settings_wrapper$analysis_settings_hash

if (
  is.null(
    locked_design_hash
  ) ||
    is.null(
      baseline_analysis_hash
    ) ||
    is.null(
      geographic_analysis_hash
    )
) {
  stop(
    "Required upstream provenance hashes are missing."
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
    "Script-19 baseline results do not correspond to the current locked inputs."
  )
}

if (
  !identical(
    geometry_results$metadata$locked_design_hash,
    locked_design_hash
  ) ||
    !identical(
      geometry_results$metadata$baseline_analysis_hash,
      baseline_analysis_hash
    )
) {
  stop(
    "Script-20 geometry results do not correspond to the current baseline."
  )
}

if (
  !identical(
    geographic_results$metadata$locked_design_hash,
    locked_design_hash
  ) ||
    !identical(
      geographic_results$metadata$baseline_analysis_hash,
      baseline_analysis_hash
    ) ||
    !identical(
      geographic_results$metadata$analysis_settings_hash,
      geographic_analysis_hash
    )
) {
  stop(
    "Script-22 geographic results do not correspond to the current baseline."
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
    "Locked species order differs from the Script-23 design."
  )
}

species_matrices <- locked_inputs$species_pca_matrices

if (
  is.null(
    species_matrices
  ) ||
    !identical(
      names(
        species_matrices
      ),
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
  species_matrices[[
    species_name
  ]] <- validate_pc_matrix(
    species_matrices[[
      species_name
    ]],
    paste0(
      species_name,
      " occurrence PC matrix"
    )
  )
}


# ============================================================
# Baseline QPH model paths and validation
# ============================================================

baseline_qph_model_file <- function(species_name) {
  file.path(
    baseline_fit_directory,
    "model_objects",
    paste0(
      species_code(
        species_name
      ),
      "__qph.rds"
    )
  )
}


sensitivity_model_file <- function(
    species_name,
    configuration_id
) {
  file.path(
    model_directory,
    paste0(
      species_code(
        species_name
      ),
      "__",
      configuration_id,
      "__qph.rds"
    )
  )
}


baseline_qph_models <- list()
baseline_model_md5 <- character(0)
baseline_bandwidth_info <- list()
baseline_qa_rows <- list()
baseline_qa_index <- 0L

for (
  species_name in expected_species
) {
  current_file <- baseline_qph_model_file(
    species_name
  )

  if (!file.exists(current_file)) {
    stop(
      "Missing revised baseline QPH model:\n  ",
      current_file
    )
  }

  baseline_bundle <- readRDS(
    current_file
  )

  if (
    !identical(
      baseline_bundle$metadata$species,
      species_name
    ) ||
      !identical(
        baseline_bundle$metadata$method,
        "QPH"
      ) ||
      !identical(
        baseline_bundle$metadata$locked_design_hash,
        locked_design_hash
      ) ||
      !identical(
        baseline_bundle$metadata$analysis_settings_hash,
        baseline_analysis_hash
      ) ||
      !identical(
        baseline_bundle$metadata$qph_core_version,
        expected_qph_core_version
      )
  ) {
    stop(
      "Baseline QPH provenance mismatch for ",
      species_name,
      "."
    )
  }

  validate_hypervolume(
    baseline_bundle$hypervolume,
    paste0(
      species_name,
      " baseline QPH"
    )
  )

  audit <- baseline_bundle$qph_result$audit

  occurrence_points <- species_matrices[[
    species_name
  ]]

  independent_bandwidth_info <- estimate_qph_sqrt_nb_bandwidth(
    occurrence_points
  )

  independent_matches_saved <- (
    audit$K ==
      independent_bandwidth_info$k &&
      isTRUE(
        all.equal(
          as.numeric(
            audit$local_s
          ),
          as.numeric(
            independent_bandwidth_info$local_s
          ),
          tolerance = 1e-12
        )
      ) &&
      isTRUE(
        all.equal(
          audit$mean_s,
          independent_bandwidth_info$mean_s,
          tolerance = 1e-12
        )
      ) &&
      isTRUE(
        all.equal(
          audit$baseline_scalar_h,
          independent_bandwidth_info$scalar_bandwidth,
          tolerance = 1e-12
        )
      ) &&
      isTRUE(
        all.equal(
          as.numeric(
            audit$baseline_isotropic_bandwidth
          ),
          as.numeric(
            independent_bandwidth_info$bandwidth
          ),
          tolerance = 1e-12
        )
      )
  )

  if (!independent_matches_saved) {
    stop(
      "Independent sqrt-NB bandwidth recalculation does not match the ",
      "Script-19 baseline for ",
      species_name,
      "."
    )
  }

  baseline_settings_ok <- (
    isTRUE(
      all.equal(
        audit$q,
        baseline_q,
        tolerance = 1e-12
      )
    ) &&
      audit$samples_per_point ==
        baseline_samples_per_point &&
      isTRUE(
        all.equal(
          audit$sd_count,
          baseline_sd_count,
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
              occurrence_points
            )
          )
        )
  )

  if (!baseline_settings_ok) {
    stop(
      "Script-19 QPH baseline settings do not match the locked Script-23 ",
      "baseline for ",
      species_name,
      "."
    )
  }

  baseline_qph_models[[
    species_name
  ]] <- baseline_bundle

  baseline_bandwidth_info[[
    species_name
  ]] <- independent_bandwidth_info

  baseline_model_md5[[
    species_name
  ]] <- safe_md5(
    current_file
  )

  baseline_qa_index <- baseline_qa_index + 1L

  baseline_qa_rows[[
    baseline_qa_index
  ]] <- data.frame(
    Species = species_name,
    Species_code = species_code(
      species_name
    ),
    Occurrence_count = nrow(
      occurrence_points
    ),
    K = audit$K,
    Mean_s = audit$mean_s,
    Baseline_scalar_h = audit$baseline_scalar_h,
    Baseline_bandwidth_PC1 = audit$baseline_isotropic_bandwidth[[1L]],
    Baseline_bandwidth_PC2 = audit$baseline_isotropic_bandwidth[[2L]],
    Baseline_bandwidth_PC3 = audit$baseline_isotropic_bandwidth[[3L]],
    q = audit$q,
    Samples_per_point = audit$samples_per_point,
    SD_count = audit$sd_count,
    Sampling_seed = audit$sampling_seed,
    Independent_bandwidth_recalculation_matches = (
      independent_matches_saved
    ),
    Baseline_model_MD5 = safe_md5(
      current_file
    ),
    stringsAsFactors = FALSE
  )
}

baseline_qa <- do.call(
  rbind,
  baseline_qa_rows
)

write_csv_safely(
  baseline_qa,
  baseline_qa_file
)


# ============================================================
# Analysis settings / checkpoint compatibility
# ============================================================

analysis_settings <- list(
  script = "23_Acacia_QPH_Sensitivity.R",
  analysis_branch = "Acacia_sqrtNB_q099",
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  geographic_analysis_hash = geographic_analysis_hash,
  qph_core_version = QPH_CORE_VERSION,
  qph_core_md5 = qph_core_md5,
  baseline_model_md5 = baseline_model_md5,
  species = expected_species,
  sensitivity_design = unique_configurations,
  baseline = list(
    bandwidth_multiplier = baseline_bandwidth_multiplier,
    q = baseline_q,
    samples_per_point = baseline_samples_per_point,
    sd_count = baseline_sd_count
  ),
  sensitivity = list(
    bandwidth_multipliers = bandwidth_multipliers,
    q_levels = q_levels,
    samples_per_point_fixed = baseline_samples_per_point,
    design_type = "OFAT"
  ),
  stochastic_rule = paste(
    "Every sensitivity fit for a species reuses that species' Script-19",
    "baseline QPH sampling seed."
  ),
  overlap = list(
    num_points_max = overlap_num_points_max,
    distance_factor = overlap_distance_factor,
    master_seed = overlap_master_seed
  ),
  geographic_projection = list(
    pc_raster_md5 = safe_md5(
      pc_raster_file
    ),
    cell_area_raster_md5 = safe_md5(
      cell_area_file
    ),
    projection_batch_size = projection_batch_size,
    projection_tolerance = projection_tolerance
  ),
  topology_sensitivity = FALSE,
  comparators_varied = FALSE
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

if (
  file.exists(
    analysis_settings_file
  )
) {
  previous_settings <- readRDS(
    analysis_settings_file
  )

  if (
    !identical(
      previous_settings$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Existing Script-23 outputs were created under incompatible inputs or ",
      "settings. Archive/remove 05_QPH_Sensitivity before intentionally ",
      "starting the current revised sensitivity design."
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
# QPH model bundle helper
# ============================================================

make_projection_model <- function(
    species_name,
    occurrence_points,
    qph_result,
    configuration
) {
  bandwidth <- as.numeric(
    qph_result$bandwidth
  )

  names(
    bandwidth
  ) <- expected_pc_names

  potential_minimum <- min(
    c(
      qph_result$occurrence_potential_raw,
      qph_result$candidate_potential_raw
    )
  )

  list(
    model_type = "QPH",
    formula_version = paste(
      "V(y) = -d/2 + 0.5 * weighted mean",
      "bandwidth-standardised squared distance"
    ),
    occurrence_points = occurrence_points,
    bandwidth = bandwidth,
    bandwidth_names = expected_pc_names,
    bandwidth_method = "sqrtNB",
    bandwidth_multiplier = configuration$Bandwidth_multiplier[[1L]],
    dimensionality = 3L,
    potential_quantile = configuration$q[[1L]],
    potential_threshold_raw = qph_result$potential_threshold_raw,
    potential_threshold_relative = qph_result$potential_threshold_relative,
    potential_minimum = potential_minimum,
    energy_constant = 0,
    candidate_sd_count = baseline_sd_count,
    potential_batch_size = potential_batch_size,
    inclusion_rule = "candidate region AND potential <= potential_threshold_raw",
    qph_core_version = QPH_CORE_VERSION
  )
}


compact_qph_result <- function(qph_result) {
  list(
    audit = qph_result$audit,
    audit_summary = qph_result$audit_summary,
    bandwidth_info = qph_result$bandwidth_info,
    bandwidth = qph_result$bandwidth,
    ellipsoid_scales = qph_result$ellipsoid_scales,
    occurrence_potential_raw = qph_result$occurrence_potential_raw,
    occurrence_potential_relative = qph_result$occurrence_potential_relative,
    potential_threshold_raw = qph_result$potential_threshold_raw,
    potential_threshold_relative = qph_result$potential_threshold_relative,
    sampling_region_volume = qph_result$sampling_region_volume,
    retained_fraction = qph_result$retained_fraction,
    qph_volume = qph_result$qph_volume,
    qph_volume_se_conditional = qph_result$qph_volume_se_conditional
  )
}


fit_one_sensitivity_qph <- function(
    species_name,
    configuration
) {
  occurrence_points <- species_matrices[[
    species_name
  ]]

  baseline_bundle <- baseline_qph_models[[
    species_name
  ]]

  bandwidth_info <- baseline_bandwidth_info[[
    species_name
  ]]

  baseline_bandwidth <- as.numeric(
    bandwidth_info$bandwidth
  )

  bandwidth_multiplier <- configuration$Bandwidth_multiplier[[1L]]

  fitted_bandwidth <- (
    baseline_bandwidth *
      bandwidth_multiplier
  )

  names(
    fitted_bandwidth
  ) <- expected_pc_names

  # At the baseline bandwidth multiplier, allow construct_qph() to use the
  # locked sqrt-NB bandwidth directly. For 0.75/1.25, make the deliberate
  # sensitivity override explicit while passing the original bandwidth audit.
  bandwidth_argument <- if (
    isTRUE(
      all.equal(
        bandwidth_multiplier,
        1,
        tolerance = 1e-12
      )
    )
  ) {
    NULL
  } else {
    fitted_bandwidth
  }

  sampling_seed <- as.integer(
    baseline_bundle$metadata$sampling_seed
  )

  start_time <- proc.time()[[
    "elapsed"
  ]]

  qph_result <- construct_qph(
    data = occurrence_points,
    bandwidth = bandwidth_argument,
    bandwidth_info = bandwidth_info,
    name = paste0(
      "QPH sensitivity: ",
      species_name,
      " / ",
      configuration$Configuration_ID[[1L]]
    ),
    samples_per_point = configuration$Samples_per_point[[1L]],
    sd_count = baseline_sd_count,
    q = configuration$q[[1L]],
    sampling_seed = sampling_seed,
    sampling_chunk_size = shared_chunk_size,
    potential_batch_size = potential_batch_size,
    verbose = show_progress_messages
  )

  runtime_seconds <- (
    proc.time()[[
      "elapsed"
    ]] -
      start_time
  )

  hv <- qph_result$hypervolume

  colnames(
    hv@Data
  ) <- expected_pc_names

  colnames(
    hv@RandomPoints
  ) <- expected_pc_names

  methods::validObject(
    hv
  )

  # Explicitly verify that the fitted bandwidth is the intended OFAT value.
  #
  # IMPORTANT:
  # `fitted_bandwidth` has PC1-PC3 names whereas as.numeric() removes names
  # from qph_result$bandwidth. Compare numeric values on BOTH sides so the
  # audit tests bandwidth values rather than vector attributes.
  intended_bandwidth_numeric <- as.numeric(
    fitted_bandwidth
  )

  fitted_bandwidth_numeric <- as.numeric(
    qph_result$bandwidth
  )

  if (
    !isTRUE(
      all.equal(
        fitted_bandwidth_numeric,
        intended_bandwidth_numeric,
        tolerance = 1e-12
      )
    )
  ) {
    stop(
      "Fitted QPH bandwidth does not match the intended sensitivity value."
    )
  }

  audit <- qph_result$audit

  if (
    audit$K !=
      bandwidth_info$k ||
      !isTRUE(
        all.equal(
          audit$mean_s,
          bandwidth_info$mean_s,
          tolerance = 1e-12
        )
      ) ||
      !isTRUE(
        all.equal(
          audit$q,
          configuration$q[[1L]],
          tolerance = 1e-12
        )
      ) ||
      audit$samples_per_point !=
        configuration$Samples_per_point[[1L]] ||
      !isTRUE(
        all.equal(
          audit$sd_count,
          baseline_sd_count,
          tolerance = 1e-12
        )
      ) ||
      audit$sampling_seed !=
        sampling_seed
  ) {
    stop(
      "QPH sensitivity audit failed."
    )
  }

  projection_model <- make_projection_model(
    species_name = species_name,
    occurrence_points = occurrence_points,
    qph_result = qph_result,
    configuration = configuration
  )

  model_bundle <- list(
    metadata = list(
      species = species_name,
      species_code = species_code(
        species_name
      ),
      method = "QPH",
      configuration_id = configuration$Configuration_ID[[1L]],
      configuration_family = configuration$Configuration_family[[1L]],
      occurrence_count = nrow(
        occurrence_points
      ),
      dimensionality = 3L,
      sampling_seed = sampling_seed,
      locked_design_hash = locked_design_hash,
      baseline_analysis_hash = baseline_analysis_hash,
      sensitivity_analysis_hash = analysis_settings_hash,
      qph_core_version = QPH_CORE_VERSION,
      qph_core_md5 = qph_core_md5,
      fitted_at = as.character(
        Sys.time()
      ),
      hypervolume_version = as.character(
        utils::packageVersion(
          "hypervolume"
        )
      )
    ),
    settings = list(
      bandwidth_multiplier = configuration$Bandwidth_multiplier[[1L]],
      q = configuration$q[[1L]],
      samples_per_point = configuration$Samples_per_point[[1L]],
      sd_count = baseline_sd_count,
      sampling_chunk_size = shared_chunk_size,
      potential_batch_size = potential_batch_size
    ),
    hypervolume = hv,
    projection_model = projection_model,
    qph_result = compact_qph_result(
      qph_result
    ),
    diagnostics = list(
      runtime_seconds = runtime_seconds,
      retained_fraction = qph_result$retained_fraction,
      sampling_region_volume = qph_result$sampling_region_volume,
      qph_volume_se_conditional = qph_result$qph_volume_se_conditional,
      candidate_point_count = length(
        qph_result$inside_qph
      ),
      retained_point_count = sum(
        qph_result$inside_qph
      )
    )
  )

  list(
    bundle = model_bundle,
    runtime_seconds = runtime_seconds
  )
}


# ============================================================
# Model registry helpers
# ============================================================

empty_model_registry <- function() {
  data.frame(
    Condition_ID = character(0),
    Species = character(0),
    Species_code = character(0),
    Configuration_ID = character(0),
    Success = logical(0),
    Reused_baseline = logical(0),
    Model_file = character(0),
    Model_MD5 = character(0),
    Runtime_seconds = numeric(0),
    Error_message = character(0),
    stringsAsFactors = FALSE
  )
}


registry_replace_row <- function(
    registry,
    new_row
) {
  registry <- registry[
    registry$Condition_ID !=
      new_row$Condition_ID[[1L]],
    ,
    drop = FALSE
  ]

  rbind(
    registry,
    new_row
  )
}


if (
  resume_model_fits &&
    file.exists(
      model_registry_file
    )
) {
  checkpoint <- readRDS(
    model_registry_file
  )

  if (
    !identical(
      checkpoint$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Existing Script-23 model registry is incompatible with the current ",
      "analysis settings."
    )
  }

  model_registry <- checkpoint$registry
} else {
  model_registry <- empty_model_registry()
}


save_model_registry <- function() {
  saveRDS(
    list(
      analysis_settings_hash = analysis_settings_hash,
      registry = model_registry
    ),
    model_registry_file,
    version = 3
  )

  invisible(
    TRUE
  )
}


# ============================================================
# Fit / reuse all 25 species x sensitivity conditions
# ============================================================

message(
  "\nBeginning revised empirical QPH sensitivity fits..."
)

for (
  condition_index in seq_len(
    nrow(
      sensitivity_design
    )
  )
) {
  design_row <- sensitivity_design[
    condition_index,
    ,
    drop = FALSE
  ]

  species_name <- design_row$Species[[1L]]
  configuration_id <- design_row$Configuration_ID[[1L]]
  condition_id <- design_row$Condition_ID[[1L]]

  configuration <- unique_configurations[
    unique_configurations$Configuration_ID ==
      configuration_id,
    ,
    drop = FALSE
  ]

  if (
    nrow(
      configuration
    ) !=
      1L
  ) {
    stop(
      "Could not recover unique configuration ",
      configuration_id,
      "."
    )
  }

  if (
    isTRUE(
      configuration$Is_baseline[[1L]]
    )
  ) {
    baseline_file <- baseline_qph_model_file(
      species_name
    )

    baseline_bundle <- baseline_qph_models[[
      species_name
    ]]

    new_row <- data.frame(
      Condition_ID = condition_id,
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Configuration_ID = configuration_id,
      Success = TRUE,
      Reused_baseline = TRUE,
      Model_file = normalizePath(
        baseline_file,
        winslash = "/",
        mustWork = TRUE
      ),
      Model_MD5 = safe_md5(
        baseline_file
      ),
      Runtime_seconds = NA_real_,
      Error_message = NA_character_,
      stringsAsFactors = FALSE
    )

    model_registry <- registry_replace_row(
      model_registry,
      new_row
    )

    save_model_registry()

    next
  }

  output_model_file <- sensitivity_model_file(
    species_name,
    configuration_id
  )

  existing <- model_registry[
    model_registry$Condition_ID ==
      condition_id,
    ,
    drop = FALSE
  ]

  if (
    resume_model_fits &&
      nrow(
        existing
      ) ==
        1L &&
      isTRUE(
        existing$Success[[1L]]
      ) &&
      file.exists(
        output_model_file
      )
  ) {
    existing_bundle <- readRDS(
      output_model_file
    )

    compatible <- (
      identical(
        existing_bundle$metadata$sensitivity_analysis_hash,
        analysis_settings_hash
      ) &&
        identical(
          existing_bundle$metadata$species,
          species_name
        ) &&
        identical(
          existing_bundle$metadata$configuration_id,
          configuration_id
        ) &&
        identical(
          safe_md5(
            output_model_file
          ),
          existing$Model_MD5[[1L]]
        )
    )

    if (compatible) {
      message(
        "Skipping completed QPH sensitivity fit ",
        condition_index,
        "/",
        nrow(
          sensitivity_design
        ),
        ": ",
        condition_id
      )

      next
    }

    stop(
      "Existing sensitivity model/checkpoint mismatch:\n  ",
      output_model_file
    )
  }

  if (
    nrow(
      existing
    ) ==
      1L &&
      !isTRUE(
        existing$Success[[1L]]
      ) &&
      !retry_failed_model_fits
  ) {
    next
  }

  message(
    "Fitting QPH sensitivity ",
    condition_index,
    "/",
    nrow(
      sensitivity_design
    ),
    ": ",
    condition_id
  )

  fit_result <- tryCatch(
    {
      result <- fit_one_sensitivity_qph(
        species_name = species_name,
        configuration = configuration
      )

      saveRDS(
        result$bundle,
        output_model_file,
        version = 3
      )

      data.frame(
        Condition_ID = condition_id,
        Species = species_name,
        Species_code = species_code(
          species_name
        ),
        Configuration_ID = configuration_id,
        Success = TRUE,
        Reused_baseline = FALSE,
        Model_file = normalizePath(
          output_model_file,
          winslash = "/",
          mustWork = TRUE
        ),
        Model_MD5 = safe_md5(
          output_model_file
        ),
        Runtime_seconds = result$runtime_seconds,
        Error_message = NA_character_,
        stringsAsFactors = FALSE
      )
    },
    error = function(error_condition) {
      data.frame(
        Condition_ID = condition_id,
        Species = species_name,
        Species_code = species_code(
          species_name
        ),
        Configuration_ID = configuration_id,
        Success = FALSE,
        Reused_baseline = FALSE,
        Model_file = normalizePath(
          output_model_file,
          winslash = "/",
          mustWork = FALSE
        ),
        Model_MD5 = NA_character_,
        Runtime_seconds = NA_real_,
        Error_message = conditionMessage(
          error_condition
        ),
        stringsAsFactors = FALSE
      )
    }
  )

  model_registry <- registry_replace_row(
    model_registry,
    fit_result
  )

  save_model_registry()

  gc()
}


# ============================================================
# Final model-registry validation
# ============================================================

model_registry$Species <- factor(
  model_registry$Species,
  levels = expected_species
)

model_registry$Configuration_ID <- factor(
  model_registry$Configuration_ID,
  levels = unique_configurations$Configuration_ID
)

model_registry <- model_registry[
  order(
    model_registry$Species,
    model_registry$Configuration_ID
  ),
  ,
  drop = FALSE
]

model_registry$Species <- as.character(
  model_registry$Species
)

model_registry$Configuration_ID <- as.character(
  model_registry$Configuration_ID
)

rownames(
  model_registry
) <- NULL

if (
  nrow(
    model_registry
  ) !=
    nrow(
      sensitivity_design
    )
) {
  stop(
    "Model registry does not contain all 25 species x configuration rows."
  )
}


# ============================================================
# Model loader
# ============================================================

load_condition_bundle <- function(
    species_name,
    configuration_id
) {
  condition_id <- paste(
    species_code(
      species_name
    ),
    configuration_id,
    sep = "__"
  )

  registry_row <- model_registry[
    model_registry$Condition_ID ==
      condition_id,
    ,
    drop = FALSE
  ]

  if (
    nrow(
      registry_row
    ) !=
      1L ||
      !isTRUE(
        registry_row$Success[[1L]]
      )
  ) {
    return(
      NULL
    )
  }

  model_file <- registry_row$Model_file[[1L]]

  if (!file.exists(model_file)) {
    stop(
      "Successful model registry row points to missing file:\n  ",
      model_file
    )
  }

  bundle <- readRDS(
    model_file
  )

  if (
    identical(
      configuration_id,
      "baseline"
    )
  ) {
    if (
      !identical(
        bundle$metadata$analysis_settings_hash,
        baseline_analysis_hash
      )
    ) {
      stop(
        "Baseline QPH model provenance changed unexpectedly."
      )
    }
  } else {
    if (
      !identical(
        bundle$metadata$sensitivity_analysis_hash,
        analysis_settings_hash
      )
    ) {
      stop(
        "Sensitivity QPH model provenance mismatch."
      )
    }
  }

  bundle
}


# ============================================================
# Compile model / geometry / audit summaries
# ============================================================

model_summary_rows <- list()
geometry_summary_rows <- list()
audit_rows <- list()

summary_index <- 0L

baseline_centroids <- list()
baseline_volumes <- list()

for (
  species_name in expected_species
) {
  baseline_bundle <- load_condition_bundle(
    species_name,
    "baseline"
  )

  if (is.null(baseline_bundle)) {
    stop(
      "Baseline QPH bundle unexpectedly unavailable for ",
      species_name,
      "."
    )
  }

  baseline_hv <- standardise_hypervolume_axis_names(
    baseline_bundle$hypervolume
  )

  baseline_centroids[[
    species_name
  ]] <- colMeans(
    baseline_hv@RandomPoints
  )

  baseline_volumes[[
    species_name
  ]] <- as.numeric(
    baseline_hv@Volume
  )
}


for (
  condition_index in seq_len(
    nrow(
      sensitivity_design
    )
  )
) {
  design_row <- sensitivity_design[
    condition_index,
    ,
    drop = FALSE
  ]

  species_name <- design_row$Species[[1L]]
  configuration_id <- design_row$Configuration_ID[[1L]]

  bundle <- load_condition_bundle(
    species_name,
    configuration_id
  )

  summary_index <- summary_index + 1L

  if (is.null(bundle)) {
    model_summary_rows[[
      summary_index
    ]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Configuration_ID = configuration_id,
      Configuration_family = design_row$Configuration_family[[1L]],
      Is_baseline = design_row$Is_baseline[[1L]],
      Success = FALSE,
      Bandwidth_multiplier = design_row$Bandwidth_multiplier[[1L]],
      q = design_row$q[[1L]],
      Samples_per_point = design_row$Samples_per_point[[1L]],
      Hypervolume_volume = NA_real_,
      Volume_ratio_to_baseline = NA_real_,
      Volume_percent_change_from_baseline = NA_real_,
      Random_point_count = NA_integer_,
      Point_density = NA_real_,
      Retained_fraction = NA_real_,
      QPH_volume_SE_conditional = NA_real_,
      QPH_threshold_raw = NA_real_,
      QPH_threshold_relative = NA_real_,
      Runtime_seconds = NA_real_,
      stringsAsFactors = FALSE
    )

    geometry_summary_rows[[
      summary_index
    ]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Configuration_ID = configuration_id,
      Success = FALSE,
      Occurrence_centroid_PC1 = NA_real_,
      Occurrence_centroid_PC2 = NA_real_,
      Occurrence_centroid_PC3 = NA_real_,
      QPH_centroid_PC1 = NA_real_,
      QPH_centroid_PC2 = NA_real_,
      QPH_centroid_PC3 = NA_real_,
      Centroid_displacement_from_occurrence = NA_real_,
      Centroid_displacement_from_baseline_QPH = NA_real_,
      stringsAsFactors = FALSE
    )

    next
  }

  hv <- standardise_hypervolume_axis_names(
    bundle$hypervolume
  )

  occurrence_points <- species_matrices[[
    species_name
  ]]

  occurrence_centroid <- colMeans(
    occurrence_points
  )

  hv_centroid <- colMeans(
    hv@RandomPoints
  )

  audit <- bundle$qph_result$audit

  registry_row <- model_registry[
    model_registry$Condition_ID ==
      design_row$Condition_ID[[1L]],
    ,
    drop = FALSE
  ]

  model_summary_rows[[
    summary_index
  ]] <- data.frame(
    Species = species_name,
    Species_code = species_code(
      species_name
    ),
    Configuration_ID = configuration_id,
    Configuration_family = design_row$Configuration_family[[1L]],
    Is_baseline = design_row$Is_baseline[[1L]],
    Success = TRUE,
    Bandwidth_multiplier = design_row$Bandwidth_multiplier[[1L]],
    q = design_row$q[[1L]],
    Samples_per_point = design_row$Samples_per_point[[1L]],
    Hypervolume_volume = as.numeric(
      hv@Volume
    ),
    Volume_ratio_to_baseline = safe_ratio(
      as.numeric(
        hv@Volume
      ),
      baseline_volumes[[
        species_name
      ]]
    ),
    Volume_percent_change_from_baseline = safe_percent_change(
      as.numeric(
        hv@Volume
      ),
      baseline_volumes[[
        species_name
      ]]
    ),
    Random_point_count = nrow(
      hv@RandomPoints
    ),
    Point_density = as.numeric(
      hv@PointDensity
    ),
    Retained_fraction = bundle$qph_result$retained_fraction,
    QPH_volume_SE_conditional = (
      bundle$qph_result$qph_volume_se_conditional
    ),
    QPH_threshold_raw = bundle$qph_result$potential_threshold_raw,
    QPH_threshold_relative = (
      bundle$qph_result$potential_threshold_relative
    ),
    Runtime_seconds = registry_row$Runtime_seconds[[1L]],
    stringsAsFactors = FALSE
  )

  geometry_summary_rows[[
    summary_index
  ]] <- data.frame(
    Species = species_name,
    Species_code = species_code(
      species_name
    ),
    Configuration_ID = configuration_id,
    Success = TRUE,
    Occurrence_centroid_PC1 = occurrence_centroid[[1L]],
    Occurrence_centroid_PC2 = occurrence_centroid[[2L]],
    Occurrence_centroid_PC3 = occurrence_centroid[[3L]],
    QPH_centroid_PC1 = hv_centroid[[1L]],
    QPH_centroid_PC2 = hv_centroid[[2L]],
    QPH_centroid_PC3 = hv_centroid[[3L]],
    Centroid_displacement_from_occurrence = centroid_distance(
      occurrence_centroid,
      hv_centroid
    ),
    Centroid_displacement_from_baseline_QPH = centroid_distance(
      baseline_centroids[[
        species_name
      ]],
      hv_centroid
    ),
    stringsAsFactors = FALSE
  )

  audit_summary <- qph_audit_summary(
    audit
  )

  audit_rows[[
    summary_index
  ]] <- cbind(
    data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Configuration_ID = configuration_id,
      Bandwidth_multiplier = design_row$Bandwidth_multiplier[[1L]],
      stringsAsFactors = FALSE
    ),
    audit_summary
  )
}

model_summary <- do.call(
  rbind,
  model_summary_rows
)

geometry_summary <- do.call(
  rbind,
  geometry_summary_rows
)

audit_summary_table <- do.call(
  rbind,
  audit_rows
)

write_csv_safely(
  model_summary,
  model_summary_file
)

write_csv_safely(
  geometry_summary,
  geometry_summary_file
)

write_csv_safely(
  audit_summary_table,
  qph_audit_file
)


# ============================================================
# Niche-breadth rankings
# ============================================================

rank_summary <- model_summary[
  ,
  c(
    "Species",
    "Species_code",
    "Configuration_ID",
    "Success",
    "Bandwidth_multiplier",
    "q",
    "Samples_per_point",
    "Hypervolume_volume"
  ),
  drop = FALSE
]

rank_summary$Niche_breadth_rank <- NA_integer_

for (
  configuration_id in unique_configurations$Configuration_ID
) {
  indices <- which(
    rank_summary$Configuration_ID ==
      configuration_id &
      rank_summary$Success
  )

  if (
    length(
      indices
    ) >
      0L
  ) {
    rank_summary$Niche_breadth_rank[
      indices
    ] <- rank(
      -rank_summary$Hypervolume_volume[
        indices
      ],
      ties.method = "min"
    )
  }
}

baseline_ranks <- rank_summary[
  rank_summary$Configuration_ID ==
    "baseline",
  c(
    "Species",
    "Niche_breadth_rank"
  ),
  drop = FALSE
]

names(
  baseline_ranks
)[[
  2L
]] <- "Baseline_niche_breadth_rank"

rank_summary <- merge(
  rank_summary,
  baseline_ranks,
  by = "Species",
  all.x = TRUE,
  sort = FALSE
)

rank_summary$Rank_change_from_baseline <- (
  rank_summary$Niche_breadth_rank -
    rank_summary$Baseline_niche_breadth_rank
)

rank_summary$Rank_preserved <- (
  rank_summary$Rank_change_from_baseline ==
    0
)

write_csv_safely(
  rank_summary,
  rank_summary_file
)


# ============================================================
# Environmental overlap helpers
# ============================================================

get_hv_component_volume <- function(
    hv_set,
    component_name
) {
  if (
    !methods::is(
      hv_set,
      "HypervolumeList"
    )
  ) {
    stop(
      "Set operation did not return a HypervolumeList."
    )
  }

  if (
    !component_name %in%
      names(
        hv_set@HVList
      )
  ) {
    stop(
      "Set-operation result lacks component '",
      component_name,
      "'."
    )
  }

  component <- hv_set@HVList[[
    component_name
  ]]

  if (is.null(component)) {
    return(
      0
    )
  }

  if (
    !methods::is(
      component,
      "Hypervolume"
    )
  ) {
    stop(
      "Set-operation component is not a Hypervolume."
    )
  }

  volume <- as.numeric(
    component@Volume
  )

  if (!is.finite(volume)) {
    return(
      NA_real_
    )
  }

  volume
}


calculate_overlap_safe <- function(
    hv1,
    hv2,
    seed
) {
  hv1 <- standardise_hypervolume_axis_names(
    hv1
  )

  hv2 <- standardise_hypervolume_axis_names(
    hv2
  )

  volume_1 <- as.numeric(
    hv1@Volume
  )

  volume_2 <- as.numeric(
    hv2@Volume
  )

  set.seed(
    as.integer(
      seed
    )
  )

  tryCatch(
    {
      start_time <- proc.time()[[
        "elapsed"
      ]]

      hv_set <- hypervolume::hypervolume_set(
        hv1 = hv1,
        hv2 = hv2,
        num.points.max = overlap_num_points_max,
        verbose = FALSE,
        check.memory = FALSE,
        distance.factor = overlap_distance_factor
      )

      runtime_seconds <- (
        proc.time()[[
          "elapsed"
        ]] -
          start_time
      )

      intersection_volume <- get_hv_component_volume(
        hv_set,
        "Intersection"
      )

      union_volume <- get_hv_component_volume(
        hv_set,
        "Union"
      )

      jaccard <- if (
        is.finite(
          intersection_volume
        ) &&
          is.finite(
            union_volume
          ) &&
          union_volume >
            0
      ) {
        intersection_volume /
          union_volume
      } else {
        NA_real_
      }

      sorensen <- if (
        is.finite(
          intersection_volume
        ) &&
          (
            volume_1 +
              volume_2
          ) >
            0
      ) {
        2 *
          intersection_volume /
          (
            volume_1 +
              volume_2
          )
      } else {
        NA_real_
      }

      fraction_1 <- if (
        volume_1 >
          0
      ) {
        intersection_volume /
          volume_1
      } else {
        NA_real_
      }

      fraction_2 <- if (
        volume_2 >
          0
      ) {
        intersection_volume /
          volume_2
      } else {
        NA_real_
      }

      list(
        success = TRUE,
        volume_1 = volume_1,
        volume_2 = volume_2,
        intersection_volume = intersection_volume,
        union_volume = union_volume,
        jaccard = jaccard,
        sorensen = sorensen,
        fraction_1 = fraction_1,
        fraction_2 = fraction_2,
        runtime_seconds = runtime_seconds,
        error_message = NA_character_
      )
    },
    error = function(error_condition) {
      list(
        success = FALSE,
        volume_1 = volume_1,
        volume_2 = volume_2,
        intersection_volume = NA_real_,
        union_volume = NA_real_,
        jaccard = NA_real_,
        sorensen = NA_real_,
        fraction_1 = NA_real_,
        fraction_2 = NA_real_,
        runtime_seconds = NA_real_,
        error_message = conditionMessage(
          error_condition
        )
      )
    }
  )
}


# ============================================================
# Restartable environmental overlap analysis
# ============================================================

species_pairs <- utils::combn(
  expected_species,
  2,
  simplify = FALSE
)

if (
  resume_overlap_comparisons &&
    file.exists(
      overlap_checkpoint_file
    )
) {
  overlap_checkpoint <- readRDS(
    overlap_checkpoint_file
  )

  if (
    !identical(
      overlap_checkpoint$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Existing sensitivity-overlap checkpoint is incompatible."
    )
  }

  overlap_results <- overlap_checkpoint$results
} else {
  overlap_results <- list()
}


save_overlap_checkpoint <- function() {
  saveRDS(
    list(
      analysis_settings_hash = analysis_settings_hash,
      results = overlap_results
    ),
    overlap_checkpoint_file,
    version = 3
  )

  invisible(
    TRUE
  )
}


total_overlap_comparisons <- (
  nrow(
    unique_configurations
  ) *
    length(
      species_pairs
    )
)

comparison_counter <- 0L

message(
  "\nBeginning QPH sensitivity between-species overlap analysis..."
)

for (
  configuration_index in seq_len(
    nrow(
      unique_configurations
    )
  )
) {
  configuration_id <- unique_configurations$Configuration_ID[[
    configuration_index
  ]]

  for (
    pair_index in seq_along(
      species_pairs
    )
  ) {
    species_1 <- species_pairs[[
      pair_index
    ]][[
      1L
    ]]

    species_2 <- species_pairs[[
      pair_index
    ]][[
      2L
    ]]

    comparison_counter <- comparison_counter + 1L

    result_key <- paste(
      configuration_id,
      species_code(
        species_1
      ),
      species_code(
        species_2
      ),
      sep = "__"
    )

    existing_result <- overlap_results[[
      result_key
    ]]

    if (
      !is.null(
        existing_result
      ) &&
        (
          isTRUE(
            existing_result$success
          ) ||
            !retry_failed_overlap_comparisons
        )
    ) {
      next
    }

    bundle_1 <- load_condition_bundle(
      species_1,
      configuration_id
    )

    bundle_2 <- load_condition_bundle(
      species_2,
      configuration_id
    )

    current_seed <- as.integer(
      overlap_master_seed +
        configuration_index *
          10000L +
        pair_index *
          100L
    )

    if (
      is.null(
        bundle_1
      ) ||
        is.null(
          bundle_2
        )
    ) {
      overlap_results[[
        result_key
      ]] <- list(
        key = result_key,
        configuration_id = configuration_id,
        species_1 = species_1,
        species_2 = species_2,
        seed = current_seed,
        success = FALSE,
        volume_1 = NA_real_,
        volume_2 = NA_real_,
        intersection_volume = NA_real_,
        union_volume = NA_real_,
        jaccard = NA_real_,
        sorensen = NA_real_,
        fraction_1 = NA_real_,
        fraction_2 = NA_real_,
        runtime_seconds = NA_real_,
        error_message = "One or both QPH model bundles are unavailable."
      )

      save_overlap_checkpoint()

      next
    }

    message(
      "QPH overlap ",
      comparison_counter,
      "/",
      total_overlap_comparisons,
      ": ",
      configuration_id,
      " | ",
      species_1,
      " vs ",
      species_2
    )

    overlap_result <- calculate_overlap_safe(
      hv1 = bundle_1$hypervolume,
      hv2 = bundle_2$hypervolume,
      seed = current_seed
    )

    overlap_results[[
      result_key
    ]] <- c(
      list(
        key = result_key,
        configuration_id = configuration_id,
        species_1 = species_1,
        species_2 = species_2,
        seed = current_seed
      ),
      overlap_result
    )

    save_overlap_checkpoint()

    gc()
  }
}


overlap_rows <- lapply(
  overlap_results,
  function(result) {
    data.frame(
      Configuration_ID = result$configuration_id,
      Species_1 = result$species_1,
      Species_2 = result$species_2,
      Species_pair = paste(
        result$species_1,
        result$species_2,
        sep = " vs "
      ),
      Success = result$success,
      Volume_species_1 = result$volume_1,
      Volume_species_2 = result$volume_2,
      Intersection_volume = result$intersection_volume,
      Union_volume = result$union_volume,
      Jaccard_similarity = result$jaccard,
      Sorensen_similarity = result$sorensen,
      Fraction_species_1_overlapped = result$fraction_1,
      Fraction_species_2_overlapped = result$fraction_2,
      Set_operation_runtime_seconds = result$runtime_seconds,
      Set_operation_seed = result$seed,
      Error_message = result$error_message,
      stringsAsFactors = FALSE
    )
  }
)

overlap_summary <- do.call(
  rbind,
  overlap_rows
)

rownames(
  overlap_summary
) <- NULL

write_csv_safely(
  overlap_summary,
  overlap_summary_file
)


baseline_overlap <- overlap_summary[
  overlap_summary$Configuration_ID ==
    "baseline" &
    overlap_summary$Success,
  c(
    "Species_pair",
    "Jaccard_similarity",
    "Sorensen_similarity"
  ),
  drop = FALSE
]

names(
  baseline_overlap
) <- c(
  "Species_pair",
  "Baseline_Jaccard_similarity",
  "Baseline_Sorensen_similarity"
)

overlap_change <- merge(
  overlap_summary,
  baseline_overlap,
  by = "Species_pair",
  all.x = TRUE,
  sort = FALSE
)

overlap_change$Jaccard_change_from_baseline <- (
  overlap_change$Jaccard_similarity -
    overlap_change$Baseline_Jaccard_similarity
)

overlap_change$Sorensen_change_from_baseline <- (
  overlap_change$Sorensen_similarity -
    overlap_change$Baseline_Sorensen_similarity
)

write_csv_safely(
  overlap_change,
  overlap_change_file
)


# ============================================================
# Geographic projection inputs from Script 22
# ============================================================

pc_raster <- terra::rast(
  pc_raster_file
)

cell_area_raster <- terra::rast(
  cell_area_file
)

if (
  terra::nlyr(
    pc_raster
  ) !=
    3L
) {
  stop(
    "Script-22 PCA raster does not contain PC1-PC3."
  )
}

names(
  pc_raster
) <- expected_pc_names

if (
  terra::nlyr(
    cell_area_raster
  ) !=
    1L
) {
  stop(
    "Script-22 cell-area raster does not contain exactly one layer."
  )
}

if (
  !isTRUE(
    terra::compareGeom(
      pc_raster[[1L]],
      cell_area_raster,
      stopOnError = FALSE
    )
  )
) {
  stop(
    "Script-22 PC raster and cell-area raster geometries differ."
  )
}

pc_values <- terra::values(
  pc_raster,
  mat = TRUE
)

colnames(
  pc_values
) <- expected_pc_names

valid_cell_index <- which(
  stats::complete.cases(
    pc_values
  )
)

if (
  length(
    valid_cell_index
  ) ==
    0L
) {
  stop(
    "No complete environmental cells exist in the Script-22 PC raster."
  )
}

cell_area_values <- as.numeric(
  terra::values(
    cell_area_raster
  )
)

cell_area_values[
  !is.finite(
    pc_values[
      ,
      1L
    ]
  )
] <- NA_real_

available_domain_area_km2 <- sum(
  cell_area_values[
    valid_cell_index
  ],
  na.rm = TRUE
)


# ============================================================
# QPH geographic projection helper
# ============================================================

project_qph_to_pc_raster_values <- function(
    pc_values,
    valid_cell_index,
    projection_model
) {
  occurrence_points <- validate_pc_matrix(
    projection_model$occurrence_points,
    "projection_model occurrence points"
  )

  bandwidth <- as.numeric(
    projection_model$bandwidth
  )

  qph_threshold <- as.numeric(
    projection_model$potential_threshold_raw
  )

  sd_count <- as.numeric(
    projection_model$candidate_sd_count
  )

  if (
    length(
      bandwidth
    ) !=
      3L ||
      any(
        !is.finite(
          bandwidth
        )
      ) ||
      any(
        bandwidth <=
          0
      )
  ) {
    stop(
      "Invalid QPH projection bandwidth."
    )
  }

  if (
    !is.finite(
      qph_threshold
    )
  ) {
    stop(
      "Invalid QPH potential threshold."
    )
  }

  if (
    !is.finite(
      sd_count
    ) ||
      sd_count <=
        0
  ) {
    stop(
      "Invalid QPH candidate sd.count."
    )
  }

  inclusion <- rep(
    NA_integer_,
    nrow(
      pc_values
    )
  )

  valid_points <- pc_values[
    valid_cell_index,
    ,
    drop = FALSE
  ]

  # Exact rectangular pre-filter around the union of occurrence-centred
  # bandwidth-scaled ellipsoids. Points outside this box cannot be in the
  # candidate region; all retained candidates are still checked exactly.
  occurrence_min <- apply(
    occurrence_points,
    2L,
    min
  )

  occurrence_max <- apply(
    occurrence_points,
    2L,
    max
  )

  bounding_min <- (
    occurrence_min -
      sd_count *
        bandwidth
  )

  bounding_max <- (
    occurrence_max +
      sd_count *
        bandwidth
  )

  in_bounding_box <- rep(
    TRUE,
    nrow(
      valid_points
    )
  )

  for (
    dimension_index in 1:3
  ) {
    in_bounding_box <- (
      in_bounding_box &
        valid_points[
          ,
          dimension_index
        ] >=
          bounding_min[[
            dimension_index
          ]] &
        valid_points[
          ,
          dimension_index
        ] <=
          bounding_max[[
            dimension_index
          ]]
    )
  }

  valid_result <- integer(
    nrow(
      valid_points
    )
  )

  candidate_indices <- which(
    in_bounding_box
  )

  if (
    length(
      candidate_indices
    ) >
      0L
  ) {
    candidate_points <- valid_points[
      candidate_indices,
      ,
      drop = FALSE
    ]

    occurrence_scaled <- sweep(
      occurrence_points,
      2L,
      bandwidth,
      FUN = "/"
    )

    occurrence_squared_norm <- rowSums(
      occurrence_scaled^2
    )

    number_batches <- ceiling(
      nrow(
        candidate_points
      ) /
        projection_batch_size
    )

    for (
      batch_index in seq_len(
        number_batches
      )
    ) {
      batch_start <- (
        (
          batch_index -
            1L
        ) *
          projection_batch_size +
          1L
      )

      batch_end <- min(
        batch_index *
          projection_batch_size,
        nrow(
          candidate_points
        )
      )

      batch_rows <- batch_start:batch_end

      batch_points <- candidate_points[
        batch_rows,
        ,
        drop = FALSE
      ]

      batch_scaled <- sweep(
        batch_points,
        2L,
        bandwidth,
        FUN = "/"
      )

      distance_squared <- outer(
        rowSums(
          batch_scaled^2
        ),
        occurrence_squared_norm,
        FUN = "+"
      ) -
        2 *
          tcrossprod(
            batch_scaled,
            occurrence_scaled
          )

      distance_squared[
        distance_squared <
          0 &
          distance_squared >
            -1e-8
      ] <- 0

      if (
        any(
          distance_squared <
            0
        )
      ) {
        stop(
          "Unexpected negative squared distances during QPH projection."
        )
      }

      row_minimum <- apply(
        distance_squared,
        1L,
        min
      )

      inside_candidate <- (
        row_minimum <=
          sd_count^2
      )

      batch_inside <- logical(
        length(
          batch_rows
        )
      )

      if (
        any(
          inside_candidate
        )
      ) {
        candidate_d2 <- distance_squared[
          inside_candidate,
          ,
          drop = FALSE
        ]

        candidate_minimum <- row_minimum[
          inside_candidate
        ]

        shifted_weights <- exp(
          -0.5 *
            sweep(
              candidate_d2,
              1L,
              candidate_minimum,
              FUN = "-"
            )
        )

        shifted_sum <- rowSums(
          shifted_weights
        )

        candidate_potential <- (
          -3 /
            2 +
            0.5 *
              rowSums(
                shifted_weights *
                  candidate_d2
              ) /
              shifted_sum
        )

        batch_inside[
          inside_candidate
        ] <- (
          candidate_potential <=
            qph_threshold +
              projection_tolerance
        )
      }

      original_valid_positions <- candidate_indices[
        batch_rows
      ]

      valid_result[
        original_valid_positions
      ] <- as.integer(
        batch_inside
      )
    }
  }

  inclusion[
    valid_cell_index
  ] <- valid_result

  list(
    inclusion = inclusion,
    bounding_box_cell_count = length(
      candidate_indices
    ),
    included_cell_count = sum(
      valid_result ==
        1L
    )
  )
}


make_binary_raster <- function(
    template,
    values_vector,
    output_file
) {
  raster_object <- template[[1L]]

  names(
    raster_object
  ) <- "included"

  terra::values(
    raster_object
  ) <- values_vector

  terra::writeRaster(
    raster_object,
    output_file,
    overwrite = TRUE,
    datatype = "INT1U",
    NAflag = 255
  )

  terra::rast(
    output_file
  )
}


sensitivity_projection_raster_path <- function(
    species_name,
    configuration_id
) {
  file.path(
    projection_raster_directory,
    paste0(
      species_code(
        species_name
      ),
      "__",
      configuration_id,
      "__qph_geographic_inclusion.tif"
    )
  )
}


baseline_projection_raster_path <- function(species_name) {
  file.path(
    geographic_directory,
    "projection_rasters",
    paste0(
      species_code(
        species_name
      ),
      "__qph__geographic_inclusion.tif"
    )
  )
}


validate_projection_raster <- function(path) {
  if (!file.exists(path)) {
    return(
      FALSE
    )
  }

  raster_object <- terra::rast(
    path
  )

  (
    terra::nlyr(
      raster_object
    ) ==
      1L &&
      isTRUE(
        terra::compareGeom(
          raster_object,
          pc_raster[[1L]],
          stopOnError = FALSE
        )
      )
  )
}


# ============================================================
# Restartable geographic projection registry
# ============================================================

empty_projection_registry <- function() {
  data.frame(
    Condition_ID = character(0),
    Species = character(0),
    Configuration_ID = character(0),
    Success = logical(0),
    Reused_script22_baseline = logical(0),
    Reused_existing_sensitivity_raster = logical(0),
    Raster_file = character(0),
    Raster_MD5 = character(0),
    Runtime_seconds = numeric(0),
    Bounding_box_cell_count = integer(0),
    Error_message = character(0),
    stringsAsFactors = FALSE
  )
}


if (
  resume_geographic_projections &&
    file.exists(
      projection_registry_file
    )
) {
  projection_checkpoint <- readRDS(
    projection_registry_file
  )

  if (
    !identical(
      projection_checkpoint$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Existing sensitivity projection registry is incompatible."
    )
  }

  projection_registry <- projection_checkpoint$registry
} else {
  projection_registry <- empty_projection_registry()
}


projection_registry_replace_row <- function(
    registry,
    new_row
) {
  registry <- registry[
    registry$Condition_ID !=
      new_row$Condition_ID[[1L]],
    ,
    drop = FALSE
  ]

  rbind(
    registry,
    new_row
  )
}


save_projection_registry <- function() {
  saveRDS(
    list(
      analysis_settings_hash = analysis_settings_hash,
      registry = projection_registry
    ),
    projection_registry_file,
    version = 3
  )

  invisible(
    TRUE
  )
}


# ============================================================
# Geographic projection for all 25 conditions
# ============================================================

message(
  "\nBeginning revised QPH sensitivity geographic projections..."
)

for (
  condition_index in seq_len(
    nrow(
      sensitivity_design
    )
  )
) {
  design_row <- sensitivity_design[
    condition_index,
    ,
    drop = FALSE
  ]

  species_name <- design_row$Species[[1L]]
  configuration_id <- design_row$Configuration_ID[[1L]]
  condition_id <- design_row$Condition_ID[[1L]]

  bundle <- load_condition_bundle(
    species_name,
    configuration_id
  )

  existing <- projection_registry[
    projection_registry$Condition_ID ==
      condition_id,
    ,
    drop = FALSE
  ]

  if (is.null(bundle)) {
    new_row <- data.frame(
      Condition_ID = condition_id,
      Species = species_name,
      Configuration_ID = configuration_id,
      Success = FALSE,
      Reused_script22_baseline = FALSE,
      Reused_existing_sensitivity_raster = FALSE,
      Raster_file = NA_character_,
      Raster_MD5 = NA_character_,
      Runtime_seconds = NA_real_,
      Bounding_box_cell_count = NA_integer_,
      Error_message = "QPH model bundle unavailable.",
      stringsAsFactors = FALSE
    )

    projection_registry <- projection_registry_replace_row(
      projection_registry,
      new_row
    )

    save_projection_registry()

    next
  }

  if (
    identical(
      configuration_id,
      "baseline"
    )
  ) {
    raster_file <- baseline_projection_raster_path(
      species_name
    )

    if (
      !validate_projection_raster(
        raster_file
      )
    ) {
      stop(
        "Script-22 revised baseline QPH projection raster is missing or ",
        "geometrically incompatible for ",
        species_name,
        "."
      )
    }

    new_row <- data.frame(
      Condition_ID = condition_id,
      Species = species_name,
      Configuration_ID = configuration_id,
      Success = TRUE,
      Reused_script22_baseline = TRUE,
      Reused_existing_sensitivity_raster = FALSE,
      Raster_file = normalizePath(
        raster_file,
        winslash = "/",
        mustWork = TRUE
      ),
      Raster_MD5 = safe_md5(
        raster_file
      ),
      Runtime_seconds = 0,
      Bounding_box_cell_count = NA_integer_,
      Error_message = NA_character_,
      stringsAsFactors = FALSE
    )

    projection_registry <- projection_registry_replace_row(
      projection_registry,
      new_row
    )

    save_projection_registry()

    next
  }

  output_raster_file <- sensitivity_projection_raster_path(
    species_name,
    configuration_id
  )

  if (
    resume_geographic_projections &&
      nrow(
        existing
      ) ==
        1L &&
      isTRUE(
        existing$Success[[1L]]
      ) &&
      validate_projection_raster(
        output_raster_file
      ) &&
      identical(
        safe_md5(
          output_raster_file
        ),
        existing$Raster_MD5[[1L]]
      )
  ) {
    next
  }

  if (
    nrow(
      existing
    ) ==
      1L &&
      !isTRUE(
        existing$Success[[1L]]
      ) &&
      !retry_failed_geographic_projections
  ) {
    next
  }

  message(
    "QPH geographic sensitivity ",
    condition_index,
    "/",
    nrow(
      sensitivity_design
    ),
    ": ",
    condition_id
  )

  projection_result <- tryCatch(
    {
      start_time <- proc.time()[[
        "elapsed"
      ]]

      projected <- project_qph_to_pc_raster_values(
        pc_values = pc_values,
        valid_cell_index = valid_cell_index,
        projection_model = bundle$projection_model
      )

      runtime_seconds <- (
        proc.time()[[
          "elapsed"
        ]] -
          start_time
      )

      make_binary_raster(
        template = pc_raster,
        values_vector = projected$inclusion,
        output_file = output_raster_file
      )

      data.frame(
        Condition_ID = condition_id,
        Species = species_name,
        Configuration_ID = configuration_id,
        Success = TRUE,
        Reused_script22_baseline = FALSE,
        Reused_existing_sensitivity_raster = FALSE,
        Raster_file = normalizePath(
          output_raster_file,
          winslash = "/",
          mustWork = TRUE
        ),
        Raster_MD5 = safe_md5(
          output_raster_file
        ),
        Runtime_seconds = runtime_seconds,
        Bounding_box_cell_count = projected$bounding_box_cell_count,
        Error_message = NA_character_,
        stringsAsFactors = FALSE
      )
    },
    error = function(error_condition) {
      data.frame(
        Condition_ID = condition_id,
        Species = species_name,
        Configuration_ID = configuration_id,
        Success = FALSE,
        Reused_script22_baseline = FALSE,
        Reused_existing_sensitivity_raster = FALSE,
        Raster_file = normalizePath(
          output_raster_file,
          winslash = "/",
          mustWork = FALSE
        ),
        Raster_MD5 = NA_character_,
        Runtime_seconds = NA_real_,
        Bounding_box_cell_count = NA_integer_,
        Error_message = conditionMessage(
          error_condition
        ),
        stringsAsFactors = FALSE
      )
    }
  )

  projection_registry <- projection_registry_replace_row(
    projection_registry,
    projection_result
  )

  save_projection_registry()

  gc()
}


# ============================================================
# Geographic area summaries
# ============================================================

geographic_rows <- list()
geographic_index <- 0L

for (
  condition_index in seq_len(
    nrow(
      sensitivity_design
    )
  )
) {
  design_row <- sensitivity_design[
    condition_index,
    ,
    drop = FALSE
  ]

  condition_id <- design_row$Condition_ID[[1L]]
  species_name <- design_row$Species[[1L]]
  configuration_id <- design_row$Configuration_ID[[1L]]

  registry_row <- projection_registry[
    projection_registry$Condition_ID ==
      condition_id,
    ,
    drop = FALSE
  ]

  geographic_index <- geographic_index + 1L

  if (
    nrow(
      registry_row
    ) !=
      1L ||
      !isTRUE(
        registry_row$Success[[1L]]
      )
  ) {
    geographic_rows[[
      geographic_index
    ]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Configuration_ID = configuration_id,
      Success = FALSE,
      Projected_area_km2 = NA_real_,
      Projected_area_million_km2 = NA_real_,
      Percent_available_domain = NA_real_,
      Included_cell_count = NA_integer_,
      Runtime_seconds = if (
        nrow(
          registry_row
        ) ==
          1L
      ) {
        registry_row$Runtime_seconds[[1L]]
      } else {
        NA_real_
      },
      Reused_script22_baseline = if (
        nrow(
          registry_row
        ) ==
          1L
      ) {
        registry_row$Reused_script22_baseline[[1L]]
      } else {
        FALSE
      },
      Raster_file = if (
        nrow(
          registry_row
        ) ==
          1L
      ) {
        registry_row$Raster_file[[1L]]
      } else {
        NA_character_
      },
      Error_message = if (
        nrow(
          registry_row
        ) ==
          1L
      ) {
        registry_row$Error_message[[1L]]
      } else {
        "Projection registry row unavailable."
      },
      stringsAsFactors = FALSE
    )

    next
  }

  raster_file <- registry_row$Raster_file[[1L]]

  raster_object <- terra::rast(
    raster_file
  )

  inclusion_values <- as.integer(
    as.numeric(
      terra::values(
        raster_object
      )
    )
  )

  included <- (
    is.finite(
      inclusion_values
    ) &
      inclusion_values ==
        1L &
      is.finite(
        cell_area_values
      )
  )

  projected_area_km2 <- sum(
    cell_area_values[
      included
    ],
    na.rm = TRUE
  )

  geographic_rows[[
    geographic_index
  ]] <- data.frame(
    Species = species_name,
    Species_code = species_code(
      species_name
    ),
    Configuration_ID = configuration_id,
    Success = TRUE,
    Projected_area_km2 = projected_area_km2,
    Projected_area_million_km2 = projected_area_km2 /
      1e6,
    Percent_available_domain = 100 *
      projected_area_km2 /
      available_domain_area_km2,
    Included_cell_count = sum(
      included
    ),
    Runtime_seconds = registry_row$Runtime_seconds[[1L]],
    Reused_script22_baseline = (
      registry_row$Reused_script22_baseline[[1L]]
    ),
    Raster_file = raster_file,
    Error_message = NA_character_,
    stringsAsFactors = FALSE
  )
}

geographic_area <- do.call(
  rbind,
  geographic_rows
)

baseline_geographic_area <- geographic_area[
  geographic_area$Configuration_ID ==
    "baseline" &
    geographic_area$Success,
  c(
    "Species",
    "Projected_area_km2"
  ),
  drop = FALSE
]

names(
  baseline_geographic_area
)[[
  2L
]] <- "Baseline_projected_area_km2"

geographic_area <- merge(
  geographic_area,
  baseline_geographic_area,
  by = "Species",
  all.x = TRUE,
  sort = FALSE
)

geographic_area$Geographic_area_ratio_to_baseline <- mapply(
  safe_ratio,
  geographic_area$Projected_area_km2,
  geographic_area$Baseline_projected_area_km2
)

geographic_area$Geographic_area_percent_change_from_baseline <- mapply(
  safe_percent_change,
  geographic_area$Projected_area_km2,
  geographic_area$Baseline_projected_area_km2
)

geographic_area$Geographic_area_rank <- NA_integer_

for (
  configuration_id in unique_configurations$Configuration_ID
) {
  indices <- which(
    geographic_area$Configuration_ID ==
      configuration_id &
      geographic_area$Success
  )

  if (
    length(
      indices
    ) >
      0L
  ) {
    geographic_area$Geographic_area_rank[
      indices
    ] <- rank(
      -geographic_area$Projected_area_km2[
        indices
      ],
      ties.method = "min"
    )
  }
}

baseline_geographic_ranks <- geographic_area[
  geographic_area$Configuration_ID ==
    "baseline",
  c(
    "Species",
    "Geographic_area_rank"
  ),
  drop = FALSE
]

names(
  baseline_geographic_ranks
)[[
  2L
]] <- "Baseline_geographic_area_rank"

geographic_area <- merge(
  geographic_area,
  baseline_geographic_ranks,
  by = "Species",
  all.x = TRUE,
  sort = FALSE
)

geographic_area$Geographic_rank_change_from_baseline <- (
  geographic_area$Geographic_area_rank -
    geographic_area$Baseline_geographic_area_rank
)

geographic_area$Geographic_rank_preserved <- (
  geographic_area$Geographic_rank_change_from_baseline ==
    0
)

write_csv_safely(
  geographic_area,
  geographic_area_file
)


# ============================================================
# Combine species-level geometry and geography
# ============================================================

summary_vs_baseline <- merge(
  model_summary,
  geometry_summary,
  by = c(
    "Species",
    "Species_code",
    "Configuration_ID",
    "Success"
  ),
  all.x = TRUE,
  sort = FALSE
)

summary_vs_baseline <- merge(
  summary_vs_baseline,
  rank_summary[
    ,
    c(
      "Species",
      "Configuration_ID",
      "Niche_breadth_rank",
      "Baseline_niche_breadth_rank",
      "Rank_change_from_baseline",
      "Rank_preserved"
    ),
    drop = FALSE
  ],
  by = c(
    "Species",
    "Configuration_ID"
  ),
  all.x = TRUE,
  sort = FALSE
)

summary_vs_baseline <- merge(
  summary_vs_baseline,
  geographic_area[
    ,
    c(
      "Species",
      "Configuration_ID",
      "Success",
      "Projected_area_km2",
      "Projected_area_million_km2",
      "Percent_available_domain",
      "Included_cell_count",
      "Baseline_projected_area_km2",
      "Geographic_area_ratio_to_baseline",
      "Geographic_area_percent_change_from_baseline",
      "Geographic_area_rank",
      "Baseline_geographic_area_rank",
      "Geographic_rank_change_from_baseline",
      "Geographic_rank_preserved"
    ),
    drop = FALSE
  ],
  by = c(
    "Species",
    "Configuration_ID"
  ),
  all.x = TRUE,
  suffixes = c(
    "",
    "_Geographic"
  ),
  sort = FALSE
)

write_csv_safely(
  summary_vs_baseline,
  summary_vs_baseline_file
)


# ============================================================
# Configuration-level stability summaries
# ============================================================

baseline_volume_vector <- model_summary[
  model_summary$Configuration_ID ==
    "baseline" &
    model_summary$Success,
  c(
    "Species",
    "Hypervolume_volume"
  ),
  drop = FALSE
]

baseline_area_vector <- geographic_area[
  geographic_area$Configuration_ID ==
    "baseline" &
    geographic_area$Success,
  c(
    "Species",
    "Projected_area_km2"
  ),
  drop = FALSE
]

baseline_overlap_vector <- overlap_summary[
  overlap_summary$Configuration_ID ==
    "baseline" &
    overlap_summary$Success,
  c(
    "Species_pair",
    "Jaccard_similarity"
  ),
  drop = FALSE
]

stability_rows <- list()
stability_index <- 0L

for (
  configuration_index in seq_len(
    nrow(
      unique_configurations
    )
  )
) {
  configuration <- unique_configurations[
    configuration_index,
    ,
    drop = FALSE
  ]

  configuration_id <- configuration$Configuration_ID[[1L]]

  if (
    identical(
      configuration_id,
      "baseline"
    )
  ) {
    next
  }

  current_volumes <- model_summary[
    model_summary$Configuration_ID ==
      configuration_id &
      model_summary$Success,
    c(
      "Species",
      "Hypervolume_volume"
    ),
    drop = FALSE
  ]

  volume_compare <- merge(
    baseline_volume_vector,
    current_volumes,
    by = "Species",
    suffixes = c(
      "_baseline",
      "_current"
    )
  )

  current_areas <- geographic_area[
    geographic_area$Configuration_ID ==
      configuration_id &
      geographic_area$Success,
    c(
      "Species",
      "Projected_area_km2"
    ),
    drop = FALSE
  ]

  area_compare <- merge(
    baseline_area_vector,
    current_areas,
    by = "Species",
    suffixes = c(
      "_baseline",
      "_current"
    )
  )

  current_overlap <- overlap_summary[
    overlap_summary$Configuration_ID ==
      configuration_id &
      overlap_summary$Success,
    c(
      "Species_pair",
      "Jaccard_similarity"
    ),
    drop = FALSE
  ]

  overlap_compare <- merge(
    baseline_overlap_vector,
    current_overlap,
    by = "Species_pair",
    suffixes = c(
      "_baseline",
      "_current"
    )
  )

  stability_index <- stability_index + 1L

  stability_rows[[
    stability_index
  ]] <- data.frame(
    Configuration_ID = configuration_id,
    Configuration_family = configuration$Configuration_family[[1L]],
    Bandwidth_multiplier = configuration$Bandwidth_multiplier[[1L]],
    q = configuration$q[[1L]],
    Samples_per_point = configuration$Samples_per_point[[1L]],
    Species_with_complete_volume = nrow(
      volume_compare
    ),
    Spearman_niche_breadth_correlation = if (
      nrow(
        volume_compare
      ) >=
        3L
    ) {
      suppressWarnings(
        stats::cor(
          volume_compare$Hypervolume_volume_baseline,
          volume_compare$Hypervolume_volume_current,
          method = "spearman"
        )
      )
    } else {
      NA_real_
    },
    Mean_absolute_volume_percent_change = if (
      nrow(
        volume_compare
      ) >
        0L
    ) {
      mean(
        abs(
          100 *
            (
              volume_compare$Hypervolume_volume_current /
                volume_compare$Hypervolume_volume_baseline -
                1
            )
        ),
        na.rm = TRUE
      )
    } else {
      NA_real_
    },
    Maximum_absolute_volume_percent_change = if (
      nrow(
        volume_compare
      ) >
        0L
    ) {
      max(
        abs(
          100 *
            (
              volume_compare$Hypervolume_volume_current /
                volume_compare$Hypervolume_volume_baseline -
                1
            )
        ),
        na.rm = TRUE
      )
    } else {
      NA_real_
    },
    Species_with_complete_geographic_area = nrow(
      area_compare
    ),
    Spearman_geographic_area_correlation = if (
      nrow(
        area_compare
      ) >=
        3L
    ) {
      suppressWarnings(
        stats::cor(
          area_compare$Projected_area_km2_baseline,
          area_compare$Projected_area_km2_current,
          method = "spearman"
        )
      )
    } else {
      NA_real_
    },
    Mean_absolute_geographic_area_percent_change = if (
      nrow(
        area_compare
      ) >
        0L
    ) {
      mean(
        abs(
          100 *
            (
              area_compare$Projected_area_km2_current /
                area_compare$Projected_area_km2_baseline -
                1
            )
        ),
        na.rm = TRUE
      )
    } else {
      NA_real_
    },
    Maximum_absolute_geographic_area_percent_change = if (
      nrow(
        area_compare
      ) >
        0L
    ) {
      max(
        abs(
          100 *
            (
              area_compare$Projected_area_km2_current /
                area_compare$Projected_area_km2_baseline -
                1
            )
        ),
        na.rm = TRUE
      )
    } else {
      NA_real_
    },
    Species_pairs_with_complete_overlap = nrow(
      overlap_compare
    ),
    Spearman_pairwise_Jaccard_correlation = if (
      nrow(
        overlap_compare
      ) >=
        3L
    ) {
      suppressWarnings(
        stats::cor(
          overlap_compare$Jaccard_similarity_baseline,
          overlap_compare$Jaccard_similarity_current,
          method = "spearman"
        )
      )
    } else {
      NA_real_
    },
    Mean_absolute_Jaccard_change = if (
      nrow(
        overlap_compare
      ) >
        0L
    ) {
      mean(
        abs(
          overlap_compare$Jaccard_similarity_current -
            overlap_compare$Jaccard_similarity_baseline
        ),
        na.rm = TRUE
      )
    } else {
      NA_real_
    },
    Maximum_absolute_Jaccard_change = if (
      nrow(
        overlap_compare
      ) >
        0L
    ) {
      max(
        abs(
          overlap_compare$Jaccard_similarity_current -
            overlap_compare$Jaccard_similarity_baseline
        ),
        na.rm = TRUE
      )
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
}

stability_summary <- do.call(
  rbind,
  stability_rows
)

write_csv_safely(
  stability_summary,
  stability_summary_file
)


# ============================================================
# Plot-ready OFAT tables for Script 24
# ============================================================

plot_ready_species <- merge(
  plot_design,
  summary_vs_baseline,
  by = "Configuration_ID",
  all.x = TRUE,
  sort = FALSE
)

plot_ready_species$Species <- factor(
  plot_ready_species$Species,
  levels = expected_species
)

plot_ready_species$Sensitivity_family <- factor(
  plot_ready_species$Sensitivity_family,
  levels = c(
    "Bandwidth multiplier",
    "Potential q"
  )
)

plot_ready_species <- plot_ready_species[
  order(
    plot_ready_species$Sensitivity_family,
    plot_ready_species$Parameter_value,
    plot_ready_species$Species
  ),
  ,
  drop = FALSE
]

plot_ready_species$Species <- as.character(
  plot_ready_species$Species
)

plot_ready_species$Sensitivity_family <- as.character(
  plot_ready_species$Sensitivity_family
)

write_csv_safely(
  plot_ready_species,
  plot_ready_species_file
)


plot_ready_overlap <- merge(
  plot_design,
  overlap_change,
  by = "Configuration_ID",
  all.x = TRUE,
  sort = FALSE
)

plot_ready_overlap$Sensitivity_family <- factor(
  plot_ready_overlap$Sensitivity_family,
  levels = c(
    "Bandwidth multiplier",
    "Potential q"
  )
)

plot_ready_overlap <- plot_ready_overlap[
  order(
    plot_ready_overlap$Sensitivity_family,
    plot_ready_overlap$Parameter_value,
    plot_ready_overlap$Species_pair
  ),
  ,
  drop = FALSE
]

plot_ready_overlap$Sensitivity_family <- as.character(
  plot_ready_overlap$Sensitivity_family
)

write_csv_safely(
  plot_ready_overlap,
  plot_ready_overlap_file
)


# ============================================================
# Failure audit
# ============================================================

failure_rows <- list()
failure_index <- 0L

failed_models <- model_registry[
  !model_registry$Success,
  ,
  drop = FALSE
]

if (
  nrow(
    failed_models
  ) >
    0L
) {
  for (
    row_index in seq_len(
      nrow(
        failed_models
      )
    )
  ) {
    failure_index <- failure_index + 1L

    failure_rows[[
      failure_index
    ]] <- data.frame(
      Failure_stage = "QPH model fitting",
      Species = failed_models$Species[[row_index]],
      Configuration_ID = failed_models$Configuration_ID[[row_index]],
      Comparison = NA_character_,
      Error_message = failed_models$Error_message[[row_index]],
      stringsAsFactors = FALSE
    )
  }
}


failed_overlap <- overlap_summary[
  !overlap_summary$Success,
  ,
  drop = FALSE
]

if (
  nrow(
    failed_overlap
  ) >
    0L
) {
  for (
    row_index in seq_len(
      nrow(
        failed_overlap
      )
    )
  ) {
    failure_index <- failure_index + 1L

    failure_rows[[
      failure_index
    ]] <- data.frame(
      Failure_stage = "Between-species environmental overlap",
      Species = NA_character_,
      Configuration_ID = failed_overlap$Configuration_ID[[row_index]],
      Comparison = failed_overlap$Species_pair[[row_index]],
      Error_message = failed_overlap$Error_message[[row_index]],
      stringsAsFactors = FALSE
    )
  }
}


failed_projection <- projection_registry[
  !projection_registry$Success,
  ,
  drop = FALSE
]

if (
  nrow(
    failed_projection
  ) >
    0L
) {
  for (
    row_index in seq_len(
      nrow(
        failed_projection
      )
    )
  ) {
    failure_index <- failure_index + 1L

    failure_rows[[
      failure_index
    ]] <- data.frame(
      Failure_stage = "Geographic projection",
      Species = failed_projection$Species[[row_index]],
      Configuration_ID = failed_projection$Configuration_ID[[row_index]],
      Comparison = NA_character_,
      Error_message = failed_projection$Error_message[[row_index]],
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
    Failure_stage = character(0),
    Species = character(0),
    Configuration_ID = character(0),
    Comparison = character(0),
    Error_message = character(0),
    stringsAsFactors = FALSE
  )
}

write_csv_safely(
  failure_table,
  failure_file
)


# ============================================================
# Final model/projection registry ordering
# ============================================================

model_registry$Species <- factor(
  model_registry$Species,
  levels = expected_species
)

model_registry$Configuration_ID <- factor(
  model_registry$Configuration_ID,
  levels = unique_configurations$Configuration_ID
)

model_registry <- model_registry[
  order(
    model_registry$Species,
    model_registry$Configuration_ID
  ),
  ,
  drop = FALSE
]

model_registry$Species <- as.character(
  model_registry$Species
)

model_registry$Configuration_ID <- as.character(
  model_registry$Configuration_ID
)


projection_registry$Species <- factor(
  projection_registry$Species,
  levels = expected_species
)

projection_registry$Configuration_ID <- factor(
  projection_registry$Configuration_ID,
  levels = unique_configurations$Configuration_ID
)

projection_registry <- projection_registry[
  order(
    projection_registry$Species,
    projection_registry$Configuration_ID
  ),
  ,
  drop = FALSE
]

projection_registry$Species <- as.character(
  projection_registry$Species
)

projection_registry$Configuration_ID <- as.character(
  projection_registry$Configuration_ID
)


# ============================================================
# Final result object
# ============================================================

run_metadata <- list(
  script = "23_Acacia_QPH_Sensitivity.R",
  analysis_settings_hash = analysis_settings_hash,
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  geographic_analysis_hash = geographic_analysis_hash,
  qph_core_version = QPH_CORE_VERSION,
  qph_core_md5 = qph_core_md5,
  unique_configurations_per_species = nrow(
    unique_configurations
  ),
  species_count = length(
    expected_species
  ),
  unique_species_conditions = nrow(
    sensitivity_design
  ),
  baseline_models_reused = sum(
    sensitivity_design$Is_baseline
  ),
  new_qph_fits_requested = sum(
    sensitivity_design$Requires_new_fit
  ),
  successful_species_conditions = sum(
    model_registry$Success
  ),
  overlap_comparisons_requested = total_overlap_comparisons,
  overlap_comparisons_successful = sum(
    overlap_summary$Success
  ),
  geographic_projections_requested = nrow(
    sensitivity_design
  ),
  geographic_projections_successful = sum(
    projection_registry$Success
  ),
  topology_sensitivity = FALSE,
  comparator_sensitivity = FALSE,
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
  unique_configurations = unique_configurations,
  sensitivity_design = sensitivity_design,
  plot_design = plot_design,
  baseline_qa = baseline_qa,
  model_registry = model_registry,
  projection_registry = projection_registry,
  qph_audit = audit_summary_table,
  model_summary = model_summary,
  geometry_summary = geometry_summary,
  niche_breadth_rankings = rank_summary,
  between_species_overlap = overlap_summary,
  overlap_change_vs_baseline = overlap_change,
  geographic_area = geographic_area,
  summary_vs_baseline = summary_vs_baseline,
  stability_summary = stability_summary,
  plot_ready_species = plot_ready_species,
  plot_ready_overlap = plot_ready_overlap,
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
  "ACACIA QPH SENSITIVITY",
  "======================",
  "",
  "Scope:",
  "  QPH only.",
  "  Gaussian KDE and SVM are unchanged and are not refitted.",
  "  No topology sensitivity analysis is performed.",
  "",
  "Revised QPH baseline:",
  "  Nasios-Bors-derived square-root local-distance bandwidth",
  "  K = round(sqrt(n))",
  "  s_i = sum of K squared nearest-other distances / (K - 1)",
  "  h = sqrt(mean(s_i))",
  "  isotropic bandwidth",
  "  q = 0.99",
  "  samples.per.point = 100",
  "  sd.count = 3",
  "",
  "OFAT sensitivity:",
  "  bandwidth multiplier = 0.75, 1.00, 1.25",
  "  q = 0.950, 0.975, 0.990",
  "  samples.per.point = 100 for every condition",
  "",
  "Unique conditions per species = 5.",
  "Species = 5.",
  "Unique species x condition rows = 25.",
  "Script-19 revised baseline objects reused = 5.",
  "New QPH fits requested = 20.",
  "",
  "All sensitivity fits for a species reuse that species' Script-19 QPH",
  "sampling seed to reduce avoidable Monte-Carlo seed differences.",
  "",
  "Empirical endpoints:",
  "  environmental volume",
  "  centroid displacement from occurrence cloud",
  "  centroid displacement from baseline QPH",
  "  niche-breadth rank stability",
  "  between-species environmental overlap",
  "  projected Australian geographic area",
  "  projected-area rank stability",
  "",
  "Geographic projections are potential geographic projections of the fitted",
  "environmental hypervolumes. No empirical geographic truth is assumed.",
  "",
  "samples.per.point is fixed at 100 and is not an empirical sensitivity axis.",
  "",
  "Publication figures are deferred to Script 24.",
  "",
  paste0(
    "Successful model conditions: ",
    sum(
      model_registry$Success
    ),
    " / ",
    nrow(
      model_registry
    )
  ),
  paste0(
    "Successful environmental overlaps: ",
    sum(
      overlap_summary$Success
    ),
    " / ",
    nrow(
      overlap_summary
    )
  ),
  paste0(
    "Successful geographic projections: ",
    sum(
      projection_registry$Success
    ),
    " / ",
    nrow(
      projection_registry
    )
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
    "Geographic analysis hash: ",
    geographic_analysis_hash
  ),
  paste0(
    "Sensitivity analysis hash: ",
    analysis_settings_hash
  ),
  paste0(
    "QPH core version: ",
    QPH_CORE_VERSION
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
# Final console summaries
# ============================================================

message(
  "\n============================================================"
)

message(
  "23_Acacia_QPH_Sensitivity.R complete."
)

message(
  "\nSensitivity design:"
)

print(
  unique_configurations,
  row.names = FALSE
)

message(
  "\nSpecies-level volume / centroid / geography sensitivity:"
)

print(
  summary_vs_baseline[
    ,
    c(
      "Species",
      "Configuration_ID",
      "Bandwidth_multiplier",
      "q",
      "Samples_per_point",
      "Hypervolume_volume",
      "Volume_ratio_to_baseline",
      "Centroid_displacement_from_baseline_QPH",
      "Projected_area_km2",
      "Geographic_area_ratio_to_baseline"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)

message(
  "\nConfiguration-level stability:"
)

print(
  stability_summary,
  digits = 5,
  row.names = FALSE
)

message(
  "\nNiche-breadth ranks:"
)

print(
  rank_summary[
    ,
    c(
      "Species",
      "Configuration_ID",
      "Niche_breadth_rank",
      "Baseline_niche_breadth_rank",
      "Rank_change_from_baseline"
    ),
    drop = FALSE
  ],
  row.names = FALSE
)

message(
  "\nSuccessful new/reused model conditions: ",
  sum(
    model_registry$Success
  ),
  " / ",
  nrow(
    model_registry
  )
)

message(
  "Successful overlap comparisons: ",
  sum(
    overlap_summary$Success
  ),
  " / ",
  nrow(
    overlap_summary
  )
)

message(
  "Successful geographic projections: ",
  sum(
    projection_registry$Success
  ),
  " / ",
  nrow(
    projection_registry
  )
)

message(
  "Failure records: ",
  nrow(
    failure_table
  )
)

message(
  "\nFinal sensitivity object:\n  ",
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
# Completion warning
# ============================================================

if (
  nrow(
    failure_table
  ) >
    0L
) {
  warning(
    "Script 23 completed with ",
    nrow(
      failure_table
    ),
    " recorded failure(s). Inspect:\n  ",
    normalizePath(
      failure_file,
      winslash = "/",
      mustWork = FALSE
    )
  )
}
