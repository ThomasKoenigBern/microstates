function com = pop_ClustNumSelection(AllEEG,TheEEG,CurrentSet,UseMean,FitPar,MeanSet)
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
    if isfield(TheEEG.msinfo,'FitPar');      params = TheEEG.msinfo.FitPar;     % possibly need to use ClustPar instead of FitPar? issue
    else params = [];
    end
%     [FitPar,paramsComplete] = UpdateFitParameters(FitPar,params,{'lambda','PeakFit','b','BControl'});

    if nargin < 5 || paramsComplete == false
        % adding min and max classes so that numClasses is returned into
        % params
        FitPar = SetFittingParameters([],params);
        if isempty(FitPar) return;      end
    end
    
    TheEEG.msinfo.FitPar = FitPar;
    

    %% Compute criterion for each clustering solution
    % if ms maps doesn't exist, clustPar will not be recognized, so throw
    % error

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

    % Criterion for metacriterion (11)
    CV = nan(nSubjects, maxClusters);           % Cross-Validation
    CC = nan(nSubjects, maxClusters);           % Cubic-Clustering Criterion
    DB = nan(nSubjects, maxClusters);           % Davies-Bouldin
    D = nan(nSubjects, maxClusters);            % Dunn
    FVG = nan(nSubjects, maxClusters);          % Frey and Van Groenewoud
    H = nan(nSubjects, maxClusters);            % Hartigan
    KL = nan(nSubjects, maxClusters);           % Krzanowski-Lai
    M = nan(nSubjects, maxClusters);            % Mariott
    PB = nan(nSubjects, maxClusters);           % Point-Biserial
    T = nan(nSubjects, maxClusters);            % Tau
    W = nan(nSubjects, maxClusters);            % Trace (Dispersion)

    % Other criterion
    GEV = nan(nSubjects, maxClusters);          % Global Explained Variance
    CH = nan(nSubjects, maxClusters);           % Calinski-Harabasz
    S = nan(nSubjects, maxClusters);            % Silhouette
    
    for subj=1:nSubjects
        if UseMean
            ChildIndex = ChildIndices(subj);
            TheEEG = AllEEG(ChildIndex);
        end

        % ADD CLUSTERING FOR ONE GREATER THAN MAX SOLUTION %
        % ADD CALCULATION OF W MATRIX TO PASS INTO OTHER FUNCTIONS %

        % Frey and Van Groenewoud - easier to compute across all clustering
        % solutions at once, closer to 1 is better
        FVG(subj, :) = eeg_FreyVanGroenewoud(TheEEG, FitPar);

        for i=1:maxClusters
            nc = ClusterNumbers(i);         % number of clusters
            

            % Assign microstate labels
            Maps = TheEEG.msinfo.MSMaps(nc).Maps;

            % Check for segmented data and reshape if necessary
            
            [ClustLabels, gfp, fit] = AssignMStates(TheEEG,Maps,FitPar,TheEEG.msinfo.ClustPar.IgnorePolarity);
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
            
            % CRITERION CALCULATIONS %

            % Cross Validation
            CV(subj, i) = crossVal;

            % Davies-Bouldin - the lower the better
            DB(subj, i) = evalclusters(IndSamples', ClustLabels, 'DaviesBouldin').CriterionValues;

            % Dunn - the higher the better
            D(subj, i) = eeg_Dunn(IndSamples', ClustLabels);

            % Dispersion (Trace)
            W(subj, i) = eeg_Dispersion(IndSamples',ClustLabels);

            % Cross Validation
            % need to pass in subj
            CV(subj, i) = eeg_crossVal(TheEEG, IndSamples', ClustLabels, ClusterNumbers(i));
            
            % Dispersion (TODO)
            W(subj, i) = eeg_Dispersion(IndSamples',ClustLabels);
            
            % Krzanowski-Lai
            % params: ClustLabels, clustNum, W_i, nClusters, nChannels
            % KL(subj, i) = eeg_krzanowskiLai(ClustLabels, ClusterNumbers(i), W(i), TheEEG.msinfo.ClustPar.MaxClasses, size(IndSamples, 1));
            % Krzanowski-Lai
            KL(subj, i) = krzanowskiLai;
            
            % EXTRA CALCULATIONS %
            % Global Explained Variance - the higher the better
            GEV(subj, i) = fit;

            % Calinski-Harabasz - the higher the better
            CH(subj, i) = evalclusters(IndSamples', ClustLabels, 'CalinskiHarabasz').CriterionValues;

            % Silhouette (TODO)
        end

        % Hartigan - easier to compute across all clustering solutions at
        % once after dispersion has been calculated for all, higher is
        % better
        H(subj, :) = eeg_Hartigan(TheEEG, FitPar, W(subj, :));

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
        [8 2] [8 2] [8 2] [8 2] [8 2] [8 2] 1 1 [8 2] [8 2] [8 2] 1 1}, 'uilist', {...
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
        {'Style', 'checkbox', 'string', 'Krzanowski-Lai', 'tag', 'useKL', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Mariott', 'tag', 'useM', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Point-Biserial', 'tag', 'usePB', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Tau', 'tag', 'useT', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info'} ...
        {'Style', 'checkbox', 'string', 'Trace (Dispersion)', 'tag', 'useW', 'value', 1} ...
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
            title("Cross-Validation");
        end
        if (structout.useDB)
            nexttile
            plot(ClusterNumbers, DB, "-o");
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
            title("Frey and Van Groenewoud")
        end
        if (structout.useH)
            nexttile
            plot(ClusterNumbers, H, "-o");
            title("Hartigan")
        end
        if (structout.useKL)
            nexttile
            plot(ClusterNumbers, KL, "-o");
            title("Krzanowski-Lai");
        end
        if (structout.useW)
            nexttile
            plot(ClusterNumbers, W, "-o");
            title("Dispersion");
        end
        if (structout.useKL)
            nexttile
            plot(ClusterNumbers, KL, "-o");
            title("Krzanowski-Lai");
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