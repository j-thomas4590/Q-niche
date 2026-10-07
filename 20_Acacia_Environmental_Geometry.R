# ============================================================
# 20_Acacia_Environmental_Geometry.R
# ============================================================
#
# PURPOSE
# -------
# Quantify environmental-space geometry for the revised empirical Acacia
# baseline models from Script 19.
#


rm(list = ls())
gc()


# ============================================================
# Packages
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
    "Install required package(s): ",
    paste(
      missing_packages,
      collapse = ", "
    )
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
  "02_Environmental_Geometry"
)

table_directory <- file.path(
  output_directory,
  "tables"
)

figure_directory <- file.path(
  output_directory,
  "figures"
)

figure_data_directory <- file.path(
  output_directory,
  "figure_data"
)

for (directory in c(
  output_directory,
  table_directory,
  figure_directory,
  figure_data_directory
)) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ============================================================
# Locked species / method definitions
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

species_short_labels <- c(
  "Acacia georginae" = "A. georginae",
  "Acacia tumida" = "A. tumida",
  "Acacia kempeana" = "A. kempeana",
  "Acacia calamifolia" = "A. calamifolia",
  "Acacia saligna" = "A. saligna"
)

method_order <- c(
  "QPH",
  "Gaussian KDE",
  "SVM"
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
# Numerical settings retained from old empirical geometry
# ============================================================

overlap_num_points_max <- 10000L
overlap_distance_factor <- 1

master_seed <- 260808L

resume_from_checkpoint <- TRUE
retry_failed_overlap_comparisons <- TRUE

# Plotting only. Complete saved RandomPoints are always used numerically.
maximum_publication_hypervolume_points <- 7000L

figure_tiff_dpi <- 600


# ============================================================
# Input files
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

required_input_files <- c(
  locked_archive_file,
  locked_settings_file,
  baseline_settings_file,
  baseline_results_file
)

missing_input_files <- required_input_files[
  !file.exists(required_input_files)
]

if (length(missing_input_files) > 0L) {
  stop(
    "Missing required upstream file(s):\n  ",
    paste(
      missing_input_files,
      collapse = "\n  "
    ),
    "\nScripts 18 and 19 must finish successfully before Script 20."
  )
}


# ============================================================
# Output files
# ============================================================

geometry_checkpoint_file <- file.path(
  output_directory,
  "acacia_geometry_overlap_checkpoint.rds"
)

analysis_settings_file <- file.path(
  output_directory,
  "analysis_settings.rds"
)

volume_centroid_file <- file.path(
  table_directory,
  "acacia_volume_centroid_summary.csv"
)

volume_ranking_file <- file.path(
  table_directory,
  "acacia_niche_breadth_rankings.csv"
)

volume_ratio_file <- file.path(
  table_directory,
  "acacia_within_species_volume_ratios.csv"
)

between_species_overlap_file <- file.path(
  table_directory,
  "acacia_between_species_overlap_by_method.csv"
)

cross_method_overlap_file <- file.path(
  table_directory,
  "acacia_within_species_cross_method_overlap.csv"
)

between_species_centroid_file <- file.path(
  table_directory,
  "acacia_between_species_centroid_distances.csv"
)

cross_method_centroid_file <- file.path(
  table_directory,
  "acacia_within_species_cross_method_centroid_distances.csv"
)

method_disagreement_file <- file.path(
  table_directory,
  "acacia_species_method_disagreement_summary.csv"
)

overlap_failure_file <- file.path(
  table_directory,
  "acacia_overlap_failures.csv"
)

model_validation_file <- file.path(
  table_directory,
  "acacia_geometry_model_validation.csv"
)

main_plot_data_file <- file.path(
  figure_data_directory,
  "acacia_empirical_hypervolume_PC1_PC2_PC3_plot_data.csv"
)

between_species_heatmap_data_file <- file.path(
  figure_data_directory,
  "acacia_between_species_overlap_heatmap_data.csv"
)

cross_method_plot_data_file <- file.path(
  figure_data_directory,
  "acacia_cross_method_overlap_plot_data.csv"
)

main_figure_pdf <- file.path(
  figure_directory,
  "Figure_Acacia_environmental_hypervolumes_PC1_PC2_PC3.pdf"
)

main_figure_png <- file.path(
  figure_directory,
  "Figure_Acacia_environmental_hypervolumes_PC1_PC2_PC3.png"
)

main_figure_tiff <- file.path(
  figure_directory,
  "Figure_Acacia_environmental_hypervolumes_PC1_PC2_PC3.tiff"
)

summary_figure_pdf <- file.path(
  figure_directory,
  "Figure_Acacia_environmental_geometry_summary.pdf"
)

summary_figure_png <- file.path(
  figure_directory,
  "Figure_Acacia_environmental_geometry_summary.png"
)

heatmap_figure_pdf <- file.path(
  figure_directory,
  "Figure_Acacia_between_species_overlap_heatmaps.pdf"
)

heatmap_figure_png <- file.path(
  figure_directory,
  "Figure_Acacia_between_species_overlap_heatmaps.png"
)

run_metadata_file <- file.path(
  output_directory,
  "acacia_environmental_geometry_metadata.rds"
)

final_results_file <- file.path(
  output_directory,
  "acacia_environmental_geometry_sqrtNB_q099.rds"
)

analysis_notes_file <- file.path(
  output_directory,
  "ACACIA_ENVIRONMENTAL_GEOMETRY_NOTES.txt"
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


validate_numeric_matrix <- function(
    x,
    object_name,
    expected_columns = NULL
) {

  x <- as.matrix(x)
  storage.mode(x) <- "double"

  if (nrow(x) < 1L) {
    stop(
      object_name,
      " contains no rows."
    )
  }

  if (ncol(x) < 1L) {
    stop(
      object_name,
      " contains no columns."
    )
  }

  if (
    !is.null(
      expected_columns
    ) &&
      ncol(x) !=
        expected_columns
  ) {
    stop(
      object_name,
      " has ",
      ncol(x),
      " columns; expected ",
      expected_columns,
      "."
    )
  }

  if (any(!is.finite(x))) {
    stop(
      object_name,
      " contains missing or non-finite values."
    )
  }

  x
}


set_pc_names <- function(x) {

  x <- validate_numeric_matrix(
    x,
    "PC matrix",
    expected_columns = 3L
  )

  colnames(x) <- expected_pc_names

  x
}


standardise_hypervolume_axis_names <- function(hv) {

  if (!methods::is(hv, "Hypervolume")) {
    stop(
      "Expected a Hypervolume object."
    )
  }

  if (
    ncol(
      hv@Data
    ) !=
      3L ||
      ncol(
        hv@RandomPoints
      ) !=
        3L
  ) {
    stop(
      "Hypervolume does not have exactly three environmental dimensions."
    )
  }

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


thin_points_for_plot <- function(
    points,
    maximum_points,
    seed
) {

  points <- set_pc_names(
    points
  )

  if (
    nrow(
      points
    ) <=
      maximum_points
  ) {
    return(points)
  }

  set.seed(
    as.integer(
      seed
    )
  )

  points[
    sample.int(
      nrow(
        points
      ),
      size = maximum_points,
      replace = FALSE
    ),
    ,
    drop = FALSE
  ]
}


centroid_distance <- function(
    x,
    y
) {

  x <- as.numeric(x)
  y <- as.numeric(y)

  if (
    length(x) !=
      length(y) ||
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
    return(NA_real_)
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
    !is.finite(
      denominator
    ) ||
      denominator == 0
  ) {
    return(NA_real_)
  }

  numerator /
    denominator
}


safe_min <- function(x) {

  x <- x[
    is.finite(
      x
    )
  ]

  if (length(x) == 0L) {
    return(NA_real_)
  }

  min(x)
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


get_hv_component_volume <- function(
    hv_set,
    component_name
) {

  if (!methods::is(hv_set, "HypervolumeList")) {
    stop(
      "Set operation did not return a HypervolumeList object."
    )
  }

  if (
    !component_name %in%
      names(
        hv_set@HVList
      )
  ) {
    stop(
      "Set-operation result does not contain component '",
      component_name,
      "'. Components available: ",
      paste(
        names(
          hv_set@HVList
        ),
        collapse = ", "
      )
    )
  }

  component <- hv_set@HVList[[component_name]]

  if (is.null(component)) {
    return(0)
  }

  if (!methods::is(component, "Hypervolume")) {
    stop(
      "Set-operation component is not a Hypervolume object."
    )
  }

  volume <- as.numeric(
    component@Volume
  )

  if (!is.finite(volume)) {
    return(NA_real_)
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

      jaccard <- safe_ratio(
        intersection_volume,
        union_volume
      )

      sorensen <- safe_ratio(
        2 *
          intersection_volume,
        volume_1 +
          volume_2
      )

      fraction_1 <- safe_ratio(
        intersection_volume,
        volume_1
      )

      fraction_2 <- safe_ratio(
        intersection_volume,
        volume_2
      )

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


save_plot_three_formats <- function(
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


# ============================================================
# Load authoritative upstream objects
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
    "Could not recover required Script-18/19 provenance hashes."
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
    baseline_results$metadata$analysis_settings_hash,
    baseline_analysis_hash
  ) ||
    !identical(
      baseline_results$metadata$locked_design_hash,
      locked_design_hash
    )
) {
  stop(
    "Script-19 final object does not correspond to the current Script-18 inputs."
  )
}

if (
  baseline_results$metadata$model_count_successful !=
    15L ||
    baseline_results$metadata$model_count_failed !=
      0L
) {
  stop(
    "Script 20 requires all 15 Script-19 baseline models to have succeeded."
  )
}


# ============================================================
# Validate locked species PC matrices
# ============================================================

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
    "Locked species PCA matrices are missing or out of order."
  )
}

for (
  species_name in expected_species
) {

  species_matrices[[species_name]] <- set_pc_names(
    species_matrices[[species_name]]
  )
}


# ============================================================
# Validate all 15 revised baseline model bundles
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

model_validation_rows <- list()
model_validation_index <- 0L

model_md5_vector <- character(0)

for (
  species_name in expected_species
) {

  model_bundles[[species_name]] <- list()

  occurrence_points <- species_matrices[[
    species_name
  ]]

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

    required_bundle_fields <- c(
      "metadata",
      "hypervolume",
      "projection_model",
      "diagnostics"
    )

    if (
      !all(
        required_bundle_fields %in%
          names(
            bundle
          )
      )
    ) {
      stop(
        "Model bundle has unexpected structure: ",
        current_file
      )
    }

    if (
      !identical(
        bundle$metadata$species,
        species_name
      ) ||
        !identical(
          bundle$metadata$method,
          method_name
        )
    ) {
      stop(
        "Species/method metadata mismatch in ",
        current_file
      )
    }

    if (
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
        "Upstream provenance mismatch in ",
        current_file
      )
    }

    if (
      bundle$metadata$occurrence_count !=
        nrow(
          occurrence_points
        )
    ) {
      stop(
        "Occurrence count mismatch in ",
        current_file
      )
    }

    hv <- standardise_hypervolume_axis_names(
      bundle$hypervolume
    )

    if (
      nrow(
        hv@RandomPoints
      ) <
        1L ||
        !is.finite(
          hv@Volume
        ) ||
        hv@Volume <=
          0
    ) {
      stop(
        "Invalid saved hypervolume in ",
        current_file
      )
    }

    bundle$hypervolume <- hv

    # Method-specific revised baseline checks.
    method_parameter_check <- TRUE
    method_parameter_note <- NA_character_

    if (
      identical(
        method_name,
        "QPH"
      )
    ) {

      if (
        !"qph_result" %in%
          names(
            bundle
          )
      ) {
        stop(
          "QPH bundle is missing qph_result: ",
          current_file
        )
      }

      audit <- bundle$qph_result$audit

      method_parameter_check <- (
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
                  occurrence_points
                )
              )
            )
      )

      method_parameter_note <- (
        "sqrt-NB isotropic bandwidth; q=0.99"
      )

    } else if (
      identical(
        method_name,
        "Gaussian KDE"
      )
    ) {

      method_parameter_check <- (
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

      method_parameter_note <- (
        "independent Silverman bandwidth; probability quantile=0.95"
      )

    } else {

      method_parameter_check <- (
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
            all.equal(
              bundle$projection_model$svm_scale_factor,
              1,
              tolerance = 1e-12
            )
          ) &&
          isTRUE(
            bundle$projection_model$internal_scaling
          )
      )

      method_parameter_note <- (
        "nu=0.01; gamma=0.50; scale.factor=1; projection scale=TRUE"
      )
    }

    if (!isTRUE(method_parameter_check)) {
      stop(
        "Method-specific baseline QA failed for ",
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

    model_md5_vector[[condition_id]] <- safe_md5(
      current_file
    )

    model_validation_index <- (
      model_validation_index +
        1L
    )

    model_validation_rows[[
      model_validation_index
    ]] <- data.frame(
      Condition_id = condition_id,
      Species = species_name,
      Method = method_name,
      Occurrence_count = nrow(
        occurrence_points
      ),
      Hypervolume_random_points = nrow(
        hv@RandomPoints
      ),
      Hypervolume_volume = as.numeric(
        hv@Volume
      ),
      Method_parameter_check = method_parameter_check,
      Method_parameter_note = method_parameter_note,
      Model_MD5 = safe_md5(
        current_file
      ),
      stringsAsFactors = FALSE
    )

    model_bundles[[species_name]][[method_name]] <- bundle
  }
}

model_validation <- do.call(
  rbind,
  model_validation_rows
)

rownames(
  model_validation
) <- NULL

write_csv_safely(
  model_validation,
  model_validation_file
)


# ============================================================
# Analysis settings and compatibility hash
# ============================================================

analysis_settings <- list(
  script = "20_Acacia_Environmental_Geometry.R",
  analysis_branch = "Acacia_sqrtNB_q099",
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  model_md5_vector = model_md5_vector,
  species = expected_species,
  methods = method_order,
  environmental_space = "shared occurrence-derived PC1-PC3",
  interpretation = paste(
    "Empirical comparison among alternative reconstructions;",
    "no true niche is assumed."
  ),
  overlap = list(
    num_points_max = overlap_num_points_max,
    distance_factor = overlap_distance_factor,
    master_seed = master_seed
  )
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
      "Existing Script-20 outputs were created with different models or ",
      "overlap settings. Archive/remove 02_Environmental_Geometry before ",
      "starting the current analysis."
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
# Volume and centroid summaries
# ============================================================

message(
  "Calculating Acacia hypervolume size and centroid summaries..."
)

volume_centroid_rows <- list()
volume_centroid_index <- 0L

for (
  species_name in expected_species
) {

  occurrence_points <- species_matrices[[
    species_name
  ]]

  occurrence_centroid <- colMeans(
    occurrence_points
  )

  for (
    method_name in method_order
  ) {

    hv <- model_bundles[[species_name]][[
      method_name
    ]]$hypervolume

    hv_centroid <- colMeans(
      hv@RandomPoints
    )

    volume_centroid_index <- (
      volume_centroid_index +
        1L
    )

    volume_centroid_rows[[
      volume_centroid_index
    ]] <- data.frame(
      Species = species_name,
      Species_code = species_code(
        species_name
      ),
      Method = method_name,
      Occurrence_count = nrow(
        occurrence_points
      ),
      Hypervolume_volume = as.numeric(
        hv@Volume
      ),
      Point_density = as.numeric(
        hv@PointDensity
      ),
      Hypervolume_random_points = nrow(
        hv@RandomPoints
      ),
      Occurrence_centroid_PC1 = occurrence_centroid[[1L]],
      Occurrence_centroid_PC2 = occurrence_centroid[[2L]],
      Occurrence_centroid_PC3 = occurrence_centroid[[3L]],
      Hypervolume_centroid_PC1 = hv_centroid[[1L]],
      Hypervolume_centroid_PC2 = hv_centroid[[2L]],
      Hypervolume_centroid_PC3 = hv_centroid[[3L]],
      Centroid_displacement_from_occurrence = centroid_distance(
        occurrence_centroid,
        hv_centroid
      ),
      stringsAsFactors = FALSE
    )
  }
}

volume_centroid_summary <- do.call(
  rbind,
  volume_centroid_rows
)

rownames(
  volume_centroid_summary
) <- NULL

volume_centroid_summary$Niche_breadth_rank_within_method <- NA_integer_

for (
  method_name in method_order
) {

  method_indices <- which(
    volume_centroid_summary$Method ==
      method_name
  )

  volume_centroid_summary$Niche_breadth_rank_within_method[
    method_indices
  ] <- rank(
    -volume_centroid_summary$Hypervolume_volume[
      method_indices
    ],
    ties.method = "min"
  )
}

write_csv_safely(
  volume_centroid_summary,
  volume_centroid_file
)


# ============================================================
# Niche-breadth ranking and within-species volume ratios
# ============================================================

ranking_rows <- list()
volume_ratio_rows <- list()

for (
  species_index in seq_along(
    expected_species
  )
) {

  species_name <- expected_species[[
    species_index
  ]]

  species_data <- volume_centroid_summary[
    volume_centroid_summary$Species ==
      species_name,
    ,
    drop = FALSE
  ]

  get_method_value <- function(
      method_name,
      column_name
  ) {

    value <- species_data[
      species_data$Method ==
        method_name,
      column_name
    ]

    if (length(value) != 1L) {
      stop(
        "Could not recover unique ",
        column_name,
        " for ",
        species_name,
        " / ",
        method_name,
        "."
      )
    }

    value[[1L]]
  }

  qph_volume <- get_method_value(
    "QPH",
    "Hypervolume_volume"
  )

  kde_volume <- get_method_value(
    "Gaussian KDE",
    "Hypervolume_volume"
  )

  svm_volume <- get_method_value(
    "SVM",
    "Hypervolume_volume"
  )

  ranking_rows[[species_index]] <- data.frame(
    Species = species_name,
    QPH_volume = qph_volume,
    QPH_rank = get_method_value(
      "QPH",
      "Niche_breadth_rank_within_method"
    ),
    Gaussian_KDE_volume = kde_volume,
    Gaussian_KDE_rank = get_method_value(
      "Gaussian KDE",
      "Niche_breadth_rank_within_method"
    ),
    SVM_volume = svm_volume,
    SVM_rank = get_method_value(
      "SVM",
      "Niche_breadth_rank_within_method"
    ),
    stringsAsFactors = FALSE
  )

  volume_ratio_rows[[species_index]] <- data.frame(
    Species = species_name,
    QPH_volume = qph_volume,
    Gaussian_KDE_volume = kde_volume,
    SVM_volume = svm_volume,
    Gaussian_to_QPH_volume_ratio = safe_ratio(
      kde_volume,
      qph_volume
    ),
    SVM_to_QPH_volume_ratio = safe_ratio(
      svm_volume,
      qph_volume
    ),
    QPH_to_Gaussian_volume_ratio = safe_ratio(
      qph_volume,
      kde_volume
    ),
    QPH_to_SVM_volume_ratio = safe_ratio(
      qph_volume,
      svm_volume
    ),
    Maximum_to_minimum_method_volume_ratio = safe_ratio(
      max(
        qph_volume,
        kde_volume,
        svm_volume
      ),
      min(
        qph_volume,
        kde_volume,
        svm_volume
      )
    ),
    stringsAsFactors = FALSE
  )
}

volume_rankings <- do.call(
  rbind,
  ranking_rows
)

volume_ratios <- do.call(
  rbind,
  volume_ratio_rows
)

write_csv_safely(
  volume_rankings,
  volume_ranking_file
)

write_csv_safely(
  volume_ratios,
  volume_ratio_file
)


# ============================================================
# Centroid distances among species and among methods
# ============================================================

message(
  "Calculating centroid-distance comparisons..."
)

species_pairs <- combn(
  expected_species,
  2,
  simplify = FALSE
)

method_pairs <- combn(
  method_order,
  2,
  simplify = FALSE
)


between_species_centroid_rows <- list()
between_species_centroid_index <- 0L

for (
  method_name in method_order
) {

  for (
    species_pair in species_pairs
  ) {

    species_1 <- species_pair[[1L]]
    species_2 <- species_pair[[2L]]

    centroid_1 <- colMeans(
      model_bundles[[species_1]][[
        method_name
      ]]$hypervolume@RandomPoints
    )

    centroid_2 <- colMeans(
      model_bundles[[species_2]][[
        method_name
      ]]$hypervolume@RandomPoints
    )

    between_species_centroid_index <- (
      between_species_centroid_index +
        1L
    )

    between_species_centroid_rows[[
      between_species_centroid_index
    ]] <- data.frame(
      Method = method_name,
      Species_1 = species_1,
      Species_2 = species_2,
      Species_pair = paste(
        species_1,
        species_2,
        sep = " vs "
      ),
      Centroid_distance = centroid_distance(
        centroid_1,
        centroid_2
      ),
      stringsAsFactors = FALSE
    )
  }
}

between_species_centroid_distances <- do.call(
  rbind,
  between_species_centroid_rows
)

write_csv_safely(
  between_species_centroid_distances,
  between_species_centroid_file
)


cross_method_centroid_rows <- list()
cross_method_centroid_index <- 0L

for (
  species_name in expected_species
) {

  for (
    method_pair in method_pairs
  ) {

    method_1 <- method_pair[[1L]]
    method_2 <- method_pair[[2L]]

    centroid_1 <- colMeans(
      model_bundles[[species_name]][[
        method_1
      ]]$hypervolume@RandomPoints
    )

    centroid_2 <- colMeans(
      model_bundles[[species_name]][[
        method_2
      ]]$hypervolume@RandomPoints
    )

    cross_method_centroid_index <- (
      cross_method_centroid_index +
        1L
    )

    cross_method_centroid_rows[[
      cross_method_centroid_index
    ]] <- data.frame(
      Species = species_name,
      Method_1 = method_1,
      Method_2 = method_2,
      Method_pair = paste(
        method_1,
        method_2,
        sep = " vs "
      ),
      Centroid_distance = centroid_distance(
        centroid_1,
        centroid_2
      ),
      stringsAsFactors = FALSE
    )
  }
}

cross_method_centroid_distances <- do.call(
  rbind,
  cross_method_centroid_rows
)

write_csv_safely(
  cross_method_centroid_distances,
  cross_method_centroid_file
)


# ============================================================
# Restartable overlap checkpoint
# ============================================================

between_species_overlap_results <- list()
cross_method_overlap_results <- list()

if (
  resume_from_checkpoint &&
    file.exists(
      geometry_checkpoint_file
    )
) {

  checkpoint_object <- readRDS(
    geometry_checkpoint_file
  )

  if (
    !identical(
      checkpoint_object$analysis_settings_hash,
      analysis_settings_hash
    )
  ) {
    stop(
      "Existing Script-20 overlap checkpoint was created with different ",
      "baseline models or numerical settings."
    )
  }

  between_species_overlap_results <- (
    checkpoint_object$between_species_overlap_results
  )

  cross_method_overlap_results <- (
    checkpoint_object$cross_method_overlap_results
  )

  if (is.null(between_species_overlap_results)) {
    between_species_overlap_results <- list()
  }

  if (is.null(cross_method_overlap_results)) {
    cross_method_overlap_results <- list()
  }
}


save_overlap_checkpoint <- function() {

  saveRDS(
    list(
      analysis_settings_hash = analysis_settings_hash,
      analysis_settings = analysis_settings,
      between_species_overlap_results = (
        between_species_overlap_results
      ),
      cross_method_overlap_results = (
        cross_method_overlap_results
      ),
      last_saved_at = as.character(
        Sys.time()
      )
    ),
    geometry_checkpoint_file,
    version = 3
  )
}


# ============================================================
# Between-species overlap separately within each method
# ============================================================

message(
  "Calculating pairwise interspecific overlap within each estimator..."
)

for (
  method_index in seq_along(
    method_order
  )
) {

  method_name <- method_order[[
    method_index
  ]]

  for (
    pair_index in seq_along(
      species_pairs
    )
  ) {

    species_pair <- species_pairs[[
      pair_index
    ]]

    species_1 <- species_pair[[1L]]
    species_2 <- species_pair[[2L]]

    result_key <- paste(
      method_code(
        method_name
      ),
      species_code(
        species_1
      ),
      species_code(
        species_2
      ),
      sep = "__"
    )

    existing_result <- between_species_overlap_results[[
      result_key
    ]]

    if (
      !is.null(
        existing_result
      ) &&
        isTRUE(
          existing_result$success
        )
    ) {
      message(
        "Skipping successful overlap: ",
        result_key
      )

      next
    }

    if (
      !is.null(
        existing_result
      ) &&
        !isTRUE(
          existing_result$success
        ) &&
        !retry_failed_overlap_comparisons
    ) {
      next
    }

    current_seed <- as.integer(
      master_seed +
        method_index *
          10000L +
        pair_index *
          100L
    )

    message(
      "Overlap: ",
      method_name,
      " | ",
      species_1,
      " vs ",
      species_2
    )

    overlap_result <- calculate_overlap_safe(
      hv1 = model_bundles[[species_1]][[
        method_name
      ]]$hypervolume,
      hv2 = model_bundles[[species_2]][[
        method_name
      ]]$hypervolume,
      seed = current_seed
    )

    between_species_overlap_results[[
      result_key
    ]] <- c(
      list(
        key = result_key,
        comparison_type = "between_species_within_method",
        method = method_name,
        species_1 = species_1,
        species_2 = species_2,
        seed = current_seed
      ),
      overlap_result
    )

    if (!isTRUE(overlap_result$success)) {
      warning(
        "Between-species overlap failed for ",
        result_key,
        ": ",
        overlap_result$error_message
      )
    }

    save_overlap_checkpoint()
    gc()
  }
}


# ============================================================
# Cross-method overlap for the same species
# ============================================================

message(
  "Calculating cross-method overlap within each species..."
)

for (
  species_index in seq_along(
    expected_species
  )
) {

  species_name <- expected_species[[
    species_index
  ]]

  for (
    pair_index in seq_along(
      method_pairs
    )
  ) {

    method_pair <- method_pairs[[
      pair_index
    ]]

    method_1 <- method_pair[[1L]]
    method_2 <- method_pair[[2L]]

    result_key <- paste(
      species_code(
        species_name
      ),
      method_code(
        method_1
      ),
      method_code(
        method_2
      ),
      sep = "__"
    )

    existing_result <- cross_method_overlap_results[[
      result_key
    ]]

    if (
      !is.null(
        existing_result
      ) &&
        isTRUE(
          existing_result$success
        )
    ) {
      message(
        "Skipping successful cross-method overlap: ",
        result_key
      )

      next
    }

    if (
      !is.null(
        existing_result
      ) &&
        !isTRUE(
          existing_result$success
        ) &&
        !retry_failed_overlap_comparisons
    ) {
      next
    }

    current_seed <- as.integer(
      master_seed +
        500000L +
        species_index *
          10000L +
        pair_index *
          100L
    )

    message(
      "Cross-method overlap: ",
      species_name,
      " | ",
      method_1,
      " vs ",
      method_2
    )

    overlap_result <- calculate_overlap_safe(
      hv1 = model_bundles[[species_name]][[
        method_1
      ]]$hypervolume,
      hv2 = model_bundles[[species_name]][[
        method_2
      ]]$hypervolume,
      seed = current_seed
    )

    cross_method_overlap_results[[
      result_key
    ]] <- c(
      list(
        key = result_key,
        comparison_type = "cross_method_within_species",
        species = species_name,
        method_1 = method_1,
        method_2 = method_2,
        seed = current_seed
      ),
      overlap_result
    )

    if (!isTRUE(overlap_result$success)) {
      warning(
        "Cross-method overlap failed for ",
        result_key,
        ": ",
        overlap_result$error_message
      )
    }

    save_overlap_checkpoint()
    gc()
  }
}


# ============================================================
# Compile overlap tables
# ============================================================

between_species_overlap_rows <- lapply(
  between_species_overlap_results,
  function(result) {

    data.frame(
      Success = result$success,
      Method = result$method,
      Species_1 = result$species_1,
      Species_2 = result$species_2,
      Species_pair = paste(
        result$species_1,
        result$species_2,
        sep = " vs "
      ),
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

between_species_overlap <- do.call(
  rbind,
  between_species_overlap_rows
)

rownames(
  between_species_overlap
) <- NULL

between_species_overlap$Method <- factor(
  between_species_overlap$Method,
  levels = method_order
)

between_species_overlap <- between_species_overlap[
  order(
    between_species_overlap$Method,
    match(
      between_species_overlap$Species_1,
      expected_species
    ),
    match(
      between_species_overlap$Species_2,
      expected_species
    )
  ),
  ,
  drop = FALSE
]

between_species_overlap$Method <- as.character(
  between_species_overlap$Method
)

write_csv_safely(
  between_species_overlap,
  between_species_overlap_file
)


cross_method_overlap_rows <- lapply(
  cross_method_overlap_results,
  function(result) {

    data.frame(
      Success = result$success,
      Species = result$species,
      Method_1 = result$method_1,
      Method_2 = result$method_2,
      Method_pair = paste(
        result$method_1,
        result$method_2,
        sep = " vs "
      ),
      Volume_method_1 = result$volume_1,
      Volume_method_2 = result$volume_2,
      Intersection_volume = result$intersection_volume,
      Union_volume = result$union_volume,
      Jaccard_similarity = result$jaccard,
      Sorensen_similarity = result$sorensen,
      Fraction_method_1_overlapped = result$fraction_1,
      Fraction_method_2_overlapped = result$fraction_2,
      Set_operation_runtime_seconds = result$runtime_seconds,
      Set_operation_seed = result$seed,
      Error_message = result$error_message,
      stringsAsFactors = FALSE
    )
  }
)

cross_method_overlap <- do.call(
  rbind,
  cross_method_overlap_rows
)

rownames(
  cross_method_overlap
) <- NULL

write_csv_safely(
  cross_method_overlap,
  cross_method_overlap_file
)


# ============================================================
# Overlap failures
# ============================================================

between_species_failures <- between_species_overlap[
  !between_species_overlap$Success,
  c(
    "Method",
    "Species_1",
    "Species_2",
    "Error_message"
  ),
  drop = FALSE
]

between_species_failures$Comparison_type <- rep(
  "Between species",
  nrow(
    between_species_failures
  )
)


cross_failure_index <- (
  !cross_method_overlap$Success
)

within_species_failures <- data.frame(
  Method = cross_method_overlap$Method_pair[
    cross_failure_index
  ],
  Species_1 = cross_method_overlap$Species[
    cross_failure_index
  ],
  Species_2 = cross_method_overlap$Species[
    cross_failure_index
  ],
  Error_message = cross_method_overlap$Error_message[
    cross_failure_index
  ],
  Comparison_type = rep(
    "Within species across methods",
    sum(
      cross_failure_index
    )
  ),
  stringsAsFactors = FALSE
)


overlap_failures <- rbind(
  between_species_failures,
  within_species_failures
)

rownames(
  overlap_failures
) <- NULL

write_csv_safely(
  overlap_failures,
  overlap_failure_file
)


# ============================================================
# Species-level method disagreement summary
# ============================================================

method_disagreement_rows <- list()

for (
  species_index in seq_along(
    expected_species
  )
) {

  species_name <- expected_species[[
    species_index
  ]]

  species_volume_data <- volume_centroid_summary[
    volume_centroid_summary$Species ==
      species_name,
    ,
    drop = FALSE
  ]

  species_cross_overlap <- cross_method_overlap[
    cross_method_overlap$Species ==
      species_name &
      cross_method_overlap$Success,
    ,
    drop = FALSE
  ]

  species_cross_centroids <- cross_method_centroid_distances[
    cross_method_centroid_distances$Species ==
      species_name,
    ,
    drop = FALSE
  ]

  method_disagreement_rows[[species_index]] <- data.frame(
    Species = species_name,
    Minimum_method_volume = min(
      species_volume_data$Hypervolume_volume
    ),
    Maximum_method_volume = max(
      species_volume_data$Hypervolume_volume
    ),
    Maximum_to_minimum_volume_ratio = safe_ratio(
      max(
        species_volume_data$Hypervolume_volume
      ),
      min(
        species_volume_data$Hypervolume_volume
      )
    ),
    Minimum_cross_method_Jaccard = safe_min(
      species_cross_overlap$Jaccard_similarity
    ),
    Mean_cross_method_Jaccard = safe_mean(
      species_cross_overlap$Jaccard_similarity
    ),
    Maximum_cross_method_centroid_distance = safe_max(
      species_cross_centroids$Centroid_distance
    ),
    stringsAsFactors = FALSE
  )
}

method_disagreement_summary <- do.call(
  rbind,
  method_disagreement_rows
)

write_csv_safely(
  method_disagreement_summary,
  method_disagreement_file
)


# ============================================================
# Figure data: environmental hypervolumes
# ============================================================

message(
  "Building environmental geometry figure data..."
)

source_order <- c(
  "Occurrences",
  method_order
)

main_plot_rows <- list()
main_plot_index <- 0L

for (
  species_index in seq_along(
    expected_species
  )
) {

  species_name <- expected_species[[
    species_index
  ]]

  occurrence_points <- species_matrices[[
    species_name
  ]]

  main_plot_index <- main_plot_index + 1L

  main_plot_rows[[
    main_plot_index
  ]] <- data.frame(
    PC1 = occurrence_points[
      ,
      "PC1"
    ],
    PC2 = occurrence_points[
      ,
      "PC2"
    ],
    PC3 = occurrence_points[
      ,
      "PC3"
    ],
    Species = species_name,
    Species_label = unname(
      species_short_labels[[
        species_name
      ]]
    ),
    Source = "Occurrences",
    Is_occurrence = TRUE,
    stringsAsFactors = FALSE
  )

  for (
    method_index in seq_along(
      method_order
    )
  ) {

    method_name <- method_order[[
      method_index
    ]]

    points <- model_bundles[[species_name]][[
      method_name
    ]]$hypervolume@RandomPoints

    points <- thin_points_for_plot(
      points = points,
      maximum_points = maximum_publication_hypervolume_points,
      seed = as.integer(
        master_seed +
          800000L +
          species_index *
            1000L +
          method_index *
            10L
      )
    )

    main_plot_index <- main_plot_index + 1L

    main_plot_rows[[
      main_plot_index
    ]] <- data.frame(
      PC1 = points[
        ,
        "PC1"
      ],
      PC2 = points[
        ,
        "PC2"
      ],
      PC3 = points[
        ,
        "PC3"
      ],
      Species = species_name,
      Species_label = unname(
        species_short_labels[[
          species_name
        ]]
      ),
      Source = method_name,
      Is_occurrence = FALSE,
      stringsAsFactors = FALSE
    )
  }
}

main_plot_data <- do.call(
  rbind,
  main_plot_rows
)

rownames(
  main_plot_data
) <- NULL

main_plot_data$Species_label <- factor(
  main_plot_data$Species_label,
  levels = unname(
    species_short_labels[
      expected_species
    ]
  )
)

main_plot_data$Source <- factor(
  main_plot_data$Source,
  levels = source_order
)

write_csv_safely(
  main_plot_data,
  main_plot_data_file
)


# ============================================================
# Figure 1: PC1-PC2 reconstruction with PC3 colour
# ============================================================

pc3_limits <- range(
  main_plot_data$PC3[
    is.finite(
      main_plot_data$PC3
    )
  ]
)

main_figure <- ggplot(
  main_plot_data,
  aes(
    x = PC1,
    y = PC2,
    colour = PC3
  )
) +
  geom_point(
    size = 0.28,
    alpha = 0.52
  ) +
  facet_grid(
    Source ~ Species_label,
    scales = "fixed"
  ) +
  scale_colour_viridis_c(
    option = "D",
    limits = pc3_limits,
    name = "PC3"
  ) +
  labs(
    x = "PC1",
    y = "PC2"
  ) +
  theme_classic(
    base_size = 9.5
  ) +
  theme(
    strip.background = element_blank(),
    strip.text = element_text(
      face = "bold"
    ),
    legend.position = "bottom",
    panel.spacing = grid::unit(
      0.45,
      "lines"
    )
  )

save_plot_three_formats(
  plot_object = main_figure,
  pdf_file = main_figure_pdf,
  png_file = main_figure_png,
  tiff_file = main_figure_tiff,
  width = 15.5,
  height = 10.5
)


# ============================================================
# Figure 2: compact volume / centroid / cross-method agreement
# ============================================================

summary_volume_data <- volume_centroid_summary

summary_volume_data$Species_label <- factor(
  unname(
    species_short_labels[
      summary_volume_data$Species
    ]
  ),
  levels = unname(
    species_short_labels[
      expected_species
    ]
  )
)

summary_volume_data$Method <- factor(
  summary_volume_data$Method,
  levels = method_order
)


volume_plot <- ggplot(
  summary_volume_data,
  aes(
    x = Species_label,
    y = Hypervolume_volume,
    fill = Method
  )
) +
  geom_col(
    position = position_dodge(
      width = 0.82
    ),
    width = 0.74
  ) +
  scale_fill_manual(
    values = method_colours,
    drop = FALSE
  ) +
  labs(
    x = NULL,
    y = expression(
      "Hypervolume volume (PC units"^3*")"
    ),
    fill = NULL
  ) +
  theme_classic(
    base_size = 10
  ) +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(
      angle = 35,
      hjust = 1
    )
  )


centroid_plot <- ggplot(
  summary_volume_data,
  aes(
    x = Species_label,
    y = Centroid_displacement_from_occurrence,
    colour = Method,
    group = Method
  )
) +
  geom_point(
    size = 2.3,
    position = position_dodge(
      width = 0.45
    )
  ) +
  scale_colour_manual(
    values = method_colours,
    drop = FALSE
  ) +
  labs(
    x = NULL,
    y = "Centroid displacement from occurrence cloud",
    colour = NULL
  ) +
  theme_classic(
    base_size = 10
  ) +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(
      angle = 35,
      hjust = 1
    )
  )


cross_method_plot_data <- cross_method_overlap[
  cross_method_overlap$Success,
  ,
  drop = FALSE
]

cross_method_plot_data$Species_label <- factor(
  unname(
    species_short_labels[
      cross_method_plot_data$Species
    ]
  ),
  levels = unname(
    species_short_labels[
      expected_species
    ]
  )
)

cross_method_plot_data$Method_pair <- factor(
  cross_method_plot_data$Method_pair,
  levels = c(
    "QPH vs Gaussian KDE",
    "QPH vs SVM",
    "Gaussian KDE vs SVM"
  )
)

write_csv_safely(
  cross_method_plot_data,
  cross_method_plot_data_file
)


cross_overlap_plot <- ggplot(
  cross_method_plot_data,
  aes(
    x = Species_label,
    y = Jaccard_similarity,
    group = Method_pair,
    linetype = Method_pair,
    shape = Method_pair
  )
) +
  geom_line(
    linewidth = 0.65,
    colour = "#4A4A4A"
  ) +
  geom_point(
    size = 2.2,
    colour = "#4A4A4A"
  ) +
  scale_y_continuous(
    limits = c(
      0,
      1
    )
  ) +
  labs(
    x = NULL,
    y = "Cross-method Jaccard similarity",
    linetype = NULL,
    shape = NULL
  ) +
  theme_classic(
    base_size = 10
  ) +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(
      angle = 35,
      hjust = 1
    )
  )


summary_figure <- (
  volume_plot /
    centroid_plot /
    cross_overlap_plot
) +
  patchwork::plot_layout(
    guides = "collect"
  ) +
  patchwork::plot_annotation(
    tag_levels = "A"
  ) &
  theme(
    legend.position = "bottom"
  )

ggplot2::ggsave(
  filename = summary_figure_pdf,
  plot = summary_figure,
  width = 10.8,
  height = 10.8,
  units = "in",
  bg = "white"
)

ggplot2::ggsave(
  filename = summary_figure_png,
  plot = summary_figure,
  width = 10.8,
  height = 10.8,
  units = "in",
  dpi = 350,
  bg = "white"
)


# ============================================================
# Figure 3: between-species overlap heatmaps
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
            ) &
            between_species_overlap$Success,
          ,
          drop = FALSE
        ]

        jaccard_value <- if (
          nrow(
            row
          ) == 1L
        ) {
          row$Jaccard_similarity[[1L]]
        } else {
          NA_real_
        }
      }

      heatmap_index <- heatmap_index + 1L

      heatmap_rows[[
        heatmap_index
      ]] <- data.frame(
        Method = method_name,
        Species_1 = species_1,
        Species_2 = species_2,
        Species_1_label = unname(
          species_short_labels[[
            species_1
          ]]
        ),
        Species_2_label = unname(
          species_short_labels[[
            species_2
          ]]
        ),
        Jaccard_similarity = jaccard_value,
        stringsAsFactors = FALSE
      )
    }
  }
}

between_species_heatmap_data <- do.call(
  rbind,
  heatmap_rows
)

between_species_heatmap_data$Method <- factor(
  between_species_heatmap_data$Method,
  levels = method_order
)

between_species_heatmap_data$Species_1_label <- factor(
  between_species_heatmap_data$Species_1_label,
  levels = unname(
    species_short_labels[
      expected_species
    ]
  )
)

between_species_heatmap_data$Species_2_label <- factor(
  between_species_heatmap_data$Species_2_label,
  levels = rev(
    unname(
      species_short_labels[
        expected_species
      ]
    )
  )
)

write_csv_safely(
  between_species_heatmap_data,
  between_species_heatmap_data_file
)


heatmap_figure <- ggplot(
  between_species_heatmap_data,
  aes(
    x = Species_1_label,
    y = Species_2_label,
    fill = Jaccard_similarity
  )
) +
  geom_tile(
    colour = "white",
    linewidth = 0.3
  ) +
  geom_text(
    aes(
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
  facet_wrap(
    ~Method,
    nrow = 1
  ) +
  scale_fill_viridis_c(
    limits = c(
      0,
      1
    ),
    name = "Jaccard"
  ) +
  labs(
    x = NULL,
    y = NULL
  ) +
  theme_classic(
    base_size = 9.5
  ) +
  theme(
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    ),
    strip.background = element_blank(),
    strip.text = element_text(
      face = "bold"
    ),
    legend.position = "bottom"
  )

ggplot2::ggsave(
  filename = heatmap_figure_pdf,
  plot = heatmap_figure,
  width = 12.0,
  height = 4.8,
  units = "in",
  bg = "white"
)

ggplot2::ggsave(
  filename = heatmap_figure_png,
  plot = heatmap_figure,
  width = 12.0,
  height = 4.8,
  units = "in",
  dpi = 350,
  bg = "white"
)


# ============================================================
# Final result object
# ============================================================

run_metadata <- list(
  script = "20_Acacia_Environmental_Geometry.R",
  analysis_settings_hash = analysis_settings_hash,
  locked_design_hash = locked_design_hash,
  baseline_analysis_hash = baseline_analysis_hash,
  overlap_num_points_max = overlap_num_points_max,
  overlap_distance_factor = overlap_distance_factor,
  overlap_master_seed = master_seed,
  between_species_overlap_comparisons = nrow(
    between_species_overlap
  ),
  cross_method_overlap_comparisons = nrow(
    cross_method_overlap
  ),
  overlap_failures = nrow(
    overlap_failures
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
  model_validation = model_validation,
  volume_centroid_summary = volume_centroid_summary,
  niche_breadth_rankings = volume_rankings,
  within_species_volume_ratios = volume_ratios,
  between_species_overlap = between_species_overlap,
  cross_method_overlap = cross_method_overlap,
  between_species_centroid_distances = (
    between_species_centroid_distances
  ),
  cross_method_centroid_distances = (
    cross_method_centroid_distances
  ),
  method_disagreement_summary = method_disagreement_summary,
  overlap_failures = overlap_failures,
  figure_data = list(
    environmental_hypervolumes = main_plot_data,
    cross_method_overlap = cross_method_plot_data,
    between_species_heatmap = between_species_heatmap_data
  )
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
  "ACACIA ENVIRONMENTAL GEOMETRY",
  "=============================",
  "",
  "Interpretation:",
  "  No analytical or independently known true empirical niche is assumed.",
  "  Hypervolume volume is estimator-specific inferred niche breadth.",
  "  Occurrence centroids are empirical positional references, not truth.",
  "  Jaccard/Sorensen values quantify agreement among reconstructions.",
  "",
  "Inputs:",
  "  Script 18 locked occurrence-derived PC1-PC3 matrices.",
  "  Script 19 revised baseline QPH, Gaussian KDE and SVM models.",
  "",
  "Revised QPH:",
  "  sqrt-NB isotropic bandwidth",
  "  q = 0.99",
  "  samples.per.point = 100",
  "  sd.count = 3",
  "",
  "Gaussian KDE:",
  "  independent Silverman bandwidth",
  "  probability quantile = 0.95",
  "  samples.per.point = 100",
  "  sd.count = 3",
  "",
  "SVM:",
  "  nu = 0.01",
  "  gamma = 0.50",
  "  scale.factor = 1",
  "",
  "Set operations:",
  paste0(
    "  num.points.max = ",
    overlap_num_points_max
  ),
  paste0(
    "  distance.factor = ",
    overlap_distance_factor
  ),
  paste0(
    "  master seed = ",
    master_seed
  ),
  "",
  "Outputs include:",
  "  hypervolume volume and occurrence-centroid displacement",
  "  niche-breadth rankings",
  "  within-species method volume ratios",
  "  interspecific overlap separately within each estimator",
  "  cross-method overlap within species",
  "  interspecific centroid distances",
  "  cross-method centroid distances",
  "  method-disagreement summaries",
  "",
  paste0(
    "Overlap failures: ",
    nrow(
      overlap_failures
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
    "Script-20 analysis settings hash: ",
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
  "20_Acacia_Environmental_Geometry.R complete."
)

message(
  "\nHypervolume volumes, ranks and centroid displacement:"
)

print(
  volume_centroid_summary[
    ,
    c(
      "Species",
      "Method",
      "Hypervolume_volume",
      "Niche_breadth_rank_within_method",
      "Centroid_displacement_from_occurrence"
    ),
    drop = FALSE
  ],
  digits = 6,
  row.names = FALSE
)

message(
  "\nBetween-species overlap success:"
)

print(
  with(
    between_species_overlap,
    table(
      Method,
      Success,
      useNA = "ifany"
    )
  )
)

message(
  "\nCross-method overlap success:"
)

print(
  with(
    cross_method_overlap,
    table(
      Success,
      useNA = "ifany"
    )
  )
)

message(
  "\nFinal geometry object:\n  ",
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
# Require complete overlap analysis before Script 21
# ============================================================

if (
  nrow(
    overlap_failures
  ) > 0L
) {
  stop(
    "One or more Acacia overlap calculations failed. Successful calculations ",
    "and the checkpoint were retained. Re-run Script 20 after addressing the ",
    "failure(s) before treating the geometry branch as complete.\nFailure table:\n  ",
    normalizePath(
      overlap_failure_file,
      winslash = "/",
      mustWork = FALSE
    )
  )
}
