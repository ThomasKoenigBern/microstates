function [AllEEG, TheEEG, com] = pop_ClustNumSelection(AllEEG,TheEEG,CurrentSet,UseMean,FitPar,MeanSet)
    com = '';
    
    %% Error handling, data and parameters selection
    % Check if multiple datasets are selected
    if numel(TheEEG) > 1
        errordlg2('pop_ClustNumSelection currently() supports only a single EEG structure as input');
        return;
    end
    
    if nargin < 4,     UseMean =  false;    end
    if nargin < 5,     FitPar  = [];        end 
    if nargin < 6,     MeanSet = [];        end 
    
    % check if the currently selected EEG structure contains microstate
    % information
    if ~isfield(TheEEG,'msinfo')
        errordlg2(['The data does not contain microstate maps. Identify microstate maps first' ...
            ' from Tools -> Microstates -> Identify microstate maps.'],'Data driven selection of number of microstates');
        return;
    end

    % if the currently selected EEG structure is a mean but the user
    % selected the own template maps version, correct them
    if isfield(TheEEG.msinfo, 'children') && ~UseMean
        errordlg2(['The currently selected EEG dataset contains mean microstate maps across individuals. ' ...
            'Use the mean template maps menu item instead.'], 'Data driven selection of number of microstates');
        return;
    end
    
    % if doing mean level analysis and the mean set is not already 
    % passed in, check if the currently selected EEG structure is a mean
    % set and if not, have the user select the mean set
    if UseMean == true
        if isempty(MeanSet)
            if ~isfield(TheEEG.msinfo, 'children')
                nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
                HasChildren = cellfun(@(x) isfield(x,'children'), {AllEEG.msinfo});
                nonemptyMean = nonempty(HasChildren);
            
                AvailableMeans = {AllEEG(nonemptyMean).setname};
                res = inputgui( 'geometry', {1 1}, 'geomvert', [1 4], 'uilist', { ...
                    { 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'  } ...
                    { 'Style', 'listbox', 'string', AvailableMeans, 'tag','SelectSets'}});
             
                if isempty(res)
                    return
                end
                MeanSet = nonemptyMean(res{1});
            else
                MeanSet = CurrentSet;
            end
        end
        TheEEG = AllEEG(MeanSet);
    end
    
    % Select fitting parameters - do not allow user to deselect fitting only
    % on GFP peaks if this option was chosen for clustering
    % set BControl = false for all cases
    if isfield(TheEEG.msinfo,'FitPar');      params = TheEEG.msinfo.FitPar;
    else params = [];
    end
    [FitPar,paramsComplete] = UpdateFitParameters(FitPar,params,{'lambda','PeakFit','b','BControl'});

    if nargin < 5 || paramsComplete == false
        FitPar = SetFittingParameters([],params, ~TheEEG.msinfo.ClustPar.GFPPeaks);
        if isempty(FitPar) return;      end
    end
    
    TheEEG.msinfo.FitPar = FitPar;

    %% Compute criterion for each clustering solution
    ClusterNumbers = TheEEG.msinfo.ClustPar.MinClasses:TheEEG.msinfo.ClustPar.MaxClasses;
    maxClusters = size(ClusterNumbers, 2);        
    
    % If doing mean level analysis, find the children EEG sets of the mean
    % set and initialize the criterion matrices according to how many
    % datasets are included in the mean set
    if UseMean
        ChildIndices = FindTheWholeFamily(TheEEG, AllEEG);
        nSubjects = numel(ChildIndices);
    else
        nSubjects = 1;
    end
    
    % W - within-group dispersion matrix (used for several criterion)
    W = cell(nSubjects, maxClusters, 1);            

    % Criterion for metacriterion (11)
    CV = nan(nSubjects, maxClusters);           % Cross-Validation
    CC = nan(nSubjects, maxClusters);           % Cubic-Clustering Criterion
    DB = nan(nSubjects, maxClusters);           % Davies-Bouldin
    D = nan(nSubjects, maxClusters);            % Dunn
    FVG = nan(nSubjects, maxClusters);          % Frey and Van Groenewoud
    H = nan(nSubjects, maxClusters);            % Hartigan
    KL_nrm = nan(nSubjects, maxClusters);       % Normalized Krzanowski-Lai (according to Murray 2008)
    KL = nan(nSubjects, maxClusters);           % Krzanowski-Lai (according to Krzanowski-Lai 1988)
    M = nan(nSubjects, maxClusters);            % Mariott
    PB = nan(nSubjects, maxClusters);           % Point-Biserial
    T = nan(nSubjects, maxClusters);            % Tau
    
    % Other criterion
    GEV = nan(nSubjects, maxClusters);          % Global Explained Variance
    CH = nan(nSubjects, maxClusters);           % Calinski-Harabasz
    S = nan(nSubjects, maxClusters);            % Silhouette
    
    for subj=1:nSubjects
        if UseMean
            ChildIndex = ChildIndices(subj);
            TheEEG = AllEEG(ChildIndex);
        end
        
        % store time samples and cluster labels for each solution - used as
        % input for Frey index function
        numClustSolutions = length(ClusterNumbers);
        AllIndSamples = cell(numClustSolutions + 1, 1);
        AllClustLabels = cell(numClustSolutions + 1, 1);

        nSegments = size(TheEEG.data,3);
        % number of samples with valid microstate assignments for each
        % cluster solution - used as input for Hartigan index function
        nsamples = zeros(maxClusters);

        %AllClustLabels = zeros(maxClusters, size(TheEEG.data,2),nSegments);
        for i=1:maxClusters
            warning('off', 'stats:pdist2:DataConversion');
            nc = ClusterNumbers(i);         % number of clusters
            
            % Assign microstate labels
            Maps = TheEEG.msinfo.MSMaps(nc).Maps;            
            [ClustLabels, gfp, fit] = AssignMStates(TheEEG,Maps,FitPar,TheEEG.msinfo.ClustPar.IgnorePolarity);
            %AllClustLabels(i,:,:) = ClustLabels(:,:);
            IndSamples = TheEEG.data;

            % Check for segmented data and reshape if necessary
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
            nsamples(i) = size(IndSamples, 2);

            AllIndSamples{i} = IndSamples';
            AllClustLabels{i} = ClustLabels;
            
            % CRITERION CALCULATIONS %

            % W matrix
            W{subj, i} = eeg_W(IndSamples,ClustLabels);
            trace_w = zeros(1, maxClusters);

            for j = 1:maxClusters
                trace_w(1,j) = trace(W{j});
            end
            if i < maxClusters && i > 1 
                diff_q =  (((nc-1)^(2/size(IndSamples,2))) * trace_w(1, i-1))...
                        - (((nc)^(2/size(IndSamples,2))) * trace_w(1, i));
                diff_qplus1 = (((nc)^(2/size(IndSamples,2))) * trace_w(1, i))...
                            - (((nc+1)^(2/size(IndSamples,2))) * trace_w(1, i+1));
                KL(subj, i) = abs(diff_q/diff_qplus1);
            end
            KL(subj, maxClusters) = nan;

            % Davies-Bouldin - the lower the better
            DB(subj, i) = eeg_DaviesBouldin(IndSamples, ClustLabels, TheEEG.msinfo.ClustPar.IgnorePolarity);

            % Dunn - the higher the better
            D(subj, i) = eeg_Dunn(IndSamples', ClustLabels);

            % Cross Validation
            % need to pass in subj
%             CV(subj, i) = eeg_crossVal(TheEEG, IndSamples', ClustLabels, ClusterNumbers(i));
            
            % Krzanowski-Lai
            % params: ClustLabels, clustNum, W_i, nClusters, nChannels
            % KL(subj, i) = eeg_krzanowskiLai(ClustLabels, ClusterNumbers(i), W(i), TheEEG.msinfo.ClustPar.MaxClasses, size(IndSamples, 1));
            % Krzanowski-Lai
            KL(subj, i) = zeros(1,1);        % issue, temp

            % Marriot
            detW = det(W{subj, i});
            M(subj, i) = nc*nc*detW;
            
            % Point-Biserial
            tic
            PB(subj, i) = eeg_PointBiserial(IndSamples, ClustLabels, TheEEG.msinfo.ClustPar.IgnorePolarity);
            toc

            % EXTRA CALCULATIONS %
            % Global Explained Variance - the higher the better
            GEV(subj, i) = fit;

            % Calinski-Harabasz - the higher the better
            %CH(subj, i) = eeg_CalinskiHarabasz(IndSamples, ClustLabels, TheEEG.msinfo.ClustPar.IgnorePolarity);

            % Silhouette (TODO)
        end

        % Find MS maps for one greater than largest cluster solution
        % used for Hartigan, KL, and Frey index
        maxClustNumber = ClusterNumbers(end);
        ClustPar = TheEEG.msinfo.ClustPar;
        [IndSamples, ClustLabels] = FindMSMaps(TheEEG, maxClustNumber+1, FitPar, ClustPar);

        AllIndSamples{end} = IndSamples';
        AllClustLabels{end} = ClustLabels;

        % Frey and Van Groenewoud - closer to 1 is better
        FVG(subj, :) = eeg_FreyVanGroenewoud(AllIndSamples, AllClustLabels, ClusterNumbers);

        % compute W matrix of one greater than max cluster solution - used
        % for Hartigan index
        Wmax = eeg_W(IndSamples, ClustLabels);
        Wsubj = W(subj, :);

        % Krzanowski-Lai
        % params: ClustLabels, clustNum, W_i, nClusters, nChannels
%         KL = eeg_krzanowskiLai(ClustLabels, ClusterNumbers(i), W{i}, TheEEG.msinfo.ClustPar.MaxClasses, size(IndSamples, 1));
        % Krzanowski-Lai
        % KL(subj, i) = zeros(1,1);        % issue, temp
%         KL(subj, :) = abs(diff_q / diff_qplus1);

        % Tau index (TODO)
%         T(subj, i) = eeg_tau(TheEEG, IndSamples, AllClustLabels);

        % Hartigan - easier to compute across all clustering solutions at
        % once after dispersion has been calculated for all, higher is
        % better
        % Hartigan - higher is better
        H(subj, :) = eeg_Hartigan([Wsubj Wmax], ClusterNumbers, nsamples);

    end

    if UseMean
        % Criterion for metacriterion (11)
        CV = mean(CV, 1);
        CC = mean(CC, 1);
        DB = mean(DB, 1);
        D = mean(D, 1);
        FVG = mean(FVG, 1);
        H = mean(H, 1);
        KL = mean(KL, 1);
        M = mean(M, 1);
        PB = mean(PB, 1);
        T = mean(T, 1);
        W = mean(W, 1);

        % Other criterion
        GEV = mean(GEV, 1);
        CH = mean(CH, 1);
        S = mean(S, 1);
    end

    [res,~,~,structout] = inputgui( 'geometry', { 1 1 1 [8 2] [8 2] [8 2] [8 2] [8 2] ...
        [8 2] [8 2] [8 2] [8 2] [8 2] [8 2] [8 2] 1 1 [8 2] [8 2] [8 2] 1 1}, 'uilist', {...
        {'Style', 'text', 'string', 'Select measures to be plotted:'} ...
        {'Style', 'text', 'string', ''} ...
        {'Style', 'text', 'string', 'Measures for Metacriterion', 'fontweight', 'bold'} ...
        {'Style', 'checkbox', 'string', 'Cross-Validation', 'tag', 'useCV', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...        
        {'Style', 'checkbox', 'string', 'Cubic Clustering Criterion', 'tag', 'useCC', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...              
        {'Style', 'checkbox', 'string', 'Davies-Bouldin', 'tag', 'useDB', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Dunn', 'tag', 'useD', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Frey and Van Groenewoud', 'tag', 'useFVG', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Hartigan', 'tag', 'useH', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Normalized Krzanowski-Lai', 'tag', 'useKLnrm', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Krzanowski-Lai', 'tag', 'useKL', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Mariott', 'tag', 'useM', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Point-Biserial', 'tag', 'usePB', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Tau', 'tag', 'useT', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Trace(W)', 'tag', 'useTrace', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'text', 'string', ''} ...
        {'Style', 'text', 'string', 'Other Measures', 'fontweight', 'bold'} ...
        {'Style', 'checkbox', 'string', 'Global Explained Variance', 'tag', 'useGEV', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Silhouette', 'tag', 'useSilhouette', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'Callback', @silhouetteInfo} ...
        {'Style', 'checkbox', 'string', 'Calinski-Harabasz', 'tag', 'useCH', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'text', 'string', ''} ...
        {'Style', 'checkbox', 'string', 'Plot Metacriterion', 'tag', 'plotMetacriterion', 'value', 1} ...
        },'title', 'Data driven selection of number of classes');

    if (isempty(res)) return;   end
    
    %% Plotting
    res = cell2mat(res);

    % number of graphs that are part of the metacriterion
    nMetacriterionGraphs = sum(res(1:11) == 1);
    nExtraGraphs = sum(res(12:14) == 1);
    
    if (nMetacriterionGraphs > 0)
        figure('Name', 'Measures for Metacriterion', 'Position', [100 100 700 600]);
        if (nMetacriterionGraphs > 5 && nMetacriterionGraphs < 11)
            tiledlayout(6, 2);
        end
        if (nMetacriterionGraphs > 5)
            tiledlayout(5, 2);
        else
            tiledlayout(nMetacriterionGraphs, 1);
        end
        
        if (structout.useCV)
            nexttile
            plot(ClusterNumbers, CV, "-o");
            set(gca,'Ydir','reverse');
            title("Cross-Validation");
        end
        if (structout.useDB)
            nexttile
            plot(ClusterNumbers, DB, "-o");
            set(gca,'Ydir','reverse');
            title("Davies-Bouldin");
        end
        if (structout.useD)
            nexttile
            plot(ClusterNumbers, D, "-o");
            title("Dunn");
        end
        if (structout.useFVG)
            nexttile
            plot(ClusterNumbers, FVG, "-o");
            set(gca,'Ydir','reverse');
            title("Frey and Van Groenewoud")
        end
        if (structout.useH)
            nexttile
            plot(ClusterNumbers, H, "-o");
            set(gca,'Ydir','reverse');
            title("Hartigan")
        end
        if (structout.useKLnrm)
            nexttile
            plot(ClusterNumbers, KL_nrm, "-o");
            title("Normalized Krzanowski-Lai");
        end
        if (structout.useKL)
            nexttile
            plot(ClusterNumbers, KL, "-o");
            title("Krzanowski-Lai");
        end
        if (structout.useM)
            nexttile
            plot(ClusterNumbers, M, "-o");
            title("Marriot");
        end
        if (structout.usePB)
            nexttile
            plot(ClusterNumbers, PB, "-o");
            title("Point-Biserial");
        end
        if (structout.useTrace)
            nexttile
            plot(ClusterNumbers, trace_w, "-o");
            title("Trace(W)");
        end
    end

    if (nExtraGraphs > 0)
        figure('Name', 'Extra Measures', 'Position', [900 200 600 500]);
        tiledlayout(nExtraGraphs, 1);
        
        if (structout.useGEV)
            nexttile
            plot(ClusterNumbers, GEV, "-o");
            title("GEV");
        end
        if (structout.useCH)
            nexttile
            plot(ClusterNumbers, CH, "-o");
            title("Calinski-Harabasz");
        end
    end
    
end

function silhouetteInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'The silhouette value for each point is a measure of how similar that point is to points in its own cluster, when compared to points in other clusters. The silhouette value ranges from –1 to 1. A high silhouette value indicates that i is well matched to its own cluster, and poorly matched to other clusters. If most points have a high silhouette value, then the clustering solution is appropriate. If many points have a low or negative silhouette value, then the clustering solution might have too many or too few clusters. You can use silhouette values as a clustering evaluation criterion with any distance metric.'}})
end

function ChildIndices = FindTheWholeFamily(TheMeanEEG,AllEEGs)
        
    AvailableDataNames = {AllEEGs.setname};
    
        ChildIndices = [];
        for i = 1:numel(TheMeanEEG.msinfo.children)
            idx = find(strcmp(TheMeanEEG.msinfo.children{i},AvailableDataNames));
        
            if isempty(idx)
                errordlg2(sprintf('Dataset %s not found',TheMeanEEG.msinfo.children{i}),'Silhouette explorer');
            end
    
            if numel(idx) > 1
                errordlg2(sprintf('Dataset %s repeatedly found',TheMeanEEG.msinfo.children{i}),'Silhouette explorer');
            end
            if ~isfield(AllEEGs(idx).msinfo,'children')
                ChildIndices = [ChildIndices idx]; %#ok<AGROW>
            else
                ChildIndices = [ChildIndices FindTheWholeFamily(AllEEGs(idx),AllEEGs)]; %#ok<AGROW>
            end
        end


end

function [IndSamples, ClustLabels] = FindMSMaps(TheEEG, numClusts, FitPar, ClustPar)
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
    
    % Assign microstate labels for one greater than max cluster
    % solution, add time samples and labels to cell arrays
    [ClustLabels, ~, ~] = AssignMStates(TheEEG,Maps,FitPar,TheEEG.msinfo.ClustPar.IgnorePolarity);
    
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
end