%% Set parameters
nRuns = 5;
group = 'EO';
nSubjects = 22;
Classes = 4:20;

%% Load datasets
scriptPath = fileparts(mfilename('fullpath'));
setsPath = fullfile(scriptPath, 'EEGLAB sets', 'individual');
setFiles = dir(setsPath);
setFilenames = {setFiles(3:end).name};
setFilenames = setFilenames(contains(setFilenames, group));

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
EEG = pop_loadset('filename', setFilenames, 'filepath', setsPath);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

%% Generate random groups and compute GEV
% outputFilename = strcat(char(datetime('now', 'Format', 'yyyy-MM-dd_HH-mma')), "_", string(nRuns), " runs_Group ", group);
meanSetsPath = fullfile(scriptPath, 'EEGLAB sets', 'mean', group);

grp1_GEVs = nan(nRuns, numel(Classes));
grp2_GEVs = nan(nRuns, numel(Classes));
grp1_grp2_GEVs = nan(nRuns, numel(Classes));
grp2_grp1_GEVs = nan(nRuns, numel(Classes));

for i=1:nRuns

    % Split the datasets into 2 random groups
    idx = randperm(nSubjects);
    grp1Idx = idx(1:floor(nSubjects/2));
    grp2Idx = idx((floor(nSubjects/2)+1):end);

    % Make and save mean sets
    [~, grp1EEG, CURRENTSET] = pop_CombMSTemplates(ALLEEG, grp1Idx, 'MeanName', 'Group1', 'IgnorePolarity', 1, 'Classes', Classes);
    [~, grp2EEG, CURRENTSET] = pop_CombMSTemplates(ALLEEG, grp2Idx, 'MeanName', 'Group2', 'IgnorePolarity', 1, 'Classes', Classes);
    outputPath = fullfile(meanSetsPath, char(datetime('now', 'Format', 'yyyy-MM-dd_HH-mma')));
    mkdir(outputPath);
    pop_saveset(grp1EEG, 'filename', grp1EEG.setname, 'filepath', outputPath, 'savemode', 'onefile');
    pop_saveset(grp2EEG, 'filename', grp2EEG.setname, 'filepath', outputPath, 'savemode', 'onefile');
    
    % Store within-group GEVs
    grp1_GEVs(i,:) = arrayfun(@(x) sum(grp1EEG.msinfo.MSMaps(x).ExpVar), Classes);
    grp2_GEVs(i,:) = arrayfun(@(x) sum(grp2EEG.msinfo.MSMaps(x).ExpVar), Classes);

    % Compute and store between-group GEVs
    grp1_grp2_GEVs(i,:) = arrayfun(@(x) GEV(ALLEEG, grp2Idx, grp1EEG.msinfo.MSMaps(x).Maps), Classes);
    grp2_grp1_GEVs(i,:) = arrayfun(@(x) GEV(ALLEEG, grp1Idx, grp2EEG.msinfo.MSMaps(x).Maps), Classes);
end

% Compute average within and between GEVs
within_GEV = (grp1_GEVs + grp2_GEVs)./2;
between_GEV = (grp1_grp2_GEVs + grp2_grp1_GEVs)./2;

% Compute average across all runs
avg_within_GEV = mean(within_GEV);
avg_between_GEV = mean(between_GEV);

%% Plot
plot(Classes, within_GEV, 'b--');
hold on
plot(Classes, between_GEV, 'r--');
plot(Classes, avg_within_GEV, 'b-', 'LineWidth', 2, 'DisplayName', 'Within');
plot(Classes, avg_between_GEV, 'r-', 'LineWidth', 2, 'DisplayName', 'Between');
legend

function gev = GEV(AllEEG, subjIdx, meanMaps)    
    % Get a nChannels x nMaps array of all individual maps
    indMaps = [];
    nClasses = size(meanMaps,1);
    for s=1:numel(subjIdx)
        indMaps = [indMaps AllEEG(subjIdx(s)).msinfo.MSMaps(nClasses).Maps'];
    end

    Cov = abs(L2NormDim(meanMaps, 2)*indMaps);
    [mfit, ~] = max(Cov);

    gev = sum(mfit.^2)/sum(vecnorm(indMaps).^2);
end