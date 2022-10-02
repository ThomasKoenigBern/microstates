function [PB, G] = eeg_GammaPointBiserial(IndSamples, ClustLabels, IgnorePolarity)
    
    % Performs pair-wise computation of 1 - abs(spatial correlation) or 
    % 1 - (spatial correlation) for every pair of columns in matrix A or
    % matrix A and matrix B
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

    % Point-Biserial initializations
    % sum of squares of all pairwise distances in dataset
    SS = 0;    
    % sum of between-cluster correlation distances
    SB = 0;  
    % sum of within-cluster correlation distances
    SW = 0;
    % number of within-cluster pairs
    NW = 0;

    % Gamma initializations
    allWithinPairCorrs = [];
    allBetweenPairCorrs = [];
    splus = 0;
    sminus = 0;

    for i = 1:numClusts
        members = (ClustLabels == clusters(i));
        % pairCorrs is entire matrix of correlations
        pairCorrs = pairCorrDist(IndSamples(:, members));
        % remove double correlations (pairCorrs is symmetric)
        pairCorrs = triu(pairCorrs, 1);
        pairCorrs = pairCorrs(:);
        pairCorrs(pairCorrs == 0) = [];
        allWithinPairCorrs = [allWithinPairCorrs; pairCorrs];

        SW = SW + sum(pairCorrs);
        ni = sum(members);
        NW = NW + ni*(ni-1)/2;    
        SS = SS + sum(pairCorrs.^2);
    end

    % element (i,j) is the corr between the i'th element of first with j'th
    % element of second
    for i = 1:numClusts-1
        for j=i+1:numClusts
            membersi = (ClustLabels == clusters(i));
            membersj = (ClustLabels == clusters(j));
            pairCorrs = pairCorrDist(IndSamples(:, membersi), IndSamples(:, membersj));
            pairCorrs = pairCorrs(:);
            allBetweenPairCorrs = [allBetweenPairCorrs; pairCorrs];
            
            SB = SB + sum(pairCorrs);
            SS = SS + sum(pairCorrs.^2);
        end
    end

    % compute number of total and between-cluster pairs
    n = size(IndSamples, 2);
    NT = n*(n-1)/2;
    NB = NT - NW;
    
    % compute mean sum of within- and between-cluster distances
    meanSW = SW/NW;
    meanSB = SB/NB;

    % use mean correlation distance and sum of squares of distances to
    % compute standard deviation across ALL distances
    meanCorrDist = (SW + SB)/NT;
    sd = sqrt((SS - NT*meanCorrDist^2)/(NT-1));
    
    % compute Point-Biserial index
    PB = (meanSB - meanSW)*sqrt((NW*NB)/(NT*NT))/sd;

    % compute splus and sminus
    % splus = number of times 2 points not clustered together have a larger
    % distance than 2 points in the same cluster
    % sminus = number of times 2 points not clustered together have a
    % smaller distance than 2 points in the same cluster
    parfor i=1:length(allBetweenPairCorrs)
        splus = splus + sum(allBetweenPairCorrs(i) > allWithinPairCorrs);
        sminus = sminus + sum(allBetweenPairCorrs(i) < allWithinPairCorrs);
    end

    % compute Gamma index
    G = (splus - sminus)/(splus + sminus);
end