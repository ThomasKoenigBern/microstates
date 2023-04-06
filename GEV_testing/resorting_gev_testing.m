%% Set parameters
nRuns = 5;
group = 'EC';
nSubjects = 22;
Classes = 4:9;
   

%% Load datasets
scriptPath = fileparts(mfilename('fullpath'));
setsPath = fullfile(scriptPath, 'EEGLAB sets', 'individual');
setFiles = dir(setsPath);
setFilenames = {setFiles(3:end).name};
setFilenames = setFilenames(contains(setFilenames, group));

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
EEG = pop_loadset('filename', setFilenames, 'filepath', setsPath);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

%% Load group datasets and compute GEVs
meanSetsPath = fullfile(scriptPath, 'EEGLAB sets', 'mean', group);
meanFolders = dir(meanSetsPath);
meanFoldernames = {meanFolders(3:end).name};

quantPath = fullfile(scriptPath, 'quantify_csvs', group);

grp1_GEVs = nan(nRuns, numel(Classes));
grp2_GEVs = nan(nRuns, numel(Classes));
grp1_grp2_GEVs = nan(nRuns, numel(Classes));
grp2_grp1_GEVs = nan(nRuns, numel(Classes));

for i=1:nRuns
    % Load group datasets
    grp1EEG = pop_loadset('filename', 'Group1.set', 'filepath', fullfile(meanSetsPath, meanFoldernames{i}));
    [tmpALLEEG, ~, CURRENTSET] = pop_newset(ALLEEG, grp1EEG, CURRENTSET);
    grp2EEG = pop_loadset('filename', 'Group2.set', 'filepath', fullfile(meanSetsPath, meanFoldernames{i}));
    tmpALLEEG = pop_newset(tmpALLEEG, grp2EEG, CURRENTSET);

    grp1Idx = find(matches({tmpALLEEG.setname}, grp1EEG.msinfo.children));
    grp2Idx = find(matches({tmpALLEEG.setname}, grp2EEG.msinfo.children));

    % Sort all subjects by group 1 mean maps
    [tmpALLEEG, EEG, CURRENTSET] = pop_SortMSTemplates(tmpALLEEG, 1:nSubjects, 'TemplateSet', 'Group1', 'IgnorePolarity', 1, 'Classes', Classes);
    % Within group GEV (Group 1 mean maps vs. Group 1 subject maps)
    grp1_GEVs(i,:) = arrayfun(@(x) GEV(tmpALLEEG, grp1Idx, grp1EEG.msinfo.MSMaps(x).Maps), Classes);
    % Between group GEV (Group 1 mean maps vs. Group 2 subject maps)
    grp1_grp2_GEVs(i,:) = arrayfun(@(x) GEV(tmpALLEEG, grp2Idx, grp1EEG.msinfo.MSMaps(x).Maps), Classes);

    % Sort all subjects by group 2 mean maps
    [tmpALLEEG, EEG, CURRENTSET] = pop_SortMSTemplates(tmpALLEEG, 1:nSubjects, 'TemplateSet', 'Group2', 'IgnorePolarity', 1, 'Classes', Classes);
    % Within group GEV (Group 2 mean maps vs. Group 2 subject maps)
    grp2_GEVs(i,:) = arrayfun(@(x) GEV(tmpALLEEG, grp2Idx, grp2EEG.msinfo.MSMaps(x).Maps), Classes);
    % Between group GEV (Group 2 mean maps vs. Group 1 subject maps)
    grp2_grp1_GEVs(i,:) = arrayfun(@(x) GEV(tmpALLEEG, grp1Idx, grp2EEG.msinfo.MSMaps(x).Maps), Classes);
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

function gev = GEV(AllEEG, subjIdx, meanMaps)    
    % Get a nMaps x nChannels array of all individual maps
    indMaps = [];
    nClasses = size(meanMaps,1);
    for s=1:numel(subjIdx)
        indMaps = [indMaps; AllEEG(subjIdx(s)).msinfo.MSMaps(nClasses).Maps];
    end
    
    fit = sum(abs(repmat(L2NormDim(meanMaps,2), numel(subjIdx), 1).*indMaps), 2);
    gev = sum(fit.^2)/sum(vecnorm(indMaps').^2);
end