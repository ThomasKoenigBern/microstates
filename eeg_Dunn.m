% this version uses distances between centroids for both inter-cluster and
% intra-cluster distances
function Dunn = eeg_Dunn(IndSamples, ClustLabels)
    % get number of clusters
    clusters = unique(ClustLabels);
    numClusts = length(clusters);
    if numClusts == 1
        Dunn = nan;
        return;
    end
    
   centroids = NaN(numClusts,size(IndSamples,2));
   intraClustDists = zeros(numClusts,1);
   for i = 1:numClusts
      clustMembers = (ClustLabels == clusters(i));
      if any(clustMembers)
          centroids(i,:) = mean(IndSamples(clustMembers,:),1) ;
          %average distance of each observation to the centroids
          intraClustDists(i)= mean(pdist2(IndSamples(clustMembers,:),centroids(i,:)));
      end
   end

   % min inter-cluster distance is minimum distance between centroids
   interClustDist = min(pdist(centroids));
    
   % max intra-cluster distance is twice the maximum average distance
   % between all members of a cluster and its centroid
   intraClustDist = 2*max(intraClustDists);

   Dunn = interClustDist/intraClustDist;
end