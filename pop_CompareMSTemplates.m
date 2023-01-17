function com = pop_CompareMSTemplates(AllEEG, varargin)
    com = '';

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_CompareMSTemplates';
    p.FunctionName = funcName;
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'IgnorePolarity', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    addParameter(p, 'TemplateSet', '', @(x) validateattributes(x, {'char', 'string', 'numeric'}, {}));
    addParameter(p, 'nClasses', []);

    parse(p, AllEEG, varargin{:});

    if isnumeric(p.Results.TemplateSet)
        validateattributes(p.Results.TemplateSet, {'numeric'}, {'integer', 'scalar', 'positive', '<=', numel(AllEEG)}, funcName, 'TemplateSet');
    else
        validateattributes(p.Results.TemplateSet, {'char', 'string'}, {'scalartext'});
    end

    SelectedSets = p.Results.SelectedSets;
    IgnorePolarity = p.Results.IgnorePolarity;
    TemplateSet = p.Results.TemplateSet;
    nClasses = p.Results.nClasses;

    %% SelectedSets validation

    %% TemplateSet validation

    %% Ask user for comparison type
    options = {'Compare solutions within dataset',
        'Compare individual maps',
        'Compare individual maps with mean maps',
        'Compare individual maps with published maps',
        'Compare mean maps',
        'Compare mean maps with published maps'};
    selection = radioDialog(options, 'Compare microstate maps');
end