% pop_QuantMSTemplates() Quantifies the temporal dynamics of microstates in
% the EEG data. Generates a window with summary statistics for tepmoral
% dynamics extracted, along with a table of temporal dynamics statistics
% for all sets chosen for analysis. Statistics are saved to the "stats"
% field of "msinfo" and can be saved to a csv, txt, xlsx, 4R, or mat file.
%
% Usage:
%   >> [EEG, CURRENTSET, com] = pop_QuantMSTemplates(ALLEEG, SelectedSets, 
%       'key1', value1, 'key2', value2)
%
% To use each subject's own microstate maps for backfitting, specify
% "TemplateSet" as "own."
% Ex:
%   >> [EEG, CURRENTSET] = pop_QuantMSTemplates(ALLEEG, 1:5, 'TemplateSet',
%       'own')
%
% To use a mean set or published set for backfitting, specify either the
% index of the mean set in ALLEEG, the name of the mean set, or the name of
% the published set.
% Ex:
%   >> [EEG, CURRENTSET] = pop_QuantMSTemplates(ALLEEG, 1:5, 'TemplateSet',
%       'Koenig2002')
%
% To generate and save temporal dynamics statistics without displaying the
% GUI, use the "Filename" and "gui" parameters.
% Ex:
%   >> [EEG, CURRENTSET] = pop_QuantMSTemplates(ALLEEG, 1:5, 'TemplateSet',
%       'own', 'Filename', 'microstate/results/temporal_dynamics.csv',
%       'gui', 0)
%
% Graphical interface:
%
%   "Choose sets for quantifying"
%   -> Select sets to extract temporal dynamics for
%   -> Command line equivalent: "SelectedSets"
%
%   "Name of template set"
%   -> Name of template set whose maps will be used for backfitting and
%   extracting temporal dynamics. Select "Own" to use each subject's own
%   maps to quantify their own data, or select the name of a template set
%   to use its maps to quantify all subjects.
%   -> Command line equivalent: "TemplateSet"
%
%   "Show data visualizations"
%   -> Controls whether to generate figure with summary of extracted
%   temporal dynamics statistics. Uncheck this if you want to skip the
%   visualizations and save the results to a file.
%   -> Command line equivalent: "gui"
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
%   -> Array of set indices of ALLEEG for which temporal dynamics will be
%   extracted. If not provided, a GUI will appear to choose sets.
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
%   "Filename"
%   -> Full csv, txt, xlsx, 4R, or mat filename to save the generated table
%   of temporal dynamics statistics for all sets chosen for analysis. If
%   provided, the function will automatically save the statistics rather
%   than prompting for a filename. Useful for scripting purposes.
%
%   "gui"
%   -> 1 = show GUI with summary statistics of temporal dynamics, 0 = do
%   not show GUI. Useful for scripting purposes, e.g. if the function is
%   being used to generate and save statistics and the GUI is not necessary
%   -> Default = 1
%
% Outputs:
%
%   "EEG" 
%   -> EEG structure array of selected sets with temporal dynamics
%   statistics added to the "msinfo.stats" field. Fitting parameters in the
%   "msinfo.FitPar" field may also be updated.
% 
%   "CURRENTSET"
%   -> The indices of the EEGs selected for quantification
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

function [EEGout, CurrentSet, com, EpochData] = pop_QuantMSTemplates(AllEEG, varargin)

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
    funcName = 'pop_QuantMSTemplates';
    p.FunctionName = funcName;
    p.StructExpand = false;         % do not expand FitPar struct input into key, value args

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'FitPar', []);
    addParameter(p, 'TemplateSet', '', @(x) validateattributes(x, {'char', 'string', 'numeric'}, {}));
    addParameter(p, 'Filename', '', @(x) validateattributes(x, {'char', 'string'}, {'scalartext'}));
    addParameter(p, 'gui', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    
    parse(p, AllEEG, varargin{:});

    if isnumeric(p.Results.TemplateSet)
        validateattributes(p.Results.TemplateSet, {'numeric'}, {'integer', 'scalar', 'positive', '<=', numel(AllEEG)}, funcName, 'TemplateSet');
    else
        validateattributes(p.Results.TemplateSet, {'char', 'string'}, {'scalartext'});
    end

    SelectedSets = p.Results.SelectedSets;
    FitPar = p.Results.FitPar;
    TemplateSet = p.Results.TemplateSet;
    FileName = p.Results.Filename;
    showGUI = p.Results.gui;

    %% SelectedSets validation
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(and(and(and(~HasChildren, ~HasDyn), ~isEmpty), HasMS));
    
    if isempty(AvailableSets)
        errordlg2(['No valid sets for quantifying found.'], 'Quantify microstates error');
        return;
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets);
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['The following sets cannot be quantified: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, dynamics sets, ' ...
                'or sets without microstate maps.'];
            errordlg2(errorMessage, 'Quantify microstates error');
            return;
        end
    % Otherwise, add set selection gui elements
    else
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        guiElements = [guiElements, ....
                    {{ 'Style', 'text'    , 'string', 'Choose sets for quantifying'}} ...
                    {{ 'Style', 'text'    , 'string', 'Use ctrlshift for multiple selection'}} ...
                    {{ 'Style', 'text'    , 'string', 'If one is chosen, individual stats will be displayed.'}} ...
                    {{ 'Style', 'text'    , 'string', 'If multiple are chosen, aggregate stats will be displayed.'}} ...
                    {{ 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}];
        guiGeom  = [guiGeom  1 1 1 1 1];
        guiGeomV = [guiGeomV  1 1 1 1 4];
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
                errordlg2([errorMessage], 'Quantify microstates error');
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
                    errordlg2([errorMessage], 'Quantify microstates error');
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
                errordlg2([errorMessage], 'Quantify microstates error');
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
        % If gui is being displayed, add option to show/hide GUI
        if contains('gui', p.UsingDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'text', 'string', ''}} ...
                {{ 'Style', 'checkbox', 'string','Show data visualizations','tag','showGUI','Value', showGUI}}];
            guiGeom = [guiGeom 1 1];
            guiGeomV = [guiGeomV 1 1];
        end

        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Quantify microstates');

        if isempty(res); return; end
        
        if isfield(outstruct, 'SelectedSets')
            SelectedSets = AvailableSets(outstruct.SelectedSets);
        end

        if isfield(outstruct, 'TemplateIndex')
            if outstruct.TemplateIndex == 1
                TemplateMode = 'own';
                TemplateSet = 'own';
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

        if isfield(outstruct, 'showGUI')
            showGUI = outstruct.showGUI;
        end
    end

    if numel(SelectedSets) < 1
        errordlg2('You must select at least one set of microstate maps','Quantify microstates error');
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

        if ~isempty(warningSetnames) && guiOpts.showQuantWarning1
            txt = sprintf('%s, ', warningSetnames{:});
            txt = txt(1:end-2);
            warningMessage = sprintf(['Template set "%s" is not the parent set of ' ...
                'the following sets: %s. Are you sure you would like to proceed?'], ...
                TemplateName, txt);
            [yesPressed, boxChecked] = warningDialog(warningMessage, 'Quantify microstates warning');
            if boxChecked;  guiOpts.showQuantWarning1 = false;     end
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
            errordlg2(errorMessage, 'Quantify microstates error');
            return;
        end
    else
        MinClasses = ChosenTemplate.msinfo.ClustPar.MinClasses;
        MaxClasses = ChosenTemplate.msinfo.ClustPar.MaxClasses;
    end

    FitPar = SetFittingParameters(MinClasses:MaxClasses, FitPar, funcName);
    if isempty(FitPar);  return; end

    %% Check for consistent sorting across selected sets if own templates are being used
    SelectedEEG = AllEEG(SelectedSets);
    if strcmp(TemplateMode, 'own')
        % First check if any datasets remain unsorted
        noSort = false;
        SortModes = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(FitPar.nClasses).SortMode, 1:numel(SelectedEEG), 'UniformOutput', false);
        if any(strcmp(SortModes, 'none')) && guiOpts.showQuantWarning2
            warningMessage = ['Some datasets remain unsorted. Would you like to ' ...
                'sort all sets according to the same template before proceeding?'];
            [yesPressed, noPressed, boxChecked] = warningDialog(warningMessage, 'Quantify microstates warning');
            noSort = noPressed;
            if boxChecked;  guiOpts.showQuantWarning2 = false;  end
            if yesPressed
                [SelectedEEG, CurrentSet, sortCom] = pop_SortMSTemplates(AllEEG, SelectedSets, 'Classes', FitPar.nClasses);
                if isempty(sortCom);    return; end
                if isempty(com)
                    com = sortCom;
                else
                    com = [com newline sortCom];
                end
            elseif ~noPressed
                return;
            end
        end

        % Then check if there is inconsistency in sorting across datasets
        noSameSort = false;
        SortedBy = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(FitPar.nClasses).SortedBy, 1:numel(SelectedEEG), 'UniformOutput', false);
        emptyIdx = arrayfun(@(x) isempty(SortedBy{x}), 1:numel(SortedBy));
        SortedBy(emptyIdx) = [];
        if any(contains(SortedBy, '->'))
            multiSortedBys = cellfun(@(x) x(1:strfind(x, '->')-1), SortedBy(contains(SortedBy, '->')), 'UniformOutput', false);
            SortedBy(contains(SortedBy, '->')) = multiSortedBys;
        end
        if ~noSort && numel(unique(SortedBy)) > 1 && guiOpts.showQuantWarning3
            warningMessage = ['Sorting information differs across datasets. Would you like to ' ...
                'sort all sets according to the same template before proceeding?'];
            [yesPressed, noPressed, boxChecked] = warningDialog(warningMessage, 'Quantify microstates warning');
            noSameSort = noPressed;
            if boxChecked;  guiOpts.showQuantWarning3 = false;  end
            if yesPressed
                [SelectedEEG, CurrentSet, sortCom] = pop_SortMSTemplates(AllEEG, SelectedSets, 'Classes', FitPar.nClasses);
                if isempty(sortCom);    return; end
                if isempty(com)
                    com = sortCom;
                else
                    com = [com newline sortCom];
                end
            elseif ~noPressed
                return;
            end
        end

        % Check for unassigned labels
        Colors = cell2mat(arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(FitPar.nClasses).ColorMap, 1:numel(SelectedEEG), 'UniformOutput', false)');
        if ~noSort && any(arrayfun(@(x) all(Colors(x,:) == [.75 .75 .75]), 1:size(Colors,1))) && guiOpts.showQuantWarning4
            warningMessage = ['Some maps do not have assigned labels. For all maps to be assigned a label, each set must either be ' ...
                'manually sorted and assigned new labels, or sorted by a template set with equal (ideally) or greater number of maps. Would you like ' ...
                'to re-sort before proceeding?'];
            [yesPressed, noPressed, boxChecked] = warningDialog(warningMessage, 'Quantify microstates warning');
            if boxChecked;  guiOpts.showQuantWarning4 = false;   end
            if yesPressed
                [SelectedEEG, CurrentSet, sortCom] = pop_SortMSTemplates(AllEEG, SelectedSets, 'Classes', FitPar.nClasses);
                if isempty(sortCom);    return; end
                if isempty(com)
                    com = sortCom;
                else
                    com = [com newline sortCom];
                end
            elseif ~noPressed
                return;
            end
        end

        % Check for consistent labels 
        AllLabels = {};
        for set=1:numel(SelectedEEG)                 
            AllLabels = [AllLabels SelectedEEG(set).msinfo.MSMaps(FitPar.nClasses).Labels];
        end 
        if ~noSort && ~noSameSort && numel(unique(AllLabels)) > FitPar.nClasses && guiOpts.showQuantWarning5
            warningMessage = ['Map labels are inconsistent across cluster solutions. This can occur when sorting is performed using a ' ...
                'template set with a greater number of maps than the solution being sorted. To achieve consistency, maps should ideally be manually sorted ' ...
                'and assigned the same set of labels, or sorted using a template set with an equal number of maps. Would you like to re-sort before proceeding?'];
            [yesPressed, noPressed, boxChecked] = warningDialog(warningMessage, 'Quantify microstates warning');
            if boxChecked;  guiOpts.showQuantWarning5 = false;   end
            if yesPressed
                [SelectedEEG, CurrentSet, sortCom] = pop_SortMSTemplates(AllEEG, SelectedSets, 'Classes', FitPar.nClasses);
                if isempty(sortCom);    return; end
                if isempty(com)
                    com = sortCom;
                else
                    com = [com newline sortCom];
                end
            elseif ~noPressed
                return;
            end
        end
    end

    if isfield(FitPar,'SingleEpochFileTemplate')
        SingleEpochFileTemplate = FitPar.SingleEpochFileTemplate;
    else 
        SingleEpochFileTemplate = [];
    end

    %% Quantify
    h = waitbar(0, sprintf('Working on %s', SelectedEEG(1).setname), 'Name', 'Quantifying microstates, please wait...');
    for s = 1:numel(SelectedSets)
        waitbar((s-1) / numel(SelectedSets),h,sprintf('Working on %s',SelectedEEG(s).setname));

        % Get dataset information
        DataInfo.subject   = SelectedEEG(s).subject;
        DataInfo.group     = SelectedEEG(s).group;
        DataInfo.condition = SelectedEEG(s).condition;
        DataInfo.setname   = SelectedEEG(s).setname;

        SelectedEEG(s).msinfo.FitPar = FitPar;

        if strcmp(TemplateMode, 'own')
            msinfo = SelectedEEG(s).msinfo;
        else
            msinfo = ChosenTemplate.msinfo;
        end
        Maps = NormDimL2(msinfo.MSMaps(FitPar.nClasses).Maps, 2);
        
        if strcmp(TemplateMode, 'own')
            [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,FitPar,msinfo.ClustPar.IgnorePolarity);
            if ~isempty(MSClass)
                [MSStats(s), SSEpochData] = QuantifyMSDynamics(MSClass,gfp,SelectedEEG(s).msinfo,SelectedEEG(s).srate, DataInfo, [], IndGEVs, SingleEpochFileTemplate);
            end
        else
            [LocalToGlobal, GlobalToLocal] = MakeResampleMatrices(SelectedEEG(s).chanlocs,ChosenTemplate.chanlocs);
            if any(isnan(LocalToGlobal(:)))
                errordlg2(['Set ' SelectedEEG(s).setname ' does not have all channel positions defined'],'Quantify microstates error');
                return;
            end
            if SelectedEEG(s).nbchan > ChosenTemplate.nbchan
                [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,FitPar, msinfo.ClustPar.IgnorePolarity, LocalToGlobal);
            else
                Maps = Maps*GlobalToLocal';
                [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,FitPar, msinfo.ClustPar.IgnorePolarity);
            end
            if ~isempty(MSClass)
                [MSStats(s), SSEpochData] = QuantifyMSDynamics(MSClass,gfp,SelectedEEG(s).msinfo,SelectedEEG(s).srate, DataInfo, TemplateName, IndGEVs, SingleEpochFileTemplate);
            end
        end
        SelectedEEG(s).msinfo.stats = MSStats(s);
        EpochData(s) = SSEpochData;
    end
    close(h);

    % Set labels for output
    Labels = arrayfun(@(x) sprintf('MS %i.%i', FitPar.nClasses, x), 1:FitPar.nClasses, 'UniformOutput', false);

    %% Show GUI with summary statistics
    if showGUI
        if numel(SelectedSets) == 1
            figName = ['Microstates statistics summary: ' SelectedEEG.setname];
            x = categorical(Labels);
            x = reordercats(x, Labels);
        else
            figName = 'Microstates statistics summary';
            x = repmat(Labels, 1, numel(SelectedSets));
            x = categorical(x, Labels);
        end
        
        if isempty(FileName)
            statsFig = figure('Name', figName, 'WindowStyle', 'modal', 'NumberTitle', 'off', ...
            'Position', [100 100 1350 600]);
            statsFig.CloseRequestFcn = 'uiresume();';
            statsFig.UserData.FileName = '';
            plotsPanel = uipanel(statsFig, 'Units', 'normalized', 'Position', [0 0.1 1 0.9]);
            uicontrol('Style', 'pushbutton', 'String', 'Export microstate statistics', ...
                'Units', 'normalized', 'Position', [.42 .02 .16 .06], ...
                'Callback', {@outputStats, FileName, MSStats, Labels, statsFig});
        else
            statsFig = figure('Name', figName, 'NumberTitle', 'off', ...
            'Position', [100 100 1350 600]);
            plotsPanel = uipanel(statsFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1], 'BorderType', 'none');
        end
        
        t = tiledlayout(plotsPanel, 2, 3);
        t.TileSpacing = 'tight';
        t.Padding = 'compact';
    
        % GEV
        gevAx = nexttile(t, 1);
        if numel(SelectedSets) == 1
            bar(gevAx, x, MSStats.IndExpVar*100);
        else
            IndGEVs = cell2mat(arrayfun(@(x) MSStats(x).IndExpVar*100, 1:numel(SelectedSets), 'UniformOutput', false));
            swarmchart(gevAx, x, IndGEVs, 25, [0 0.4470 0.7410],'filled');
        end
        title(gevAx, 'Explained Variance (%)');
    
        % Duration
        durAx = nexttile(t, 2);
        if numel(SelectedSets)  == 1
            bar(durAx, x, MSStats.Duration*1000);
        else
            Durations = cell2mat(arrayfun(@(x) MSStats(x).Duration*1000, 1:numel(SelectedSets), 'UniformOutput', false));
            swarmchart(durAx, x, Durations, 25, [0 0.4470 0.7410],'filled');
        end
        title(durAx, 'Mean Duration (ms)');
    
        % Occurrence
        occAx = nexttile(t, 4);
        if numel(SelectedSets) == 1
            bar(occAx, x, MSStats.Occurrence);
        else
            Occurrences = cell2mat(arrayfun(@(x) MSStats(x).Occurrence, 1:numel(SelectedSets), 'UniformOutput', false));
            swarmchart(occAx, x, Occurrences, 25, [0 0.4470 0.7410],'filled');
        end
        title(occAx, 'Occurence (segments/s)');
    
        % Coverage
        covAx = nexttile(t, 5);
        if numel(SelectedSets) == 1
            bar(covAx, x, MSStats.Contribution*100);
        else
            Coverages = cell2mat(arrayfun(@(x) MSStats(x).Contribution*100, 1:numel(SelectedSets), 'UniformOutput', false));
            swarmchart(covAx, x, Coverages, 25, [0 0.4470 0.7410],'filled');
        end
        title(covAx, 'Coverage (%)');
    
        % GFP
    %     gfpAx = nexttile(t);
    %     if numel(SelectedSets) == 1
    %         bar(gfpAx, x, MSStats.MeanGFP);
    %     else
    %         GFPs = cell2mat(arrayfun(@(x) MSStats(x).MeanGFP, 1:numel(SelectedSets), 'UniformOutput', false));
    %         swarmchart(gfpAx, x, GFPs, 25, [0 0.4470 0.7410],'filled');
    %     end
    %     title(gfpAx, 'Mean GFP');
    
        % Transition matrix
        nexttile(t, 3);
        if numel(SelectedSets) == 1
            h = heatmap(t, Labels, Labels, MSStats.OrgTM, 'GridVisible', 'off');
            h.Title = 'Transition Matrix';
        else
            avgTM = zeros(FitPar.nClasses);
            for s=1:numel(SelectedSets)
                avgTM = avgTM + MSStats(s).OrgTM;
            end
            avgTM = avgTM/numel(SelectedSets);
            h = heatmap(t, Labels, Labels, avgTM, 'GridVisible', 'off');
            h.Title = 'Average Transition Matrix';
        end
        h.XLabel = 'To';
        h.YLabel = 'From';
    
        % Delta transition matrix
        nexttile(t, 6);
        if numel(SelectedSets) == 1
            h2 = heatmap(t, Labels, Labels, MSStats.DeltaTM, 'GridVisible', 'off');
            h2.Title = 'Delta Transition Matrix';
        else
            avgTM = zeros(FitPar.nClasses);
            for s=1:numel(SelectedSets)
                avgTM = avgTM + MSStats(s).DeltaTM;
            end
            avgTM = avgTM/numel(SelectedSets);
            h2 = heatmap(t, Labels, Labels, avgTM, 'GridVisible', 'off');
            h2.Title = 'Average Delta Transition Matrix';
        end
        h2.XLabel = 'To';
        h2.YLabel = 'From';

        if isempty(FileName)
            uiwait(statsFig);
            FileName = statsFig.UserData.FileName;
            delete(statsFig);
        else
            FileName = outputStats([], [], FileName, MSStats, Labels);
        end
    else
        % Generate output file
        FileName = outputStats([], [], FileName, MSStats, Labels);
        if FileName == 0
            return;
        end
    end

    EEGout = SelectedEEG;
    CurrentSet = SelectedSets;

    if ischar(TemplateSet) || isstring(TemplateSet)
        quantCom = sprintf('[EEG, CURRENTSET, com] = pop_QuantMSTemplates(%s, %s, ''FitPar'', %s, ''TemplateSet'', ''%s'', ''FileName'', ''%s'', ''gui'', %i);', inputname(1), mat2str(SelectedSets), struct2String(FitPar), TemplateSet, FileName, showGUI);
    elseif isnumeric(TemplateSet)
        quantCom = sprintf('[EEG, CURRENTSET, com] = pop_QuantMSTemplates(%s, %s, ''FitPar'', %s, ''TemplateSet'', %i, ''FileName'', ''%s'', ''gui'', %i);', inputname(1), mat2str(SelectedSets), struct2String(FitPar), TemplateSet, FileName, showGUI);
    end

    if isempty(com)
        com = quantCom;
    else
        com = [com newline quantCom];
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

function FileName = outputStats(src, event, FileName, MSStats, Labels, fig)
    if isempty(FileName)
        [FName,PName,idx] = uiputfile({'*.csv','Comma separated file';'*.csv','Semicolon separated file';'*.txt','Tab delimited file';'*.mat','Matlab Table'; '*.xlsx','Excel file';'*.4R','Text file for R'},'Save microstate statistics');
        if FName == 0
            if nargin > 5
                fig.UserData.FileName = '';
                return;
            else
                FileName = 0;
                return;
            end
        end
        FileName = fullfile(PName,FName);
    else
        idx = 1;
        if contains(FileName,'.mat')
            idx = 4;
        end
        if contains(FileName,'.xls')
            idx = 5;
        end
        if contains(FileName,'.4R')
            idx = 6;
        end
    end

    if ~isempty(FileName)   
        switch idx
            case 1
                SaveStructToTable(MSStats,FileName,',',Labels);
            case 2
                SaveStructToTable(MSStats,FileName,';',Labels);
            case 3
                SaveStructToTable(MSStats,FileName,sprintf('\t'),Labels);
            case 4
                save(FileName,'MSStats');
            case 5
                writecell(SaveStructToTable(MSStats,[],[],Labels), FileName);
            case 6
                SaveStructToR(MSStats,FileName);
        end
    end

    if nargin > 5
        src.Enable = 'off';
        fig.UserData.FileName = FileName;
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