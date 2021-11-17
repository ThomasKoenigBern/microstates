
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
FitPars = struct('nClasses',5,'lambda',1,'b',20,'PeakFit',true, 'BControl',true,'Rectify',false,'Normalize',false,'SegmentSize',1,'SingleEpochFileTemplate','e:\\%s.mat');

% Define the parameters for clustering
ClustPars = struct('MinClasses',4,'MaxClasses',7,'GFPPeaks',true,'IgnorePolarity',true,'MaxMaps',1000,'Restarts',20, 'UseAAHC',false,'Normalize',false);

% This is the path were all the output will go
SavePath   = 'D:\Dropbox (PUK-TRC)\Reality monitoring_IRC\Sleeponset_experience_data\SO_EEGData_Sarah\Clean_Chengdu\MSResults';


% Here, we collect the EEG data (one folder per group)
nGroups = 1;
 
% where the data is stored:
%GroupDirArray{1} = 'D:\Dropbox (PUK-TRC)\Reality monitoring_IRC\Sleeponset_experience_data\SO_EEGData_Sarah\Clean_Chengdu';
GroupDirArray{1} = 'E:\Dropbox (PUK)\Reality monitoring_IRC\Sleeponset_experience_data\SO_EEGData_Sarah\Clean_Chengdu';


%% Read the data

eeglabpath = fileparts(which('eeglab.m'));
DipFitPath = fullfile(eeglabpath,'plugins','dipfit2.3');

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
            tmpEEG = pop_fileio(fullfile(GroupDir,FileNamesGroup{f}));   % Basic file read
%            tmpEEG = eeg_RejectBABadIntervals(tmpEEG);   % Get rid of bad intervals
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
   
%% 
%EEG = pop_loadset('filename','GrandMean.set','filepath','D:\Dropbox (PUK-TRC)\Reality monitoring_IRC\Sleeponset_experience_data\SO_EEGData_Sarah\Clean_Chengdu\MSResults');
EEG = pop_loadset('filename','GrandMean.set','filepath','E:\Dropbox (PUK)\Reality monitoring_IRC\Sleeponset_experience_data\SO_EEGData_Sarah\Clean_Chengdu\MSResults');
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'gui','off'); % And make this a new set

% And we have a look at it
GrandGrandMeanIndex = CURRENTSET;
pop_ShowIndMSMaps(ALLEEG(GrandGrandMeanIndex), 5); 
drawnow;


%% Here comes the stats part

% And using the grand grand mean template
% pop_QuantMSTemplates(ALLEEG, AllSubjects, 1, FitPars, GrandGrandMeanIndex, fullfile(SavePath,'ResultsFromGrandGrandMeanTemplate.xlsx'));
pop_QuantMSTemplates(ALLEEG, AllSubjects, 1, FitPars, GrandGrandMeanIndex, 'Test.mat');


% % And finally, based on the normative maps from 2002
% pop_QuantMSTemplates(ALLEEG, AllSubjects, 1, FitPars, NormativeTemplateIndex, fullfile(SavePath,'ResultsFromNormativeTemplate2002.xlsx'));

%% Eventually export the individual microstate maps to do statistics in Ragu
pop_RaguMSTemplates(ALLEEG, AllSubjects);