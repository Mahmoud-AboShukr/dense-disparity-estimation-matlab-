# Stereo Vision Disparity Estimation in MATLAB

This repository presents a MATLAB implementation of **stereo disparity estimation** on a rectified image pair from the **Middlebury stereo dataset**.  
The project studies the full stereo matching pipeline, from qualitative inspection of rectification to block-matching disparity computation, similarity metric comparison, hole filling, consistency checking, and energy-based regularization.

Rather than stopping at a basic disparity map, the project progressively improves the matching pipeline through multiple classical stereo vision techniques and evaluates the results against ground-truth disparity.

## Project Overview

The workflow includes:

- loading and visualizing a rectified stereo pair,
- verifying horizontal epipolar alignment using stereo anaglyphs and row intensity profiles,
- estimating a realistic disparity search range,
- implementing custom block matching for disparity estimation,
- comparing **SAD**, **SSD**, and **NCC** similarity measures,
- rejecting homogeneous regions using contrast and gradient criteria,
- filling missing disparity values with morphological post-processing,
- improving robustness using **left-right consistency checking**,
- reformulating stereo matching as an **energy minimization** problem,
- solving disparity optimization with:
  - a relaxation / ICM-like method,
  - row-wise dynamic programming.

## Main Features

- MATLAB implementation of block matching from scratch
- Automatic disparity-range estimation using `disparityBM`
- Comparison of classical similarity measures:
  - **SAD** — Sum of Absolute Differences
  - **SSD** — Sum of Squared Differences
  - **NCC** — Normalized Cross-Correlation
- Texture rejection using local contrast and Sobel gradients
- Post-processing with dilation and median filtering
- Left-right consistency filtering
- Cost-volume construction for energy minimization
- Regularized disparity estimation with relaxation and dynamic programming
- Quantitative comparison with ground-truth disparity

## Repository Structure

```text
stereo-vision-disparity-estimation/
├── stereo_disparity_pipeline.m
├── README.md
├── MATLAB_REQUIREMENTS.md
├── im2.ppm
├── im6.ppm
└── disp2.pgm
```

## Methodology

### 1. Stereo Pair Inspection
The project begins by loading the left and right images, converting them to grayscale, and visually checking whether the pair is already rectified.

### 2. Rectification Verification
A stereo anaglyph and a row-wise intensity profile are used to confirm that the displacement between corresponding pixels is purely horizontal. This justifies a 1D disparity search along image rows.

### 3. Block Matching
A custom block-matching function is implemented to compute disparity by searching for the best match in the right image for each block in the left image.

### 4. Similarity Measures
The project compares three classical matching costs:
- **SAD** for simplicity and speed,
- **SSD** for stronger penalization of intensity differences,
- **NCC** for better robustness to brightness and contrast changes.

### 5. Reliability Filtering
Flat or low-information regions are rejected using:
- a local contrast threshold,
- a Sobel-gradient threshold.

This reduces unstable matches in homogeneous areas.

### 6. Hole Filling
Undefined or unreliable disparity values are filled using morphological dilation followed by median filtering.

### 7. Consistency Checking
A left-right consistency check removes disparity assignments that are not geometrically self-consistent between the two matching directions.

### 8. Energy Minimization
The disparity problem is finally formulated using:
- a **data term** from matching cost,
- a **smoothness term** enforcing local disparity coherence.

Two optimization strategies are then applied:
- **Relaxation / ICM-like optimization**
- **Dynamic programming along scanlines**

## Dataset

This project uses a stereo pair and ground-truth disparity map from the **Middlebury stereo benchmark**.

Expected input files:
- `im2.ppm` — left image
- `im6.ppm` — right image
- `disp2.pgm` — ground-truth disparity

## Requirements

See `MATLAB_REQUIREMENTS.md` for the full dependency list.

At minimum, the project expects:
- MATLAB
- Image Processing Toolbox
- Computer Vision Toolbox

## How to Run

1. Place the stereo images and disparity ground-truth in the working directory.
2. Open MATLAB.
3. Open the main script:
   ```matlab
   stereo_disparity_pipeline.m
   ```
4. Run the script section by section or as a whole.

The script will:
- visualize the stereo pair,
- estimate disparity maps with several methods,
- display comparison figures,
- compute error metrics against ground truth.

## Results

The project demonstrates how disparity quality evolves as the stereo pipeline becomes more sophisticated:

- basic block matching provides a first depth estimate,
- SSD and NCC improve matching quality over plain SAD in many regions,
- contrast and gradient filtering reduce noise in textureless areas,
- hole filling improves visual coherence,
- left-right consistency removes invalid matches,
- energy minimization produces smoother and more structured disparity maps.
