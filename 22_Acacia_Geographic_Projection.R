# ============================================================
# 22_Acacia_Geographic_Projection.R
# ============================================================
#
# PURPOSE
# -------
# Project the revised baseline environmental hypervolumes for the FIVE locked
# empirical Acacia species back into geographic space across Australia.
#


rm(list = ls())
gc()


# ============================================================
# Packages
# ============================================================

required_packages <- c(
  "terra",
  "hypervolume",
  "e1071",
  "ggplot2",
  "patchwork",
  "maps"
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

library(terra)
library(hypervolume)
library(e1071)
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

output_directory <- file.path(
  analysis_root_directory,
  "04_Geographic_Projection"
)

raster_output_directory <- file.path(
  output_directory,
  "projection_rasters"
)

table_directory <- file.path(
  output_directory,
  "tables"
)

figure_directory <- file.path(
  output_directory,
  "figures"
)

for (directory in c(
  output_directory,
  raster_output_directory,
  table_directory,
  figure_directory
)) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ============================================================
# Optional environmental-source overrides
# ============================================================
#
# Normally no edits are required. Script 22 first tries the exact raster
# source files recorded inside the Script-18 authoritative archive.
#
# If the original WorldClim files have been moved, set BOTH overrides below.
# The script still checks filenames/order, file sizes where available, raster
# geometry and environmental-variable identity against the locked archive.
# ============================================================

bio_directory_override <- NA_character_
elevation_file_override <- NA_character_


# ============================================================
# Locked design
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

expected_environment_names <- c(
  paste0(
    "bio",
    1:19
  ),
  "elevation"
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

method_colours <- c(
  "Gaussian KDE" = "#D7301F",
  "SVM" = "#238B45",
  "QPH" = "#2C7FB8"
)

occurrence_colour <- "#111111"
shared_area_colour <- "#D9D9D9"


# ============================================================
# Projection settings
# ============================================================

australia_extent_values <- c(
  xmin = 112,
  xmax = 154,
  ymin = -44,
  ymax = -10
)

# Preserve the completed empirical projection's computational batching.
projection_batch_size <- 1000L
svm_prediction_batch_size <- 25000L

# Used only by hypervolume's internal KDE density calibration.
shared_chunk_size <- 100L

# Native raster resolution is always used numerically.
plot_aggregation_factor <- 2L

resume_from_existing_rasters <- TRUE
show_progress_messages <- TRUE

projection_tolerance <- sqrt(
  .Machine$double.eps
)

figure_tiff_dpi <- 600L


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
    "\nScripts 18 and 19 must complete before Script 22."
  )
}


# ============================================================
# Output files
# ============================================================

analysis_settings_file <- file.path(
  output_directory,
  "analysis_settings.rds"
)

pc_raster_file <- file.path(
  raster_output_directory,
  "Australia_occurrence_PCA_PC1_PC3.tif"
)

land_mask_file <- file.path(
  raster_output_directory,
  "Australia_complete_environment_mask.tif"
)

cell_area_file <- file.path(
  raster_output_directory,
  "Australia_cell_area_km2.tif"
)

projection_summary_file <- file.path(
  table_directory,
  "acacia_geographic_projection_area_summary.csv"
)

projection_runtime_file <- file.path(
  table_directory,
  "acacia_geographic_projection_runtime.csv"
)

projection_parameters_file <- file.path(
  table_directory,
  "acacia_geographic_projection_parameters.csv"
)

within_species_overlap_file <- file.path(
  table_directory,
  "acacia_geographic_cross_method_overlap.csv"
)

within_species_area_ratio_file <- file.path(
  table_directory,
  "acacia_geographic_cross_method_area_ratios.csv"
)

between_species_overlap_file <- file.path(
  table_directory,
  "acacia_geographic_between_species_overlap.csv"
)

occurrence_coverage_file <- file.path(
  table_directory,
  "acacia_geographic_occurrence_coverage.csv"
)

environmental_geographic_comparison_file <- file.path(
  table_directory,
  "acacia_environmental_volume_vs_geographic_area.csv"
)

environment_source_qa_file <- file.path(
  table_directory,
  "acacia_geographic_environment_source_QA.csv"
)

model_validation_file <- file.path(
  table_directory,
  "acacia_geographic_model_validation.csv"
)

projection_manifest_file <- file.path(
  table_directory,
  "acacia_geographic_projection_manifest.csv"
)

main_map_pdf <- file.path(
  figure_directory,
  "Figure_Acacia_geographic_projections.pdf"
)

main_map_png <- file.path(
  figure_directory,
  "Figure_Acacia_geographic_projections.png"
)

main_map_tiff <- file.path(
  figure_directory,
  "Figure_Acacia_geographic_projections.tiff"
)

summary_figure_pdf <- file.path(
  figure_directory,
  "Figure_Acacia_geographic_summary.pdf"
)

summary_figure_png <- file.path(
  figure_directory,
  "Figure_Acacia_geographic_summary.png"
)

difference_figure_pdf <- file.path(
  figure_directory,
  "Supplementary_Acacia_geographic_difference_maps.pdf"
)

difference_figure_png <- file.path(
  figure_directory,
  "Supplementary_Acacia_geographic_difference_maps.png"
)

between_species_heatmap_pdf <- file.path(
  figure_directory,
  "Supplementary_Acacia_geographic_overlap_heatmaps.pdf"
)

between_species_heatmap_png <- file.path(
  figure_directory,
  "Supplementary_Acacia_geographic_overlap_heatmaps.png"
)

environmental_geographic_figure_pdf <- file.path(
  figure_directory,
  "Supplementary_Acacia_environmental_vs_geographic_area.pdf"
)

environmental_geographic_figure_png <- file.path(
  figure_directory,
  "Supplementary_Acacia_environmental_vs_geographic_area.png"
)

run_metadata_file <- file.path(
  output_directory,
  "acacia_geographic_projection_metadata.rds"
)

final_results_file <- file.path(
  output_directory,
  "acacia_geographic_projection_sqrtNB_q099.rds"
)

analysis_notes_file <- file.path(
  output_directory,
  "ACACIA_GEOGRAPHIC_PROJECTION_NOTES.txt"
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


projection_raster_path <- function(
    species_name,
    method_name
) {
  file.path(
    raster_output_directory,
    paste0(
      species_code(
        species_name
      ),
      "__",
      method_code(
        method_name
      ),
      "__geographic_inclusion.tif"
    )
  )
}


format_species_label <- function(species_name) {
  sub(
    "^Acacia ",
    "A. ",
    species_name
  )
}


validate_numeric_matrix <- function(
    x,
    object_name = "x",
    expected_columns = NULL
) {
  x <- as.matrix(
    x
  )
  storage.mode(
    x
  ) <- "double"

  if (
    !is.null(
      expected_columns
    ) &&
      ncol(
        x
      ) !=
        expected_columns
  ) {
    stop(
      object_name,
      " must contain exactly ",
      expected_columns,
      " columns."
    )
  }

  if (
    nrow(
      x
    ) <
      1L
  ) {
    stop(
      object_name,
      " contains no rows."
    )
  }

  if (any(!is.finite(x))) {
    stop(
      object_name,
      " contains non-finite values."
    )
  }

  x
}


prediction_to_inside <- function(prediction) {
  if (is.logical(prediction)) {
    return(
      as.logical(
        prediction
      )
    )
  }

  if (is.factor(prediction)) {
    prediction <- as.character(
      prediction
    )
  }

  if (is.character(prediction)) {
    lower_prediction <- tolower(
      prediction
    )

    inside <- lower_prediction %in%
      c(
        "true",
        "1",
        "+1",
        "inside",
        "in",
        "yes"
      )

    outside <- lower_prediction %in%
      c(
        "false",
        "0",
        "-1",
        "outside",
        "out",
        "no"
      )

    if (!all(inside | outside)) {
      stop(
        "Could not interpret one-class SVM predictions."
      )
    }

    return(inside)
  }

  numeric_prediction <- suppressWarnings(
    as.numeric(
      prediction
    )
  )

  if (
    any(
      !is.finite(
        numeric_prediction
      )
    )
  ) {
    stop(
      "Could not interpret one-class SVM predictions."
    )
  }

  numeric_prediction >
    0
}


# ============================================================
# Load locked upstream objects
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
  is.null(
    locked_design_hash
  ) ||
    is.null(
      baseline_analysis_hash
    )
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
    "Script 22 requires all 15 Script-19 baseline model fits to have succeeded."
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
    "Locked species order differs from the Script-22 design."
  )
}

if (
  !identical(
    as.character(
      locked_settings$environmental_variables
    ),
    expected_environment_names
  )
) {
  stop(
    "Locked environmental-variable order is not bio1-bio19 + elevation."
  )
}

shared_pca <- locked_inputs$shared_pca
occurrence_metadata <- locked_inputs$final_occurrence_metadata
raster_manifest <- locked_inputs$raster_manifest

if (is.null(shared_pca)) {
  stop(
    "Locked archive contains no shared_pca object."
  )
}

if (is.null(occurrence_metadata)) {
  stop(
    "Locked archive contains no final_occurrence_metadata."
  )
}

if (
  !all(
    c(
      "species",
      "longitude",
      "latitude"
    ) %in%
      names(
        occurrence_metadata
      )
  )
) {
  stop(
    "Locked occurrence metadata lacks species/longitude/latitude columns."
  )
}

if (
  is.null(
    raster_manifest
  ) ||
    !all(
      c(
        "Layer_order",
        "Standardised_layer_name",
        "Source_file",
        "File_size_bytes"
      ) %in%
        names(
          raster_manifest
        )
    )
) {
  stop(
    "Locked archive raster manifest is absent or incomplete."
  )
}

raster_manifest <- raster_manifest[
  order(
    raster_manifest$Layer_order
  ),
  ,
  drop = FALSE
]

if (
  !identical(
    as.character(
      raster_manifest$Standardised_layer_name
    ),
    expected_environment_names
  )
) {
  stop(
    "Locked raster manifest order does not match the environmental design."
  )
}


# ============================================================
# Load and validate all 15 model bundles
# ============================================================

model_bundles <- stats::setNames(
  vector(
    "list",
    length(
      expected_species
    )
  ),
  expected_species
)

model_file_md5 <- character(0)
model_validation_rows <- list()
model_validation_index <- 0L

for (
  species_name in expected_species
) {
  model_bundles[[species_name]] <- list()

  for (
    method_name in method_order
  ) {
    current_file <- model_file_path(
      species_name,
      method_name
    )

    if (!file.exists(current_file)) {
      stop(
        "Missing Script-19 model object:\n  ",
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
        "Model metadata/provenance mismatch for ",
        species_name,
        " / ",
        method_name,
        "."
      )
    }

    if (is.null(bundle$projection_model)) {
      stop(
        "Projection model missing for ",
        species_name,
        " / ",
        method_name,
        "."
      )
    }

    methods::validObject(
      bundle$hypervolume
    )

    parameter_check <- TRUE
    parameter_note <- NA_character_

    if (identical(method_name, "QPH")) {
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
          )
      )

      parameter_note <- (
        "sqrt-NB isotropic bandwidth; q=0.99"
      )
    } else if (
      identical(
        method_name,
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
        "independent Silverman bandwidth; probability quantile=0.95"
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
          ) &&
          isTRUE(
            bundle$projection_model$internal_scaling
          )
      )

      parameter_note <- (
        "one-class radial SVM; nu=0.01; gamma=0.50; scale=TRUE"
      )
    }

    if (!isTRUE(parameter_check)) {
      stop(
        "Projection baseline QA failed for ",
        species_name,
        " / ",
        method_name,
        "."
      )
    }

    condition_id <- model_key(
      species_name,
      method_name
    )

    model_file_md5[[condition_id]] <- safe_md5(
      current_file
    )

    model_validation_index <- model_validation_index + 1L

    model_validation_rows[[
      model_validation_index
    ]] <- data.frame(
      Condition_id = condition_id,
      Species = species_name,
      Method = method_name,
      Occurrence_count = bundle$metadata$occurrence_count,
      Hypervolume_volume = as.numeric(
        bundle$hypervolume@Volume
      ),
      Random_point_count = nrow(
        bundle$hypervolume@RandomPoints
      ),
      Parameter_check = parameter_check,
      Parameter_note = parameter_note,
      Model_MD5 = safe_md5(
        current_file
      ),
      stringsAsFactors = FALSE
    )

    model_bundles[[species_name]][[
      method_name
    ]] <- bundle
  }
}

model_validation <- do.call(
  rbind,
  model_validation_rows
)

write_csv_safely(
  model_validation,
  model_validation_file
)


# ============================================================
# Resolve the exact environmental raster sources
# ============================================================

extract_bioclim_number <- function(path) {
  filename <- basename(
    path
  )

  matches <- regexec(
    "bio[_-]?([0-9]{1,2})(?:[^0-9]|$)",
    filename,
    ignore.case = TRUE
  )

  capture <- regmatches(
    filename,
    matches
  )[[1L]]

  if (length(capture) < 2L) {
    return(NA_integer_)
  }

  as.integer(
    capture[[2L]]
  )
}


resolve_environmental_source_files <- function() {
  # 1. Explicit user override.
  if (
    !is.na(
      bio_directory_override
    ) &&
      nzchar(
        bio_directory_override
      ) &&
      !is.na(
        elevation_file_override
      ) &&
      nzchar(
        elevation_file_override
      )
  ) {
    if (!dir.exists(bio_directory_override)) {
      stop(
        "bio_directory_override does not exist:\n  ",
        bio_directory_override
      )
    }

    if (!file.exists(elevation_file_override)) {
      stop(
        "elevation_file_override does not exist:\n  ",
        elevation_file_override
      )
    }

    bio_files <- list.files(
      bio_directory_override,
      pattern = "\\.tif$",
      full.names = TRUE,
      ignore.case = TRUE
    )

    return(
      list(
        bio_files = bio_files,
        elevation_file = elevation_file_override,
        resolution_route = "explicit override"
      )
    )
  }

  # 2. Exact files recorded in the locked raster manifest.
  manifest_files <- as.character(
    raster_manifest$Source_file
  )

  if (
    length(
      manifest_files
    ) ==
      20L &&
      all(
        file.exists(
          manifest_files
        )
      )
  ) {
    return(
      list(
        bio_files = manifest_files[
          1:19
        ],
        elevation_file = manifest_files[[
          20L
        ]],
        resolution_route = "locked raster manifest exact paths"
      )
    )
  }

  # 3. Original directories stored in the authoritative archive.
  original_bio_directory <- locked_inputs$settings$bio_directory
  original_elevation_file <- locked_inputs$settings$elevation_file

  if (
    !is.null(
      original_bio_directory
    ) &&
      !is.null(
        original_elevation_file
      ) &&
      dir.exists(
        original_bio_directory
      ) &&
      file.exists(
        original_elevation_file
      )
  ) {
    bio_files <- list.files(
      original_bio_directory,
      pattern = "\\.tif$",
      full.names = TRUE,
      ignore.case = TRUE
    )

    return(
      list(
        bio_files = bio_files,
        elevation_file = original_elevation_file,
        resolution_route = "authoritative archive settings"
      )
    )
  }

  # 4. Known project-machine locations.
  bio_candidates <- unique(
    c(
      file.path(
        path.expand(
          "~/Desktop/WorldClim/BIO_2.5"
        ),
        "wc2.1_2.5m_bio"
      ),
      "C:/Users/r02jt24/Desktop/WorldClim/BIO_2.5/wc2.1_2.5m_bio"
    )
  )

  elevation_candidates <- unique(
    c(
      file.path(
        path.expand(
          "~/Desktop/WorldClim/Elev_2.5"
        ),
        "wc2.1_2.5m_elev",
        "wc2.1_2.5m_elev.tif"
      ),
      "C:/Users/r02jt24/Desktop/WorldClim/Elev_2.5/wc2.1_2.5m_elev/wc2.1_2.5m_elev.tif"
    )
  )

  existing_bio <- bio_candidates[
    dir.exists(
      bio_candidates
    )
  ]

  existing_elevation <- elevation_candidates[
    file.exists(
      elevation_candidates
    )
  ]

  if (
    length(
      existing_bio
    ) >
      0L &&
      length(
        existing_elevation
      ) >
        0L
  ) {
    bio_files <- list.files(
      existing_bio[[1L]],
      pattern = "\\.tif$",
      full.names = TRUE,
      ignore.case = TRUE
    )

    return(
      list(
        bio_files = bio_files,
        elevation_file = existing_elevation[[1L]],
        resolution_route = "known WorldClim desktop location"
      )
    )
  }

  stop(
    "Could not locate the 19 WorldClim bioclimatic rasters and elevation. ",
    "Set bio_directory_override and elevation_file_override near the top ",
    "of Script 22."
  )
}


resolved_environment <- resolve_environmental_source_files()

bio_files <- resolved_environment$bio_files
elevation_file <- resolved_environment$elevation_file

if (length(bio_files) != 19L) {
  stop(
    "Expected exactly 19 bioclimatic .tif files but found ",
    length(
      bio_files
    ),
    "."
  )
}

bio_numbers <- vapply(
  bio_files,
  extract_bioclim_number,
  integer(1)
)

if (
  anyNA(
    bio_numbers
  ) ||
    !setequal(
      bio_numbers,
      1:19
    )
) {
  stop(
    "Could not uniquely identify bio1 through bio19 from the selected files."
  )
}

bio_files <- bio_files[
  order(
    bio_numbers
  )
]

resolved_source_files <- c(
  bio_files,
  elevation_file
)

resolved_source_names <- c(
  paste0(
    "bio",
    1:19
  ),
  "elevation"
)

# Compare file sizes with the locked manifest. This is a cheap but useful
# identity check when the files have moved to a different filesystem.
current_file_sizes <- as.numeric(
  file.info(
    resolved_source_files
  )$size
)

locked_file_sizes <- as.numeric(
  raster_manifest$File_size_bytes
)

environment_source_qa <- data.frame(
  Layer_order = seq_along(
    resolved_source_files
  ),
  Standardised_layer_name = resolved_source_names,
  Locked_source_file = as.character(
    raster_manifest$Source_file
  ),
  Resolved_source_file = normalizePath(
    resolved_source_files,
    winslash = "/",
    mustWork = TRUE
  ),
  Locked_file_size_bytes = locked_file_sizes,
  Resolved_file_size_bytes = current_file_sizes,
  File_size_matches_locked_manifest = (
    current_file_sizes ==
      locked_file_sizes
  ),
  Resolution_route = resolved_environment$resolution_route,
  stringsAsFactors = FALSE
)

if (
  any(
    !environment_source_qa$File_size_matches_locked_manifest
  )
) {
  stop(
    "One or more resolved environmental rasters differ in file size from ",
    "the Script-18 locked raster manifest. Refusing to project a changed ",
    "environmental dataset."
  )
}

write_csv_safely(
  environment_source_qa,
  environment_source_qa_file
)


# ============================================================
# Load, validate and crop environmental rasters
# ============================================================

message(
  "Loading locked WorldClim/elevation environmental rasters..."
)

bio_stack <- terra::rast(
  bio_files
)

elevation_raster <- terra::rast(
  elevation_file
)

if (
  terra::nlyr(
    bio_stack
  ) !=
    19L
) {
  stop(
    "Bioclimatic raster stack does not contain 19 layers."
  )
}

if (
  terra::nlyr(
    elevation_raster
  ) !=
    1L
) {
  stop(
    "Elevation raster must contain exactly one layer."
  )
}

for (
  layer_index in seq_len(
    terra::nlyr(
      bio_stack
    )
  )
) {
  if (
    !isTRUE(
      terra::compareGeom(
        bio_stack[[1L]],
        bio_stack[[layer_index]],
        stopOnError = FALSE
      )
    )
  ) {
    stop(
      "Bioclimatic raster layer ",
      layer_index,
      " does not share the bio1 geometry."
    )
  }
}

if (
  !isTRUE(
    terra::compareGeom(
      bio_stack[[1L]],
      elevation_raster,
      stopOnError = FALSE
    )
  )
) {
  stop(
    "Elevation raster geometry does not match the bioclimatic rasters."
  )
}

names(
  bio_stack
) <- paste0(
  "bio",
  1:19
)

names(
  elevation_raster
) <- "elevation"

environmental_stack <- c(
  bio_stack,
  elevation_raster
)

if (
  !identical(
    names(
      environmental_stack
    ),
    expected_environment_names
  )
) {
  stop(
    "Environmental raster layer names/order are not as expected."
  )
}

# Confirm geometry against the values stored in the locked manifest.
manifest_geometry_columns <- c(
  "Raster_rows",
  "Raster_columns",
  "Resolution_x",
  "Resolution_y",
  "Extent_xmin",
  "Extent_xmax",
  "Extent_ymin",
  "Extent_ymax"
)

if (
  all(
    manifest_geometry_columns %in%
      names(
        raster_manifest
      )
  )
) {
  current_extent <- as.vector(
    terra::ext(
      environmental_stack
    )
  )

  current_resolution <- terra::res(
    environmental_stack
  )

  locked_geometry_ok <- (
    all(
      raster_manifest$Raster_rows ==
        terra::nrow(
          environmental_stack
        )
    ) &&
      all(
        raster_manifest$Raster_columns ==
          terra::ncol(
            environmental_stack
          )
      ) &&
      all(
        abs(
          raster_manifest$Resolution_x -
            current_resolution[[1L]]
        ) <
          1e-12
      ) &&
      all(
        abs(
          raster_manifest$Resolution_y -
            current_resolution[[2L]]
        ) <
          1e-12
      ) &&
      all(
        abs(
          raster_manifest$Extent_xmin -
            current_extent[[1L]]
        ) <
          1e-10
      ) &&
      all(
        abs(
          raster_manifest$Extent_xmax -
            current_extent[[2L]]
        ) <
          1e-10
      ) &&
      all(
        abs(
          raster_manifest$Extent_ymin -
            current_extent[[3L]]
        ) <
          1e-10
      ) &&
      all(
        abs(
          raster_manifest$Extent_ymax -
            current_extent[[4L]]
        ) <
          1e-10
      )
  )

  if (!locked_geometry_ok) {
    stop(
      "Resolved environmental raster geometry differs from the Script-18 ",
      "locked raster manifest."
    )
  }
}

australia_extent <- terra::ext(
  australia_extent_values[[
    "xmin"
  ]],
  australia_extent_values[[
    "xmax"
  ]],
  australia_extent_values[[
    "ymin"
  ]],
  australia_extent_values[[
    "ymax"
  ]]
)

environmental_stack <- terra::crop(
  environmental_stack,
  australia_extent,
  snap = "out"
)

if (
  !terra::is.lonlat(
    environmental_stack,
    perhaps = TRUE,
    warn = FALSE
  )
) {
  warning(
    "Environmental raster CRS is not identified as longitude/latitude. ",
    "Area will still be calculated using terra::cellSize(transform=TRUE)."
  )
}


# ============================================================
# Validate the locked PCA against environmental variables
# ============================================================

if (
  is.null(
    shared_pca$center
  ) ||
    is.null(
      shared_pca$scale
    ) ||
    is.null(
      shared_pca$rotation
    )
) {
  stop(
    "Locked PCA lacks centre, scale or rotation."
  )
}

if (
  length(
    shared_pca$center
  ) !=
    20L ||
    length(
      shared_pca$scale
    ) !=
      20L ||
    nrow(
      shared_pca$rotation
    ) !=
      20L
) {
  stop(
    "Locked PCA does not have the expected 20-variable structure."
  )
}

if (
  !identical(
    rownames(
      shared_pca$rotation
    ),
    expected_environment_names
  )
) {
  stop(
    "PCA variable order differs from the environmental raster order."
  )
}


# ============================================================
# Analysis settings / provenance hash
# ============================================================

raster_manifest_hash <- hash_r_object(
  raster_manifest
)

analysis_settings <- list(
  script = "22_Acacia_Geographic_Projection.R",
  analysis_branch = "Acacia_sqrtNB_q099",
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  model_file_md5 = model_file_md5,
  raster_manifest_hash = raster_manifest_hash,
  resolved_environment_file_sizes = current_file_sizes,
  australia_extent_values = australia_extent_values,
  projection_batch_size = projection_batch_size,
  svm_prediction_batch_size = svm_prediction_batch_size,
  shared_chunk_size = shared_chunk_size,
  projection_tolerance = projection_tolerance,
  plot_aggregation_factor = plot_aggregation_factor,
  method_colours = method_colours
)

analysis_settings_hash <- hash_r_object(
  analysis_settings
)

if (
  file.exists(
    analysis_settings_file
  )
) {
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
      "Existing Script-22 outputs were created from different locked inputs, ",
      "model files, rasters or projection settings. Archive/remove ",
      "04_Geographic_Projection before rerunning the current analysis."
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
# PCA raster construction
# ============================================================

build_pca_raster <- function(
    environmental_stack,
    shared_pca,
    output_file
) {
  if (
    resume_from_existing_rasters &&
      file.exists(
        output_file
      )
  ) {
    message(
      "Reusing compatible saved Australian PC1-PC3 raster."
    )

    pc_raster <- terra::rast(
      output_file
    )

    if (
      terra::nlyr(
        pc_raster
      ) !=
        3L
    ) {
      stop(
        "Saved PCA raster does not contain three layers."
      )
    }

    names(
      pc_raster
    ) <- expected_pc_names

    return(
      pc_raster
    )
  }

  pca_center <- as.numeric(
    shared_pca$center
  )

  pca_scale <- as.numeric(
    shared_pca$scale
  )

  pca_rotation <- as.matrix(
    shared_pca$rotation[
      ,
      1:3,
      drop = FALSE
    ]
  )

  projection_function <- function(v) {
    if (is.null(dim(v))) {
      v <- matrix(
        v,
        nrow = 1L
      )
    }

    output <- matrix(
      NA_real_,
      nrow = nrow(
        v
      ),
      ncol = 3L
    )

    complete_rows <- stats::complete.cases(
      v
    )

    if (any(complete_rows)) {
      x <- v[
        complete_rows,
        ,
        drop = FALSE
      ]

      x <- sweep(
        x,
        2L,
        pca_center,
        FUN = "-"
      )

      x <- sweep(
        x,
        2L,
        pca_scale,
        FUN = "/"
      )

      output[
        complete_rows,
      ] <- x %*%
        pca_rotation
    }

    output
  }

  message(
    "Projecting the 20 Australian environmental rasters through the ",
    "locked occurrence-only PCA..."
  )

  pc_raster <- terra::app(
    environmental_stack,
    fun = projection_function,
    filename = output_file,
    overwrite = TRUE,
    wopt = list(
      names = expected_pc_names,
      datatype = "FLT4S"
    )
  )

  names(
    pc_raster
  ) <- expected_pc_names

  pc_raster
}


pc_raster <- build_pca_raster(
  environmental_stack = environmental_stack,
  shared_pca = shared_pca,
  output_file = pc_raster_file
)

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
    "No complete Australian environmental cells remain after PCA projection."
  )
}

message(
  "Complete Australian environmental cells available for projection: ",
  format(
    length(
      valid_cell_index
    ),
    big.mark = ","
  )
)


# ============================================================
# Complete-environment mask and cell area
# ============================================================

make_binary_raster <- function(
    template,
    values_vector,
    output_file
) {
  result <- template[[1L]]

  names(
    result
  ) <- "included"

  terra::values(
    result
  ) <- values_vector

  terra::writeRaster(
    result,
    output_file,
    overwrite = TRUE,
    datatype = "INT1U",
    NAflag = 255
  )

  terra::rast(
    output_file
  )
}


land_mask_values <- rep(
  NA_integer_,
  nrow(
    pc_values
  )
)

land_mask_values[
  valid_cell_index
] <- 1L

if (
  !file.exists(
    land_mask_file
  ) ||
    !resume_from_existing_rasters
) {
  make_binary_raster(
    template = pc_raster,
    values_vector = land_mask_values,
    output_file = land_mask_file
  )
}

land_mask_raster <- terra::rast(
  land_mask_file
)

if (
  resume_from_existing_rasters &&
    file.exists(
      cell_area_file
    )
) {
  message(
    "Reusing compatible saved native-resolution cell-area raster."
  )

  cell_area_raster <- terra::rast(
    cell_area_file
  )
} else {
  message(
    "Calculating native-resolution cell areas in km^2..."
  )

  cell_area_raster <- terra::cellSize(
    pc_raster[[1L]],
    mask = FALSE,
    unit = "km",
    transform = TRUE,
    filename = cell_area_file,
    overwrite = TRUE
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

total_domain_area_km2 <- sum(
  cell_area_values[
    valid_cell_index
  ],
  na.rm = TRUE
)

message(
  "Complete environmental projection-domain area: ",
  format(
    round(
      total_domain_area_km2
    ),
    big.mark = ","
  ),
  " km^2"
)


# ============================================================
# QPH projection helper
# ============================================================

project_qph_to_landscape <- function(
    evaluation_points,
    occurrence_points,
    bandwidth,
    potential_threshold_raw,
    sd_count,
    batch_size = projection_batch_size
) {
  evaluation_points <- validate_numeric_matrix(
    evaluation_points,
    "QPH evaluation points",
    expected_columns = 3L
  )

  occurrence_points <- validate_numeric_matrix(
    occurrence_points,
    "QPH occurrence points",
    expected_columns = 3L
  )

  bandwidth <- as.numeric(
    bandwidth
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
      potential_threshold_raw
    ) ||
      !is.finite(
        sd_count
      ) ||
      sd_count <=
        0
  ) {
    stop(
      "Invalid QPH threshold/candidate-region settings."
    )
  }

  occurrence_scaled <- sweep(
    occurrence_points,
    2L,
    bandwidth,
    FUN = "/"
  )

  occurrence_squared_norm <- rowSums(
    occurrence_scaled^2
  )

  prediction <- logical(
    nrow(
      evaluation_points
    )
  )

  potential <- rep(
    NA_real_,
    nrow(
      evaluation_points
    )
  )

  inside_candidate_region <- logical(
    nrow(
      evaluation_points
    )
  )

  for (
    start_index in seq.int(
      1L,
      nrow(
        evaluation_points
      ),
      by = batch_size
    )
  ) {
    end_index <- min(
      start_index +
        batch_size -
        1L,
      nrow(
        evaluation_points
      )
    )

    idx <- start_index:end_index

    evaluation_batch <- sweep(
      evaluation_points[
        idx,
        ,
        drop = FALSE
      ],
      2L,
      bandwidth,
      FUN = "/"
    )

    distance_squared <- outer(
      rowSums(
        evaluation_batch^2
      ),
      occurrence_squared_norm,
      FUN = "+"
    ) -
      2 *
        tcrossprod(
          evaluation_batch,
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

    batch_candidate <- (
      row_minimum <=
        sd_count^2
    )

    inside_candidate_region[
      idx
    ] <- batch_candidate

    if (any(batch_candidate)) {
      candidate_distance_squared <- distance_squared[
        batch_candidate,
        ,
        drop = FALSE
      ]

      candidate_row_minimum <- row_minimum[
        batch_candidate
      ]

      # Shifted weights avoid numerical underflow without changing the
      # weighted ratio in the QPH potential equation.
      shifted_weights <- exp(
        -0.5 *
          sweep(
            candidate_distance_squared,
            1L,
            candidate_row_minimum,
            FUN = "-"
          )
      )

      shifted_sum <- rowSums(
        shifted_weights
      )

      candidate_potential <- (
        -ncol(
          occurrence_points
        ) /
          2 +
          0.5 *
            rowSums(
              shifted_weights *
                candidate_distance_squared
            ) /
            shifted_sum
      )

      candidate_global_indices <- idx[
        batch_candidate
      ]

      potential[
        candidate_global_indices
      ] <- candidate_potential

      prediction[
        candidate_global_indices
      ] <- (
        candidate_potential <=
          potential_threshold_raw +
            projection_tolerance
      )
    }
  }

  list(
    prediction = prediction,
    potential = potential,
    inside_candidate_region = inside_candidate_region
  )
}


# ============================================================
# Gaussian KDE projection helpers
# ============================================================

calculate_raw_gaussian_sum <- function(
    evaluation_points,
    occurrence_points,
    bandwidth,
    sd_count,
    batch_size = projection_batch_size
) {
  evaluation_points <- validate_numeric_matrix(
    evaluation_points,
    "KDE evaluation points",
    expected_columns = 3L
  )

  occurrence_points <- validate_numeric_matrix(
    occurrence_points,
    "KDE occurrence points",
    expected_columns = 3L
  )

  bandwidth <- as.numeric(
    bandwidth
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
      "Invalid KDE projection bandwidth."
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
      "Invalid KDE candidate-region sd.count."
    )
  }

  occurrence_scaled <- sweep(
    occurrence_points,
    2L,
    bandwidth,
    FUN = "/"
  )

  occurrence_squared_norm <- rowSums(
    occurrence_scaled^2
  )

  output <- numeric(
    nrow(
      evaluation_points
    )
  )

  inside_candidate_region <- logical(
    nrow(
      evaluation_points
    )
  )

  for (
    start_index in seq.int(
      1L,
      nrow(
        evaluation_points
      ),
      by = batch_size
    )
  ) {
    end_index <- min(
      start_index +
        batch_size -
        1L,
      nrow(
        evaluation_points
      )
    )

    idx <- start_index:end_index

    evaluation_batch <- sweep(
      evaluation_points[
        idx,
        ,
        drop = FALSE
      ],
      2L,
      bandwidth,
      FUN = "/"
    )

    distance_squared <- outer(
      rowSums(
        evaluation_batch^2
      ),
      occurrence_squared_norm,
      FUN = "+"
    ) -
      2 *
        tcrossprod(
          evaluation_batch,
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
        "Unexpected negative squared distances during KDE projection."
      )
    }

    row_minimum <- apply(
      distance_squared,
      1L,
      min
    )

    inside_candidate_region[
      idx
    ] <- (
      row_minimum <=
        sd_count^2
    )

    shifted_weights <- exp(
      -0.5 *
        sweep(
          distance_squared,
          1L,
          row_minimum,
          FUN = "-"
        )
    )

    output[
      idx
    ] <- (
      exp(
        -0.5 *
          row_minimum
      ) *
        rowSums(
          shifted_weights
        )
    )
  }

  list(
    raw_gaussian_sum = output,
    inside_candidate_region = inside_candidate_region
  )
}


calibrate_kde_raw_threshold <- function(
    hv,
    occurrence_points,
    bandwidth,
    sd_count,
    n_calibration_points = 8L
) {
  occurrence_points <- validate_numeric_matrix(
    occurrence_points,
    "KDE calibration occurrence points",
    expected_columns = 3L
  )

  bandwidth <- as.numeric(
    bandwidth
  )

  if (
    nrow(
      hv@RandomPoints
    ) <
      1L
  ) {
    stop(
      "KDE hypervolume contains no retained random points."
    )
  }

  calculate_density_internal <- getFromNamespace(
    "calculate_density",
    "hypervolume"
  )

  order_index <- order(
    hv@ValueAtRandomPoints
  )

  chosen <- unique(
    round(
      seq(
        1,
        length(
          order_index
        ),
        length.out = min(
          n_calibration_points,
          length(
            order_index
          )
        )
      )
    )
  )

  chosen_rows <- order_index[
    chosen
  ]

  calibration_points <- validate_numeric_matrix(
    hv@RandomPoints[
      chosen_rows,
      ,
      drop = FALSE
    ],
    "KDE calibration points",
    expected_columns = 3L
  )

  raw_scores <- calculate_raw_gaussian_sum(
    evaluation_points = calibration_points,
    occurrence_points = occurrence_points,
    bandwidth = bandwidth,
    sd_count = sd_count,
    batch_size = max(
      1L,
      nrow(
        calibration_points
      )
    )
  )$raw_gaussian_sum

  n_occurrence <- nrow(
    occurrence_points
  )

  equal_weights <- rep(
    1 /
      n_occurrence,
    n_occurrence
  )

  exact_density <- vapply(
    seq_len(
      nrow(
        calibration_points
      )
    ),
    function(i) {
      calculate_density_internal(
        s = calibration_points[
          i,
        ],
        means = occurrence_points,
        kernel_sd = bandwidth,
        weight = equal_weights,
        chunksize = shared_chunk_size,
        verbose = FALSE
      )
    },
    numeric(1)
  )

  scale_factors <- (
    exact_density /
      raw_scores
  )

  scale_factors <- scale_factors[
    is.finite(
      scale_factors
    ) &
      scale_factors >
        0
  ]

  if (
    length(
      scale_factors
    ) ==
      0L
  ) {
    stop(
      "Could not calibrate the Gaussian KDE projection threshold."
    )
  }

  scale_factor <- stats::median(
    scale_factors
  )

  relative_spread <- max(
    abs(
      scale_factors /
        scale_factor -
        1
    )
  )

  if (
    is.finite(
      relative_spread
    ) &&
      relative_spread >
        1e-6
  ) {
    warning(
      "KDE raw-score calibration was not perfectly proportional; ",
      "maximum relative spread = ",
      signif(
        relative_spread,
        4
      ),
      "."
    )
  }

  retained_density_threshold <- min(
    hv@ValueAtRandomPoints,
    na.rm = TRUE
  )

  if (
    !is.finite(
      retained_density_threshold
    )
  ) {
    stop(
      "Could not recover a finite retained KDE density threshold."
    )
  }

  raw_threshold <- (
    retained_density_threshold /
      scale_factor
  )

  list(
    raw_threshold = raw_threshold,
    density_threshold = retained_density_threshold,
    density_per_raw_score = scale_factor,
    calibration_relative_spread = relative_spread
  )
}


project_kde_to_landscape <- function(
    evaluation_points,
    occurrence_points,
    hv,
    bandwidth,
    sd_count
) {
  calibration <- calibrate_kde_raw_threshold(
    hv = hv,
    occurrence_points = occurrence_points,
    bandwidth = bandwidth,
    sd_count = sd_count
  )

  scores <- calculate_raw_gaussian_sum(
    evaluation_points = evaluation_points,
    occurrence_points = occurrence_points,
    bandwidth = bandwidth,
    sd_count = sd_count,
    batch_size = projection_batch_size
  )

  prediction <- (
    scores$inside_candidate_region &
      scores$raw_gaussian_sum >
        calibration$raw_threshold
  )

  list(
    prediction = prediction,
    raw_gaussian_sum = scores$raw_gaussian_sum,
    inside_candidate_region = scores$inside_candidate_region,
    calibration = calibration
  )
}


# ============================================================
# SVM projection helper
# ============================================================

project_svm_to_landscape <- function(
    evaluation_points,
    svm_model
) {
  evaluation_points <- validate_numeric_matrix(
    evaluation_points,
    "SVM evaluation points",
    expected_columns = 3L
  )

  valid_points <- as.data.frame(
    evaluation_points
  )

  names(
    valid_points
  ) <- expected_pc_names

  prediction <- logical(
    nrow(
      valid_points
    )
  )

  number_batches <- ceiling(
    nrow(
      valid_points
    ) /
      svm_prediction_batch_size
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
        svm_prediction_batch_size +
        1L
    )

    batch_end <- min(
      batch_index *
        svm_prediction_batch_size,
      nrow(
        valid_points
      )
    )

    batch_rows <- batch_start:batch_end

    predicted_class <- stats::predict(
      svm_model,
      newdata = valid_points[
        batch_rows,
        ,
        drop = FALSE
      ]
    )

    prediction[
      batch_rows
    ] <- prediction_to_inside(
      predicted_class
    )

    if (
      show_progress_messages &&
        (
          batch_index %%
            10L ==
            0L ||
            batch_index ==
              number_batches
        )
    ) {
      message(
        "  SVM batch ",
        batch_index,
        "/",
        number_batches
      )
    }
  }

  prediction
}


# ============================================================
# Projection raster validity helper
# ============================================================

validate_existing_projection_raster <- function(
    raster_file,
    template_raster
) {
  if (!file.exists(raster_file)) {
    return(FALSE)
  }

  raster_object <- terra::rast(
    raster_file
  )

  if (
    terra::nlyr(
      raster_object
    ) !=
      1L
  ) {
    return(FALSE)
  }

  isTRUE(
    terra::compareGeom(
      raster_object,
      template_raster[[1L]],
      stopOnError = FALSE
    )
  )
}


# ============================================================
# Project all species and methods
# ============================================================

projection_values <- stats::setNames(
  vector(
    "list",
    length(
      expected_species
    )
  ),
  expected_species
)

projection_rasters <- stats::setNames(
  vector(
    "list",
    length(
      expected_species
    )
  ),
  expected_species
)

projection_runtime_rows <- list()
projection_runtime_index <- 0L

projection_parameter_rows <- list()
projection_parameter_index <- 0L

valid_pc_points <- pc_values[
  valid_cell_index,
  ,
  drop = FALSE
]

for (
  species_name in expected_species
) {
  message(
    "\n============================================================"
  )
  message(
    "Projecting species: ",
    species_name
  )
  message(
    "============================================================"
  )

  projection_values[[species_name]] <- list()
  projection_rasters[[species_name]] <- list()

  # ----------------------------------------------------------
  # QPH
  # ----------------------------------------------------------

  qph_bundle <- model_bundles[[species_name]][[
    "QPH"
  ]]

  qph_model <- qph_bundle$projection_model
  qph_file <- projection_raster_path(
    species_name,
    "QPH"
  )

  qph_reused <- (
    resume_from_existing_rasters &&
      validate_existing_projection_raster(
        qph_file,
        pc_raster
      )
  )

  qph_candidate_count <- NA_integer_

  if (qph_reused) {
    message(
      "Reusing existing compatible QPH geographic raster."
    )

    qph_raster <- terra::rast(
      qph_file
    )

    qph_values <- as.integer(
      as.numeric(
        terra::values(
          qph_raster
        )
      )
    )

    qph_runtime <- 0
  } else {
    qph_start <- proc.time()[[
      "elapsed"
    ]]

    qph_projection <- project_qph_to_landscape(
      evaluation_points = valid_pc_points,
      occurrence_points = qph_model$occurrence_points,
      bandwidth = qph_model$bandwidth,
      potential_threshold_raw = qph_model$potential_threshold_raw,
      sd_count = qph_model$candidate_sd_count,
      batch_size = projection_batch_size
    )

    qph_runtime <- (
      proc.time()[[
        "elapsed"
      ]] -
        qph_start
    )

    qph_candidate_count <- sum(
      qph_projection$inside_candidate_region
    )

    qph_values <- rep(
      NA_integer_,
      nrow(
        pc_values
      )
    )

    qph_values[
      valid_cell_index
    ] <- as.integer(
      qph_projection$prediction
    )

    qph_raster <- make_binary_raster(
      template = pc_raster,
      values_vector = qph_values,
      output_file = qph_file
    )
  }

  projection_values[[species_name]][[
    "QPH"
  ]] <- qph_values

  projection_rasters[[species_name]][[
    "QPH"
  ]] <- qph_raster

  projection_runtime_index <- projection_runtime_index + 1L

  projection_runtime_rows[[
    projection_runtime_index
  ]] <- data.frame(
    Species = species_name,
    Method = "QPH",
    Runtime_seconds = qph_runtime,
    Reused_existing_raster = qph_reused,
    Candidate_cell_count = qph_candidate_count,
    Note = "Revised sqrt-NB QPH evaluated with its own bandwidth/candidate region.",
    stringsAsFactors = FALSE
  )

  # ----------------------------------------------------------
  # Gaussian KDE
  # ----------------------------------------------------------

  kde_bundle <- model_bundles[[species_name]][[
    "Gaussian KDE"
  ]]

  kde_model <- kde_bundle$projection_model
  kde_file <- projection_raster_path(
    species_name,
    "Gaussian KDE"
  )

  kde_reused <- (
    resume_from_existing_rasters &&
      validate_existing_projection_raster(
        kde_file,
        pc_raster
      )
  )

  kde_candidate_count <- NA_integer_
  kde_calibration <- NULL

  if (kde_reused) {
    message(
      "Reusing existing compatible Gaussian KDE geographic raster."
    )

    kde_raster <- terra::rast(
      kde_file
    )

    kde_values <- as.integer(
      as.numeric(
        terra::values(
          kde_raster
        )
      )
    )

    kde_runtime <- 0

    # Recalculate calibration metadata only; this is cheap and avoids leaving
    # projection-parameter fields missing when rasters are resumed.
    kde_calibration <- calibrate_kde_raw_threshold(
      hv = kde_bundle$hypervolume,
      occurrence_points = kde_model$occurrence_points,
      bandwidth = kde_model$bandwidth,
      sd_count = kde_model$candidate_sd_count
    )
  } else {
    kde_start <- proc.time()[[
      "elapsed"
    ]]

    kde_projection <- project_kde_to_landscape(
      evaluation_points = valid_pc_points,
      occurrence_points = kde_model$occurrence_points,
      hv = kde_bundle$hypervolume,
      bandwidth = kde_model$bandwidth,
      sd_count = kde_model$candidate_sd_count
    )

    kde_runtime <- (
      proc.time()[[
        "elapsed"
      ]] -
        kde_start
    )

    kde_candidate_count <- sum(
      kde_projection$inside_candidate_region
    )

    kde_calibration <- kde_projection$calibration

    kde_values <- rep(
      NA_integer_,
      nrow(
        pc_values
      )
    )

    kde_values[
      valid_cell_index
    ] <- as.integer(
      kde_projection$prediction
    )

    kde_raster <- make_binary_raster(
      template = pc_raster,
      values_vector = kde_values,
      output_file = kde_file
    )
  }

  projection_values[[species_name]][[
    "Gaussian KDE"
  ]] <- kde_values

  projection_rasters[[species_name]][[
    "Gaussian KDE"
  ]] <- kde_raster

  projection_runtime_index <- projection_runtime_index + 1L

  projection_runtime_rows[[
    projection_runtime_index
  ]] <- data.frame(
    Species = species_name,
    Method = "Gaussian KDE",
    Runtime_seconds = kde_runtime,
    Reused_existing_raster = kde_reused,
    Candidate_cell_count = kde_candidate_count,
    Note = "Gaussian KDE evaluated independently with its own Silverman bandwidth/candidate region.",
    stringsAsFactors = FALSE
  )

  # ----------------------------------------------------------
  # SVM
  # ----------------------------------------------------------

  svm_bundle <- model_bundles[[species_name]][[
    "SVM"
  ]]

  svm_model <- svm_bundle$projection_model$e1071_model

  if (is.null(svm_model)) {
    stop(
      "Saved SVM projection classifier missing for ",
      species_name,
      "."
    )
  }

  svm_file <- projection_raster_path(
    species_name,
    "SVM"
  )

  svm_reused <- (
    resume_from_existing_rasters &&
      validate_existing_projection_raster(
        svm_file,
        pc_raster
      )
  )

  if (svm_reused) {
    message(
      "Reusing existing compatible SVM geographic raster."
    )

    svm_raster <- terra::rast(
      svm_file
    )

    svm_values <- as.integer(
      as.numeric(
        terra::values(
          svm_raster
        )
      )
    )

    svm_runtime <- 0
  } else {
    svm_start <- proc.time()[[
      "elapsed"
    ]]

    svm_prediction <- project_svm_to_landscape(
      evaluation_points = valid_pc_points,
      svm_model = svm_model
    )

    svm_runtime <- (
      proc.time()[[
        "elapsed"
      ]] -
        svm_start
    )

    svm_values <- rep(
      NA_integer_,
      nrow(
        pc_values
      )
    )

    svm_values[
      valid_cell_index
    ] <- as.integer(
      svm_prediction
    )

    svm_raster <- make_binary_raster(
      template = pc_raster,
      values_vector = svm_values,
      output_file = svm_file
    )
  }

  projection_values[[species_name]][[
    "SVM"
  ]] <- svm_values

  projection_rasters[[species_name]][[
    "SVM"
  ]] <- svm_raster

  projection_runtime_index <- projection_runtime_index + 1L

  projection_runtime_rows[[
    projection_runtime_index
  ]] <- data.frame(
    Species = species_name,
    Method = "SVM",
    Runtime_seconds = svm_runtime,
    Reused_existing_raster = svm_reused,
    Candidate_cell_count = NA_integer_,
    Note = "Saved one-class radial e1071 classifier; internal scaling=TRUE.",
    stringsAsFactors = FALSE
  )

  # ----------------------------------------------------------
  # Projection parameter audit
  # ----------------------------------------------------------

  qph_bw <- as.numeric(
    qph_model$bandwidth
  )

  kde_bw <- as.numeric(
    kde_model$bandwidth
  )

  projection_parameter_index <- projection_parameter_index + 1L

  projection_parameter_rows[[
    projection_parameter_index
  ]] <- data.frame(
    Species = species_name,
    QPH_bandwidth_method = qph_model$bandwidth_method,
    QPH_bandwidth_PC1 = qph_bw[[1L]],
    QPH_bandwidth_PC2 = qph_bw[[2L]],
    QPH_bandwidth_PC3 = qph_bw[[3L]],
    QPH_potential_quantile = qph_model$potential_quantile,
    QPH_potential_threshold_raw = qph_model$potential_threshold_raw,
    QPH_candidate_sd_count = qph_model$candidate_sd_count,
    KDE_bandwidth_method = kde_model$bandwidth_method,
    KDE_bandwidth_PC1 = kde_bw[[1L]],
    KDE_bandwidth_PC2 = kde_bw[[2L]],
    KDE_bandwidth_PC3 = kde_bw[[3L]],
    KDE_probability_quantile = kde_model$quantile_requested,
    KDE_candidate_sd_count = kde_model$candidate_sd_count,
    KDE_retained_density_threshold = kde_calibration$density_threshold,
    KDE_raw_score_threshold = kde_calibration$raw_threshold,
    KDE_density_per_raw_score = kde_calibration$density_per_raw_score,
    KDE_calibration_relative_spread = (
      kde_calibration$calibration_relative_spread
    ),
    QPH_KDE_bandwidth_vectors_identical = isTRUE(
      all.equal(
        qph_bw,
        kde_bw,
        tolerance = 1e-12
      )
    ),
    SVM_nu = svm_bundle$projection_model$svm_nu,
    SVM_gamma = svm_bundle$projection_model$svm_gamma,
    SVM_scale_factor = svm_bundle$projection_model$svm_scale_factor,
    SVM_internal_scaling = svm_bundle$projection_model$internal_scaling,
    stringsAsFactors = FALSE
  )

  gc()
}

projection_runtime <- do.call(
  rbind,
  projection_runtime_rows
)

projection_parameters <- do.call(
  rbind,
  projection_parameter_rows
)

write_csv_safely(
  projection_runtime,
  projection_runtime_file
)

write_csv_safely(
  projection_parameters,
  projection_parameters_file
)


# ============================================================
# Geographic metric helpers
# ============================================================

weighted_binary_overlap <- function(
    inclusion_1,
    inclusion_2,
    cell_area
) {
  valid <- (
    is.finite(
      inclusion_1
    ) &
      is.finite(
        inclusion_2
      ) &
      is.finite(
        cell_area
      ) &
      cell_area >
        0
  )

  x1 <- inclusion_1[
    valid
  ] ==
    1L

  x2 <- inclusion_2[
    valid
  ] ==
    1L

  area <- cell_area[
    valid
  ]

  area_1 <- sum(
    area[
      x1
    ]
  )

  area_2 <- sum(
    area[
      x2
    ]
  )

  intersection_area <- sum(
    area[
      x1 &
        x2
    ]
  )

  union_area <- sum(
    area[
      x1 |
        x2
    ]
  )

  jaccard <- if (
    union_area >
      0
  ) {
    intersection_area /
      union_area
  } else {
    NA_real_
  }

  sorensen <- if (
    (
      area_1 +
        area_2
    ) >
      0
  ) {
    2 *
      intersection_area /
      (
        area_1 +
          area_2
      )
  } else {
    NA_real_
  }

  fraction_1 <- if (
    area_1 >
      0
  ) {
    intersection_area /
      area_1
  } else {
    NA_real_
  }

  fraction_2 <- if (
    area_2 >
      0
  ) {
    intersection_area /
      area_2
  } else {
    NA_real_
  }

  list(
    area_1 = area_1,
    area_2 = area_2,
    intersection_area = intersection_area,
    union_area = union_area,
    jaccard = jaccard,
    sorensen = sorensen,
    fraction_1 = fraction_1,
    fraction_2 = fraction_2,
    unique_area_1 = area_1 -
      intersection_area,
    unique_area_2 = area_2 -
      intersection_area
  )
}


# ============================================================
# Projected area and occurrence-cell inclusion
# ============================================================

projection_summary_rows <- list()
projection_summary_index <- 0L

occurrence_coverage_rows <- list()
occurrence_coverage_index <- 0L

for (
  species_name in expected_species
) {
  species_occurrences <- occurrence_metadata[
    occurrence_metadata$species ==
      species_name,
    ,
    drop = FALSE
  ]

  if (
    nrow(
      species_occurrences
    ) <
      1L
  ) {
    stop(
      "No locked occurrence records found for ",
      species_name,
      "."
    )
  }

  occurrence_xy <- as.matrix(
    species_occurrences[
      ,
      c(
        "longitude",
        "latitude"
      )
    ]
  )

  occurrence_cells <- terra::cellFromXY(
    pc_raster[[1L]],
    occurrence_xy
  )

  for (
    method_name in method_order
  ) {
    current_values <- projection_values[[species_name]][[
      method_name
    ]]

    valid <- (
      is.finite(
        current_values
      ) &
        is.finite(
          cell_area_values
        )
    )

    included <- (
      valid &
        current_values ==
          1L
    )

    projected_area_km2 <- sum(
      cell_area_values[
        included
      ],
      na.rm = TRUE
    )

    projected_cell_count <- sum(
      included,
      na.rm = TRUE
    )

    projection_summary_index <- projection_summary_index + 1L

    projection_summary_rows[[
      projection_summary_index
    ]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Method = method_name,
      Projected_area_km2 = projected_area_km2,
      Projected_area_million_km2 = projected_area_km2 /
        1e6,
      Projection_domain_area_km2 = total_domain_area_km2,
      Percent_projection_domain = 100 *
        projected_area_km2 /
        total_domain_area_km2,
      Included_cell_count = projected_cell_count,
      Complete_environment_cell_count = length(
        valid_cell_index
      ),
      stringsAsFactors = FALSE
    )

    valid_occurrence_cell <- (
      is.finite(
        occurrence_cells
      ) &
        occurrence_cells >=
          1L &
        occurrence_cells <=
          length(
            current_values
          )
    )

    occurrence_inclusion <- rep(
      NA,
      length(
        occurrence_cells
      )
    )

    occurrence_inclusion[
      valid_occurrence_cell
    ] <- (
      current_values[
        occurrence_cells[
          valid_occurrence_cell
        ]
      ] ==
        1L
    )

    occurrence_coverage_index <- occurrence_coverage_index + 1L

    occurrence_coverage_rows[[
      occurrence_coverage_index
    ]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Method = method_name,
      Occurrence_records = nrow(
        species_occurrences
      ),
      Occurrence_records_with_projection_cell = sum(
        valid_occurrence_cell
      ),
      Occurrence_records_included = sum(
        occurrence_inclusion %in%
          TRUE,
        na.rm = TRUE
      ),
      Occurrence_inclusion_proportion = if (
        any(
          valid_occurrence_cell
        )
      ) {
        mean(
          occurrence_inclusion,
          na.rm = TRUE
        )
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }
}

projection_summary <- do.call(
  rbind,
  projection_summary_rows
)

occurrence_coverage <- do.call(
  rbind,
  occurrence_coverage_rows
)

projection_summary$Species <- factor(
  projection_summary$Species,
  levels = expected_species
)

projection_summary$Method <- factor(
  projection_summary$Method,
  levels = method_order
)

projection_summary <- projection_summary[
  order(
    projection_summary$Species,
    projection_summary$Method
  ),
  ,
  drop = FALSE
]

projection_summary$Species <- as.character(
  projection_summary$Species
)

projection_summary$Method <- as.character(
  projection_summary$Method
)

write_csv_safely(
  projection_summary,
  projection_summary_file
)

write_csv_safely(
  occurrence_coverage,
  occurrence_coverage_file
)


# ============================================================
# Within-species area ratios and cross-method geographic overlap
# ============================================================

method_pairs <- list(
  c(
    "QPH",
    "Gaussian KDE"
  ),
  c(
    "QPH",
    "SVM"
  ),
  c(
    "Gaussian KDE",
    "SVM"
  )
)

within_species_overlap_rows <- list()
within_species_overlap_index <- 0L

within_species_ratio_rows <- list()
within_species_ratio_index <- 0L

for (
  species_name in expected_species
) {
  species_area_rows <- projection_summary[
    projection_summary$Species ==
      species_name,
    ,
    drop = FALSE
  ]

  for (
    method_pair in method_pairs
  ) {
    method_1 <- method_pair[[1L]]
    method_2 <- method_pair[[2L]]

    values_1 <- projection_values[[species_name]][[
      method_1
    ]]

    values_2 <- projection_values[[species_name]][[
      method_2
    ]]

    overlap_result <- weighted_binary_overlap(
      values_1,
      values_2,
      cell_area_values
    )

    within_species_overlap_index <- (
      within_species_overlap_index +
        1L
    )

    within_species_overlap_rows[[
      within_species_overlap_index
    ]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Method_1 = method_1,
      Method_2 = method_2,
      Method_pair = paste(
        method_1,
        method_2,
        sep = " vs "
      ),
      Area_method_1_km2 = overlap_result$area_1,
      Area_method_2_km2 = overlap_result$area_2,
      Intersection_area_km2 = overlap_result$intersection_area,
      Union_area_km2 = overlap_result$union_area,
      Jaccard_similarity = overlap_result$jaccard,
      Sorensen_similarity = overlap_result$sorensen,
      Fraction_method_1_overlapped = overlap_result$fraction_1,
      Fraction_method_2_overlapped = overlap_result$fraction_2,
      Unique_method_1_area_km2 = overlap_result$unique_area_1,
      Unique_method_2_area_km2 = overlap_result$unique_area_2,
      stringsAsFactors = FALSE
    )

    area_1 <- species_area_rows$Projected_area_km2[
      species_area_rows$Method ==
        method_1
    ]

    area_2 <- species_area_rows$Projected_area_km2[
      species_area_rows$Method ==
        method_2
    ]

    within_species_ratio_index <- (
      within_species_ratio_index +
        1L
    )

    within_species_ratio_rows[[
      within_species_ratio_index
    ]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Method_1 = method_1,
      Method_2 = method_2,
      Method_pair = paste(
        method_1,
        method_2,
        sep = " / "
      ),
      Area_method_1_km2 = area_1,
      Area_method_2_km2 = area_2,
      Area_ratio_method_1_to_method_2 = if (
        length(
          area_2
        ) ==
          1L &&
          area_2 >
            0
      ) {
        area_1 /
          area_2
      } else {
        NA_real_
      },
      Percent_change_method_1_relative_to_method_2 = if (
        length(
          area_2
        ) ==
          1L &&
          area_2 >
            0
      ) {
        100 *
          (
            area_1 -
              area_2
          ) /
          area_2
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }
}

within_species_overlap <- do.call(
  rbind,
  within_species_overlap_rows
)

within_species_area_ratios <- do.call(
  rbind,
  within_species_ratio_rows
)

write_csv_safely(
  within_species_overlap,
  within_species_overlap_file
)

write_csv_safely(
  within_species_area_ratios,
  within_species_area_ratio_file
)


# ============================================================
# Between-species geographic overlap within each estimator
# ============================================================

species_pairs <- utils::combn(
  expected_species,
  2,
  simplify = FALSE
)

between_species_rows <- list()
between_species_index <- 0L

for (
  method_name in method_order
) {
  for (
    species_pair in species_pairs
  ) {
    species_1 <- species_pair[[1L]]
    species_2 <- species_pair[[2L]]

    overlap_result <- weighted_binary_overlap(
      projection_values[[species_1]][[
        method_name
      ]],
      projection_values[[species_2]][[
        method_name
      ]],
      cell_area_values
    )

    between_species_index <- between_species_index + 1L

    between_species_rows[[
      between_species_index
    ]] <- data.frame(
      Method = method_name,
      Species_1 = species_1,
      Species_2 = species_2,
      Species_pair = paste(
        species_1,
        species_2,
        sep = " vs "
      ),
      Area_species_1_km2 = overlap_result$area_1,
      Area_species_2_km2 = overlap_result$area_2,
      Intersection_area_km2 = overlap_result$intersection_area,
      Union_area_km2 = overlap_result$union_area,
      Jaccard_similarity = overlap_result$jaccard,
      Sorensen_similarity = overlap_result$sorensen,
      Fraction_species_1_overlapped = overlap_result$fraction_1,
      Fraction_species_2_overlapped = overlap_result$fraction_2,
      stringsAsFactors = FALSE
    )
  }
}

between_species_overlap <- do.call(
  rbind,
  between_species_rows
)

write_csv_safely(
  between_species_overlap,
  between_species_overlap_file
)


# ============================================================
# Environmental hypervolume volume vs geographic projected area
# ============================================================

environmental_geographic_comparison <- NULL

if (
  file.exists(
    geometry_results_file
  )
) {
  geometry_results <- readRDS(
    geometry_results_file
  )

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
      "Script-20 geometry object does not match the current locked design/models."
    )
  }

  geometry_summary <- geometry_results$volume_centroid_summary

  required_geometry_columns <- c(
    "Species",
    "Method",
    "Hypervolume_volume"
  )

  if (
    !all(
      required_geometry_columns %in%
        names(
          geometry_summary
        )
    )
  ) {
    stop(
      "Script-20 geometry summary lacks required environmental-volume columns."
    )
  }

  environmental_geographic_comparison <- merge(
    geometry_summary[
      ,
      required_geometry_columns,
      drop = FALSE
    ],
    projection_summary[
      ,
      c(
        "Species",
        "Method",
        "Projected_area_km2",
        "Projected_area_million_km2",
        "Percent_projection_domain"
      ),
      drop = FALSE
    ],
    by = c(
      "Species",
      "Method"
    ),
    all = FALSE
  )

  write_csv_safely(
    environmental_geographic_comparison,
    environmental_geographic_comparison_file
  )
} else {
  warning(
    "Script-20 geometry result object was not found. Geographic projection ",
    "will continue, but environmental-volume vs geographic-area output will ",
    "be omitted."
  )
}


# ============================================================
# Projection manifest
# ============================================================

manifest_rows <- list()
manifest_index <- 0L

for (
  species_name in expected_species
) {
  for (
    method_name in method_order
  ) {
    current_file <- projection_raster_path(
      species_name,
      method_name
    )

    manifest_index <- manifest_index + 1L

    manifest_rows[[
      manifest_index
    ]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Method = method_name,
      Raster_file = normalizePath(
        current_file,
        winslash = "/",
        mustWork = FALSE
      ),
      Raster_exists = file.exists(
        current_file
      ),
      Raster_MD5 = safe_md5(
        current_file
      ),
      Analysis_settings_hash = analysis_settings_hash,
      Model_MD5 = model_file_md5[[
        model_key(
          species_name,
          method_name
        )
      ]],
      stringsAsFactors = FALSE
    )
  }
}

projection_manifest <- do.call(
  rbind,
  manifest_rows
)

write_csv_safely(
  projection_manifest,
  projection_manifest_file
)


# ============================================================
# Plot helpers
# ============================================================

prepare_plot_raster_data <- function(
    raster_object,
    aggregation_factor = plot_aggregation_factor
) {
  plot_raster <- raster_object

  if (
    aggregation_factor >
      1L
  ) {
    plot_raster <- terra::aggregate(
      plot_raster,
      fact = aggregation_factor,
      fun = "max",
      na.rm = TRUE
    )
  }

  plot_data <- terra::as.data.frame(
    plot_raster,
    xy = TRUE,
    na.rm = FALSE
  )

  names(
    plot_data
  )[[
    3L
  ]] <- "included"

  plot_data[
    is.finite(
      plot_data$included
    ) &
      plot_data$included ==
        1,
    ,
    drop = FALSE
  ]
}


save_plot_formats <- function(
    plot_object,
    pdf_file,
    png_file,
    tiff_file = NULL,
    width,
    height
) {
  ggplot2::ggsave(
    filename = pdf_file,
    plot = plot_object,
    width = width,
    height = height,
    units = "in",
    bg = "white"
  )

  ggplot2::ggsave(
    filename = png_file,
    plot = plot_object,
    width = width,
    height = height,
    units = "in",
    dpi = 350,
    bg = "white"
  )

  if (!is.null(tiff_file)) {
    ggplot2::ggsave(
      filename = tiff_file,
      plot = plot_object,
      width = width,
      height = height,
      units = "in",
      dpi = figure_tiff_dpi,
      compression = "lzw",
      bg = "white"
    )
  }

  invisible(TRUE)
}


world_map <- ggplot2::map_data(
  "world",
  region = "Australia"
)

occurrence_plot_data <- occurrence_metadata[
  occurrence_metadata$species %in%
    expected_species,
  c(
    "species",
    "longitude",
    "latitude"
  ),
  drop = FALSE
]

occurrence_plot_data$Species <- factor(
  occurrence_plot_data$species,
  levels = expected_species,
  labels = vapply(
    expected_species,
    format_species_label,
    character(1)
  )
)


# ============================================================
# Figure 1: 3 methods x 5 species potential geographic projections
# ============================================================

map_rows <- list()
map_index <- 0L

for (
  species_name in expected_species
) {
  for (
    method_name in method_order
  ) {
    current_data <- prepare_plot_raster_data(
      projection_rasters[[species_name]][[
        method_name
      ]]
    )

    if (
      nrow(
        current_data
      ) >
        0L
    ) {
      map_index <- map_index + 1L

      current_data$Species <- format_species_label(
        species_name
      )

      current_data$Method <- method_name

      map_rows[[
        map_index
      ]] <- current_data
    }
  }
}

map_plot_data <- if (
  length(
    map_rows
  ) >
    0L
) {
  do.call(
    rbind,
    map_rows
  )
} else {
  data.frame(
    x = numeric(0),
    y = numeric(0),
    included = numeric(0),
    Species = character(0),
    Method = character(0)
  )
}

map_plot_data$Species <- factor(
  map_plot_data$Species,
  levels = vapply(
    expected_species,
    format_species_label,
    character(1)
  )
)

map_plot_data$Method <- factor(
  map_plot_data$Method,
  levels = method_order
)

main_map <- ggplot2::ggplot() +
  ggplot2::geom_polygon(
    data = world_map,
    ggplot2::aes(
      x = long,
      y = lat,
      group = group
    ),
    fill = "white",
    colour = "#777777",
    linewidth = 0.2
  ) +
  ggplot2::geom_raster(
    data = map_plot_data,
    ggplot2::aes(
      x = x,
      y = y,
      fill = Method
    ),
    alpha = 0.72
  ) +
  ggplot2::geom_point(
    data = occurrence_plot_data,
    ggplot2::aes(
      x = longitude,
      y = latitude
    ),
    colour = occurrence_colour,
    size = 0.38,
    alpha = 0.70
  ) +
  ggplot2::facet_grid(
    Method ~ Species
  ) +
  ggplot2::scale_fill_manual(
    values = method_colours,
    drop = FALSE,
    name = NULL
  ) +
  ggplot2::coord_quickmap(
    xlim = c(
      australia_extent_values[[
        "xmin"
      ]],
      australia_extent_values[[
        "xmax"
      ]]
    ),
    ylim = c(
      australia_extent_values[[
        "ymin"
      ]],
      australia_extent_values[[
        "ymax"
      ]]
    ),
    expand = FALSE
  ) +
  ggplot2::labs(
    x = "Longitude",
    y = "Latitude"
  ) +
  ggplot2::theme_classic(
    base_size = 9
  ) +
  ggplot2::theme(
    strip.background = ggplot2::element_blank(),
    strip.text = ggplot2::element_text(
      face = "bold"
    ),
    legend.position = "none",
    panel.spacing = grid::unit(
      0.35,
      "lines"
    )
  )

save_plot_formats(
  plot_object = main_map,
  pdf_file = main_map_pdf,
  png_file = main_map_png,
  tiff_file = main_map_tiff,
  width = 16,
  height = 9.5
)


# ============================================================
# Figure 2: projected area, method agreement, occurrence inclusion
# ============================================================

projection_summary_plot <- projection_summary

projection_summary_plot$Species <- factor(
  projection_summary_plot$Species,
  levels = expected_species,
  labels = vapply(
    expected_species,
    format_species_label,
    character(1)
  )
)

projection_summary_plot$Method <- factor(
  projection_summary_plot$Method,
  levels = method_order
)

area_panel <- ggplot2::ggplot(
  projection_summary_plot,
  ggplot2::aes(
    x = Species,
    y = Projected_area_million_km2,
    fill = Method
  )
) +
  ggplot2::geom_col(
    position = ggplot2::position_dodge(
      width = 0.82
    ),
    width = 0.74
  ) +
  ggplot2::scale_fill_manual(
    values = method_colours,
    drop = FALSE
  ) +
  ggplot2::labs(
    x = NULL,
    y = expression(
      "Projected area (million km"^2*")"
    ),
    fill = NULL
  ) +
  ggplot2::theme_classic(
    base_size = 10
  ) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(
      angle = 35,
      hjust = 1
    ),
    legend.position = "bottom"
  )


within_overlap_plot <- within_species_overlap

within_overlap_plot$Species <- factor(
  within_overlap_plot$Species,
  levels = expected_species,
  labels = vapply(
    expected_species,
    format_species_label,
    character(1)
  )
)

within_overlap_plot$Method_pair <- factor(
  within_overlap_plot$Method_pair,
  levels = c(
    "QPH vs Gaussian KDE",
    "QPH vs SVM",
    "Gaussian KDE vs SVM"
  )
)

agreement_panel <- ggplot2::ggplot(
  within_overlap_plot,
  ggplot2::aes(
    x = Species,
    y = Jaccard_similarity,
    group = Method_pair,
    linetype = Method_pair,
    shape = Method_pair
  )
) +
  ggplot2::geom_line(
    linewidth = 0.6,
    colour = "#4A4A4A"
  ) +
  ggplot2::geom_point(
    size = 2.2,
    colour = "#4A4A4A"
  ) +
  ggplot2::scale_y_continuous(
    limits = c(
      0,
      1
    )
  ) +
  ggplot2::labs(
    x = NULL,
    y = "Area-weighted geographic Jaccard",
    linetype = NULL,
    shape = NULL
  ) +
  ggplot2::theme_classic(
    base_size = 10
  ) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(
      angle = 35,
      hjust = 1
    ),
    legend.position = "bottom"
  )


occurrence_coverage_plot <- occurrence_coverage

occurrence_coverage_plot$Species <- factor(
  occurrence_coverage_plot$Species,
  levels = expected_species,
  labels = vapply(
    expected_species,
    format_species_label,
    character(1)
  )
)

occurrence_coverage_plot$Method <- factor(
  occurrence_coverage_plot$Method,
  levels = method_order
)

coverage_panel <- ggplot2::ggplot(
  occurrence_coverage_plot,
  ggplot2::aes(
    x = Species,
    y = Occurrence_inclusion_proportion,
    colour = Method,
    group = Method
  )
) +
  ggplot2::geom_line(
    linewidth = 0.6
  ) +
  ggplot2::geom_point(
    size = 2.2
  ) +
  ggplot2::scale_colour_manual(
    values = method_colours,
    drop = FALSE
  ) +
  ggplot2::scale_y_continuous(
    limits = c(
      0,
      1
    )
  ) +
  ggplot2::labs(
    x = NULL,
    y = "Occurrence records included",
    colour = NULL
  ) +
  ggplot2::theme_classic(
    base_size = 10
  ) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(
      angle = 35,
      hjust = 1
    ),
    legend.position = "bottom"
  )


summary_figure <- (
  area_panel /
    agreement_panel /
    coverage_panel
) +
  patchwork::plot_annotation(
    tag_levels = "A"
  ) +
  patchwork::plot_layout(
    guides = "collect"
  ) &
  ggplot2::theme(
    legend.position = "bottom"
  )

ggplot2::ggsave(
  filename = summary_figure_pdf,
  plot = summary_figure,
  width = 11.5,
  height = 10.5,
  units = "in",
  bg = "white"
)

ggplot2::ggsave(
  filename = summary_figure_png,
  plot = summary_figure,
  width = 11.5,
  height = 10.5,
  units = "in",
  dpi = 350,
  bg = "white"
)


# ============================================================
# Supplementary difference maps: QPH vs comparator
# ============================================================

difference_rows <- list()
difference_index <- 0L

difference_pairs <- list(
  c(
    "QPH",
    "Gaussian KDE"
  ),
  c(
    "QPH",
    "SVM"
  )
)

for (
  species_name in expected_species
) {
  for (
    method_pair in difference_pairs
  ) {
    comparator <- method_pair[[2L]]

    qph_values <- projection_values[[species_name]][[
      "QPH"
    ]]

    comparator_values <- projection_values[[species_name]][[
      comparator
    ]]

    valid <- (
      is.finite(
        qph_values
      ) &
        is.finite(
          comparator_values
        )
    )

    category <- rep(
      NA_integer_,
      length(
        qph_values
      )
    )

    category[
      valid &
        qph_values ==
          0L &
        comparator_values ==
          0L
    ] <- 0L

    category[
      valid &
        qph_values ==
          1L &
        comparator_values ==
          0L
    ] <- 1L

    category[
      valid &
        qph_values ==
          0L &
        comparator_values ==
          1L
    ] <- 2L

    category[
      valid &
        qph_values ==
          1L &
        comparator_values ==
          1L
    ] <- 3L

    difference_raster <- pc_raster[[1L]]

    terra::values(
      difference_raster
    ) <- category

    if (
      plot_aggregation_factor >
        1L
    ) {
      # For plotting only, retain any non-zero category in the aggregated
      # block. This figure is descriptive; all metrics use native resolution.
      difference_raster <- terra::aggregate(
        difference_raster,
        fact = plot_aggregation_factor,
        fun = "modal",
        na.rm = TRUE
      )
    }

    difference_data <- terra::as.data.frame(
      difference_raster,
      xy = TRUE,
      na.rm = TRUE
    )

    names(
      difference_data
    )[[3L]] <- "category"

    difference_data <- difference_data[
      difference_data$category !=
        0,
      ,
      drop = FALSE
    ]

    if (
      nrow(
        difference_data
      ) >
        0L
    ) {
      difference_index <- difference_index + 1L

      difference_data$Species <- format_species_label(
        species_name
      )

      difference_data$Comparison <- paste(
        "QPH vs",
        comparator
      )

      difference_data$Category <- factor(
        difference_data$category,
        levels = c(
          1,
          2,
          3
        ),
        labels = c(
          "QPH only",
          paste0(
            comparator,
            " only"
          ),
          "Shared"
        )
      )

      difference_rows[[
        difference_index
      ]] <- difference_data
    }
  }
}

if (
  length(
    difference_rows
  ) >
    0L
) {
  difference_plot_data <- do.call(
    rbind,
    difference_rows
  )

  difference_plot_data$Species <- factor(
    difference_plot_data$Species,
    levels = vapply(
      expected_species,
      format_species_label,
      character(1)
    )
  )

  qph_kde_data <- difference_plot_data[
    difference_plot_data$Comparison ==
      "QPH vs Gaussian KDE",
    ,
    drop = FALSE
  ]

  qph_svm_data <- difference_plot_data[
    difference_plot_data$Comparison ==
      "QPH vs SVM",
    ,
    drop = FALSE
  ]

  make_difference_panel <- function(
      plot_data,
      comparator,
      comparator_colour
  ) {
    ggplot2::ggplot() +
      ggplot2::geom_polygon(
        data = world_map,
        ggplot2::aes(
          x = long,
          y = lat,
          group = group
        ),
        fill = "white",
        colour = "#777777",
        linewidth = 0.2
      ) +
      ggplot2::geom_raster(
        data = plot_data,
        ggplot2::aes(
          x = x,
          y = y,
          fill = Category
        ),
        alpha = 0.78
      ) +
      ggplot2::facet_wrap(
        ~Species,
        nrow = 1
      ) +
      ggplot2::scale_fill_manual(
        values = c(
          "QPH only" = method_colours[[
            "QPH"
          ]],
          stats::setNames(
            comparator_colour,
            paste0(
              comparator,
              " only"
            )
          ),
          "Shared" = shared_area_colour
        ),
        drop = FALSE,
        name = NULL
      ) +
      ggplot2::coord_quickmap(
        xlim = c(
          australia_extent_values[[
            "xmin"
          ]],
          australia_extent_values[[
            "xmax"
          ]]
        ),
        ylim = c(
          australia_extent_values[[
            "ymin"
          ]],
          australia_extent_values[[
            "ymax"
          ]]
        ),
        expand = FALSE
      ) +
      ggplot2::labs(
        x = "Longitude",
        y = "Latitude",
        title = paste(
          "QPH versus",
          comparator
        )
      ) +
      ggplot2::theme_classic(
        base_size = 9
      ) +
      ggplot2::theme(
        strip.background = ggplot2::element_blank(),
        legend.position = "bottom"
      )
  }

  difference_kde_panel <- make_difference_panel(
    qph_kde_data,
    "Gaussian KDE",
    method_colours[[
      "Gaussian KDE"
    ]]
  )

  difference_svm_panel <- make_difference_panel(
    qph_svm_data,
    "SVM",
    method_colours[[
      "SVM"
    ]]
  )

  difference_figure <- (
    difference_kde_panel /
      difference_svm_panel
  ) +
    patchwork::plot_annotation(
      tag_levels = "A"
    )

  ggplot2::ggsave(
    filename = difference_figure_pdf,
    plot = difference_figure,
    width = 15,
    height = 7.5,
    units = "in",
    bg = "white"
  )

  ggplot2::ggsave(
    filename = difference_figure_png,
    plot = difference_figure,
    width = 15,
    height = 7.5,
    units = "in",
    dpi = 350,
    bg = "white"
  )
}


# ============================================================
# Supplementary between-species geographic overlap heatmaps
# ============================================================

heatmap_rows <- list()
heatmap_index <- 0L

for (
  method_name in method_order
) {
  for (
    species_1 in expected_species
  ) {
    for (
      species_2 in expected_species
    ) {
      if (identical(species_1, species_2)) {
        jaccard_value <- 1
      } else {
        row <- between_species_overlap[
          between_species_overlap$Method ==
            method_name &
            (
              (
                between_species_overlap$Species_1 ==
                  species_1 &
                  between_species_overlap$Species_2 ==
                    species_2
              ) |
                (
                  between_species_overlap$Species_1 ==
                    species_2 &
                  between_species_overlap$Species_2 ==
                    species_1
                )
            ),
          ,
          drop = FALSE
        ]

        jaccard_value <- if (
          nrow(
            row
          ) ==
            1L
        ) {
          row$Jaccard_similarity[[
            1L
          ]]
        } else {
          NA_real_
        }
      }

      heatmap_index <- heatmap_index + 1L

      heatmap_rows[[
        heatmap_index
      ]] <- data.frame(
        Method = method_name,
        Species_1 = format_species_label(
          species_1
        ),
        Species_2 = format_species_label(
          species_2
        ),
        Jaccard_similarity = jaccard_value,
        stringsAsFactors = FALSE
      )
    }
  }
}

heatmap_data <- do.call(
  rbind,
  heatmap_rows
)

heatmap_data$Method <- factor(
  heatmap_data$Method,
  levels = method_order
)

heatmap_data$Species_1 <- factor(
  heatmap_data$Species_1,
  levels = vapply(
    expected_species,
    format_species_label,
    character(1)
  )
)

heatmap_data$Species_2 <- factor(
  heatmap_data$Species_2,
  levels = rev(
    vapply(
      expected_species,
      format_species_label,
      character(1)
    )
  )
)

between_species_heatmap <- ggplot2::ggplot(
  heatmap_data,
  ggplot2::aes(
    x = Species_1,
    y = Species_2,
    fill = Jaccard_similarity
  )
) +
  ggplot2::geom_tile(
    colour = "white",
    linewidth = 0.3
  ) +
  ggplot2::geom_text(
    ggplot2::aes(
      label = ifelse(
        is.finite(
          Jaccard_similarity
        ),
        sprintf(
          "%.2f",
          Jaccard_similarity
        ),
        "NA"
      )
    ),
    size = 2.7
  ) +
  ggplot2::facet_wrap(
    ~Method,
    nrow = 1
  ) +
  ggplot2::scale_fill_viridis_c(
    limits = c(
      0,
      1
    ),
    name = "Jaccard"
  ) +
  ggplot2::labs(
    x = NULL,
    y = NULL
  ) +
  ggplot2::theme_classic(
    base_size = 9.5
  ) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(
      angle = 45,
      hjust = 1
    ),
    strip.background = ggplot2::element_blank(),
    strip.text = ggplot2::element_text(
      face = "bold"
    ),
    legend.position = "bottom"
  )

ggplot2::ggsave(
  filename = between_species_heatmap_pdf,
  plot = between_species_heatmap,
  width = 12,
  height = 4.8,
  units = "in",
  bg = "white"
)

ggplot2::ggsave(
  filename = between_species_heatmap_png,
  plot = between_species_heatmap,
  width = 12,
  height = 4.8,
  units = "in",
  dpi = 350,
  bg = "white"
)


# ============================================================
# Supplementary environmental volume vs geographic area
# ============================================================

if (
  !is.null(
    environmental_geographic_comparison
  ) &&
    nrow(
      environmental_geographic_comparison
    ) >
      0L
) {
  environmental_geographic_plot <- environmental_geographic_comparison

  environmental_geographic_plot$Method <- factor(
    environmental_geographic_plot$Method,
    levels = method_order
  )

  environmental_geographic_plot$Species_label <- factor(
    vapply(
      environmental_geographic_plot$Species,
      format_species_label,
      character(1)
    ),
    levels = vapply(
      expected_species,
      format_species_label,
      character(1)
    )
  )

  environmental_geographic_figure <- ggplot2::ggplot(
    environmental_geographic_plot,
    ggplot2::aes(
      x = Hypervolume_volume,
      y = Projected_area_million_km2,
      colour = Method,
      shape = Species_label
    )
  ) +
    ggplot2::geom_point(
      size = 2.8
    ) +
    ggplot2::scale_colour_manual(
      values = method_colours,
      drop = FALSE
    ) +
    ggplot2::labs(
      x = expression(
        "Environmental hypervolume volume (PC units"^3*")"
      ),
      y = expression(
        "Projected geographic area (million km"^2*")"
      ),
      colour = NULL,
      shape = NULL
    ) +
    ggplot2::theme_classic(
      base_size = 10
    ) +
    ggplot2::theme(
      legend.position = "bottom"
    )

  ggplot2::ggsave(
    filename = environmental_geographic_figure_pdf,
    plot = environmental_geographic_figure,
    width = 8.5,
    height = 6.5,
    units = "in",
    bg = "white"
  )

  ggplot2::ggsave(
    filename = environmental_geographic_figure_png,
    plot = environmental_geographic_figure,
    width = 8.5,
    height = 6.5,
    units = "in",
    dpi = 350,
    bg = "white"
  )
}


# ============================================================
# Final result object
# ============================================================

run_metadata <- list(
  script = "22_Acacia_Geographic_Projection.R",
  analysis_settings_hash = analysis_settings_hash,
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  environmental_source_resolution_route = (
    resolved_environment$resolution_route
  ),
  complete_environment_cells = length(
    valid_cell_index
  ),
  projection_domain_area_km2 = total_domain_area_km2,
  projection_rasters_requested = (
    length(
      expected_species
    ) *
      length(
        method_order
      )
  ),
  projection_rasters_present = sum(
    projection_manifest$Raster_exists
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

final_results <- list(
  metadata = run_metadata,
  analysis_settings = analysis_settings,
  environment_source_qa = environment_source_qa,
  model_validation = model_validation,
  projection_parameters = projection_parameters,
  projection_runtime = projection_runtime,
  projection_area_summary = projection_summary,
  occurrence_coverage = occurrence_coverage,
  within_species_cross_method_overlap = within_species_overlap,
  within_species_cross_method_area_ratios = (
    within_species_area_ratios
  ),
  between_species_overlap = between_species_overlap,
  environmental_volume_vs_geographic_area = (
    environmental_geographic_comparison
  ),
  projection_manifest = projection_manifest,
  raster_files = list(
    pc_raster = pc_raster_file,
    complete_environment_mask = land_mask_file,
    cell_area = cell_area_file,
    species_method_projection_rasters = lapply(
      expected_species,
      function(species_name) {
        stats::setNames(
          vapply(
            method_order,
            function(method_name) {
              projection_raster_path(
                species_name,
                method_name
              )
            },
            character(1)
          ),
          method_order
        )
      }
    )
  )
)

names(
  final_results$raster_files$species_method_projection_rasters
) <- expected_species

saveRDS(
  final_results,
  final_results_file,
  version = 3
)


# ============================================================
# Analysis notes and session information
# ============================================================

analysis_notes <- c(
  "ACACIA GEOGRAPHIC PROJECTION",
  "============================",
  "",
  "Interpretation:",
  "  Potential geographic projections of fitted environmental hypervolumes.",
  "  No known empirical geographic truth is assumed.",
  "  These are not independently validated species distribution models.",
  "",
  "Environmental domain:",
  "  Australia/Tasmania extent 112--154 E, 44--10 S",
  "  native WorldClim 2.5-arc-minute resolution for all numerical metrics",
  "  plotting aggregation only; no aggregation in analysis",
  "",
  "Environmental transformation:",
  "  exact Script-18 occurrence-derived pooled PCA",
  "  retained axes PC1-PC3",
  "",
  "QPH:",
  "  revised sqrt-NB bandwidth from Script 19",
  "  q = 0.99",
  "  its own bandwidth-scaled candidate region",
  "",
  "Gaussian KDE:",
  "  independent Silverman bandwidth from Script 19",
  "  probability quantile = 0.95",
  "  its own bandwidth-scaled candidate region",
  "  KDE is never evaluated with the QPH bandwidth",
  "",
  "SVM:",
  "  one-class radial e1071 projection model from Script 19",
  "  nu = 0.01",
  "  gamma = 0.50",
  "  internal scale = TRUE",
  "",
  "Species x method endpoints:",
  "  projected area",
  "  percent of complete environmental domain",
  "  included raster cells",
  "  occurrence-record inclusion proportion",
  "",
  "Cross-method endpoints:",
  "  area ratios",
  "  area-weighted Jaccard",
  "  area-weighted Sorensen",
  "  directional overlap fractions",
  "  shared and unique projected area",
  "",
  "Between-species endpoint:",
  "  area-weighted geographic overlap within each estimator",
  "",
  paste0(
    "Environmental source resolution route: ",
    resolved_environment$resolution_route
  ),
  paste0(
    "Complete environmental cells: ",
    length(
      valid_cell_index
    )
  ),
  paste0(
    "Projection domain area (km^2): ",
    signif(
      total_domain_area_km2,
      10
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
    "Script-22 analysis settings hash: ",
    analysis_settings_hash
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
# Console summary
# ============================================================

message(
  "\n============================================================"
)

message(
  "22_Acacia_Geographic_Projection.R complete."
)

message(
  "\nProjected area summary:"
)

print(
  projection_summary[
    ,
    c(
      "Species",
      "Method",
      "Projected_area_km2",
      "Percent_projection_domain",
      "Included_cell_count"
    ),
    drop = FALSE
  ],
  digits = 6,
  row.names = FALSE
)

message(
  "\nWithin-species geographic method agreement:"
)

print(
  within_species_overlap[
    ,
    c(
      "Species",
      "Method_pair",
      "Jaccard_similarity",
      "Sorensen_similarity",
      "Fraction_method_1_overlapped",
      "Fraction_method_2_overlapped"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)

message(
  "\nOccurrence-record inclusion:"
)

print(
  occurrence_coverage[
    ,
    c(
      "Species",
      "Method",
      "Occurrence_inclusion_proportion"
    ),
    drop = FALSE
  ],
  digits = 5,
  row.names = FALSE
)

message(
  "\nProjection-parameter QA:"
)

print(
  projection_parameters[
    ,
    c(
      "Species",
      "QPH_bandwidth_PC1",
      "QPH_bandwidth_PC2",
      "QPH_bandwidth_PC3",
      "KDE_bandwidth_PC1",
      "KDE_bandwidth_PC2",
      "KDE_bandwidth_PC3",
      "QPH_KDE_bandwidth_vectors_identical"
    ),
    drop = FALSE
  ],
  digits = 6,
  row.names = FALSE
)

message(
  "\nFinal geographic object:\n  ",
  normalizePath(
    final_results_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "============================================================"
)
