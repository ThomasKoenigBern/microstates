function [metacriteria, criteria, GEVs, mcVotes, com] = clustNumSelection(TheEEG, MaxSamples)
    com = '';
    
    % Select fitting parameters
    FitPar.PeakFit = 1;
    FitPar.BControl = 0;
    FitPar.b = 0;
    FitPar.lambda = 0;
    TheEEG.msinfo.FitPar = FitPar;

    ClustPar = TheEEG.msinfo.ClustPar;    

    %% Compute criterion for each clustering solution
    ClusterNumbers = TheEEG.msinfo.ClustPar.MinClasses+1:TheEEG.msinfo.ClustPar.MaxClasses-1;
    maxClusters = size(ClusterNumbers, 2);                  

    % Criterion for metacriterion (6)
    metacriteria.G = nan(1, maxClusters);             % Gamma
%     metacriteria.S = nan( 1, maxClusters);            % Silhouette
    metacriteria.DB = nan( 1, maxClusters);           % Davies-Bouldin
    metacriteria.PB = nan( 1, maxClusters);           % Point-Biserial
    metacriteria.D = nan( 1, maxClusters);            % Dunn
    metacriteria.KL = nan( 1, maxClusters);           % Krzanowski-Lai

    % IQM^2/IQR metacriterion structures
    allMetacriteria = nan(6, maxClusters);            % all criterion that contribute to final metacriterion

    % Extra criterion
    criteria.CV = nan( 1, maxClusters);           % Cross-Validation (second derivative)
    criteria.FVG = nan( 1, maxClusters);          % Frey and Van Groenewoud
    criteria.H = nan( 1, maxClusters);            % Hartigan (first derivative)
    criteria.TW = nan( 1, maxClusters);           % Trace(W) (second derivative)
%     criteria.GEV = nan( 1, maxClusters);          % Global Explained Variance
    criteria.CH = nan( 1, maxClusters);           % Calinski-Harabasz

    % Individual GEVs
    GEVs = cell(7, 1);
        
    % store time samples and cluster labels for each solution - used as
    % input for Frey and KL index functions
    numClustSolutions = length(ClusterNumbers);
    AllIndSamples = cell(numClustSolutions + 2, 1);
    AllClustLabels = cell(numClustSolutions + 2, 1);

    ClustPar = TheEEG.msinfo.ClustPar;      

    % number of samples with valid microstate assignments for each
    % cluster solution - used as input for Hartigan index function
    nsamples = zeros(1, maxClusters+1);

    %disp("About to loop through clusters");
    for i=1:maxClusters
        warning('off', 'stats:pdist2:DataConversion');
        nc = ClusterNumbers(i);         % number of clusters
        %fprintf("Calculating criteria for %d cluster solution %d\n", nc);

        % Assign microstate labels
        %fprintf("Assigning microstate labels\n");
%         tic
        Maps = TheEEG.msinfo.MSMaps(nc).Maps;            
        [ClustLabels, ~, ~, GEV_classes] = AssignMStates(TheEEG,Maps,FitPar,TheEEG.msinfo.ClustPar.IgnorePolarity);
        GEVs{i} = GEV_classes';
        IndSamples = TheEEG.data;
%         toc

        % Distribute random sampling across segments
        %fprintf("Distributing random sampling across segments\n");
%         tic
        nSegments = TheEEG.trials;
        nSamples = size(TheEEG.data, 2)*size(TheEEG.data, 3);
        if (MaxSamples < nSamples)
            SamplesPerSegment = hist(ceil(double(nSegments) * rand(MaxSamples,1)), nSegments);
        else 
            SamplesPerSegment = inf(nSegments,1);
        end
%         toc

        SamplesToUse = [];
        ClustLabelsToUse = [];
        for s = 1:nSegments
            if (size(IndSamples, 2) > SamplesPerSegment(s)) && SamplesPerSegment(s) > 0
                idx = randperm(size(IndSamples,2));
                SamplesToUse = [SamplesToUse IndSamples(:,idx(1:SamplesPerSegment(s)),s)];
                ClustLabelsToUse = [ClustLabelsToUse; ClustLabels(idx(1:SamplesPerSegment(s)),s)];
            else
                SamplesToUse = [SamplesToUse IndSamples(:,:,s)];
                ClustLabelsToUse = [ClustLabelsToUse; ClustLabels(:, s)];
            end
        end
        IndSamples = SamplesToUse;
        ClustLabels = squeeze(ClustLabelsToUse);

        % Check for zero elements in ClustLabels and remove them
        zeroIndices = find(~ClustLabels);
        if (size(zeroIndices,1) > 0)
            % remove samples with no microstate assignmnets
            IndSamples(:, zeroIndices') = [];
            % remove clust labels of zero
            ClustLabels(zeroIndices') = [];
        end
        nsamples(i) = size(IndSamples, 2);

        AllIndSamples{i+1} = IndSamples;
        AllClustLabels{i+1} = ClustLabels;
        
        % CRITERION CALCULATIONS %

        % Cross Validation
%         disp("Cross Validation");
%         tic
        criteria.CV( i) = eeg_crossVal(Maps, IndSamples', ClustLabels, ClusterNumbers(i));
%         toc

        % Trace(W)
%         disp("Trace(dispersion");
%         tic
        criteria.TW( i) = eeg_TW(IndSamples,ClustLabels);
%         toc

        % Davies-Bouldin - the lower the better
%         disp("Davies-Bouldin");
%         tic
        metacriteria.DB( i) = eeg_DaviesBouldin(IndSamples, ClustLabels, TheEEG.msinfo.ClustPar.IgnorePolarity);
%         toc

        % Dunn - the higher the better
%         disp("Dunn");
%         tic
        metacriteria.D( i) = eeg_Dunn(IndSamples, ClustLabels,TheEEG.msinfo.ClustPar.IgnorePolarity);
%         toc

        % Point-Biserial and Gamma
%         disp("Point-Biserial and Gamma");
%         tic
        [metacriteria.PB(i), metacriteria.G(i)] = eeg_GammaPointBiserial(IndSamples, ClustLabels, TheEEG.msinfo.ClustPar.IgnorePolarity);
%         toc

        % Global Explained Variance - the higher the better
%         criteria.GEV( i) = fit;

        % Calinski-Harabasz - the higher the better
%         disp("Calinski-Harabasz");
%         tic
        criteria.CH(i) = eeg_CalinskiHarabasz(IndSamples, ClustLabels, TheEEG.msinfo.ClustPar.IgnorePolarity);
%         toc

        % Silhouette
        % disp("Silhouette");
        % tic
        % distfun = @(XI,XJ)(1-abs(MyCorr(XI',XJ')));        
        % metacriteria.S(i) = sum(silhouette(IndSamples', ClustLabels, distfun))/nsamples(i);
        % toc
    end

    % Find MS maps for one greater than largest cluster solution
    % used for Hartigan, KL, and Frey index
%     disp("Identifying MS maps for one greater than largest solution (H, KL, FVG)");
%     tic
    maxClustNumber = ClusterNumbers(end);
    [IndSamples, ClustLabels] = FindMSMaps(TheEEG, maxClustNumber+1, FitPar, ClustPar, MaxSamples);
%     toc

    % Find Cross-Validation for one greater than largest cluster
    % solution
%     disp("Cross validation for one greater than largest cluster");
%     tic
    CVmax = eeg_crossVal(Maps, IndSamples', ClustLabels, ClusterNumbers(end)+1);
%     toc

    % compute Trace(W) of one greater than max cluster solution
%     disp("Trace(w) for one greater than largest cluster");
%     tic
    TWmax = eeg_TW(IndSamples, ClustLabels);
    TWsubj = criteria.TW(:);
%     toc

    AllIndSamples{end} = IndSamples;
    AllClustLabels{end} = ClustLabels;

    % Frey and Van Groenewoud - closer to 1 is better
%     disp("Frey Van Groenewoud");
%     tic
    criteria.FVG(:) = eeg_FreyVanGroenewoud(AllIndSamples(2:end), AllClustLabels(2:end), ClusterNumbers);
%     toc

    % Find MS maps for one less than smallest cluster solution
    % used for KL and CV index
%     disp("Identifying MS maps for one less than smallest cluster solution (for KL)");
%     tic
    minClustNumber = ClusterNumbers(1);
    [IndSamples, ClustLabels] = FindMSMaps(TheEEG, minClustNumber-1, FitPar, ClustPar, MaxSamples);
    nsamples(1) = size(IndSamples, 2);
%     toc

    % Find Cross-Validation for one less than smallest cluster solution
%     disp("Cross validation for one less than smallest cluster");
%     tic
    CVmin = eeg_crossVal(Maps, IndSamples', ClustLabels, ClusterNumbers(1)-1);
%     toc

    % Find Trace(W) for one less than smallest cluster solution
%     disp("Trace(w) for one less than smallest cluster");
%     tic
    TWmin = eeg_TW(IndSamples, ClustLabels);
%     toc

    % Take second difference of Cross-Validation values
%     disp("Second difference of Cross validation");
%     tic
    criteria.CV(:) = diff(diff([CVmin; criteria.CV(:); CVmax]));
%     toc

    % Take second difference of Trace(W) values
%     disp("Second difference of Trace(W)");
%     tic
    criteria.TW(:) = diff(diff([TWmin; criteria.TW(:); TWmax]));
%     toc

    % Hartigan - higher is better
%     disp("Hartigan");
%     tic
    H = eeg_Hartigan([TWmin; TWsubj; TWmax], [(ClusterNumbers(1) - 1) ClusterNumbers], nsamples);
%     toc

    % Take first difference of Hartigan values
%     disp("First difference of Hartigan");
%     tic
    criteria.H(:) = diff(H);
%     toc

    AllIndSamples{1} = IndSamples;
    AllClustLabels{1} = ClustLabels;
    
    % Krzanowski-Lai - higher is better
%     disp("Krzanowski-Lai");
%     tic
    metacriteria.KL(:) = eeg_krzanowskiLai(AllIndSamples, AllClustLabels, ClusterNumbers, TheEEG.msinfo.ClustPar.IgnorePolarity);
%     toc
    

    % normalize criteria for metacriterion
%     disp("Normalize criteria for metacriterion");
%     tic
    names = fieldnames(metacriteria);
    nCriterion = length(names);
    if (mod(nCriterion, 2) == 0)
        votes = zeros(nCriterion+1, 1);
    else
        votes = zeros(nCriterion, 1);
    end
    for i=1:numel(names)
        % Normalize
        c = metacriteria.(names{i});
        c = (c - min(c))/(max(c)-min(c));

        if (strcmp(names{i}, 'DB'))
            metacriteria.(names{i}) = 1 - c;
            allMetacriteria(i, :) = 1 - c;
        else
            metacriteria.(names{i}) = c;
            allMetacriteria(i, :) = c;
        end

        [m, ind] = max(metacriteria.(names{i}));
        votes(i) = ClusterNumbers(ind);
        mcVotes.(names{i}) = ClusterNumbers(ind);
    end
%     toc

    % Normalize and adjust all extra criteria
%     disp("Normalize and adjust all extra criteria");
%     tic
    names = fieldnames(criteria);
    for i=1:numel(names)
        c = criteria.(names{i});
        if (strcmp(names{i}, 'FVG'))
            FVG = abs(1 - c);
            FVG = (FVG - min(FVG))/(max(FVG) - min(FVG)); 
            criteria.FVG = 1 - FVG;
        else
            criteria.(names{i}) = (c - min(c))/(max(c)-min(c));
        end     

        [m, ind] = max(criteria.(names{i}));
        mcVotes.(names{i}) = ClusterNumbers(ind);
    end
%     toc

    % calculate metacriterion
%     disp("Calculate metacriterion");
%     tic
    % compute IQM
    nCriterion = size(allMetacriteria, 1);
    criterionIQM = sort(allMetacriteria);           % first sort the columns and make copy of array
    quartileSize = nCriterion/4;                    % calculate quartile size

    % if number of criterion chosen is divisible by 4, can take IQM
    % without weighting partial values
    if (mod(nCriterion, 4) == 0)
        criterionIQM = criterionIQM(1+quartileSize:nCriterion-quartileSize,:);
        IQM = mean(criterionIQM);
    else
        removeSize = floor(quartileSize);           % number of values to remove from 1st and 4th quartiles
        criterionIQM = criterionIQM(1+removeSize:nCriterion-removeSize,:);
        nIQR = size(criterionIQM, 1);               % number of values in IQR
        weight = (nIQR-2*quartileSize)/2;           % weight to multiply partial values of IQR by
        IQM = zeros(1, maxClusters);
        for i=1:maxClusters
            IQM(i) = weight*(criterionIQM(1, i) + criterionIQM(end, i)) + sum(criterionIQM(2:nIQR-1, i));
        end
    end
    
    % compute IQR
    IQR = iqr(allMetacriteria);

    metacriterion = (IQM.^2)./IQR;

    metacriteria.MC1 = metacriterion;
    toc
    if (mod(nCriterion, 2) == 0)
        medCriterion = median(allMetacriteria);
        [m , ind] = max(medCriterion);
        votes(end) = ClusterNumbers(ind);
    end
    [M I] = max(metacriterion);
    mcVotes.MC1 = ClusterNumbers(I);
    mcVotes.MC2 = median(votes);
    mcVotes.MC3 = mode(votes);

%     % calculate metacriterion (median of all votes)
%     names = fieldnames(metacriteria);
%     votes = zeros(5, 1);
%     for i=1:numel(names)
%         c = metacriteria.(names{i});
%         if (names{i} == 'DB')
%             [m, ind] = min(c);
%         else
%             [m, ind] = max(c);
%         end
%         metacriteria.(names{i}) = ClusterNumbers(ind);
%         votes(i) = ClusterNumbers(ind);
%     end
% 
%     metacriteria.mc = median(votes);

end

function [IndSamples, ClustLabels] = FindMSMaps(TheEEG, numClusts, FitPar, ClustPar, MaxSamples)
    % Only do clustering if the maps do not already exist
    doClustering = 0;

    if (numClusts > length(TheEEG.msinfo.MSMaps))
        doClustering = 1;
    else
        if (isempty(TheEEG.msinfo.MSMaps(numClusts).Maps))
            doClustering = 1;
        end
    end

    if doClustering
    
        % Distribute the random sampling across segments
        nSegments = TheEEG.trials;
        if ~isinf(ClustPar.MaxMaps)
            MapsPerSegment = hist(ceil(double(nSegments) * rand(ClustPar.MaxMaps,1)),nSegments);
        else
            MapsPerSegment = inf(nSegments,1);
        end
        
        MapsToUse = [];
        for s = 1:nSegments
            if ClustPar.GFPPeaks == 1
                gfp = std(TheEEG.data(:,:,s),1,1);
                IsGFPPeak = find([false (gfp(1,1:end-2) < gfp(1,2:end-1) & gfp(1,2:end-1) > gfp(1,3:end)) false]);
                if numel(IsGFPPeak) > MapsPerSegment(s) && MapsPerSegment(s) > 0
                    idx = randperm(numel(IsGFPPeak));
                    IsGFPPeak = IsGFPPeak(idx(1:MapsPerSegment(s)));
                end
                MapsToUse = [MapsToUse TheEEG.data(:,IsGFPPeak,s)];
            else
                if (size(TheEEG.data,2) > ClustPar.MaxMaps) && MapsPerSegment(s) > 0
                    idx = randperm(size(TheEEG.data,2));
                    MapsToUse = [MapsToUse TheEEG.data(:,idx(1:MapsPerSegment(s)),s)];
                else
                    MapsToUse = [MapsToUse TheEEG.data(:,:,s)];
                end
            end
        end
        
        flags = '';
        if ClustPar.IgnorePolarity == false
            flags = [flags 'p'];
        end
        if ClustPar.Normalize == true
            flags = [flags 'n'];
        end
        
        if ClustPar.UseEMD == true
            flags = [flags 'e'];
        end
        
        if ClustPar.UseAAHC == false
            [b_model,~,~,~] = eeg_kMeans(MapsToUse', numClusts ,ClustPar.Restarts,[],flags,TheEEG.chanlocs);
            Maps = b_model;
        else
            [b_model,~] = eeg_computeAAHC(double(MapsToUse'), numClusts, false, ClustPar.IgnorePolarity,ClustPar.Normalize);
            Maps = b_model{1};
        end
        TheEEG.msinfo.MSMaps(numClusts).Maps = Maps;
    else
        Maps = TheEEG.msinfo.MSMaps(numClusts).Maps;
    end
    
    % Assign microstate labels
    [ClustLabels, ~, ~] = AssignMStates(TheEEG,Maps,FitPar,TheEEG.msinfo.ClustPar.IgnorePolarity);
    
    IndSamples = TheEEG.data;
    % Distribute random sampling across segments
    nSegments = TheEEG.trials;
    if ~isinf(MaxSamples)
        SamplesPerSegment = hist(ceil(double(nSegments) * rand(MaxSamples,1)), nSegments);
    else 
        SamplesPerSegment = inf(nSegments,1);
    end

    SamplesToUse = [];
    ClustLabelsToUse = [];
    for s = 1:nSegments
        if (size(IndSamples, 2) > SamplesPerSegment(s)) && SamplesPerSegment(s) > 0
            idx = randperm(size(IndSamples,2));
            SamplesToUse = [SamplesToUse IndSamples(:,idx(1:SamplesPerSegment(s)),s)];
            ClustLabelsToUse = [ClustLabelsToUse; ClustLabels(idx(1:SamplesPerSegment(s)),s)];
        else
            SamplesToUse = [SamplesToUse IndSamples(:,:,s)];
            ClustLabelsToUse = [ClustLabelsToUse; ClustLabels(:, s)];
        end
    end
    IndSamples = SamplesToUse;
    ClustLabels = squeeze(ClustLabelsToUse);

    % Check for zero elements in ClustLabels and remove them
    zeroIndices = find(~ClustLabels);
    if (size(zeroIndices,1) > 0)
        % remove samples with no microstate assignmnets
        IndSamples(:, zeroIndices') = [];
        % remove clust labels of zero
        ClustLabels(zeroIndices') = [];
    end
end