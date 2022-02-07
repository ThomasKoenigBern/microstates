% modified version of Davies Bouldin computation in 
% DaviesBouldinEvaluation.m from Machine Learning and Statistics toolbox - 
% uses absolute spatial correlation as distance function instead of 
% euclidean distance

function DB = eeg_DaviesBouldin(IndSamples,ClustLabels)

      function dist = distfun(XI,XJ)
        dist = (1-abs(MyCorr(XI',XJ')));
      end

      clusters = unique(ClustLabels);
      numClusts = length(clusters);
      if numClusts == 1
          DB = nan;
          return;
      end
      centroids = NaN(numClusts,size(IndSamples,2));
      
      aveWithinD= zeros(numClusts,1);
      for i = 1:numClusts
          members = (ClustLabels == clusters(i));
          if any(members)
              centroids(i,:) = mean(IndSamples(members,:),1) ;
              %average distance of each observation to the centroids, using
              %1 - absolute spatial correlation as distance function
              aveWithinD(i)= mean(pdist2(IndSamples(members,:),centroids(i,:), @distfun));
          end
      end
             
      interD = pdist(centroids, @distfun); %1 - absolute spatial correlation
      R = zeros(numClusts);
      for i = 1:numClusts
          for j=i+1:numClusts %j>i
              R(i,j)= (aveWithinD(i)+aveWithinD(j))/ interD((i-1)*(numClusts-i/2)+j-i);%d((I-1)*(M-I/2)+J-I)
          end
      end
      R=R+R';
    
      RI = max(R,[],1);
      DB = mean(RI);
end