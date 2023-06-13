% pop_SaveMSParameters() Generates a structure array of temporal dynamics
% parameters for all selected subjects. The structure array is stored in
% the "MSStats" output and can also be saved to a csv, txt, xlsx, 4R, or
% mat file. pop_FitMSMaps() must be used before calling this function
% to extract temporal parameters.
% The structure array contains the following parameters:
%   - TotalTime: total time in s for which valid microstate assignments
%   exist. Typically less than the length of time in the dataset due to
%   undefined periods at the beginning and end of epochs and around
%   boundary events.
%   - TotalExpVar: total variance in the EEG data explained by the template
%   maps selected for backfitting.
%   - IndExpVar: 1 x number of classes vector of variances explained by
%   each template map used for backfitting
%   - MeanDuration: 1 x number of classes vector of the mean length of time
%   each template map remains stable
%   - MeanDurationAll: mean length of time a template map remains stable
%   (average duration across all template maps)
%   - MeanOccurrence: 1 x number of classes vector of mean number of times
%   per second each template map appears
%   - MeanOccurrenceAll: mean number of times per second any template map
%   appears (average occurrences/s across all template maps)
%   - Coverage: 1 x number of classes vector of percentages of total time
%   that each template map is active
%   - MeanGFP: 1 x number of classes vector of the mean global field power
%   of timepoints assigned to each template map
%   - OrgTM: observed matrix of transition probabilities between microstate
%   classes, expressed as percentages of the total number of transitions
%   between all classes. Rows of the matrix correspond to the microstate
%   class being transitioned from, and columns correspond to the microstate
%   class being transitioned to (e.g. the value in row 1, column 2
%   represents the transition probability of microstate 1 to microstate 2.
%   - DeltaTM: differences between observed and expected transition
%   probabilities, expressed as percentages. The matrix of expected
%   transition probabilities is computed from the number of appearances of
%   each microstate class.
%   - DurationDist: 1 x number of classes cell array of vectors containing
%   the entire distribution of durations for each template map (not
%   included in exported file)
%   - GFPDist: 1 x number of classes cell array of vectors containing the
%   entire distribution of global field power values of the timepoints
%   assigned to each template map (not included in exported file)
%   - MSClass: number of epochs x number of timeframes/epoch array of
%   microstate class labels assigned to the entire recording period (not
%   included in exported file)
%   - GFP: number of epochs x number of timeframes/epoch array of global
%   field power values at each timepoint (not included in exported file)
%   - FittingTemplate: name of the template set whose maps were used for
%   backfitting
%   - SortedBy: sorting information for the fitting template
%
% Usage:
%   >> MSStats = pop_SaveMSParameters(ALLEEG, SelectedSets, 'key1', value1,
%       'key2', value2)
%
% Specify the number of classes in the fitting solution using the "Classes"
% argument and the filename to save the array of parameters to using the
% "Filename" argument.
% Ex:
%   >> MSStats = pop_SaveMSParameters(ALLEEG, 1:5, 'Classes', 4, 
%       'Filename', 'microstate/results/temporal_parameters.csv')
%
% The "Filename" argument can also be specified as "none" if you would like
% to use the MSStats output but do not need the information saved to a
% file.
% Ex:
%   >> MSStats = pop_SaveMSParameters(ALLEEG, 1:5, 'Classes', 4,
%   'Filename', 'none')
%
% Graphical interface:
%
%   "Choose sets to include in export"
%   -> Select sets whose temporal parameters should be saved
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
%   -> Array of set indices of ALLEEG whose temporal parameters will be
%   saved. Selected sets must contain temporal parameters in the "MSStats"
%   field of "msinfo" (obtained from calling pop_FitMSMaps). If sets
%   are not provided, a GUI will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "Classes"
%   -> Scalar integer value indicating the fitting solution whose
%   associated temporal parameters will be saved.
%
%   "Filename"
%   -> Full csv, txt, xlsx, 4R, or mat filename to save the generated array
%   of temporal dynamics parameters for all sets chosen for analysis. If
%   provided, the function will automatically save the parameters rather
%   than prompting for a filename. Useful for scripting purposes. If you
%   would not like to save the temporal dynamics to a file, specify as
%   "none" to avoid the file explorer popping up.
%
% Outputs:
%
%   "MSStats"
%   -> Structure array containing temporal dynamics parameters for each
%   dataset selected for the analysis. Each field corresponds to a
%   different temporal parameter, and each element in the array corresponds
%   to a dataset.
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

function [MSStats, com] = pop_SaveMSParameters(AllEEG, varargin)

    %% Set defaults for outputs
    com = '';
    MSStats = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_SaveMSParameters';

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));
    addParameter(p, 'Filename', '', @(x) validateattributes(x, {'char', 'string'}, {'scalartext'}));
    
    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    nClasses = p.Results.Classes;
    FileName = p.Results.Filename;

    %% SelectedSets validation        
    HasStats = arrayfun(@(x) hasStats(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(HasStats & ~HasDyn);
    
    if isempty(AvailableSets)
        errordlg2(['No sets with temporal parameters found. ' ...
            'Use Tools->Backfit microstate maps to EEG to extract temporal dynamics first.'], 'Export temporal parameters error');
        return;
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
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        [res,~,~,outstruct] = inputgui('geometry', [1 1 1], 'geomvert', [1 1 4], 'uilist', {
                    { 'Style', 'text'    , 'string', 'Choose sets to include in export', 'FontWeight', 'bold'} ...
                    { 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'} ...
                    { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
                    'title', 'Export temporal parameters');

        if isempty(res); return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);

        if numel(SelectedSets) < 1
            errordlg2('You must select at least one set of microstate maps','Export temporal parameters error');
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
        if ~isempty(p.UsingDefaults)
            errordlg2(errorMessage, 'Export temporal parameters error');
        else
            error(errorMessage);
        end
        return;
    end
    if matches('Classes', p.UsingDefaults)
        classChoices = sprintf('%i Classes|', commonClasses);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
            { {'Style', 'text', 'string', 'Select number of classes'} ...
              {'Style', 'listbox', 'string', classChoices, 'Value', 1, 'Tag', 'Classes'}}, ...
              'title', 'Export temporal parameters');
        
        if isempty(res); return; end
        nClasses = commonClasses(outstruct.Classes);
    else
        if ~ismember(nClasses, commonClasses)
            classesTxt = sprintf('%i, ', commonClasses);
            classesTxt = classesTxt(1:end-2);
            errorMessage = sprintf(['Not all selected sets to export contain microstate statistics for the %i cluster solution. ' ...
                'Valid class numbers include: %s.'], nClasses, classesTxt);
            if ~isempty(p.UsingDefaults)
                errordlg2(errorMessage, 'Export temporal parameters error');
            else
                error(errorMessage);
            end
            return;
        end
    end

    %% Verify compatibility between selected sets

    % Check for consistent fitting parameters
    PeakFit = arrayfun(@(x) logical(SelectedEEG(x).msinfo.FitPar.PeakFit), 1:numel(SelectedEEG));
    unmatched = ~(all(PeakFit == 1) || all(PeakFit == 0));

    if all(PeakFit == 0)
        b = arrayfun(@(x) SelectedEEG(x).msinfo.FitPar.b, 1:numel(SelectedEEG));
        lambda = arrayfun(@(x) SelectedEEG(x).msinfo.FitPar.lambda, 1:numel(SelectedEEG));
        unmatched = ~all(b == b(1)) || ~all(lambda == lambda(1));
    end

    if unmatched
        errorMessage = 'Fitting parameters differ between selected sets.';  
        if ~isempty(p.UsingDefaults)
            errordlg2(errorMessage, 'Export temporal parameters error');
        else
            error(errorMessage);
        end
        return;
    end

    % Check for consistent fitting templates
    FittingTemplates = arrayfun(@(x) SelectedEEG(x).msinfo.MSStats(nClasses).FittingTemplate, 1:numel(SelectedEEG), 'UniformOutput', false);
    if numel(unique(FittingTemplates)) > 1
        errorMessage = 'Fitting templates differ across datasets.';
        if ~isempty(p.UsingDefaults)
            errordlg2(errorMessage, 'Export temporal parameters error');
        else
            error(errorMessage);
        end
        return;
    end

    % Check for consistent fitting template sorting
    SortedBy = arrayfun(@(x) SelectedEEG(x).msinfo.MSStats(nClasses).SortedBy, 1:numel(SelectedEEG), 'UniformOutput', false);
    if numel(unique(SortedBy)) > 1
        errorMessage = 'Sorting information for the fitting template differs across datasets.';
        if ~isempty(p.UsingDefaults)
            errordlg2(errorMessage, 'Export temporal parameters error');
        else
            error(errorMessage);
        end
        return;
    end

    % Check for consistent labels if fitting template is own maps
    if strcmp(FittingTemplates{1}, '<<own>>')
        labels = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).Labels, 1:numel(SelectedEEG), 'UniformOutput', false);
        labels = horzcat(labels{:});
        if numel(unique(labels)) > nClasses
            errorMessage = 'Microstate map labels differ across datasets.';
            if ~isempty(p.UsingDefaults)
                errordlg2(errorMessage, 'Export temporal parameters error');
            else
                error(errorMessage);
            end
            return;
        end
    end

    %% Generate output file

    % Get MSStats from all selected sets
    MSStats = arrayfun(@(x) SelectedEEG(x).msinfo.MSStats(nClasses), 1:numel(SelectedEEG), 'UniformOutput', false);
    MSStats = horzcat(MSStats{:});
    
    % Add dataset info fields
    for s=1:numel(SelectedSets)
        MSStats(s).Dataset   = SelectedEEG(s).setname;        
        MSStats(s).Subject   = SelectedEEG(s).subject;
        MSStats(s).Group     = SelectedEEG(s).group;
        MSStats(s).Condition = SelectedEEG(s).condition;        
    end
    nFields = length(fieldnames(MSStats));
    MSStats = orderfields(MSStats, [(nFields-3):nFields, 1:(nFields-4)]);                               % reorder struct fields so dataset info is first

    outputStats = rmfield(MSStats, {'DurationDist', 'GFPDist', 'MSClass', 'GFP', 'TemplateLabels'});    % remove fields with extra info for output file

    % Set labels for output
    Labels = SelectedEEG(1).msinfo.MSStats(nClasses).TemplateLabels;

    if ~strcmp(FileName, 'none')
        if isempty(FileName)
            % Set default filename
            if strcmp(FittingTemplates{1}, '<<own>>')
                defaultFilename = sprintf('TemporalParameters_%i classes_IndividualTemplates.csv', nClasses);
            else
                defaultFilename = sprintf('TemporalParameters_%i classes_%s_Template.csv', nClasses, FittingTemplates{1});
            end
            [FName,PName,idx] = uiputfile({'*.csv','Comma separated file';'*.csv','Semicolon separated file';'*.txt','Tab delimited file';'*.mat','Matlab Table'; '*.xlsx','Excel file';'*.4R','Text file for R'},'Save microstate statistics', defaultFilename);
            if FName == 0
                FileName = 'none';
            else
                FileName = fullfile(PName,FName);
            end
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
    
        if ~strcmp(FileName, 'none')
            switch idx
                case 1
                    SaveStructToTable(outputStats,FileName,',',Labels);
                case 2
                    SaveStructToTable(outputStats,FileName,';',Labels);
                case 3
                    SaveStructToTable(outputStats,FileName,sprintf('\t'),Labels);
                case 4
                    save(FileName,'outputStats');
                case 5
                    writecell(SaveStructToTable(outputStats,[],[],Labels), FileName);
                case 6
                    SaveStructToR(outputStats,FileName);
            end
        end
    end

    com = sprintf('[MSStats, com] = pop_SaveMSStats(%s, %s, ''Classes'', %i, ''FileName'', ''%s'');', inputname(1), mat2str(SelectedSets), nClasses, FileName);

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