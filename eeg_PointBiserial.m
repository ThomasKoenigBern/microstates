function PB = eeg_PointBiserial(IndSamples, ClustLabels, IgnorePolarity)
    
    % Performs pair-wise computation of 1 - abs(spatial correlation) or 
    % 1 - (spatial correlation) for every pair of columns in matrix A
    function corrDist = pairCorrDist(A,B)
        if (nargin < 2)
            c = corr(A);
        else
            c = corr(A,B);
        end
        if (IgnorePolarity) 
            corrDist = 1 - abs(c);
        else 
            corrDist = 1 - c; 
        end
    end

    clusters = unique(ClustLabels);
    numClusts = length(clusters);
    if numClusts == 1
        PB = nan;
        return;
    end

    SS = 0;         % sum of squares of all pairwise distances in dataset
%     allCorrDists = zeros(NT, 1, 'single');
%     idx = 1;
    
    % sum of between-cluster correlation distances
    SB = 0;
    for i = 1:numClusts-1
      for j=i+1:numClusts
          membersi = (ClustLabels == clusters(i));
          membersj = (ClustLabels == clusters(j));
          pairCorrs = pairCorrDist(IndSamples(:, membersi), IndSamples(:, membersj));
          SB = SB + sum(sum(pairCorrs));
          
          SS = SS + sum(sum(pairCorrs.^2));
%           allCorrDists(idx:idx+numel(pairCorrs)-1, :) = reshape(pairCorrs, [numel(pairCorrs), 1]);
%           idx = idx + numel(pairCorrs);
      end
    end
    
    % sum of within-cluster correlation distances
    SW = zeros(numClusts, 1);
    NW = zeros(numClusts, 1);
    for i = 1:numClusts
        members = (ClustLabels == clusters(i));
        pairCorrs = pairCorrDist(IndSamples(:, members));
        SW(i) = sum(sum(triu(pairCorrs, 1)));
        ni = sum(members);
        NW(i) = ni*(ni-1)/2;
        
        SS = SS + sum(sum(triu(pairCorrs, 1).^2));
%         pairCorrs = triu(pairCorrs, 1);
%         pairCorrs = reshape(pairCorrs, [numel(pairCorrs), 1]);
%         zeroIndices = ~pairCorrs;
%         pairCorrs(zeroIndices) = [];
%         allCorrDists(idx:idx+numel(pairCorrs)-1,:) = pairCorrs;
%         idx = idx + numel(pairCorrs);
    end

%     sd = std(allCorrDists);
    SW = sum(SW);
    NW = sum(NW);
    
    n = size(IndSamples, 2);
    NT = n*(n-1)/2;
    NB = NT - NW;
    
    meanSW = SW/NW;
    meanSB = SB/NB;
    
%     allCorrDists = triu(pairCorrDist(IndSamples),1);
%     allCorrDists = reshape(allCorrDists, [numel(allCorrDists), 1]);
%     zeroIndices = ~allCorrDists;
%     allCorrDists(zeroIndices) = [];
%     sd = std(allCorrDists);

    meanCorrDist = (SW + SB)/NT;
    sd = sqrt((SS - NT*meanCorrDist^2)/(NT-1));
    
    PB = (meanSB - meanSW)*sqrt((NW*NB)/(NT*NT))/sd;
end