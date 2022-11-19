function [criteria, numGFPPeaks] = generate_criteria_GFPpeaks(TheEEG, nSamples)

    ClusterNumbers = TheEEG.msinfo.ClustPar.MinClasses+1:TheEEG.msinfo.ClustPar.MaxClasses-1;
    numClustSolutions = numel(ClusterNumbers);

    % Initialize criteria struct array
    criteria(1).name   = 'G';          % Gamma
    criteria(2).name   = 'S';          % Silhouette
    criteria(3).name   = 'DB';         % Davies-Bouldin
    criteria(4).name   = 'PB';         % Point-Biserial
    criteria(5).name   = 'D';          % Dunn
    criteria(6).name   = 'KL';         % Krzanowski-Lai
    criteria(7).name   = 'KLnrm';      % Normalized Krzanowski-Lai
    criteria(8).name   = 'CV';         % Cross-Validation
    criteria(9).name   = 'CV2';        % Cross-Validation v2
    criteria(10).name  = 'FVG';        % Frey and Van Groenewoud
    criteria(11).name  = 'CH';         % Calinski-Harabasz

    criteria(1).values  = nan(1, numClustSolutions);
    criteria(2).values  = nan(1, numClustSolutions);
    criteria(3).values  = nan(1, numClustSolutions);
    criteria(4).values  = nan(1, numClustSolutions);
    criteria(5).values  = nan(1, numClustSolutions);
    criteria(6).values  = nan(1, numClustSolutions);
    criteria(7).values  = nan(1, numClustSolutions);
    criteria(8).values  = nan(1, numClustSolutions);
    criteria(9).values  = nan(1, numClustSolutions);
    criteria(10).values = nan(1, numClustSolutions);
    criteria(11).values = nan(1, numClustSolutions);

    % Check for segmented data and reshape if necessary
    IndSamples = TheEEG.data;
    nChannels = size(IndSamples, 1);    
    if (numel(size(IndSamples)) == 3)
        % reshape IndSamples
        IndSamples = reshape(IndSamples, nChannels, []);
    end
    
    % Find GFP peaks
    gfp = std(IndSamples);
    GFPPeakIndices = find([false (gfp(1,1:end-2) < gfp(1,2:end-1) & gfp(1,2:end-1) > gfp(1,3:end)) false]);
    numGFPPeaks = numel(GFPPeakIndices);

    % Extract an nSamples random subset of the GFP peaks as input data
    if nSamples ~= inf
        if nSamples < numGFPPeaks
            idx = randperm(numGFPPeaks);
            SubsetIndices = GFPPeakIndices(idx(1:nSamples));
            IndSamples = IndSamples(:, SubsetIndices);
        else
            criteria = [];
            return;
        end
    else
        IndSamples = IndSamples(:, GFPPeakIndices);
        nSamples = numGFPPeaks;
    end

    % Average reference input data (?)
%     newRef = eye(nChannels);
%     newRef = newRef - 1/nChannels;
%     IndSamples = newRef*IndSamples;

    % Normalize input data if clusters were identified with normalized data
    if TheEEG.msinfo.ClustPar.Normalize
        IndSamples = NormDimL2(IndSamples,1);
    end

    % Create distance matrix for input data
    % can change distance measure to DISS, Euclidean, etc.
    DistMat = corr(IndSamples);
    if TheEEG.msinfo.ClustPar.IgnorePolarity
        DistMat = 1 - abs(DistMat);
    else
        DistMat = 1 - DistMat;
    end

    % Find sum of all pairwise distances in the input data, the total
    % number of pairs, and the standard deviation of all pairwise distances
    % (for PB)
    sumAllDists = sum(sum(triu(DistMat,1)));
    nAll = nSamples*(nSamples-1)/2;
    meanDist = sumAllDists/nAll;
    stdev = sqrt((sumAllDists - nAll*meanDist^2)/(nAll-1));

    % Data mean (for CH)
    DataMean = mean(IndSamples, 2);

    % Initialize mean distance vectors to hold mean distances for all
    % cluster solutions (for FVG)
    meanWithinDists = nan(1, numClustSolutions+1);
    meanBetweenDists = nan(1, numClustSolutions+1);

    % Initialize W and M vectors (for KL)
    W = nan(1, numClustSolutions+2);            % dispersion for each cluster solution
    M = nan(1, numClustSolutions+2);            % scaled dispersion values

    %% Get maps and cluster labels for one less than min cluster solution
    nc = ClusterNumbers(1)-1;
    [Maps, ClustLabels] = getClusters(TheEEG, nc, IndSamples);

    % Extract all within-cluster distances for one less than min solution
    [WithinDistances, ~, WithinPairLabels] = getWithinAndBetweenDistances(ClustLabels, DistMat);

    % Get W and M for one less than min cluster solution (for KL)
    sumD = nan(1, nc);                          % sum of pairwise distances for each cluster
    nMembers = zeros(1, nc);                    % number of members of each cluster

    for c=1:nc
        sumD(c) = sum(WithinDistances(WithinPairLabels == c));
        nMembers(c) = sum(ClustLabels == c);       
    end

    W(1) = sum(sumD./(2*nMembers));
    M(1) = W(1)*nc^(2/nChannels);

    for i=1:numClustSolutions
        nc = ClusterNumbers(i);                 % number of clusters
        [Maps, ClustLabels] = getClusters(TheEEG, nc, IndSamples);

        %% Extract all within- and between- cluster distances and other measures
        [WithinDistances, BetweenDistances, WithinPairLabels, IsWithinPair, BetweenPairLabels] = getWithinAndBetweenDistances(ClustLabels, DistMat);

        sumD = nan(1, nc);                      % sum of pairwise distances for each cluster
        nMembers= zeros(1, nc);                 % number of members of each cluster

        sumMemberCentroidDists = nan(1, nc);    % sum of distances between cluster members and centroid (microstate map)
        clustDiameters = nan(1,nc);             % cluster diameters (maximum within-cluster distance for each cluster )

        for c=1:nc
            sumD(c) = sum(WithinDistances(WithinPairLabels == c));
            nMembers(c) = sum(ClustLabels == c);

            % Extract distances between cluster members and microstate maps
            Map = Maps(:, c);
            ClustMembers = IndSamples(:, ClustLabels == c);
            memberCentroidDists = elementCorrDist(ClustMembers,Map,TheEEG.msinfo.ClustPar.IgnorePolarity);
            sumMemberCentroidDists(c) = sum(memberCentroidDists);

            clustDiameters(c) = max(WithinDistances(WithinPairLabels == c));
        end
    
        %% Get W and M (for KL)
        W(i+1) = sum(sumD./(2*nMembers));
        M(i+1) = W(i+1)*nc^(2/nChannels);

        %% POINT-BISERIAL
        nWithin = numel(WithinDistances);
        nBetween = numel(BetweenDistances);

        sumWithin = sum(WithinDistances);
        sumBetween = sum(BetweenDistances);

        meanWithinDists(i) = sumWithin/nWithin;
        meanBetweenDists(i) = sumBetween/nBetween;

        criteria(matches({criteria.name}, 'PB')).values(i) = (meanBetweenDists(i) - meanWithinDists(i))*sqrt(nWithin*nBetween / nAll^2)/stdev;

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
        tic
        for j = LastGoodWithinIdx + 1:nWithin
	        % Where does the problem start in the sorted between distances? 
	        LastGoodBetweenIdx = find(BetweenDistances > WithinDistances(j), 1,'last');
	        % Up to there, we’re good
            SPlus = SPlus + LastGoodBetweenIdx;
            % From then on, all is bad
	        SMinus = SMinus + (nBetween - (LastGoodBetweenIdx + 1));
        end
        toc
    
        criteria(matches({criteria.name}, 'G')).values(i) = (SPlus - SMinus)/(SPlus + SMinus);

        %% CALINSKI-HARABASZ
        WithinClustVar = sum(sumMemberCentroidDists);
        BetweenClustVar = elementCorrDist(Maps, DataMean, TheEEG.msinfo.ClustPar.IgnorePolarity);
        BetweenClustVar = sum(nMembers.*BetweenClustVar);
        criteria(matches({criteria.name}, 'CH')).values(i) =  (BetweenClustVar/WithinClustVar)*((nSamples-nc)/(nc-1));

        %% DAVIES-BOULDIN
        MeanMemberCentroidDists = sumMemberCentroidDists./nMembers;

        % Create matrix of cluster centroid distances
        CentroidDistMat = corr(Maps);
        if TheEEG.msinfo.ClustPar.IgnorePolarity
            CentroidDistMat = 1 - abs(CentroidDistMat);
        else
            CentroidDistMat = 1 - CentroidDistMat;
        end

        % Get within-to-between cluster distance ratios for all cluster
        % pairs
        R = zeros(nc);
        for j=1:nc
            for k=j+1:nc
                R(j,k) = (MeanMemberCentroidDists(j) + MeanMemberCentroidDists(k))/CentroidDistMat(j,k);
            end
        end
        R = R+R';

        RI = max(R, [], 1);
        criteria(matches({criteria.name}, 'DB')).values(i) = mean(RI);

        %% SILHOUETTE
        % Average distance from each input vector to all other members
        % in its cluster
        AvgWithinDists = nan(1,nSamples);
        % Average distance from each input vector to members in other
        % clusters
        AvgBetweenDists = nan(nc,nSamples);

        for n=1:nSamples
            AvgWithinDists(n) = mean(DistMat(n, IsWithinPair(n,:)));
            for clust=1:nc
                AvgBetweenDists(nc, n) = mean(DistMat(n, ~IsWithinPair(n,:)));
            end
        end

        minAvgBetweenDist = min(AvgBetweenDists, [], 1);
        criteria(matches({criteria.name}, 'S')).values(i) =  mean((minAvgBetweenDist - AvgWithinDists)./max(minAvgBetweenDist, AvgWithinDists));

        %% DUNN
        minInterClustDists = [];
        % Get minimum distance between each pair of clusters
        for j=1:nc
            for k=j+1:nc
                BetweenClustIndices = logical(matches(BetweenPairLabels, string(j) + string(k)) + matches(BetweenPairLabels, string(k) + string(j)));
                minInterClustDists = [minInterClustDists min(BetweenDistances(BetweenClustIndices))];
            end
        end

        criteria(matches({criteria.name}, 'D')).values(i) =  min(minInterClustDists)/max(clustDiameters);

        %% CROSS-VALIDATION
        % original definition in Pascual-Marqui 1995
        sigma2 = sum(sum(IndSamples.^2) -  sum(Maps(:, ClustLabels).*IndSamples).^2);
        criteria(matches({criteria.name}, 'CV')).values(i) =  sigma2*((nChannels-1)/(nChannels-1-nc))^2;

        % CV version 2 testing
        % modified to use 1 - spatial correlation or 1 - abs(spatial
        % correlation) rather than squared Euclidean distance to allow for
        % both respecting and ignoring polarity
        sigma = sum(sumMemberCentroidDists)/(nSamples*(nChannels-1));
        criteria(matches({criteria.name}, 'CV2')).values(i) =  sigma*((nChannels-1)/(nChannels-1-nc))^2;
    end

    %% Get maps and cluster labels for one greater than max cluster solution
    nc = ClusterNumbers(end)+1;
    [Maps, ClustLabels] = getClusters(TheEEG, nc, IndSamples);

    % Extract all within- and between-cluster distances for one larger than
    % max cluster solution
    [WithinDistances, BetweenDistances, WithinPairLabels] = getWithinAndBetweenDistances(ClustLabels, DistMat);

    %% FREY AND VAN GROENEWOUD
    % Compute mean within- and between- distance for one greater than max
    % cluster solution
    meanWithinDists(end) = mean(WithinDistances);
    meanBetweenDists(end) = mean(BetweenDistances);

    criteria(matches({criteria.name}, 'FVG')) = (meanBetweenDists(2:end) - meanBetweenDists(1:end-1)) ./ (meanWithinDists(2:end) - meanWithinDists(1:end-1));

    %% KRZANOWSKI-LAI/NORMALIZED KRZANOWSKI-LAI
    % Get W and M for one greater than max cluster solution
    sumD = nan(1, nc);                          % sum of pairwise distances for each cluster
    nMembers = zeros(1, nc);                    % number of members of each cluster

    for c=1:nc
        sumD(c) = sum(WithinDistances(WithinPairLabels == c));
        nMembers(c) = sum(ClustLabels == c);
    end

    W(end) = sum(sumD./(2*nMembers));
    M(end) = W(end)*nc^(2/nChannels);
    
    d = M(1:end-1) - M(2:end);

    % KL
    criteria(matches({criteria.name}, 'KL')) = abs(d(1:end-1)./d(2:end));

    % KLnrm
    KLnrm = (d(1:end-1) - d(2:end)) ./ M(1:end-2);
    KLnrm((d < 0)) = 0;
    KLnrm((d(1:end-1) < d(2:end))) = 0;
    criteria(matches({criteria.name}, 'KLnrm')) = KLnrm;

    % Normalize criteria
    for i=1:numel(criteria)
        c = criteria(i).values;

        if strcmp(criteria(i).name, 'DB') || strcmp(criteria(i).name, 'CV') || strcmp(criteria(i).name, 'CV2')
            c = (c - min(c))/(max(c)-min(c));
            c = 1 - c;
        elseif strcmp(criteria(i).name, 'FVG')
            c = abs(1-c);
            c = (c - min(c))/(max(c) - min(c));
            c = 1 - c;
        else
            % Normalize
            c = (c - min(c))/(max(c) - min(c));
        end

        criteria(i).normValues = c;
    end

end

function [Maps, ClustLabels] = getClusters(TheEEG, nc, IndSamples)       
    % Get maps for the specified cluster solution, average reference and
    % normalize
    Maps = TheEEG.msinfo.MSMaps(nc).Maps;
    nChannels = size(Maps,2);
    newRef = eye(nChannels);
    newRef = newRef - 1/nChannels;
    IndSamples = newRef*IndSamples;
    Maps = Maps*newRef;
    Maps = NormDimL2(Maps,2);

    % Assign labels to the input voltage vectors
    Cov = Maps*IndSamples;
    if TheEEG.msinfo.ClustPar.IgnorePolarity
        Cov = abs(Cov);
    end
    [mCov, ClustLabels] = max(Cov);
     Maps = Maps';
end

function [WithinDistances, BetweenDistances, WithinPairLabels, IsWithinPairOut, BetweenClustLabels] = getWithinAndBetweenDistances(ClustLabels, DistMat)
        % Find (i,j) indices of within- and between- cluster pairs
        PairLabels = repmat(ClustLabels,size(DistMat, 1),1);
        IsWithinPair = PairLabels == PairLabels';
        IsBetweenPair = ~IsWithinPair;

        IsWithinPairOut = IsWithinPair;
        
        % Remove duplicates and diagonal
        IsWithinPair = triu(IsWithinPair,1);
        IsBetweenPair = triu(IsBetweenPair,1);
        
        % Extract within- and between-cluster distances
        WithinDistances = DistMat(IsWithinPair);
        BetweenDistances = DistMat(IsBetweenPair);

        % Get cluster labels that each within-cluster distance belongs to
        WithinPairLabels = PairLabels(IsWithinPair);

        % Create string labels to denote which 2 clusters the
        % between-cluster distances are from
        stringPairLabels1 = string(PairLabels);
        stringPairLabels2 = stringPairLabels1';
        BetweenClustLabels = stringPairLabels1(IsBetweenPair) + stringPairLabels2(IsBetweenPair);
end

% Performs element-wise computation of 1 - abs(spatial correlation) or 
% 1 - (spatial correlation) between matrices A and B or matrix A and vector
% B
function corrDist = elementCorrDist(A,B,IgnorePolarity)
    % average reference
    nChannels = size(A, 1);
    newRef = eye(nChannels);
    newRef = newRef - 1/nChannels;
    A = newRef*A;
    B = newRef*B;

    % normalize
    A = NormDimL2(A, 1);
    B = NormDimL2(B, 1);

    % get correlation
    corr = sum(A.*B, 1);           

    % corr dist
    if (IgnorePolarity) 
        corrDist = 1 - abs(corr);
    else 
        corrDist = 1 - corr; 
    end
end