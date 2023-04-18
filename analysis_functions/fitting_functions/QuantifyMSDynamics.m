%QuantifyMSDynamics() Quantify microstate parameters
%
% Usage:
%   >> res = QuantifyMSDynamics(MSClass, gfp, info, SamplingRate, DataInfo, TemplateName, IndGEVs)
%
% Where: - MSClass is a N timepoints x N Segments matrix of momentary labels
%        - gfp is a N timepoints x N Segments matrix of momentary GFP
%        values
%        - info is the structure with the microstate information
%        - SamplingRate is the sampling rate
%        - DataInfo contains info about the dataset analyzed
%        - TemplateInfo contains the name of the template set used for
%        quantifying and the template set it was sorted by
%        - IndGEVs is a vector with Global Explained Variance values for
%        each microstate map
%
% Output: 
%         - res: A Matlab table with the results, including the individual 
%           and total global explained variances, mean durations, mean
%           occurrences, coverages, mean GFPs, the observed transition
%           matrix, and the delta transition matrix
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
function res = QuantifyMSDynamics(MSClass, gfp, info, SamplingRate, DataInfo, TemplateInfo, IndGEVs)
    nEpochs = size(MSClass,2);
    TimeAxis = (0:(size(MSClass,1)-1)) / SamplingRate;

    % Extract dataset information
    res.DataSet      = DataInfo.setname;
    res.Subject      = DataInfo.subject;
    res.Group        = DataInfo.group;
    res.Condition    = DataInfo.condition;

    % Compute temporal dynamics
    sumDuration   = zeros(1,info.FitPar.nClasses);
    numHits       = zeros(1,info.FitPar.nClasses);
    sumGFP        = zeros(1,info.FitPar.nClasses);
    numPoints     = zeros(1,info.FitPar.nClasses);
    TotalTime     = 0;
    eOrgTM        = zeros(info.FitPar.nClasses,info.FitPar.nClasses,nEpochs);
    
    for e = 1: nEpochs

        % Find indices of microstate class transitions
        ChangeIndex  = find([0 diff(MSClass(:,e)')]);
        StartTimes   = TimeAxis(ChangeIndex(1:(end-1)));
        EndTimes     = TimeAxis((ChangeIndex(2:end)-1));
        
        % Durations of each microstate class appearance in the epoch
        Duration = EndTimes - StartTimes + TimeAxis(1);
        Class    = MSClass(ChangeIndex,e);
        
        if numel(Class) == 0
            Class(1) = nan;
        end        
        Class(end) = nan;

        % Times with microstate assignments that are not 0
        TotalTime = TotalTime + sum(Duration(Class > 0));
        
        for c1 = 1: info.FitPar.nClasses    % c1: from 1 to number of classes

            Hits = find(Class == c1);
            sumDuration(c1) = sumDuration(c1) + sum(Duration(Hits));
            numPoints(c1)   = numPoints(c1) + sum(MSClass(:,e) == c1);
            sumGFP(c1)      = sumGFP(c1) + sum(gfp(1, MSClass(:,e) == c1, e));
            numHits(c1)     = numHits(c1) + numel(Hits);            
      
            for c2 = 1:info.FitPar.nClasses
                eOrgTM(c1,c2,e) = sum(Class(Hits+1) == c2); 
            end
        end
    end

    res.TotalTime = TotalTime;

    % Total and individual explained variances
    res.TotalExpVar = sum(IndGEVs);  
    res.IndExpVar = IndGEVs;

    % Temporal dynamics    
    res.MeanDuration        = sumDuration./numHits;                 % mean duration of each microstate class
    res.MeanDurationAll     = sum(sumDuration)/sum(numHits);        % mean duration across all microstate classes
    
    res.MeanOccurrence      = numHits./TotalTime;                   % number of occurrences/s for each microstate class
    res.MeanOccurrenceAll   = sum(numHits)/TotalTime;               % mean number of occurrences/s across all microstate classes

    res.Coverage            = numPoints./sum(numPoints);            % fraction of activation time for each microstate class    

    res.MeanGFP             = sumGFP./numPoints;                    % mean GFP during activation of each microstate class
    
    orgTM = sum(eOrgTM,3);
    orgTM = orgTM / sum(eOrgTM, "all");

    expTM = zeros(info.FitPar.nClasses, info.FitPar.nClasses);
    for c1 = 1:info.FitPar.nClasses
        for c2 = 1:info.FitPar.nClasses
            if c1 == c2;    continue;   end
            expTM(c1,c2) = (numHits(c1)/sum(numHits)) * (numHits(c2)/sum(numHits)) /(1 - (numHits(c1)/sum(numHits)) );
        end
    end
    
    res.DeltaTM = ((orgTM - expTM)*100)./expTM;
    res.DeltaTM(isnan(res.DeltaTM)) = 0;

    res.OrgTM = orgTM*100;

    % if quantifying by own maps, include spatial correlations between
    % individual maps and the template maps they were sorted by
%     if isempty(TemplateName)
%         for i=1:info.FitPar.nClasses
%             templateLabel = sprintf('TemplateLabel_MS%i_%i', info.FitPar.nClasses, i);
%             res.(templateLabel) = info.MSMaps(info.FitPar.nClasses).Labels{i};
%             spCorrLabel = sprintf('SpCorr_MS%i_%i', info.FitPar.nClasses, i);
%             res.(spCorrLabel) = info.MSMaps(info.FitPar.nClasses).SpatialCorrelation(i);
%         end
%     end

    % Set template and sorting information
    res.FittingTemplate = TemplateInfo.name;
    if isempty(TemplateInfo.SortedBy)
        res.SortedBy = 'N/A';
    else
        res.SortedBy = TemplateInfo.SortedBy;
    end
end