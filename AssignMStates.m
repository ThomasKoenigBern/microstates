%AssignMStates() Assigns EEG data to microstate clusters
%
% Usage:
%   >> [MSClass,gfp, fit] = AssignMStates(eegdata, Maps, params, IgnorePolarity, chanlocs)
%
% Where: - eegdata is an eeglab EEG structure
%        - Maps is a Nu x Ne matrix containing microstate template maps
%        - params.PeakFit: true if fitting is only done on GFP peaks and
%          the assignment is interpolated in between, false otherwise
%        - par.b is the window size, if labels are smoothed
%        - par.lambda is the non-smoothness penalty factor
%          (should be between 0 and 1)
%        - IgnorePolarity if the polarity of the maps is to be
%          ignored (the standard for EEG), false otherwise.
%        - chanlocs is the channel position information of the Maps matrix,
%          if Maps and the eegdata have different montages. 
%
% Output: 
%        - MSClass: N timepoints x N Segments matrix of momentary labels
%        - gfp: N timepoints x N Segments matrix of momentary gFP values
%        - fit: Relative variance explained by the model
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
function [MSClass, gfp, fit, IndGEVs] = AssignMStates(eegdata, Maps, params, IgnorePolarity, InterpolationMatrix)

    
    if nargin < 5
        TheEEGData = eegdata.data;
    else
        TheEEGData = zeros(size(Maps,2),size(eegdata.data,2),size(eegdata.data,3));
        for s = 1:size(eegdata.data,3)
            TheEEGData(:,:,s) = InterpolationMatrix * eegdata.data(:,:,s);
        end
    end
    
    if(size(TheEEGData,3) > 1 && isfield(params,'SegmentSize'))
        warning('Data already segmented, parameter SegmentSize has been ignored');
    end
    
    if(size(TheEEGData,3) == 1 && isfield(params,'SegmentSize'))
        SegmentPoints = params.SegmentSize * eegdata.srate;
        nSegs = floor(size(TheEEGData,2) / SegmentPoints);
        TheEEGData = reshape(TheEEGData(:,1:nSegs*SegmentPoints),size(TheEEGData,1),SegmentPoints,nSegs);
    end
   
    BoundaryPoint = [];
    BoundaryEpoch = [];
    % Are there any boundary events?
    for e = 1:numel(eegdata.event)
        if strcmp(eegdata.event(e).type,'boundary')
            BoundaryPoint = [BoundaryPoint,eegdata.event(e).latency];
            if isfield(eegdata.event(e),'epoch')
                % should this be eegdata.event(e).epoch, not event?
                BoundaryEpoch = [BoundaryEpoch, eegdata.event(e).event];
            else
                BoundaryEpoch = [BoundaryEpoch, 1];
            end
        end
    end
    nClasses = size(Maps,1);
    nSegments = size(TheEEGData,3);
    MSClass = zeros(size(TheEEGData,2),nSegments);

    gfp = std(TheEEGData,1,1);

    GEV_classes = zeros(nClasses, 1);
    GEV_classes_numerator = zeros(nClasses, 1);
    GEV_classes_denominator = zeros(nClasses, 1);
    clustLabelRatios = zeros(nClasses, 1);

%     Fit_GEV = zeros(nClasses, 1);
%     Var_GEV = zeros(nClasses, 1);
    AllMFit = 0;
    AllMVar = 0;
    IndGEVnum = zeros(1, nClasses);
    IndGEVdenom = 0;
   
    if params.PeakFit == 1
        Fit = nan(nClasses,size(TheEEGData,2));
        for s = 1:nSegments
            % Identify GFP Peaks
            IsIn = find([false (gfp(1,1:end-2,s) < gfp(1,2:end-1,s) & gfp(1,2:end-1,s) > gfp(1,3:end,s)) false]);
            if isempty(IsIn)
                errordlg2('No GFP peaks found','Microstate fitting');
                MSClass = [];
                return;
            end
            % Compute covariance between maps and timepoints
            Cov = NormDimL2(Maps,2) * squeeze(TheEEGData(:,IsIn,s)) / size(Maps,2);
            if IgnorePolarity == true
                Cov = abs(Cov);
            end
            % mfit = max covariance, GFPPClass = microstate label
            [mfit,GFPPClass] = max(Cov);
            
            AllMFit = AllMFit + squeeze(sum(mfit,2));
            PeakAssignment = zeros(nClasses,numel(IsIn));
            % add sum of standard deviations 
            AllMVar = AllMVar +  squeeze(sum(std(TheEEGData(:,IsIn,s),1,1),2));
           
            for c = 1:nClasses
                PeakAssignment(c,GFPPClass == c) = 1;
                Fit(c,:) = interp1(IsIn,PeakAssignment(c,:),1:size(TheEEGData,2),'linear');
            end
            Fit(isnan(Fit)) = 0;        % microstate assignments of 0
            % Whatever state is at the first and last GFP peak is not fully
            % defined and is removed
            
            [Hit,Winner] = max(Fit);
            
            % Individual GEV calculations
            for c = 1:nClasses
                clustMembers = TheEEGData(:, Winner == c, s);
                if any(clustMembers)
                    if (IgnorePolarity)
                        clustCorr = abs(corr(clustMembers, Maps(c, :)'));
                    else
                        clustCorr = corr(clustMembers, Maps(c, :)');
                    end
    
                    IndGEVnum(c) = IndGEVnum(c) + sum((gfp(1, Winner == c, s).*clustCorr').^2);
                    IndGEVdenom = IndGEVdenom + sum(gfp(1, Winner == c, s).^2);
                end
            end

            Winner(Hit == 0) = 0;       % microstate assignments of 0
            if params.BControl == true
                % Kill microstates truncated by boundaries
                for b = 1:numel(BoundaryPoint)
                    if BoundaryEpoch(b) == s
                        FirstPeakAfterBoundary = find(IsIn > BoundaryPoint(b),1);
                        LastPeakBeforeBoundary = find(IsIn < BoundaryPoint(b),1,'last');
                        Winner = fill1D(Winner, IsIn(FirstPeakAfterBoundary), 0);
                        Winner = fill1D(Winner, IsIn(LastPeakBeforeBoundary), 0);                
                    end
                end
                Winner = fill1D(Winner, IsIn(1)  , 0);
                Winner = fill1D(Winner, IsIn(end), 0);
            end
            MSClass(:,s) = Winner;
        end
    else
        MSClass = zeros(size(TheEEGData,2),nSegments);
        for s = 1:nSegments
            [Winner,ExpVar] = SmoothLabels(TheEEGData(:,:,s),Maps,params, eegdata.srate,IgnorePolarity);

            % Individual GEV calculations
            for c = 1:nClasses
                clustMembers = TheEEGData(:, Winner == c, s);
                if any(clustMembers)
                    if (IgnorePolarity)
                        clustCorr = abs(corr(clustMembers, Maps(c, :)'));
                    else
                        clustCorr = corr(clustMembers, Maps(c, :)');
                    end
    
                    IndGEVnum(c) = IndGEVnum(c) + sum((gfp(1, Winner == c, s).*clustCorr').^2);
                    IndGEVdenom = IndGEVdenom + sum(gfp(1, Winner == c, s).^2);
                end
            end

            % Kill microstates truncated by boundaries
            if params.BControl == true
                for b = 1:numel(BoundaryPoint)
                    if BoundaryEpoch(b) == s
                        FirstPointAfterBoundary = ceil( BoundaryPoint(b));
                        LastPointBeforeBoundary = floor(BoundaryPoint(b));
                        
                        Winner = fill1D(Winner, FirstPointAfterBoundary, 0);
                        Winner = fill1D(Winner, LastPointBeforeBoundary, 0);   
                    end
                end
            % Clear the first and last state, because it is undefined
                Winner = fill1D(Winner,1           ,0);
                Winner = fill1D(Winner,numel(Winner),0);
            end
%             GEVs(1,s) = sum(ExpVar(1,Winner > 0),2) / sum(Winner > 0);    % (Anjali) added this to extract individual GEVs
            for c = 1:nClasses
                for t = 1:size(Winner, 2)
                    gfp_c_t = std(TheEEGData(:,t,s));
                    if Winner ~= 0      % gamma = 1
                        GEV_classes(c) = GEV_classes(c) + ((gfp_c_t * Hit(t))^2 / (gfp_c_t^2));
                    end
                end
            end

            AllMFit = AllMFit + sum(ExpVar(1,Winner > 0),2);
            AllMVar = AllMVar + sum(Winner > 0);
            MSClass(:,s) = Winner;

        end

    end
    fit = AllMFit / AllMVar;

    IndGEVs = IndGEVnum/IndGEVdenom;
    TotalGEV = sum(IndGEVs);
end



function val = fill1D(val, StartPos, NewValue)
    
    StartPos = max(StartPos,1);
    StartPos = min(numel(val),StartPos);
    
    OldValue = val(StartPos);
    val(StartPos) = NewValue;
    % run left
    xp = StartPos - 1;
    while xp >= 1
        if val(xp) == OldValue
            val(xp) = NewValue;
            xp = xp - 1;
        else
            break;
        end
    end

    % run right
    xp = StartPos + 1;
    while xp <= numel(val)
       if val(xp) == OldValue
            val(xp) = NewValue;
            xp = xp + 1;
        else
            break;
        end
    end
end        
