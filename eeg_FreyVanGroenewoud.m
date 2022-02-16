function FVG = eeg_FreyVanGroenewoud(TheEEG, FitPar)
    % get number of clusters
    ClusterNumbers = TheEEG.msinfo.ClustPar.MinClasses:TheEEG.msinfo.ClustPar.MaxClasses;
    numClustSolutions = length(ClusterNumbers);
    maxClustNumber = ClusterNumbers(end);

    Maps = cell(numClustSolutions+1, 1);
    for i= 1:numClustSolutions
        nc = ClusterNumbers(i);
        Maps{i} = TheEEG.msinfo.MSMaps(nc).Maps;
    end

    % need one greater than the highest number of clusters found in order
    % to compute Frey index for the largest clustering solution

    % cannot call pop_FindMSTemplates directly because we do not want to
    % update the msinfo struct to contain more clustering solutions than
    % chosen by the user
    
    ClustPar = TheEEG.msinfo.ClustPar;
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
        [b_model,~,~,~] = eeg_kMeans(MapsToUse',maxClustNumber+1,ClustPar.Restarts,[],flags,TheEEG.chanlocs);
        Maps{numClustSolutions+1} = b_model;
    else
        [b_model,~] = eeg_computeAAHC(double(MapsToUse'),maxClustNumber+1,false, ClustPar.IgnorePolarity,ClustPar.Normalize);
        Maps{numClustSolutions+1} = b_model{1};
    end
    
    % now that we have the maps for all needed clustering solutions,
    % get the individual samples and cluster labels for each solution
    AllIndSamples = cell(numClustSolutions + 1, 1);
    AllClustLabels = cell(numClustSolutions + 1, 1);
    for i=1:numClustSolutions+1
        % Assign microstate labels
        [ClustLabels, ~, ~, ~, ~] = AssignMStates(TheEEG,Maps{i},FitPar,TheEEG.msinfo.ClustPar.IgnorePolarity);
        
        % Check for segmented data and reshape if necessary
        IndSamples = TheEEG.data;
        if (numel(size(IndSamples)) == 3)
            nSegments = size(IndSamples, 3);
    
            % reshape IndSamples
            NewIndSamples = IndSamples(:,:,1);
            for j = 2:nSegments
                NewIndSamples = cat(2, NewIndSamples, IndSamples(:,:,j));
            end
            IndSamples = NewIndSamples;
    
            % reshape ClustLabels
            NewClustLabels = ClustLabels(:,1);
            for k = 2:nSegments
                NewClustLabels = cat(1, NewClustLabels, ClustLabels(:,k));
            end
            ClustLabels = squeeze(NewClustLabels);
        end

        % Check for zero elements in ClustLabels and remove them
        zeroIndices = find(~ClustLabels);
        if (size(zeroIndices,1) > 0)
            % remove samples with no microstate assignmnets
            IndSamples(:, zeroIndices') = [];
            % remove clust labels of zero
            ClustLabels(zeroIndices') = [];
        end
        
        AllIndSamples{i} = IndSamples';
        AllClustLabels{i} = ClustLabels;
    end

    % using the individual samples and cluster labels for each solution,
    % compute Frey index for each solution
    FVG = zeros(numClustSolutions, 1);
    for c = 1:numClustSolutions
        IndSamples = AllIndSamples{c};
        ClustLabels = AllClustLabels{c};
        nc = ClusterNumbers(c);     % number of clusters
        
        % find mean inter-cluster distance and mean intra-cluster distance
        % for the CURRENT clustering solution
        centroids = NaN(nc,size(IndSamples,2));
        intraClustDists = zeros(nc,1);
        
        clusters = unique(ClustLabels);
        for i = 1:nc
          clustMembers = (ClustLabels == clusters(i));
          if any(clustMembers)
              centroids(i,:) = mean(IndSamples(clustMembers,:),1) ;
              % twice the average distance of each observation to the centroids
              intraClustDists(i)= 2*mean(pdist2(IndSamples(clustMembers,:),centroids(i,:)));
          end
        end
        
        currInterClustDist = mean(pdist(centroids));
        currIntraClustDist = mean(intraClustDists);

        % find the mean inter-cluster distance and mean intra-cluster
        % distance for the NEXT clustering solution
        IndSamples = AllIndSamples{c+1};
        ClustLabels = AllClustLabels{c+1};
        if (nc == ClusterNumbers(end))
            nc = ClusterNumbers(end) + 1;
        end

        centroids = NaN(nc,size(IndSamples,2));
        intraClustDists = zeros(nc,1);
        
        clusters = unique(ClustLabels);
        for i = 1:nc
          clustMembers = (ClustLabels == clusters(i));
          if any(clustMembers)
              centroids(i,:) = mean(IndSamples(clustMembers,:),1) ;
              % twice the average distance of each observation to the centroids
              intraClustDists(i)= 2*mean(pdist2(IndSamples(clustMembers,:),centroids(i,:)));
          end
        end
        
        nextInterClustDist = mean(pdist(centroids));
        nextIntraClustDist = mean(intraClustDists);

        FVG(c) = (nextInterClustDist - currInterClustDist)/(nextIntraClustDist - currIntraClustDist);
    end

end