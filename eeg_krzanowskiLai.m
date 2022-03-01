% INCOMPLETE. Issues have to do with looping through
% maps then timepoints. Need to follow Murray equation more closely
% Winner is a list of length Timepoints, each element representing the
% winning microstate number
function KL_nrm = eeg_krzanowskiLai(ClustLabels, clustNum, W_i, nClusters, nChannels) % make parameters: 
   
%     distance = 0;
%     nMaps = size(Maps,1);
%     nTimepoints = size(Winner,2);

    % Poulsen toolbox key
    % K: number of classes
    % C: number of channels
%     M_q = nan(nClusters,1);
    
    M_q = W_i*nClusters^(2/nChannels); %for KL

%     d_q = nan(nClusters,1);
    % look into Fray Van Groenewoud comparison
    d_q = M_q(1:nClusters-1) - M_q(2:nClusters);

    KL_nrm = (d_q(1:nClusters-1) - d_q(2:nClusters))./ M_q(1:nClusters-1); 
    

   
end
