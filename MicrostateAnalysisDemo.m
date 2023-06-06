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
%   group and condition. The top level folders should be organized by
%   group, with the group names used for the folder names. Within each
%   group folder, there should then be a folder for each condition, again
%   with the condition names used for the folder names. For example, a
%   "root" folder containing two group folders, "Group_A" and
%   "Group_B", each of which contain two condition folders, "Condition_A"
%   and "Condition_B":
%                  _______________root_______________
%                  |                                 |  
%          _____Group_A_____                ______Group_B_____
%         |                 |               |                 | 
%    Condition_A       Condition_B     Condition_A       Condition_B 
%
%   Filenames should begin with subject IDs. If additional information is
%   included in the filename, separate it with an underscore (e.g.
%   's1_EC.set'). The section will also prompt you for a directory to save 
%   the analysis results.
%
%   Section 3 will load the datasets from the input folder you provide and
%   update the "group" and "condition" field of each dataset loaded. Please 
%   note that this script assumes your files are in .set format and may 
%   need to be modified if your datasets are in a different format.
%
%   Section 4 will perform clustering to identify individual microstate maps 
%   for all loaded datasets.
%
%   Section 5 will identify group level microstate maps for each combination 
%   of group and condition.
%
%   Section 6 will identify grand mean microstate maps for each group across 
%   conditions.
%
%   Section 7 will identify grand grand mean microstate maps across all 
%   groups and conditions.
%
%   Section 8 will sort the identified microstate maps. First, the grand
%   grand mean maps will be sorted according to the published template maps
%   specified in the parameters section. By default, the Koenig 2002 maps
%   will be used to sort 4-6 cluster solutions, and the Custo 2017 maps
%   will be used to sort the 7 cluster solution. These can be modified
%   depending on the cluster solutions you would like to identify. If you
%   would like to use your own published template maps for sorting, add the
%   set file containing the maps to the "microstates/Templates" folder. 
%   The maps should be contained in the "msinfo" field of the EEG struct,
%   and should contain unique labels and colors for each map. After the
%   grand grand mean maps are sorted, the grand mean maps for each group,
%   group level maps for each group and condition, and individual maps for
%   each subject will be sorted by the grand grand mean.
%
%   Section 9 will save the individual, group level, grand mean, and grand 
%   grand mean set files containing the microstate maps data, along with 
%   figures containing the plotted microstate maps.
%
%   Section 10 will perform backfitting and quantification of temporal
%   dynamics according to different template maps. It will save 3 different
%   files for each solution used for backfitting, one containing temporal 
%   parameters from using individual maps for backfitting, one from using 
%   the grand grand mean templates for backfitting, and one from using a 
%   published template for backfitting. It will also save figures
%   containing the plotted distribution of temporal parameters across all
%   datasets, as well as return the extracted temporal parameters in the
%   "MSStats" structure array for further analysis. The published template 
%   to use for backfitting can be modified in the parameters section.
%
%   Section 11 will use Ragu to perform TANOVA to compare microstate map
%   topographies between groups and conditions (optional, comment out if
%   not using)

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
inputDir = uigetdir([], 'Directory containing group folders');
if inputDir == 0;    return; end
groupFolders = dir(inputDir);
groupFolders = groupFolders(~matches({groupFolders.name}, {'.', '..'}));
nGroups = length(groupFolders);
groupNames = cell(1, nGroups);
condNames = cell(1, nGroups);
dataDirs = cell(1, nGroups);
for i=1:nGroups
    groupDir = fullfile(inputDir, groupFolders(i).name);
    groupNames{i} = groupFolders(i).name;
    condFolders = dir(groupDir);
    condFolders = condFolders(~matches({condFolders.name}, {'.', '..'}));    
    condNames{i} = {condFolders.name};
    dataDirs{i} = cellfun(@(x) fullfile(groupDir, x), condNames{i}, 'UniformOutput', false);
end

% Set save output path
saveDir = uigetdir([], 'Directory to save results');
if saveDir == 0;    return; end

% Make sub-directory with current date and time
subDir = fullfile(saveDir, [char(datetime('now', 'Format', 'yyyy-MM-dd_HH-mma')) '_Microstate Analysis']);
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

% Start EEGLAB and find Microstates plugin files
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

%% 3. Load datasets and update subject, group, and condition info
for i=1:nGroups

    for j=1:numel(dataDirs{i})
        setFiles = dir(fullfile(dataDirs{i}{j}, '*.set'));
        setFilenames = {setFiles.name};

        % Load datasets
        fprintf('Loading datasets in group %s, condition %s...\n', groupNames{i}, condNames{i}{j});
        EEG = pop_loadset('filename', setFilenames, 'filepath', dataDirs{i}{j});
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);
        currGroupIdx = lastGroupIdx:numel(ALLEEG);

        % Update group and condition info for all sets
        fprintf('Updating group and condition information for group %s, condition %s...\n', groupNames{i}, condNames{i}{j});
        for k=1:numel(currGroupIdx)
            [EEG, ALLEEG, CURRENTSET] = eeg_retrieve(ALLEEG, currGroupIdx(k));
            filename = EEG.filename(1:strfind(EEG.filename, '.')-1);
            idx = strfind(filename, '_');
            if isempty(idx)
                EEG.subject = filename;
            else
                EEG.subject = filename(1:idx-1);
            end
            EEG.group = groupNames{i};
            EEG.condition = condNames{i}{j};
            [ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
        end

        GroupIdx{i} = [GroupIdx{i} {currGroupIdx}];
        lastGroupIdx = numel(ALLEEG) + 1;
    end                   
end

AllSubjects = 1:numel(ALLEEG);

%% 4. Identify individual microstate maps for each subject
disp('Identifying microstates for all sets...');
[EEG, CURRENTSET] = pop_FindMSMaps(ALLEEG, AllSubjects, 'ClustPar', ClustPar);
[ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% 5. Identify group level microstate maps for each group/condition
GroupMeanIdx = cell(1, nGroups);
for i=1:nGroups
    for j=1:numel(condNames{i})
        fprintf('Identifying group level mean maps for group %s, condition %s...\n', groupNames{i}, condNames{i}{j});
        EEG = pop_CombMSMaps(ALLEEG, GroupIdx{i}{j}, 'MeanName', ['GroupMean_' groupNames{i} '_' condNames{i}{j}], ...
            'IgnorePolarity', ClustPar.IgnorePolarity);
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off');
        GroupMeanIdx{i} = [GroupMeanIdx{i} CURRENTSET];
    end    
end

%% 6. Identify grand mean microstate maps for each group
GrandMeanIdx = zeros(1, nGroups);
for i=1:nGroups
    if numel(condNames{i}) > 1
        fprintf('Identifying grand mean maps for group %s across conditions...\n', groupNames{i});
        EEG = pop_CombMSMaps(ALLEEG, GroupMeanIdx{i}, 'MeanName', ['GrandMean_' groupNames{i}], ...
            'IgnorePolarity', ClustPar.IgnorePolarity);
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off');
        GrandMeanIdx(i) = CURRENTSET;
    else
        GrandMeanIdx(i) = GroupMeanIdx{i};
    end
end

%% 7. Identify grand grand mean microstate maps across all groups and conditions
if nGroups > 1
    disp('Identifying grand grand mean maps across all groups and conditions...');
    EEG = pop_CombMSMaps(ALLEEG, GrandMeanIdx, 'MeanName','GrandGrandMean', 'IgnorePolarity', ClustPar.IgnorePolarity);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off');
    GrandGrandMeanIdx = CURRENTSET;
else
    GrandGrandMeanIdx = GrandMeanIdx;
end

%% 8. Sorting
% Sort the grand grand mean maps by the specified published template(s)
disp('Sorting grand grand mean maps by published templates...');
for i=1:numel(TemplateNames)
    [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, GrandGrandMeanIdx, 'TemplateSet', TemplateNames{i}, 'Classes', SortClasses{i}, 'IgnorePolarity', ClustPar.IgnorePolarity);
    [ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
end

% Sort the individual, group level, and grand mean maps by the grand grand mean maps
disp('Sorting subject, group level, and grand mean maps by grand grand mean maps...');
[ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1:numel(ALLEEG)-1, 'TemplateSet', GrandGrandMeanIdx, 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'IgnorePolarity', ClustPar.IgnorePolarity);
[ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% 8. Save set files with microstates data and figures with microstate plots
warning('off', 'MATLAB:print:UIControlsScaled');
for i=1:nGroups
    for j=1:numel(condNames{i})
        currGroupIdx = GroupIdx{i}{j};
        fprintf('Plotting and saving maps for group %s, condition %s...\n', groupNames{i}, condNames{i}{j});
        for k=1:numel(currGroupIdx)
            % Save figures with individual microstate maps
            fig = pop_ShowIndMSMaps(ALLEEG, currGroupIdx(k), 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'Visible', false);
            saveas(fig, fullfile(subjFigDir, [ALLEEG(currGroupIdx(k)).filename(1:end-4) '.png']));
            close(fig);
    
            % Save individual set files with microstates data    
            pop_saveset(ALLEEG(currGroupIdx(k)), 'filename', ALLEEG(currGroupIdx(k)).filename, 'filepath', subjDir);
        end

        % Save figures with group level microstate maps
        fig = pop_ShowIndMSMaps(ALLEEG, GroupMeanIdx{i}(j), 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'Visible', false);
        saveas(fig, fullfile(meanFigDir, [ALLEEG(GroupMeanIdx{i}(j)).setname '.png']));
        close(fig);
    
        % Save group level set files with microstates data
        pop_saveset(ALLEEG(GroupMeanIdx{i}(j)), 'filename', [ALLEEG(GroupMeanIdx{i}(j)).setname '.set'], 'filepath', meanDir);
    end    

    % Save figures with grand mean microstate maps        
    fprintf('Plotting and saving grand mean maps for group %s...\n', groupNames{i});   
    fig = pop_ShowIndMSMaps(ALLEEG, GrandMeanIdx(i), 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'Visible', false);
    saveas(fig, fullfile(meanFigDir, [ALLEEG(GrandMeanIdx(i)).setname '.png']));
    close(fig);

    % Save grand mean set files with microstates data
    pop_saveset(ALLEEG(GrandMeanIdx(i)), 'filename', [ALLEEG(GrandMeanIdx(i)).setname '.set'], 'filepath', meanDir);
end

% Save figures with grand grand mean microstate maps
disp('Plotting and saving grand grand mean maps...');
fig = pop_ShowIndMSMaps(ALLEEG, GrandGrandMeanIdx, 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses, 'Visible', false);
saveas(fig, fullfile(meanFigDir, [ALLEEG(GrandGrandMeanIdx).setname '.png']));
close(fig);
% Save grand mean set files with microstates data
pop_saveset(ALLEEG(GrandGrandMeanIdx), 'filename', [ALLEEG(GrandGrandMeanIdx).setname '.set'], 'filepath', meanDir);

%% 9. Backfit and quantify temporal dynamics
disp('Backfitting and extracting temporal dynamics...');

% Backfit using individual microstate maps
[EEG, CURRENTSET] = pop_FitMSMaps(ALLEEG, AllSubjects, 'TemplateSet', 'own', 'FitPar', FitPar);
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

% Backfit using grand grand mean microstate maps
[EEG, CURRENTSET] = pop_FitMSMaps(ALLEEG, AllSubjects, 'TemplateSet', GrandGrandMeanIdx, 'FitPar', FitPar);
[ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
GrandGrandMeanStats = cell(1, length(FitPar.Classes));
for c=1:length(FitPar.Classes)
    filename = sprintf('TemporalParameters_%i classes_GrandGrandMeanTemplate', FitPar.Classes(c));
    % save results to csv
    GrandGrandMeanStats{c} = pop_SaveMSParameters(ALLEEG, AllSubjects, 'Classes', FitPar.Classes(c), 'Filename', fullfile(quantDir, [filename '.csv']));
    % save plotted temporal parameters
    fig = pop_ShowMSParameters(ALLEEG, AllSubjects, 'Classes', FitPar.Classes(c), 'Visible', false);                    
    saveas(fig, fullfile(quantFigDir, [filename '.png']));
    close(fig);
end

% Backfit using published microstate maps
tmpFitPar = FitPar;
TemplateStats = cell(1, numel(TemplateNames));
for i=1:numel(TemplateNames)
    tmpFitPar.Classes = SortClasses{i};
    [EEG, CURRENTSET] = pop_FitMSMaps(ALLEEG, AllSubjects, 'TemplateSet', TemplateNames{i}, 'FitPar', tmpFitPar);
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
    pop_RaguMSMaps(ALLEEG, AllSubjects, 'Classes', c);
end