% UPDATE DOCUMENTATION TO REFLECT KEY, VALUE PARAMETERS
%
%pop_FindMSTemplates() interactively identify microstate topographies
%
% Usage:
%   >> [EEGout, CurrentSet, com] = pop_FindMSTemplates(AllEEG, SelectedSets, ClustPar,ShowMaps,ShowDyn, TemplateName)
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
%   Added by Delara 10/12/22
%   "Sort maps by published template when done" / TemplateName
%   -> Sort maps according to the specified published template when done
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

function [EEGout, CurrentSet, com] = pop_FindMSTemplates(AllEEG, varargin)

    %% Set defaults for outputs
    com = '';
    global MSTEMPLATE;
    global EEG;
    global CURRENTSET;
    EEGout = EEG;
    CurrentSet = CURRENTSET;

    guiElements = {};
    guiGeom = {};
    guiGeomV = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_FindMSTemplates';
    p.FunctionName = funcName;
    p.StructExpand = false;         % do not expand ClustPar struct input into key, value args
    
    logClass = {'logical', 'numeric'};
    logAttributes = {'binary', 'scalar'};
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'ClustPar', []);
    addParameter(p, 'ShowMaps', false, @(x) validateattributes(x, logClass, logAttributes));
    addParameter(p, 'ShowDyn', false, @(x) validateattributes(x, logClass, logAttributes));
    addParameter(p, 'TemplateSet', '', @(x) validateattributes(x, {'char', 'string'}, {'scalartext'}));

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    ClustPar = p.Results.ClustPar;
    ShowMaps = p.Results.ShowMaps;
    ShowDyn = p.Results.ShowDyn;
    TemplateSet = p.Results.TemplateSet;

    %% SelectedSets validation
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(and(and(~HasChildren, ~HasDyn), ~isEmpty));
    if isempty(AvailableSets)
        errordlg2(['No valid sets for clustering found.'], 'Identify microstates error');
        return;
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets);
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['The following sets cannot be clustered: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, or dynamics sets.'];
            errordlg2(errorMessage, 'Identify microstates error');
            return;
        end
    % Otherwise, add set selection gui elements
    else
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        if isempty(defaultSets);    defaultSets = 1;    end
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        guiElements = [guiElements, ....
                    {{ 'Style', 'text'    , 'string', 'Choose sets for clustering'}} ...
                    {{ 'Style', 'text'    , 'string', 'Use ctrlshift for multiple selection'}} ...
                    {{ 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}];
        guiGeom  = [guiGeom  1 1 1];
        guiGeomV = [guiGeomV  1 1 4];
    end

    %% ClustPar validation
    [ClustPar, ClustParDefaults] = checkClustPar(ClustPar);

    % Add all the cluster parameters that were filled in with default
    % values as gui elements
    if ~isempty(ClustParDefaults)
        guiElements = [guiElements ...
            {{ 'Style', 'text', 'string', 'Clustering parameters', 'fontweight', 'bold'  }}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];

        if contains('UseAAHC', ClustParDefaults)
            ClustPar.UseAAHC = floor(ClustPar.UseAAHC) + 1;
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Algorithm', 'fontweight', 'normal'  }} ...
                {{ 'Style', 'popupmenu', 'string',{'k-means','AAHC'},'tag','UseAAHC', 'Value', ClustPar.UseAAHC}}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    
        if contains('MinClasses', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Min number of classes', 'fontweight', 'normal'  }} ...
                {{ 'Style', 'edit', 'string', sprintf('%i',ClustPar.MinClasses), 'tag','MinClasses' }}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    
        if contains('MaxClasses', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Max number of classes', 'fontweight', 'normal'  }} ...
                {{ 'Style', 'edit', 'string', sprintf('%i',ClustPar.MaxClasses), 'tag','MaxClasses' }}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    
        if contains('Restarts', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Number of restarts', 'fontweight', 'normal'  }} ...
                {{ 'Style', 'edit', 'string', sprintf('%i',ClustPar.Restarts),'tag' 'Restarts' }}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    
        if contains('MaxMaps', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Max number of maps to use', 'fontweight', 'normal'  }} ...
                {{ 'Style', 'edit', 'string', sprintf('%i',ClustPar.MaxMaps), 'tag', 'MaxMaps'}}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    
        if contains('GFPPeaks', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'checkbox', 'string', 'GFP peaks only' 'tag', 'GFPPeaks','Value', ClustPar.GFPPeaks }}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end
    
        if contains('IgnorePolarity', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'checkbox', 'string', 'No polarity','tag','IgnorePolarity','Value', ClustPar.IgnorePolarity }}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end
    
        if contains('Normalize', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'checkbox', 'string', 'Normalize EEG before clustering','tag','Normalize' ,'Value', ClustPar.Normalize }}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end
    end

    %% Add other options as gui elements if they were not provided
    % (Only display in GUI if other cluster parameters are already being
    % displayed, otherwise use defaults)
    if ~isempty(p.UsingDefaults) && ~isempty(ClustParDefaults)
        guiElements = [guiElements ...
            {{ 'Style', 'text', 'string', 'Additional options', 'fontweight', 'bold'}}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];

        if contains('TemplateSet', p.UsingDefaults)
            [TemplateNames, DisplayNames] = getTemplateNames();

            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Sort maps by published template when done'}} ...
                {{ 'Style', 'popupmenu', 'string', DisplayNames,'tag','TemplateIndex','Value', 1}}];
            guiGeom = [guiGeom 1 1];
            guiGeomV = [guiGeomV 1 1];
        end

        if contains('ShowMaps', p.UsingDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'checkbox', 'string','Show maps when done','tag','ShowMaps','Value', ShowMaps}}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end
    
        if contains('ShowDyn', p.UsingDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'checkbox', 'string','Show dynamics when done','tag','ShowDyn','Value', ShowDyn }}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end
    end
    

    %% Prompt user to fill in remaining parameters if necessary
    if ~isempty(guiElements)
        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Microstate clustering parameters');

        if isempty(res); return; end

        if isfield(outstruct, 'SelectedSets')
            SelectedSets = AvailableSets(outstruct.SelectedSets);
        end
    
        if isfield(outstruct, 'UseAAHC')
            ClustPar.UseAAHC = outstruct.UseAAHC == 2;
        end
        if isfield(outstruct, 'MinClasses')
            ClustPar.MinClasses = str2double(outstruct.MinClasses);
        end
        if isfield(outstruct, 'MaxClasses')
            ClustPar.MaxClasses = str2double(outstruct.MaxClasses);
        end
        if isfield(outstruct, 'Restarts')
            ClustPar.Restarts = str2double(outstruct.Restarts);
        end
        if isfield(outstruct, 'MaxMaps')
            ClustPar.MaxMaps = str2double(outstruct.MaxMaps);
        end
        if isfield(outstruct, 'GFPPeaks')
            ClustPar.GFPPeaks = outstruct.GFPPeaks;
        end
        if isfield(outstruct, 'IgnorePolarity')
            ClustPar.IgnorePolarity = outstruct.IgnorePolarity;
        end
        if isfield(outstruct, 'Normalize')
            ClustPar.Normalize = outstruct.Normalize;
        end
        if isfield(outstruct, 'ShowMaps')
            ShowMaps = outstruct.ShowMaps;
        end
        if isfield(outstruct, 'ShowDyn')
            ShowDyn = outstruct.ShowDyn;
        end
        if isfield(outstruct, 'TemplateIndex')
            if outstruct.TemplateIndex ~= 1         
                TemplateSet = TemplateNames{outstruct.TemplateIndex - 1};
            end
        end
    end

    if numel(SelectedSets) < 1
        errordlg2('You must select at least one set of microstate maps.','Identify microstates error');
        return;
    end

    ClustPar = checkClustPar(ClustPar);

    if ClustPar.UseAAHC && ClustPar.Normalize
        warndlg2('There is an issue with the currently implemented AAHC algorithm and normalization, normalization has been set to false.','Clustering algorithm selection');
        ClustPar.Normalize = false;
    end

    if ~isfield(ClustPar,'UseEMD')
        ClustPar.UseEMD = false;
    end
    
    %% Clustering
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
                msinfo.MSMaps(nClusters).ColorMap = repmat([.75 .75 .75], nClusters, 1);
                for j = 1:nClusters
                    msinfo.MSMaps(nClusters).Labels{j} = sprintf('MS_%i.%i',nClusters,j);
                end
                msinfo.MSMaps(nClusters).SortMode = 'none';
                msinfo.MSMaps(nClusters).SortedBy = '';
                msinfo.MSMaps(nClusters).SpatialCorrelation= [];
            end
        else
            [b_model,exp_var] = eeg_computeAAHC(double(MapsToUse'),ClustPar.MinClasses:ClustPar.MaxClasses,false, ClustPar.IgnorePolarity,ClustPar.Normalize);
    
            for nClusters = ClustPar.MinClasses:ClustPar.MaxClasses
                msinfo.MSMaps(nClusters).Maps = b_model{nClusters-ClustPar.MinClasses+1};
                msinfo.MSMaps(nClusters).ExpVar = exp_var(nClusters-ClustPar.MinClasses+1);
                msinfo.MSMaps(nClusters).ColorMap = repmat([.75 .75 .75], nClusters, 1);
                for j = 1:nClusters
                    msinfo.MSMaps(nClusters).Labels{j} = sprintf('MS_%i.%i',nClusters,j);
                end
                msinfo.MSMaps(nClusters).SortMode = 'none';
                msinfo.MSMaps(nClusters).SortedBy = '';
                msinfo.MSMaps(nClusters).SpatialCorrelation= [];               
            end
        end
    
        msinfo.ClustPar = ClustPar;
        AllEEG(sIndex).msinfo = msinfo;
        AllEEG(sIndex).saved = 'no';
    end

    %% Sorting
    if ~isempty(TemplateSet)
        [EEGout, CurrentSet, ~] = pop_SortMSTemplates(AllEEG, SelectedSets, ...
            'IgnorePolarity', ClustPar.IgnorePolarity, 'TemplateSet', TemplateSet, ...
            'ClassRange', ClustPar.MinClasses:ClustPar.MaxClasses);
    else
        EEGout = AllEEG(SelectedSets);
        CurrentSet = SelectedSets;
    end

    %% Show maps
    if ShowMaps
        pop_ShowIndMSMaps(EEGout, 1:numel(EEGout));
    end

    %% Show dynamics
    if ShowDyn
        [EEGout, CurrentSet, ~] = pop_ShowIndMSDyn(EEGout, 1:numel(EEGout));
    end
    
    %% Command string generation
    com = sprintf('[EEG CURRENTSET com] = pop_FindMSTemplates(%s, %s, ''ClustPar'', %s, ''ShowMaps'', %i, ''ShowDyn'', %i, ''TemplateSet'', ''%s'');',  inputname(1), mat2str(SelectedSets), struct2String(ClustPar), ShowMaps, ShowDyn, TemplateSet);
end

function [ClustPar, UsingDefaults] = checkClustPar(varargin)
    
    if ~isempty(varargin)
        if isempty(varargin{:})
            varargin = {};
        end
    end

    % Parse and validate inputs
    p = inputParser;
    funcName = 'pop_FindMSTemplates';
    p.FunctionName = funcName;
    p.KeepUnmatched = true;

    numClass = {'numeric'};
    numAttributes = {'integer', 'positive', 'scalar'};
    logClass = {'logical', 'numeric'};
    logAttributes = {'binary', 'scalar'};

    % Numeric inputs
    addParameter(p, 'MinClasses', 4, @(x) validateattributes(x, numClass, numAttributes, funcName, 'ClustPar.MinClasses'));
    addParameter(p, 'MaxClasses', 7, @(x) validateattributes(x, numClass, numAttributes, funcName, 'ClustPar.MaxClasses'));
    addParameter(p, 'MaxMaps', inf, @(x) validateattributes(x, numClass, {'positive', 'scalar', 'nonnan'}, funcName, 'ClustPar.MaxMaps'));
    addParameter(p, 'Restarts', 20, @(x) validateattributes(x, numClass, numAttributes, funcName, 'ClustPar.Restarts'));

    % Logical inputs
    addParameter(p, 'GFPPeaks', true, @(x) validateattributes(x, logClass, logAttributes, funcName, 'ClustPar.GFPPeaks'));
    addParameter(p, 'IgnorePolarity', true, @(x) validateattributes(x, logClass, logAttributes, funcName, 'ClustPar.IgnorePolarity'));
    addParameter(p, 'UseAAHC', false, @(x) validateattributes(x, logClass, logAttributes, funcName, 'ClustPar.UseAAHC'));
    addParameter(p, 'Normalize', true, @(x) validateattributes(x, logClass, logAttributes, funcName, 'ClustPar.Normalize'));

    parse(p, varargin{:});
    ClustPar = p.Results;
    UsingDefaults = p.UsingDefaults;
end

function [TemplateNames, DisplayNames] = getTemplateNames()
    global MSTEMPLATE;
    TemplateNames = {MSTEMPLATE.setname};
    nClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MinClasses, 1:numel(MSTEMPLATE));
    [nClasses, sortOrder] = sort(nClasses, 'ascend');
    TemplateNames = TemplateNames(sortOrder);
    nSubjects = arrayfun(@(x) MSTEMPLATE(x).msinfo.MetaData.nSubjects, sortOrder);
    nSubjects = arrayfun(@(x) sprintf('n=%i', x), nSubjects, 'UniformOutput', false);
    DisplayNames = strcat(string(nClasses), " maps - ", TemplateNames, " - ", nSubjects);
    DisplayNames = ['None' DisplayNames];
end

function isEmpty = isEmptySet(in)
    isEmpty = all(cellfun(@(x) isempty(in.(x)), fieldnames(in)));
end

function hasDyn = isDynamicsSet(in)
    hasDyn = false;

    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end
    
    % check if set is a dynamics set
    if ~isfield(in.msinfo, 'DynamicsInfo')
        return;
    else
        hasDyn = true;
    end
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
