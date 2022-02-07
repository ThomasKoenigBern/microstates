function com = pop_MS_IndGEV(AllEEG, CurrentSet, IgnorePolarity)
    com = '';

    if nargin < 2 
        CurrentSet = [];
    end

    if nargin < 3  IgnorePolarity = true;            end %#ok<*SEPEX>
    
    % checks if current dataset has microstate info
    CurrentSet = AllEEG(CurrentSet);
    if isfield(CurrentSet, 'msinfo') == 0
        errordlg2('You must identify microstate maps for this dataset', 'No microstate information found')
        return
    end

    if nargin < 3
        res = inputgui( 'geometry', {1}, 'geomvert', 1, 'uilist', { ...
            { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
            });
    
        if isempty(res); return; end
        IgnorePolarity = res{1};
    end    
    
    IndGEVExplorer(CurrentSet);    
        
    %com = sprintf('com = pop_MS_IndGEV(%s, [%s], %i);', inputname(1),txt,IgnorePolarity); 

end
