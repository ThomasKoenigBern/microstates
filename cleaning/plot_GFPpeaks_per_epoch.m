setIdx = 5;

ud.GFPpeaks = cell(ALLEEG(setIdx).trials, 1);
ud.times = cell(ALLEEG(setIdx).trials, 1);
for e=1:ALLEEG(setIdx).trials
    gfp = std(ALLEEG(setIdx).data(:,:,e));
    GFPpeaks = find([false (gfp(1,1:end-2) < gfp(1,2:end-1) & gfp(1,2:end-1) > gfp(1,3:end)) false]);
    ud.times{e} = arrayfun(@(x) sprintf('%i ms', x), ALLEEG(setIdx).times(GFPpeaks), 'UniformOutput', false);
    ud.GFPpeaks{e} = ALLEEG(setIdx).data(:,GFPpeaks,e);
end

X = [ALLEEG(setIdx).chanlocs.X];
Y = [ALLEEG(setIdx).chanlocs.Y];
Z = [ALLEEG(setIdx).chanlocs.Z];
ud.chanlocs = [X;Y;Z];
ud.nEpochs = ALLEEG(setIdx).trials;
ud.epoch = 1;
fig = figure;
ud.p = uipanel(fig, 'Units', 'normalized', 'Position', [.01 .16 .98 .83], 'Title', 'Epoch 1');
tl = tiledlayout(ud.p, 3, 10, 'Padding', 'tight', 'TileSpacing', 'tight');
ud.Axes = cell(3, 10);
for y=1:3
    for x=1:10
        idx = ((y-1)*10)+x;
        ud.Axes{y,x} = axes(tl);
        ud.Axes{y,x}.Layout.Tile = idx;
        ud.Axes{y,x}.Color = "none";
        ud.Axes{y,x}.XAxis.Visible = 'off';
        ud.Axes{y,x}.YAxis.Visible = 'off';
    end
end
GFPpeaks = ud.GFPpeaks{1};
for y=1:3
    for x=1:10
        idx = ((y-1)*10)+x;
        if idx > size(GFPpeaks,2)
            for i=1:numel(ud.Axes{y,x}.Children)
                ud.Axes{y,x}.Children(i).Visible = 'off';
            end
            ud.Axes{y,x}.Title.Visible = 'off';
        else
            dspCMap3(ud.Axes{y,x}, GFPpeaks(:,idx)', ud.chanlocs,'NoScale', ...
                        'Resolution',2,'ShowNose',15);
            title(ud.Axes{y,x}, ud.times{1}{idx});
            ud.Axes{y,x}.Title.Visible = 'on';    
            ud.Axes{y,x}.Visible = 'on';
            ud.Axes{y,x}.Color = "none";
            ud.Axes{y,x}.XAxis.Visible = 'off';
            ud.Axes{y,x}.YAxis.Visible = 'off';
        end
    end
end

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
    ud.p.Title = sprintf('Epoch %i', newEpoch);
    GFPpeaks = ud.GFPpeaks{newEpoch};
    for y=1:3
        for x=1:10
            idx = ((y-1)*10)+x;
            if idx > size(GFPpeaks,2)
                for i=1:numel(ud.Axes{y,x}.Children)
                    ud.Axes{y,x}.Children(i).Visible = 'off';
                    ud.Axes{y,x}.Visible = 'on';
                    ud.Axes{y,x}.Color = "none";
                    ud.Axes{y,x}.XAxis.Visible = 'off';
                    ud.Axes{y,x}.YAxis.Visible = 'off';
                end
                ud.Axes{y,x}.Title.Visible = 'off';
            else
                dspCMap3(ud.Axes{y,x}, GFPpeaks(:,idx)', ud.chanlocs,'NoScale', ...
                            'Resolution',2,'ShowNose',15);
                title(ud.Axes{y,x}, ud.times{newEpoch}{idx});
                ud.Axes{y,x}.Title.Visible = 'on';        
                ud.Axes{y,x}.Visible = 'on';
                ud.Axes{y,x}.Color = "none";
                ud.Axes{y,x}.XAxis.Visible = 'off';
                ud.Axes{y,x}.YAxis.Visible = 'off';
            end
        end
    end
    ud.epoch = newEpoch;
    src.Parent.UserData = ud;
end