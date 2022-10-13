 %pop_QuantMSTemplates() quantifies the presence of microstates in EEG data
%
% Usage:
%   >> [com,Evol] = pop_QuantMSTemplates(AllEEG, CURRENTSET, UseMeanTmpl, FitParameters, MeanSet, FileName)
%
% EEG lab specific:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%
%   "CURRENTSET" 
%   -> Index of selected EEGs. If more than one EEG is selected, the analysis
%      will be limited to those, if not, the user is asked
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
%   Meanset
%   -> Index of the AllEEG dataset containing the mean clusters to be used if UseMeanTmpl
%   is true, else not relevant
%
%   Filename
%   -> Name of the file to store the output. 
%
% Output:
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

function [EEGOUT, CurrentSet, com,EpochData] = pop_QuantMSTemplates(AllEEG, SelectedSets, UseMeanTmpl, FitParameters, MeanSet, FileName)
    
    global MSTEMPLATE;
    global EEG;
    global CURRENTSET;

    com = '';
    EEGOUT = EEG;
    CurrentSet = CURRENTSET;

    if nargin < 2,  SelectedSets    = [];     end   
    if nargin < 3,  UseMeanTmpl   =  0;     end
    if nargin < 4,  FitParameters = [];     end 
    if nargin < 5,  MeanSet       = [];     end 

    % select type of templates to use
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
        end % switch
    end 

    % identify valid (containing msinfo) datasets with and without children
    nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG),'UniformOutput',true);
    nonemptyMean = nonempty(HasChildren);
 
    % identify available templates to use for quantifying based on
    % template type
    if UseMeanTmpl == 0
        if (isempty(nonempty))
            error('No usable data found');
        end
        nonemptyInd  = nonempty(~HasChildren);
    elseif UseMeanTmpl == 1
        AvailableMeans = {AllEEG(nonemptyMean).setname};
        nonemptyInd  = find(~HasChildren);
    else
        AvailableMeans = {MSTEMPLATE.setname};
        nonemptyInd  = find(~HasChildren);
    end
    
    AvailableSets  = {AllEEG(nonemptyInd).setname};

    % Delara 8/29/22 change: remove pop-up selection of dataset to quantify
    % if command string includes a dataset

    isValid = ismember(SelectedSets, nonemptyInd);
    invalidSets = find(~isValid);           % indices of selected sets that have children
    if (~isempty(invalidSets))
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

    % select template to use for quantifying
    if UseMeanTmpl > 0 && isempty(MeanSet) 
        if (UseMeanTmpl == 1)           % using mean maps
            res = inputgui( 'geometry', {1 1}, 'geomvert', [1 5], 'uilist', { ...
                { 'Style', 'text', 'string', 'Name of mean set', 'fontweight', 'bold'  } ...
                 { 'Style', 'listbox', 'string', AvailableMeans, 'tag','SelectSets'}});
        else
            res = inputgui( 'geometry', {1 1}, 'geomvert', [1 5], 'uilist', { ...
                { 'Style', 'text', 'string', 'Name of published template', 'fontweight', 'bold'  } ...
                 { 'Style', 'listbox', 'string', AvailableMeans, 'tag','SelectSets'}});
        end
 
        if isempty(res)
            return
        end
        if UseMeanTmpl == 1
            MeanSet = nonemptyMean(res{1});
        else
            MeanSet = res{1};
        end
    end    
    
    switch UseMeanTmpl
        case 0,
            MinClasses = max(cellfun(@(x) GetClusterField(AllEEG(x),'MinClasses'),num2cell(SelectedSets)));
            MaxClasses = min(cellfun(@(x) GetClusterField(AllEEG(x),'MaxClasses'),num2cell(SelectedSets)));
        case 1,
            TheChosenTemplate = AllEEG(MeanSet);
            MinClasses = TheChosenTemplate.msinfo.ClustPar.MinClasses;
            MaxClasses = TheChosenTemplate.msinfo.ClustPar.MaxClasses;
        case 2,
            TheChosenTemplate = MSTEMPLATE(MeanSet);
            MinClasses = TheChosenTemplate.msinfo.ClustPar.MinClasses;
            MaxClasses = TheChosenTemplate.msinfo.ClustPar.MaxClasses;
    end
    if UseMeanTmpl == 0
        if isfield(AllEEG(SelectedSets(1)).msinfo,'FitPar');     par = AllEEG(SelectedSets(1)).msinfo.FitPar;
        else par = [];
        end
    else
        if isfield(TheChosenTemplate.msinfo,'FitPar');            par = TheChosenTemplate.msinfo.FitPar;
        else par = [];
        end
    end
    
    [par,paramsComplete] = UpdateFitParameters(FitParameters,par,{'nClasses','lambda','PeakFit','b', 'BControl'});
 
    if ~paramsComplete
        par = SetFittingParameters(MinClasses:MaxClasses,par);
        if isempty(par);    return; end
    end
    
%    MSStats = table();
    
    if isfield(FitParameters,'SingleEpochFileTemplate')
        SingleEpochFileTemplate = FitParameters.SingleEpochFileTemplate;
    else 
        SingleEpochFileTemplate = [];
    end

    h = waitbar(0);
    set(h,'Name','Quantifying microstates, please wait...');
    set(findall(h,'type','text'),'Interpreter','none');

%    MSStats(numel(SelectedSet)).DataSet = '';
    for s = 1:numel(SelectedSets)
        sIdx = SelectedSets(s);
        waitbar((s-1) / numel(SelectedSets),h,sprintf('Working on %s',AllEEG(sIdx).setname),'Interpreter','none');
        DataInfo.subject   = AllEEG(sIdx).subject;
        DataInfo.group     = AllEEG(sIdx).group;
        DataInfo.condition = AllEEG(sIdx).condition;
        DataInfo.setname   = AllEEG(sIdx).setname;
        Labels = [];
        
        if UseMeanTmpl == 0
            if isfield(AllEEG(sIdx).msinfo.MSMaps(par.nClasses),'Labels')
                Labels = AllEEG(sIdx).msinfo.MSMaps(par.nClasses).Labels;
            end
            Maps = NormDimL2(AllEEG(sIdx).msinfo.MSMaps(par.nClasses).Maps,2);
            SheetName = 'Individual Maps';
            AllEEG(sIdx).msinfo.FitPar = par;
            [MSClass,gfp,ExpVar, IndGEVs] = AssignMStates(AllEEG(sIdx),Maps,par,AllEEG(sIdx).msinfo.ClustPar.IgnorePolarity);
            if ~isempty(MSClass)
 %              MSStats = [MSStats; QuantifyMSDynamics(MSClass,AllEEG(sIdx).msinfo,AllEEG(sIdx).srate, DataInfo, '<<own>>')];
                [AllEEG, EEGOUT, MSStats(s), SSEpochData] = QuantifyMSDynamics(MSClass,gfp,AllEEG(sIdx).msinfo,AllEEG(sIdx).srate, DataInfo, UseMeanTmpl, [], ExpVar, IndGEVs, SingleEpochFileTemplate, AllEEG, sIdx);
            end
        else
            if isfield(TheChosenTemplate.msinfo.MSMaps(par.nClasses),'Labels')
                Labels = TheChosenTemplate.msinfo.MSMaps(par.nClasses).Labels;
            end

            Maps = NormDimL2(TheChosenTemplate.msinfo.MSMaps(par.nClasses).Maps,2);
            SheetName = TheChosenTemplate.setname;
            AllEEG(sIdx).msinfo.FitPar = par;
            LocalToGlobal = MakeResampleMatrices(AllEEG(sIdx).chanlocs,TheChosenTemplate.chanlocs);
            if any(isnan(LocalToGlobal(:)))
                errordlg2(['Set ' ALLEEG(sIdx) ' does not have all channel positions defined'],'Microstate fitting');
            end
            [MSClass,gfp,ExpVar, IndGEVs] = AssignMStates(AllEEG(sIdx),Maps,par, TheChosenTemplate.msinfo.ClustPar.IgnorePolarity, LocalToGlobal);
            if ~isempty(MSClass)
%                MSStats = [MSStats; QuantifyMSDynamics(MSClass,AllEEG(sIdx).msinfo,AllEEG(sIdx).srate, DataInfo, TheChosenTemplate.setname)]; 
                try
                    [AllEEG, EEGOUT, MSStats(s), SSEpochData] = QuantifyMSDynamics(MSClass,gfp,AllEEG(sIdx).msinfo,AllEEG(sIdx).srate, DataInfo, UseMeanTmpl, TheChosenTemplate.setname, ExpVar, IndGEVs, SingleEpochFileTemplate, AllEEG, sIdx);
                catch ME
                    return;
                end
            end
        end
        EpochData(s) = SSEpochData;
    end
    close(h);

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

    EEGOUT = AllEEG(SelectedSets);
    CurrentSet = SelectedSets;
    
    if (isempty(MeanSet))
        com = sprintf('[ALLEEG EEG com] = pop_QuantMSTemplates(%s, [%s], %i, %s, [], ''%s'');', inputname(1), txt, UseMeanTmpl, struct2String(par), FileName);
    else
        com = sprintf('com = pop_QuantMSTemplates(%s, [%s], %i, %s, %s, ''%s'');', inputname(1), txt, UseMeanTmpl, struct2String(par), MeanSet, FileName);
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
