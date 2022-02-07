% modified version of Calinski Harabasz computation in
% CalinskiHarabaszEvaluation.m from Machine Learning and Statistics toolbox
% - uses absolute spatial correlation as distance function instead of 
% euclidean distance

function CH = eeg_CalinskiHarabasz(IndSamples, ClustLabels)
    [centroids, Ni, SUMD] = getCandSUMD(IndSamples, ClustLabels);
    clusters = unique(ClustLabels);
    numClusts = length(clusters);
    if numClusts == 1
       CH = nan;
       return;
    end
    CH = getCH(IndSamples, centroids, Ni, SUMD, numClusts);
end

function dist = distfun(XI,XJ)
        dist = (1-abs(MyCorr(XI',XJ')));
end
      
function [centroids, counts, sumD] = getCandSUMD(IndSamples, ClustLabels)
      %Get centroids, number of observations and sum of Squared Euclidean
      %distance for each cluster based on cluster index. Index doesn't need
      %to be integers between 1:number of clusters
      p = size(IndSamples,2);
      clusters = unique(ClustLabels);

      numClusts = length(clusters);
      centroids = NaN(numClusts,p);
      counts = zeros(numClusts,1);
      sumD = zeros(numClusts,1);
      for i = 1:numClusts
          members = (ClustLabels == clusters(i));
          if any(members)
              counts(i) = sum(members);
              centroids(i,:) = sum(IndSamples(members,:),1) / counts(i);
              sumD(i)= sum(pdist2(IndSamples(members,:),centroids(i,:), @distfun).^2);          
          end
      end
  end
  
  function CH = getCH(IndSamples,centroids, Ni, SUMD,NC)
     %Get CalinskiHarabasz value based on cluster centroids, The number of
     %points in each cluster, sum of Squared Euclidean and the number of
     %clusters
      GlobalMean = mean(IndSamples,1);
      SSW = sum(SUMD,1);
      SSB = (pdist2(centroids,GlobalMean, @distfun).^2);
      SSB = sum(Ni.*SSB);
      CH =(SSB/(NC-1))/(SSW/(length(IndSamples)-NC));
  end

% Taken from Poulsen MST1.0 toolbox
% function C2 = columncorr(A,B)
%     % Fast way to compute correlation of multiple pairs of vectors without
%     % computing all pairs as would with corr(A,B). Borrowed from Oli at Stack
%     % overflow. Note the resulting coefficients vary slightly from the ones
%     % obtained from corr due differences in the order of the calculations.
%     % (Differences are of a magnitude of 1e-9 to 1e-17 depending of the tested
%     % data).
%     
%     An=bsxfun(@minus,A,mean(A,1));                 
%     Bn=bsxfun(@minus,B,mean(B,1));                 
%     An=bsxfun(@times,An,1./sqrt(sum(An.^2,1)));    
%     Bn=bsxfun(@times,Bn,1./sqrt(sum(Bn.^2,1)));    
%     C2=sum(An.*Bn,1);                            
% end