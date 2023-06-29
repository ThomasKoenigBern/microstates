setIdx = 5;
ResidualEstimator = VA_MakeSplineResidualMatrix(ALLEEG(setIdx).chanlocs);

ud.GFPresiduals = cell(ALLEEG(setIdx).trials, 1);
ud.times = cell(ALLEEG(setIdx).trials, 1);
for e=1:ALLEEG(setIdx).trials
    gfp = std(ALLEEG(setIdx).data(:,:,e));
    GFPpeaks = find([false (gfp(1,1:end-2) < gfp(1,2:end-1) & gfp(1,2:end-1) > gfp(1,3:end)) false]);
    ud.times{e} = arrayfun(@(x) sprintf('%i ms', x), ALLEEG(setIdx).times(GFPpeaks), 'UniformOutput', false);
    ud.GFPresiduals{e} = ResidualEstimator*ALLEEG(setIdx).data(:,GFPpeaks,e);
end

ud.nEpochs = ALLEEG(setIdx).trials;
ud.epoch = 1;
ud.chanNames = {ALLEEG(setIdx).chanlocs.labels};
fig = figure;
p = uipanel(fig, 'Units', 'normalized', 'Position', [.01 .16 .98 .83]);
ud.ax = axes(p);

x = repmat(ud.times{1}, 1, ALLEEG(setIdx).nbchan);
x = categorical(x, ud.times{1});
residuals = reshape(ud.GFPresiduals{1}', 1, []);
scatter = swarmchart(ud.ax, x, residuals, 15, [0 0.4470 0.7410], 'filled');
xlabel(ud.ax, 'GFP timepoints');
ylabel(ud.ax, 'Channel Residuals');
title(ud.ax, 'Epoch 1');
scatter.DataTipTemplate.DataTipRows = dataTipTextRow('Chan:', reshape(repmat(ud.chanNames, numel(ud.times{1}), 1), 1, []));

leftBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [.05 .02 .1 .1], ...
    'String', '<<', 'Callback', {@epochChanged, -1});
rightBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [.85 .02 .1 .1], ...
    'String', '>>', 'Callback', {@epochChanged, 1});
editBox = uicontrol(fig, 'Style', 'edit', 'String', '1', 'Units', 'normalized', 'Position', [.45 .02 .1 .1], 'Callback', @epochChanged);

fig.UserData = ud;

function epochChanged(src,~,dir)
    ud = src.Parent.UserData;
    if nargin == 3
        currEpoch = ud.epoch;
        newEpoch = currEpoch + dir;
        if newEpoch < 1 || newEpoch > ud.nEpochs
            return;
        end
    else
        newEpoch = str2double(src.String);
        if newEpoch < 1 || newEpoch > ud.nEpochs
            return;
        end
    end
    x = repmat(ud.times{newEpoch}, 1, numel(ud.chanNames));
    x = categorical(x, ud.times{newEpoch});
    residuals = reshape(ud.GFPresiduals{newEpoch}', 1, []);
    scatter = swarmchart(ud.ax, x, residuals, 15, [0 0.4470 0.7410],'filled');
    xlabel(ud.ax, 'GFP timepoints');
    ylabel(ud.ax, 'Channel Residuals');
    title(ud.ax, sprintf('Epoch %i', newEpoch));
    scatter.DataTipTemplate.DataTipRows = dataTipTextRow('Chan:', reshape(repmat(ud.chanNames, numel(ud.times{newEpoch}), 1), 1, []));
    ud.epoch = newEpoch;
    src.Parent.UserData = ud;
end