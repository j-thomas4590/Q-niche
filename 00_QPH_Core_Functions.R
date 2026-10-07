# ============================================================
# 00_QPH_Core_Functions.R
# ============================================================
#
# Authoritative reusable functions for the revised Q-niche (refered to as QPH throughout) analyses.
#
# Locked baseline QPH definition:
#   - bandwidth rule:
#       K = round(sqrt(n))
#       s_i = sum_{k=1}^K ||x_i - x_(k)||^2 / (K - 1)
#       mean_s = mean(s_i)
#       h = sqrt(mean_s)
#       bandwidth = rep(h, d)
#   - the K neighbours are the K nearest OTHER occurrence observations
#     under Euclidean distance in the environmental space supplied to QPH
#   - the scalar h is applied isotropically across all retained axes
#   - baseline occurrence-potential quantile q = 0.99
#   - samples_per_point = 100
#   - sd_count = 3
#
# Terminology:
#   "Nasios-Bors-derived square-root local-distance bandwidth"
#
#.
#
# ============================================================
# ============================================================
# Core version identifier
# ============================================================

QPH_CORE_VERSION <- "sqrtNB_q099_v1"

QPH_BANDWIDTH_METHOD <- paste(
  "Nasios-Bors-derived square-root",
  "local-distance bandwidth"
)


# ============================================================
# Basic validation helpers
# ============================================================

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


set_environmental_axis_names <- function(x) {
  x <- as.matrix(x)

  colnames(x) <- paste(
    "Environmental axis",
    seq_len(ncol(x))
  )

  x
}


validate_positive_integer <- function(x, object_name) {
  if (
    length(x) != 1L ||
      is.na(x) ||
      !is.finite(x) ||
      x < 1 ||
      x != as.integer(x)
  ) {
    stop(object_name, " must be a positive integer.")
  }

  as.integer(x)
}


validate_positive_scalar <- function(x, object_name) {
  if (
    length(x) != 1L ||
      is.na(x) ||
      !is.finite(x) ||
      x <= 0
  ) {
    stop(object_name, " must be positive and finite.")
  }

  as.numeric(x)
}


# ============================================================
# QPH Nasios-Bors-derived square-root bandwidth
# ============================================================
#
# IMPORTANT:
# This function implements the locked bandwidth calculation exactly as
# specified for the revised QPH analyses.
#
# The K nearest OTHER observations are selected using Euclidean distance.
# There are K squared distances in the numerator and the denominator is
# deliberately (K - 1), matching the locked QPH definition.
# ============================================================

estimate_qph_sqrt_nb_bandwidth <- function(data, k = NULL) {

  data <- as.matrix(data)

  n <- nrow(data)
  d <- ncol(data)

  # Neighbourhood size used in the revised QPH analyses
  if (is.null(k)) {
    k <- round(sqrt(n))
  }

  k <- max(
    2L,
    min(as.integer(k), n - 1L)
  )

  # Pairwise Euclidean distances
  distance_matrix <- as.matrix(
    stats::dist(data)
  )

  diag(distance_matrix) <- Inf

  # Nasios-Bors local squared-distance statistic
  s_i <- numeric(n)

  for (i in seq_len(n)) {

    nearest <- order(
      distance_matrix[i, ],
      decreasing = FALSE
    )[seq_len(k)]

    squared_distances <- (
      distance_matrix[i, nearest]^2
    )

    s_i[i] <- (
      sum(squared_distances) /
        (k - 1)
    )
  }

  # Published Nasios-Bors scale would be:
  #   mean_s <- mean(s_i)
  #
  # Revised QPH instead uses the square root so that the
  # bandwidth is on the same scale as Euclidean distance.
  mean_s <- mean(s_i)

  h_scalar <- sqrt(mean_s)

  # Isotropic QPH bandwidth
  bandwidth <- rep(
    h_scalar,
    d
  )

  names(bandwidth) <- colnames(data)

  list(
    bandwidth = bandwidth,
    scalar_bandwidth = h_scalar,
    k = k,
    mean_s = mean_s,
    local_s = s_i
  )
}


# ============================================================
# Validate a saved/precomputed QPH bandwidth audit
# ============================================================
#
# This is useful for expensive sensitivity analyses, where the baseline
# sqrt-NB calculation can be performed once and passed repeatedly to the
# QPH constructor while fitted bandwidths are varied explicitly.
# ============================================================

validate_qph_bandwidth_info <- function(
    bandwidth_info,
    data
) {
  data <- validate_numeric_matrix(data, "data")

  required_names <- c(
    "bandwidth",
    "scalar_bandwidth",
    "k",
    "mean_s",
    "local_s"
  )

  if (!is.list(bandwidth_info)) {
    stop("bandwidth_info must be a list.")
  }

  if (!all(required_names %in% names(bandwidth_info))) {
    stop(
      "bandwidth_info is missing one or more required elements: ",
      paste(required_names, collapse = ", "),
      "."
    )
  }

  n <- nrow(data)
  d <- ncol(data)

  if (length(bandwidth_info$local_s) != n) {
    stop("bandwidth_info$local_s does not match the number of rows in data.")
  }

  if (length(bandwidth_info$bandwidth) != d) {
    stop("bandwidth_info$bandwidth does not match the dimensionality of data.")
  }

  if (
    any(!is.finite(bandwidth_info$local_s)) ||
      any(bandwidth_info$local_s < 0)
  ) {
    stop("bandwidth_info$local_s must contain finite non-negative values.")
  }

  if (
    length(bandwidth_info$mean_s) != 1L ||
      !is.finite(bandwidth_info$mean_s) ||
      bandwidth_info$mean_s <= 0
  ) {
    stop("bandwidth_info$mean_s must be positive and finite.")
  }

  if (
    length(bandwidth_info$scalar_bandwidth) != 1L ||
      !is.finite(bandwidth_info$scalar_bandwidth) ||
      bandwidth_info$scalar_bandwidth <= 0
  ) {
    stop("bandwidth_info$scalar_bandwidth must be positive and finite.")
  }

  if (
    any(!is.finite(bandwidth_info$bandwidth)) ||
      any(bandwidth_info$bandwidth <= 0)
  ) {
    stop("bandwidth_info$bandwidth must contain positive finite values.")
  }

  expected_scalar <- sqrt(as.numeric(bandwidth_info$mean_s))

  if (!isTRUE(all.equal(
    as.numeric(bandwidth_info$scalar_bandwidth),
    expected_scalar,
    tolerance = 1e-12
  ))) {
    stop(
      "bandwidth_info is internally inconsistent: scalar_bandwidth is not ",
      "sqrt(mean_s)."
    )
  }

  expected_bandwidth <- rep(
    as.numeric(bandwidth_info$scalar_bandwidth),
    d
  )

  if (!isTRUE(all.equal(
    as.numeric(bandwidth_info$bandwidth),
    expected_bandwidth,
    tolerance = 1e-12
  ))) {
    stop(
      "bandwidth_info is internally inconsistent: the baseline bandwidth ",
      "must be isotropic."
    )
  }

  invisible(TRUE)
}


# ============================================================
# QPH potential
# ============================================================
#
# Analytical potential used in the existing QPH implementation:
#
#   V(y) = -d/2 +
#          sum_i[D_i^2 exp(-D_i^2/2)] /
#          (2 sum_i[exp(-D_i^2/2)])
#
# where distances are evaluated in bandwidth-standardised coordinates.
# The additive energy constant is therefore set to E = 0.
#
# This implementation is retained from the existing analysis.
# ============================================================

calculate_qph_potential <- function(
    evaluation_points,
    occurrence_points,
    bandwidth,
    batch_size = 500L
) {
  evaluation_points <- validate_numeric_matrix(
    evaluation_points,
    "evaluation_points"
  )

  occurrence_points <- validate_numeric_matrix(
    occurrence_points,
    "occurrence_points"
  )

  if (ncol(evaluation_points) != ncol(occurrence_points)) {
    stop(
      "evaluation_points and occurrence_points must have the ",
      "same dimensionality."
    )
  }

  bandwidth <- as.numeric(bandwidth)
  dimensionality <- ncol(occurrence_points)

  if (length(bandwidth) != dimensionality) {
    stop(
      "bandwidth must contain one positive value for each dimension."
    )
  }

  if (any(!is.finite(bandwidth)) || any(bandwidth <= 0)) {
    stop("All bandwidth values must be positive and finite.")
  }

  batch_size <- as.integer(batch_size)

  if (length(batch_size) != 1L || is.na(batch_size) || batch_size < 1L) {
    stop("batch_size must be a positive integer.")
  }

  # Transform to bandwidth-standardised coordinates. The package's
  # axis-aligned hyperellipsoids become hyperspheres in this space.
  occurrence_scaled <- sweep(
    occurrence_points,
    MARGIN = 2,
    STATS = bandwidth,
    FUN = "/"
  )

  evaluation_scaled <- sweep(
    evaluation_points,
    MARGIN = 2,
    STATS = bandwidth,
    FUN = "/"
  )

  occurrence_squared_norm <- rowSums(occurrence_scaled^2)
  number_of_evaluation_points <- nrow(evaluation_scaled)
  potential <- numeric(number_of_evaluation_points)

  batch_starts <- seq.int(
    from = 1L,
    to = number_of_evaluation_points,
    by = batch_size
  )

  for (start_index in batch_starts) {
    end_index <- min(
      start_index + batch_size - 1L,
      number_of_evaluation_points
    )

    batch_indices <- start_index:end_index

    evaluation_batch <- evaluation_scaled[
      batch_indices,
      ,
      drop = FALSE
    ]

    # Pairwise squared distances:
    # ||a - b||^2 = ||a||^2 + ||b||^2 - 2 a'b
    distance_squared <- outer(
      rowSums(evaluation_batch^2),
      occurrence_squared_norm,
      FUN = "+"
    ) - 2 * tcrossprod(
      evaluation_batch,
      occurrence_scaled
    )

    # Remove tiny negative values caused by floating-point error.
    tiny_negative <- (
      distance_squared < 0 &
        distance_squared > -1e-8
    )

    distance_squared[tiny_negative] <- 0

    if (any(distance_squared < 0)) {
      stop("Unexpected negative squared distances were produced.")
    }

    gaussian_weights <- exp(-0.5 * distance_squared)
    weight_sum <- rowSums(gaussian_weights)

    if (any(!is.finite(weight_sum)) || any(weight_sum <= 0)) {
      stop("A Gaussian weight sum was zero or non-finite.")
    }

    weighted_distance_sum <- rowSums(
      gaussian_weights * distance_squared
    )

    potential[batch_indices] <- (
      -dimensionality / 2 +
        0.5 * weighted_distance_sum / weight_sum
    )
  }

  potential
}


# ============================================================
# QPH audit helper
# ============================================================

make_qph_audit <- function(
    data,
    bandwidth_info,
    fitted_bandwidth,
    bandwidth_source,
    q,
    samples_per_point,
    sd_count,
    sampling_seed,
    sampling_chunk_size,
    potential_batch_size
) {
  data <- validate_numeric_matrix(data, "data")
  validate_qph_bandwidth_info(bandwidth_info, data)

  fitted_bandwidth <- as.numeric(fitted_bandwidth)

  if (length(fitted_bandwidth) != ncol(data)) {
    stop("fitted_bandwidth must contain one value per environmental axis.")
  }

  if (any(!is.finite(fitted_bandwidth)) || any(fitted_bandwidth <= 0)) {
    stop("fitted_bandwidth must contain positive finite values.")
  }

  list(
    core_version = QPH_CORE_VERSION,
    bandwidth_method = QPH_BANDWIDTH_METHOD,
    bandwidth_source = as.character(bandwidth_source),
    n = nrow(data),
    d = ncol(data),
    K = as.integer(bandwidth_info$k),
    local_s = as.numeric(bandwidth_info$local_s),
    mean_s = as.numeric(bandwidth_info$mean_s),
    baseline_scalar_h = as.numeric(bandwidth_info$scalar_bandwidth),
    baseline_isotropic_bandwidth = as.numeric(bandwidth_info$bandwidth),
    fitted_bandwidth = fitted_bandwidth,
    fitted_isotropic = isTRUE(all.equal(
      fitted_bandwidth,
      rep(fitted_bandwidth[1], length(fitted_bandwidth)),
      tolerance = 1e-12
    )),
    q = as.numeric(q),
    samples_per_point = as.integer(samples_per_point),
    sd_count = as.numeric(sd_count),
    sampling_seed = as.integer(sampling_seed),
    sampling_chunk_size = as.integer(sampling_chunk_size),
    potential_batch_size = as.integer(potential_batch_size)
  )
}


# ============================================================
# Compact one-row audit summary
# ============================================================
#
# The full audit retains every local_s value in the RDS object. This helper
# gives downstream scripts a convenient one-row summary for CSV tables.
# ============================================================

qph_audit_summary <- function(audit) {
  required_names <- c(
    "core_version",
    "bandwidth_method",
    "bandwidth_source",
    "n",
    "d",
    "K",
    "local_s",
    "mean_s",
    "baseline_scalar_h",
    "baseline_isotropic_bandwidth",
    "fitted_bandwidth",
    "fitted_isotropic",
    "q",
    "samples_per_point",
    "sd_count",
    "sampling_seed",
    "sampling_chunk_size",
    "potential_batch_size"
  )

  if (!is.list(audit) || !all(required_names %in% names(audit))) {
    stop("audit is not a complete QPH audit object.")
  }

  fitted_bandwidth_text <- paste(
    format(audit$fitted_bandwidth, digits = 17, scientific = FALSE),
    collapse = ";"
  )

  baseline_bandwidth_text <- paste(
    format(
      audit$baseline_isotropic_bandwidth,
      digits = 17,
      scientific = FALSE
    ),
    collapse = ";"
  )

  data.frame(
    Core_version = audit$core_version,
    Bandwidth_method = audit$bandwidth_method,
    Bandwidth_source = audit$bandwidth_source,
    n = audit$n,
    d = audit$d,
    K = audit$K,
    Mean_s = audit$mean_s,
    Baseline_scalar_h = audit$baseline_scalar_h,
    Baseline_bandwidth_vector = baseline_bandwidth_text,
    Fitted_bandwidth_vector = fitted_bandwidth_text,
    Fitted_isotropic = audit$fitted_isotropic,
    q = audit$q,
    Samples_per_point = audit$samples_per_point,
    SD_count = audit$sd_count,
    Sampling_seed = audit$sampling_seed,
    Sampling_chunk_size = audit$sampling_chunk_size,
    Potential_batch_size = audit$potential_batch_size,
    Local_s_count = length(audit$local_s),
    Local_s_min = min(audit$local_s),
    Local_s_mean = mean(audit$local_s),
    Local_s_max = max(audit$local_s),
    stringsAsFactors = FALSE
  )
}


# ============================================================
# Authoritative QPH constructor
# ============================================================
#
# Baseline use:
#
#   fit <- construct_qph(
#     data = occurrence_points,
#     q = 0.99,
#     samples_per_point = 100L,
#     sd_count = 3,
#     sampling_seed = my_seed
#   )
#
# When bandwidth = NULL, the constructor ALWAYS uses the revised locked
# sqrt-NB bandwidth estimated from the supplied occurrence cloud.
#
# Sensitivity use:
#   1. Calculate bandwidth_info once with
#        estimate_qph_sqrt_nb_bandwidth(data)
#   2. Supply a deliberately varied fitted bandwidth through `bandwidth`
#      while also passing the unmodified `bandwidth_info` for audit.
#
# This keeps the baseline rule and the sensitivity modification explicit.
# ============================================================

construct_qph <- function(
    data,
    bandwidth = NULL,
    bandwidth_info = NULL,
    name = "Quantum potential hypervolume",
    samples_per_point = 100L,
    sd_count = 3,
    q = 0.99,
    sampling_seed = 123L,
    sampling_chunk_size = 100L,
    potential_batch_size = 500L,
    verbose = TRUE
) {
  if (!requireNamespace("hypervolume", quietly = TRUE)) {
    stop(
      "The hypervolume package is required to construct QPH objects."
    )
  }

  data <- validate_numeric_matrix(data, "data")
  data <- set_environmental_axis_names(data)

  if (nrow(data) < 3L) {
    stop(
      "At least three occurrence points are required for the locked ",
      "sqrt-NB bandwidth rule."
    )
  }

  dimensionality <- ncol(data)

  if (is.null(bandwidth_info)) {
    bandwidth_info <- estimate_qph_sqrt_nb_bandwidth(data)
  } else {
    validate_qph_bandwidth_info(
      bandwidth_info = bandwidth_info,
      data = data
    )
  }

  # Baseline fits use the revised sqrt-NB bandwidth directly.
  # A supplied bandwidth is treated as an explicit override, for example
  # in a future sensitivity analysis. The unmodified sqrt-NB quantities
  # remain stored in the audit either way.
  if (is.null(bandwidth)) {
    bandwidth <- bandwidth_info$bandwidth
    bandwidth_source <- "sqrtNB_q099 baseline"
  } else {
    bandwidth_source <- "explicit supplied QPH bandwidth override"
  }

  bandwidth <- as.numeric(bandwidth)

  if (length(bandwidth) != dimensionality) {
    stop("bandwidth must contain one value for each dimension.")
  }

  if (any(!is.finite(bandwidth)) || any(bandwidth <= 0)) {
    stop("All bandwidth values must be positive and finite.")
  }

  names(bandwidth) <- colnames(data)

  samples_per_point <- validate_positive_integer(
    samples_per_point,
    "samples_per_point"
  )

  sampling_chunk_size <- validate_positive_integer(
    sampling_chunk_size,
    "sampling_chunk_size"
  )

  potential_batch_size <- validate_positive_integer(
    potential_batch_size,
    "potential_batch_size"
  )

  sampling_seed <- as.integer(sampling_seed)

  if (
    length(sampling_seed) != 1L ||
      is.na(sampling_seed)
  ) {
    stop("sampling_seed must be a single non-missing integer.")
  }

  sd_count <- validate_positive_scalar(
    sd_count,
    "sd_count"
  )

  if (
    length(q) != 1L ||
      !is.finite(q) ||
      q <= 0 ||
      q >= 1
  ) {
    stop("q must lie strictly between zero and one.")
  }

  q <- as.numeric(q)

  audit <- make_qph_audit(
    data = data,
    bandwidth_info = bandwidth_info,
    fitted_bandwidth = bandwidth,
    bandwidth_source = bandwidth_source,
    q = q,
    samples_per_point = samples_per_point,
    sd_count = sd_count,
    sampling_seed = sampling_seed,
    sampling_chunk_size = sampling_chunk_size,
    potential_batch_size = potential_batch_size
  )

  if (verbose) {
    message(
      "QPH bandwidth: h = ",
      format(audit$baseline_scalar_h, digits = 10),
      "; K = ",
      audit$K,
      "; q = ",
      format(q, digits = 4)
    )

    if (bandwidth_source != "sqrtNB_q099 baseline") {
      message(
        "Using explicit fitted bandwidth override: ",
        paste(format(bandwidth, digits = 10), collapse = ", ")
      )
    }

    message("Calculating potential at occurrence points...")
  }

  occurrence_potential_raw <- calculate_qph_potential(
    evaluation_points = data,
    occurrence_points = data,
    bandwidth = bandwidth,
    batch_size = potential_batch_size
  )

  potential_threshold_raw <- unname(
    stats::quantile(
      occurrence_potential_raw,
      probs = q,
      type = 7,
      names = FALSE
    )
  )

  hypervolume_namespace <- asNamespace("hypervolume")

  if (!exists(
    "sample_model_ellipsoid",
    envir = hypervolume_namespace,
    inherits = FALSE
  )) {
    stop(
      "The installed hypervolume package does not contain the internal ",
      "function sample_model_ellipsoid()."
    )
  }

  sample_model_ellipsoid_hv <- getFromNamespace(
    "sample_model_ellipsoid",
    "hypervolume"
  )

  qph_prediction_function <- function(new_points) {
    -calculate_qph_potential(
      evaluation_points = new_points,
      occurrence_points = data,
      bandwidth = bandwidth,
      batch_size = potential_batch_size
    )
  }

  ellipsoid_scales <- bandwidth * sd_count

  set.seed(sampling_seed)

  if (verbose) {
    message(
      "Sampling the union of occurrence-centred hyperellipsoids..."
    )
  }

  # Preserve the existing candidate-sampling implementation.
  # min.value = -Inf returns a uniform candidate cloud across the
  # complete union before the QPH potential threshold is applied.
  qph_sampling <- sample_model_ellipsoid_hv(
    predict_function = qph_prediction_function,
    data = data,
    scales = ellipsoid_scales,
    min.value = -Inf,
    samples.per.point = samples_per_point,
    chunk.size = sampling_chunk_size,
    verbose = verbose,
    return.full = FALSE
  )

  candidate_points <- qph_sampling$samples[
    ,
    seq_len(dimensionality),
    drop = FALSE
  ]

  colnames(candidate_points) <- colnames(data)

  # The sampler stores negative potential because higher prediction values
  # are normally interpreted as stronger model support.
  candidate_potential_raw <- -as.numeric(
    qph_sampling$samples[, dimensionality + 1L]
  )

  sampling_region_volume <- as.numeric(qph_sampling$volume)

  inside_qph <- (
    candidate_potential_raw <=
      potential_threshold_raw + sqrt(.Machine$double.eps)
  )

  qph_points <- candidate_points[
    inside_qph,
    ,
    drop = FALSE
  ]

  qph_potential_raw <- candidate_potential_raw[inside_qph]

  if (nrow(qph_points) == 0L) {
    stop("No candidate points passed the QPH threshold.")
  }

  retained_fraction <- mean(inside_qph)
  qph_volume <- sampling_region_volume * retained_fraction

  if (!is.finite(qph_volume) || qph_volume <= 0) {
    stop("The estimated QPH volume is not positive and finite.")
  }

  retained_fraction_se <- sqrt(
    retained_fraction *
      (1 - retained_fraction) /
      length(inside_qph)
  )

  qph_volume_se_conditional <- (
    sampling_region_volume * retained_fraction_se
  )

  potential_minimum <- min(
    c(
      occurrence_potential_raw,
      candidate_potential_raw
    )
  )

  occurrence_potential_relative <- (
    occurrence_potential_raw - potential_minimum
  )

  candidate_potential_relative <- (
    candidate_potential_raw - potential_minimum
  )

  qph_potential_relative <- (
    qph_potential_raw - potential_minimum
  )

  potential_threshold_relative <- (
    potential_threshold_raw - potential_minimum
  )

  point_density <- nrow(qph_points) / qph_volume

  # The final QPH is a binary region represented uniformly. Raw potential
  # values are returned separately rather than being stored as probability
  # densities in ValueAtRandomPoints.
  uniform_density <- rep(
    1 / qph_volume,
    nrow(qph_points)
  )

  # `kde.bandwidth` is retained as a compatibility field used by existing
  # Hypervolume-oriented downstream code. It contains the QPH bandwidth and
  # must NOT be interpreted as meaning that QPH used the KDE estimator's
  # Silverman bandwidth. Explicit QPH fields are saved alongside it.
  hv_qph <- methods::new(
    "Hypervolume",
    Name = as.character(name),
    Method = "Quantum potential hypervolume",
    Data = data,
    Dimensionality = as.numeric(dimensionality),
    Volume = as.numeric(qph_volume),
    PointDensity = as.numeric(point_density),
    Parameters = list(
      kde.bandwidth = bandwidth,
      kde.method = QPH_BANDWIDTH_METHOD,
      qph.bandwidth = bandwidth,
      qph.bandwidth.method = QPH_BANDWIDTH_METHOD,
      qph.bandwidth.source = bandwidth_source,
      qph.K = audit$K,
      qph.mean.s = audit$mean_s,
      qph.scalar.h.baseline = audit$baseline_scalar_h,
      qph.local.s = audit$local_s,
      samples.per.point = samples_per_point,
      sd.count = sd_count,
      sampling.seed = sampling_seed,
      potential.quantile = q,
      potential.threshold.raw = potential_threshold_raw,
      potential.threshold.relative = potential_threshold_relative,
      coordinate.system = "Bandwidth-standardised coordinates",
      sampling.region.volume = sampling_region_volume,
      retained.fraction = retained_fraction,
      volume.standard.error.conditional = qph_volume_se_conditional,
      volume.method = paste(
        "Uniform ellipsoidal sampling followed by",
        "Monte Carlo sublevel-set integration"
      ),
      qph.core.version = QPH_CORE_VERSION
    ),
    RandomPoints = qph_points,
    ValueAtRandomPoints = uniform_density
  )

  methods::validObject(hv_qph)

  list(
    hypervolume = hv_qph,
    audit = audit,
    audit_summary = qph_audit_summary(audit),
    bandwidth_info = bandwidth_info,
    occurrence_points = data,
    bandwidth = bandwidth,
    ellipsoid_scales = ellipsoid_scales,
    occurrence_potential_raw = occurrence_potential_raw,
    occurrence_potential_relative = occurrence_potential_relative,
    candidate_points = candidate_points,
    candidate_potential_raw = candidate_potential_raw,
    candidate_potential_relative = candidate_potential_relative,
    potential_threshold_raw = potential_threshold_raw,
    potential_threshold_relative = potential_threshold_relative,
    inside_qph = inside_qph,
    qph_points = qph_points,
    qph_potential_raw = qph_potential_raw,
    qph_potential_relative = qph_potential_relative,
    sampling_region_volume = sampling_region_volume,
    retained_fraction = retained_fraction,
    qph_volume = qph_volume,
    qph_volume_se_conditional = qph_volume_se_conditional
  )
}


# ============================================================
# End of authoritative QPH core functions
# ============================================================
