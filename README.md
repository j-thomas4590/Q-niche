# Q-niche

Code accompanying **“`Q-niche': topologically preserving niche hypervolumes built using a quantum mechanics modelling analogue”**.

Some scripts, functions and filenames use **QPH** (quantum potential hypervolumes), the former name of **Q-niche**.

## Files and inputs

- `Scripts/`: R code for the analyses.
- `Data/`: base RDS input archives for the synthetic, virtual-species and empirical Acacia analyses.
- `Results/`: created locally by the scripts; generated results are not included in this repository.

Synthetic niche definitions and dataset construction are described in the manuscript and Supplementary Materials. The scripts read the supplied base RDS archives rather than recreating the original datasets. Script 11 generates its own dimensionality-test datasets.

**WorldClim data are not included.** Download and extract the WorldClim 2.1 bioclimatic variables (BIO1–BIO19) and elevation at 2.5 arc-minute resolution before running the Acacia geographical projection analysis (Script 22). Set the raster input paths to the downloaded files. The virtual-species analyses use the environmental landscape stored in their supplied archives.

## Running the code

Run scripts from the repository root and install the R packages specified in each script. Keep the supplied input filenames and folder structure. Run each numbered analysis sequence in order; later scripts use outputs from earlier scripts. `00_QPH_Core_Functions.R` is sourced by the estimator scripts.

## Script guide

| Script | Purpose |
|---|---|
| `00_QPH_Core_Functions.R` | Core Q-niche estimation functions. |
| `01_2D_Synthetic_Baseline_Fits.R` | Fit the three estimators to the two-dimensional synthetic datasets. |
| `02_2D_Synthetic_Geometry.R` | Evaluate two-dimensional geometrical recovery. |
| `03_2D_Synthetic_Topology.R` | Evaluate two-dimensional topological recovery. |
| `04_2D_Synthetic_Sensitivity.R` | Test sensitivity to estimator settings. |
| `05_2D_Independent_Occurrence_Robustness.R` | Repeat comparisons across independent occurrence clouds. |
| `06_3D_Synthetic_Baseline_Fits.R` | Fit the three estimators to the three-dimensional synthetic datasets. |
| `07_3D_Synthetic_Geometry.R` | Evaluate three-dimensional geometrical recovery. |
| `08_3D_Synthetic_Topology.R` | Evaluate three-dimensional topological recovery. |
| `09_3D_Synthetic_Sensitivity.R` | Test three-dimensional sensitivity to estimator settings. |
| `11_Synthetic_Dimensionality_Test.R` | Examine recovery, sampling efficiency and runtime across dimensions. |
| `12_Virtual_Species_Locked_Inputs.R` | Validate and package the supplied virtual-species inputs. |
| `13_Virtual_Species_Baseline_Fits_and_Geography.R` | Fit virtual-species hypervolumes and project them geographically. |
| `14_Virtual_Species_Environmental_Geometry_n900.R` | Evaluate environmental geometrical recovery. |
| `15_Virtual_Species_Topology_n900.R` | Evaluate environmental topological recovery. |
| `16_Virtual_Species_QPH_Sensitivity_n900.R` | Test Q-niche sensitivity for the virtual species. |
| `18_Acacia_Locked_Inputs.R` | Validate and package the supplied Acacia inputs. |
| `19_Acacia_Baseline_Fits.R` | Fit Acacia hypervolumes using the three estimators. |
| `20_Acacia_Environmental_Geometry.R` | Compare Acacia hypervolume geometry. |
| `21_Acacia_Topology.R` | Compare Acacia hypervolume topology. |
| `22_Acacia_Geographic_Projection.R` | Project Acacia hypervolumes across Australia. |
| `23_Acacia_QPH_Sensitivity.R` | Test Q-niche sensitivity for the Acacia analyses. |
