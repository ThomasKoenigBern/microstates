function GEVExplorer(TemplateEEG, SortedSet,figh)
    
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
    
    CallGEVExplorer([],[],SortedSet,TemplateEEG,ClusterNumbers,txt)
end

% SortedSet: all child EEG structures
% eegout: Mean EEG structure
% ClusterNumbers: vector of all cluster numbers tried
function CallGEVExplorer(hObject,~,SortedSet,eegout,ClusterNumbers,txt)

%     if isempty(hObject)
%         index = 1;
%     else
%         index = get(hObject,'Value');
%     end
    
    maxClusters = size(ClusterNumbers, 2);
    GEVvalues = zeros(maxClusters, 1)
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
        
        % get mean template maps for the current clustering solution
        MeanTemplateMaps = eegout.data(:,:,nmaps)
        MeanTemplateMaps = MeanTemplateMaps(:, 1:nmaps)
        GEV = eeg_GEV(double(SortedMapsShifted), double(MeanTemplateMaps), double(Clusters));
        GEVvalues(i) = GEV;
    end

    plot(ClusterNumbers, GEVvalues, "-o");
    title("GEV for Each Cluster Number");
    xlabel("Cluster Numbers");
    ylabel("GEV");

end