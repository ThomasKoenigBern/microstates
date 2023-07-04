% QuantifyMSDynamics() Quantify microstate parameters
%
% Usage:
%   >> res = QuantifyMSDynamics(MSClass, gfp, info, SamplingRate, DataInfo, TemplateName, IndGEVs)
%
% Where: - MSClass is a N timepoints x N Segments matrix of momentary labels
%        - gfp is a N timepoints x N Segments matrix of momentary GFP
%        values
%        - SamplingRate is the sampling rate
%        - IndGEVs is a vector with Global Explained Variance values for
%        each microstate map
%
% Output: 
%         - res: A Matlab table with the results, including the individual 
%           and total global explained variances, mean durations, mean
%           occurrences, coverages, mean GFPs, the observed transition
%           matrix, and the delta transition matrix
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
%
function res = QuantifyMSDynamics(MSClass, gfp, SamplingRate, TemplateInfo, IndGEVs)
    nEpochs = size(MSClass,2);
    nClasses = numel(IndGEVs);
    TimeAxis = (0:(size(MSClass,1)-1)) / SamplingRate;    

    % Compute temporal dynamics
    sumDuration   = zeros(1,nClasses);
    durations     = cell(1,nClasses);
    numHits       = zeros(1,nClasses);
    sumGFP        = zeros(1,nClasses);
    gfps          = cell(1,nClasses);
    numPoints     = zeros(1,nClasses);
    TotalTime     = 0;
    eOrgTM        = zeros(nClasses,nClasses,nEpochs);
    
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
        
        for c1 = 1: nClasses    % c1: from 1 to number of classes

            Hits = find(Class == c1);
            sumDuration(c1) = sumDuration(c1) + sum(Duration(Hits));
            durations{c1}   = [durations{c1} Duration(Hits)];
            numPoints(c1)   = numPoints(c1) + sum(MSClass(:,e) == c1);
            sumGFP(c1)      = sumGFP(c1) + sum(gfp(1, MSClass(:,e) == c1, e));
            gfps{c1}        = [gfps{c1} gfp(1, MSClass(:,e) == c1, e)];
            numHits(c1)     = numHits(c1) + numel(Hits);            
      
            for c2 = 1:nClasses
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

    res.Coverage            = (numPoints./sum(numPoints))*100;      % fraction of activation time for each microstate class    

    res.MeanGFP             = sumGFP./numPoints;                    % mean GFP during activation of each microstate class
    
    orgTM = sum(eOrgTM,3);
    orgTM = orgTM / sum(eOrgTM, "all");

    expTM = zeros(nClasses, nClasses);
    for c1 = 1:nClasses
        for c2 = 1:nClasses
            if c1 == c2;    continue;   end
            expTM(c1,c2) = (numHits(c1)/sum(numHits)) * (numHits(c2)/sum(numHits)) /(1 - (numHits(c1)/sum(numHits)) );
        end 
    end

    res.OrgTM = orgTM*100;
    res.DeltaTM = ((orgTM - expTM)*100)./expTM;
    res.DeltaTM(isnan(res.DeltaTM)) = 0;    

    % Duration and GFP standard deviation
    res.DurationStdDev = cellfun(@std, durations);
    res.GFPStdDev      = cellfun(@std, gfps);

    % Add distribution data and individual labels
    res.DurationDist    = durations;
    res.GFPDist         = gfps;
    res.MSClass         = MSClass;
    res.GFP             = squeeze(gfp);

    % Set template and sorting information
    res.FittingTemplate = TemplateInfo.name;
    if isempty(TemplateInfo.SortedBy)
        res.SortedBy = 'N/A';
    else
        res.SortedBy = TemplateInfo.SortedBy;
    end
    res.TemplateLabels = TemplateInfo.TemplateLabels;
end