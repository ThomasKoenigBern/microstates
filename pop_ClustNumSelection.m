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
        errordlg2('The data does not contain microstate maps','Data driven selection of number of microstates');
        return;
    end
    
    % if doing mean level analysis and the mean set is not already 
    % passed in, check if the currently selected EEG structure is a mean
    % set and if not, have the user select the mean set
    if UseMean == true && isempty(MeanSet)
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
    
    % Select fitting parameters
    if UseMean == false
        if isfield(TheEEG.msinfo,'FitPar');              params = TheEEG.msinfo.FitPar;
        else params = [];
        end
    else
        if isfield(AllEEG(MeanSet).msinfo,'FitPar');     params = AllEEG(MeanSet).msinfo.FitPar;
        else params = [];
        end
    end
    [FitPar,paramsComplete] = UpdateFitParameters(FitPar,params,{'lambda','PeakFit','b','BControl'});

    if nargin < 4 || paramsComplete == false
        FitPar = SetFittingParameters([],FitPar);
    end
    
    TheEEG.msinfo.FitPar = FitPar;

    %% Compute criterion for each clustering solution
    ClusterNumbers = TheEEG.msinfo.ClustPar.MinClasses:TheEEG.msinfo.ClustPar.MaxClasses;
    maxClusters = size(ClusterNumbers, 2);

    % Criterion for metacriterion (11)
    CV = nan(maxClusters, 1);           % Cross-Validation
    CC = nan(maxClusters, 1);           % Cubic-Clustering Criterion
    DB = nan(maxClusters, 1);           % Davies-Bouldin
    D = nan(maxClusters, 1);         % Dunn
    FVG = nan(maxClusters, 1);          % Frey and Van Groenewoud
    H = nan(maxClusters, 1);            % Hartigan
    KL = nan(maxClusters, 1);           % Krzanowski-Lai
    M = nan(maxClusters, 1);            % Mariott
    PB = nan(maxClusters, 1);           % Point-Biserial
    T = nan(maxClusters, 1);            % Tau
    W = nan(maxClusters, 1);            % Trace (Dispersion)

    % Other criterion
    GEV = nan(maxClusters, 1);
    CH = nan(maxClusters, 1);    
    Silhouette = nan(maxClusters, 1);

    for i=1:maxClusters
        nc = ClusterNumbers(i);         % number of clusters

        % if not using a MeanSet, find the single criterion value for each
        % clustering solution
        if UseMean == false
            % Assign microstate labels
            Maps = TheEEG.msinfo.MSMaps(nc).Maps;
            [ClustLabels, gfp, fit, crossVal] = AssignMStates(TheEEG,Maps,FitPar,TheEEG.msinfo.ClustPar.IgnorePolarity);
            
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
            % Check for zero elements in ClustLabels (in case of truncating)
            zeroIndices = find(~ClustLabels);
            if (size(zeroIndices,1) > 0)
                % remove samples with no microstate assignmnets
                IndSamples(:, zeroIndices') = [];
                % remove clust labels of zero
                ClustLabels(zeroIndices') = [];
            end
            
            % CRITERION CALCULATIONS
            
            % Global Explained Variance
            GEV(i) = fit;

            % Calinski-Harabasz - the higher the better
            %CH(i) = eeg_CalinskiHarabasz(IndSamples', ClustLabels);
            % CH(i) = evalclusters(IndSamples', ClustLabels, 'CalinskiHarabasz');

            % Davies-Bouldin
            % DB(i) = evalclusters(IndSamples', ClustLabels, 'DaviesBouldin');
            %DB(i) = eeg_DaviesBouldin(IndSamples', ClustLabels);

            % Cross Validation (TODO)
            CV(i) = crossVal;
            
            % Dispersion (TODO)

            % Silhouette (TODO)
        end
%         disp(CV)
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
    
    function silhouetteInfo(src,event)
        inputgui('geometry', [1], 'uilist', {...
            {'Style', 'text', 'string', ...
            'The silhouette value for each point is a measure of how similar that point is to points in its own cluster, when compared to points in other clusters. The silhouette value ranges from –1 to 1. A high silhouette value indicates that i is well matched to its own cluster, and poorly matched to other clusters. If most points have a high silhouette value, then the clustering solution is appropriate. If many points have a low or negative silhouette value, then the clustering solution might have too many or too few clusters. You can use silhouette values as a clustering evaluation criterion with any distance metric.'}})
    end
end