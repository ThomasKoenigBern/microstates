function ShowProgress(Prog,handle)

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

if ~ishandle(handle)
    return
end

axes(handle);
h = barh(0.5,Prog);    
set(h,'BarWidth',1,'EdgeColor',[1 0 0],'FaceColor',[1 0 0]);
set(gca,'XTick',[],'YTick',[]);
axis([0 1 0 1]);
drawnow