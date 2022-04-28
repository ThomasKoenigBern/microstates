function FVG = eeg_FreyVanGroenewoud(AllIndSamples, AllClustLabels, ClusterNumbers)
    numClustSolutions = length(ClusterNumbers);

    % using the individual samples and cluster labels for each solution,
    % compute Frey index for each solution
    FVG = zeros(numClustSolutions, 1);
    for c = 1:numClustSolutions
        IndSamples = AllIndSamples{c}';
        ClustLabels = AllClustLabels{c}';
        nc = ClusterNumbers(c);     % number of clusters
        
        % find mean inter-cluster distance and mean intra-cluster distance
        % for the CURRENT cluster solution
        centroids = NaN(nc,size(IndSamples,2));
        intraClustDists = zeros(nc,1);
        
        clusters = unique(ClustLabels);
        for i = 1:nc
          clustMembers = (ClustLabels == clusters(i));
          if any(clustMembers)
              centroids(i,:) = mean(IndSamples(clustMembers,:),1) ;
              % twice the average distance of each observation to the centroids
              intraClustDists(i)= 2*mean(pdist2(IndSamples(clustMembers,:),centroids(i,:)));
          end
        end
        
        currInterClustDist = mean(pdist(centroids));
        currIntraClustDist = mean(intraClustDists);

        % find the mean inter-cluster distance and mean intra-cluster
        % distance for the NEXT cluster solution
        IndSamples = AllIndSamples{c+1}';
        ClustLabels = AllClustLabels{c+1}';
        if (nc == ClusterNumbers(end))
            nc = ClusterNumbers(end) + 1;
        end

        centroids = NaN(nc,size(IndSamples,2));
        intraClustDists = zeros(nc,1);
        
        clusters = unique(ClustLabels);
        for i = 1:nc
          clustMembers = (ClustLabels == clusters(i));
          if any(clustMembers)
              centroids(i,:) = mean(IndSamples(clustMembers,:),1) ;
              % twice the average distance of each observation to the centroids
              intraClustDists(i)= 2*mean(pdist2(IndSamples(clustMembers,:),centroids(i,:)));
          end
        end
        
        nextInterClustDist = mean(pdist(centroids));
        nextIntraClustDist = mean(intraClustDists);

        FVG(c) = (nextInterClustDist - currInterClustDist)/(nextIntraClustDist - currIntraClustDist);
    end

end