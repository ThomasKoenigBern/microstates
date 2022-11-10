 %pop_QuantMSTemplates() quantifies the presence of microstates in EEG data
%
% Usage:
%   >> [EEGOUT, CurrentSet, com,Evol] = pop_QuantMSTemplates(AllEEG, SelectedSets, UseMeanTmpl, FitParameters, TemplateSet, TemplateName, FileName)
%
% EEG lab specific:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%
%   "SelectedSets" 
%   -> Index of selected EEGs. If more than one EEG is selected, the analysis
%      will be limited to those, if not, the user is asked. 
%
% Graphical interface / input parameters
%
%   UseMeanTmpl
%   -> 0 if the template from the data itself is to be used
%   -> 1 if a mean template is to be used
%   -> 2 if a published template is to be used
%
%   FitParameters 
%   -> A struct with the following parameters:
%      - nClasses: The number of classes to fit
%      - PeakFit : Whether to fit only the GFP peaks and interpolate in
%        between (true), or fit to the entire data (false)
%      - b       : Window size for label smoothing (0 for none)
%      - lambda  : Penalty function for non-smoothness
%   + optional parameters;
%      - SegmentSize: Chops the data into segments of SegmentSize seconds
%        and returns the obtained dynamics in the extra output argument
%        Evol
%
%   TemplateSet
%   -> Index of the AllEEG dataset containing the mean clusters to be used if UseMeanTmpl
%   is true, else not relevant
%
%   TemplateName (added by Delara 10/18/22)
%   -> Name of published template or mean map setname that should be used
%   for quantifying. Will be used if UseMeanTmpl is 2, or if UseMeanTmpl is
%   1 and TemplateSet is empty. If TemplateSet is not empty, this will be
%   ignored.
%
%   Filename
%   -> Name of the file to store the output. 
%
% Output:
%
%   "EEGOUT"
%   -> EEG structure with all the quantiufied EEGs. May or may not have
%   updated sorting depending on user choice.
%
%   "CurrentSet"
%   -> Index of the quantified EEGs.
%
%   "com"
%   -> Command necessary to replicate the computation
%              %
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

function [EEGOUT, CurrentSet, com,EpochData] = pop_QuantMSTemplates(AllEEG, SelectedSets, UseMeanTmpl, FitParameters, TemplateSet, TemplateName, FileName)
    
    %% Set default values for outputs and input parameters
    global EEG;
    global CURRENTSET;    
    global MSTEMPLATE;
    global showMessage;
    com = '';
    EEGOUT = EEG;
    CurrentSet = CURRENTSET;

    if nargin < 2,  SelectedSets    = [];     end   
    if nargin < 3,  UseMeanTmpl     =  0;     end
    if nargin < 4,  FitParameters   = [];     end 
    if nargin < 5,  TemplateSet     = [];     end 
    if nargin < 6;  TemplateName    = [];     end
    if nargin < 7;  FileName        = [];     end

    %% Select type of templates to use
    if nargin < 3
        ButtonName = questdlg('What type of templates do  you want to use?', ...
                         'Microstate statistics', ...
                         'Sorted individual maps', 'Averaged maps','Published templates', 'Sorted individual maps');
        switch ButtonName,
            case 'Individual maps',
                UseMeanTmpl = 0;
            case 'Averaged maps',
                UseMeanTmpl = 1;
            case 'Published templates',
                UseMeanTmpl = 2;
        end
    end 

    %% Validate SelectedSets

    % identify valid (containing msinfo) datasets with and without children
    nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG),'UniformOutput',true);
    nonemptyInd  = nonempty(~HasChildren);
    nonemptyMean = nonempty(HasChildren);

    % Check if there are available sets to quantify
    if isempty(nonemptyInd)
        errordlg2(['No datasets with microstate maps found. Use Tools ->' ...
                ' Microstates -> Identify microstates to create maps before' ...
                ' quantifying.'], 'Quantify microstates');
        return;
    end

    % Check if SelectedSets are included in AvailableSets
    if ~isempty(SelectedSets)
        isValid = ismember(SelectedSets, nonemptyInd);
        if any(~isValid)
            invalidSets = SelectedSets(~isValid);
            if (any(invalidSets > numel(AllEEG)))
                errordlg2(['Selected dataset indices exceed the total number of ' ...
                    'datasets loaded to EEGLAB.'], 'Sort microstate classes');
                return;
            else
                if numel(SelectedSets) > 1            % the user has selected multiple datasets
                    if (numel(invalidSets) == 1)
                        errordlg2(sprintf(['Dataset %d is a mean set and cannot be quantified.' ...
                            ' Deselect this dataset to proceed.'], invalidSets),'Quantify microstates');
                    elseif (numel(invalidSets) < numel(SelectedSets))
                        errordlg2(sprintf(['Datasets %s are mean sets and cannot be quantified.' ...
                            ' Deselect these datasets to proceed.'], ...
                            [sprintf('%d,', invalidSets(1:end-1)), sprintf('%d', invalidSets(end))]), ...
                            'Quantify microstates');
                    else
                        errordlg2(['The selected datasets are mean sets and cannot be quantified.' ...
                            ' Please select different datasets.'],'Quantify microstates');
                    end
                else
                    errordlg2(sprintf(['Dataset %d is a mean set and cannot be quantified.' ...
                            ' Please select a different dataset.'], invalidSets),'Quantify microstates');
                end
            end
        end
    end

    %% Validate TemplateSet

    % identify available templates to use for quantifying based on
    % template type
    if UseMeanTmpl == 1
        TemplateNames = {AllEEG(nonemptyMean).setname};
    elseif UseMeanTmpl == 2
        TemplateNames = {MSTEMPLATE.setname};
    else
        TemplateNames = 1;
    end
    
    % Check if there are template sets available
    if isempty(TemplateNames)
        if UseMeanTmpl == 2
            errordlg2(['No published templates found. Add template sets to ' ...
                'the microstates/Templates folder before quantifying.'], ['Quantify ' ...
                'microstates']);
            return;
        else
            errordlg2(['No mean sets found. Use Tools -> Microstates -> ' ...
                'Compute mean microstate maps across individuals to create ' ...
                'the mean maps before quantifying.'], 'Quantify microstates');
            return;
        end
    end

    % Check if the provided template set/name is included in the available
    % template sets
    if ~isempty(TemplateSet) && UseMeanTmpl ~= 2
        if ~ismember(TemplateSet, nonemptyMean)
            errorMessage = sprintf('Dataset %i is not a valid mean set.', ...
                TemplateSet);
            errordlg2([errorMessage], 'Sort microstate classes');
            return;
        else
            TemplateIndex = find(nonemptyMean == TemplateSet, 1);
        end
    elseif ~isempty(TemplateName)
        if (~any(matches(TemplateNames, TemplateName)))
            if TemplateSet == -1
                errorMessage = sprintf('The specified template %s could not be found in the microstates/Templates' + ...
                'folder. Please add the template to the folder before sorting.', TemplateName);
                errordlg2([errorMessage],'Quantify microstates');
                return;
            else
                errorMessage = sprintf('The specified mean set %s could not be found.', TemplateName);
                errordlg2([errorMessage], 'Quantify microstates');
                return;
            end
        else
            TemplateIndex = find(matches(TemplateNames, TemplateName));
        end
    else
        TemplateIndex = [];
    end

    %% Prompt user to select sets to quantify and template set if needed in pop-up windows
    AvailableSetnames = {AllEEG(nonemptyInd).setname};
    if isempty(SelectedSets) && UseMeanTmpl > 0

        if isempty(TemplateIndex)
            TemplateIndex = 1;
        end

        res = inputgui('title','Quantify microstates',...
        'geometry', {1 1 1 1 1}, 'geomvert', [1 1 4 1 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Choose sets for quantifying'} ...
            { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
            { 'Style', 'listbox', 'string', AvailableSetnames, 'tag','SelectSets' ,'Min', 0, 'Max',2} ...
            { 'Style', 'text', 'string', 'Name of template map', 'fontweight', 'bold'  } ...
            { 'Style', 'popupmenu', 'string', TemplateNames,'tag','MeanName','Value', TemplateIndex} ...
            });

        if isempty(res); return; end
        
        SelectedSets = nonemptyInd(res{1});
        TemplateIndex = res{2};
        TemplateName = TemplateNames{TemplateIndex};

    elseif isempty(SelectedSets) 

        if isempty(TemplateIndex)
            TemplateIndex = 1;
        end

        res = inputgui('title','Quantify microstates',...
        'geometry', {1 1 1}, 'geomvert', [1 1 4], 'uilist', { ...
            { 'Style', 'text', 'string', 'Choose sets for quantifying'} ...
            { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
            { 'Style', 'listbox', 'string', AvailableSetnames, 'tag','SelectSets' ,'Min', 0, 'Max',2} ...
            });

        if isempty(res); return; end
        
        SelectedSets = nonemptyInd(res{1});
        
    elseif isempty(TemplateIndex) && UseMeanTmpl > 0
        TemplateIndex = 1;

        res = inputgui('title','Quantify microstates',...
        'geometry', {1 1 1}, 'geomvert', [1 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Name of template map', 'fontweight', 'bold'  } ...
            { 'Style', 'popupmenu', 'string', TemplateNames,'tag','MeanName' ,'Value', TemplateIndex } ...
            });
        
        if isempty(res); return; end
        TemplateIndex = res{1};
        TemplateName = TemplateNames{TemplateIndex};
    else
        TemplateName = TemplateNames{TemplateIndex};
    end

    if numel(SelectedSets) < 1
        errordlg2('You must select at least one set of microstate maps','Sort microstate classes');
        return;
    end

    %% Verify compatibility between selected sets to sort and template set

    % Check if template set is a parent set of all the selected sets (only
    % for mean sets)
    if UseMeanTmpl == 1
        warningSetnames = {};
        for index = 1:length(SelectedSets)
            sIndex = SelectedSets(index);
            containsChild = checkSetForChild(AllEEG, nonemptyMean(TemplateIndex), AllEEG(sIndex).setname);
            if ~containsChild
                warningSetnames = [warningSetnames, AllEEG(sIndex).setname];
            end
        end

        if ~isempty(warningSetnames) && showMessage
            txt = sprintf('%s, ', warningSetnames{:});
            txt = txt(1:end-2);
            warningMessage = sprintf(['Template set %s is not the parent set of ' ...
                'the following sets: %s. Are you sure you would like to proceed?'], ...
                TemplateName, txt);

            res = inputgui('title', 'Quantify microstates', ...
                'geometry', {1 [1 1] 1}, 'uilist', { ...
                { 'Style', 'text', 'string', warningMessage} ...
                { 'Style', 'radiobutton', 'string', 'Yes', 'Value', 0} ...
                { 'Style', 'radiobutton', 'string', 'No', 'Value', 0} ...
                { 'Style', 'checkbox', 'string', 'Do not show this message again', 'Value', 0} });
    
            if isempty(res); return; end 
            if (res{2}); return; end
            if (res{3})
                showMessage = 0;
            end

        end
    end
    
    %% Update fitting parameters
    switch UseMeanTmpl
        case 0,
            MinClasses = max(cellfun(@(x) GetClusterField(AllEEG(x),'MinClasses'),num2cell(SelectedSets)));
            MaxClasses = min(cellfun(@(x) GetClusterField(AllEEG(x),'MaxClasses'),num2cell(SelectedSets)));
        case 1,
            ChosenTemplate = AllEEG(TemplateSet);
            MinClasses = ChosenTemplate.msinfo.ClustPar.MinClasses;
            MaxClasses = ChosenTemplate.msinfo.ClustPar.MaxClasses;
        case 2,
            ChosenTemplate = MSTEMPLATE(TemplateSet);
            MinClasses = ChosenTemplate.msinfo.ClustPar.MinClasses;
            MaxClasses = ChosenTemplate.msinfo.ClustPar.MaxClasses;
    end

%     if UseMeanTmpl == 0
%         if isfield(AllEEG(SelectedSets(1)).msinfo,'FitPar');     par = AllEEG(SelectedSets(1)).msinfo.FitPar;
%         else par = [];
%         end
%     else
%         if isfield(ChosenTemplate.msinfo,'FitPar');              par = ChosenTemplate.msinfo.FitPar;
%         else par = [];
%         end
%     end
    
    par = [];
    [par,paramsComplete] = UpdateFitParameters(FitParameters,par,{'nClasses','lambda','PeakFit','b', 'BControl'});
 
    if ~paramsComplete
        par = SetFittingParameters(MinClasses:MaxClasses,par);
        if isempty(par);    return; end
    end

    %% Check for consistent sorting across selected sets if own templates are being used
    SelectedEEG = AllEEG(SelectedSets);
    if UseMeanTmpl == 0
        SortedBy = AllEEG(SelectedSets(1)).msinfo.MSMaps(par.nClasses).SortedBy;

        for i=1:numel(SelectedSets)
            if ~strcmp(SortedBy, AllEEG(SelectedSets(i)).msinfo.MSMaps(par.nClasses).SortedBy)
                warningMessage = ['Sorting information differs across datasets. ' ...
                    'Would you like to resort all sets according to the same template ' ...
                    'before proceeding?'];

                PublishedTemplateNames = {MSTEMPLATE.setname};
                MeanSetNames = {AllEEG(nonemptyMean).setname};
                CombinedSetNames = [PublishedTemplateNames MeanSetNames];

                res = inputgui('title', 'Quantify microstates', ...
                    'geometry', {1 1 1 1 1 1}, 'uilist', { ...
                    { 'Style', 'text', 'string', warningMessage} ...
                    { 'Style', 'radiobutton', 'string', 'Yes', 'Value', 0} ...
                    { 'Style', 'text', 'string', 'Name of template map', 'fontweight', 'bold'  } ...
                    { 'Style', 'popupmenu', 'string', CombinedSetNames,'tag','TemplateName' } ...
                    { 'Style', 'radiobutton', 'string', 'No', 'Value', 0} ...
                    { 'Style', 'checkbox', 'string', 'Do not ask me again', 'Value', 0} });
                
                if isempty(res); return; end 
                if (res{4})
                    showMessage = 0;
                end
                if (res{1})
                    TemplateIndex = res{2};
                    if TemplateIndex <= numel(PublishedTemplateNames)
                        TemplateName = PublishedTemplateNames(TemplateIndex);
                        [SelectedEEG, CurrentSet, ~] = pop_SortMSTemplates(AllEEG, SelectedSets, 0, -1, TemplateName, 1);
                    else
                        TemplateName = MeanSetNames(TemplateIndex - numel(PublishedTemplateNames));
                        [SelectedEEG, CurrentSet, ~] = pop_SortMSTemplates(AllEEG, SelectedSets, 0, [], TemplateName, 1);
                    end
                end
                break;
            end

        end
    end

    if isfield(FitParameters,'SingleEpochFileTemplate')
        SingleEpochFileTemplate = FitParameters.SingleEpochFileTemplate;
    else 
        SingleEpochFileTemplate = [];
    end

    %% Quantify
    h = waitbar(0);
    set(h,'Name','Quantifying microstates, please wait...');
    set(findall(h,'type','text'),'Interpreter','none');

    for s = 1:numel(SelectedSets)
        waitbar((s-1) / numel(SelectedSets),h,sprintf('Working on %s',SelectedEEG(s).setname),'Interpreter','none');

        % Get dataset information
        DataInfo.subject   = SelectedEEG(s).subject;
        DataInfo.group     = SelectedEEG(s).group;
        DataInfo.condition = SelectedEEG(s).condition;
        DataInfo.setname   = SelectedEEG(s).setname;
        
        % Quantifying using own templates
        if UseMeanTmpl == 0
            Maps = NormDimL2(SelectedEEG(s).msinfo.MSMaps(par.nClasses).Maps,2);
            SheetName = 'Individual Maps';
            SelectedEEG(s).msinfo.FitPar = par;

            [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,par,SelectedEEG(s).msinfo.ClustPar.IgnorePolarity);
            if ~isempty(MSClass)
                [MSStats(s), SSEpochData] = QuantifyMSDynamics(MSClass,gfp,SelectedEEG(s).msinfo,SelectedEEG(s).srate, DataInfo, [], IndGEVs, SingleEpochFileTemplate);
            end
        else
            Maps = NormDimL2(ChosenTemplate.msinfo.MSMaps(par.nClasses).Maps,2);
            SheetName = ChosenTemplate.setname;
            SelectedEEG(s).msinfo.FitPar = par;
            LocalToGlobal = MakeResampleMatrices(SelectedEEG(s).chanlocs,ChosenTemplate.chanlocs);
            if any(isnan(LocalToGlobal(:)))
                errordlg2(['Set ' SelectedEEG(s) ' does not have all channel positions defined'],'Microstate fitting');
            end

            [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,par, ChosenTemplate.msinfo.ClustPar.IgnorePolarity, LocalToGlobal);
            if ~isempty(MSClass)
                [MSStats(s), SSEpochData] = QuantifyMSDynamics(MSClass,gfp,SelectedEEG(s).msinfo,SelectedEEG(s).srate, DataInfo, ChosenTemplate.setname, IndGEVs, SingleEpochFileTemplate);
            end
        end
        EpochData(s) = SSEpochData;
    end
    close(h);

    % Set labels for output
    Labels = [];
    % Use generic numerical labels for own templates
    if UseMeanTmpl == 0
        for i=1:par.nClasses
            Labels{i} = sprintf('MS%i_%i', par.nClasses, i);
        end
    else
    % Use published template or mean set labels for other templates
        if isfield(ChosenTemplate.msinfo.MSMaps(par.nClasses),'Labels')
            Labels = ChosenTemplate.msinfo.MSMaps(par.nClasses).Labels;
        end
    end

    % Generate output file
    idx = 1;
    if nargin < 6
        [FName,PName,idx] = uiputfile({'*.csv','Comma separated file';'*.csv','Semicolon separated file';'*.txt','Tab delimited file';'*.mat','Matlab Table'; '*.xlsx','Excel file';'*.csv','Text file for R'},'Save microstate statistics');
        FileName = fullfile(PName,FName);
    else
        idx = 1;
        if ~isempty(strfind(FileName,'.mat'))
            idx = 4;
        end
        if ~isempty(strfind(FileName,'.xls'))
            idx = 5;
        end

        if ~isempty(strfind(FileName,'.4R'))
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
                xlswrite(FileName,SaveStructToTable(MSStats,[],[],Labels),SheetName);
            case 6
                SaveStructToR(MSStats,FileName);
        end
    end
    txt = sprintf('%i ',SelectedSets);
    txt(end) = [];

    EEGOUT = SelectedEEG;
    CurrentSet = SelectedSets;
    
    if (isempty(TemplateSet))
        com = sprintf('[ALLEEG EEG com] = pop_QuantMSTemplates(%s, [%s], %i, %s, [], ''%s'');', inputname(1), txt, UseMeanTmpl, struct2String(par), FileName);
    else
        com = sprintf('com = pop_QuantMSTemplates(%s, [%s], %i, %s, %s, ''%s'');', inputname(1), txt, UseMeanTmpl, struct2String(par), TemplateSet, FileName);
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

function x = GetClusterField(in,fieldname)
    x = nan;
    if ~isfield(in,'msinfo')
        return
    end
    if ~isfield(in.msinfo,'ClustPar')
        return;
    end
    if isfield(in.msinfo.ClustPar,fieldname)
        x = in.msinfo.ClustPar.(fieldname);
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