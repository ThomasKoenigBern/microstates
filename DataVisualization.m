function DataVisualization(TheStatsStructure)
    % add nclasses as param
    disp("Entered HeatMapDisplaySceleton()");

    nSubjects = numel(TheStatsStructure);
    nClasses = size(TheStatsStructure(1).OrgTM,1);
    
    [res,~,~,structout] = inputgui('title','Microstate Data Visualization', ...
       'geometry', {1 1 1 1 1 1}, 'geomvert', [3 1 1 1 1 1], 'uilist', {...
        { 'Style', 'text', 'string', 'Variables to plot', 'fontweight', 'bold'  } ...
        {'Style', 'checkbox', 'string', 'Transition probabilities', 'tag', 'showTransitionPrb', 'value', 1} ...
        {'Style', 'checkbox', 'string', 'Duration', 'tag', 'showDuration', 'value', 1} ...
%         {'Style', 'checkbox', 'string', 'Spatial correlations', 'tag', 'showCorrels', 'value', 1} ...       % remove
        {'Style', 'checkbox', 'string', 'Occurrence', 'tag', 'showOccurrence', 'value', 1} ...
        {'Style', 'checkbox', 'string', 'Coverage', 'tag', 'showCoverage', 'value', 1} ...
        {'Style', 'checkbox', 'string', 'GFP', 'tag', 'showGFP', 'value', 1} ...
%         {'Style', 'pushbutton', 'string', 'Plot' } ...
       });


    
    if structout.showTransitionPrb == true
        %     TheStatsStructure
        
        % The statistics info comes in a structure array, one structure per
        % subject
        
        % We can pull out all the values from the transitions into a cell
        % array:
        OrgTMCellArray = {TheStatsStructure.OrgTM};        
        
        % And convert this to a normal numeric matrix
        OrgTMMatrix = cell2mat(OrgTMCellArray);
        
        % That needs some reshaping to have it in the nClasses x nClasses x
        % nSubjects format
        OrgTMMatrix = reshape(OrgTMMatrix,nClasses,nClasses,nSubjects);
    
        % Now we e.g. can average over subjects
        MeanOrgTMMatrix = mean(OrgTMMatrix,3);
        
        disp("MeanOrgTMMatrix");
        disp(MeanOrgTMMatrix);
        dataVisGui.h = heatmap(MeanOrgTMMatrix);
        dataVisGui.h.Title = "Microstate Transition Probabilities";
    %     dataVisGui.h.Position = [0.05 0.2 0.5 0.5];    
        dataVisGui.closeBtn = uicontrol('Style', 'pushbutton', 'String', 'Close', 'Units','Normalized','Position', [0.80 0.05 0.15 0.05], 'Callback', 'close(gcf)');
    end
%     if structout.showCorrels == true
%         correlsGui.h = heatmap(correls);
%         correlsGui.h.Title = "Microstate Spatial correlations to normative maps";
%     %     dataVisGui.h.Position = [0.05 0.2 0.5 0.5];    
%         correlsGui.closeBtn = uicontrol('Style', 'pushbutton', 'String', 'Close', 'Units','Normalized','Position', [0.80 0.05 0.15 0.05], 'Callback', 'close(gcf)');
% 
%     end

    if structout.showDuration == true
        DurationArray = {TheStatsStructure.meanDuration};        
        
        % And convert this to a normal numeric matrix
        DurationMatrix = cell2mat(DurationArray);
        
        % That needs some reshaping to have it in the nClasses x nClasses x
        % nSubjects format
        DurationMatrix = reshape(DurationMatrix,nClasses,nClasses,nSubjects);
    
        % Now we e.g. can average over subjects
        MeanOrgTMMatrix = mean(OrgTMMatrix,3);
        
        disp("MeanOrgTMMatrix");
        disp(MeanOrgTMMatrix);
        duration.h = bar(TheStatsStructure.Duration);
        duration.h.Title = "Microstate Duration";
    %     dataVisGui.h.Position = [0.05 0.2 0.5 0.5];    
        duration.closeBtn = uicontrol('Style', 'pushbutton', 'String', 'Close', 'Units','Normalized','Position', [0.80 0.05 0.15 0.05], 'Callback', 'close(gcf)');

    end

 
end