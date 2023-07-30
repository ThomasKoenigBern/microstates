function h = SmoothStackPlot(x,y)

Colors = lines(size(y,2));

baseline = zeros(size(y,1),1);

px = repmat([x(:);flip(x(:))],1,size(y,2));
py = [cumsum([baseline y(:,1:end-1)],2); flip(cumsum(y,2))];

for i = 1:size(y,2)
    h(i) = patch(px(:,i),py(:,i),Colors(i,:));
end