% pop_FindMSMaps() Interactively identify microstate topographies
%
% Usage:
%   >> [EEG, CURRENTSET] = pop_FindMSMaps(ALLEEG, SelectedSets, 
%       'ClustPar', ClustPar)
%
% Graphical interface:
%
%   "Choose sets for clustering"
%   -> Select sets for which microstates will be identified
%   -> Command line equivalent: "SelectedSets"
%
%   "Clustering parameters"
%    ---------------------
%   "Algorithm"
%   -> Choose k-means or AAHC for the algorithm used for clustering
%   -> Command line equivalent: "ClustPar.UseAAHC"
%
%   "Min number of classes"
%   -> Minimum number of clusters to identify
%   -> Command line equivalent: "ClustPar.MinClasses"
%
%   "Max number of classes"
%   -> Maximum number of clusters to identify
%   -> Command line equivalent: "ClustPar.MaxClasses"
%
%   "Number of restarts"
%   -> Number of times the k-means algorithm is restarted with a new random
%   configuration. Ignored if AAHC is selected.
%   -> Command line equivalent: "ClustPar.Restarts"
%
%   "Max number of maps to use"
%   -> Maximum number of data samples used to identify clusters. Will
%   choose a random subsample of the size specified. Enter "inf" to use all
%   data samples.
%   -> Command line equivalent: "ClustPar.MaxMaps"
%
%   "GFP peaks only"
%   -> Limit the selection of maps used for clustering to global field
%   power peaks
%   -> Command line equivalent: "ClustPar.GFPPeaks"
%
%   "No polarity"
%   -> Assign maps with inverted polarity to the same class (standard for
%   resting state EEG)
%   -> Command line equivalent: "ClustPar.IgnorePolarity"
%
%   "Normalize EEG before clustering"
%   -> Normalize data such that each sample has a global field power of 1
%   before clustering. Normalization will only apply to clustering and not
%   modify data stored in the EEG set.
%   -> Command line equivalent: "ClustPar.Normalize"
%
%   "Additional options"
%    ------------------
%   "Show maps when done"
%   -> Show maps when done. If multiple sets are selected, a tab will be
%   opened for each.
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Vector of set indices of ALLEEG for which microstates will be
%   identified. If not provided, a GUI will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "ClustPar"
%   -> Structure containing fields specifying parameters to use for
%   clustering. If some required fields are not included, a GUI will appear
%   with the unincluded fields. Required fields:
%       "ClustPar.UseAAHC"
%       -> 1 = use AAHC algorithm, 0 = use k-means algorithm
%
%       "ClustPar.MinClasses"
%       -> Minimum number of clusters to identify
%
%       "ClustPar.MaxClasses"
%       -> Maximum number of clusters to identify
%
%       "ClustPar.Restarts"
%       -> Number of times the k-means algorithm is restarted with a new
%        random configuration. Ignored if ClustPar.UseAAHC is 1.
%
%       "ClustPar.MaxMaps"
%       -> Maximum number of data samples used to identify clusters. Will
%       choose a random subsample of the size specified. Use "inf" to use
%       all data samples.
%
%       "ClustPar.GFPPeaks"
%       -> 1 = Use only samples at global field power peaks for clustering,
%       0 = use all samples for clustering
%
%       "ClustPar.IgnorePolarity"
%       -> 1 = Assign maps with inverted polarity to the same class, 0 =
%       assign maps with inverted polarity to different classes
%
%       "ClustPar.Normalize"
%       -> 1 = Normalize data such that each sample has a global field
%       power of 1 before clustering, 0 = do not normalize data.
%        Normalization will only apply to clustering and not modify data 
%       stored in the EEG set.
%
% Outputs:
%
%   "EEG" 
%   -> EEG structure array of selected sets with microstate map information
%   added to the "msinfo" field
% 
%   "CURRENTSET"
%   -> The indices of the EEGs containing the identified microstate maps
%
%   "com"
%   -> Command necessary to replicate the computation
%
% MICROSTATELAB: The EEGLAB toolbox for resting-state microstate analysis
% Version 1.0
%
% Authors:
% Thomas Koenig (thomas.koenig@upd.unibe.ch)
% Delara Aryan  (dearyan@chla.usc.edu)
% 
% Copyright (C) 2023 Thomas Koenig and Delara Aryan
%
% If you use this software, please cite as:
% "MICROSTATELAB: The EEGLAB toolbox for resting-state microstate 
% analysis by Thomas Koenig and Delara Aryan"
% In addition, please reference MICROSTATELAB within the Materials and
% Methods section as follows:
% "Analysis was performed using MICROSTATELAB by Thomas Koenig and Delara
% Aryan."
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

function [EEGout, CurrentSet, com] = pop_FindMSMaps(AllEEG, varargin)

    [~,nogui] = eegplugin_microstatelab;

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
    p.FunctionName = 'pop_FindMSMaps';
    p.StructExpand = false;         % do not expand ClustPar struct input into key, value args
    
    logClass = {'logical', 'numeric'};
    logAttributes = {'binary', 'scalar'};
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'nonnegative', '<=', numel(AllEEG)})); % Took out the 'vector attirbute to allow for [] input
    addParameter(p, 'ClustPar', []);
    addParameter(p, 'TTFrD', false, @(x) validateattributes(x, logClass, logAttributes));

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    ClustPar = p.Results.ClustPar;
    DoTTFrD = p.Results.TTFrD;
    ShowMaps = false;

    %% SelectedSets validation
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    HasTTFrDF   = arrayfun(@(x) DoesItHaveWavelets(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    isPublished = arrayfun(@(x) isPublishedSet(AllEEG(x), {MSTEMPLATE.setname}), 1:numel(AllEEG));
    if DoTTFrD == true
        AvailableSets = find(~isEmpty & ~HasChildren & ~HasDyn & ~isPublished & HasTTFrDF);
    else
        AvailableSets = find(~isEmpty & ~HasChildren & ~HasDyn & ~isPublished);
    end
    
    if isempty(AvailableSets)
        errorMessage = 'No valid sets for identifying microstates found.';
        if matches('SelectedSets', p.UsingDefaults)
            errorDlg2(errorMessage, 'Identify microstates per dataset error');
            return;
        else
            error(errorMessage);
        end
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets, 'stable');
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error(['The following sets cannot be clustered: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, or dynamics sets.']);
        end
    % Otherwise, add set selection gui elements
    else
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        if isempty(defaultSets);    defaultSets = 1;    end
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        guiElements = [guiElements, ....
                    {{ 'Style', 'text'    , 'string', 'Choose sets for clustering', 'fontweight', 'bold'}} ...
                    {{ 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'}} ...
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

        if matches('UseAAHC', ClustParDefaults)
            ClustPar.UseAAHC = floor(ClustPar.UseAAHC) + 1;
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Algorithm', 'fontweight', 'normal'  }} ...
                {{ 'Style', 'popupmenu', 'string',{'k-means','AAHC'},'tag','UseAAHC', 'Value', ClustPar.UseAAHC, 'Callback', @algorithmChanged}}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    
        if matches('MinClasses', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Min number of classes', 'fontweight', 'normal'  }} ...
                {{ 'Style', 'edit', 'string', sprintf('%i',ClustPar.MinClasses), 'tag','MinClasses' }}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    
        if matches('MaxClasses', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Max number of classes', 'fontweight', 'normal'  }} ...
                {{ 'Style', 'edit', 'string', sprintf('%i',ClustPar.MaxClasses), 'tag','MaxClasses' }}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    
        if matches('Restarts', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Number of restarts', 'fontweight', 'normal', 'tag', 'RestartsLabel'  }} ...
                {{ 'Style', 'edit', 'string', sprintf('%i',ClustPar.Restarts),'tag' 'Restarts' }}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    
        if matches('MaxMaps', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', 'Max number of maps to use', 'fontweight', 'normal'  }} ...
                {{ 'Style', 'edit', 'string', sprintf('%i',ClustPar.MaxMaps), 'tag', 'MaxMaps'}}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    
        if matches('GFPPeaks', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'checkbox', 'string', 'GFP peaks only' 'tag', 'GFPPeaks','Value', ClustPar.GFPPeaks }}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end
    
        if matches('IgnorePolarity', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'checkbox', 'string', 'No polarity','tag','IgnorePolarity','Value', ClustPar.IgnorePolarity }}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end
    
        if matches('Normalize', ClustParDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'checkbox', 'string', 'Normalize EEG before clustering','tag','Normalize' ,'Value', ClustPar.Normalize }}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end
    end

    %% Add other options as gui elements
    % (Only display in GUI if other cluster parameters are already being
    % displayed, otherwise use defaults)
    if ~isempty(ClustParDefaults)
        guiElements = [guiElements ...
            {{ 'Style', 'text', 'string', 'Additional options', 'fontweight', 'bold'}} ...
            {{ 'Style', 'checkbox', 'string','Show maps when done','tag','ShowMaps','Value', ShowMaps}}];
        guiGeom = [guiGeom 1 1];
        guiGeomV = [guiGeomV 1 1];
    end
    
    %% Prompt user to fill in remaining parameters if necessary
    if ~isempty(guiElements)
        if nogui == true
            error("Parameters missing in function pop_FindMSMaps, check the help for pop_FindMSMaps for support");
        end
        
        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Identify microstate maps per dataset');

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

        if numel(SelectedSets) < 1
            errordlg2('You must select at least one dataset.','Identify microstate maps per dataset error');
            return;
        end
    end

    ClustPar = checkClustPar(ClustPar);

    if ClustPar.UseAAHC && ClustPar.Normalize
        warndlg2('There is an issue with the currently implemented AAHC algorithm and normalization, normalization has been set to false.','Clustering algorithm selection');
        ClustPar.Normalize = false;
    end
    
    FailedSets = [];
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
    
        if DoTTFrD
            if isfield(AllEEG(sIndex).TTFrD.Wavelets,'Include')
                MapsToUse = AllEEG(sIndex).TTFrD.Wavelets.Maps(:,AllEEG(sIndex).TTFrD.Wavelets.Include);
            else
                MapsToUse = AllEEG(sIndex).TTFrD.Wavelets.Maps;
            end
        else

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
        end

        if size(MapsToUse,2) < ClustPar.MaxClasses
            warning('Not enough data to cluster in set %s',AllEEG(sIndex).setname);
%            FailedSets = [FailedSets,sIndex]; %#ok<AGROW> 
            FailedSets = [FailedSets,i]; %#ok<AGROW> Fix TK 2.9.2024

            continue;
        end

        flags = '';
        if ClustPar.IgnorePolarity == false
            flags = [flags 'p'];
        end
        if ClustPar.Normalize == true
            flags = [flags 'n'];
        end
        
        if isfield(ClustPar, 'UseEMD')
            if ClustPar.UseEMD == true
                flags = [flags 'e'];
            end
        end
        
        if ClustPar.UseAAHC == false
            for nClusters = ClustPar.MinClasses:ClustPar.MaxClasses
                [b_model,~,~,exp_var] = eeg_kMeans(MapsToUse',nClusters,ClustPar.Restarts,[],flags,AllEEG(sIndex).chanlocs);
       
                msinfo.MSMaps(nClusters).Maps = double(b_model);
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
                msinfo.MSMaps(nClusters).Maps = double(b_model{nClusters-ClustPar.MinClasses+1});
                msinfo.MSMaps(nClusters).ExpVar = double(exp_var{nClusters-ClustPar.MinClasses+1});
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

    % Remove sets that were not clustered
    SelectedSets(FailedSets) = [];

    if isempty(SelectedSets)
        EEGout = EEG;
        CurrentSet = CURRENTSET;
    else
        EEGout = AllEEG(SelectedSets);
        CurrentSet = SelectedSets;    
    end
    %% Command string generation
    com = sprintf('[EEG, CURRENTSET] = pop_FindMSMaps(%s, %s, ''ClustPar'', %s);',  inputname(1), mat2str(SelectedSets), struct2String(ClustPar));

    %% Show maps
    if ShowMaps
        pop_ShowIndMSMaps(EEGout, 1:numel(EEGout), 'Classes', ClustPar.MinClasses:ClustPar.MaxClasses);
        com = [com newline ...
            sprintf('fig_h = pop_ShowIndMSMaps(EEG, %s, ''Classes'', %i:%i, ''Visible'', 1);', mat2str(1:numel(SelectedSets)), ClustPar.MinClasses, ClustPar.MaxClasses)];
    end
end

function algorithmChanged(obj, ~)
    restartsLabel = findobj(obj.Parent, 'Tag', 'RestartsLabel');
    restartsEdit = findobj(obj.Parent, 'Tag', 'Restarts');
    normalizeBox = findobj(obj.Parent, 'Tag', 'Normalize');

    if obj.Value == 1
        if ~isempty(restartsLabel)
            restartsLabel.Enable = 'on';
            restartsEdit.Enable  = 'on';
        end
        if ~isempty(normalizeBox)
            normalizeBox.Value = 1;
            normalizeBox.Enable  = 'on';
        end
    else
        if ~isempty(restartsLabel)
            restartsLabel.Enable = 'off';
            restartsEdit.Enable  = 'off';
        end
        if ~isempty(normalizeBox)
            normalizeBox.Value = 0;
            normalizeBox.Enable  = 'off';
        end
    end
end

function [ClustPar, UsingDefaults] = checkClustPar(varargin)
    
    if ~isempty(varargin)
        if isempty(varargin{:})
            varargin = {};
        end
    end

    % Parse and validate inputs
    p = inputParser;
    funcName = 'pop_FindMSMaps';
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

function isEmpty = isEmptySet(in)
    isEmpty = all(cellfun(@(x) isempty(in.(x)), fieldnames(in)));
end

function hasDyn = isDynamicsSet(in)
    hasDyn = false;
    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end    
    % check if set has FitPar
    if ~isfield(in.msinfo, 'FitPar')
        return;
    end
    % check if FitPar contains Rectify/Normalize parameters
    if ~isfield(in.msinfo.FitPar, 'Rectify')
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

function isPublished = isPublishedSet(in, templateNames)
    isPublished = false;
    if isempty(in.setname)
        return;
    end

    if matches(in.setname, templateNames)
        isPublished = true;
    end
end

function Answer = DoesItHaveWavelets(in)
    Answer = false;
    if ~isfield(in,'TTFrD')
        return;
    end
    
    if ~isfield(in.TTFrD,'Wavelets')
        return
    end
    if ~isfield(in.TTFrD.Wavelets,'Maps')
        return;
    else
        Answer = true;
    end
end
