% adapted from:
% Julian Ramos (2022). Dunn's index 
% (https://www.mathworks.com/matlabcentral/fileexchange/27859-dunn-s-index), 
% MATLAB Central File Exchange. Retrieved February 2, 2022.

% this version uses single linkage distance for inter-cluster distance
% (distance between two CLOSEST data points from different clusters) and
% complete diameter linkage distance for intra-cluster distance (distance
% between two most REMOTE data points within the same cluster)
function Dunn = eeg_Dunn(IndSamples, ClustLabels)
    % get number of clusters
    clusters = unique(ClustLabels);
    numClusts = length(clusters);
    if numClusts == 1
        Dunn = nan;
        return;
    end
    
    % get pairwise distances between each observation
    distM = squareform(pdist(IndSamples));
    
    % find the min inter-cluster distance (numerator)
    interClustDists =[];
    for c=1:numClusts
        clustMembers = find(ClustLabels==c);            % indices of current cluster
        nonClustMembers = find(ClustLabels~=c);         % indices outside of current cluster
        temp = distM(clustMembers, nonClustMembers);    % distances between cluster and other clusters
        interClustDists = [interClustDists; temp(:)];   
    end
    num=min(min(interClustDists));

    % find the max intra-cluster distance (denominator)
    neg_obs=zeros(size(distM,1),size(distM,2));
    for c=1:numClusts
        clustMembers = find(ClustLabels==c);
        neg_obs(clustMembers,clustMembers) = 1;
    end
    dem = neg_obs.*distM;       % get only the intra-cluster distances
    dem = max(max(dem));

    % Dunn = min(inter-cluster distances)/max(intra-cluster distances)
    Dunn = num/dem;
end