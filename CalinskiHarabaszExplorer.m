function CalinskiHarabaszExplorer(TemplateEEG, SortedSet,figh)
    
    if nargin > 2
        figure(figh);
        clf;
    else
        if ~isempty(findobj('Tag','CalinskiHarabaszExplorer'))
            figh = figure(findobj('Tag','CalinskiHarabaszExplorer'));
        else
            figh = figure();
        end
    end
    
    set(figh,'Tag','CalinskiHarabaszExplorer');
    
    ClusterNumbers = TemplateEEG.msinfo.ClustPar.MinClasses:TemplateEEG.msinfo.ClustPar.MaxClasses;

    txt = cellfun(@(x) sprintf('%i Classes',x),num2cell(ClusterNumbers),'UniformOutput',false);
    
    CallCalinskiHarabaszExplorer([],[],SortedSet,TemplateEEG,ClusterNumbers,txt)
end

% SortedSet: all child EEG structures
% eegout: Mean EEG structure
% ClusterNumbers: vector of all cluster numbers tried
function CallCalinskiHarabaszExplorer(hObject,~,SortedSet,eegout,ClusterNumbers,txt)

%     if isempty(hObject)
%         index = 1;
%     else
%         index = get(hObject,'Value');
%     end
    
    maxClusters = size(ClusterNumbers, 2);
    chValues = zeros(maxClusters, 1)
    for i = 1:maxClusters
        nc = ClusterNumbers(i);
        % clf
        
        nSubjects = numel(SortedSet);
        
        
        SortedMaps = cellfun(@(x) SortedSet(x).msinfo.MSMaps(nc).Maps,num2cell(1:nSubjects),'UniformOutput',false);
        [nmaps,nchannels] = size(SortedMaps{1,1});
        SortedMaps = NormDimL2(reshape(cell2mat(SortedMaps),[nmaps,nchannels,nSubjects]),2);
        Clusters = repmat(1:nc,nSubjects,1);
        Subjects = repmat((1:nSubjects)',1,nmaps);
        Clusters = reshape(Clusters,1,nmaps * nSubjects)';
        Subjects = reshape(Subjects,1,nmaps * nSubjects)';
        SortedMapsShifted = shiftdim(SortedMaps,1);
        SortedMapsShifted = reshape(SortedMapsShifted,nchannels,nmaps * nSubjects);
        
        %distfun = @(XI,XJ)(1-abs(MyCorr(XI',XJ')));
        %distfun = @(XI,XJ)(EMMapDifference(XI,XJ,eegout.chanlocs,eegout.chanlocs,true));
        
        CalinskiHarabasz1 = evalclusters(double(SortedMapsShifted'), double(Clusters), 'CalinskiHarabasz');
        CalinskiHarabasz2 = eeg_CalinskiHarabasz(double(SortedMapsShifted'), double(Clusters));
        chValues(i) = CalinskiHarabasz2;
        disp(CalinskiHarabasz1)
        disp(CalinskiHarabasz2) 
    end

    plot(ClusterNumbers, chValues, "-o");
    title("Calinski-Harabasz Index for Each Cluster Number");
    xlabel("Cluster Numbers");
    ylabel("Calinski-Harabasz Index");

end