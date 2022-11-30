
%% Demo script for microstate analyses in EEGLAB
%
% %Author: Thomas Koenig, University of Bern, Switzerland, 2018
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

%% Define the basic parameters
% This is for vision analyzer data and may need adjustments
clear all
close all
clc

LowCutFilter  =  2;
HighCutFilter = 20;
FilterCoefs   = 2000;

% For already saved and filtered EEG-lab data
% ReadVision = false;
% FilterTheData = false;

% for "fresh" vision analyzer data:
ReadVision = true;
FilterTheData = true;

% These are the paramters for the fitting based on GFP peaks only
FitPars = struct('nClasses',7,'lambda',1,'b',20,'PeakFit',true, 'BControl',true,'Rectify',false,'Normalize',false);

% Define the parameters for clustering
ClustPars = struct('MinClasses',4,'MaxClasses',7,'GFPPeaks',true,'IgnorePolarity',true,'MaxMaps',500,'Restarts',20', 'UseAAHC',false,'Normalize',false);

% This is the path were all the output will go
SavePath   = uigetdir([],'Path to store the results');

if SavePath == 0
    return
end

% Here, we collect the EEG data (one folder per group)
nGroups = str2double(inputdlg('Number of groups','Microstate analysis',1));
 
for Group = 1:nGroups
    GroupDirArray{Group} = uigetdir([],sprintf('Path to the data of group %i (Vision Analyzer data)',Group)); %#ok<SAGROW>
    
    if GroupDirArray{Group} == 0
        return
    end
end


%% Read the data

eeglabpath = fileparts(which('eeglab.m'));
DipFitPath = fullfile(eeglabpath,'plugins','dipfit');

eeglab

AllSubjects = [];

for Group = 1:nGroups
    GroupDir = GroupDirArray{Group};
    
    GroupIndex{Group} = []; %#ok<SAGROW>
    
    if ReadVision == true
        DirGroup = dir(fullfile(GroupDir,'*.vhdr'));
    else
        DirGroup = dir(fullfile(GroupDir,'*.set'));
    end

    FileNamesGroup = {DirGroup.name};

    % Read the data from the group 
    for f = 1:numel(FileNamesGroup)
        if ReadVision == true
            tmpEEG = pop_loadbv(GroupDir,FileNamesGroup{f});   % Basic file read
            tmpEEG = eeg_RejectBABadIntervals(tmpEEG);   % Get rid of bad intervals
            setname = strrep(FileNamesGroup{f},'.vhdr',''); % Set a useful name of the dataset
            [ALLEEG, tmpEEG, CURRENTSET] = pop_newset(ALLEEG, tmpEEG, 0,'setname',FileNamesGroup{f},'gui','off'); % And make this a new set
            tmpEEG=pop_chanedit(tmpEEG, 'lookup',fullfile(DipFitPath,'standard_BESA','standard-10-5-cap385.elp')); % Add the channel positions
        else
            tmpEEG = pop_loadset('filename',FileNamesGroup{f},'filepath',GroupDir);
            [ALLEEG, tmpEEG, CURRENTSET] = pop_newset(ALLEEG, tmpEEG, 0,'gui','off'); % And make this a new set
        end

        tmpEEG = pop_reref(tmpEEG, []); % Make things average reference
        if FilterTheData == true
            tmpEEG = pop_eegfiltnew(tmpEEG, LowCutFilter,HighCutFilter, FilterCoefs, 0, [], 0); % And bandpass-filter 2-20Hz
        end
        tmpEEG.group = sprintf('Group_%i',Group); % Set the group (will appear in the statistics output)
        [ALLEEG,EEG,CURRENTSET] = eeg_store(ALLEEG, tmpEEG, CURRENTSET); % Store the thing
        GroupIndex{Group} = [GroupIndex{Group} CURRENTSET]; % And keep track of the group
        AllSubjects = [AllSubjects CURRENTSET]; %#ok<AGROW>
    end
    
end

eeglab redraw
   
%% Cluster the stuff

[EEG,ClusteredSets] = pop_FindMSTemplates(ALLEEG,AllSubjects, ClustPars); % This is the actual clustering within subjects
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, ClusteredSets); % Done, we just need to store this

eeglab redraw

%% Now we combine the microstate maps across subjects and sort the mean

% First, we load a set of normative maps to orient us later
templatepath = fullfile(fileparts(which('eegplugin_Microstates.m')),'Templates');

EEG = pop_loadset('filename','Normative microstate template maps Neuroimage 2002.set','filepath',templatepath);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off'); % And make this a new set

% And we have a look at it
NormativeTemplateIndex = CURRENTSET;
pop_ShowIndMSMaps(ALLEEG(NormativeTemplateIndex), 4); 
drawnow;


% Now we go into averaging within each group
for Group = 1:nGroups
    % The mean of group X
    [~,EEG] = pop_CombMSTemplates(ALLEEG, GroupIndex{Group}, 0, 0, sprintf('GrandMean Group %i',Group));
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, numel(ALLEEG)+1,'gui','off'); % Make a new set
    GrandMeanIndex(Group) = CURRENTSET; % And keep track of it
end

% Now we want the grand-grand mean, based on the group means, if there is
% more than one group
if nGroups > 1
    [~,EEG] = pop_CombMSTemplates(ALLEEG, GrandMeanIndex, 1, 0, 'GrandGrandMean');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, numel(ALLEEG)+1,'gui','off'); % Make a new set
    GrandGrandMeanIndex = CURRENTSET; % and keep track of it
else
    GrandGrandMeanIndex = GrandMeanIndex(1);
end

% We automatically sort the grandgrandmean based on a template from the literature
[EEG,CURRENTSET] = pop_SortMSTemplates(ALLEEG, GrandGrandMeanIndex, 1, NormativeTemplateIndex);
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

% This should now be as good as possible, but we should look at it
pop_ShowIndMSMaps(EEG, 4, GrandGrandMeanIndex, ALLEEG); % Here, we go interactive to allow the user to put the classes in the canonical order

eeglab redraw


%% And we sort things out over means and subjects
% Now, that we have mean maps, we use them to sort the individual templates
% First, the sequence of the two group means has be adjusted based on the
% grand grand mean
if nGroups > 1
    [EEG,CURRENTSET] = pop_SortMSTemplates(ALLEEG, GrandMeanIndex, 1, GrandGrandMeanIndex);
    [ALLEEG,EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET); % and store it
end

% Then, we sort the individuals based on their group means
for Group = 1:nGroups
    [EEG,CURRENTSET] = pop_SortMSTemplates(ALLEEG, GroupIndex{Group}, 0, GrandMeanIndex(Group)); % Group 1
    [ALLEEG,EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET); % and store it
end

eeglab redraw

%% We eventually save things

for f = 1:numel(ALLEEG)
    EEG = eeg_retrieve(ALLEEG,f);
    fname = EEG.setname;
    pop_saveset( EEG, 'filename',fname,'filepath',SavePath);
end

%% Visualize some stuff to see if the fitting parameters appear reasonable

% Just a look at the first EEG
EEG = eeg_retrieve(ALLEEG,1); 
pop_ShowIndMSDyn([],EEG,0,FitPars);
pop_ShowIndMSMaps(EEG,FitPars.nClasses);

%% Here comes the stats part

% Using the individual templates
pop_QuantMSTemplates(ALLEEG, AllSubjects, 0, FitPars, []                   ,[], fullfile(SavePath,'ResultsFromIndividualTemplates.xlsx'));

% And using the grand grand mean template
pop_QuantMSTemplates(ALLEEG, AllSubjects, 1, FitPars, GrandGrandMeanIndex, fullfile(SavePath,'ResultsFromGrandGrandMeanTemplate.xlsx'));

% And finally, based on the normative maps from 2002
pop_QuantMSTemplates(ALLEEG, AllSubjects, 1, FitPars, NormativeTemplateIndex, fullfile(SavePath,'ResultsFromNormativeTemplate2002.xlsx'));

%% Eventually export the individual microstate maps to do statistics in Ragu
pop_RaguMSTemplates(ALLEEG, AllSubjects);