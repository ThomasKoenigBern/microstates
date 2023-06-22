% pop_GetMSDynamics() Generate new EEG datasets representing the temporal
% dynamics of microstates over time. For each set chosen, a new dataset
% will be generated with one data channel for each microstate map, whose
% values over time are the activations of that microstate map over time.
% pop_FitMSMaps() must be used before calling this function to extract
% temporal parameters.
%
% Usage:
%   >> [EEG, CURRENTSET] = pop_GetMSDynamics(ALLEEG, SelectedSets, 
%       'Classes', Classes, 'Rectify', true/false, 'Normalize', true/false)
%
% Graphical interface:
%
%   "Choose sets for obtaining dynamics"
%   -> Select sets for which new sets should be generated representing
%   temporal dynamics
%   -> Command line equivalent: "SelectedSets"
%
%   "Select number of classes"   
%   -> Select which fitting solution should be used
%   -> Command line equivalent: "Classes"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Vector of set indices of ALLEEG for which new sets containg temporal
%   dynamics representations will be generated. If not provided, a GUI will
%   appear to select sets.
%
% Key, Value inputs (optional):
%
%   "Classes"
%   -> Integer indicating the fitting solution whose associated temporal 
%   dynamics will be stored in new sets.
%
%   "Rectify"
%   -> 1 = Remove polarity reversal information from microstate assignments
%   (store the absolute value of microstate assignments), 0 = retain
%   polarity reversal information
%
%   "Normalize"
%   -> 1 = Represent microstate activations as binary 1s or 0s, 0 =
%   represent microstate activations as continuous strengths of
%   activations, quantified as dot products between each microstate map and
%   associated voltage vectors.
%
% Outputs:
%
%   "EEG" 
%   -> EEG structure array of new sets containg temporal dynamics
%   representations of the selected sets.
%
%   "CURRENTSET" 
%   -> Indices of the new dynamics sets.
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

function [EEGout, CurrentSet, com] = pop_GetMSDynamics(AllEEG, varargin)

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
    p.FunctionName = 'pop_GetMSDynamics';

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));
    addParameter(p, 'Rectify', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    addParameter(p, 'Normalize', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));    
    
    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    nClasses = p.Results.Classes;
    Rectify = p.Results.Rectify;
    Normalize = p.Results.Normalize;

    %% SelectedSets validation    
    HasStats = arrayfun(@(x) hasStats(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(HasStats & ~HasDyn);
    
    if isempty(AvailableSets)
        errorMessage = ['No sets with temporal parameters found. ' ...
            'Use Tools->Backfit microstate maps to EEG to extract temporal dynamics.'];
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(errorMessage, 'Obtain microstate activation time series error');
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
            error(['The following sets do not contain temporal parameters: %s. ' ...
                'Use pop_FitMSMaps() to extract temporal dynamics first.'], invalidSetsTxt);
        end
    % Otherwise, prompt user to choose sets
    else
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        [res,~,~,outstruct] = inputgui('geometry', [1 1 1], 'geomvert', [1 1 4], 'uilist', {
                    { 'Style', 'text'    , 'string', 'Choose sets for obtaining dynamics', 'fontweight', 'bold'} ...
                    { 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'} ...
                    { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
                    'title', 'Obtain microstate activation time series');

        if isempty(res); return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);

        if numel(SelectedSets) < 1
            errordlg2('You must select at least one dataset','Obtain microstate activation time series error');
            return;
        end
    end         
    SelectedEEG = AllEEG(SelectedSets);

    %% Classes validation
    classRanges = arrayfun(@(x) SelectedEEG(x).msinfo.FitPar.Classes, 1:numel(SelectedEEG), 'UniformOutput', false)';
    commonClasses = classRanges{1};
    for i=2:numel(SelectedSets)
        commonClasses = intersect(commonClasses, classRanges{i});
    end

    if isempty(commonClasses)
        errorMessage = 'No overlap in cluster solutions used for fitting found between all selected sets.';
        if matches('SelectedSets', p.UsingDefaults)
            errordlg2(errorMessage, 'Obtain microstate activation time series error');
        else
            error(errorMessage);
        end
        return;
    end
    if matches('Classes', p.UsingDefaults)
        classChoices = sprintf('%i Classes|', commonClasses);
        classChoices(end) = [];

        guiElements = [guiElements ...
            {{ 'Style', 'text', 'string', 'Select number of classes' }} ...
            {{ 'Style', 'listbox', 'string', classChoices, 'Value', 1, 'Tag', 'Classes' }}];
        guiGeom = [guiGeom 1 1];
        guiGeomV = [guiGeomV 1 4];
    else
        if ~ismember(nClasses, commonClasses)
            classesTxt = sprintf('%i, ', commonClasses);
            classesTxt = classesTxt(1:end-2);
            error(['Not all selected sets contain microstate dynamics information for the %i cluster solution. ' ...
                'Valid class numbers include: %s.'], nClasses, classesTxt);
        end
    end

    %% Add other gui elements
    if matches('Rectify', p.UsingDefaults)
        guiElements = [guiElements ...
            {{ 'Style', 'checkbox', 'string', 'Rectify', 'tag', 'Rectify', 'Value', Rectify}}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];
    end

    if matches('Normalize', p.UsingDefaults)
        guiElements = [guiElements ...
            {{ 'Style', 'checkbox', 'string', 'Normalize', 'tag', 'Normalize', 'Value', Normalize}}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];
    end

    %% Prompt user to fill in remaining parameters if necessary
    if ~isempty(guiElements)
        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Obtain microstate activation time series');

        if isempty(res); return; end
        
        if isfield(outstruct, 'Classes')
            nClasses = commonClasses(outstruct.Classes);
        end

        if isfield(outstruct, 'Rectify')
            Rectify = outstruct.Rectify;
        end

        if isfield(outstruct, 'Normalize')
            Normalize = outstruct.Normalize;
        end
    end
    
    %% Obtain dynamics    
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    meanSets = find(HasChildren);
    meanSetnames = {AllEEG(meanSets).setname};
    publishedSetnames = {MSTEMPLATE.setname};
    for s=1:length(SelectedSets)
        TemplateName = SelectedEEG(s).msinfo.MSStats(nClasses).FittingTemplate;
        if strcmp(TemplateName, '<<own>>')
            MSMaps = SelectedEEG(s).msinfo.MSMaps(nClasses);
            templateChanlocs = SelectedEEG(s).chanlocs;
        else
            % Look for the fitting template in ALLEEG and MSTEMPLATE
            if matches(TemplateName, meanSetnames)
                meanIdx = meanSets(matches(meanSetnames, TemplateName));
                if numel(meanIdx) > 1
                    errorMessage = sprintf(['Multiple mean sets found that match the fitting template "%s" ' ...
                            'for dataset %i. Please rename duplicate mean sets.'], TemplateName, SelectedSets(s));
                    if isempty(p.UsingDefaults)
                        error(errorMessage);
                    else
                        errordlg2(errorMessage, 'Obtain microstate activation time series error');
                        return;
                    end
                else
                    MSMaps = AllEEG(meanIdx).msinfo.MSMaps(nClasses);     
                    templateChanlocs = AllEEG(meanIdx).chanlocs;
                end
            elseif matches(TemplateName, publishedSetnames)
                meanIdx = matches(publishedSetnames, TemplateName);
                MSMaps = MSTEMPLATE(meanIdx).msinfo.MSMaps(nClasses);
                templateChanlocs = MSTEMPLATE(meanIdx).chanlocs;
            else
                errorMessage = sprintf('Fitting template "%s" for dataset %i could not be found.', TemplateName, SelectedSets(s));
                if isempty(p.UsingDefaults)
                    error(errorMessage);
                else
                    errordlg2(errorMessage, 'Obtain microstate activation time series error');
                    return;
                end
            end   
        end

        [LocalToGlobal, GlobalToLocal] = MakeResampleMatrices(SelectedEEG(s).chanlocs, templateChanlocs);

        MSClass = SelectedEEG(s).msinfo.MSStats(nClasses).MSClass;
        if isempty(MSClass);    return; end

        newEEG(s) = SelectedEEG(s);
        newEEG(s).setname = [SelectedEEG(s).setname '_dynamics'];
        newEEG(s).nbchan = nClasses;

        % replace MSMaps and MSStats with only the relevant maps        
        newEEG(s).msinfo = rmfield(newEEG(s).msinfo, 'MSMaps');
        newEEG(s).msinfo.MSMaps(nClasses) = MSMaps;
        newEEG(s).msinfo.MSStats([1:nClasses-1, nClasses+1:end]) = [];

        % add new fitting parameters
        newEEG(s).msinfo.FitPar.Rectify = Rectify;
        newEEG(s).msinfo.FitPar.Normalize = Normalize;

        Centering = eye(size(SelectedEEG(s).data, 1)) - 1/size(SelectedEEG(s).data, 1); 

        newData = zeros(nClasses, SelectedEEG(s).pnts, SelectedEEG(s).trials);
        
        for class=1:nClasses
            if isempty(MSMaps.Labels)
                ChanName = sprintf('MS_%i.%i', nClasses, class);
            else
                ChanName = MSMaps.Labels{class};
            end
            
            chanlocs(class) = struct('labels',ChanName,'type','','theta', nan,'radius',nan,'X',nan,'Y',nan,'Z',nan,'sph_theta',nan,'sph_phi',nan,'sph_radius',nan,'urchan',nan,'ref','none');

            for e=1:SelectedEEG(s).trials
                assigned = MSClass(:,e) == class;
                if Normalize
                    newData(class, :, e) = assigned;
                else        
                    % average reference data
%                     data = Centering*SelectedEEG(s).data(:, assigned, e);
                    data = SelectedEEG(s).data(:, assigned, e);                    
                    if SelectedEEG(s).nbchan > length(templateChanlocs)
                        newData(class, assigned, e) = MSMaps.Maps(class, :)*(LocalToGlobal*data);
                    elseif SelectedEEG(s).nbchan < length(templateChanlocs)
                        newData(class, assigned, e) = (MSMaps.Maps(class, :)*GlobalToLocal')*data;
                    else
                        newData(class, assigned, e) = MSMaps.Maps(class, :)*data;
                    end

                    if Rectify
                        newData(class, assigned, e) = abs(newData(class, assigned, e));
                    end
                end
            end

            newEEG(s).chanlocs = chanlocs;
            newEEG(s).data = newData;
        end
    end

    EEGout = newEEG;
    CurrentSet = numel(AllEEG);     % update CurrentSet so new datasets will be appended to the end of ALLEEG

    com = sprintf('[EEG, CURRENTSET, com] = pop_GetMSDynamics(%s, %s, ''Classes'', %i);', inputname(1), mat2str(SelectedSets), nClasses);
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

function hasStats = hasStats(in)
    hasStats = false;

    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end
    
    % check if set has MSStats
    if ~isfield(in.msinfo, 'MSStats')
        return;
    else
        hasStats = true;
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