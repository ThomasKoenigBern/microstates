%QuantifyMSDynamics() Quantify microstate parameters
%
% Usage:
%   >> res = QuantifyMSDynamics(MSClass,info, SamplingRate, DataInfo, TemplateName)
%
% Where: - MSClass is a N timepoints x N Segments matrix of momentary labels
%        - info is the structure with the microstate information
%        - Samplingrate is the sampling rate
%        - DataInfo contains info about the dataset analyzed
%        - TemplateName is the name of the microstate map template used
%        - ExpVar is the explained variance
%          The last three parameters are only for the documentation of the
%          results.
%
% Output: 
%         - res: A Matlab table with the results, including the observed 
%           transition matrix, the transition matrix expected if
%           transitions were only determined by the occurrence, and the
%           difference between the two.
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
%
function [res,EpochData] = QuantifyMSDynamics(MSClass,gfp,info, SamplingRate, DataInfo, TemplateName, ExpVar, SingleEpochFileTemplate, curr_EEG, AllEEG, idx)
    if nargin < 9
        SingleEpochFileTemplate = [];
    end

    nEpochs = size(MSClass,2);
    TimeAxis = (0:(size(MSClass,1)-1)) / SamplingRate;

    res.DataSet      = DataInfo.setname;
    res.Subject      = DataInfo.subject;
    res.Group        = DataInfo.group;
    res.Condition    = DataInfo.condition;
    
    if isempty(TemplateName)
        res.Template = '<<own>>';
        if isfield(info,'MSMaps')
            res.SortInfo     = info.MSMaps(info.FitPar.nClasses).SortedBy;
        else
            res.SortInfo = 'NA';
        end
    else
        res.Template     = TemplateName;
        res.SortInfo     = 'NA';
    end

    res.ExpVar       = ExpVar;

    eDuration        = nan(1,info.FitPar.nClasses,nEpochs);
    eOccurrence      = zeros(1,info.FitPar.nClasses,nEpochs);
    eContribution    = zeros(1,info.FitPar.nClasses,nEpochs);
    eMeanGFP         = zeros(1,info.FitPar.nClasses,nEpochs);
    eTotalTime       = zeros(1,nEpochs);
    eMeanDuration    = nan(1,nEpochs);
    eMeanOccurrence  = nan(1,nEpochs);

    eOrgTM        = zeros(info.FitPar.nClasses,info.FitPar.nClasses,nEpochs);
    eExpTM        = zeros(info.FitPar.nClasses,info.FitPar.nClasses,nEpochs);
    
    for e = 1: nEpochs      % e: from 1 to number of maps

        ChangeIndex = find([0 diff(MSClass(:,e)')]);
        StartTimes   = TimeAxis(ChangeIndex(1:(end-1)    ));
        EndTimes     = TimeAxis((ChangeIndex(2:end    )-1));

        Duration = EndTimes - StartTimes + TimeAxis(1);
        Class    = MSClass(ChangeIndex,e);
        
       if numel(Class) == 0
            Class(1) = nan;
        end
        
        Class(end) = nan;

        TotalTime = sum(Duration(Class > 0));
        eTotalTime(e)    = TotalTime;

        eMeanDuration(e) = mean(Duration(Class > 0));
        MeanOcc = sum(Class > 0) / TotalTime;
        eMeanOccurrence(e) = MeanOcc;
        
        
        for c1 = 1: info.FitPar.nClasses    % c1: from 1 to number of classes

            Hits = find(Class == c1);
            eDuration(1,c1,e)     = mean(Duration(Hits));
            eOccurrence(1,c1,e)   = numel(Hits) / TotalTime;
            eContribution(1,c1,e) = sum(Duration(Hits)) / TotalTime;
            eMeanGFP(1,c1,e)      = 0;
      
            for c2 = 1: info.FitPar.nClasses
                eOrgTM(c1,c2,e) = sum(Class(Hits+1) == c2); 
            end

        end
        cnt = zeros(info.FitPar.nClasses,1);
        for n = 1:(numel(Class)-1)
            if Class(n) == 0
                continue;
            end
            eMeanGFP(1,Class(n),e) = eMeanGFP(1,Class(n),e) + mean(gfp(1,ChangeIndex(n):ChangeIndex(n+1),e),2);
            cnt(Class(n)) = cnt(Class(n)) + 1;
        end
        
        for c1 = 1: info.FitPar.nClasses
            eMeanGFP(1,c1,e) = eMeanGFP(1,c1,e) ./ cnt(c1);
            for c2 = 1: info.FitPar.nClasses
                eExpTM(c1,c2,e) = eOccurrence(1,c1,e) / MeanOcc * eOccurrence(1,c2,e) / MeanOcc / (1 - eOccurrence(1,c1,e) / MeanOcc);
            end
            eExpTM(c1,c1,e) = 0;
        end
    end
    
    [curr_EEG,~,~] = pop_SortMSTemplates(AllEEG,idx,true, -1);
    
    eSpCorrelation = curr_EEG.msinfo.MSMaps(info.FitPar.nClasses).Communality;
    eSpCorrelation = mynanmean(eSpCorrelation,3);

    res.TotalTime = sum(eTotalTime);
    res.SpatialCorrelation = mynanmean(eSpCorrelation,3);
    res.Duration     = mynanmean(eDuration,3);
    res.MeanDuration = mean(eMeanDuration);
 
    res.Occurrence   = mynanmean(eOccurrence,3);
    res.MeanOccurrence = mean(eMeanOccurrence);

    res.Contribution = mynanmean(eContribution,3);

    res.MeanGFP = mynanmean(eMeanGFP,3);
    
    res.OrgTM = mynanmean(eOrgTM,3);
    res.OrgTM = res.OrgTM / sum(res.OrgTM(:));
    
    res.ExpTM = mynanmean(eExpTM,3);
    res.DeltaTM = res.OrgTM - res.ExpTM;
    
    EpochData.Duration     = squeeze(eDuration);
    EpochData.Occurrence   = squeeze(eOccurrence);
    EpochData.Contribution = squeeze(eContribution);
    
    disp("printing DataInfo.setname to csv:");
    disp(DataInfo.setname);
    disp("printing SingleEpochFileTemplate to csv:");
    disp(class(SingleEpochFileTemplate));

    if ~isempty(SingleEpochFileTemplate)
        OutputFileName = sprintf(SingleEpochFileTemplate,DataInfo.setname);        
        save(OutputFileName,'eDuration','eOccurrence','eContribution');
    end
end

function res = mynanmean(in,dim)
    isout = isnan(in);
    in(isout) = 0;
    res = sum(in,dim) ./ sum(~isout,dim);
end
