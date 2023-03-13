clear variables
close all
clc

% Set clustering parameters
ClustPar.UseAAHC = false;           % true = AAHC, false = kmeans
ClustPar.MinClasses = 4;
ClustPar.MaxClasses = 7;
ClustPar.Restarts = 5;
ClustPar.MaxMaps = inf;
ClustPar.GFPPeaks = true;
ClustPar.IgnorePolarity = true;
ClustPar.Normalize = true;

% Set backfitting parameters
FitPar.nClasses = 4;
FitPar.PeakFit = true;
FitPar.lambda = 0.3;               % smoothness penalty
FitPar.b = 30;                     % smoothing window (ms)
FitPar.BControl = true;            % remove potentially truncated microstates
FitPar.Rectify = false;
FitPar.Normalize = false;

FittingTemplate = 'Koenig2002';     % published template to use for quantifying     

% Template sorting - by default, 4-6 cluster solutions will be sorted by
% Koenig 2002 maps and 7 cluster solution will be sorted by Custo maps
TemplateNames = {'Koenig2002', 'Custo2017'};
SortClasses   = {4:6,           7         };

% Set path to directory containing group folders
dataDir = uigetdir([], 'Directory containing group folders');
if dataDir == 0;    return; end
groupFolders = dir(dataDir);
groupFolders = groupFolders(~matches({groupFolders.name}, {'.', '..'}));
nGroups = length(groupFolders);
groupDirs = cell(1, nGroups);
groupNames = cell(1, nGroups);
for i=1:nGroups
    groupDirs{i} = fullfile(dataDir, groupFolders(i).name);
    groupNames{i} = groupFolders(i).name;
end

% Set save output path
saveDir = uigetdir([], 'Directory to save results');
if saveDir == 0;    return; end

% Make new directories to store results
subjDir = fullfile(saveDir, '1_Microstates_Clustered_Individual Subjects');
meanDir = fullfile(saveDir, '2_Microstates_Clustered_Mean Sets');
subjFigDir = fullfile(saveDir, '3_Figures_Subject Maps');
meanFigDir = fullfile(saveDir, '4_Figures_Mean Maps');
quantDir = fullfile(saveDir, '5_Quantification of Temporal Dynamics');

mkdir(subjDir);
mkdir(meanDir);
mkdir(subjFigDir);
mkdir(meanFigDir);
mkdir(quantDir);

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

GroupIdx = cell(1, nGroups);
lastGroupIdx = 1;

%% Load datasets and update group info
for i=1:nGroups
    groupDir = groupDirs{i};
    groupFiles = dir(fullfile(groupDir, '*.set'));
    groupFilenames = {groupFiles.name};

    % Load datasets
    fprintf('Loading datasets in group %s...\n', groupNames{i});
    EEG = pop_loadset('filename', groupFilenames, 'filepath', groupDir);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);
    currGroupIdx = lastGroupIdx:numel(ALLEEG);

    % Update group info for all sets
    fprintf('Updating group information for group %s...\n', groupNames{i});
    for j=1:numel(currGroupIdx)
        [EEG, ALLEEG, CURRENTSET] = eeg_retrieve(ALLEEG, currGroupIdx(j));
        EEG.group = groupNames{i};
        [ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
    end    

    GroupIdx{i} = currGroupIdx;
    lastGroupIdx = numel(ALLEEG) + 1;    
end

eeglab redraw
AllSubjects = 1:numel(ALLEEG);

%% Identify microstates
disp('Identifying microstates for all sets...');
[EEG, CURRENTSET] = pop_FindMSTemplates(ALLEEG, AllSubjects, 'ClustPar', ClustPar);
[ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% Identify group level maps
GroupMeanIdx = zeros(1, nGroups);
for i=1:nGroups
    fprintf('Identifying group level mean maps for group %s...\n', groupNames{i});
    [ALLEEG, EEG] = pop_CombMSTemplates(ALLEEG, GroupIdx{i}, 'MeanName', ['GroupMean_' groupNames{i}], 'IgnorePolarity', ClustPar.IgnorePolarity);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off');
    GroupMeanIdx(i) = CURRENTSET;
end

%% Identify grand mean maps
if nGroups > 1
    disp('Identifying grand mean maps across all groups...');
    [ALLEEG, EEG] = pop_CombMSTemplates(ALLEEG, GroupMeanIdx, 'MeanName', 'GrandMean', 'IgnorePolarity', ClustPar.IgnorePolarity);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off');
    GrandMeanIdx = CURRENTSET;
else
    GrandMeanIdx = GroupMeanIdx;
end

eeglab redraw

%% Sorting
% Sort the grand mean maps by the specified published template(s)
disp('Sorting grand mean maps by published templates...');
for i=1:numel(TemplateNames)
    [EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, GrandMeanIdx, 'TemplateSet', TemplateNames{i}, 'Classes', SortClasses{i}, 'IgnorePolarity', ClustPar.IgnorePolarity);
    [ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
end

% Sort the subjects and group level maps by the grand mean maps
disp('Sorting subject and group level maps by grand mean maps...');
[EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, 1:numel(ALLEEG)-1, 'TemplateSet', GrandMeanIdx, 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'IgnorePolarity', ClustPar.IgnorePolarity);
[ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% Save sets and figures
for i=1:nGroups
    currGroupIdx = GroupIdx{i};

    % Plot maps and save figures for all sets in group
    fprintf('Plotting and saving maps for group %s...\n', groupNames{i});
    for j=1:numel(currGroupIdx)
        [ALLEEG, EEG, CURRENTSET, fig] = pop_ShowIndMSMaps(ALLEEG, currGroupIdx(j), 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'Visible', false);
        saveas(fig, fullfile(subjFigDir, [EEG.setname '.png']));
        close(fig);

        % Save sets with microstate maps data    
        pop_saveset(EEG, 'filename', EEG.setname, 'filepath', subjDir);    
    end

    % Plot maps and save figure for group level set
    [ALLEEG, EEG, CURRENTSET, fig] = pop_ShowIndMSMaps(ALLEEG, GroupMeanIdx(i), 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'Visible', false);
    saveas(fig, fullfile(meanFigDir, [EEG.setname '.png']));
    close(fig);

    % Save group level set with microstate maps data
    pop_saveset(EEG, 'filename', EEG.setname, 'filepath', meanDir);
end

% Plot maps and save figure for grand mean set
disp('Plotting and saving grand mean maps...');
[ALLEEG, EEG, CURRENTSET, fig] = pop_ShowIndMSMaps(ALLEEG, GrandMeanIdx, 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'Visible', false);
saveas(fig, fullfile(meanFigDir, [EEG.setname '.png']));
close(fig);
pop_saveset(EEG, 'filename', EEG.setname, 'filepath', meanDir);

%% Quantify microstate dynamics
disp('Quantifying microstate dynamics...');
pop_QuantMSTemplates(ALLEEG, AllSubjects, 'TemplateSet', 'own', 'FitPar', FitPar, 'Filename', fullfile(quantDir, 'MicrostateDynamics_SubjectTemplates.csv'), 'gui', 0);
pop_QuantMSTemplates(ALLEEG, AllSubjects, 'TemplateSet', GrandMeanIdx, 'FitPar', FitPar, 'Filename', fullfile(quantDir, 'MicrostateDynamics_GrandMeanTemplate.csv'), 'gui', 0);
pop_QuantMSTemplates(ALLEEG, AllSubjects, 'TemplateSet', FittingTemplate, 'FitPar', FitPar, 'Filename', fullfile(quantDir, ['MicrostateDynamics_' FittingTemplate '.csv']), 'gui', 0);

%% Export microstate maps to Ragu
if numel(which('Ragu')) > 1
    pop_RaguMSTemplates(ALLEEG, AllSubjects, FitPar.nClasses);
end

eeglab redraw