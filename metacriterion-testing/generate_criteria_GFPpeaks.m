function criteria = generate_criteria_GFPpeaks(TheEEG, nSamples)

    ClusterNumbers = TheEEG.msinfo.ClustPar.MinClasses+1:TheEEG.msinfo.ClustPar.MaxClasses-1;
    maxClusters = size(ClusterNumbers, 2);
    numClustSolutions = numel(ClusterNumbers);

    % Initialize criteria struct
    criteria.G      = nan( 1, maxClusters);     % Gamma
    criteria.S      = nan( 1, maxClusters);     % Silhouette
    criteria.DB     = nan( 1, maxClusters);     % Davies-Bouldin
    criteria.PB     = nan( 1, maxClusters);     % Point-Biserial
    criteria.D      = nan( 1, maxClusters);     % Dunn
    criteria.KL     = nan( 1, maxClusters);     % Krzanowski-Lai
    criteria.CV     = nan( 1, maxClusters);     % Cross-Validation (second derivative)
    criteria.FVG    = nan( 1, maxClusters);     % Frey and Van Groenewoud
    criteria.H      = nan( 1, maxClusters);     % Hartigan (first derivative)
    criteria.TW     = nan( 1, maxClusters);     % Trace(W) (second derivative)
    criteria.CH     = nan( 1, maxClusters);     % Calinski-Harabasz

    % Check for segmented data and reshape if necessary
    IndSamples = TheEEG.data;
    if (numel(size(IndSamples)) == 3)
        nChannels = size(IndSamples, 1);
        % reshape IndSamples
        IndSamples = reshape(IndSamples, nChannels, []);
    end
    
    % Find GFP peaks
    gfp = std(TheEEG.data);
    GFPPeakIndices = find([false (gfp(1,1:end-2) < gfp(1,2:end-1) & gfp(1,2:end-1) > gfp(1,3:end)) false]);
    numGFPPeaks = numel(GFPPeakIndices);

    % Extract random subset of nSamples as input data
    idx = randperm(numGFPPeaks);
    SubsetIndices = GFPPeakIndices(idx(1:nSamples));
    IndSamples = IndSamples(:, SubsetIndices);

    % Average reference input data
%     newRef = eye(nChannels);
%     newRef = newRef - 1/nChannels;
%     IndSamples = newRef*IndSamples;

    % Normalize input data if clusters were identified with normalized data
    if TheEEG.msinfo.ClustPar.Normalize
        IndSamples = NormDimL2(IndSamples,1);
    end

    % Create distance matrix for input data
    DistMat = corr(IndSamples);
    if TheEEG.msinfo.ClustPar.IgnorePolarity
        DistMat = 1 - abs(DistMat);
    else
        DistMat = 1 - DistMat;
    end

    % Initialize mean distance vectors to hold mean distances for all
    % cluster solutions
    meanWithinDists = nan(1, numClustSolutions+1);
    meanBetweenDists = nan(1, numClustSolutions+1);

    for i=1:maxClusters
        nc = ClusterNumbers(i);                 % number of clusters
        
        % Get maps for the current cluster solution, average reference and
        % normalize
        Maps = TheEEG.msinfo.MSMaps(nc).Maps;
        Maps = Maps*newRef;
        Maps = NormDimL2(Maps,2);

        % Assign labels to the input voltage vectors
        Cov = Maps*IndSamples;
        if TheEEG.msinfo.ClustPar.IgnorePolarity
            Cov = abs(Cov);
        end
        [mCov, ClustLabels] = max(Cov);

        %% Extract all within- and between- cluster distances
        IsWithinPair = repmat(ClustLabels(:),1,nTimePoints) == repmat(ClustLabels(:)',nTimePoints,1);
        IsBetweenPair = ~IsWithinPair;
        
        % Remove duplicates and diagonal
        IsWithinPair = triu(IsWithinPair,1);
        IsBetweenPair = triu(IsBetweenPair,1);
        
        DistMat = DistMat(:);
        WithinDistances = DistMat(IsWithinPair(:));
        BetweenDistances = DistMat(IsBetweenPair(:));

        nWithin = numel(WithinDistances);
        nBetween = numel(BetweenDistances);

        %% POINT-BISERIAL
        sumWithin = sum(WithinDistances);
        sumBetween = sum(BetweenDistances);
        sumAll = sumWithin + sumBetween;
        nAll = nSamples*(nSamples-1)/2;

        meanWithinDists(i) = sumWithin/nWithin;
        meanBetweenDists(i) = sumBetween/nBetween;
        meanDist = (sumWithin + sumBetween)/nAll;

        std = sqrt((sumAll - nAll*meanDist^2)/(nAll-1));

        criteria.PB(i) = (meanBetweenDist - meanWithinDist)*sqrt(nWithin*nBetween / nAll^2)/std;

        %% GAMMA
        % Sort distances
        WithinDistances = sort(WithinDistances,'ascend');
        BetweenDistances = sort(BetweenDistances,'descend');

        SmallestBetween = BetweenDistances(end);
        LastGoodWithinIdx = find(WithinDistances < SmallestBetween, 1,'last');
        
        SPlus = LastGoodWithinIdx * nBetween;
        SMinus = 0;
        
        % Catch the perfect case:
        if LastGoodWithinIdx == nWithin
	        return;
        end
        
        % Iterate through the more controversial within distances
        for j = LastGoodWithinIdx + 1:nWithin
	        % Where does the problem start in the sorted between distances? 
	        LastGoodBetweenIdx = find(BetweenDistances > WithinDistances(j), 1,'last');
	        % Up to there, we’re good
            SPlus = SPlus + LastGoodBetweenIdx;
            % From then on, all is bad
	        SMinus = SMinus + (nBetween - (LastGoodBetweenIdx + 1));
        end
    
        criteria.G(i) = (SPlus - SMinus)/(SPlus + SMinus);



    end

    %% FREY AND VAN GROENEWOUD
    nc = ClusterNumbers(end)+1;
        
    % Get maps for the cluster solution one larger than the max, average
    % reference and normalize
    Maps = TheEEG.msinfo.MSMaps(nc).Maps;
    Maps = Maps*newRef;
    Maps = NormDimL2(Maps,2);

    % Assign labels to the input voltage vectors
    Cov = Maps*IndSamples;
    if TheEEG.msinfo.ClustPar.IgnorePolarity
        Cov = abs(Cov);
    end
    [mCov, ClustLabels] = max(Cov);

    % Extract all within- and between-cluster distances for one larger than
    % max cluster solution
    IsWithinPair = repmat(ClustLabels(:),1,nTimePoints) == repmat(ClustLabels(:)',nTimePoints,1);
    IsBetweenPair = ~IsWithinPair;
    
    % Remove duplicates and diagonal
    IsWithinPair = triu(IsWithinPair,1);
    IsBetweenPair = triu(IsBetweenPair,1);
    
    DistMat = DistMat(:);
    WithinDistances = DistMat(IsWithinPair(:));
    BetweenDistances = DistMat(IsBetweenPair(:));

    % Compute mean within- and between- distance for one greater than max
    % cluster solution
    meanWithinDists(end) = mean(WithinDistances);
    meanBetweenDists(end) = mean(BetweenDistances);

    criteria.FVG = (meanBetweenDists(2:end) - meanBetweenDists(1:end-1)) / (meanWithinDists(2:end) - meanWithinDists(1:end-1));

end