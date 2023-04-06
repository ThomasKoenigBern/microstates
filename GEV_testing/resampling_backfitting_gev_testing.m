%% Set parameters
nRuns = 5;
group = 'EO';
nSubjects = 22;
Classes = 4:20;

FitPar.PeakFit = 1;            
FitPar.BControl = true;       

%% Load datasets
scriptPath = fileparts(mfilename('fullpath'));
setsPath = fullfile(scriptPath, 'EEGLAB sets', 'individual');
setFiles = dir(setsPath);
setFilenames = {setFiles(3:end).name};
setFilenames = setFilenames(contains(setFilenames, group));

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
EEG = pop_loadset('filename', setFilenames, 'filepath', setsPath);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

%% Load group datasets and backfit
meanSetsPath = fullfile(scriptPath, 'EEGLAB sets', 'mean', group);
meanFolders = dir(meanSetsPath);
meanFoldernames = {meanFolders(3:end).name};

quantPath = fullfile(scriptPath, 'quantify_csvs', group);

grp1_GEVs = nan(nRuns, nSubjects/2, numel(Classes));
grp2_GEVs = nan(nRuns, nSubjects/2, numel(Classes));
grp1_grp2_GEVs = nan(nRuns, nSubjects/2, numel(Classes));
grp2_grp1_GEVs = nan(nRuns, nSubjects/2, numel(Classes));

for i=1:nRuns
    % Load group datasets
    grp1EEG = pop_loadset('filename', 'Group1.set', 'filepath', fullfile(meanSetsPath, meanFoldernames{i}));
    [tmpALLEEG, ~, CURRENTSET] = pop_newset(ALLEEG, grp1EEG, CURRENTSET);
    grp2EEG = pop_loadset('filename', 'Group2.set', 'filepath', fullfile(meanSetsPath, meanFoldernames{i}));
    tmpALLEEG = pop_newset(tmpALLEEG, grp2EEG, CURRENTSET);

    grp1Idx = find(matches({ALLEEG.setname}, grp1EEG.msinfo.children));
    grp2Idx = find(matches({ALLEEG.setname}, grp2EEG.msinfo.children));

    % Backfit within and between groups and save GEVs
    for c=1:numel(Classes)
        FitPar.nClasses = Classes(c);

        % Within groups
        quantFilename = fullfile(quantPath, sprintf('Group1-Group1_%i classes_run %i', Classes(c), i));
        [EEG CURRENTSET] = pop_QuantMSTemplates(tmpALLEEG, grp1Idx, 'TemplateSet', 'Group1', 'FitPar', FitPar, 'Filename', quantFilename, 'gui', false);
        grp1_GEVs(i, :, c) = arrayfun(@(x) EEG(x).msinfo.stats.TotalExpVar, 1:numel(EEG));

        quantFilename = fullfile(quantPath, sprintf('Group2-Group2_%i classes_run %i', Classes(c), i));
        [EEG CURRENTSET] = pop_QuantMSTemplates(tmpALLEEG, grp2Idx, 'TemplateSet', 'Group2', 'FitPar', FitPar, 'Filename', quantFilename, 'gui', false);
        grp2_GEVs(i, :, c) = arrayfun(@(x) EEG(x).msinfo.stats.TotalExpVar, 1:numel(EEG));

        % Between groups
        quantFilename = fullfile(quantPath, sprintf('Group1-Group2_%i classes_run %i', Classes(c), i));
        [EEG CURRENTSET] = pop_QuantMSTemplates(tmpALLEEG, grp2Idx, 'TemplateSet', 'Group1', 'FitPar', FitPar, 'Filename', quantFilename, 'gui', false);
        grp1_grp2_GEVs(i, :, c) = arrayfun(@(x) EEG(x).msinfo.stats.TotalExpVar, 1:numel(EEG));

        quantFilename = fullfile(quantPath, sprintf('Group2-Group1_%i classes_run %i', Classes(c), i));
        [EEG CURRENTSET] = pop_QuantMSTemplates(tmpALLEEG, grp1Idx, 'TemplateSet', 'Group2', 'FitPar', FitPar, 'Filename', quantFilename, 'gui', false);
        grp2_grp1_GEVs(i, :, c) = arrayfun(@(x) EEG(x).msinfo.stats.TotalExpVar, 1:numel(EEG));

    end
end

% Compute average GEVs across all subjects
avg_grp1_GEVs = squeeze(mean(grp1_GEVs, 2));
avg_grp2_GEVs = squeeze(mean(grp2_GEVs, 2));
avg_grp1_grp2_GEVs = squeeze(mean(grp1_grp2_GEVs, 2));
avg_grp2_grp1_GEVs = squeeze(mean(grp2_grp1_GEVs, 2));

% Compute average within and between GEVs
within_GEV = (avg_grp1_GEVs + avg_grp2_GEVs)./2;
between_GEV = (avg_grp1_grp2_GEVs + avg_grp2_grp1_GEVs)./2;

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