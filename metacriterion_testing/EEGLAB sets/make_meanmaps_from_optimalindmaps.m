clear variables

scriptPath = fileparts(mfilename('fullpath'));

% CHANGE DATA TYPE HERE %
dataName = '71 channels';
% CHANGE DIRECTORIES HERE %
csvsPath = fullfile(scriptPath, '../criteria csvs', 'individual_csvs');
clusteredSetsPath = fullfile(scriptPath, 'TD_EC_EO_3-11microstates');

% MODIFY INCLUDED AND EXCLUDED CRITERIA HERE %
replaceCV = 1;
includedCriteria = {'CV', 'DB', 'D', 'FVG', 'KL', 'KLnrm', 'PB'};
excludedCriteria = {'CH', 'S'};

% SET METACRITERION TYPE TO USE HERE %
useIQMSNR = 1;      % 1 = use IQM/SNR metacriterion, 0 = use median vote metacriterion
if useIQMSNR
    metacriterionName = 'IQMSNR';
else
    metacriterionName = 'Median Vote';
end

numCriteria = numel(includedCriteria);
includedCriteriaString = sprintf('%s ', string(includedCriteria));
includedCriteriaString(end) = [];

nSubjects = 44;
ClusterNumbers = 4:10;
numClustSolutions = numel(ClusterNumbers);

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

% Load the datasets
setFiles = dir(clusteredSetsPath);
setFilenames = {setFiles(3:end).name};

EEG = pop_loadset('filename', setFilenames, 'filepath', clusteredSetsPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

chanlocs = EEG.chanlocs;

% Get the csv filenames
csvFiles = dir(csvsPath);
csvFilenames = {csvFiles(3:end).name};

% Aggregate the optimal map numbers for the EC sets and EO sets
EC_optimalIndMaps = [];
EO_optimalIndMaps = [];

for i=1:numel(csvFilenames)
    csvFilename = csvFilenames{i};
    tbl = readtable(fullfile(csvsPath, csvFilename));
    
    % Rename table column names and remove header row with NaN values
    tbl.Properties.VariableNames = {'run_no', 'sample_size', 'criterion_name', ...
        'clust4', 'clust5', 'clust6', 'clust7', 'clust8', 'clust9', 'clust10'};
    tbl(1,:) = [];

    % Find rows with criteria values from using all GFP peaks
    isAllPeaks = (tbl.sample_size ~= 1000) & (tbl.sample_size ~= 2000) & (tbl.sample_size ~= 4000);
    criteriaValues = tbl(isAllPeaks, :);

    % remove CV and rename CV2
    if replaceCV
        criteriaValues(matches(criteriaValues.criterion_name, 'CV'), :) = [];
        criteriaValues{matches(criteriaValues.criterion_name, 'CV2'), 3} = {'CV'};
    end

    % remove criteria to exclude
    for c=1:numel(excludedCriteria)
        cIdx = matches(criteriaValues.criterion_name, excludedCriteria{c});
        if any(cIdx)
            criteriaValues(cIdx, :) = [];
        end
    end

    % sort in alphabetical order
    [sortedNames, sortIdx] = sort(criteriaValues.criterion_name);
    criteriaValues = criteriaValues{sortIdx, 4:end};

    % compute IQM
    criterionIQM = sort(criteriaValues);                            % first sort the columns and make copy of array
    quartileSize = numCriteria/4;                                   % calculate quartile size

    % if number of criterion chosen is divisible by 4, can take IQM
    % without weighting partial values
    if (mod(numCriteria, 4) == 0)
        criterionIQM = criterionIQM(1+quartileSize:numCriteria-quartileSize,:);
        IQM = mean(criterionIQM);
    % otherwise, find full and partial observations of IQR and weight for
    % partial values
    else
        removeSize = floor(quartileSize);                           % number of values to remove from 1st and 4th quartiles
        criterionIQM = criterionIQM(1+removeSize:end-removeSize,:); % full and partial values of IQR
        nIQR = numCriteria - 2*quartileSize;                        % number of values in IQR
        nFull = size(criterionIQM,1) - 2;                           % number of full values in IQR
        weight = (nIQR-nFull)/2;                                    % weight to multiply partial values of IQR by
        IQM = zeros(1, numClustSolutions);
        for c=1:numClustSolutions
            IQM(c) = (weight*(criterionIQM(1, c) + criterionIQM(end, c)) + sum(criterionIQM(2:end-1, c)))/nIQR;
        end
    end
    
    % compute IQR
    IQR = iqr(criteriaValues);

    % compute metacriterion
    metacriterion = (IQM.^2)./IQR;

    % normalize
    metacriterion = (metacriterion - min(metacriterion))/(max(metacriterion) - min(metacriterion));
    
    % Get the optimal number of maps from the dataset using either the
    % IQM/SNR metacriterion or the median metacriterion
    [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);

    if useIQMSNR
        % find optimal cluster number predicted by IQM/SNR metacriterion
        [M, ind] = max(metacriterion);
        optimalNMaps = ClusterNumbers(ind);
        optimalIndMaps = EEG.msinfo.MSMaps(optimalNMaps).Maps;
    else
        % find optimal cluster number for each criterion
        [M, ind] = max(criteriaValues, [], 2);
        optimalNMaps = median(ClusterNumbers(ind));
        optimalIndMaps = EEG.msinfo.MSMaps(optimalNMaps).Maps;
    end

    if contains(csvFilename, 'EC')
        EC_optimalIndMaps = [EC_optimalIndMaps; optimalIndMaps];
    elseif contains(csvFilename, 'EO')
        EO_optimalIndMaps = [EO_optimalIndMaps; optimalIndMaps];
    end
end

% Cluster the optimal maps across participants into mean
MinClust = 3;
MaxClust = 11;
NumRestarts = 10;
ClustType = 0; %k-means = 0, AAHC = 1
ClustPar = struct('MinClasses',MinClust,'MaxClasses',MaxClust,'GFPPeaks',true,'IgnorePolarity',true,'MaxMaps',inf,'Restarts',NumRestarts, 'UseAAHC', ClustType,'Normalize',true);

flags = '';
if ClustPar.IgnorePolarity == false
    flags = [flags 'p'];
end
if ClustPar.Normalize == true
    flags = [flags 'n'];
end

% EC
for nClusters = ClustPar.MinClasses:ClustPar.MaxClasses
    [b_model,~,~,exp_var] = eeg_kMeans(EC_optimalIndMaps,nClusters,ClustPar.Restarts,[],flags,chanlocs);

    EC_msinfo.MSMaps(nClusters).Maps = b_model;
    EC_msinfo.MSMaps(nClusters).ExpVar = double(exp_var);
    EC_msinfo.MSMaps(nClusters).ColorMap = lines(nClusters);
    for j = 1:nClusters
        EC_msinfo.MSMaps(nClusters).Labels{j} = sprintf('MS_%i.%i',nClusters,j);
    end
    EC_msinfo.MSMaps(nClusters).SortMode = 'none';
    EC_msinfo.MSMaps(nClusters).SortedBy = '';
    EC_msinfo.MSMaps(nClusters).SpatialCorrelation= [];
end

% EO
for nClusters = ClustPar.MinClasses:ClustPar.MaxClasses
    [b_model,~,~,exp_var] = eeg_kMeans(EO_optimalIndMaps,nClusters,ClustPar.Restarts,[],flags,chanlocs);

    EO_msinfo.MSMaps(nClusters).Maps = b_model;
    EO_msinfo.MSMaps(nClusters).ExpVar = double(exp_var);
    EO_msinfo.MSMaps(nClusters).ColorMap = lines(nClusters);
    for j = 1:nClusters
        EO_msinfo.MSMaps(nClusters).Labels{j} = sprintf('MS_%i.%i',nClusters,j);
    end
    EO_msinfo.MSMaps(nClusters).SortMode = 'none';
    EO_msinfo.MSMaps(nClusters).SortedBy = '';
    EO_msinfo.MSMaps(nClusters).SpatialCorrelation= [];
end

% Create new EEGLAB sets

% EC
EC_EEG = eeg_emptyset();
EC_EEG.chanlocs     = chanlocs;
EC_EEG.data         = EC_optimalIndMaps';
EC_EEG.msinfo       = EC_msinfo;
EC_EEG.setname      = sprintf('EC Mean From Optimal Ind Maps_%s_%s', dataName, metacriterionName);
EC_EEG.nbchan       = size(EC_EEG.data,1);
EC_EEG.trials       = size(EC_EEG.data,3);
EC_EEG.pnts         = size(EC_EEG.data,2);
EC_EEG.srate        = 1;
EC_EEG.xmin         = 1;
EC_EEG.times        = 1:EC_EEG.pnts;
EC_EEG.xmax         = EC_EEG.times(end);

pop_saveset(EC_EEG, 'filename', EC_EEG.setname, 'filepath', fullfile(scriptPath, 'TD_EC_EO_Mean_Sets'), 'savemode', 'onefile');

% EO
EO_EEG = eeg_emptyset();
EO_EEG.chanlocs     = chanlocs;
EO_EEG.data         = EO_optimalIndMaps';
EO_EEG.msinfo       = EO_msinfo;
EO_EEG.setname      = sprintf('EO Mean From Optimal Ind Maps_%s_%s', dataName, metacriterionName);
EO_EEG.nbchan       = size(EO_EEG.data,1);
EO_EEG.trials       = size(EO_EEG.data,3);
EO_EEG.pnts         = size(EO_EEG.data,2);
EO_EEG.srate        = 1;
EO_EEG.xmin         = 1;
EO_EEG.times        = 1:EO_EEG.pnts;
EO_EEG.xmax         = EO_EEG.times(end);

pop_saveset(EO_EEG, 'filename', EO_EEG.setname, 'filepath', fullfile(scriptPath, 'TD_EC_EO_Mean_Sets'), 'savemode', 'onefile');