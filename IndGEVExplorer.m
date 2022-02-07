function IndGEVExplorer(CurrentSet,figh)
    
    if nargin > 2
        figure(figh);
        clf;
    else
        if ~isempty(findobj('Tag','IndGEVExplorer'))
            figh = figure(findobj('Tag','IndGEVExplorer'));
        else
            figh = figure();
        end
    end
    
    set(figh,'Tag','IndGEVExplorer');
    
    ClusterNumbers = CurrentSet.msinfo.ClustPar.MinClasses:CurrentSet.msinfo.ClustPar.MaxClasses;

    txt = cellfun(@(x) sprintf('%i Classes',x),num2cell(ClusterNumbers),'UniformOutput',false);
    
    CallIndGEVExplorer([],[],CurrentSet,ClusterNumbers,txt);
end

% CurrentSet: current EEG structure
% ClusterNumbers: vector of all cluster numbers tried
function CallIndGEVExplorer(hObject,~,CurrentSet,ClusterNumbers,txt)

%     if isempty(hObject)
%         index = 1;
%     else
%         index = get(hObject,'Value');
%     end
    
    maxClusters = size(ClusterNumbers, 2);
    IndGEVvalues = zeros(maxClusters, 1);
    for i = 1:maxClusters
        nc = ClusterNumbers(i);
        % clf

        % get all samples from current dataset
        IndSamples = CurrentSet.data;

        % get template maps from current dataset
        TemplateMaps = CurrentSet.msinfo.MSMaps(nc).Maps';

        % get cluster labels for each time sample
        % fit parameters to get same cluster labels as if obtained from
        % original clustering algorithm (no interpolating, smoothing, etc.)
        % - change this later to make more efficient
        FitPar.PeakFit = false;
        FitPar.BControl = 0;
        FitPar.lambda = 0;
        [MSClass, MSClass2, gfp,fit] = AssignMStates(CurrentSet,TemplateMaps',FitPar,CurrentSet.msinfo.ClustPar.IgnorePolarity);
        
        IndGEV = eeg_GEV(double(IndSamples), double(TemplateMaps), double(MSClass2));
        disp([num2str(nc) ' clusters: ' num2str(IndGEV*100) '%'])
        IndGEVvalues(i) = IndGEV;
    end

    plot(ClusterNumbers, IndGEVvalues, "-o");
    title("GEV for Each Cluster Number");
    xlabel("Cluster Numbers");
    ylabel("GEV");


end