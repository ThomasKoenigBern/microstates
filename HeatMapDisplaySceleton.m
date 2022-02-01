function HeatMapDisplaySceleton(TheStatsStructure)

    nSubjects = numel(TheStatsStructure);
    nClasses = size(TheStatsStructure(1).OrgTM,1);

    TheStatsStructure
    
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
    MeanOrgTMMatrix = mean(OrgTMMatrix,3)
 
end
