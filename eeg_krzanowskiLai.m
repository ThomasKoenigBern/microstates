% INCOMPLETE. Issues have to do with looping through
% maps then timepoints. Need to follow Murray equation more closely
% Winner is a list of length Timepoints, each element representing the
% winning microstate number
function KL = eeg_krzanowskiLai(nClusters, nVars, trace_w) % make parameters: 
   
%     distance = 0;
%     nMaps = size(Maps,1);
%     nTimepoints = size(Winner,2);

    % Poulsen toolbox key
    % K: number of classes
    % C: number of channels
%     M_q = nan(nClusters,1);
    
%     M_q = W_i*nClusters^(2/nChannels); %for KL_nrm and KL

%     d_q = nan(nClusters,1);
    % look into Fray Van Groenewoud comparison
    % Looks incorrect. M_q is size 104x104, so taking the first nClusters-1
    % columns doesn't seem right?
%     d_q = M_q(1:nClusters-1) - M_q(2:nClusters);    
% 
%     KL_nrm = (d_q(1:nClusters-2) - d_q(2:nClusters-1))./ M_q(1:nClusters-2); 
%     

%     KL = zeros(nClusters,1);
%     M = nan(nClusters,1); 
% 
%     diff = nan(nClusters,1);
    
%     M(:) = W_i*nClusters^(2/nChannels); %for KL
    
    % diff(K)=M(K-1)-M(K), excludes first segmentation. note: different from KL_nrm.
%     diff(2:end) = M_q(1:end-1) - M(2:end);
    
    % KL=abs(diff(K)/diff(K+1)), excludes last segmentation
%     KL(1:end-1) = abs(diff(1:end-1) ./ diff(2:end));
    
    % Added rule that W(K) - W(K-1) cannot be positive, i.e. W increases from K-1
    % to K.    
%     i = [false; W(2:end) - W(1:end-1)];
%     KL(i>0) = 0;
%     KL([1 end]) = nan;
  
end

function diff_q = diff(q_clusters)
    diff_q = (((q_clusters-1)^(2/size(IndSamples,2))) * trace_w(1, optimalNumClusters-1))...
                    - (((optimalNumClusters)^(2/size(IndSamples,2))) * trace_w(1, optimalNumClusters))
end