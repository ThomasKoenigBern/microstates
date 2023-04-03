function G = eeg_Gamma_optimized(IndSamples, ClustLabels, IgnorePolarity)
    
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

    DistMat = pairCorrDist(IndSamples);
    nTimePoints = size(IndSamples, 2);
    IsWithinPair = repmat(ClustLabels(:),1,nTimePoints) == repmat(ClustLabels(:)',nTimePoints,1);
    IsBetweenPair = ~IsWithinPair;
    
    % Now we still need to get rid of the duplicates and the diagonal
    IsWithinPair = triu(IsWithinPair,1);
    IsBetweenPair = triu(IsBetweenPair,1);
    
    DistMat = DistMat(:);
    WithinDistances = DistMat(IsWithinPair(:));
    BetweenDistances = DistMat(IsBetweenPair(:));

    % Done, but for the rest of the job, sorting is a good idea:
    SortedWithinDistances = sort(WithinDistances,'ascend');
    SortedBetweenDistances = sort(BetweenDistances,'descend');
    
    % and some helper variables:
    nWithinDistances = numel(SortedWithinDistances);
    nBetweenDistances = numel(SortedBetweenDistances);

    % This is for getting S+ and S- faster, hopefully…
    % First, we can pick out the easy cases of within distances smaller than all between distances:
    SmallestBetweenDistance = SortedBetweenDistances(end);
    LastUnproblematicWithinDistanceIdx = find(SortedWithinDistances < SmallestBetweenDistance,1,'last');
    
    SPlus = LastUnproblematicWithinDistanceIdx * nBetweenDistances;
    SMinus = 0;
    
    % Catch the perfect case:
    if LastUnproblematicWithinDistanceIdx == nWithinDistances
	    return;
    end
    
    % Now we iterate through the more controversial within distances
    for i = LastUnproblematicWithinDistanceIdx + 1:nWithinDistances
	    % Where does the problem start in the sorted between distances? 
	    LastUnproblematicBetweenDistanceIdx = find(SortedBetweenDistances > SortedWithinDistances(i),1,'last');
	    % Up to there, we’re good
        SPlus = SPlus + LastUnproblematicBetweenDistanceIdx;
        % From then on, all is bad
	    SMinus = SMinus + (nBetweenDistances - (LastUnproblematicBetweenDistanceIdx +1));
    end

    G = (SPlus - SMinus)/(SPlus + SMinus);
end