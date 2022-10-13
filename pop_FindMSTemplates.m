%pop_FindMSTemplates() interactively identify microstate topographies
%
% Usage:
%   >> [EEGout, CurrentSet, com] = pop_FindMSTemplates(AllEEG, SelectedSets, ClustPar,ShowMaps,ShowDyn, SortMaps)
%
% EEG lab specific:
%
%   "EEGout"
%   -> The refreshed set of current EEGs
%
%   "CurrentSet"
%   -> The indices of the refreshed set of current EEGs
%
% Graphical interface / parameters:
%
%   "Clustering parameters"
%    ---------------------
%   "Min number of classes" / ClustPar.MinClasses
%   -> Minimal number of clusters to search for
%
%   "Max number of classes" / ClustPar.MaxClasses
%   -> Maximum number of clusters to search for
%
%   "Number of restarts" / ClustPar.Restarts
%   -> Number of times the k-means is restarted with a new random configuration
%
%   "Max number of maps to use" / ClustPar.MaxMaps
%   -> Use a random subsample of the data to identify the clusters
%
%   "GFP peaks only" / ClustPar.GFPPeaks
%   -> Limit the selection of maps used for cluster to moments of GFP peaks
%
%   "No polarity" / ClustPar.IgnorePolarity
%   -> Assign maps with inverted polarity to the same class (standard for resting EEG)
%
%   "Use AAHC Algorithm" / ClustPar.UseAAHC
%   -> Use the AAHC algorithm instead of the k-means
%
%   "Normalize EEG before clustering" / ClustPar.UseAAHC
%   -> Make all data GFP = 1 before clustering
%
%   "Display options"
%    ---------------
%
%   "Show maps when done" / ShowMaps
%   -> Show maps when done
%
%   "Show dynamics when done" / ShowDyn
%   -> Show dynamics when done
%
%   Added by Delara 8/16/22
%   "Sort maps when done" / SortMaps
%   -> Sort maps according to published templates when done
%
% Output:
%
%   "EEGout" 
%   -> EEG structure with the EEG containing the identified cluster centers
% 
%   "CurrentSet"
%   -> The indices of the EEGs containing the identified cluster centers
%
%   "com"
%   -> Command necessary to replicate the computation
%
% Author: Thomas Koenig, University of Bern, Switzerland, 2016
%
% Copyright (C) 2016 Thomas Koenig, University of Bern, Switzerland, 2016
% thomas.koenig@puk.unibe.ch
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

function [EEGout, CurrentSet, com] = pop_FindMSTemplates(AllEEG, SelectedSets, ClustPar, ShowMaps, ShowDyn, SortMaps)

    global EEG;
    global CURRENTSET;
    global MSTEMPLATE;
    com = '';
    EEGout = EEG;
    CurrentSet = CURRENTSET;
    
    if nargin < 4
        ClustPar = [];
    end
    if nargin < 5;  ShowMaps       = false; end
    if nargin < 6;  ShowDyn        = false; end
    if nargin < 7;  SortMaps       = false; end

    if isempty(SelectedSets)
        % if multiple datasets have not already been selected, prompt the
        % user to select them
        HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG),'UniformOutput',true);
        AvailableSets = {AllEEG(~HasChildren).setname};

        res = inputgui('title','Identify microstate maps',...
            'geometry', {1 1 1}, 'geomvert', [1 1 4], 'uilist', { ...
                { 'Style', 'text', 'string', 'Choose sets for clustering'} ...
                { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
                { 'Style', 'listbox', 'string', AvailableSets, 'tag','SelectSets' ,'Min', 0, 'Max',2} ...
                });

        if isempty(res); return; end
        
        AllSets = 1:numel(AllEEG);
        ValidSets = AllSets(~HasChildren);
        SelectedSets = ValidSets(res{1});
    end
    
    FieldNames = {'MinClasses','MaxClasses','GFPPeaks','IgnorePolarity','MaxMaps','Restarts', 'UseAAHC','Normalize'};

    iscomplete = all(isfield(ClustPar,FieldNames));

    % Update clustering parameters
    if ~iscomplete 
        % Throw in the defaults where necessary and confirm
        ClustPar = UpdateFitParameters(ClustPar, struct('MinClasses',3,'MaxClasses',6,'GFPPeaks',true,'IgnorePolarity',true,'MaxMaps',1000,'Restarts',5', 'UseAAHC',false,'Normalize',true),FieldNames);
        
        if islogical(ClustPar.UseAAHC)
            ClustPar.UseAAHC = floor(ClustPar.UseAAHC) + 1;
        end
        
        [res,~,~,structout] = inputgui( 'geometry', {1 [1 1] [1 1] [1 1] [1 1] [1 1] 1 1 1 1 1 1 1},  'uilist', { ...
             { 'Style', 'text', 'string', 'Clustering parameters', 'fontweight', 'bold'  } ...  
             { 'Style', 'text', 'string', 'Algorithm', 'fontweight', 'normal'  } ...
             { 'Style', 'popupmenu', 'string',{'k-means','AAHC'},'tag','UseAAHC', 'Value', ClustPar.UseAAHC}  ... 
             { 'Style', 'text', 'string', 'Min number of classes', 'fontweight', 'normal'  } ...
             { 'Style', 'edit', 'string', sprintf('%i',ClustPar.MinClasses), 'tag','Min_Classes' } ... 
             { 'Style', 'text', 'string', 'Max number of classes', 'fontweight', 'normal'  } ...
             { 'Style', 'edit', 'string', sprintf('%i',ClustPar.MaxClasses),'tag','Max_Classes' } ... 
             { 'Style', 'text', 'string', 'Number of restarts', 'fontweight', 'normal'  } ...
             { 'Style', 'edit', 'string', sprintf('%i',ClustPar.Restarts),'tag' 'Restarts' } ... 
             { 'Style', 'text', 'string', 'Max number of maps to use', 'fontweight', 'normal'  } ...
             { 'Style', 'edit', 'string', sprintf('%i',ClustPar.MaxMaps), 'tag', 'Max_Maps'} ...
             { 'Style', 'checkbox', 'string', 'GFP peaks only' 'tag', 'GFP_Peaks'    ,'Value', ClustPar.GFPPeaks }  ...
             { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', ClustPar.IgnorePolarity }  ...
             { 'Style', 'checkbox', 'string', 'Normalize EEG before clustering','tag','Normalize' ,'Value', ClustPar.Normalize }  ...
             { 'Style', 'text', 'string', 'Display options', 'fontweight', 'bold'  } ...
             { 'Style', 'checkbox', 'string', 'Sort maps according to published template when done', 'tag', 'Sort_Maps', 'Value', SortMaps } ...
             { 'Style', 'checkbox', 'string','Show maps when done','tag','Show_Maps'    ,'Value', ShowMaps }  ...
             { 'Style', 'checkbox', 'string','Show dynamics when done','tag','Show_Dyn' ,'Value', ShowDyn } } ...
             ,'title','Microstate clustering parameters');
        
        if isempty(res);    return; end

        ClustPar.UseAAHC        = structout.UseAAHC == 2;
        ClustPar.MaxMaps        = str2double(structout.Max_Maps);
        ClustPar.GFPPeaks       = structout.GFP_Peaks;
        ClustPar.IgnorePolarity = structout.Ignore_Polarity;
        ClustPar.MinClasses     = str2double(structout.Min_Classes);
        ClustPar.MaxClasses     = str2double(structout.Max_Classes);
        ClustPar.Restarts       = str2double(structout.Restarts);
        ClustPar.Normalize      = structout.Normalize;
        ShowMaps                = structout.Show_Maps;
        ShowDyn                 = structout.Show_Dyn;
        SortMaps                = structout.Sort_Maps;
    end

    if ClustPar.UseAAHC == true && ClustPar.Normalize == true
        warndlg2('There is an issue with the currently implemented AAHC algorithm and normalization, normalization has been set to false.','Clustering algorithm selection');
        ClustPar.Normalize = false;
    end
    
    if ~isfield(ClustPar,'UseEMD')
        ClustPar.UseEMD = false;
    end
    
    for i=1:length(SelectedSets)
        fprintf("Clustering dataset %i of %i\n", i, length(SelectedSets));

        sIndex = SelectedSets(i);

        % Distribute the random sampling across segments
        nSegments = AllEEG(sIndex).trials;
        if ~isinf(ClustPar.MaxMaps)
            MapsPerSegment = hist(ceil(double(nSegments) * rand(ClustPar.MaxMaps,1)),nSegments);
        else
            MapsPerSegment = inf(nSegments,1);
        end
    
        MapsToUse = [];
        for s = 1:nSegments
            if ClustPar.GFPPeaks == 1
                gfp = std(AllEEG(sIndex).data(:,:,s),1,1);
                IsGFPPeak = find([false (gfp(1,1:end-2) < gfp(1,2:end-1) & gfp(1,2:end-1) > gfp(1,3:end)) false]);
                if numel(IsGFPPeak) > MapsPerSegment(s) && MapsPerSegment(s) > 0
                    idx = randperm(numel(IsGFPPeak));
                    IsGFPPeak = IsGFPPeak(idx(1:MapsPerSegment(s)));
                end
                MapsToUse = [MapsToUse AllEEG(sIndex).data(:,IsGFPPeak,s)];
            else
                if (size(AllEEG(sIndex).data,2) > ClustPar.MaxMaps) && MapsPerSegment(s) > 0
                    idx = randperm(size(AllEEG(sIndex).data,2));
                    MapsToUse = [MapsToUse AllEEG(sIndex).data(:,idx(1:MapsPerSegment(s)),s)];
                else
                    MapsToUse = [MapsToUse AllEEG(sIndex).data(:,:,s)];
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
            for nClusters = ClustPar.MinClasses:ClustPar.MaxClasses
                [b_model,~,~,exp_var] = eeg_kMeans(MapsToUse',nClusters,ClustPar.Restarts,[],flags,AllEEG(sIndex).chanlocs);
       
                msinfo.MSMaps(nClusters).Maps = b_model;
                msinfo.MSMaps(nClusters).ExpVar = double(exp_var);
                msinfo.MSMaps(nClusters).ColorMap = lines(nClusters);
                msinfo.MSMaps(nClusters).SortMode = 'none';
                msinfo.MSMaps(nClusters).SortedBy = '';
                msinfo.MSMaps(nClusters).SpatialCorrelation= [];
            end
        else
            [b_model,exp_var] = eeg_computeAAHC(double(MapsToUse'),ClustPar.MinClasses:ClustPar.MaxClasses,false, ClustPar.IgnorePolarity,ClustPar.Normalize);
    
            for nClusters = ClustPar.MinClasses:ClustPar.MaxClasses
                msinfo.MSMaps(nClusters).Maps = b_model{nClusters-ClustPar.MinClasses+1};
                msinfo.MSMaps(nClusters).ExpVar = exp_var(nClusters-ClustPar.MinClasses+1);
                msinfo.MSMaps(nClusters).ColorMap = lines(nClusters);
                msinfo.MSMaps(nClusters).SortMode = 'none';
                msinfo.MSMaps(nClusters).SortedBy = '';
                msinfo.MSMaps(nClusters).SpatialCorrelation= [];
            end
        end
    
        msinfo.ClustPar = ClustPar;
        AllEEG(sIndex).msinfo = msinfo;
        AllEEG(sIndex).saved = 'no';

        if SortMaps == true
            % Sort 3-6 cluster solutions using 2002 normative maps and 7
            % cluster solution with Custo 2017 maps
            if (ClustPar.MinClasses < 3 && ClustPar.MaxClasses > 2) || (ClustPar.MinClasses > 2)
                [AllEEG(sIndex), ~, ~] = pop_SortMSTemplates(AllEEG, sIndex, 0, -1, "Norms NI2002", 1);
            end
            if (ClustPar.MinClasses <= 7 && ClustPar.MaxClasses >= 7)
                [AllEEG(sIndex), ~, ~] = pop_SortMSTemplates(AllEEG, sIndex, 0, -1, "Custo2017", 1);
            end
        end
        if ShowMaps == true
            pop_ShowIndMSMaps(AllEEG(sIndex));
        end
        if ShowDyn == true
            pop_ShowIndMSDyn([],AllEEG(sIndex),0);
        end
    
    end

    EEGout = AllEEG(SelectedSets);
    CurrentSet = SelectedSets;
    
    structInfo = sprintf('struct(''MinClasses'', %i, ''MaxClasses'', %i, ''GFPPeaks'', %i, ''IgnorePolarity'', %i, ''MaxMaps'', %i, ''Restarts'', %i, ''UseAAHC'', %i, ''Normalize'', %i)',ClustPar.MinClasses, ClustPar.MaxClasses, ClustPar.GFPPeaks, ClustPar.IgnorePolarity, ClustPar.MaxMaps, ClustPar.Restarts, ClustPar.UseAAHC, ClustPar.Normalize);

    com = sprintf('[EEG CURRENTSET com] = pop_FindMSTemplates(ALLEEG, %s, %s, %i, %i, %i, %i);', mat2str(SelectedSets),structInfo,ShowMaps,ShowDyn,SortMaps);
end

function Answer = DoesItHaveChildren(in)
    Answer = false;
    if ~isfield(in,'msinfo')
        return;
    end
    
    if ~isfield(in.msinfo,'children')
        return
    else
        Answer = true;
    end
end