setIdx = 1;
ResidualEstimator = VA_MakeSplineResidualMatrix(ALLEEG(setIdx).chanlocs);

residuals = zeros(size(ALLEEG(setIdx).data));
for e=1:ALLEEG(setIdx).trials
    residuals(:,:,e) = ResidualEstimator*ALLEEG(setIdx).data(:,:,e);
end

chanRMSE = squeeze(sqrt(mean(residuals.^2, 2)));

fig = figure;
fig.UserData.chanRMSE = chanRMSE;
fig.UserData.epoch = 1;
fig.UserData.nEpochs = ALLEEG(setIdx).trials;
fig.UserData.chanNames = {ALLEEG(setIdx).chanlocs.labels};
p = uipanel(fig, 'Units', 'normalized', 'Position', [.01 .16 .98 .83]);
fig.UserData.ax = axes(p);
line = plot(fig.UserData.ax, chanRMSE(:,1));
title(fig.UserData.ax, 'Epoch 1');
line.DataTipTemplate.DataTipRows = dataTipTextRow('Chan:', fig.UserData.chanNames);
leftBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [.05 .02 .1 .1], ...
    'String', '<<', 'Callback', {@epochChanged, -1});
rightBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [.85 .02 .1 .1], ...
    'String', '>>', 'Callback', {@epochChanged, 1});

function epochChanged(src,~,dir)
    ud = src.Parent.UserData;
    currEpoch = ud.epoch;
    newEpoch = currEpoch + dir;
    if newEpoch < 1 || newEpoch > ud.nEpochs
        return;
    end
    line = plot(ud.ax, ud.chanRMSE(:,newEpoch));
    line.DataTipTemplate.DataTipRows = dataTipTextRow('Chan:', ud.chanNames);
    title(ud.ax, sprintf('Epoch %i', newEpoch));
    ud.epoch = newEpoch;
    src.Parent.UserData = ud;
end