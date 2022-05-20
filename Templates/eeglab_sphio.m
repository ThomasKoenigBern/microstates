function [S,P,O] = eeglab_sphio(EEG)

fprintf(1,'Working on %s\n',EEG.setname);
if isempty(EEG.event)
    warning('No events found in %s',EEG.setname);
    S = nan;
    P = nan;
    O = nan;
    return;
else
    latencies  = cell2mat({EEG.event.latency});
    IsBoundary = contains({EEG.event.type},'boundary');
end

latencies = [1 latencies(IsBoundary) size(EEG.data,2)];

S = 0;
P = 0;
O = 0;
t = 0;

for i = 1:numel(latencies)-1
    eegdata = EEG.data(:,ceil(latencies(i)):floor(latencies(i+1)))';
    [s,p,o] = sphio(double(eegdata),EEG.srate);
    nt = size(eegdata,1);
    S = S + s * nt;
    P = P + p * nt;
    O = O + o * nt;
    t = t + nt;
end

S = S / t;
P = P / t;
O = O / t;


