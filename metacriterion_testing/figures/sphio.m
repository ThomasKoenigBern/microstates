function [Sigma,Phi,Omega] = sphio(EEGData,SamplingRate,EpochLength)

[nFrames,nChannels,nEpochs] = size(EEGData);

if nEpochs > 1 && nargin > 2
    error('Data came already in epochs');
end

if nargin > 2
    nEpochs = floor(nFrames / EpochLength);
    EEGData = EEGData(1:(nEpochs * EpochLength),:);
    EEGData = reshape(EEGData',nChannels,EpochLength,nEpochs);
    EEGData = permute(EEGData,[2,1,3]);
end
    
[nFrames,nChannels,nEpochs] = size(EEGData);

aref = eye(nChannels) - 1/nChannels;

Sigma = nan(nEpochs,1);
Phi   = nan(nEpochs,1);
Omega = nan(nEpochs,1);

for e = 1:nEpochs
    EEG = EEGData(:,:,e) * aref;
    [v,d] = eigs(cov(EEG),nChannels-1);
    
    u = EEG * v;
    M0 = sum(sum(u.^2));
    ud = diff(u);
    M1 = sum(sum(ud.^2));
    Sigma(e) = sqrt(M0/nFrames);
    Phi(e) = 1/2/pi * sqrt(M1/M0) * SamplingRate;
    d = diag(d);
    dn = d ./ sum(d);
    Omega(e) = exp(-sum(dn.*log(dn)));
    
end
