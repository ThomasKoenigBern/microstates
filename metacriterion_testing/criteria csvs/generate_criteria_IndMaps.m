function criteria = generate_criteria_IndMaps(msinfo, IndSamples)

    ClusterNumbers = msinfo.ClustPar.MinClasses+1:msinfo.ClustPar.MaxClasses-1;
    maxClusters = size(ClusterNumbers, 2);
    numClustSolutions = numel(ClusterNumbers);
    nSamples = size(IndSamples,2);
    nChannels = size(IndSamples,1);

    % Initialize criteria vectors
%     criteriaVectors.G     = nan(1, numClustSolutions);
%     criteriaVectors.S     = nan(1, numClustSolutions);
    criteriaVectors.DB    = nan(1, numClustSolutions);
    criteriaVectors.PB    = nan(1, numClustSolutions);
    criteriaVectors.D     = nan(1, numClustSolutions);
    criteriaVectors.KL    = nan(1, numClustSolutions);
    criteriaVectors.KLnrm = nan(1, numClustSolutions);
    criteriaVectors.CV    = nan(1, numClustSolutions);
    criteriaVectors.FVG   = nan(1, numClustSolutions);
    % CV version 2 testing
%     criteriaVectors.CV2    = nan(1, numClustSolutions);    
%     criteriaVectors.CH    = nan(1, numClustSolutions);

    % Initialize criteria struct
%     criteria(1).criterionName   = 'G';          % Gamma
%     criteria(1).criterionName   = 'S';          % Silhouette
    criteria(1).criterionName   = 'DB';         % Davies-Bouldin
    criteria(2).criterionName   = 'PB';         % Point-Biserial
    criteria(3).criterionName   = 'D';          % Dunn
    criteria(4).criterionName   = 'KL';         % Krzanowski-Lai
    criteria(5).criterionName   = 'KLnrm';      % Normalized Krzanowski-Lai
    criteria(6).criterionName  = 'CV';         % Cross-Validation
    % CV version 2 testing
%     criteria(8).criterionName  = 'CV2';         % Cross-Validation
    criteria(7).criterionName  = 'FVG';        % Frey and Van Groenewoud
%     criteria(10).criterionName  = 'CH';         % Calinski-Harabasz

    % Average reference input data (?)
%     newRef = eye(nChannels);
%     newRef = newRef - 1/nChannels;
%     IndSamples = newRef*IndSamples;

    % Normalize input data if clusters were identified with normalized data
    if msinfo.ClustPar.Normalize
        IndSamples = NormDimL2(IndSamples,1);
    end

    % Create distance matrix for input data
    DistMat = corr(IndSamples);
    if msinfo.ClustPar.IgnorePolarity
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
%     DataMean = mean(IndSamples, 2);

    % Initialize mean distance vectors to hold mean distances for all
    % cluster solutions (for FVG)
    meanWithinDists = nan(1, numClustSolutions+1);
    meanBetweenDists = nan(1, numClustSolutions+1);

    % Initialize W and M vectors (for KL)
    W = nan(1, numClustSolutions+2);            % dispersion for each cluster solution
    M = nan(1, numClustSolutions+2);            % scaled dispersion values

    %% Get maps and cluster labels for one less than min cluster solution
    nc = ClusterNumbers(1)-1;
    [Maps, ClustLabels] = getClusters(msinfo, nc, IndSamples);

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

    for i=1:maxClusters
        nc = ClusterNumbers(i);                 % number of clusters
        [Maps, ClustLabels] = getClusters(msinfo, nc, IndSamples);

        %% Extract all within- and between- cluster distances and other measures
        [WithinDistances, BetweenDistances, WithinPairLabels, IsWithinPair, BetweenPairLabels] = getWithinAndBetweenDistances(ClustLabels, DistMat);

        sumD = nan(1, nc);                      % sum of pairwise distances for each cluster
        nMembers= zeros(1, nc);                 % number of members of each cluster

        sumMemberCentroidDists = nan(1, nc);    % sum of distances between cluster members and centroid (microstate map)
        clustDiameters = nan(1,nc);        % cluster diameters (maximum within-cluster distance for each cluster )

        for c=1:nc
            sumD(c) = sum(WithinDistances(WithinPairLabels == c));
            nMembers(c) = sum(ClustLabels == c);

            % Extract distances between cluster members and microstate maps
            Map = Maps(:, c);
            ClustMembers = IndSamples(:, ClustLabels == c);
            memberCentroidDists = elementCorrDist(ClustMembers,Map,msinfo.ClustPar.IgnorePolarity);
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

        criteriaVectors.PB(i) = (meanBetweenDists(i) - meanWithinDists(i))*sqrt(nWithin*nBetween / nAll^2)/stdev;

        %% GAMMA
%         % Sort distances
%         WithinDistances = sort(WithinDistances,'ascend');
%         BetweenDistances = sort(BetweenDistances,'descend');
% 
%         SmallestBetween = BetweenDistances(end);
%         LastGoodWithinIdx = find(WithinDistances < SmallestBetween, 1,'last');
%         
%         SPlus = LastGoodWithinIdx * nBetween;
%         SMinus = 0;
%         
%         % Catch the perfect case:
%         if LastGoodWithinIdx == nWithin
% 	        return;
%         end
%         
%         % Iterate through the more controversial within distances
%         tic
%         for j = LastGoodWithinIdx + 1:nWithin
% 	        % Where does the problem start in the sorted between distances? 
% 	        LastGoodBetweenIdx = find(BetweenDistances > WithinDistances(j), 1,'last');
% 	        % Up to there, we’re good
%             SPlus = SPlus + LastGoodBetweenIdx;
%             % From then on, all is bad
% 	        SMinus = SMinus + (nBetween - (LastGoodBetweenIdx + 1));
%         end
%         toc
%     
%         criteriaVectors.G(i) = (SPlus - SMinus)/(SPlus + SMinus);

        %% CALINSKI-HARABASZ
%         WithinClustVar = sum(sumMemberCentroidDists);
%         BetweenClustVar = elementCorrDist(Maps, DataMean, msinfo.ClustPar.IgnorePolarity);
%         BetweenClustVar = sum(nMembers.*BetweenClustVar);
%         criteriaVectors.CH(i) = (BetweenClustVar/WithinClustVar)*((nSamples-nc)/(nc-1));

        %% DAVIES-BOULDIN
        MeanMemberCentroidDists = sumMemberCentroidDists./nMembers;

        % Create matrix of cluster centroid distances
        CentroidDistMat = corr(Maps);
        if msinfo.ClustPar.IgnorePolarity
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
        criteriaVectors.DB(i) = mean(RI);

        %% SILHOUETTE
%         % Average distance from each input vector to all other members
%         % in its cluster
%         AvgWithinDists = nan(1,nSamples);
%         % Average distance from each input vector to members in other
%         % clusters
%         AvgBetweenDists = nan(nc,nSamples);
% 
%         for n=1:nSamples
%             AvgWithinDists(n) = mean(DistMat(n, IsWithinPair(n,:)));
%             for clust=1:nc
%                 AvgBetweenDists(nc, n) = mean(DistMat(n, ~IsWithinPair(n,:)));
%             end
%         end
% 
%         minAvgBetweenDist = min(AvgBetweenDists, [], 1);
%         criteriaVectors.S(i) = mean((minAvgBetweenDist - AvgWithinDists)./max(minAvgBetweenDist, AvgWithinDists));

        %% DUNN
        minInterClustDists = [];
        % Get minimum distance between each pair of clusters
        for j=1:nc
            for k=j+1:nc
                BetweenClustIndices = logical(matches(BetweenPairLabels, string(j) + string(k)) + matches(BetweenPairLabels, string(k) + string(j)));
                minInterClustDists = [minInterClustDists min(BetweenDistances(BetweenClustIndices))];
            end
        end

        criteriaVectors.D(i) = min(minInterClustDists)/max(clustDiameters);

        %% CROSS-VALIDATION
        % modified to use 1 - spatial correlation or 1 - abs(spatial
        % correlation) rather than squared Euclidean distance to allow for
        % both respecting and ignoring polarity
%         sigma = sum(sumMemberCentroidDists)/(nSamples*(nChannels-1));
%         criteriaVectors.CV(i) = sigma*((nChannels-1)/(nChannels-1-nc))^2;

        % CV version 2 testing
        sigma2 = sum(sum(IndSamples.^2) -  sum(Maps(:, ClustLabels).*IndSamples).^2);
        criteriaVectors.CV(i) = sigma2*((nChannels-1)/(nChannels-1-nc))^2;
    end

    %% Get maps and cluster labels for one greater than max cluster solution
    nc = ClusterNumbers(end)+1;
    [Maps, ClustLabels] = getClusters(msinfo, nc, IndSamples);

    % Extract all within- and between-cluster distances for one larger than
    % max cluster solution
    [WithinDistances, BetweenDistances, WithinPairLabels] = getWithinAndBetweenDistances(ClustLabels, DistMat);

    %% FREY AND VAN GROENEWOUD
    % Compute mean within- and between- distance for one greater than max
    % cluster solution
    meanWithinDists(end) = mean(WithinDistances);
    meanBetweenDists(end) = mean(BetweenDistances);

    criteriaVectors.FVG = (meanBetweenDists(2:end) - meanBetweenDists(1:end-1)) ./ (meanWithinDists(2:end) - meanWithinDists(1:end-1));

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
    criteriaVectors.KL = abs(d(1:end-1)./d(2:end));

    % KLnrm
    KLnrm = (d(1:end-1) - d(2:end)) ./ M(1:end-2);
    KLnrm((d < 0)) = 0;
    KLnrm((d(1:end-1) < d(2:end))) = 0;
    criteriaVectors.KLnrm = KLnrm;

    % Normalize criteria and update struct to output
    criterionNames = fieldnames(criteriaVectors);
    for i=1:numel(criterionNames)
        c = criteriaVectors.(criterionNames{i});

        if strcmp(criterionNames{i}, 'DB') || strcmp(criterionNames{i}, 'CV') || strcmp(criterionNames{i}, 'CV2')
            c = (c - min(c))/(max(c)-min(c));
            c = 1 - c;
            criteriaVectors.(criterionNames{i}) = c;
        elseif strcmp(criterionNames{i}, 'FVG')
            c = abs(1-c);
            c = (c - min(c))/(max(c) - min(c));
            c = 1 - c;
            criteriaVectors.(criterionNames{i}) = c;
        else
            % Normalize
            c = (c - min(c))/(max(c) - min(c));
            criteriaVectors.(criterionNames{i}) = c;
        end

        % Add to output struct
        idx = matches({criteria.criterionName}, criterionNames{i});
        for j=1:maxClusters
            nc = ClusterNumbers(j);
            clustName = ['clust' int2str(nc)];
            criteria(idx).(clustName) = c(j);
        end
    end

end

function [Maps, ClustLabels] = getClusters(msinfo, nc, IndSamples)       
    % Get maps for the specified cluster solution, average reference and
    % normalize
    Maps = msinfo.MSMaps(nc).Maps;
    nChannels = size(Maps,2);
    newRef = eye(nChannels);
    newRef = newRef - 1/nChannels;
    IndSamples = newRef*IndSamples;
    Maps = Maps*newRef;
    Maps = NormDimL2(Maps,2);

    % Assign labels to the input voltage vectors
    Cov = Maps*IndSamples;
    if msinfo.ClustPar.IgnorePolarity
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