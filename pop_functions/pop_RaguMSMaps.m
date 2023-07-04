% pop_RaguMSMaps() Transfer microstate maps to Ragu for topographic testing
%
% Usage:
%   >> com = pop_RaguMSMaps(ALLEEG, SelectedSets, 'Classes', Classes)
%
% Graphical interface:
%
%   "Choose sets to export"
%   -> Select sets to export to Ragu
%   -> Command line equivalent: "SelectedSets"
%
%   "Select number of classes"
%   -> Select which cluster solution to export
%   -> Command line equivalent: "Classes"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Vector of set indices of ALLEEG to export. If not provided, a GUI
%   will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "Classes"
%   -> Integer indicating which cluster solutionto export from each of the 
%   selected sets. If not provided, a GUI will appear to select the number 
%   of classes to export.
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

function com = pop_RaguMSMaps(AllEEG, varargin)

    [~,nogui] = eegplugin_microstatelab;

    if nogui == true
        error("This function needs a GUI");
    end


    global MSTEMPLATE;
    com = '';

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_RaguMSMaps';

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));      

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    Classes = p.Results.Classes;

    %% SelectedSets validation
    % First make sure there are valid sets to export
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isPublished = arrayfun(@(x) isPublishedSet(AllEEG(x), {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableSets = find(HasMS & ~HasChildren & ~HasDyn & ~isPublished);
    
    if isempty(AvailableSets)
        errorMessage = ['No valid sets for topographic testing found. Use ' ...
            '"Tools->Identify microstate maps per dataset to find and store microstate map data'];
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(errorMessage, 'Export microstates to Ragu error');
            return;
        else
            error(errorMessage);
        end
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        % Check for empty sets, dynamics sets, or any sets without
        % microstate maps
        SelectedSets = unique(SelectedSets);
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error(['The following sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, dynamics sets, or sets ' ...
                'without microstate maps.']);
        end
    % Otherwise, prompt the user to select sets
    else
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        if isempty(defaultSets);    defaultSets = 1;    end        
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        [res, ~, ~, outstruct] = inputgui('geometry', {1 1 1}, 'geomvert', [1 1 4], 'uilist', { ...
                    { 'Style', 'text'    , 'string', 'Choose sets to export', 'FontWeight', 'bold'} ...
                    { 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'} ...
                    { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
                    'title', 'Export microstate maps to Ragu');
        
        if isempty(res);    return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);

        if numel(SelectedSets) < 1
            errordlg2('You must select at least one dataset','Export microstates to Ragu error');
            return;
        end
    end
    
    MinClasses = max(arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MinClasses, SelectedSets));
    MaxClasses = min(arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MaxClasses, SelectedSets));
    if MaxClasses < MinClasses
        errorMessage = 'No overlap in cluster solutions found between all selected sets.';
        if matches('SelectedSets', p.UsingDefaults)
            errordlg2(errorMessage, 'Export microstate maps to Ragu error');
            return;
        else
            error(errorMessage);
        end
    end
    if matches('Classes', p.UsingDefaults)
        classRange = MinClasses:MaxClasses;
        classChoices = sprintf('%i Classes|', classRange);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
            { {'Style', 'text', 'string', 'Select number of classes'} ...
              {'Style', 'listbox', 'string', classChoices, 'Min', 0, 'Max', 1, 'Tag', 'Classes'} }, ...
              'title', 'Export microstates to Ragu');
        
        if isempty(res); return; end

        Classes = classRange(outstruct.Classes);
    else
        if Classes < MinClasses || Classes > MaxClasses          
            error(['The specified number of classes %i is invalid.' ...
                ' Valid class numbers are in the range %i-%i.'], Classes, MinClasses, MaxClasses);
        end
    end

    %% Check for consistent sorting across datasets
    setnames = {AllEEG(SelectedSets).setname};
    isEmpty = cellfun(@isempty,setnames);
    if any(isEmpty)
        setnames(isEmpty) = {''};
    end
    % First check if any datasets remain unsorted
    SortModes = arrayfun(@(x) AllEEG(x).msinfo.MSMaps(Classes).SortMode, SelectedSets, 'UniformOutput', false);
    if matches('none', SortModes)
        unsortedSets = setnames(strcmp(SortModes, 'none'));
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(sprintf('The %i cluster solutions of the following sets remain unsorted. Please sort all sets before proceeding.', Classes), ...
                'Export microstates to Ragu error', unsortedSets);
            return;
        else
            unsortedSetsTxt = sprintf(['%s' newline], string(unsortedSets));
            error(['The %i cluster solutions of the following sets remain unsorted: ' newline unsortedSetsTxt ...
                    'Please sort all sets before proceeding.'], Classes);
        end
    end

    % Check for unassigned labels
    Colors = arrayfun(@(x) AllEEG(x).msinfo.MSMaps(Classes).ColorMap, SelectedSets, 'UniformOutput', false);
    unlabeled = cellfun(@(x) any(arrayfun(@(y) all(x(y,:) == [.75 .75 .75]), 1:size(x,1))), Colors);
    if any(unlabeled)
        unsortedSets = setnames(unlabeled);
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(sprintf(['The %i cluster solutions of the following sets contain maps without assigned labels. ' ...
                'For all maps to be assigned a label, each cluster solution must either be manually assigned labels, ' ...
                'or sorted by a template solution with an equal or greater number of maps. Please sort maps accordingly before proceeding.'], Classes), ...
                'Export microstates to Ragu error', unsortedSets);
            return;
        else
            unsortedSetsTxt = sprintf(['%s' newline], string(unsortedSets));
            error(['The %i cluster solutions of the following sets contain maps without assigned labels: ' newline unsortedSetsTxt ...
                'For all maps to be assigned a label, each cluster solution must either be manually assigned labels, ' ...
                'or sorted by a template solution with an equal or greater number of maps. Please sort maps accordingly before proceeding.'], Classes);
        end
    end

    % Check for consistent labels 
    labels = arrayfun(@(x) AllEEG(x).msinfo.MSMaps(Classes).Labels, SelectedSets, 'UniformOutput', false);
    labels = vertcat(labels{:});
    if any(arrayfun(@(x) numel(unique(labels(:,x))), 1:size(labels,2)) > 1)
        errorMessage = sprintf(['Map labels of the %i cluster solution are inconsistent across datasets. Please sort maps such that map labels are identical ' ...
            'across all datasets before proceeding.'], Classes);
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(errorMessage, 'Export microstates to Ragu error');
            return;
        else
            error(errorMessage);
        end
    end        

    rd = MsMapsAndDesign4Ragu(AllEEG(SelectedSets), Classes);
 %    rd = SaveMSMapsForRagu(AllEEG(SelectedSets), Classes);

    % Prompt user for within and between factors design
    inputGUI = figure("Name", "Export microstates to Ragu", "MenuBar", "none", "ToolBar", "none", ...
        "NumberTitle", "off", "Color", [.66 .76 1]);
    inputGUI.Position(3:4) = [420 180];
    inputGUI.UserData = rd;

    uicontrol(inputGUI, 'Style', 'Text', 'String', 'Define within subjects design', 'Position', [20 140 250 20], ...
        'FontSize', 12, 'BackgroundColor', [.66 .76 1], 'HorizontalAlignment', 'left');
    uicontrol(inputGUI, 'Style', 'pushbutton', 'String', 'Edit design', 'Position', [300 135 100 30], 'FontSize', 11, ...
        'Callback', @defineWithinDesign);
    uicontrol(inputGUI, 'Style', 'Text', 'String', 'Define between subjects design', 'Position', [20 90 250 20], ...
        'FontSize', 12, 'BackgroundColor', [.66 .76 1], 'HorizontalAlignment', 'left');
    uicontrol(inputGUI, 'Style', 'pushbutton', 'String', 'Edit design', 'Position', [300 85 100 30], 'FontSize', 11, ...
        'Callback', @defineBetweenDesign);
    uicontrol(inputGUI, 'Style', 'pushbutton', 'String', 'Ok', 'Position', [300 10 100 30], 'Enable', 'off', 'Tag', 'Ok', 'Callback', 'uiresume()');
    uicontrol(inputGUI, 'Style', 'pushbutton', 'String', 'Cancel', 'Position', [190 10 100 30], 'Callback', @(src,event)close(src.Parent));

    uiwait(inputGUI);
    if ~isvalid(inputGUI)
        return;
    end
    rd = inputGUI.UserData;
    delete(inputGUI);

    rd = Randomizer_ComputeTanova(rd);
 
    Randomizer_ShowTanovaResults(rd);

    com = sprintf('pop_RaguMSMaps(%s, %s, ''Classes'', %i);', inputname(1), mat2str(SelectedSets), Classes);
end

function defineWithinDesign(src, ~)
    
    rd = src.Parent.UserData;
    okBtn = findobj(src.Parent, 'Tag', 'Ok');

    Output = Randomizer_Design([], [], [], rd);
    if ~isempty(Output)
        rd = get(Output,'UserData');
        close(Output);
        src.Parent.UserData = rd;
        if ~isempty(rd.Design)
            okBtn.Enable = 'on';
        end
    end

end

function defineBetweenDesign(src, ~)

    rd = src.Parent.UserData;
    okBtn = findobj(src.Parent, 'Tag', 'Ok');    

    Output = Randomizer_IndFeatures([], [], [], rd);
    if ~isempty(Output)
        rd = get(Output,'UserData');
        close(Output);
        src.Parent.UserData = rd;
        if numel(unique(rd.IndFeature)) > 1
            okBtn.Enable = 'on';
        end
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