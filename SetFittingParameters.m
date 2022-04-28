%SetFittingParameters() Choose fitting parameters
%
% Usage: 
%   >> params = SetFittingParameters(PossibleNs, params, AddChannelFlag)
%
% Where: - PossibleNs is an array of possible microstate class numbers
%        - params is a structure with the fitting parameters
%          (see <a href="matlab:helpwin AssignMStates">AssignMStates</a> for details
% Output:
%        - params:   The fitting parameters chosen
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
function params = SetFittingParameters(PossibleNs, params, GFPPeaksFlag, AddChannelFlag)
    
    if nargin < 4; AddChannelFlag = false;          end
    if nargin < 3;  GFPPeaksFlag = true;            end
    if nargin < 2;  params = [];                    end
    if nargin < 1;  PossibleNs = params.MinClasses: params.MaxClasses;  end    
 
    choice = '';
    if(~isempty(PossibleNs))
        for i = 1:numel(PossibleNs)
            choice = [choice sprintf('%i Classes|',PossibleNs(i))];
        end
    
        choice(end) = [];
    end
    
    if ~isfield(params,'b');        params.b          = 0;    end
    if ~isfield(params,'lambda');    params.lambda    = 0.3;  end
    if ~isfield(params, 'PeakFit');  params.PeakFit   = true; end
    if ~isfield(params, 'nClasses') && ~isempty(PossibleNs)
        params.nClasses  = min(PossibleNs); 
    end
    if ~isfield(params, 'BControl'); params.BControl  = true; end
    if ~isfield(params, 'Rectify');  params.Rectify   = false; end
    if ~isfield(params, 'Normalize');params.Normalize = false; end
    
    if ~isempty(PossibleNs)
        idx = find(params.nClasses == PossibleNs);
        if(isempty(idx));   idx = 1;    end
    end
    
    if GFPPeaksFlag == true
        EnableGFPPeaks = 'on';
    else
        EnableGFPPeaks = 'off';
    end

    if AddChannelFlag == true
        EnableFitPars = 'on';
    else
        EnableFitPars = 'off';
    end

    if (isempty(PossibleNs))
        % If no min and max classes are passed in, the fitting parameters
        % window is for criterion backfitting, so do not include the
        % classes selection window or BControl option
        [res, ~, ~, structout] = inputgui( 'geometry', {1 1 [1 1] [1 1] 1 1}, 'uilist', { ...
            { 'Style', 'checkbox', 'string' 'Fitting only on GFP peaks' 'tag' 'PeakFit'    ,'Value', params.PeakFit, 'Enable', EnableGFPPeaks }  ...
            { 'Style', 'text', 'string', 'Label smoothing (window = 0 for no smoothing)', 'fontweight', 'bold', 'HorizontalAlignment', 'center'} ...
            { 'Style', 'text', 'string', 'Label smoothing window (ms)', 'fontweight', 'bold'  } ...
            { 'Style', 'edit', 'string', num2str(params.b) 'tag' 'SmoothWindow'} ...
            { 'Style', 'text', 'string', 'Non-Smoothness penalty', 'fontweight', 'bold'  } ...
            { 'Style', 'edit', 'string', num2str(params.lambda) 'tag' 'lambda' } ... 
            { 'Style', 'checkbox', 'string','Rectify microstate fit' 'tag' 'Rectify','Value',params.Rectify,'Enable',EnableFitPars} ... 
            { 'Style', 'checkbox', 'string','Normalize microstate fit' 'tag' 'Normalize','Value',params.Normalize,'Enable',EnableFitPars } ... 
            },'title','Choose microstate fitting parameters');
    else
        [res, ~, ~, structout] = inputgui( 'geometry', {[1 1] 1 1 1 1 [1 1] [1 1] 1 1}, 'geomvert', [3 1 1 1 1 1 1 1 1],  'uilist', { ...
            { 'Style', 'text', 'string', 'Number of classes', 'fontweight', 'bold'  } ...
            { 'style', 'listbox', 'string', choice, 'Value', idx}...
            { 'Style', 'text', 'string', ''} ...
            { 'Style', 'checkbox', 'string' 'Fitting only on GFP peaks' 'tag' 'PeakFit'    ,'Value', params.PeakFit, 'Enable', EnableGFPPeaks }  ...
            { 'Style', 'checkbox', 'string' 'Remove potentially truncated microstates' 'tag' 'BControl'    ,'Value', params.BControl }  ...
            { 'Style', 'text', 'string', 'Label smoothing (window = 0 for no smoothing)', 'fontweight', 'bold', 'HorizontalAlignment', 'center'} ...
            { 'Style', 'text', 'string', 'Label smoothing window (ms)', 'fontweight', 'bold'  } ...
            { 'Style', 'edit', 'string', num2str(params.b) 'tag' 'SmoothWindow'} ...
            { 'Style', 'text', 'string', 'Non-Smoothness penalty', 'fontweight', 'bold'  } ...
            { 'Style', 'edit', 'string', num2str(params.lambda) 'tag' 'lambda' } ... 
            { 'Style', 'checkbox', 'string','Rectify microstate fit' 'tag' 'Rectify','Value',params.Rectify,'Enable',EnableFitPars} ... 
            { 'Style', 'checkbox', 'string','Normalize microstate fit' 'tag' 'Normalize','Value',params.Normalize,'Enable',EnableFitPars } ... 
            },'title','Choose microstate fitting parameters');
    end
    
    if isempty(res)
        params = [];
        return
    else
        if ~isempty(PossibleNs)
            params.nClasses = PossibleNs(res{1});
            params.BControl = structout.BControl;
        end
        params.PeakFit = structout.PeakFit;
        params.b = structout.SmoothWindow;
        params.lambda = structout.lambda;
        params.Rectify = structout.Rectify;
        params.Normalize = structout.Normalize;
    end
end