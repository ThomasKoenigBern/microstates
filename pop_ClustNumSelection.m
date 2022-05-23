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
    if ~isfield(TheEEG,'msinfo') || isempty(TheEEG.msinfo)
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
    params.BControl = false;                % do not allow truncating
    [FitPar,paramsComplete] = UpdateFitParameters(FitPar,params,{'lambda','PeakFit','b', 'BControl'});

    if nargin < 5 || paramsComplete == false
        FitPar = SetFittingParameters([], FitPar, ~TheEEG.msinfo.ClustPar.GFPPeaks);
        if isempty(FitPar) return;      end
    end
    
    TheEEG.msinfo.FitPar = FitPar;

    % Specify how much data to use in criterion computations
    [res, ~, ~, structout] = inputgui( 'geometry', {1 [1 1]}, 'uilist', { ...
        { 'Style', 'text', 'string', ['Enter max number of samples to use in criterion computations. ' ...
        'Use inf to use all samples.'], 'fontweight', 'normal' } ...
        { 'Style', 'text', 'string', 'Max number of samples to use', 'fontweight', 'normal' } ...
        { 'Style', 'edit', 'string', '', 'tag' 'MaxSamples'} ...
        },'title','Specify downsampling');
    if isempty(res)
        return
    end
    MaxSamples = str2double(structout.MaxSamples);

    %% Compute criterion for each clustering solution
    ClusterNumbers = TheEEG.msinfo.ClustPar.MinClasses:TheEEG.msinfo.ClustPar.MaxClasses;
    startIndex = find(ClusterNumbers == 4);
    if (~isempty(startIndex))
        ClusterNumbers = ClusterNumbers(startIndex:end);
    end
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
    
    % Criterion for metacriterion (6)
    metacriteria.G = nan(nSubjects, maxClusters);            % Gamma
    metacriteria.S = nan(nSubjects, maxClusters);            % Silhouette
    metacriteria.DB = nan(nSubjects, maxClusters);           % Davies-Bouldin
    metacriteria.PB = nan(nSubjects, maxClusters);           % Point-Biserial
    metacriteria.D = nan(nSubjects, maxClusters);            % Dunn
    metacriteria.KL = nan(nSubjects, maxClusters);           % Krzanowski-Lai

    allMetacriteria = nan(6, maxClusters);                   % all criterion that contribute to final metacriterion

    % Extra criterion
    criteria.CV = nan(nSubjects, maxClusters);           % Cross-Validation (second derivative)
    criteria.FVG = nan(nSubjects, maxClusters);          % Frey and Van Groenewoud
    criteria.H = nan(nSubjects, maxClusters);            % Hartigan (first derivative)
    % KL_nrm = nan(nSubjects, maxClusters);       % Normalized Krzanowski-Lai (according to Murray 2008)
    criteria.TW = nan(nSubjects, maxClusters);           % Trace(W) (second derivative)
    criteria.GEV = nan(nSubjects, maxClusters);          % Global Explained Variance
    criteria.CH = nan(nSubjects, maxClusters);           % Calinski-Harabasz
    
    for subj=1:nSubjects
        if UseMean
            ChildIndex = ChildIndices(subj);
            TheEEG = AllEEG(ChildIndex);
        end
        
        % store time samples and cluster labels for each solution - used as
        % input for Frey and KL index functions
        numClustSolutions = length(ClusterNumbers);
        AllIndSamples = cell(numClustSolutions + 2, 1);
        AllClustLabels = cell(numClustSolutions + 2, 1);

        ClustPar = TheEEG.msinfo.ClustPar;      

        % number of samples with valid microstate assignments for each
        % cluster solution - used as input for Hartigan index function
        nsamples = zeros(maxClusters);

        for i=1:maxClusters
            warning('off', 'stats:pdist2:DataConversion');
            nc = ClusterNumbers(i);         % number of clusters
            
            % Assign microstate labels
            Maps = TheEEG.msinfo.MSMaps(nc).Maps;            
            [ClustLabels, gfp, fit] = AssignMStates(TheEEG,Maps,FitPar,TheEEG.msinfo.ClustPar.IgnorePolarity);
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
            nsamples(i) = size(IndSamples, 2);

            AllIndSamples{i+1} = IndSamples;
            AllClustLabels{i+1} = ClustLabels;
            
            % CRITERION CALCULATIONS %

            % Cross Validation
            criteria.CV(subj, i) = eeg_crossVal(TheEEG, IndSamples', ClustLabels, ClusterNumbers(i));

            % Trace(W)
            criteria.TW(subj, i) = eeg_TW(IndSamples,ClustLabels);
            
            % Davies-Bouldin - the lower the better
            metacriteria.DB(subj, i) = eeg_DaviesBouldin(IndSamples, ClustLabels, TheEEG.msinfo.ClustPar.IgnorePolarity);

            % Dunn - the higher the better
            metacriteria.D(subj, i) = eeg_Dunn(IndSamples', ClustLabels);
            
            % Point-Biserial and Gamma
            [metacriteria.PB(subj, i), metacriteria.G(subj, i)] = eeg_GammaPointBiserial(IndSamples, ClustLabels, TheEEG.msinfo.ClustPar.IgnorePolarity);

            % Global Explained Variance - the higher the better
            criteria.GEV(subj, i) = fit;
            
            % Calinski-Harabasz - the higher the better
            criteria.CH(subj, i) = eeg_CalinskiHarabasz(IndSamples, ClustLabels, TheEEG.msinfo.ClustPar.IgnorePolarity);

            % Silhouette
            % distfun = @(XI,XJ)(1-abs(MyCorr(XI',XJ')));
            % metacriteria.S(subj, i) = sum(silhouette(IndSamples', ClustLabels, distfun))/nsamples(i);
        end

        % Find MS maps for one greater than largest cluster solution
        maxClustNumber = ClusterNumbers(end);
        [IndSamples, ClustLabels] = FindMSMaps(TheEEG, maxClustNumber+1, FitPar, ClustPar, MaxSamples);

        % Find Cross-Validation for one greater than largest cluster
        % solution
        CVmax = eeg_crossVal(TheEEG, IndSamples', ClustLabels, ClusterNumbers(i));

        % compute Trace(W) of one greater than max cluster solution
        TWmax = eeg_TW(IndSamples, ClustLabels);
        TWsubj = criteria.TW(subj, :);

        AllIndSamples{end} = IndSamples;
        AllClustLabels{end} = ClustLabels;

        % Frey and Van Groenewoud - closer to 1 is better
        criteria.FVG(subj, :) = eeg_FreyVanGroenewoud(AllIndSamples(2:end), AllClustLabels(2:end), ClusterNumbers);

        % Find MS maps for one less than smallest cluster solution
        % used for KL index
        minClustNumber = ClusterNumbers(1);
        [IndSamples, ClustLabels] = FindMSMaps(TheEEG, minClustNumber-1, FitPar, ClustPar, MaxSamples);

        % Find Cross-Validation for one less than smallest cluster solution
        CVmin = eeg_crossVal(TheEEG, IndSamples', ClustLabels, ClusterNumbers(i));

        % Find Trace(W) for one less than smallest cluster solution
        TWmin = eeg_TW(IndSamples, ClustLabels);

        % Take second difference of Cross-Validation values
        criteria.CV(subj, :) = diff(diff([CVmin criteria.CV(subj,:) CVmax]));

        % Take second difference of Trace(W) values
        criteria.TW(subj, :) = diff(diff([TWmin criteria.TW(subj,:) TWmax]));

        % Hartigan - higher is better
        H = eeg_Hartigan([TWmin TWsubj TWmax], [(ClusterNumbers(1) - 1) ClusterNumbers], nsamples);

        % Take first difference of Hartigan values
        criteria.H(subj, :) = diff(H);

        AllIndSamples{1} = IndSamples;
        AllClustLabels{1} = ClustLabels;
        
        % Krzanowski-Lai - higher is better
        metacriteria.KL(subj, :) = eeg_krzanowskiLai(AllIndSamples, AllClustLabels, ClusterNumbers, TheEEG.msinfo.ClustPar.IgnorePolarity);

    end

    if UseMean
        % Criterion for metacriterion (11)
        CV = mean(CV, 1);
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
        [8 2] 1 1 [8 2] [8 2] [8 2] [8 2] [8 2] [8 2]}, 'uilist', {...
        {'Style', 'text', 'string', 'Select measures to be plotted:'} ...
        {'Style', 'text', 'string', ''} ...
        {'Style', 'text', 'string', 'Measures for Metacriterion', 'fontweight', 'bold'} ...   
        {'Style', 'checkbox', 'string', 'Gamma', 'tag', 'useG', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @gammaInfo} ...
        {'Style', 'checkbox', 'string', 'Silhouette', 'tag', 'useS', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'Callback', @silhouetteInfo} ...
        {'Style', 'checkbox', 'string', 'Davies-Bouldin', 'tag', 'useDB', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @dbInfo} ...
        {'Style', 'checkbox', 'string', 'Point-Biserial', 'tag', 'usePB', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @pbInfo} ...
        {'Style', 'checkbox', 'string', 'Dunn', 'tag', 'useD', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @dunnInfo} ...
        {'Style', 'checkbox', 'string', 'Krzanowski-Lai', 'tag', 'useKL', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @klInfo} ...        
        {'Style', 'text', 'string', ''} ...
        {'Style', 'text', 'string', 'Other Measures', 'fontweight', 'bold'} ...
        {'Style', 'checkbox', 'string', 'Cross Validation', 'tag', 'useCV', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @cvInfo} ...
        {'Style', 'checkbox', 'string', 'Frey and Van Groenewoud', 'tag', 'useFVG', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @fvgInfo} ...
        {'Style', 'checkbox', 'string', 'Hartigan', 'tag', 'useH', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @hartiganInfo} ...
        {'Style', 'checkbox', 'string', 'Trace(W)', 'tag', 'useTrace', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @traceInfo} ...       
        {'Style', 'checkbox', 'string', 'Global Explained Variance', 'tag', 'useGEV', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @gevInfo} ...
        {'Style', 'checkbox', 'string', 'Calinski-Harabasz', 'tag', 'useCH', 'value', 1} ...
        {'Style', 'pushbutton', 'string', 'Info', 'CallBack', @chInfo} ...
        },'title', 'Data driven selection of number of classes');

    if (isempty(res)) return;   end
    
    %% Plotting
    res = cell2mat(res);

    % number of graphs that are part of the metacriterion
    nMetacriterionGraphs = sum(res(1:6) == 1);
    % number of extra graphs
    nExtraGraphs = sum(res(7:12) == 1);

    % normalize criteria for metacriterion
    names = fieldnames(metacriteria);
    votes = zeros(7, 1);
    for i=1:numel(names)
        % Normalize
        c = metacriteria.(names{i});
        metacriteria.(names{i}) = (c - min(c))/(max(c)-min(c));
        [m, ind] = max(metacriteria.(names{i}));
        votes(i) = ClusterNumbers(ind);

        % Normalize
        c = metacriteria.(names{i});
        c = (c - min(c))/(max(c)-min(c));
        metacriteria.(names{i}) = c;

        if (strcmp(names{i}, 'DB'))
            [m, ind] = min(metacriteria.(names{i}));
            allMetacriteria(i, :) = 1 - c;
        else
            [m, ind] = max(metacriteria.(names{i}));
            allMetacriteria(i, :) = c;
        end
        
        votes(i) = ClusterNumbers(ind);
    end

    % Calculate metacriterion
    medCriterion = median(allMetacriteria);
    [m , ind] = max(medCriterion);
    votes(end) = ClusterNumbers(ind);
    metacriteria.MC = median(votes);

    % Normalize and adjust all extra criteria
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
    end
    
    figure('Name', 'Measures for Metacriterion', 'Position', [100 100 700 600]);
%     leg = legend('Orientation', 'Horizontal');
%     leg.Layout.Tile = 'north';
    if (nMetacriterionGraphs == 2)
        tiledlayout(2, 2)
    end
    if (nMetacriterionGraphs >= 3)
        tiledlayout(3, 2);
    end
    if (nMetacriterionGraphs >= 5)
        tiledlayout(4, 2);
    end  

    if (structout.useS)
        nexttile
        plot(ClusterNumbers, metacriteria.S, "-o");
        title("Silhouette");
    end
    if (structout.useDB)
        nexttile
        plot(ClusterNumbers, metacriteria.DB, "-ro");
        title("Davies-Bouldin");
    end
    if (structout.usePB)
        nexttile
        plot(ClusterNumbers, metacriteria.PB, "-o");
        title("Point-Biserial");
    end
    if (structout.useD)
        nexttile
        plot(ClusterNumbers, metacriteria.D, "-ro");
        title("Dunn");
    end
    if (structout.useKL)
        nexttile
        plot(ClusterNumbers, metacriteria.KL, "-o");
        title("Krzanowski-Lai");
    end
    if (structout.useG)
        nexttile
        plot(ClusterNumbers, metacriteria.G, "-o");
        title("Gamma");
    end

    % add histogram with votes
    edges = [(ClusterNumbers - 0.5) ClusterNumbers(end) + 0.5];
    nexttile([1 2])
    histogram(votes, edges);
    title('Optimal Number of Microstates Votes Distribution');

    if (nExtraGraphs > 0)
        figure('Name', 'Extra Measures', 'Position', [900 200 600 500]);
        tiledlayout(nExtraGraphs, 1);
        
        if (nExtraGraphs == 2)
            tiledlayout(1, 2)
        end        
        if (nExtraGraphs >= 3)
            tiledlayout(2, 2);
        end
        if (nExtraGraphs >= 5)
            tiledlayout(3, 2);
        end        
        
        if (structout.useCV)
            nexttile
            plot(ClusterNumbers, criteria.CV, "-o");
            title("Cross-Validation");
        end
        if (structout.useFVG)
            nexttile
            plot(ClusterNumbers, criteria.FVG, "-o");
            title("Frey and Van Groenewoud")
        end
        if (structout.useH)
            nexttile
            plot(ClusterNumbers, criteria.H, "-o");
            title("Hartigan")
        end
        if (structout.useTrace)
            nexttile
            plot(ClusterNumbers, criteria.TW, "-o");
            title("Trace(W)");
        end
        if (structout.useGEV)
            nexttile
            plot(ClusterNumbers, criteria.GEV, "-o");
            title("GEV");
        end
        if (structout.useCH)
            nexttile
            plot(ClusterNumbers, criteria.CH, "-o");
            title("Calinski-Harabasz");
        end
    end
%     function [TheEEG,com] = pop_FindMSTemplates(TheEEG, ClustPar, ShowMaps,ShowDyn)
%     com = sprintf('[%s,com] = pop_FindMSTemplates(%s, %s, %i, %i);', inputname(1),inputname(1),structInfo,ShowMaps,ShowDyn);
% 
%    com = sprintf('[%s, %s, com] = pop_ClustNumSelection(%s, %s, %s, %s, %i, %i);', inputname(1), inputname(1), inputname(1), inputname(1), inputname(1), UseMean,FitPar,MeanSet);
%     com = sprintf('[AllEEG, TheEEG, com] = pop_ClustNumSelection(AllEEG,TheEEG,CurrentSet,UseMean,FitPar,MeanSet)

end

function gammaInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on gamma criterion here'}})
end
function silhouetteInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'The silhouette value for each point is a measure of how similar that point is to points in its own cluster, when compared to points in other clusters. The silhouette value ranges from –1 to 1. A high silhouette value indicates that i is well matched to its own cluster, and poorly matched to other clusters. If most points have a high silhouette value, then the clustering solution is appropriate. If many points have a low or negative silhouette value, then the clustering solution might have too many or too few clusters. You can use silhouette values as a clustering evaluation criterion with any distance metric.'}})
end
function dbInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on Davies Bouldin criterion here'}})
end
function pbInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on Point-Biserial criterion here'}})
end
function dunnInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on Dunn criterion here'}})
end
function klInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on Krzanowski-Lai criterion here'}})
end
function cvInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on Cross-Validation criterion here'}})
end
function fvgInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on Frey Van Groenwood criterion here'}})
end
function hartiganInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on Hartigan criterion here'}})
end
function traceInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on trace(w) criterion here'}})
end
function gevInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on GEV criterion here'}})
end
function chInfo(src,event)
    inputgui('geometry', [1], 'uilist', {...
        {'Style', 'text', 'string', ...
        'Info on Calinski-Harabasz criterion here'}})
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

function [IndSamples, ClustLabels] = FindMSMaps(TheEEG, numClusts, FitPar, ClustPar, MaxSamples)
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