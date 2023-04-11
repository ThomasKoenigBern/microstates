% pop_RaguMSTemplates() Transfer microstate maps to Ragu for topographic testing
%
% Usage:
%   >> com = pop_RaguMSTemplates(ALLEEG, SelectedSets, 'Classes', Classes)
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
%   -> Array of set indices of ALLEEG to export. If not provided, a GUI
%   will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "Classes"
%   -> Number of microstate classes to export from each of the selected
%   sets. If not provided, a GUI will appear to select the number of
%   classes to export.
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

function com = pop_RaguMSTemplates(AllEEG, varargin)

    com = '';

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_RaguMSTemplates';
    p.FunctionName = funcName;

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));      

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    Classes = p.Results.Classes;

    %% SelectedSets validation
    % First make sure there are valid sets to export
    % First make sure there are valid sets for sorting
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(and(and(~isEmpty, ~HasDyn), HasMS));
    
    if isempty(AvailableSets)
        errordlg2('No valid sets for exporting found.', 'Export microstates to Ragu error');
        return;
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
            errorMessage = ['The following sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, dynamics sets, or sets ' ...
                'without microstate maps.'];
            errordlg2(errorMessage, 'Export microstates to Ragu error');
            return;
        end
    % Otherwise, prompt the user to select sets
    else
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        if isempty(defaultSets);    defaultSets = 1;    end        
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        [res, ~, ~, outstruct] = inputgui('geometry', {1 1 1}, 'geomvert', [1 1 4], 'uilist', { ...
                    { 'Style', 'text'    , 'string', 'Choose sets to export'} ...
                    { 'Style', 'text'    , 'string', 'Use ctrlshift for multiple selection'} ...
                    { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
                    'title', 'Export microstate maps to Ragu');
        
        if isempty(res);    return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);

        if numel(SelectedSets) < 1
            errordlg2('You must select at least one set of microstate maps','Export microstates to Ragu error');
            return;
        end
    end
    
    MinClasses = max(arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MinClasses, SelectedSets));
    MaxClasses = min(arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MaxClasses, SelectedSets));
    if contains('Classes', p.UsingDefaults)
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
            errorMessage = sprintf(['The specified number of classes %i is invalid.' ...
                ' Valid class numbers are in the range %i-%i.'], Classes, MinClasses, MaxClasses);
            errordlg2(errorMessage, 'Export microstates to Ragu error');
            return;
        end
    end
    rd = MsMapsAndDesign4Ragu(AllEEG(SelectedSets), Classes);
 %    rd = SaveMSMapsForRagu(AllEEG(SelectedSets), Classes);

    Output = Randomizer_Design([], [], [],rd);
    if isempty(Output)
        return;
    end

    rd = get(Output,'UserData');

    close(Output);

    Output = Randomizer_IndFeatures([], [], [],rd);
    if isempty(Output)
        return;
    end

    rd = get(Output,'UserData');

    close(Output);

    rd = Randomizer_ComputeTanova(rd);
 
    Randomizer_ShowTanovaResults(rd);
    %Ragu(rd);

    com = sprintf('com = pop_RaguMSTemplates(%s, %s, ''Classes'', %i);', inputname(1), mat2str(SelectedSets), Classes);
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