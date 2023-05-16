%%  Demo script for microstate analyses in EEGLAB
%
%   Author: Thomas Koenig, University of Bern, Switzerland, 2018
%  
%   Copyright (C) 2018 Thomas Koenig, University of Bern, Switzerland
%   thomas.koenig@upd.unibe.ch
%  
%   This program is free software; you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation; either version 2 of the License, or
%   (at your option) any later version.
%  
%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU General Public License for more details.
%  
%   You should have received a copy of the GNU General Public License
%   along with this program; if not, write to the Free Software
%   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
%
% ---------------------------------
% This is a sample script that you may have to adapt to meet your specific
% needs.
%
%   Section 1 contains default clustering, backfitting, and sorting
%   parameters that can be modified as necessary.
%
%   Section 2 will prompt you for a directory containing your EEG data. For
%   the script to work as is, your data should be organized in folders by
%   group, with the group names used for the folder names. (E.g. a "data"
%   folder containing two folders, "data/Eyes_Closed" and "data/Eyes_Open")
%   It will also prompt you for a directory to save the analysis results.
%
%   Section 3 will load the datasets from the input folder you
%   provide and update the "group" field of each dataset loaded. Please
%   note that this script assumes your files are in .set format and may
%   need to be modified if your datasets are in a different format.
%
%   Section 4 will perform clustering to identify individual microstate map
%   templates for all loaded datasets.
%
%   Section 5 will identify group level microstate map templates for each
%   group.
%
%   Section 6 will identify grand mean microstate map templates across all
%   group level templates.
%
%   Section 7 will sort the identified microstate maps. First, the grand
%   mean maps will be sorted according to the published template maps
%   specified in the parameters section. By default, the Koenig 2002 maps
%   will be used to sort 4-6 cluster solutions, and the Custo 2017 maps
%   will be used to sort the 7 cluster solution. These can be modified
%   depending on the cluster solutions you would like to identify. If you
%   would like to use your own published template maps for sorting, add the
%   set file containing the maps to the "microstates/Templates" folder. 
%   The maps should be contained in the "msinfo" field of the EEG struct,
%   and should contain unique labels and colors for each map. After the
%   grand mean maps are sorted, the individual and group level maps will be
%   sorted by the grand mean maps.
%
%   Section 8 will save the individual, group level, and grand mean set
%   files containing the microstate maps data, along with figures
%   containing the plotted microstate maps.
%
%   Section 9 will perform backfitting and quantification of temporal
%   dynamics according to different template maps. It will save 3 different
%   files for each solution used for backfitting, one containing temporal 
%   parameters from using individual maps for backfitting, one from using 
%   the grand mean templates for backfitting, and one from using a 
%   published template for backfitting. It will also save figures
%   containing the plotted distribution of temporal parameters across all
%   datasets, as well as return the extracted temporal parameters in the
%   "MSStats" structure array for further analysis. The published template 
%   to use for backfitting can be modified in the parameters section.
%
%   Section 10 will export the generated microstate maps to the Ragu 
%   software for further optional analysis. This section will only occur if
%   Ragu has been downloaded.

clear variables
close all
clc

%% 1. Set clustering, backfitting, and sorting parameters

% Set clustering parameters
ClustPar.UseAAHC = false;               % true = AAHC, false = kmeans
ClustPar.MinClasses = 4;                % minimum number of clusters to identify
ClustPar.MaxClasses = 7;                % maximum number of clusters to identify
ClustPar.Restarts = 20;                 % number of times kmeans algorithm is restarted (ignored if using AAHC)
ClustPar.MaxMaps = inf;                 % maximum number of data samples to use to identify clusters
ClustPar.GFPPeaks = true;               % whether clustering should be limited to global field power peaks
ClustPar.IgnorePolarity = true;         % whether maps of inverted polarities should be considered part of the same cluster
ClustPar.Normalize = true;              % Set to false if using AAHC

% Set backfitting parameters
FitPar.Classes = ClustPar.MinClasses:ClustPar.MaxClasses;   % cluster solutions to use for backfitting
FitPar.PeakFit = ClustPar.GFPPeaks;                         % whether to backfit only on global field power peaks
FitPar.lambda = 0.3;                                        % smoothness penalty - ignored if FitPar.PeakFit = 1
FitPar.b = 30;                                              % smoothing window (ms) - ignored if FitPar.PeakFit = 1
    
% Template sorting - by default, 4-6 cluster solutions will be sorted by
% Koenig 2002 maps and 7 cluster solution will be sorted by Custo maps
% NOTE: If more than 7 maps are identified, please either update 
% the "TemplateNames" and "SortClasses" variables below with your own
% template, or use the interactive explorer to manually sort maps.
TemplateNames = {'Koenig2002', 'Custo2017'};
SortClasses   = {4:6,           7         };

%% 2. Get input directory and create output directories
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

% Make sub-directory with current date and time
subDir = fullfile(saveDir, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH-mma')) '_Microstates Analysis']);
mkdir(subDir);

% Make new directories to store results
subjDir = fullfile(subDir, '1_Set files with individual microstate maps');
meanDir = fullfile(subDir, '2_Set files with group level and grand mean microstate maps');
subjFigDir = fullfile(subDir, '3_Png files with individual microstate maps');
meanFigDir = fullfile(subDir, '4_Png files with group level and grand mean microstate maps');
quantDir = fullfile(subDir, '5_Csv files of temporal dynamics parameters');
quantFigDir = fullfile(subDir, '6_Png files of plotted temporal dynamics parameters');

mkdir(subjDir);
mkdir(meanDir);
mkdir(subjFigDir);
mkdir(meanFigDir);
mkdir(quantDir);
mkdir(quantFigDir);

% Save copy of current script to output folder to document which parameters were used
scriptPath = [mfilename('fullpath') '.m'];
copyfile(scriptPath, subDir);

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('nogui');
pluginpath = fileparts(which('eegplugin_Microstates.m'));
addpath(genpath(pluginpath));

% Load template sets
templatepath = fullfile(pluginpath,'Templates');
Templates = dir(fullfile(templatepath,'*.set'));
MSTemplate = [];   
for t = 1: numel(Templates)
    MSTemplate = eeg_store(MSTemplate,pop_loadset('filename',Templates(t).name,'filepath',templatepath));
end
global MSTEMPLATE;
MSTEMPLATE = MSTemplate;

GroupIdx = cell(1, nGroups);
lastGroupIdx = 1;

%% 3. Load datasets and update group info
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

AllSubjects = 1:numel(ALLEEG);

%% 4. Identify individual template maps
disp('Identifying microstates for all sets...');
[EEG, CURRENTSET] = pop_FindMSTemplates(ALLEEG, AllSubjects, 'ClustPar', ClustPar);
[ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% 5. Identify group level template maps
GroupMeanIdx = zeros(1, nGroups);
for i=1:nGroups
    fprintf('Identifying group level mean maps for group %s...\n', groupNames{i});
    [ALLEEG, EEG] = pop_CombMSTemplates(ALLEEG, GroupIdx{i}, 'MeanName', ['GroupMean_' groupNames{i}], 'IgnorePolarity', ClustPar.IgnorePolarity);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off');
    GroupMeanIdx(i) = CURRENTSET;
end

%% 6. Identify grand mean template maps
if nGroups > 1
    disp('Identifying grand mean maps across all groups...');
    [ALLEEG, EEG] = pop_CombMSTemplates(ALLEEG, GroupMeanIdx, 'MeanName', 'GrandMean', 'IgnorePolarity', ClustPar.IgnorePolarity);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off');
    GrandMeanIdx = CURRENTSET;
else
    GrandMeanIdx = GroupMeanIdx;
end

%% 7. Sorting
% Sort the grand mean maps by the specified published template(s)
disp('Sorting grand mean maps by published templates...');
for i=1:numel(TemplateNames)
    [ALLEEG, EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, GrandMeanIdx, 'TemplateSet', TemplateNames{i}, 'Classes', SortClasses{i}, 'IgnorePolarity', ClustPar.IgnorePolarity);
    [ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
end
% Relabel maps with alphabetic labels
letters = 'A':'Z';
labels = arrayfun(@(x) {letters(x)}, 1:26);
for i=ClustPar.MinClasses:ClustPar.MaxClasses
    [ALLEEG, EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, GrandMeanIdx, 'TemplateSet', 'manual', 'Classes', i, 'SortOrder', 1:i, 'NewLabels', labels(1:i));
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
end

% Sort the individual and group level maps by the grand mean maps
disp('Sorting subject and group level maps by grand mean maps...');
[ALLEEG, EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, 1:numel(ALLEEG)-1, 'TemplateSet', GrandMeanIdx, 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'IgnorePolarity', ClustPar.IgnorePolarity);
[ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% 8. Save set files with microstates data and figures with microstate plots
warning('off', 'MATLAB:print:UIControlsScaled');
for i=1:nGroups
    currGroupIdx = GroupIdx{i};
    
    fprintf('Plotting and saving maps for group %s...\n', groupNames{i});
    for j=1:numel(currGroupIdx)
        % Save figures with individual microstate maps
        fig = pop_ShowIndMSMaps(ALLEEG, currGroupIdx(j), 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'Visible', false);
        saveas(fig, fullfile(subjFigDir, [ALLEEG(currGroupIdx(j)).filename(1:end-4) '.png']));
        close(fig);

        % Save individual set files with microstates data    
        pop_saveset(ALLEEG(currGroupIdx(j)), 'filename', ALLEEG(currGroupIdx(j)).filename, 'filepath', subjDir);    
    end

    % Save figures with group level microstate maps
    fig = pop_ShowIndMSMaps(ALLEEG, GroupMeanIdx(i), 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'Visible', false);
    saveas(fig, fullfile(meanFigDir, [ALLEEG(GroupMeanIdx(i)).setname '.png']));
    close(fig);

    % Save group level set files with microstates data
    pop_saveset(ALLEEG(GroupMeanIdx(i)), 'filename', ALLEEG(GroupMeanIdx(i)).setname, 'filepath', meanDir);
end

% Save figures with grand mean microstate maps
disp('Plotting and saving grand mean maps...');
fig = pop_ShowIndMSMaps(ALLEEG, GrandMeanIdx, 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'Visible', false);
saveas(fig, fullfile(meanFigDir, [ALLEEG(GrandMeanIdx).setname '.png']));
close(fig);
% Save grand mean set files with microstates data
pop_saveset(ALLEEG(GrandMeanIdx), 'filename', ALLEEG(GrandMeanIdx).setname, 'filepath', meanDir);

%% 9. Backfit and quantify temporal dynamics
disp('Backfitting and extracting temporal dynamics...');

% Backfit using individual microstate template maps
[EEG, CURRENTSET] = pop_FitMSTemplates(ALLEEG, AllSubjects, 'TemplateSet', 'own', 'FitPar', FitPar);
[ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
IndStats = cell(1, length(FitPar.Classes));
for c=1:length(FitPar.Classes)
    filename = sprintf('TemporalParameters_%i classes_IndividualTemplates', FitPar.Classes(c));
    % save results to csv
    IndStats{c} = pop_SaveMSParameters(ALLEEG, AllSubjects, 'Classes', FitPar.Classes(c), 'Filename', fullfile(quantDir, [filename '.csv']));
    % save plotted temporal parameters
    fig = pop_ShowMSParameters(ALLEEG, AllSubjects, 'Classes', FitPar.Classes(c), 'Visible', false);                    
    saveas(fig, fullfile(quantFigDir, [filename '.png']));
    close(fig);
end

% Backfit using grand mean microstate template maps
[EEG, CURRENTSET] = pop_FitMSTemplates(ALLEEG, AllSubjects, 'TemplateSet', GrandMeanIdx, 'FitPar', FitPar);
[ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
GrandMeanStats = cell(1, length(FitPar.Classes));
for c=1:length(FitPar.Classes)
    filename = sprintf('TemporalParameters_%i classes_GrandMeanTemplate', FitPar.Classes(c));
    % save results to csv
    GrandMeanStats{c} = pop_SaveMSParameters(ALLEEG, AllSubjects, 'Classes', FitPar.Classes(c), 'Filename', fullfile(quantDir, [filename '.csv']));
    % save plotted temporal parameters
    fig = pop_ShowMSParameters(ALLEEG, AllSubjects, 'Classes', FitPar.Classes(c), 'Visible', false);                    
    saveas(fig, fullfile(quantFigDir, [filename '.png']));
    close(fig);
end

% Backfit using published microstate template maps
tmpFitPar = FitPar;
TemplateStats = cell(1, numel(TemplateNames));
for i=1:numel(TemplateNames)
    tmpFitPar.Classes = SortClasses{i};
    [EEG, CURRENTSET] = pop_FitMSTemplates(ALLEEG, AllSubjects, 'TemplateSet', TemplateNames{i}, 'FitPar', tmpFitPar);
    [ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
    tempStats = cell(1, length(tmpFitPar.Classes));
    for c=1:length(tmpFitPar.Classes)
        filename = sprintf('TemporalParameters_%i classes_%s', tmpFitPar.Classes(c), TemplateNames{i});
        % save results to csv
        tempStats{c} = pop_SaveMSParameters(ALLEEG, AllSubjects, 'Classes', tmpFitPar.Classes(c), 'Filename', fullfile(quantDir, [filename '.csv']));
        % save plotted temporal parameters
        fig = pop_ShowMSParameters(ALLEEG, AllSubjects, 'Classes', tmpFitPar.Classes(c), 'Visible', false);                    
        saveas(fig, fullfile(quantFigDir, [filename '.png']));
        close(fig);
    end
    TemplateStats{i} = tempStats;
end

%% 10. Export microstate maps to Ragu
for c=FitPar.Classes
    pop_RaguMSTemplates(ALLEEG, AllSubjects, 'Classes', c);
end