% pop_FitMSMaps() Backfits template maps to EEG and extracts temporal
% parameters. Temporal dynamics parameters for each subject are saved to 
% the "MSStats" field of "msinfo" in the corresponding EEG set.
%
% Usage:
%   >> [EEG, CURRENTSET] = pop_FitMSMaps(ALLEEG, SelectedSets, 'FitPar',
%       FitPar, 'TemplateSet', TemplateSet)
%
% To use each dataset's own microstate maps for backfitting, specify
% "TemplateSet" as "own."
% Ex:
%   >> [EEG, CURRENTSET] = pop_FitMSMaps(ALLEEG, 1:5, 'TemplateSet', 
%       'own')
%
% To use a mean set or published set for backfitting, specify either the
% index of the mean set in ALLEEG, the name of the mean set, or the name of
% the published set.
% Ex:
%   >> [EEG, CURRENTSET] = pop_FitMSMaps(ALLEEG, 1:5, 'TemplateSet', 
%       'Koenig2002')
%
% Graphical interface:
%
%   "Choose sets for backfitting"
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
%   "Microstate fitting parameters"
%   ------------------------------
%
%   "Number of classes"
%   -> Which cluster solutions to use for backfitting
%   -> Command line equivalent: "FitPar.Classes"
%
%   "Label smoothing window"
%   -> Window size in ms to use for temporal smoothing of microstate
%   assignments. Use 0 to skip temporal smoothing. Will not appear if
%   datasets selected for backfitting were clustered only on GFP peaks.
%   -> Command line equivalent: "FitPar.b"
%
%   "Non-Smoothness penality"
%   -> Penalty for non-smoothness in the temporal smoothing algorithm.
%   Will not appear if datasets selected for backfitting were clustered
%   only on GFP peaks.
%   -> Command line equivalent: "FitPar.lambda"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Vector of set indices of ALLEEG for which temporal dynamics will be
%   extracted. Selected sets must be individual datasets (not group level 
%   or grand mean sets). If not provided, a GUI will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "FitPar"
%   -> Structure containing fields specifying parameters for backfitting.
%   If some required fields are not included, a GUI will appear with the
%   unincluded fields. FitPar fields include:
%       "FitPar.Classes"
%       -> Vectir of cluster solutions to use for backfitting
%
%       "FitPar.PeakFit"
%       -> 1 = backfit maps only at global field power peaks and
%       interpolate in between, 0 = backfit maps at all timepoints.
%       Recommended to backfit maps to GFP peaks if maps were clustered
%       using only GFP peaks, and to backfit maps at all timepoints if maps
%       clustered using all timepoints.
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
%   -> EEG structure array of selected sets with temporal dynamics
%   parameters added to the "msinfo.MSStats" field. Fitting parameters in 
%   the "msinfo.FitPar" field or sorting information may also be updated.
% 
%   "CURRENTSET"
%   -> The indices of the EEGs selected for backfitting
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

function [EEGout, CurrentSet, com] = pop_FitMSMaps(AllEEG, varargin)

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
    p.FunctionName = 'pop_FitMSMaps';
    p.StructExpand = false;         % do not expand FitPar struct input into key, value args

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'FitPar', []);
    addParameter(p, 'TemplateSet', '', @(x) validateattributes(x, {'char', 'string', 'numeric'}, {}));
    
    parse(p, AllEEG, varargin{:});

    if isnumeric(p.Results.TemplateSet)
        validateattributes(p.Results.TemplateSet, {'numeric'}, {'integer', 'scalar', 'positive', '<=', numel(AllEEG)}, 'pop_FitMSMaps', 'TemplateSet');
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
    isPublished = arrayfun(@(x) isPublishedSet(AllEEG(x), {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableSets = find(HasMS & ~HasChildren & ~HasDyn & ~isPublished);
    
    if isempty(AvailableSets)
        errorMessage = ['No valid sets found for backfitting. Use ' ...
            '"Tools->Identify microstate maps per dataset" to find and store microstate map data.'];
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(errorMessage, 'Backfit microstate maps to EEG error');
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
            error(['The following sets cannot be backfit: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, dynamics sets, ' ...
                'or sets without microstate maps.']);
        end
    % Otherwise, add set selection gui elements
    else
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        if isempty(defaultSets);    defaultSets = 1;    end
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        guiElements = [guiElements, ....
                    {{ 'Style', 'text'    , 'string', 'Choose sets for backfitting', 'FontWeight', 'bold'}} ...
                    {{ 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'}} ...
                    {{ 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}];
        guiGeom  = [guiGeom  1 1 1];
        guiGeomV = [guiGeomV  1 1 4];
    end

    %% TemplateSet validation
    % If the user has provided a template set number or name, check its
    % validity
    meanSets = find(HasChildren & ~HasDyn);
    meanSetnames = {AllEEG(meanSets).setname};
    [publishedSetnames, publishedDisplayNames, sortOrder] = getTemplateNames();
    TemplateIndex = 1;
    if ~isempty(TemplateSet)        
        % If the template set is a number, make sure it is one of the
        % mean sets in ALLEEG
        if isnumeric(TemplateSet)
            if ~ismember(TemplateSet, meanSets)
                error(['The specified template set number %i is not a valid mean set. ' ...
                    'Make sure you have not selected an individual set or a dynamics set.'], TemplateSet);
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
                    error(['There are multiple mean sets with the name "%s." ' ...
                        'Please specify the set number instead ot the set name.'], TemplateSet);
                else
                    TemplateMode = 'mean';
                    TemplateIndex = find(matches(meanSetnames, TemplateSet));
                    TemplateName = TemplateSet;
                    TemplateSet = meanSets(TemplateIndex);
                end
            else
                error(['The specified template set "%s" could not be found in the ALLEEG ' ...
                    'mean sets or in the microstates/Templates folder.'], TemplateSet);
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
             'title','Backfit microstate maps');

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

        if numel(SelectedSets) < 1
            errordlg2('You must select at least one dataset','Backfit microstate maps to EEG error');
            return;
        end
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

        if ~isempty(warningSetnames)
            if matches('SelectedSets', p.UsingDefaults) && getpref('MICROSTATELAB', 'showFitWarning')
                warningMessage = sprintf(['Template set "%s" is not the parent set of ' ...
                    'the following sets. Are you sure you would like to proceed?'], TemplateName);
                [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Backfit microstate maps warning', warningSetnames);
                if boxChecked;  setpref('MICROSTATELAB', 'showFitWarning', 0);  end
                if ~yesPressed; return;                                         end
            else
                warningSetsTxt = sprintf(['%s' newline], string(warningSetnames));
                warning(['Template set "%s" is not the parent set of the following sets: ' newline warningSetsTxt], TemplateName);
            end
        end
    end

    %% Validate and get FitPar
    if strcmp(TemplateMode, 'own')
        AllMinClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MinClasses, SelectedSets);
        AllMaxClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MaxClasses, SelectedSets);
        MinClasses = max(AllMinClasses);
        MaxClasses = min(AllMaxClasses);
        if MaxClasses < MinClasses
            errorMessage = 'No overlap in microstate classes found between all selected sets.';
            if matches('SelectedSets', p.UsingDefaults)
                errordlg2(errorMessage, 'Backfit microstate maps to EEG error');
            else
                error(errorMessage);
            end
            return;
        end

        GFPPeaks = arrayfun(@(x) logical(AllEEG(x).msinfo.ClustPar.GFPPeaks), SelectedSets);
        IgnorePolarity = arrayfun(@(x) logical(AllEEG(x).msinfo.ClustPar.IgnorePolarity), SelectedSets);
        if ~(all(GFPPeaks == 1) || all(GFPPeaks == 0)) || ~(all(IgnorePolarity == 1) || all(IgnorePolarity == 0))
            errorMessage = ['Microstate clustering parameters differ between selected sets. Sets selected for backfitting should ' ...
                'have consistent parameters for ignoring polarity and clustering on GFP peaks.'];
            if matches('SelectedSets', p.UsingDefaults)
                errorDialog(errorMessage, 'Backfit microstate maps to EEG error');
                return;
            else
                warning(errorMessage);
                if ~(all(GFPPeaks == 1) || all(GFPPeaks == 0))
                    PeakFit = -1;
                else
                    PeakFit = all(GFPPeaks == 1);
                end
            end            
        else
            PeakFit = all(GFPPeaks == 1);
        end
    else
        MinClasses = ChosenTemplate.msinfo.ClustPar.MinClasses;
        MaxClasses = ChosenTemplate.msinfo.ClustPar.MaxClasses;

        PeakFit = ChosenTemplate.msinfo.ClustPar.GFPPeaks;
    end

    FitPar = SetFittingParameters(MinClasses:MaxClasses, FitPar, 'pop_FitMSMaps', PeakFit);
    if isempty(FitPar);  return; end

    %% Check for consistent sorting across selected sets if own templates are being used
    SelectedEEG = AllEEG(SelectedSets);

    if strcmp(TemplateMode, 'own')
        setnames = {SelectedEEG.setname};
        isEmpty = cellfun(@isempty,setnames);
        if any(isEmpty)
           setnames(isEmpty) = {''};
        end
        for c=FitPar.Classes
            % First check if any datasets remain unsorted
            SortModes = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(c).SortMode, 1:numel(SelectedEEG), 'UniformOutput', false);
            if matches('none', SortModes)
                unsortedSets = setnames(strcmp(SortModes, 'none'));
                if matches('SelectedSets', p.UsingDefaults)
                    errorDialog(sprintf('The %i cluster solutions of the following sets remain unsorted. Please sort all sets before proceeding.', c), ...
                        'Backfit microstate maps to EEG error', unsortedSets);
                    return;
                else
                    unsortedSetsTxt = sprintf(['%s' newline], string(unsortedSets));
                    error(['The %i cluster solutions of the following sets remain unsorted: ' newline unsortedSetsTxt ...
                            'Please sort all sets before proceeding.'], c);
                end
            end
    
            % Check for unassigned labels
            Colors = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(c).ColorMap, 1:numel(SelectedEEG), 'UniformOutput', false);
            unlabeled = cellfun(@(x) any(arrayfun(@(y) all(x(y,:) == [.75 .75 .75]), 1:size(x,1))), Colors);
            if any(unlabeled)
                unsortedSets = setnames(unlabeled);
                if matches('SelectedSets', p.UsingDefaults)
                    errorDialog(sprintf(['The %i cluster solutions of the following sets contain maps without assigned labels. ' ...
                        'For all maps to be assigned a label, each cluster solution must either be manually assigned labels, ' ...
                        'or sorted by a template solution with an equal or greater number of maps. Please sort maps accordingly before proceeding.'], c), ...
                        'Backfit microstate maps to EEG error', unsortedSets);
                    return;
                else
                    unsortedSetsTxt = sprintf(['%s' newline], string(unsortedSets));
                    error(['The %i cluster solutions of the following sets contain maps without assigned labels: ' newline unsortedSetsTxt ...
                        'For all maps to be assigned a label, each cluster solution must either be manually assigned labels, ' ...
                        'or sorted by a template solution with an equal or greater number of maps. Please sort maps accordingly before proceeding.'], c);
                end
            end
    
            % Check for consistent labels 
            labels = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(c).Labels, 1:numel(SelectedEEG), 'UniformOutput', false);
            labels = vertcat(labels{:});
            if any(arrayfun(@(x) numel(unique(labels(:,x))), 1:size(labels,2)) > 1)
                errorMessage = sprintf(['Map labels of the %i cluster solution are inconsistent across datasets. Please sort maps such that map labels are identical ' ...
                    'across all datasets before proceeding.'], c);
                if matches('SelectedSets', p.UsingDefaults)
                    errorDialog(errorMessage, 'Backfit microstate maps to EEG error');
                    return;
                else
                    error(errorMessage);
                end
            end        
        end
    
    % Otherwise check that the template set is sorted if using a mean set
    elseif strcmp(TemplateMode, 'mean')
        for c=FitPar.Classes
            if matches('none', ChosenTemplate.msinfo.MSMaps(c).SortMode)
                errorMessage = sprintf(['The %i cluster solution of template set "%s" remains unsorted. Please sort ' ...
                    'the template set before proceeding.'], c, ChosenTemplate.setname);
                if matches('TemplateSet', p.UsingDefaults)
                    errorDialog(errorMessage, 'Backfit microstate maps to EEG error');
                    return;
                else
                    error(errorMessage);
                end
            end

            if any(arrayfun(@(x) all(ChosenTemplate.msinfo.MSMaps(c).ColorMap(x,:) == [.75 .75 .75]), 1:c))
                errorMessage = sprintf(['The %i cluster solution of the template set "%s" contains maps without assigned labels. ' ...
                    'For all maps to be assigned a label, the cluster solution must either be manually assigned labels, ' ...
                    'or sorted by a template solution with an equal or greater number of maps. Please sort maps accordingly before proceeding.'], c, ChosenTemplate.setname);
                if matches('SelectedSets', p.UsingDefaults)
                    errorDialog(errorMessage, 'Backfit microstate maps to EEG error');
                    return;
                else
                    error(errorMessage);
                end
            end
        end
    end

    %% Backfit and compute temporal parameters
    h = waitbar(0, sprintf('Working on %s', SelectedEEG(1).setname), 'Name', 'Quantifying microstates, please wait...');
    h.Children.Title.Interpreter = 'none';
    for s = 1:numel(SelectedSets)
        waitbar((s-1) / numel(SelectedSets),h,sprintf('Working on %s',SelectedEEG(s).setname));       
                
        SelectedEEG(s).msinfo.FitPar = FitPar;

        for c=1:numel(FitPar.Classes)                        
            if strcmp(TemplateMode, 'own')
                msinfo = SelectedEEG(s).msinfo;
                TemplateInfo.name = '<<own>>';            
            else
                msinfo = ChosenTemplate.msinfo;
                TemplateInfo.name = ChosenTemplate.setname;
            end
            TemplateInfo.SortedBy = msinfo.MSMaps(FitPar.Classes(c)).SortedBy;
            TemplateInfo.TemplateLabels = msinfo.MSMaps(FitPar.Classes(c)).Labels;
            Maps = L2NormDim(msinfo.MSMaps(FitPar.Classes(c)).Maps, 2);
            
            if strcmp(TemplateMode, 'own')
                [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,FitPar,msinfo.ClustPar.IgnorePolarity);
            else
                [LocalToGlobal, GlobalToLocal] = MakeResampleMatrices(SelectedEEG(s).chanlocs,ChosenTemplate.chanlocs);
                if any(isnan(LocalToGlobal(:)))
                    if matches('SelectedSets', p.UsingDefaults)
                        errordlg2(['Set ' SelectedEEG(s).setname ' does not have all channel positions defined'],'Backfit microstate maps to EEG error');
                        return;
                    else
                        error(['Set ' SelectedEEG(s).setname ' does not have all channel positions defined']);
                    end
                end
                if SelectedEEG(s).nbchan > ChosenTemplate.nbchan
                    [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,FitPar, msinfo.ClustPar.IgnorePolarity, LocalToGlobal);
                else
                    Maps = Maps*GlobalToLocal';
                    [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,FitPar, msinfo.ClustPar.IgnorePolarity);
                end                
            end    

            if ~isempty(MSClass)
                MSStats(FitPar.Classes(c)) = QuantifyMSDynamics(MSClass,gfp,SelectedEEG(s).srate,TemplateInfo,IndGEVs);
            end
        end        
    
        SelectedEEG(s).msinfo.MSStats = MSStats;
    end
    close(h);

    EEGout = SelectedEEG;
    CurrentSet = SelectedSets;   

    if ischar(TemplateSet) || isstring(TemplateSet)
        fitCom = sprintf('[EEG, CURRENTSET] = pop_FitMSMaps(%s, %s, ''FitPar'', %s, ''TemplateSet'', ''%s'');', inputname(1), mat2str(SelectedSets), struct2String(FitPar), TemplateSet);
    elseif isnumeric(TemplateSet)
        fitCom = sprintf('[EEG, CURRENTSET] = pop_FitMSMaps(%s, %s, ''FitPar'', %s, ''TemplateSet'', ''%s'');', inputname(1), mat2str(SelectedSets), struct2String(FitPar), TemplateSet);
    end

    if isempty(com)
        com = fitCom;
    else
        com = [com newline fitCom];
    end

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

function isPublished = isPublishedSet(in, templateNames)
    isPublished = false;
    if isempty(in.setname)
        return;
    end

    if matches(in.setname, templateNames)
        isPublished = true;
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
        setnames = {AllEEG.setname};
        isEmpty = cellfun(@isempty,setnames);
        if any(isEmpty)
            setnames(isEmpty) = {''};
        end
        childSetIndices = unique(cell2mat(arrayfun(@(x) find(matches(setnames, AllEEG(x).msinfo.children)), SetsToSearch(HasChildren), 'UniformOutput', false)));
        containsChild = checkSetForChild(AllEEG, childSetIndices, childSetName);
    end

end