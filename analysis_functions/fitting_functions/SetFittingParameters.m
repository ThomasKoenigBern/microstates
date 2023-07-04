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

function FitPar = SetFittingParameters(PossibleNs, FitPar, funcName, PeakFit, AddOptions)
    
    if nargin < 5;  AddOptions = false; end
   
    % Initial validation
    [FitPar, FitParDefaults] = checkFitPar(funcName, PossibleNs, AddOptions, PeakFit, FitPar);

    guiElements = {};
    guiGeom = {};
    guiGeomV = []; 

    showPeakFit = true;
    if PeakFit == 1
        if ~FitPar.PeakFit
            warning(['Backfitting on all timepoints rather than only GFP peaks is not recommended if microstates were clustered' ...
                ' using only GFP peaks. For consistency, set FitPar.PeakFit to true.']);
        end
        if ~matches('Classes', FitParDefaults)
            showPeakFit = false;
        end
    elseif PeakFit == 0
        if FitPar.PeakFit
            warning(['Backfitting on only GFP peaks is not recommended if microstates were clustered from all timepoints. ' ...
                'For consistency, set FitPar.PeakFit to false.']);
        end
        if ~matches('Classes', FitParDefaults) && ~matches('b', FitParDefaults) && ~matches('lambda', FitParDefaults)
            showPeakFit = false;
        end
    elseif PeakFit == -1
        if FitPar.PeakFit && ~matches('Classes', FitParDefaults)
            showPeakFit = false;
        end
        if ~FitPar.PeakFit && ~matches('Classes', FitParDefaults) && ~matches('b', FitParDefaults) && ~matches('lambda', FitParDefaults)
            showPeakFit = false;
        end           
    end

    % Add all fitting parameters that were filled in with default values as
    % gui elements
    if matches('Classes', FitParDefaults)
        classChoices = sprintf('%i Classes|', PossibleNs);
        classChoices(end) = [];

        guiElements = [guiElements, ...
            {{ 'Style', 'text', 'string', 'Select cluster solutions for backfitting', 'fontweight', 'bold'}} ...
            {{ 'Style', 'text', 'string', 'Use ctrl or shift for multiple selection'}} ...
            {{ 'Style', 'listbox', 'string', classChoices, 'Value', 1, 'Min', 0, 'Max', 2, 'Tag', 'Classes'}}];
        guiGeom = [guiGeom 1 1 1];
        guiGeomV = [guiGeomV 1 1 3];
    end

    if matches('PeakFit', FitParDefaults) && showPeakFit
        if matches('Classes', FitParDefaults)
            guiElements = [guiElements, {{ 'Style', 'text', 'string', ''}}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end

        if PeakFit == -1
            guiElements = [guiElements, ...
                {{ 'Style', 'checkbox', 'string' 'Backfit only on GFP peaks' 'tag' 'PeakFit','Value', FitPar.PeakFit, 'Callback', @peakFitChanged }}];            
        elseif PeakFit == 1
            guiElements = [guiElements, ...
                {{ 'Style', 'text', 'string', ['Template maps will be backfit on GFP peaks only,' newline 'with labels interpolated in between.']}}];
        else
            guiElements = [guiElements, ...
                {{ 'Style', 'text', 'string', 'Template maps will be backfit on all EEG timepoints.'}}];
        end
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];
    end

    if ~FitPar.PeakFit && (matches('b', FitParDefaults) || matches('lambda', FitParDefaults))      
        guiElements = [guiElements, ...
            {{ 'Style', 'text', 'string', 'Label smoothing (window = 0 for no smoothing)', 'Tag', 'SmoothingLabel', 'fontweight', 'bold'}}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];

        if matches('b', FitParDefaults)
            guiElements = [guiElements, ...
                {{ 'Style', 'text', 'string', 'Label smoothing window (ms)', 'Tag', 'bLabel', 'fontweight', 'bold'}} ...
                {{ 'Style', 'edit', 'string', num2str(FitPar.b) 'tag', 'b'}}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end

        if matches('lambda', FitParDefaults)
            guiElements = [guiElements, ...
                {{ 'Style', 'text', 'string', 'Non-Smoothness penalty', 'Tag', 'lambdaLabel', 'fontweight', 'bold'}} ...
                {{ 'Style', 'edit', 'string', num2str(FitPar.lambda) 'tag', 'lambda'}}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    end

    if AddOptions
        if matches('Rectify', FitParDefaults)
            guiElements = [guiElements, ...
                {{ 'Style', 'checkbox', 'string','Rectify microstate fit' 'tag' 'Rectify','Value',FitPar.Rectify}}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1]; 
        end

        if matches('Normalize', FitParDefaults)
            guiElements = [guiElements, ...
                {{ 'Style', 'checkbox', 'string','Normalize microstate fit' 'tag' 'Normalize','Value',FitPar.Normalize}}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1]; 
        end
    end
      
    % Prompt user to fill in remaining parameters if necessary
    if ~isempty(guiElements)
        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Microstate fitting parameters');

        if isempty(res)
            FitPar = [];
            return; 
        end
        
        if isfield(outstruct, 'Classes')
            FitPar.Classes = PossibleNs(outstruct.Classes);
        end

        if isfield(outstruct, 'PeakFit')
            FitPar.PeakFit = outstruct.PeakFit;
        end

        if isfield(outstruct, 'b')
            FitPar.b = str2double(outstruct.b);
        end

        if isfield(outstruct, 'lambda')
            FitPar.lambda = str2double(outstruct.lambda);
        end

        if isfield(outstruct, 'Rectify')
            FitPar.Rectify = outstruct.Rectify;
        end

        if isfield(outstruct, 'Normalize')
            FitPar.Normalize = outstruct.Normalize;
        end

        % Re-check FitPar values
        FitPar = checkFitPar(funcName, PossibleNs, AddOptions, PeakFit, FitPar);
    end

    if FitPar.PeakFit
        FitPar = rmfield(FitPar, {'b', 'lambda'});
    end

end

function peakFitChanged(obj, ~)
    smoothingLabel  = findobj(obj.Parent, 'Tag', 'SmoothingLabel');
    bLabel          = findobj(obj.Parent, 'Tag', 'bLabel');
    b               = findobj(obj.Parent, 'Tag', 'b');
    lambdaLabel     = findobj(obj.Parent, 'Tag', 'lambdaLabel');
    lambda          = findobj(obj.Parent, 'Tag', 'lambda');

    if obj.Value
        enable = 'off';       
    else
        enable = 'on';
    end

    if ~isempty(smoothingLabel)
        smoothingLabel.Enable = enable;
    end
    if ~isempty(bLabel)
        bLabel.Enable = enable;
        b.Enable = enable;
    end
    if ~isempty(lambdaLabel)
        lambdaLabel.Enable = enable;
        lambda.Enable = enable;
    end
end

function [FitPar, UsingDefaults] = checkFitPar(funcName, PossibleNs, AddOptions, PeakFit, varargin)
    
    if ~isempty(varargin)
        if isempty(varargin{:})
            varargin = {};
        end
    end

    % Parse and validate inputs
    p = inputParser;
    p.FunctionName = funcName;
    p.KeepUnmatched = true;

    numClass = {'numeric'};
    numAttributes = {'scalar', 'nonnan'};
    logClass = {'logical', 'numeric'};
    logAttributes = {'binary', 'scalar'};

    % Numeric inputs
    addParameter(p, 'b', 0, @(x) validateattributes(x, numClass, numAttributes, funcName, 'FitPar.b'));
    addParameter(p, 'lambda', 0.3, @(x) validateattributes(x, numClass, numAttributes, funcName, 'FitPar.lambda'));
    addParameter(p, 'Classes', min(PossibleNs), ...
        @(x) validateattributes(x, numClass, {'integer', 'positive', 'vector', 'nonnan', '>=', min(PossibleNs), '<=', max(PossibleNs)}, ...
        funcName, 'FitPar.Classes'));
    
    % Logical inputs
    addParameter(p, 'PeakFit', (PeakFit == 1), @(x) validateattributes(x, logClass, logAttributes, funcName, 'FitPar.PeakFit'));
    if AddOptions
        addParameter(p, 'Rectify', false, @(x) validateattributes(x, logClass, logAttributes, funcName, 'FitPar.Rectify'));
        addParameter(p, 'Normalize', false, @(x) validateattributes(x, logClass, logAttributes, funcName, 'FitPar.Normalize'));
    end

    parse(p, varargin{:});
    FitPar = p.Results;
    UsingDefaults = p.UsingDefaults;
end