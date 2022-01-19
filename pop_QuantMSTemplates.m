 %pop_QuantMSTemplates() quantifies the presence of microstates in EEG data
%
% Usage:
%   >> [com, MSStats, Evol] = pop_QuantMSTemplates(AllEEG, CURRENTSET, UseMeanTmpl, FitParameters, MeanSet, FileName)
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
%   com
%   -> Command necessary to replicate the computation
%
%   Evol
%   -> Experimental: Evolution of the microstate quantifiers over time
%   
%   MSStats
%    -> A structure with all the mean quantifiers. If this output argument
%    is given and and the filename argument is not given, no file saving
%    dialog will appear
%
% Author: Thomas Koenig, University of Bern, Switzerland, 2022
%
% Copyright (C) 2022 Thomas Koenig, University of Bern, Switzerland, 
% thomas.koenig@upd.unibe.ch
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

function [com, MSStats, EpochData] = pop_QuantMSTemplates(AllEEG, CURRENTSET, UseMeanTmpl, FitParameters, MeanSet, FileName)
    
    global MSTEMPLATE;

    if nargin < 2,  CURRENTSET    = [];     end   
    if nargin < 3,  UseMeanTmpl   =  0;  end
    if nargin < 4,  FitParameters = [];     end 
    if nargin < 5,  MeanSet       = [];     end 

    com = '';
    if nargin < 3
        ButtonName = questdlg('What type of templates do  you want to use?', ...
                         'Microstate statistics', ...
                         'Sorted individual maps', 'Averaged maps','Published templates', 'Sorted individual maps');
        switch ButtonName
            case 'Individual maps'
                UseMeanTmpl = 0;
            case 'Averaged maps'
                UseMeanTmpl = 1;
            case 'Published templates'
                UseMeanTmpl = 2;
        end % switch
    end 

    nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG),'UniformOutput',true);
    nonemptyMean = nonempty(HasChildren);
 
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

    if numel(CURRENTSET) > 0
        SelectedSet = CURRENTSET;
    
        if UseMeanTmpl > 0 && isempty(MeanSet) 
            res = inputgui( 'geometry', {1 1}, 'geomvert', [1 5], 'uilist', { ...
                { 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'  } ...
                 { 'Style', 'listbox', 'string', AvailableMeans, 'tag','SelectSets'}});
     
            if isempty(res)
                return
            end
            if UseMeanTmpl == 1
                MeanSet = nonemptyMean(res{1});
            else
                MeanSet = res{1};
            end
        end
    else
        if UseMeanTmpl > 0 && isempty(MeanSet)
            res = inputgui('title','Quantify microstate features',...
            'geometry', {1 1 1 1 1 1}, 'geomvert', [1 1 4 1 1 4], 'uilist', { ...
                { 'Style', 'text', 'string', 'EEGs to analyze', 'fontweight', 'bold' } ...    
                { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
                { 'Style', 'listbox', 'string', AvailableSets, 'tag','SelectSets' ,'Min', 0, 'Max',2} ...
                { 'Style', 'text', 'string', ''} ...
                { 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'  } ...
                { 'Style', 'listbox', 'string', AvailableMeans, 'tag','SelectSets'}});
     
            if isempty(res)
                return
            end
            SelectedSet = nonemptyInd(res{1});
            if UseMeanTmpl == 1
                MeanSet     = nonemptyMean(res{2});
            else
                MeanSet     = res{2};
            end
           
        else
           res = inputgui('title','Quantify microstate features',...
                'geometry', {1 1 1}, 'geomvert', [1 1 4], 'uilist', { ...
                { 'Style', 'text', 'string', 'EEGs to analyze', 'fontweight', 'bold' } ...    
                { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
                { 'Style', 'listbox', 'string', AvailableSets, 'tag','SelectSets' ,'Min', 0, 'Max',2} ...
                });
     
            if isempty(res)
                return
            end
            SelectedSet = nonemptyInd(res{1});
        end
    end
    
    
    switch UseMeanTmpl
        case 0
            MinClasses = max(cellfun(@(x) GetClusterField(AllEEG(x),'MinClasses'),num2cell(SelectedSet)));
            MaxClasses = min(cellfun(@(x) GetClusterField(AllEEG(x),'MaxClasses'),num2cell(SelectedSet)));
        case 1
            TheChosenTemplate = AllEEG(MeanSet);
            MinClasses = TheChosenTemplate.msinfo.ClustPar.MinClasses;
            MaxClasses = TheChosenTemplate.msinfo.ClustPar.MaxClasses;
        case 2
            TheChosenTemplate = MSTEMPLATE(MeanSet);
            MinClasses = TheChosenTemplate.msinfo.ClustPar.MinClasses;
            MaxClasses = TheChosenTemplate.msinfo.ClustPar.MaxClasses;
    end
    if UseMeanTmpl == 0
        if isfield(AllEEG(SelectedSet(1)).msinfo,'FitPar');     par = AllEEG(SelectedSet(1)).msinfo.FitPar;
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
    end
    
    
    if (MinClasses > par.nClasses) | (MaxClasses < par.nClasses)
        errordlg2('The chosen template does not contain the chosen number of clusters','Microstate fitting');
    end
        
    if isfield(FitParameters,'SingleEpochFileTemplate')
        SingleEpochFileTemplate = FitParameters.SingleEpochFileTemplate;
    else 
        SingleEpochFileTemplate = [];
    end

    h = waitbar(0);
    set(h,'Name','Quantifying microstates, please wait...');
    set(findall(h,'type','text'),'Interpreter','none');

    for s = 1:numel(SelectedSet)
        sIdx = SelectedSet(s);

        if ischar(AllEEG(sIdx).data)
            ActiveEEG = pop_loadset('eeg',AllEEG(sIdx));
        else
            ActiveEEG = AllEEG(sIdx);
        end
        waitbar((s-1) / numel(SelectedSet),h,sprintf('Working on %s',ActiveEEG.setname),'Interpreter','none');
        DataInfo.subject   = ActiveEEG.subject;
        DataInfo.group     = ActiveEEG.group;
        DataInfo.condition = ActiveEEG.condition;
        DataInfo.setname   = ActiveEEG.setname;
        Labels = [];
        AllEEG(sIdx).msinfo.FitPar = par;
        ActiveEEG.msinfo
        if UseMeanTmpl == 0
            if isfield(ActiveEEG.msinfo.MSMaps(par.nClasses),'Labels')
                Labels = ActiveEEG.msinfo.MSMaps(par.nClasses).Labels;
            end
            Maps = NormDimL2(ActiveEEG.msinfo.MSMaps(par.nClasses).Maps,2);
            SheetName = 'Individual Maps';
            ActiveEEG.msinfo.FitPar = par;
            [MSClass,gfp,ExpVar] = AssignMStates(ActiveEEG,Maps,par,ActiveEEG.msinfo.ClustPar.IgnorePolarity);
            if ~isempty(MSClass)
 %              MSStats = [MSStats; QuantifyMSDynamics(MSClass,ActiveEEG.msinfo,ActiveEEG.srate, DataInfo, '<<own>>')];
                [MSStats(s), SSEpochData] = QuantifyMSDynamics(MSClass,gfp,ActiveEEG.msinfo,ActiveEEG.srate, DataInfo, [],ExpVar,SingleEpochFileTemplate );
            end
        else
            if isfield(TheChosenTemplate.msinfo.MSMaps(par.nClasses),'Labels')
                Labels = TheChosenTemplate.msinfo.MSMaps(par.nClasses).Labels;
            end

            Maps = NormDimL2(TheChosenTemplate.msinfo.MSMaps(par.nClasses).Maps,2);
            SheetName = TheChosenTemplate.setname;
            ActiveEEG.msinfo.FitPar = par;
            LocalToGlobal = MakeResampleMatrices(ActiveEEG.chanlocs,TheChosenTemplate.chanlocs);
            if any(isnan(LocalToGlobal(:)))
                errordlg2(['Set ' ALLEEG(sIdx) ' does not have all channel positions defined'],'Microstate fitting');
            end
            [MSClass,gfp,ExpVar] = AssignMStates(ActiveEEG,Maps,par, TheChosenTemplate.msinfo.ClustPar.IgnorePolarity, LocalToGlobal);
            if ~isempty(MSClass)
%                MSStats = [MSStats; QuantifyMSDynamics(MSClass,ActiveEEG.msinfo,ActiveEEG.srate, DataInfo, TheChosenTemplate.setname)]; 
                [MSStats(s), SSEpochData] = QuantifyMSDynamics(MSClass,gfp,ActiveEEG.msinfo,ActiveEEG.srate, DataInfo, TheChosenTemplate.setname, ExpVar,SingleEpochFileTemplate);
            end
        end
        EpochData(s) = SSEpochData;
    end
    close(h);
    FileName = [];
    idx = [];
    if nargin < 6 && nargout < 2
        [FName,PName, idx] = uiputfile({'*.csv','Comma separated file';'*.csv','Semicolon separated file';'*.txt','Tab delimited file';'*.mat','Matlab Table'; '*.xlsx','Excel file';'*.csv','Text file for R'},'Save microstate statistics');
        FileName = fullfile(PName,FName);
    end

    if ~isempty(FileName)
        if isempty(idx) 
            idx = 2;
            if contains(lower(FileName),'.mat')
                idx = 4;
            end
            if contains(lower(FileName),'.xls')
                idx = 5;
            end

            if contains(lower(FileName),'.4r')
                idx = 6;
            end
        end
        
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
    txt = sprintf('%i ',SelectedSet);
    txt(end) = [];
    if isempty(MeanSet)
        MeanSetText = '[]';
    else
        MeanSetText = sprintf('%i',MeanSet);
    end
    com = sprintf('com = pop_QuantMSTemplates(%s, [%s], %i, %s, %s, ''%s'');', inputname(1), txt, UseMeanTmpl, struct2String(par), MeanSetText, FileName);
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