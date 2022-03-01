function H = eeg_Hartigan(TheEEG, FitPar, W)
    % get number of clusters
    ClusterNumbers = TheEEG.msinfo.ClustPar.MinClasses:TheEEG.msinfo.ClustPar.MaxClasses;
    numClustSolutions = length(ClusterNumbers);
    maxClustNumber = ClusterNumbers(end);

    % need one greater than the highest number of clusters found in order
    % to compute Hartigan index for the largest cluster solution

    % cannot call pop_FindMSTemplates directly because we do not want to
    % update the msinfo struct to contain more cluster solutions than
    % chosen by the user
    
    %% Find MS maps for one greater than largest cluster solution
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
        Maps = b_model;
    else
        [b_model,~] = eeg_computeAAHC(double(MapsToUse'),maxClustNumber+1,false, ClustPar.IgnorePolarity,ClustPar.Normalize);
        Maps = b_model{1};
    end

    %% Compute W for one greater than the largest cluster solution
    % Assign microstate labels
    [ClustLabels, ~, ~, ~, ~] = AssignMStates(TheEEG,Maps,FitPar,TheEEG.msinfo.ClustPar.IgnorePolarity);
    
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
    n = size(IndSamples, 2);        % number of data points

    Wmax = eeg_Dispersion(IndSamples', ClustLabels);
    W = [W Wmax];

    %% Compute Hartigan index for each cluster solution
    H = zeros(numClustSolutions, 1);
    for c = 1:numClustSolutions
        nc = ClusterNumbers(c);     % number of clusters
        Wratio = (W(c)/W(c+1)) - 1;
        H(c) = Wratio*(n-nc-1);
    end

end