% pop_GetMSDynamics() Generate new EEG datasets representing the temporal
% dynamics of microstates over time. For each set chosen, a new dataset
% will be generated with one data channel for each microstate map, whose
% values over time are the activations of that microstate map over time.
% Useful for other downstream analyses.
%
% Usage:
%   >> [EEG, CURRENTSET, com] = pop_GetMSDynamics(ALLEEG, SelectedSets,
%       'key1', value1, 'key2', value2)
%
% To use each subject's own microstate maps for backfitting, specify
% "TemplateSet" as "own."
% Ex:
%   >> [EEG, CURRENTSET] = pop_GetMSDynamics(ALLEEG, 1:5, 'TemplateSet',
%       'own')
%
% To use a mean set or published set for backfitting, specify either the
% index of the mean set in ALLEEG, the name of the mean set, or the name of
% the published set.
% Ex:
%   >> [EEG, CURRENTSET] = pop_GetMSDynamics(ALLEEG, 1:5, 'TemplateSet',
%       'Koenig2002')
%
% Graphical interface:
%
%   "Choose sets for obtaining dynamics"
%   -> Select sets for which new sets should be generated representing
%   temporal dynamics
%   -> Command line equivalent: "SelectedSets"
%
%   "Name of template set"
%   -> Name of template set whose maps will be used for backfitting and
%   extracting temporal dynamics. Select "Own" to use each subject's own
%   maps to backfit their own data, or select the name of a template set
%   to use its maps for backfitting for all subjects.
%   -> Command line equivalent: "TemplateSet"
%
%   "Microstate fitting parameters"
%   ------------------------------
%
%   "Number of classes"
%   -> Number of classes to use for backfitting
%   -> Command line equivalent: "FitPar.nClasses"
%
%   "Fitting only on GFP peaks"
%   -> Controls whether to backfit maps only at global field power peaks
%   and interpolate microstae assignments in between peaks, or to backfit
%   maps at all timepoints.
%   -> Command line equivalent: "FitPar.PeakFit"
%
%   "Remove potentially truncated microstates"
%   -> Controls whether to remove microstate assignments around boundary
%   events in the EEG data
%   -> Command line equivalent: "FitPar.BControl"
%
%   "Label smoothing window"
%   -> Window size in ms to use for temporal smoothing of microstate
%   assignments. Use 0 to skip temporal smoothing. Ignored if fitting only
%   on GFP peaks.
%   -> Command line equivalent: "FitPar.b"
%
%   "Non-Smoothness penality"
%   -> Penalty for non-smoothness in the temporal smoothing algorithm.
%   Ignored if fitting only on GFP peaks.
%   -> Command line equivalent: "FitPar.lambda"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Array of set indices of ALLEEG for which new sets containg temporal
%   dynamics representations will be generated. If not provided, a GUI will
%   appear to select sets.
%
% Key, Value inputs (optional):
%
%   "FitPar"
%   -> Structure containing fields specifying parameters for backfitting.
%   If some required fields are not included, a GUI will appear with the
%   unincluded fields. Required fields:
%       "FitPar.nClasses"
%       -> Number of classes to use for backfitting
%
%       "FitPar.PeakFit"
%       -> 1 = backfit maps only at global field power peaks and
%       interpolate in between, 0 = backfit maps at all timepoints
%
%       "FitPar.BControl"
%       -> 1 = Remove microstate assignments around boundary events in the
%       EEG data, 0 = keep all microstate assignments
%
%       "FitPar.b"
%       -> Window size in ms to use for temporal smoothing of microstate
%       assignments. Use 0 to skip temporal smoothing. Ignored if fitting
%       only on GFP peaks.
%
%       "FitPar.lambda"
%       > Penalty for non-smoothness in the temporal smoothing algorithm.
%       Ignored if fitting only on GFP peaks.
%
%   "TemplateSet"
%   -> Integer, string, or character vector specifying the template set
%   whose maps should be used for backfitting. Can be either the index of 
%   a mean set in ALLEEG, the name of a mean set in ALLEEG, the name of a 
%   published template set in the microstates/Templates folder, or "own" to
%   use each subject's own maps for backfitting. If not provided, a GUI 
%   will appear to select a template set.
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

function [EEGout, CurrentSet, com] = pop_GetMSDynamics(AllEEG, varargin)

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
    funcName = 'pop_GetMSDynamics';
    p.FunctionName = funcName;
    p.StructExpand = false;         % do not expand FitPar struct input into key, value args

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'FitPar', []);
    addParameter(p, 'TemplateSet', '', @(x) validateattributes(x, {'char', 'string', 'numeric'}, {}));
    
    parse(p, AllEEG, varargin{:});

    if isnumeric(p.Results.TemplateSet)
        validateattributes(p.Results.TemplateSet, {'numeric'}, {'integer', 'scalar', 'positive', '<=', numel(AllEEG)}, funcName, 'TemplateSet');
    else
        validateattributes(p.Results.TemplateSet, {'char', 'string'}, {'scalartext'});
    end

    SelectedSets = p.Results.SelectedSets;
    FitPar = p.Results.FitPar;
    TemplateSet = p.Results.TemplateSet;

    %% SelectedSets validation
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    isPublishedSet = arrayfun(@(x) matches(AllEEG(x).setname, {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableSets = find(and(and(and(and(~HasChildren, ~HasDyn), ~isEmpty), HasMS), ~isPublishedSet));
    
    if isempty(AvailableSets)
        errordlg2(['No valid sets for extracting dynamics found.'], 'Obtain microstate dynamics error');
        return;
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets);
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['Dynamics cannot be extracted for the following sets: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, existing dynamics sets, ' ...
                'or sets without microstate maps.'];
            errordlg2(errorMessage, 'Obtain microstate dynamics error');
            return;
        end
    % Otherwise, add set selection gui elements
    else
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        if isempty(defaultSets);    defaultSets = 1;    end        
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        guiElements = [guiElements, ....
                    {{ 'Style', 'text'    , 'string', 'Choose sets for obtaining dynamics'}} ...
                    {{ 'Style', 'text'    , 'string', 'Use ctrlshift for multiple selection'}} ...
                    {{ 'Style', 'text'    , 'string', 'If multiple are chosen, new sets will be created for each with default names.'}} ...
                    {{ 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}];
        guiGeom  = [guiGeom  1 1 1 1];
        guiGeomV = [guiGeomV  1 1 1 4];
    end

    %% TemplateSet validation
    % If the user has provided a template set number or name, check its
    % validity
    meanSets = find(and(and(and(HasChildren, ~HasDyn), ~isEmpty), HasMS));
    meanSetnames = {AllEEG(meanSets).setname};
    [publishedSetnames, publishedDisplayNames, sortOrder] = getTemplateNames();
    TemplateIndex = 1;
    if ~isempty(TemplateSet)
        % If the template set is a number, make sure it is one of the
        % mean sets in ALLEEG
        if isnumeric(TemplateSet)
            if ~ismember(TemplateSet, meanSets)
                errorMessage = sprintf(['The specified template set number %i is not a valid mean set. ' ...
                    'Make sure you have not selected an individual set or a dynamics set.'], TemplateSet);
                errordlg2([errorMessage], 'Obtain microstate dynamics error');
                return;
            else
                TemplateMode = 'mean';
                TemplateIndex = find(ismember(meanSets, TemplateSet));
                TemplateName = meanSetnames{TemplateIndex};
            end
        % Else if the template set is a string, make sure it matches one of
        % the mean setnames, published template setnames, or "own"
        else
            if strcmpi(TemplateSet, 'own')
                TemplateMode = 'own';                           
            elseif matches(TemplateSet, publishedSetnames)
                TemplateMode = 'published';
                TemplateIndex = sortOrder(matches(publishedSetnames, TemplateSet));
                TemplateName = TemplateSet;
            elseif matches(TemplateSet, meanSetnames)
                % If there are multiple mean sets with the same name
                % provided, notify the suer
                if numel(find(matches(meanSetnames, TemplateSet))) > 1
                    errorMessage = sprintf(['There are multiple mean sets with the name "%s." ' ...
                        'Please specify the set number instead ot the set name.'], TemplateSet);
                    errordlg2([errorMessage], 'Obtain microstate dynamics error');
                    return;
                else
                    TemplateMode = 'mean';
                    TemplateIndex = find(matches(meanSetnames, TemplateSet));
                    TemplateName = TemplateSet;
                    TemplateSet = meanSets(TemplateIndex);
                end
            else
                errorMessage = sprintf(['The specified template set "%s" could not be found in the ALLEEG ' ...
                    'mean sets or in the microstates/Templates folder.'], TemplateSet);
                errordlg2([errorMessage], 'Obtain microstate dynamics error');
                return;
            end
        end

    % Otherwise, add template set selection gui elements
    else
        combinedSetnames = ['Own' meanSetnames publishedDisplayNames];
        guiElements = [guiElements ...
            {{ 'Style', 'text', 'string', 'Name of template set', 'fontweight', 'bold'}} ...
            {{ 'Style', 'popupmenu', 'string', combinedSetnames, 'tag', 'TemplateIndex', 'Value', TemplateIndex }}];
        guiGeom = [guiGeom 1 1];
        guiGeomV = [guiGeomV 1 1];
    end

    %% Prompt user to choose SelectedSets and TemplateSet if necessary
    if ~isempty(guiElements)
        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Obtain microstate activation time series');

        if isempty(res); return; end
        
        if isfield(outstruct, 'SelectedSets')
            SelectedSets = AvailableSets(outstruct.SelectedSets);
        end

        if isfield(outstruct, 'TemplateIndex')
            if outstruct.TemplateIndex == 1
                TemplateMode = 'own';
            elseif outstruct.TemplateIndex <= numel(meanSetnames)+1
                TemplateMode = 'mean';
                TemplateIndex = outstruct.TemplateIndex - 1;
                TemplateSet = meanSets(TemplateIndex);
                TemplateName = meanSetnames{TemplateIndex};
            else
                TemplateMode = 'published';
                TemplateIndex = outstruct.TemplateIndex - numel(meanSetnames) - 1;
                TemplateSet = publishedSetnames{TemplateIndex};
                TemplateName = TemplateSet;
                TemplateIndex = sortOrder(TemplateIndex);
            end
        end
    end

    if numel(SelectedSets) < 1
        errordlg2('You must select at least one set of microstate maps','Obtain microstate dynamics error');
        return;
    end

    if strcmp(TemplateMode, 'published')
        ChosenTemplate = MSTEMPLATE(TemplateIndex);
    elseif strcmp(TemplateMode, 'mean')
        ChosenTemplate = AllEEG(meanSets(TemplateIndex));
    end

    %% Verify compatibility between selected sets and template set
    % If the template set chosen is a mean set, make sure it is a parent
    % set of all the selected sets
    if strcmp(TemplateMode, 'mean')
        warningSetnames = {};
        for index = 1:length(SelectedSets)
            sIndex = SelectedSets(index);
            containsChild = checkSetForChild(AllEEG, meanSets(TemplateIndex), AllEEG(sIndex).setname);
            if ~containsChild
                warningSetnames = [warningSetnames, AllEEG(sIndex).setname];
            end
        end

        if ~isempty(warningSetnames) && guiOpts.showGetWarning
            txt = sprintf('%s, ', warningSetnames{:});
            txt = txt(1:end-2);
            warningMessage = sprintf(['Template set "%s" is not the parent set of ' ...
                'the following sets: %s. Are you sure you would like to proceed?'], ...
                TemplateName, txt);
            [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Obtain microstate dynamics warning');
            if boxChecked;  guiOpts.showGetWarning = false;     end
            if ~yesPressed; return;                             end
        end
    end

    %% Validate and get FitPar
    if strcmp(TemplateMode, 'own')
        AllMinClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MinClasses, SelectedSets);
        AllMaxClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MaxClasses, SelectedSets);
        MinClasses = max(AllMinClasses);
        MaxClasses = min(AllMaxClasses);
        if MaxClasses < MinClasses
            errorMessage = ['No overlap in microstate classes found between all selected sets.'];
            errordlg2(errorMessage, 'Obtain microstate dynamics error');
        end

        GFPPeaks = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.GFPPeaks, SelectedSets);
        PeakFit = all(GFPPeaks == 1);
    else
        MinClasses = ChosenTemplate.msinfo.ClustPar.MinClasses;
        MaxClasses = ChosenTemplate.msinfo.ClustPar.MaxClasses;

        PeakFit = ChosenTemplate.msinfo.ClustPar.GFPPeaks;
    end

    FitPar = SetFittingParameters(MinClasses:MaxClasses, FitPar, funcName, PeakFit, true);
    if isempty(FitPar);  return; end

    %% Obtain dynamics
    for index=1:length(SelectedSets)
        sIndex = SelectedSets(index);

        if strcmp(TemplateMode, 'own')
            msinfo = AllEEG(sIndex).msinfo;
        else
            msinfo = ChosenTemplate.msinfo;
        end
        Maps = msinfo.MSMaps(FitPar.nClasses).Maps;

        Labels = [];  
        if isfield(msinfo.MSMaps(FitPar.nClasses),'Labels')
            Labels = msinfo.MSMaps(FitPar.nClasses).Labels;
        end

        if ~strcmp(TemplateMode, 'own')
            [LocalToGlobal, GlobalToLocal] = MakeResampleMatrices(AllEEG(sIndex).chanlocs,ChosenTemplate.chanlocs);
            if AllEEG(sIndex).nbchan > ChosenTemplate.nbchan
                [MSClass, gfp, fit] = AssignMStates(AllEEG(sIndex), Maps, FitPar, msinfo.ClustPar.IgnorePolarity, LocalToGlobal);
            else
                Maps = Maps*GlobalToLocal';
                [MSClass, gfp, fit] = AssignMStates(AllEEG(sIndex), Maps, FitPar, msinfo.ClustPar.IgnorePolarity);
            end
        else
            [MSClass, gfp, fit] = AssignMStates(AllEEG(sIndex), Maps, FitPar, msinfo.ClustPar.IgnorePolarity);
        end

        if isempty(MSClass);    return; end

        newEEG(index) = AllEEG(sIndex);
        newEEG(index).setname = [AllEEG(sIndex).setname '_dynamics'];
        newEEG(index).nbchan = FitPar.nClasses;
        newEEG(index).msinfo.FitPar = FitPar;
        % replace msinfo.MSMaps with only the relevant maps
        newEEG(index).msinfo.MSMaps(1:end) = [];
        newEEG(index).msinfo.MSMaps(FitPar.nClasses) = AllEEG(sIndex).msinfo.MSMaps(FitPar.nClasses);
        % add dynamics info
        newEEG(index).msinfo.DynamicsInfo.TemplateMode = TemplateMode;
        if ~strcmp(TemplateMode, 'own')
            newEEG(index).msinfo.DynamicsInfo.FittingTemplate = TemplateName;
        end

        newData = zeros(FitPar.nClasses, AllEEG(sIndex).pnts, AllEEG(sIndex).trials);

        for class=1:FitPar.nClasses
            if isempty(Labels)
                ChanName = sprintf('MS_%i.%i', FitPar.nClasses, class);
            else
                ChanName = Labels{class};
            end
            
            chanlocs(class) = struct('labels',ChanName,'type','','theta', nan,'radius',nan,'X',nan,'Y',nan,'Z',nan,'sph_theta',nan,'sph_phi',nan,'sph_radius',nan,'urchan',nan,'ref','none');

            for s=1:AllEEG(sIndex).trials
                assigned = MSClass(:,s) == class;
                if FitPar.Normalize
                    newData(class, :, s) = assigned;
                else
                    if ~strcmp(TemplateMode, 'own')
                        if AllEEG(sIndex).nbchan > ChosenTemplate.nbchan
                            newData(class, assigned, s) = Maps(class, :)*(LocalToGlobal*AllEEG(sIndex).data(:, assigned, s));
                        else
                            newData(class, assigned, s) = Maps(class, :)*AllEEG(sIndex).data(:, assigned, s);
                        end
                    else
                        newData(class, assigned, s) = Maps(class, :)*AllEEG(sIndex).data(:, assigned, s);
                    end
                    if FitPar.Rectify
                        newData(class, assigned, s) = abs(newData(class, assigned, s));
                    end
                end
            end

            newEEG(index).chanlocs = chanlocs;
            newEEG(index).data = newData;
        end
    end

    EEGout = newEEG;
    CurrentSet = numel(AllEEG);     % update CurrentSet so new datasets will be appended to the end of ALLEEG

    if ischar(TemplateSet) || isstring(TemplateSet)
        com = sprintf('[EEG, CURRENTSET, com] = pop_GetMSDynamics(%s, %s, ''FitPar'', %s, ''TemplateSet'', ''%s'');', inputname(1), mat2str(SelectedSets), struct2String(FitPar), TemplateSet);
    elseif isnumeric(TemplateSet)
        com = sprintf('[EEG, CURRENTSET, com] = pop_GetMSDynamics(%s, %s, ''FitPar'', %s, ''TemplateSet'', %i);', inputname(1), mat2str(SelectedSets), struct2String(FitPar), TemplateSet);
    end

end

function [TemplateNames, DisplayNames, sortOrder] = getTemplateNames()
    global MSTEMPLATE;
    TemplateNames = {MSTEMPLATE.setname};
    minClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MinClasses, 1:numel(MSTEMPLATE));
    maxClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MaxClasses, 1:numel(MSTEMPLATE));
    [minClasses, sortOrder] = sort(minClasses, 'ascend');
    maxClasses = maxClasses(sortOrder);
    classRangeTxt = string(minClasses);
    diffMaxClasses = maxClasses ~= minClasses;
    classRangeTxt(diffMaxClasses) = sprintf('%s - %s', classRangeTxt(diffMaxClasses), string(maxClasses(diffMaxClasses)));
    TemplateNames = TemplateNames(sortOrder);
    nSubjects = arrayfun(@(x) MSTEMPLATE(x).msinfo.MetaData.nSubjects, sortOrder);
    nSubjects = arrayfun(@(x) sprintf('n=%i', x), nSubjects, 'UniformOutput', false);
    DisplayNames = strcat(classRangeTxt, " maps - ", TemplateNames, " - ", nSubjects);
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

function containsChild = checkSetForChild(AllEEG, SetsToSearch, childSetName)
    containsChild = false;
    if isempty(SetsToSearch)
        return;
    end
    
    % find which sets have children
    HasChildren = arrayfun(@(x) isfield(AllEEG(x).msinfo, 'children'), SetsToSearch);
    % if none of the sets to search have children, the child set could not
    % be found
    if ~any(HasChildren)
        return;
    end

    % search the children of all the mean sets for the child set name
    containsChild = any(arrayfun(@(x) matches(childSetName, AllEEG(x).msinfo.children), SetsToSearch(HasChildren)));

    % if the child cannot be found, search the children of the children
    if ~containsChild
        childSetIndices = unique(cell2mat(arrayfun(@(x) find(matches({AllEEG.setname}, AllEEG(x).msinfo.children)), SetsToSearch(HasChildren), 'UniformOutput', false)));
        containsChild = checkSetForChild(AllEEG, childSetIndices, childSetName);
    end

end