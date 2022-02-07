function com = pop_MS_Dispersion(AllEEG,MeanSet, IgnorePolarity)

    com = '';

    if nargin < 2 
        MeanSet = [];
    end

    if nargin < 3  IgnorePolarity = true;            end %#ok<*SEPEX>
    
    % checks if ALLEEG structure has microstate info
    nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
    % check if multiple datasets have been loaded
    HasChildren = cellfun(@(x) isfield(x,'children'), {AllEEG.msinfo});
    nonemptyGroup  = nonempty(HasChildren);

    if numel(MeanSet) < 1 
        AvailableSets = {AllEEG(nonemptyGroup).setname};
  
        res = inputgui( 'geometry', {1 1 1}, 'geomvert', [1 4 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Choose sets for sorting'} ...
            { 'Style', 'listbox', 'string', AvailableSets, 'tag','SelectSets'} ...
            { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
            });
     
        if isempty(res)
            return; 
        end
        IgnorePolarity = res{2};
        SelectedMean = nonemptyGroup(res{1});

    else
        if nargin < 3
            res = inputgui( 'geometry', {1}, 'geomvert', 1, 'uilist', { ...
                { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
                });
        
            if isempty(res); return; end
            IgnorePolarity = res{1};
        end    
        SelectedMean = MeanSet;
    end

    if numel(SelectedMean) ~= 1
        errordlg2('You must select exactly one set of microstate maps','Sort microstate classes');
        return
    end
      
    eegout = AllEEG(SelectedMean);
    
    ChildIndex = FindTheWholeFamily(eegout,AllEEG);

    DispersionExplorer(eegout, AllEEG(ChildIndex));    
    txt = sprintf('%i ',SelectedMean);
    txt(end) = [];
        
    com = sprintf('com = pop_MS_Silhouette(%s, [%s], %i);', inputname(1),txt,IgnorePolarity); 
    end


    function ChildIndex = FindTheWholeFamily(TheMeanEEG,AllEEGs)
        
    AvailableDataNames = {AllEEGs.setname};
    
        ChildIndex = [];
        for i = 1:numel(TheMeanEEG.msinfo.children)
            idx = find(strcmp(TheMeanEEG.msinfo.children{i},AvailableDataNames));
        
            if isempty(idx)
                errordlg2(sprintf('Dataset %s not found',TheMeanEEG.msinfo.children{i}),'Silhouette explorer');
            end
    
            if numel(idx) > 1
                errordlg2(sprintf('Dataset %s repeatedly found',TheMeanEEG.msinfo.children{i}),'Silhouette explorer');
            end
            if ~isfield(AllEEGs(idx).msinfo,'children')
                ChildIndex = [ChildIndex idx]; %#ok<AGROW>
            else
                ChildIndex = [ChildIndex FindTheWholeFamily(AllEEGs(idx),AllEEGs)]; %#ok<AGROW>
            end
        end

    
    end