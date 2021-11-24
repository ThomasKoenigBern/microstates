function CH = eeg_CalinskiHarabasz(templateMaps, clusts)
    [centroids, Ni, SUMD] = getCandSUMD(templateMaps, clusts);
    clusters = unique(clusts);
    numClusts = length(clusters);
    if numClusts == 1
       CH = nan;
       return;
    end
    CH = getCH(templateMaps,centroids, Ni, SUMD, numClusts);
end

function dist = distfun(XI,XJ)
        dist = (1-abs(MyCorr(XI',XJ')));
end
      
  function [centroids, counts, sumD] = getCandSUMD(templateMaps, clusts)
      %Get centroids, number of observations and sum of Squared Euclidean
      %distance for each cluster based on cluster index. Index doesn't need
      %to be integers between 1:number of clusters
      p = size(templateMaps,2);
      clusters = unique(clusts);

      numClusts = length(clusters);
      centroids = NaN(numClusts,p);
      counts = zeros(numClusts,1);
      sumD = zeros(numClusts,1);
      for i = 1:numClusts
          members = (clusts == clusters(i));
          if any(members)
              counts(i) = sum(members);
              centroids(i,:) = sum(templateMaps(members,:),1) / counts(i);
              sumD(i)= sum(pdist2(templateMaps(members,:),centroids(i,:), @distfun).^2);          
          end
      end
  end
  
  function CH = getCH(templateMaps,centroids, Ni, SUMD,NC)
     %Get CalinskiHarabasz value based on cluster centroids, The number of
     %points in each cluster, sum of Squared Euclidean and the number of
     %clusters
      GlobalMean = mean(templateMaps,1);
      SSW = sum(SUMD,1);
      SSB = (pdist2(centroids,GlobalMean, @distfun)).^2;
      SSB = sum(Ni.*SSB);
      CH =(SSB/(NC-1))/(SSW/(length(templateMaps)-NC));
  end