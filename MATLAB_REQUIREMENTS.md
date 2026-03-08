# MATLAB Requirements

## Software
- MATLAB R2022b or later recommended

## Required Toolboxes
- Image Processing Toolbox
- Computer Vision Toolbox

## Input Files
The following files are expected in the working directory:

- `im2.ppm` — left stereo image
- `im6.ppm` — right stereo image
- `disp2.pgm` — ground-truth disparity map

## MATLAB Functions Used
This project relies on built-in MATLAB functions including:

- `imread`
- `imshow`
- `rgb2gray`
- `stereoAnaglyph`
- `disparityBM`
- `imgradient`
- `imgradientxy`
- `imagesc`
- `strel`
- `imdilate`
- `medfilt2`

## Notes
- No external third-party MATLAB packages are required.
- The project is designed around a rectified stereo pair and assumes the dataset files are locally available.
- For GitHub, it is better to keep large generated outputs out of version control unless they are included as sample results.
