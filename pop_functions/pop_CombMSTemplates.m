% pop_CombMSTemplates() Interactively average microstate maps across sets
%
% This is not a simple averaging, but a permute and average loop that
% optimizes the order of microstate classes in the individual datasets for
% maximal communality before averaging.
%
% Usage:
%   >> [ALLEEG, EEG, com] = pop_CombMSTemplates(ALLEEG, SelectedSets, 
%       'key1', value1, 'key2', value2, ...)
%
% Graphical interface:
%
%   "Choose sets to combine"
%   -> Select sets to average into mean maps
%   -> Command line equivalent: "SelectedSets"
%
%   "Name of mean"
%   -> Name of mean set to be identified
%   -> Command line equivalent: "MeanName"
%
%   "No polarity"
%   -> Consider maps with inverted polarity the same class (standard for
%   resting state EEG)
%   -> Command line equivalent: "IgnorePolarity"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Array of set indices of ALLEEG to average. If not provided, a GUI
%   will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "MeanName"
%   -> String or character vector specifying name of mean set to be
%   identified. If not provided, a GUI will appear to enter a name.
%
%   "IgnorePolarity"
%   -> 1 = Consider maps with inverted polarities the same class, 0 =
%   consider maps with inverted polarites different classes. If not
%   provided, a GUI will appear to select this option.
%
% Outputs:
%
%   "ALLEEG"
%   -> ALLEEG structure array containing all sets loaded in EEGLAB. Will
%   include child sets with updated sorting if this option was selected.
%
%   "EEG" 
%   -> EEG structure containing mean microstate maps across selected sets
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

function [AllEEG, EEGout, com] = pop_CombMSTemplates(AllEEG, varargin)

    %% Set defaults for outputs
    com = '';
    global MSTEMPLATE;
    global guiOpts;
    global EEG;
    global CURRENTSET;
    EEGout = EEG;
    CurrentSet = CURRENTSET;

    guiElements = {};
    guiGeom = {};
    guiGeomV = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_CombMSTemplates';
    p.FunctionName = funcName;
    
    logClass = {'logical', 'numeric'};
    logAttributes = {'binary', 'scalar'};

    strClass = {'char', 'string'};
    strAttributes = {'scalartext'};
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'IgnorePolarity', true, @(x) validateattributes(x, logClass, logAttributes));
    addParameter(p, 'MeanName', 'GrandMean', @(x) validateattributes(x, strClass, strAttributes));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'vector'}));

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    IgnorePolarity = p.Results.IgnorePolarity;
    MeanName = p.Results.MeanName;
    Classes = p.Results.Classes;

    %% SelectedSets validation
    % First make sure there are enough sets to combine (at least 2)
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    isPublishedSet = arrayfun(@(x) matches(AllEEG(x).setname, {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableSets = find(and(and(and(~isEmpty, ~HasDyn), HasMS), ~isPublishedSet));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), AvailableSets);
    indSets = AvailableSets(~HasChildren);
    meanSets = AvailableSets(HasChildren);

    if numel(indSets) < 2 && numel(meanSets) < 2
        errordlg2(['Not enough valid sets for computing mean maps found.' ...
            'There must be at least 2 sets with microstate maps to combine.'], ...
            'Compute mean maps error');
        return;
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        % First check for empty sets, dynamics sets, or any sets without
        % microstate maps
        SelectedSets = unique(SelectedSets, 'stable');
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['The following sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, dynamics sets, or sets ' ...
                'without microstate maps.'];
            errordlg2(errorMessage, 'Compute mean maps error');
            return;
        end

        % Then make sure there are at least 2 sets
        if numel(SelectedSets) < 2
            errordlg2('You must select at least two sets of microstate maps','Combine microstate maps');
            return;
        end

        % Then make sure the selected sets are either all individual sets
        % or all mean sets
        indSelected = any(ismember(SelectedSets, indSets));
        meanSelected = any(ismember(SelectedSets, meanSets));
        if indSelected && meanSelected && guiOpts.showCombWarning
            warningMessage = ['Both individual sets and mean sets have been selected. ' ...
                'Are you sure you would like to proceed?'];
            [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Compute mean maps warning');
            if boxChecked;  guiOpts.showCombWarning = false;    end
            if ~yesPressed; return;                             end
            pickIndSets = false;
        else
            pickIndSets = indSelected;
        end
    % Otherwise, ask the user if they want to combine individual sets or
    % mean sets and add appropriate set selection gui elements
    else
        % If there are not enough mean sets or individual sets to combine,
        % don't bother asking which kind of sets to choose
        if numel(meanSets) < 2
            pickIndSets = true;
        elseif numel(indSets) < 2
            pickIndSets = false;
        % If there are enough mean sets and individual sets, ask the user
        % which kind of sets they would like to use
        else
            question = 'Which type of mean maps would you like to create?';
            title = 'Identify group level or grand mean maps';
            options = {'Mean maps across individuals', 'Grand mean maps across means'};
            selection = questionDialog(question, title, options);
            if isempty(selection) || strcmp(selection, 'Cancel')
                return;
            else
                pickIndSets = strcmp(selection, 'Mean maps across individuals');
            end
        end

        % Add appropriate gui elements
        if pickIndSets
            AvailableSets = indSets;            
        else
            AvailableSets = meanSets;
        end
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        if isempty(defaultSets);    defaultSets = 1;    end
        guiElements = [guiElements, ....
                    {{ 'Style', 'text'    , 'string', 'Choose sets to combine'}} ...
                    {{ 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'}} ...
                    {{ 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}];
        guiGeom  = [guiGeom  1 1 1];
        guiGeomV = [guiGeomV  1 1 4];
    end

    %% Add other gui elements
    if matches('MeanName', p.UsingDefaults)
        if pickIndSets
            MeanName = 'GroupMean_<group name>';
        end

        guiElements = [guiElements, ...
            {{ 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'}} ...
            {{ 'Style', 'edit', 'string', MeanName,'tag','MeanName'}}];
        guiGeom = [guiGeom [1 1]];
        guiGeomV = [guiGeomV 1];
    end

    if matches('IgnorePolarity', p.UsingDefaults)
        guiElements = [guiElements ...
            {{ 'Style', 'checkbox', 'string', 'No polarity','tag','IgnorePolarity','Value', IgnorePolarity }}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];
    end

    % Add option to sort when done if other elements are being shown
    if any(matches({'SelectedSets', 'IgnorePolarity', 'MeanName'}, p.UsingDefaults))
        guiElements = [guiElements ...
            {{ 'Style', 'checkbox', 'string', 'Edit & sort maps when done', 'tag', 'SortMaps', 'Value', 1}}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];
    end

    %% Prompt user to fill in remaining parameters if necessary
    SortMaps = false;
    if ~isempty(guiElements)
        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Identify group level or grand mean maps');

        if isempty(res); return; end

        if isfield(outstruct, 'SelectedSets')
            SelectedSets = AvailableSets(outstruct.SelectedSets);
        end

        if isfield(outstruct, 'MeanName')
            MeanName = outstruct.MeanName;
        end
    
        if isfield(outstruct, 'IgnorePolarity')
            IgnorePolarity = outstruct.IgnorePolarity;
        end

        if isfield(outstruct, 'SortMaps')
            SortMaps = outstruct.SortMaps;
        end
    end

    if numel(SelectedSets) < 2
        errordlg2('You must select at least two sets of microstate maps','Combine microstate maps error');
        return;
    end

    %% Get all channel locations and verify that parameters are identical across sets
    MinClasses     = AllEEG(SelectedSets(1)).msinfo.ClustPar.MinClasses;
    MaxClasses     = AllEEG(SelectedSets(1)).msinfo.ClustPar.MaxClasses;
    tempIPolarity  = AllEEG(SelectedSets(1)).msinfo.ClustPar.IgnorePolarity;
    GFPPeaks       = AllEEG(SelectedSets(1)).msinfo.ClustPar.GFPPeaks;
    
    if ~isfield(AllEEG(SelectedSets(1)).msinfo.ClustPar,'UseEMD')
        UseEMD = false;
    else
        UseEMD = AllEEG(SelectedSets(1)).msinfo.ClustPar.UseEMD;
    end
    
    allchans  = { };
    children  = cell(length(SelectedSets),1);
    keepindex = 0;

    for index = 1:length(SelectedSets)
        if  MinClasses     ~= AllEEG(SelectedSets(index)).msinfo.ClustPar.MinClasses || ...
            MaxClasses     ~= AllEEG(SelectedSets(index)).msinfo.ClustPar.MaxClasses || ...
            tempIPolarity  ~= AllEEG(SelectedSets(index)).msinfo.ClustPar.IgnorePolarity || ...
            GFPPeaks       ~= AllEEG(SelectedSets(index)).msinfo.ClustPar.GFPPeaks
            errordlg2('Microstate parameters differ between datasets','Combine microstate maps');
            return;
        end
    
        children(index) = {AllEEG(SelectedSets(index)).setname};
        tmpchanlocs = AllEEG(SelectedSets(index)).chanlocs;
        tmpchans = { tmpchanlocs.labels };
        allchans = unique_bc([ allchans {tmpchanlocs.labels}]);

        if length(allchans) == length(tmpchans)
            keepindex = index;
        end
    end
    if keepindex
        tmpchanlocs = AllEEG(SelectedSets(keepindex)).chanlocs; 
    %    allchans = { tmpchanlocs.labels }; 
    end

    msinfo.children = children;
    msinfo.ClustPar = AllEEG(SelectedSets(1)).msinfo.ClustPar;
   
    if ~isempty(Classes)
        MinClasses = min(Classes);
        MaxClasses = max(Classes);
    end

    %% Create combined maps
    for n = MinClasses:MaxClasses
        MapsToSort = nan(numel(SelectedSets),n,numel(tmpchanlocs));
        % Here we go to the common set of channels
        for index = 1:length(SelectedSets)
            LocalToGlobal = MakeResampleMatrices(AllEEG(SelectedSets(index)).chanlocs,tmpchanlocs);
            MapsToSort(index,:,:) = AllEEG(SelectedSets(index)).msinfo.MSMaps(n).Maps * LocalToGlobal';
        end
        % We sort out the stuff
        [BestMeanMap,~,ExpVar] = PermutedMeanMaps(MapsToSort,~IgnorePolarity,tmpchanlocs,[],UseEMD); % debugging only

        % Compute mean shared variances
        sharedVars = zeros(numel(SelectedSets), n);
        for index = 1:length(SelectedSets)
            for class = 1:n
                var = MyCorr(squeeze(MapsToSort(index,class,:)), BestMeanMap(class, :)').^2;
                if var < .5
                    var = 1 - var;
                end
                sharedVars(index,class) = var;
            end
        end
        msinfo.MSMaps(n).Maps = BestMeanMap;
        msinfo.MSMaps(n).ExpVar = ExpVar;
        msinfo.MSMaps(n).SharedVar = mean(sharedVars);        
        msinfo.MSMaps(n).ColorMap = repmat([.75 .75 .75], n, 1);
        for j = 1:n
            msinfo.MSMaps(n).Labels{j} = sprintf('MS_%i.%i', n,j);
        end
        msinfo.MSMaps(n).SortMode = 'none';
        msinfo.MSMaps(n).SortedBy = 'none';
        msinfo.MSMaps(n).SpatialCorrelation = [];
    end
    
    EEGout = eeg_emptyset();
    EEGout.chanlocs = tmpchanlocs;
    EEGout.data = zeros(numel(EEGout.chanlocs),MaxClasses,MaxClasses);
    EEGout.msinfo = msinfo;
    
    for n = MinClasses:MaxClasses
        EEGout.data(:,1:n,n) = msinfo.MSMaps(n).Maps';
    end
    
    EEGout.setname     = MeanName;
    EEGout.nbchan      = size(EEGout.data,1);
    EEGout.trials      = size(EEGout.data,3);
    EEGout.pnts        = size(EEGout.data,2);
    EEGout.srate       = 1;
    EEGout.xmin        = 1;
    EEGout.times       = 1:EEGout.pnts;
    EEGout.xmax        = EEGout.times(end);

    %% Edit and sort maps
    sortCom = '';
    if SortMaps        
        newEEG = pop_newset(AllEEG, EEGout, numel(AllEEG), 'gui', 'off');
        [newEEG, EEGout, ~, sortCom] = pop_SortMSTemplates(newEEG, numel(newEEG), 'TemplateSet', 'manual');
        AllEEG = eeg_store(AllEEG, newEEG(1:end-1), 1:numel(newEEG)-1);
    end

    %% Command string generation
    com = sprintf('[ALLEEG, EEG] = pop_CombMSTemplates(%s, %s, ''MeanName'', ''%s'', ''IgnorePolarity'', %i);', inputname(1), mat2str(SelectedSets), MeanName, IgnorePolarity);
    if ~isempty(sortCom)
        com = [com newline sortCom];
    end
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

function hasMS = hasMicrostates(in)
    hasMS = false;

    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end
    
    % check if msinfo is empty
    if isempty(in.msinfo)
        return;
    else
        hasMS = true;
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
