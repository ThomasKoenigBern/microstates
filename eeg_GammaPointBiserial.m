function [PB, G] = eeg_GammaPointBiserial(IndSamples, ClustLabels, IgnorePolarity)
    
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

    % sum of squares of all pairwise distances in dataset
    SS = 0;
    
    % sum of between-cluster correlation distances
    SB = 0;
    
    % sum of within-cluster correlation distances
    SW = 0;

    % number of within-cluster pairs
    NW = 0;

%     max_dists = zeros(numClusts, 1);
%     s_plus = zeros(numClusts, 1);
%     s_minus = zeros(numClusts, 1);

    allWithinPairCorrs = [];

    for i = 1:numClusts
        members = (ClustLabels == clusters(i));
        %pairCorrs is entire matrix of correlations
        pairCorrs = pairCorrDist(IndSamples(:, members));
        pairCorrs = triu(pairCorrs, 1);
        pairCorrs = pairCorrs(:);
        pairCorrs(pairCorrs == 0) = [];
        allWithinPairCorrs = [allWithinPairCorrs; pairCorrs];
        
        % find the max dist in pairCorrs
%         max_dists(i) = max(pairCorrs);

        SW = SW + sum(pairCorrs);
        ni = sum(members);
        NW = NW + ni*(ni-1)/2;
        
        SS = SS + sum(pairCorrs.^2);
    end
    
    splus = 0;
    sminus = 0;

    allBetweenPairCorrs = [];

    % element (i,j) is the corr between the i'th element of first with j'th
    % element of second
    for i = 1:numClusts-1
%         this_max_dist = max_dists(i);
        for j=i+1:numClusts
            membersi = (ClustLabels == clusters(i));
            membersj = (ClustLabels == clusters(j));
            pairCorrs = pairCorrDist(IndSamples(:, membersi), IndSamples(:, membersj));
            pairCorrs = triu(pairCorrs, 1);
            pairCorrs = pairCorrs(:);
            pairCorrs(pairCorrs == 0) = [];
            allBetweenPairCorrs = [allBetweenPairCorrs; pairCorrs];

%             s_plus(i) = sum(sum(pairCorrs > this_max_dist));
            %           s_minus(i) = sum(sum(pairCorrs < this_max_dist));
%             s_minus(i) = numel(pairCorrs)-s_plus(i);
            
%             parfor k=1:length(pairCorrs)
%                 splus = splus + sum(pairCorrs(k) > allWithinPairCorrs);
%                 sminus = sminus + sum(pairCorrs(k) < allWithinPairCorrs);
%             end

%             splus = splus + sum(arrayfun(@(x) sum(x > allWithinPairCorrs), pairCorrs));
%             sminus = sminus + sum(arrayfun(@(x) sum(x < allWithinPairCorrs), pairCorrs));
            
            SB = SB + sum(pairCorrs);
            
            SS = SS + sum(pairCorrs.^2);
        end
    end

    % use within-cluster and between-cluster pairwise distances to compute
    % Gamma
    parfor i=1:length(allBetweenPairCorrs)
        splus = splus + sum(allBetweenPairCorrs(i) > allWithinPairCorrs);
        sminus = sminus + sum(allBetweenPairCorrs(i) < allWithinPairCorrs);
    end

    G = (splus - sminus)/(splus + sminus);
%     gamma = (sum(s_plus) - sum(s_minus))/(sum(s_plus) + sum(s_minus));

    n = size(IndSamples, 2);
    NT = n*(n-1)/2;
    NB = NT - NW;
    
    meanSW = SW/NW;
    meanSB = SB/NB;

    meanCorrDist = (SW + SB)/NT;
    sd = sqrt((SS - NT*meanCorrDist^2)/(NT-1));
    
    PB = (meanSB - meanSW)*sqrt((NW*NB)/(NT*NT))/sd;
end