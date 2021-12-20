function com = SourceLocalization(varargin)
    if ~brainstorm('status')
        brainstorm
    end

    % sample data
    % test Time: 1 second with a sampling frequency of 125Hz
    t = 0:1/125:1;
    % Generate sinsuoidal signals
    F = arrayfun(@(c){sin(1000/c*2*pi*t)}, 1:128);
    F = vertcat(F{:}); % arr of cell to mat

    Defaults = {F,'MS',128,false};
    Defaults(1:nargin) = varargin;
    F = Defaults{1};
    pname = Defaults{2}; % protocol name
    chcnt = Defaults{3};
    showOptions = Defaults{4};
    gui_brainstorm('DeleteProtocol', pname); 
    gui_brainstorm('CreateProtocol', pname, 1,0); % create protocol


    % Initialize an empty "matrix" structure
    sMat = db_template('datamat');
    % Fill the required fields of the structure
    sMat.F = F;
    sMat.Comment     = 'Microstates Data';
    sMat.Time        = t;
    sMat.ChannelFlag = ones(1,chcnt);

    subName = 's1';
    [sSubject, iSubject] = bst_get('Subject', subName);
    if ~isempty(sSubject)
        db_delete_subjects(iSubject);
    end
    % create subject
    UseDefaultAnat = 1;
    UseDefaultChannel = 0;
    db_add_subject(subName,[],UseDefaultAnat, UseDefaultChannel);
    % Create a new folder/study in subject
    iStudy = db_add_condition(subName, subName);
    sFiles = db_add(iStudy, sMat);
    % Get the corresponding study structure
    % sStudy = bst_get('Study', iStudy);

    % import channel file
    bst_process('CallProcess', 'process_import_channel', sFiles, [], ...
            'channelfile',  {'', ''}, ...
            'usedefault',   31, ...  % Colin27: GSN HydroCel 128 E1
            'channelalign', 1, ...
            'fixunits',     1, ...
            'vox2ras',      1);

    % Process: Compute head model
    sFiles = bst_process('CallProcess', 'process_headmodel', sFiles, [], ...
        'Comment',     '', ...
        'sourcespace', 1, ...  % Cortex surface
        'meg',         3, ...  % Overlapping spheres
        'eeg',         3, ...  % OpenMEEG BEM
        'ecog',        2, ...  % OpenMEEG BEM
        'seeg',        2, ...  % OpenMEEG BEM
        'openmeeg',    struct(...
             'BemSelect',    [1, 1, 1], ...
             'BemCond',      [1, 0.0125, 1], ...
             'BemNames',     {{'Scalp', 'Skull', 'Brain'}}, ...
             'BemFiles',     {{}}, ...
             'isAdjoint',    0, ...
             'isAdaptative', 1, ...
             'isSplit',      0, ...
             'SplitLength',  4000), ...
        'channelfile', '');

    % Process: Compute covariance (noise or data)
    sFiles = bst_process('CallProcess', 'process_noisecov', sFiles, [], ...
        'baseline',       [-0.2, -0.008], ...
        'datatimewindow', [0, 1], ...
        'sensortypes',    'EEG', ...
        'target',         1, ...  % Noise covariance     (covariance over baseline time window)
        'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
        'identity',       1, ...
        'copycond',       0, ...
        'copysubj',       0, ...
        'copymatch',      0, ...
        'replacefile',    1);  % Replace

    if showOptions
        % show options (adapted from panel_protocols.m)
        [outputFiles, errMsg] = process_inverse_2018('Compute', [sFiles.iStudy], [sFiles.iItem]);
        if isempty(outputFiles) && ~isempty(errMsg)
            bst_error(errMsg, 'Compute sources', 0);
        end
    else
        % process directly Process: Compute sources [2018]
        sFiles = bst_process('CallProcess', 'process_inverse_2018', sFiles, [], ...
            'output',  3, ...  % Full results: one per file
            'inverse', struct(...
                 'Comment',        'sLORETA: EEG', ...
                 'InverseMethod',  'minnorm', ...
                 'InverseMeasure', 'sloreta', ...
                 'SourceOrient',   {{'free'}}, ...
                 'Loose',          0.2, ...
                 'UseDepth',       0, ...
                 'WeightExp',      0.5, ...
                 'WeightLimit',    10, ...
                 'NoiseMethod',    'reg', ...
                 'NoiseReg',       0.1, ...
                 'SnrMethod',      'fixed', ...
                 'SnrRms',         1e-06, ...
                 'SnrFixed',       3, ...
                 'ComputeKernel',  0, ...
                 'DataTypes',      {{'EEG'}}));
        outputFiles = sFiles.FileName;
    end
    com = 'com = SourceLocalization';
    view_surface_data([], outputFiles); % visualize
end
