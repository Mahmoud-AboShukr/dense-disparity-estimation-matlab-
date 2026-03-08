I1_rgb = imread('im2.ppm');  
I2_rgb = imread('im6.ppm');

figure; imshow(I1_rgb); title('image 2  left');
figure; imshow(I2_rgb); title('image 6  right');

I1 = rgb2gray(I1_rgb);
I2 = rgb2gray(I2_rgb);

Dgt = double(imread('disp2.pgm'));

figure; imshow(I1); title('Left image  in grayscale');
figure; imshow(I2); title('Right image in grayscale');
%% ------------------------------------------------------------------------

% let's verify using stereoAnaglyph.

anaglyph = stereoAnaglyph(I1_rgb, I2_rgb);
figure; imshow(anaglyph);
title('Stereo Anaglyph (left is red and right is cyan)');

% if we see the anaglyph image we can find that all disparity occurs along
% the horizontal axis and there is no vertical displacement between 
% corresponding points this indicates that the stereo cameras was mounted 
% in a standard horizontal baseline with parallel optical axes therefore 
% no rectification is required for this image pair

%% ------------------------------------------------------------------------
 
row = 125;  

figure;
plot(double(I1(row, :)), 'r'); hold on;
plot(double(I2(row, :)), 'b');
legend('Left image (I1)', 'Right image (I2)');
title(['Intensity profile for row ', num2str(row)]);
xlabel('Column index (x)');
ylabel('Pixel intensity');

% If we plot the intensity of a specific row from the left image and right
% image we can see that the two curves have the same shape but somehow 
% shifted horizontally this shift correspond to the disparity caused from 
% the baseline between the two cameras and as the shift is only along the 
% x-axis we can say that there is no vertical change
% which can confirm that the stereo pair is rectified and we can carry out
% the matching using 1D search along each row.

%% -----------------------------------------------------------------------
 
anaglyph = stereoAnaglyph(I1_rgb, I2_rgb);
figure; imshow(anaglyph);
title('Stereo Anaglyph (left is red and right is cyan)');
imageViewer(anaglyph);
% imtool(anaglyph);



% when we use the imageViewer and visualization and the intensity of a 
% specific line, the red (left) and cyan(right) we can find only horizontal
%  displacements, and these vary depending on the depth of the objects:

% 1- in the background the disparity is close to 0–2 pixels
% 2- At medium depths the shift is around 8–12 pixels
% 3- On the foreground objects the displacement reaches about 25–30 pixels

% as a result to that we can sat that disparity range is:
% d_min ≈ 0 px
% d_max ≈ 30 px

%% -----------------------------------------------------------------------

% This function computes a disparity map between two stereo images 
% (left and right) 
% A disparity map tells us how much each pixel shifted between the left 
% and right images — and from that shift, we can infer depth.

function D = blockMatching(I1, I2, blocSize, dispMax, seuilContrast)

    I1 = double(I1);
    I2 = double(I2);

    [h, w] = size(I1);

    D = zeros(h, w);

    b2 = floor(blocSize / 2);

    for i = 1 + b2 : h - b2
        for j = 1 + b2 : w - b2

            BL1 = I1(i-b2:i+b2, j-b2:j+b2);

            % Compute local contrast to skip flat regions
            cbloc = (max(BL1(:)) - min(BL1(:))) / max(BL1(:));
            if cbloc < seuilContrast
                continue;   
            end

            bestScore = inf;
            bestDisp  = 0;

            for d = 0 : dispMax
                j2 = j - d;   
                if j2 - b2 < 1
                    break;    
                end

                BL2 = I2(i-b2:i+b2, j2-b2:j2+b2);
                
                score = sum(abs(BL1(:) - BL2(:)));

                if score < bestScore
                    bestScore = score;
                    bestDisp  = d;
                end
            end

            D(i,j) = bestDisp;
        end
    end

    D = uint8(D);

end

D_bm = disparityBM(I1, I2, ...
    'DisparityRange', [0 64], ...
    'BlockSize', 15);

valid = D_bm(D_bm > 0);

minDisp = floor(min(valid(:)));
maxDisp = ceil(max(valid(:)));

fprintf("Estimated disparity range: %d to %d\n", minDisp, maxDisp);

blocSize = 11;
dispMax = maxDisp;
seuilContrast = 0.05;

D = blockMatching(I1, I2, blocSize, dispMax, seuilContrast);

imshow(D, []); colormap jet; colorbar;
title('Disparity Map (Block Matching)');

%% ------------------------------------------------------------------------

% Block Size (blocSize):

% A larger block size will make the disparity estimation more stable and 
% reduces noise but it will also smooth depth boundaries and loses some 
% details.
% small blocks preserve detail but are extremely sensitive to noise and 
% fail in textureless regions so we can sat that this parameter controls 
% the trade-off between detail and robustness.

% Maximum Disparity (dispMax):

% This parameter defines the search range for possible matches so if it is 
% too small then the algorithm cannot find correct matches for foreground 
% objects, which leades to incorrect disparities. 
% On the other hand if it is too large then the computation becomes 
% slower and the number of false matches will increase
% That's why it must be chosen according to the estimated depth range of
% the scene.

% Contrast Threshold (seuilContrast):

% This parameter avoids using blocks with very low texture espicially 
% where matching is unreliable, so higher threshold reduces noise but 
% also increases the number of missing disparities.
% On the other hand a lower threshold provides more dense disparity maps 
% but also increases the number of mismatches in flat regions.


%% -----------------------------------------------------------------------

function D = blockMatching2(I1, I2, blocSize, dispMax, seuilContrast, metric)
% metric: 'SAD', 'SSD', or 'NCC'

    if nargin < 6
        metric = 'SAD';   
    end

    I1 = double(I1);
    I2 = double(I2);

    [h, w] = size(I1);
    D = zeros(h, w);

    b2 = floor(blocSize / 2);

    for i = 1 + b2 : h - b2
        for j = 1 + b2 : w - b2

            BL1 = I1(i-b2:i+b2, j-b2:j+b2);

            cbloc = (max(BL1(:)) - min(BL1(:))) / max(BL1(:));
            if cbloc < seuilContrast
                continue;
            end

            bestScore = inf;
            bestDisp  = 0;

            for d = 0 : dispMax
                j2 = j - d;
                if j2 - b2 < 1
                    break;
                end

                BL2 = I2(i-b2:i+b2, j2-b2:j2+b2);

                switch upper(metric)
                    case 'SAD'
                        score = sum(abs(BL1(:) - BL2(:)));

                    case 'SSD'
                        diff  = BL1(:) - BL2(:);
                        score = sum(diff.^2);

                    case 'NCC'
                        v1 = BL1(:) - mean(BL1(:));
                        v2 = BL2(:) - mean(BL2(:));
                        num = sum(v1 .* v2);
                        den = sqrt(sum(v1.^2) * sum(v2.^2)) + eps;
                        ncc = num / den;   
                        score = -ncc;      

                    otherwise
                        error('Unknown metric %s', metric);
                end

                if score < bestScore
                    bestScore = score;
                    bestDisp  = d;
                end
            end

            D(i,j) = bestDisp;
        end
    end

    D = uint8(D);
end

blocSize = 11;
dispMax = maxDisp;
seuilContrast = 0.05;

D_SAD = blockMatching2(I1, I2, blocSize, dispMax, seuilContrast, 'SAD');
D_SSD = blockMatching2(I1, I2, blocSize, dispMax, seuilContrast, 'SSD');
D_NCC = blockMatching2(I1, I2, blocSize, dispMax, seuilContrast, 'NCC');

figure; imagesc(D_SAD); title('SAD'); axis image; colormap jet; colorbar;
figure; imagesc(D_SSD); title('SSD'); axis image; colormap jet; colorbar;
figure; imagesc(D_NCC); title('NCC'); axis image; colormap jet; colorbar;

% Here I've implemented three similarity measures for block matching: SAD, 
% SSD, and NCC.
% SAD is the simplest and fastest and it gives reasonable results but is 
% sensitive to illumination. 
% but if we considered SSD it behaves similarly but penalizes large 
% intensity differences more strongly, generally producing slightly 
% smoother and sharper disparity maps on this dataset
% NCC being a correlation-based measure is more robust to global brightness
% and contrast changes and tends to give stable matches in textured regions
% but it is computationally more expensive.
% Finally, SSD or NCC usually improves the visual quality of the disparity 
% map compared to SAD, at the cost of increased computation time.

%% ------------------------------------------------------------------------

function D = blockMatching3(I1, I2, blocSize, dispMax, seuilContrast, metric)

    if nargin < 6
        metric = 'SAD';
    end

    I1 = double(I1);
    I2 = double(I2);

    [h, w] = size(I1);

    D = zeros(h, w);

    b2 = floor(blocSize / 2);

    [Gx, Gy] = imgradientxy(I1, 'sobel');
    Gmag = sqrt(Gx.^2 + Gy.^2);

    gradThreshold = 1;  % tune experimentally

    for i = 1 + b2 : h - b2
        for j = 1 + b2 : w - b2

            BL1 = I1(i-b2:i+b2, j-b2:j+b2);

            cbloc = (max(BL1(:)) - min(BL1(:))) / max(BL1(:));
            if cbloc < seuilContrast
                continue;
            end


            patchGrad = Gmag(i-b2:i+b2, j-b2:j+b2);
            if mean(patchGrad(:)) < gradThreshold
                continue;
            end

            bestScore = inf;
            bestDisp  = 0;

            for d = 0 : dispMax
                j2 = j - d;
                if j2 - b2 < 1
                    break;
                end

                BL2 = I2(i-b2:i+b2, j2-b2:j2+b2);

                switch upper(metric)

                    case 'SAD'
                        score = sum(abs(BL1(:) - BL2(:)));

                    case 'SSD'
                        diff = BL1(:) - BL2(:);
                        score = sum(diff.^2);

                    case 'NCC'
                        v1 = BL1(:) - mean(BL1(:));
                        v2 = BL2(:) - mean(BL2(:));
                        num = sum(v1 .* v2);
                        den = sqrt(sum(v1.^2) * sum(v2.^2)) + eps;
                        score = -num / den;

                    otherwise
                        error('Unknown metric: %s', metric);
                end

                if score < bestScore
                    bestScore = score;
                    bestDisp  = d;
                end
            end

            D(i,j) = bestDisp;
        end
    end

    D = uint8(D);
end

clear; clc; close all;

I1 = rgb2gray(imread('im2.ppm'));
I2 = rgb2gray(imread('im6.ppm'));

figure; 
subplot(1,2,1); imshow(I1); title('Left Image');
subplot(1,2,2); imshow(I2); title('Right Image');

dispLarge = [0 64];

D_bm = disparityBM(I1, I2, ...
                   'DisparityRange', dispLarge, ...
                   'BlockSize', 15);

valid = D_bm(D_bm > 0);
minDisp = floor(min(valid(:)));
maxDisp = ceil(max(valid(:)));

fprintf("Estimated disparity range = %d to %d\n", minDisp, maxDisp);

figure;
imshow(D_bm, [minDisp maxDisp]); colormap jet; colorbar;
title('disparityBM (used to estimate max disparity)');

dispMax = maxDisp;

blocSize = 13;
seuilContrast = 0.05;

D_SAD = blockMatching3(I1, I2, blocSize, dispMax, seuilContrast, 'SAD');
D_SSD = blockMatching3(I1, I2, blocSize, dispMax, seuilContrast, 'SSD');
D_NCC = blockMatching3(I1, I2, blocSize, dispMax, seuilContrast, 'NCC');

figure; imagesc(D_SAD); colormap jet; colorbar; axis image;
title('Our BM using SAD');

figure; imagesc(D_SSD); colormap jet; colorbar; axis image;
title('Our BM using SSD');

figure; imagesc(D_NCC); colormap jet; colorbar; axis image;
title('Our BM using NCC');

% Load Ground Truth (Tasks 6,7)

GT = double(imread('disp2.pgm'));

% Middlebury datasets are often scaled x8
if max(GT(:)) > 100
    GT = GT / 8;
end

mask = GT > 0;

MRE_SAD = mean(abs(double(D_SAD(mask)) - GT(mask)) ./ GT(mask));
MRE_SSD = mean(abs(double(D_SSD(mask)) - GT(mask)) ./ GT(mask));
MRE_NCC = mean(abs(double(D_NCC(mask)) - GT(mask)) ./ GT(mask));

fprintf("MRE - SAD = %.4f\n", MRE_SAD);
fprintf("MRE - SSD = %.4f\n", MRE_SSD);
fprintf("MRE - NCC = %.4f\n", MRE_NCC);

E = abs(double(D_SAD) - GT);
figure; imagesc(E); colormap hot; colorbar; axis image;
title('Error map (SAD)');

%% ------------------------------------------------------------------------

function D = blockMatching4(I1, I2, blocSize, dispMax, seuilContrast, metric)

    if nargin < 6
        metric = 'SAD';
    end

    I1 = double(I1);
    I2 = double(I2);

    [h, w] = size(I1);

    D = zeros(h, w);

    b2 = floor(blocSize / 2);

    [Gx, Gy] = imgradientxy(I1, 'sobel');
    Gmag = sqrt(Gx.^2 + Gy.^2);

    gradThreshold = 1;  % tune experimentally

    for i = 1 + b2 : h - b2
        for j = 1 + b2 : w - b2

            BL1 = I1(i-b2:i+b2, j-b2:j+b2);

            cbloc = (max(BL1(:)) - min(BL1(:))) / max(BL1(:));
            if cbloc < seuilContrast
                continue;
            end


            patchGrad = Gmag(i-b2:i+b2, j-b2:j+b2);
            if mean(patchGrad(:)) < gradThreshold
                continue;
            end

            bestScore = inf;
            bestDisp  = 0;

            for d = 0 : dispMax
                j2 = j - d;
                if j2 - b2 < 1
                    break;
                end

                BL2 = I2(i-b2:i+b2, j2-b2:j2+b2);

                switch upper(metric)

                    case 'SAD'
                        score = sum(abs(BL1(:) - BL2(:)));

                    case 'SSD'
                        diff = BL1(:) - BL2(:);
                        score = sum(diff.^2);

                    case 'NCC'
                        v1 = BL1(:) - mean(BL1(:));
                        v2 = BL2(:) - mean(BL2(:));
                        num = sum(v1 .* v2);
                        den = sqrt(sum(v1.^2) * sum(v2.^2)) + eps;
                        score = -num / den;

                    otherwise
                        error('Unknown metric: %s', metric);
                end

                if score < bestScore
                    bestScore = score;
                    bestDisp  = d;
                end
            end

            D(i,j) = bestDisp;
        end
    end

    D = uint8(D);
end

clear; clc; close all;

I1 = rgb2gray(imread('im2.ppm'));
I2 = rgb2gray(imread('im6.ppm'));

figure; 
subplot(1,2,1); imshow(I1); title('Left Image');
subplot(1,2,2); imshow(I2); title('Right Image');

dispLarge = [0 64];

D_bm = disparityBM(I1, I2, ...
                   'DisparityRange', dispLarge, ...
                   'BlockSize', 15);

valid = D_bm(D_bm > 0);
minDisp = floor(min(valid(:)));
maxDisp = ceil(max(valid(:)));

fprintf("Estimated disparity range = %d to %d\n", minDisp, maxDisp);

figure;
imshow(D_bm, [minDisp maxDisp]); colormap jet; colorbar;
title('disparityBM (used to estimate max disparity)');

dispMax = maxDisp;

blocSize = 17;
seuilContrast = 0.01;

D = blockMatching4(I1, I2, blocSize, dispMax, seuilContrast, 'SAD');

if any(isnan(D(:)))
    missing = isnan(D);
    D(missing) = 0;
else
    missing = (D == 0);
end

se = strel('disk', 3);
D_filled = imdilate(D, se);

D_filled = medfilt2(D_filled, [5 5]);

figure;
subplot(1,2,1); imagesc(D); axis image; colorbar; title('Raw disparity');
subplot(1,2,2); imagesc(D_filled); axis image; colorbar; title('After hole filling');

%% --------------------------------------------------------------------------

blocSize      = 17;
dispMax       = 60;        
seuilContrast = 0.05;
tau           = 1;         



G1 = imgradient(im2gray(I1));
G2 = imgradient(im2gray(I2));

D_L = zeros(size(I1));

b2 = floor(blocSize/2);
I1d = double(I1);
I2d = double(I2);

for y = 1+b2 : size(I1,1)-b2
    for x = 1+b2 : size(I1,2)-b2

        BL1 = I1d(y-b2:y+b2, x-b2:x+b2);
        GL1 = G1(y-b2:y+b2, x-b2:x+b2);

        bestScore = inf;
        bestD = 0;

        for d = 0:dispMax
            
            xr = x - d;
            if xr-b2 < 1, break; end

            BL2 = I2d(y-b2:y+b2, xr-b2:xr+b2);
            GL2 = G2(y-b2:y+b2, xr-b2:xr+b2);

            SAD      = sum(abs(BL1(:) - BL2(:)));
            gradSAD  = sum(abs(GL1(:) - GL2(:)));

            score = SAD + 0.5 * gradSAD;

            if score < bestScore
                bestScore = score;
                bestD = d;
            end
        end
        D_L(y,x) = bestD;
    end
end

D_L = uint8(D_L);


D_R = zeros(size(I1));

for y = 1+b2 : size(I1,1)-b2
    for x = 1+b2 : size(I1,2)-b2

        BL2 = I2d(y-b2:y+b2, x-b2:x+b2);
        GL2 = G2(y-b2:y+b2, x-b2:x+b2);

        bestScore = inf;
        bestD = 0;

        for d = 0:dispMax
            
            xl = x + d;   
            if xl+b2 > size(I1,2), break; end

            BL1 = I1d(y-b2:y+b2, xl-b2:xl+b2);
            GL1 = G1(y-b2:y+b2, xl-b2:xl+b2);

            SAD      = sum(abs(BL1(:) - BL2(:)));
            gradSAD  = sum(abs(GL1(:) - GL2(:)));

            score = SAD + 0.5 * gradSAD;

            if score < bestScore
                bestScore = score;
                bestD = d;
            end
        end
        D_R(y,x) = bestD;
    end
end

D_R = uint8(D_R);

D_LR = zeros(size(I1));

for y = 1:size(I1,1)
    for x = 1:size(I1,2)

        dL = D_L(y,x);
        if dL == 0, continue; end

        xr = x - dL;
        if xr < 1 || xr > size(I1,2), continue; end

        dR = D_R(y, xr);

        if abs(double(dL) - double(dR)) <= tau
            D_LR(y,x) = dL;
        end
    end
end


figure;
subplot(1,2,1);
imagesc(D_L,[0 dispMax]); axis image; colormap jet; colorbar;
title('Improved disparity (Left → Right)');

subplot(1,2,2);
imagesc(D_LR,[0 dispMax]); axis image; colormap jet; colorbar;
title('After LR consistency check (Task 10)');

fprintf("Non-zero in D_L : %d\n", nnz(D_L));
fprintf("Non-zero in D_LR: %d\n", nnz(D_LR));

%% -------------------------------------------------------------------------

I1 = rgb2gray(imread('im2.ppm'));
I2 = rgb2gray(imread('im6.ppm'));
I1 = double(I1);
I2 = double(I2);

[h, w] = size(I1);

blocSize = 11;
b2 = floor(blocSize/2);
dispMax = 60;
lambda = 5;       % smoothness weight
numIter = 20;       % iterations for relaxation method

fprintf("Computing cost volume ...\n");

C = zeros(h, w, dispMax+1);

for y = 1+b2 : h-b2
    for x = 1+b2 : w-b2
        BL1 = I1(y-b2:y+b2, x-b2:x+b2);

        for d = 0:dispMax
            xr = x - d;
            if xr-b2 < 1
                break;
            end
            BL2 = I2(y-b2:y+b2, xr-b2:xr+b2);

            C(y,x,d+1) = sum(abs(BL1(:) - BL2(:)));
        end
    end
end

disp('Cost volume done.');

[~, D_init] = min(C, [], 3);
D_init = D_init - 1;   % convert to 0..dispMax

figure; imagesc(D_init); colormap jet; colorbar; axis image;
title('Initial Disparity (Winner Takes All)');


%  METHOD 1 — RELAXATION (ICM-like)

D_relax = D_init;

disp("Running relaxation optimization...");

for iter = 1:numIter
    fprintf("  Iteration %d/%d\n", iter, numIter);

    for y = 2:h-1
        for x = 2:w-1

            bestEnergy = inf;
            bestD = D_relax(y,x);

            for d = 0:dispMax
                dataTerm = C(y,x,d+1);

                neigh = [D_relax(y-1,x), D_relax(y+1,x), ...
                         D_relax(y,x-1), D_relax(y,x+1)];

                smoothTerm = sum(abs(d - neigh));

                E = dataTerm + lambda * smoothTerm;

                if E < bestEnergy
                    bestEnergy = E;
                    bestD = d;
                end
            end

            D_relax(y,x) = bestD;
        end
    end
end

figure;
imagesc(D_relax); colormap jet; colorbar; axis image;
title('Disparity after Relaxation Method');


%  METHOD 2 — DYNAMIC PROGRAMMING (row-wise DP)
D_DP = zeros(h, w);

disp("Running Dynamic Programming optimization...");

for y = 1:h
    DP = zeros(w, dispMax+1);
    Back = zeros(w, dispMax+1);

    DP(1,:) = squeeze(C(y,1,:));

    for x = 2:w
        for d = 0:dispMax
            costs = DP(x-1,:) + lambda * abs((0:dispMax) - d);
            [minCost, idx] = min(costs);

            DP(x, d+1) = C(y,x,d+1) + minCost;
            Back(x, d+1) = idx;   
        end
    end

    [~, best_d] = min(DP(w,:));
    D_DP(y, w) = best_d - 1;

    for x = w-1:-1:1
        best_d = Back(x+1, best_d);
        D_DP(y, x) = best_d - 1;
    end
end

figure;
imagesc(D_DP); colormap jet; colorbar; axis image;
title('Disparity after Dynamic Programming');


%  Display comparison
figure;
subplot(1,3,1);
imagesc(D_init); colormap jet; colorbar; axis image;
title('Initial WTA disparity');

subplot(1,3,2);
imagesc(D_relax); colormap jet; colorbar; axis image;
title('Relaxation result');

subplot(1,3,3);
imagesc(D_DP); colormap jet; colorbar; axis image;
title('Dynamic Programming result');