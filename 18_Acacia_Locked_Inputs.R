# ============================================================
# 18_Acacia_Locked_Inputs.R
# ============================================================
#
# PURPOSE
# -------
# Lock and validate the empirical Acacia inputs that were already created by
# the completed Acacia data-preparation workflow.
#


rm(list = ls())
gc()


# ============================================================
# Project and source settings
# ============================================================

# Run from the repository's root folder.
project_directory <- "."

analysis_root_directory <- file.path(
  project_directory,
  "Results",
  "Acacia_sqrtNB_q099"
)

output_directory <- file.path(
  analysis_root_directory,
  "00_Locked_Inputs"
)

dir.create(
  output_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

# Optional manual override. Leave as NA_character_ for automatic discovery.
source_archive_override <- NA_character_

# Protect an existing locked archive from accidental replacement.
overwrite_existing_locked_archive <- FALSE


# ============================================================
# Locked species / PCA definitions
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

expected_number_environmental_variables <- 20L

expected_source_dataset <- "hypervolume::acacia_pinus"

expected_duplicate_removal_setting <- FALSE

numeric_tolerance <- 1e-8


# ============================================================
# Output files
# ============================================================

locked_archive_file <- file.path(
  output_directory,
  "acacia_empirical_inputs_authoritative_LOCKED.rds"
)

locked_settings_file <- file.path(
  output_directory,
  "locked_input_settings.rds"
)

locked_species_pca_file <- file.path(
  output_directory,
  "acacia_species_pca_matrices_LOCKED.rds"
)

occurrence_summary_file <- file.path(
  output_directory,
  "acacia_locked_occurrence_summary.csv"
)

pca_variance_file <- file.path(
  output_directory,
  "acacia_locked_pca_variance_explained.csv"
)

pca_species_summary_file <- file.path(
  output_directory,
  "acacia_locked_species_pca_summary.csv"
)

validation_file <- file.path(
  output_directory,
  "acacia_locked_input_validation.csv"
)

manifest_file <- file.path(
  output_directory,
  "acacia_locked_input_manifest.csv"
)

notes_file <- file.path(
  output_directory,
  "ACACIA_LOCKED_INPUT_NOTES.txt"
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


validate_finite_numeric_matrix <- function(
    x,
    object_name
) {

  x <- as.matrix(x)
  storage.mode(x) <- "double"

  if (nrow(x) < 1L) {
    stop(
      object_name,
      " has no rows."
    )
  }

  if (ncol(x) < 1L) {
    stop(
      object_name,
      " has no columns."
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


add_validation <- local({

  rows <- list()
  index <- 0L

  function(
      check_name = NULL,
      passed = NULL,
      observed = NULL,
      expected = NULL,
      return_table = FALSE
  ) {

    if (isTRUE(return_table)) {

      if (length(rows) == 0L) {
        return(
          data.frame(
            Check = character(0),
            Passed = logical(0),
            Observed = character(0),
            Expected = character(0),
            stringsAsFactors = FALSE
          )
        )
      }

      output <- do.call(
        rbind,
        rows
      )

      rownames(output) <- NULL
      return(output)
    }

    index <<- index + 1L

    rows[[index]] <<- data.frame(
      Check = as.character(check_name),
      Passed = isTRUE(passed),
      Observed = paste(
        as.character(observed),
        collapse = "; "
      ),
      Expected = paste(
        as.character(expected),
        collapse = "; "
      ),
      stringsAsFactors = FALSE
    )

    invisible(NULL)
  }
})


# ============================================================
# Locate the existing authoritative Acacia archive
# ============================================================

legacy_project_candidates <- unique(
  c(
    file.path(
      dirname(project_directory),
      "Quantum Paper"
    ),
    path.expand("~/Desktop/Quantum Paper"),
    "C:/Users/r02jt24/Desktop/Quantum Paper",
    project_directory
  )
)

automatic_source_candidates <- unique(
  unlist(
    lapply(
      legacy_project_candidates,
      function(root_directory) {
        c(
          file.path(
            root_directory,
            "Empirical Results",
            "acacia_empirical_analysis",
            "01_Acacia_data_preparation",
            "acacia_empirical_inputs_authoritative.rds"
          ),
          file.path(
            root_directory,
            "Results",
            "acacia_empirical_analysis",
            "01_Acacia_data_preparation",
            "acacia_empirical_inputs_authoritative.rds"
          )
        )
      }
    ),
    use.names = FALSE
  )
)

# The already locked file is a valid fallback for a clean restart after the
# legacy source directory has been archived or removed.
automatic_source_candidates <- unique(
  c(
    automatic_source_candidates,
    locked_archive_file
  )
)

if (
  !is.na(source_archive_override) &&
    nzchar(source_archive_override)
) {

  candidate_source_archives <- source_archive_override

} else {

  candidate_source_archives <- automatic_source_candidates
}

existing_source_archives <- unique(
  candidate_source_archives[
    file.exists(candidate_source_archives)
  ]
)

if (length(existing_source_archives) == 0L) {
  stop(
    "Could not locate the completed authoritative Acacia archive.\n",
    "Expected a file named acacia_empirical_inputs_authoritative.rds in the ",
    "completed empirical data-preparation folder.\n",
    "Set source_archive_override near the top of this script to its exact path."
  )
}

source_md5_values <- vapply(
  existing_source_archives,
  safe_md5,
  character(1)
)

unique_source_md5 <- unique(
  source_md5_values[
    !is.na(source_md5_values)
  ]
)

if (length(unique_source_md5) > 1L) {

  conflict_table <- data.frame(
    Path = existing_source_archives,
    MD5 = source_md5_values,
    stringsAsFactors = FALSE
  )

  print(
    conflict_table,
    row.names = FALSE
  )

  stop(
    "Multiple candidate Acacia authoritative archives were found with ",
    "different MD5 hashes. Set source_archive_override explicitly rather ",
    "than allowing Script 18 to choose between scientifically different files."
  )
}

# Prefer a source outside the new locked branch when one is available.
outside_locked_branch <- existing_source_archives[
  normalizePath(
    existing_source_archives,
    winslash = "/",
    mustWork = TRUE
  ) !=
    normalizePath(
      locked_archive_file,
      winslash = "/",
      mustWork = FALSE
    )
]

if (length(outside_locked_branch) > 0L) {
  source_archive_file <- outside_locked_branch[[1L]]
} else {
  source_archive_file <- existing_source_archives[[1L]]
}

source_archive_file <- normalizePath(
  source_archive_file,
  winslash = "/",
  mustWork = TRUE
)

source_archive_md5 <- safe_md5(
  source_archive_file
)

message(
  "Authoritative Acacia source archive:\n  ",
  source_archive_file
)

message(
  "Source archive MD5: ",
  source_archive_md5
)


# ============================================================
# Load the source archive for validation only
# ============================================================

authoritative_inputs <- readRDS(
  source_archive_file
)

required_archive_components <- c(
  "metadata",
  "settings",
  "raster_manifest",
  "cleaning_audit",
  "cleaning_summary",
  "final_occurrence_metadata",
  "environmental_values_raw",
  "environmental_values_scaled",
  "shared_pca",
  "pca_variance_explained",
  "pca_scores_retained",
  "species_pca_matrices",
  "quality_control"
)

missing_archive_components <- setdiff(
  required_archive_components,
  names(authoritative_inputs)
)

add_validation(
  check_name = "Required archive components present",
  passed = length(missing_archive_components) == 0L,
  observed = if (
    length(missing_archive_components) == 0L
  ) {
    "all present"
  } else {
    paste(
      missing_archive_components,
      collapse = ", "
    )
  },
  expected = "all required components"
)

if (length(missing_archive_components) > 0L) {
  stop(
    "The authoritative Acacia archive is missing required component(s): ",
    paste(
      missing_archive_components,
      collapse = ", "
    )
  )
}


# ============================================================
# Validate archive metadata and locked design
# ============================================================

metadata <- authoritative_inputs$metadata
settings <- authoritative_inputs$settings
quality_control <- authoritative_inputs$quality_control

metadata_species <- as.character(
  metadata$selected_species
)

settings_species <- as.character(
  settings$selected_species
)

add_validation(
  "Metadata species order",
  identical(
    metadata_species,
    expected_species
  ),
  metadata_species,
  expected_species
)

add_validation(
  "Settings species order",
  identical(
    settings_species,
    expected_species
  ),
  settings_species,
  expected_species
)

if (
  !identical(
    metadata_species,
    expected_species
  ) ||
    !identical(
      settings_species,
      expected_species
    )
) {
  stop(
    "The authoritative archive does not contain the five locked Acacia ",
    "species in the expected order."
  )
}


metadata_species_codes <- metadata$species_codes

add_validation(
  "Species codes",
  identical(
    unname(
      as.character(
        metadata_species_codes[
          expected_species
        ]
      )
    ),
    unname(
      expected_species_codes
    )
  ),
  metadata_species_codes[
    expected_species
  ],
  expected_species_codes
)

if (
  !identical(
    unname(
      as.character(
        metadata_species_codes[
          expected_species
        ]
      )
    ),
    unname(
      expected_species_codes
    )
  )
) {
  stop(
    "Species codes in the authoritative archive differ from the locked design."
  )
}


add_validation(
  "Source dataset",
  identical(
    as.character(
      metadata$source_dataset
    ),
    expected_source_dataset
  ),
  metadata$source_dataset,
  expected_source_dataset
)

if (
  !identical(
    as.character(
      metadata$source_dataset
    ),
    expected_source_dataset
  )
) {
  stop(
    "Unexpected empirical source dataset: ",
    as.character(
      metadata$source_dataset
    )
  )
}


add_validation(
  "Number of environmental variables",
  identical(
    as.integer(
      metadata$number_of_environmental_variables
    ),
    expected_number_environmental_variables
  ),
  metadata$number_of_environmental_variables,
  expected_number_environmental_variables
)

if (
  as.integer(
    metadata$number_of_environmental_variables
  ) !=
    expected_number_environmental_variables
) {
  stop(
    "Expected exactly 20 environmental variables."
  )
}


add_validation(
  "Number of retained PCs",
  identical(
    as.integer(
      metadata$number_of_retained_principal_components
    ),
    3L
  ),
  metadata$number_of_retained_principal_components,
  3L
)

add_validation(
  "Retained PC names",
  identical(
    as.character(
      metadata$retained_principal_components
    ),
    expected_pc_names
  ),
  metadata$retained_principal_components,
  expected_pc_names
)

if (
  as.integer(
    metadata$number_of_retained_principal_components
  ) !=
    3L ||
    !identical(
      as.character(
        metadata$retained_principal_components
      ),
      expected_pc_names
    )
) {
  stop(
    "The empirical archive must retain exactly PC1, PC2 and PC3."
  )
}


duplicate_setting <- isTRUE(
  settings$remove_exact_coordinate_duplicates_within_species
)

add_validation(
  "Exact coordinate duplicates retained",
  identical(
    duplicate_setting,
    expected_duplicate_removal_setting
  ),
  paste0(
    "remove_duplicates=",
    duplicate_setting
  ),
  "remove_duplicates=FALSE"
)

if (
  !identical(
    duplicate_setting,
    expected_duplicate_removal_setting
  )
) {
  stop(
    "This locked empirical design requires exact within-species coordinate ",
    "duplicates to remain retained, matching the completed preparation analysis."
  )
}


# ============================================================
# Validate occurrence metadata
# ============================================================

occurrence_metadata <- authoritative_inputs$final_occurrence_metadata

required_occurrence_columns <- c(
  "occurrence_id",
  "source_row_id",
  "species",
  "species_code",
  "longitude",
  "latitude"
)

missing_occurrence_columns <- setdiff(
  required_occurrence_columns,
  names(
    occurrence_metadata
  )
)

add_validation(
  "Required occurrence metadata columns",
  length(missing_occurrence_columns) == 0L,
  if (
    length(missing_occurrence_columns) == 0L
  ) {
    "all present"
  } else {
    paste(
      missing_occurrence_columns,
      collapse = ", "
    )
  },
  paste(
    required_occurrence_columns,
    collapse = ", "
  )
)

if (length(missing_occurrence_columns) > 0L) {
  stop(
    "final_occurrence_metadata is missing required column(s): ",
    paste(
      missing_occurrence_columns,
      collapse = ", "
    )
  )
}


occurrence_species <- as.character(
  occurrence_metadata$species
)

unexpected_occurrence_species <- setdiff(
  unique(
    occurrence_species
  ),
  expected_species
)

missing_occurrence_species <- setdiff(
  expected_species,
  unique(
    occurrence_species
  )
)

add_validation(
  "Occurrence species set",
  length(unexpected_occurrence_species) == 0L &&
    length(missing_occurrence_species) == 0L,
  unique(
    occurrence_species
  ),
  expected_species
)

if (
  length(unexpected_occurrence_species) > 0L ||
    length(missing_occurrence_species) > 0L
) {
  stop(
    "Occurrence metadata species do not match the five locked species."
  )
}


if (
  any(
    duplicated(
      occurrence_metadata$occurrence_id
    )
  )
) {
  stop(
    "Occurrence IDs are not unique in final_occurrence_metadata."
  )
}

add_validation(
  "Occurrence IDs unique",
  TRUE,
  nrow(
    occurrence_metadata
  ),
  "one unique ID per retained record"
)


coordinate_matrix <- cbind(
  longitude = as.numeric(
    occurrence_metadata$longitude
  ),
  latitude = as.numeric(
    occurrence_metadata$latitude
  )
)

if (any(!is.finite(coordinate_matrix))) {
  stop(
    "Retained occurrence coordinates contain missing or non-finite values."
  )
}

add_validation(
  "Occurrence coordinates finite",
  TRUE,
  "all finite",
  "all finite"
)


calculated_species_counts <- table(
  factor(
    occurrence_species,
    levels = expected_species
  )
)

saved_species_counts <- quality_control$final_species_counts

if (is.null(saved_species_counts)) {
  stop(
    "quality_control$final_species_counts is missing."
  )
}

saved_species_counts <- saved_species_counts[
  expected_species
]

add_validation(
  "Occurrence counts match saved quality control",
  identical(
    as.integer(
      calculated_species_counts
    ),
    as.integer(
      saved_species_counts
    )
  ),
  paste(
    paste0(
      expected_species,
      "=",
      as.integer(
        calculated_species_counts
      )
    ),
    collapse = "; "
  ),
  paste(
    paste0(
      expected_species,
      "=",
      as.integer(
        saved_species_counts
      )
    ),
    collapse = "; "
  )
)

if (
  !identical(
    as.integer(
      calculated_species_counts
    ),
    as.integer(
      saved_species_counts
    )
  )
) {
  stop(
    "Occurrence counts do not match the archive quality-control counts."
  )
}


# ============================================================
# Validate environmental matrices and pooled PCA
# ============================================================

environmental_raw <- validate_finite_numeric_matrix(
  authoritative_inputs$environmental_values_raw,
  "environmental_values_raw"
)

environmental_scaled <- validate_finite_numeric_matrix(
  authoritative_inputs$environmental_values_scaled,
  "environmental_values_scaled"
)

if (
  nrow(
    environmental_raw
  ) !=
    nrow(
      occurrence_metadata
    ) ||
    nrow(
      environmental_scaled
    ) !=
      nrow(
        occurrence_metadata
      )
) {
  stop(
    "Environmental matrix row counts do not match retained occurrence count."
  )
}

if (
  ncol(
    environmental_raw
  ) !=
    expected_number_environmental_variables ||
    ncol(
      environmental_scaled
    ) !=
      expected_number_environmental_variables
) {
  stop(
    "Environmental matrices must contain exactly 20 variables."
  )
}

add_validation(
  "Environmental matrix dimensions",
  TRUE,
  paste0(
    nrow(
      environmental_raw
    ),
    " x ",
    ncol(
      environmental_raw
    )
  ),
  paste0(
    nrow(
      occurrence_metadata
    ),
    " x 20"
  )
)


scaled_means <- colMeans(
  environmental_scaled
)

scaled_sds <- apply(
  environmental_scaled,
  2L,
  stats::sd
)

maximum_scaled_mean <- max(
  abs(
    scaled_means
  )
)

maximum_scaled_sd_error <- max(
  abs(
    scaled_sds -
      1
  )
)

add_validation(
  "Saved scaled variables centred",
  is.finite(maximum_scaled_mean) &&
    maximum_scaled_mean <=
      numeric_tolerance,
  maximum_scaled_mean,
  paste0(
    "<= ",
    numeric_tolerance
  )
)

add_validation(
  "Saved scaled variables unit SD",
  is.finite(maximum_scaled_sd_error) &&
    maximum_scaled_sd_error <=
      numeric_tolerance,
  maximum_scaled_sd_error,
  paste0(
    "<= ",
    numeric_tolerance
  )
)

if (
  !is.finite(
    maximum_scaled_mean
  ) ||
    maximum_scaled_mean >
      numeric_tolerance ||
    !is.finite(
      maximum_scaled_sd_error
    ) ||
    maximum_scaled_sd_error >
      numeric_tolerance
) {
  stop(
    "Saved PCA-standardised environmental variables failed centring/scaling QA."
  )
}


shared_pca <- authoritative_inputs$shared_pca

if (!inherits(shared_pca, "prcomp")) {
  stop(
    "shared_pca is not a prcomp object."
  )
}

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
    "shared_pca is missing its centre, scale or rotation."
  )
}


predicted_pca_scores <- stats::predict(
  shared_pca,
  newdata = environmental_raw
)

saved_all_scores <- if (
  "pca_scores_all_components" %in%
    names(
      authoritative_inputs
    )
) {
  validate_finite_numeric_matrix(
    authoritative_inputs$pca_scores_all_components,
    "pca_scores_all_components"
  )
} else {
  validate_finite_numeric_matrix(
    shared_pca$x,
    "shared_pca$x"
  )
}

if (
  !identical(
    dim(
      predicted_pca_scores
    ),
    dim(
      saved_all_scores
    )
  )
) {
  stop(
    "Recalculated PCA score dimensions do not match saved scores."
  )
}

maximum_pca_reconstruction_difference <- max(
  abs(
    predicted_pca_scores -
      saved_all_scores
  )
)

add_validation(
  "PCA score reconstruction",
  is.finite(
    maximum_pca_reconstruction_difference
  ) &&
    maximum_pca_reconstruction_difference <=
      numeric_tolerance,
  maximum_pca_reconstruction_difference,
  paste0(
    "<= ",
    numeric_tolerance
  )
)

if (
  !is.finite(
    maximum_pca_reconstruction_difference
  ) ||
    maximum_pca_reconstruction_difference >
      numeric_tolerance
) {
  stop(
    "The saved pooled PCA cannot reproduce the saved PCA scores."
  )
}


retained_scores <- validate_finite_numeric_matrix(
  authoritative_inputs$pca_scores_retained,
  "pca_scores_retained"
)

if (
  nrow(
    retained_scores
  ) !=
    nrow(
      occurrence_metadata
    ) ||
    ncol(
      retained_scores
    ) !=
      3L
) {
  stop(
    "pca_scores_retained must have one row per retained occurrence and ",
    "exactly three columns."
  )
}

if (
  !identical(
    colnames(
      retained_scores
    ),
    expected_pc_names
  )
) {
  stop(
    "pca_scores_retained columns must be exactly PC1, PC2 and PC3."
  )
}

retained_from_prediction <- predicted_pca_scores[
  ,
  seq_len(
    3L
  ),
  drop = FALSE
]

colnames(
  retained_from_prediction
) <- expected_pc_names

maximum_retained_score_difference <- max(
  abs(
    retained_scores -
      retained_from_prediction
  )
)

add_validation(
  "Retained PC1-PC3 reproduce pooled PCA prediction",
  is.finite(
    maximum_retained_score_difference
  ) &&
    maximum_retained_score_difference <=
      numeric_tolerance,
  maximum_retained_score_difference,
  paste0(
    "<= ",
    numeric_tolerance
  )
)

if (
  !is.finite(
    maximum_retained_score_difference
  ) ||
    maximum_retained_score_difference >
      numeric_tolerance
) {
  stop(
    "Saved PC1-PC3 scores differ from the pooled PCA reconstruction."
  )
}


# ============================================================
# Validate species-specific PC1-PC3 matrices
# ============================================================

species_pca_matrices <- authoritative_inputs$species_pca_matrices

if (
  !identical(
    names(
      species_pca_matrices
    ),
    expected_species
  )
) {
  stop(
    "species_pca_matrices are not stored in the locked species order."
  )
}

species_matrix_hashes <- setNames(
  character(
    length(
      expected_species
    )
  ),
  expected_species
)

species_matrix_maximum_difference <- setNames(
  numeric(
    length(
      expected_species
    )
  ),
  expected_species
)

for (
  species_name in expected_species
) {

  current_matrix <- validate_finite_numeric_matrix(
    species_pca_matrices[[species_name]],
    paste0(
      species_name,
      " species_pca_matrix"
    )
  )

  if (
    ncol(
      current_matrix
    ) !=
      3L ||
      !identical(
        colnames(
          current_matrix
        ),
        expected_pc_names
      )
  ) {
    stop(
      species_name,
      " species PCA matrix must have columns PC1, PC2 and PC3."
    )
  }

  species_rows <- occurrence_species ==
    species_name

  expected_matrix <- retained_scores[
    species_rows,
    ,
    drop = FALSE
  ]

  if (
    nrow(
      current_matrix
    ) !=
      sum(
        species_rows
      )
  ) {
    stop(
      "Species PCA row count mismatch for ",
      species_name,
      "."
    )
  }

  current_difference <- max(
    abs(
      current_matrix -
        expected_matrix
    )
  )

  species_matrix_maximum_difference[[
    species_name
  ]] <- current_difference

  if (
    !is.finite(
      current_difference
    ) ||
      current_difference >
        numeric_tolerance
  ) {
    stop(
      "Species-specific PCA matrix differs from the corresponding rows of ",
      "pca_scores_retained for ",
      species_name,
      "."
    )
  }

  if (
    !is.null(
      rownames(
        current_matrix
      )
    ) &&
      !identical(
        rownames(
          current_matrix
        ),
        as.character(
          occurrence_metadata$occurrence_id[
            species_rows
          ]
        )
      )
  ) {
    stop(
      "Species-specific PCA matrix row names do not match occurrence IDs for ",
      species_name,
      "."
    )
  }

  species_matrix_hashes[[
    species_name
  ]] <- hash_r_object(
    current_matrix
  )
}

add_validation(
  "Species-specific PC matrices exactly match pooled retained scores",
  all(
    species_matrix_maximum_difference <=
      numeric_tolerance
  ),
  paste(
    paste0(
      names(
        species_matrix_maximum_difference
      ),
      "=",
      format(
        species_matrix_maximum_difference,
        scientific = TRUE
      )
    ),
    collapse = "; "
  ),
  paste0(
    "all <= ",
    numeric_tolerance
  )
)


# ============================================================
# Validate PCA variance table
# ============================================================

pca_variance <- authoritative_inputs$pca_variance_explained

required_pca_variance_columns <- c(
  "Principal_component",
  "Percent_variance",
  "Cumulative_percent"
)

missing_pca_variance_columns <- setdiff(
  required_pca_variance_columns,
  names(
    pca_variance
  )
)

if (length(missing_pca_variance_columns) > 0L) {
  stop(
    "pca_variance_explained is missing required column(s): ",
    paste(
      missing_pca_variance_columns,
      collapse = ", "
    )
  )
}

if (
  nrow(
    pca_variance
  ) <
    3L ||
    !identical(
      as.character(
        pca_variance$Principal_component[
          1:3
        ]
      ),
      expected_pc_names
    )
) {
  stop(
    "The first three rows of pca_variance_explained must be PC1-PC3."
  )
}

cumulative_pc1_pc3 <- as.numeric(
  pca_variance$Cumulative_percent[[3L]]
)

add_validation(
  "PC1-PC3 cumulative variance finite",
  is.finite(
    cumulative_pc1_pc3
  ),
  cumulative_pc1_pc3,
  "finite percentage"
)

if (!is.finite(cumulative_pc1_pc3)) {
  stop(
    "PC1-PC3 cumulative variance explained is non-finite."
  )
}


# ============================================================
# Build compact locked summaries
# ============================================================

occurrence_summary <- data.frame(
  Species = expected_species,
  Species_code = unname(
    expected_species_codes
  ),
  Final_occurrence_count = as.integer(
    calculated_species_counts
  ),
  Exact_coordinate_duplicate_members = vapply(
    expected_species,
    function(species_name) {

      species_rows <- occurrence_species ==
        species_name

      if (
        "exact_coordinate_duplicate_member" %in%
          names(
            occurrence_metadata
          )
      ) {
        sum(
          occurrence_metadata$exact_coordinate_duplicate_member[
            species_rows
          ],
          na.rm = TRUE
        )
      } else {
        NA_integer_
      }
    },
    integer(1)
  ),
  Exact_environment_duplicate_members = vapply(
    expected_species,
    function(species_name) {

      species_rows <- occurrence_species ==
        species_name

      if (
        "exact_environment_duplicate_member" %in%
          names(
            occurrence_metadata
          )
      ) {
        sum(
          occurrence_metadata$exact_environment_duplicate_member[
            species_rows
          ],
          na.rm = TRUE
        )
      } else {
        NA_integer_
      }
    },
    integer(1)
  ),
  Species_PC_matrix_hash = unname(
    species_matrix_hashes[
      expected_species
    ]
  ),
  stringsAsFactors = FALSE
)

write_csv_safely(
  occurrence_summary,
  occurrence_summary_file
)


write_csv_safely(
  pca_variance,
  pca_variance_file
)


species_pca_summary <- if (
  "species_pca_summary" %in%
    names(
      authoritative_inputs
    )
) {

  authoritative_inputs$species_pca_summary

} else {

  summary_rows <- list()
  summary_index <- 0L

  for (
    species_name in expected_species
  ) {

    current_matrix <- species_pca_matrices[[
      species_name
    ]]

    for (
      pc_name in expected_pc_names
    ) {

      summary_index <- summary_index + 1L

      values <- current_matrix[
        ,
        pc_name
      ]

      summary_rows[[
        summary_index
      ]] <- data.frame(
        Species = species_name,
        Principal_component = pc_name,
        N = length(
          values
        ),
        Mean = mean(
          values
        ),
        SD = stats::sd(
          values
        ),
        Minimum = min(
          values
        ),
        Median = stats::median(
          values
        ),
        Maximum = max(
          values
        ),
        stringsAsFactors = FALSE
      )
    }
  }

  do.call(
    rbind,
    summary_rows
  )
}

write_csv_safely(
  species_pca_summary,
  pca_species_summary_file
)


# ============================================================
# Create stable scientific-design hash
# ============================================================

scientific_design_object <- list(
  design_name = "Acacia empirical locked inputs for revised QPH analysis",
  source_dataset = metadata$source_dataset,
  selected_species = expected_species,
  species_codes = expected_species_codes,
  pca_scope = metadata$pca_scope,
  environmental_variables = metadata$environmental_variables,
  extraction_method = metadata$extraction_method,
  remove_exact_coordinate_duplicates_within_species = (
    settings$remove_exact_coordinate_duplicates_within_species
  ),
  retained_principal_components = expected_pc_names,
  final_occurrence_metadata = occurrence_metadata,
  environmental_values_raw = environmental_raw,
  shared_pca = shared_pca,
  pca_scores_retained = retained_scores,
  species_pca_matrices = species_pca_matrices
)

locked_design_hash <- hash_r_object(
  scientific_design_object
)

species_pca_collection_hash <- hash_r_object(
  species_pca_matrices
)


# ============================================================
# Copy the source archive byte-for-byte into the revised branch
# ============================================================

source_is_locked_file <- identical(
  normalizePath(
    source_archive_file,
    winslash = "/",
    mustWork = TRUE
  ),
  normalizePath(
    locked_archive_file,
    winslash = "/",
    mustWork = FALSE
  )
)

if (!source_is_locked_file) {

  if (file.exists(locked_archive_file)) {

    existing_locked_md5 <- safe_md5(
      locked_archive_file
    )

    if (
      identical(
        existing_locked_md5,
        source_archive_md5
      )
    ) {

      message(
        "Existing locked archive already matches the source MD5; reusing it."
      )

    } else if (
      isTRUE(
        overwrite_existing_locked_archive
      )
    ) {

      copied <- file.copy(
        from = source_archive_file,
        to = locked_archive_file,
        overwrite = TRUE,
        copy.mode = TRUE,
        copy.date = TRUE
      )

      if (!isTRUE(copied)) {
        stop(
          "Failed to overwrite the locked archive."
        )
      }

    } else {

      stop(
        "A locked Acacia archive already exists but its MD5 differs from the ",
        "selected source archive.\nExisting locked MD5: ",
        existing_locked_md5,
        "\nSource MD5: ",
        source_archive_md5,
        "\nThe existing locked archive was NOT replaced. Resolve the discrepancy ",
        "or deliberately set overwrite_existing_locked_archive <- TRUE."
      )
    }

  } else {

    copied <- file.copy(
      from = source_archive_file,
      to = locked_archive_file,
      overwrite = FALSE,
      copy.mode = TRUE,
      copy.date = TRUE
    )

    if (!isTRUE(copied)) {
      stop(
        "Failed to create the byte-for-byte locked Acacia archive."
      )
    }
  }
}

if (!file.exists(locked_archive_file)) {
  stop(
    "Locked archive was not created successfully."
  )
}

locked_archive_md5 <- safe_md5(
  locked_archive_file
)

add_validation(
  "Locked archive byte-for-byte MD5 match",
  identical(
    locked_archive_md5,
    source_archive_md5
  ),
  locked_archive_md5,
  source_archive_md5
)

if (
  !identical(
    locked_archive_md5,
    source_archive_md5
  )
) {
  stop(
    "The locked archive MD5 does not match the source archive MD5."
  )
}


# ============================================================
# Reload locked copy and verify scientific identity
# ============================================================

locked_inputs <- readRDS(
  locked_archive_file
)

locked_scientific_identity <- list(
  selected_species = locked_inputs$metadata$selected_species,
  final_occurrence_metadata = locked_inputs$final_occurrence_metadata,
  environmental_values_raw = locked_inputs$environmental_values_raw,
  shared_pca = locked_inputs$shared_pca,
  pca_scores_retained = locked_inputs$pca_scores_retained,
  species_pca_matrices = locked_inputs$species_pca_matrices
)

source_scientific_identity <- list(
  selected_species = authoritative_inputs$metadata$selected_species,
  final_occurrence_metadata = authoritative_inputs$final_occurrence_metadata,
  environmental_values_raw = authoritative_inputs$environmental_values_raw,
  shared_pca = authoritative_inputs$shared_pca,
  pca_scores_retained = authoritative_inputs$pca_scores_retained,
  species_pca_matrices = authoritative_inputs$species_pca_matrices
)

locked_identity_hash <- hash_r_object(
  locked_scientific_identity
)

source_identity_hash <- hash_r_object(
  source_scientific_identity
)

add_validation(
  "Reloaded locked scientific identity",
  identical(
    locked_identity_hash,
    source_identity_hash
  ),
  locked_identity_hash,
  source_identity_hash
)

if (
  !identical(
    locked_identity_hash,
    source_identity_hash
  )
) {
  stop(
    "Reloaded locked archive failed scientific-identity QA."
  )
}


# ============================================================
# Save convenience species matrices and lock settings
# ============================================================

saveRDS(
  species_pca_matrices,
  locked_species_pca_file,
  version = 3
)

locked_species_pca_file_md5 <- safe_md5(
  locked_species_pca_file
)


locked_settings <- list(
  script = "18_Acacia_Locked_Inputs.R",
  analysis_branch = "Acacia_sqrtNB_q099",
  locked_design_hash = locked_design_hash,
  source_archive_md5 = source_archive_md5,
  locked_archive_md5 = locked_archive_md5,
  species_pca_collection_hash = species_pca_collection_hash,
  species_pca_file_md5 = locked_species_pca_file_md5,
  source_archive_path_used = source_archive_file,
  locked_archive_path = normalizePath(
    locked_archive_file,
    winslash = "/",
    mustWork = TRUE
  ),
  selected_species = expected_species,
  species_codes = expected_species_codes,
  final_species_counts = as.integer(
    calculated_species_counts
  ),
  final_species_counts_named = stats::setNames(
    as.integer(
      calculated_species_counts
    ),
    expected_species
  ),
  environmental_variables = metadata$environmental_variables,
  number_of_environmental_variables = (
    expected_number_environmental_variables
  ),
  pca_scope = metadata$pca_scope,
  retained_pcs = expected_pc_names,
  cumulative_variance_PC1_PC3_percent = cumulative_pc1_pc3,
  extraction_method = settings$extraction_method,
  remove_exact_coordinate_duplicates_within_species = (
    settings$remove_exact_coordinate_duplicates_within_species
  ),
  maximum_pca_reconstruction_difference = (
    maximum_pca_reconstruction_difference
  ),
  maximum_retained_score_difference = (
    maximum_retained_score_difference
  ),
  maximum_scaled_mean_absolute = maximum_scaled_mean,
  maximum_scaled_sd_error = maximum_scaled_sd_error,
  qph_parameter_dependence = FALSE,
  note = paste(
    "No ecological input was regenerated. Revised QPH parameters begin",
    "in Script 19."
  )
)

saveRDS(
  locked_settings,
  locked_settings_file,
  version = 3
)


# ============================================================
# Final validation table
# ============================================================

validation_table <- add_validation(
  return_table = TRUE
)

if (
  nrow(
    validation_table
  ) == 0L ||
    any(
      !validation_table$Passed
    )
) {

  write_csv_safely(
    validation_table,
    validation_file
  )

  failed_checks <- validation_table$Check[
    !validation_table$Passed
  ]

  stop(
    "One or more locked-input validation checks failed: ",
    paste(
      failed_checks,
      collapse = "; "
    )
  )
}

write_csv_safely(
  validation_table,
  validation_file
)


# ============================================================
# Output manifest
# ============================================================

output_files_before_manifest <- c(
  locked_archive_file,
  locked_settings_file,
  locked_species_pca_file,
  occurrence_summary_file,
  pca_variance_file,
  pca_species_summary_file,
  validation_file
)

output_files_before_manifest <- output_files_before_manifest[
  file.exists(
    output_files_before_manifest
  )
]

file_information <- file.info(
  output_files_before_manifest
)

output_manifest <- data.frame(
  File_name = basename(
    output_files_before_manifest
  ),
  Relative_location = substring(
    normalizePath(
      output_files_before_manifest,
      winslash = "/",
      mustWork = TRUE
    ),
    nchar(
      normalizePath(
        output_directory,
        winslash = "/",
        mustWork = TRUE
      )
    ) +
      2L
  ),
  File_size_bytes = as.numeric(
    file_information$size
  ),
  MD5 = unname(
    tools::md5sum(
      output_files_before_manifest
    )
  ),
  stringsAsFactors = FALSE
)

write_csv_safely(
  output_manifest,
  manifest_file
)


# ============================================================
# Notes and session information
# ============================================================

notes_lines <- c(
  "ACACIA LOCKED EMPIRICAL INPUTS",
  "==============================",
  "",
  "Purpose:",
  "  Lock the already-completed Acacia occurrence/environment/PCA archive",
  "  for the revised sqrt-NB / q=0.99 QPH analysis branch.",
  "",
  "No ecological input was regenerated.",
  "No environmental raster was re-extracted.",
  "No occurrence record was added, removed or reordered.",
  "No PCA was refitted.",
  "No QPH, Gaussian KDE or SVM model was fitted.",
  "",
  "Selected species:",
  paste0(
    "  - ",
    expected_species,
    " (n = ",
    as.integer(
      calculated_species_counts
    ),
    ")"
  ),
  "",
  "PCA design:",
  paste0(
    "  ",
    metadata$pca_scope
  ),
  paste0(
    "  Retained PCs: ",
    paste(
      expected_pc_names,
      collapse = ", "
    )
  ),
  paste0(
    "  PC1-PC3 cumulative variance explained: ",
    round(
      cumulative_pc1_pc3,
      6
    ),
    "%"
  ),
  "",
  paste0(
    "Exact coordinate duplicates removed: ",
    settings$remove_exact_coordinate_duplicates_within_species
  ),
  "",
  paste0(
    "Source archive MD5: ",
    source_archive_md5
  ),
  paste0(
    "Locked archive MD5: ",
    locked_archive_md5
  ),
  paste0(
    "Locked scientific design hash: ",
    locked_design_hash
  ),
  paste0(
    "Species PC matrix collection hash: ",
    species_pca_collection_hash
  ),
  "",
  "QPH parameter dependence:",
  "  NONE in Script 18.",
  "  The revised Nasios-Bors-derived square-root local-distance bandwidth",
  "  and q = 0.99 enter for the first time in Script 19.",
  "",
  paste0(
    "Completed: ",
    Sys.time()
  )
)

writeLines(
  notes_lines,
  con = notes_file
)

capture.output(
  sessionInfo(),
  file = session_information_file
)


# ============================================================
# Refresh manifest with notes/session
# ============================================================

all_output_files <- c(
  output_files_before_manifest,
  manifest_file,
  notes_file,
  session_information_file
)

all_output_files <- unique(
  all_output_files[
    file.exists(
      all_output_files
    )
  ]
)

file_information <- file.info(
  all_output_files
)

output_manifest <- data.frame(
  File_name = basename(
    all_output_files
  ),
  Relative_location = substring(
    normalizePath(
      all_output_files,
      winslash = "/",
      mustWork = TRUE
    ),
    nchar(
      normalizePath(
        output_directory,
        winslash = "/",
        mustWork = TRUE
      )
    ) +
      2L
  ),
  File_size_bytes = as.numeric(
    file_information$size
  ),
  MD5 = unname(
    tools::md5sum(
      all_output_files
    )
  ),
  stringsAsFactors = FALSE
)

write_csv_safely(
  output_manifest,
  manifest_file
)


# ============================================================
# Final console summary
# ============================================================

message(
  "\n============================================================"
)

message(
  "18_Acacia_Locked_Inputs.R complete."
)

message(
  "No occurrence/environment/PCA regeneration was performed."
)

message(
  "\nFinal occurrence counts:"
)

print(
  occurrence_summary[
    ,
    c(
      "Species",
      "Final_occurrence_count"
    ),
    drop = FALSE
  ],
  row.names = FALSE
)

message(
  "\nPC1-PC3 cumulative variance explained: ",
  round(
    cumulative_pc1_pc3,
    4
  ),
  "%"
)

message(
  "\nSource archive MD5:\n  ",
  source_archive_md5
)

message(
  "Locked archive MD5:\n  ",
  locked_archive_md5
)

message(
  "Locked design hash:\n  ",
  locked_design_hash
)

message(
  "\nLocked authoritative archive:\n  ",
  normalizePath(
    locked_archive_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "Locked settings:\n  ",
  normalizePath(
    locked_settings_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "Validation table:\n  ",
  normalizePath(
    validation_file,
    winslash = "/",
    mustWork = FALSE
  )
)

message(
  "============================================================"
)
