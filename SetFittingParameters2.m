

function FitPar = SetFittingParameters2(PossibleNs, FitPar, funcName, AddOptions)
    
    if nargin < 4;  AddOptions = false; end

    % Initial validation
    [FitPar, FitParDefaults] = checkFitPar(funcName, PossibleNs, FitPar);

    guiElements = {};
    guiGeom = {};
    guiGeomV = []; 

    % Add all fitting parameters that were filled in with default values as
    % gui elements
    if contains('nClasses', FitParDefaults)
        classChoices = sprintf('%i Classes|', PossibleNs);
        classChoices(end) = [];

        guiElements = [guiElements, ...
            {{ 'Style', 'text', 'string', 'Number of classes', 'fontweight', 'bold'}} ...
            {{ 'Style', 'listbox', 'string', classChoices, 'Value', 1, 'Tag', 'nClasses'}}];
        guiGeom = [guiGeom [1 1]];
        guiGeomV = [guiGeomV 3];
    end

    if contains('PeakFit', FitParDefaults)
        if contains('nClasses', FitParDefaults)
            guiElements = [guiElements, {{ 'Style', 'text', 'string', ''}}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end

        guiElements = [guiElements, ...
            {{ 'Style', 'checkbox', 'string' 'Fitting only on GFP peaks' 'tag' 'PeakFit','Value', FitPar.PeakFit }}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];
    end

    if contains('BControl', FitParDefaults)
        guiElements = [guiElements, ...
            {{ 'Style', 'checkbox', 'string' 'Remove potentially truncated microstates' 'tag' 'BControl','Value', FitPar.BControl }}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];
    end

    if contains('b', FitParDefaults) || contains('lambda', FitParDefaults)
        guiElements = [guiElements, ...
            {{ 'Style', 'text', 'string', 'Label smoothing (window = 0 for no smoothing)', 'fontweight', 'bold', 'HorizontalAlignment', 'center'}}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];

        if contains('b', FitParDefaults)
            guiElements = [guiElements, ...
                {{ 'Style', 'text', 'string', 'Label smoothing window (ms)', 'fontweight', 'bold' }} ...
                {{ 'Style', 'edit', 'string', num2str(FitPar.b) 'tag' 'b'}}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end

        if contains('lambda', FitParDefaults)
            guiElements = [guiElements, ...
                {{ 'Style', 'text', 'string', 'Non-Smoothness penalty', 'fontweight', 'bold' }} ...
                {{ 'Style', 'edit', 'string', num2str(FitPar.lambda) 'tag' 'lambda' }}];
            guiGeom = [guiGeom [1 1]];
            guiGeomV = [guiGeomV 1];
        end
    end

    if AddOptions
        if contains('Rectify', FitParDefaults)
            guiElements = [guiElements, ...
                {{ 'Style', 'checkbox', 'string','Rectify microstate fit' 'tag' 'Rectify','Value',FitPar.Rectify}}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1]; 
        end

        if contains('Normalize', FitParDefaults)
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
        
        if isfield(outstruct, 'nClasses')
            FitPar.nClasses = PossibleNs(outstruct.nClasses);
        end

        if isfield(outstruct, 'PeakFit')
            FitPar.PeakFit = outstruct.PeakFit;
        end

        if isfield(outstruct, 'BControl')
            FitPar.BControl = outstruct.BControl;
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
        FitPar = checkFitPar(funcName, PossibleNs, FitPar);
    end

end

function [FitPar, UsingDefaults] = checkFitPar(funcName, PossibleNs, varargin)
    
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
    addParameter(p, 'nClasses', min(PossibleNs), ...
        @(x) validateattributes(x, numClass, [numAttributes, '>=', min(PossibleNs), '<=', max(PossibleNs)], ...
        funcName, 'FitPar.nClasses'));
    
    % Logical inputs
    addParameter(p, 'PeakFit', true, @(x) validateattributes(x, logClass, logAttributes, funcName, 'FitPar.PeakFit'));
    addParameter(p, 'BControl', true, @(x) validateattributes(x, logClass, logAttributes, funcName, 'FitPar.BControl'));
    addParameter(p, 'Rectify', false, @(x) validateattributes(x, logClass, logAttributes, funcName, 'FitPar.Rectify'));
    addParameter(p, 'Normalize', false, @(x) validateattributes(x, logClass, logAttributes, funcName, 'FitPar.Normalize'));

    parse(p, varargin{:});
    FitPar = p.Results;
    UsingDefaults = p.UsingDefaults;
end