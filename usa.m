function figHandle = usa(boundaryFile, outputFile)
% USA Open the 3D map, or export with usa([], 'output/usa-bank-failures.png').
if nargin < 1, boundaryFile = []; end
if nargin < 2, outputFile = ''; end
states = loadStateBoundaries(boundaryFile);
counts = dataCompiler();
names = {'Alabama','Alaska','Arizona','Arkansas','California','Colorado', ...
'Connecticut','Delaware','Florida','Georgia','Hawaii','Idaho','Illinois', ...
'Indiana','Iowa','Kansas','Kentucky','Louisiana','Maine','Maryland', ...
'Massachusetts','Michigan','Minnesota','Mississippi','Missouri','Montana', ...
'Nebraska','Nevada','New Hampshire','New Jersey','New Mexico','New York', ...
'North Carolina','North Dakota','Ohio','Oklahoma','Oregon','Pennsylvania', ...
'Rhode Island','South Carolina','South Dakota','Tennessee','Texas','Utah', ...
'Vermont','Virginia','Washington','West Virginia','Wisconsin','Wyoming'};
[known, paletteIndex] = ismember({states.Name}, names);
states = states(known); paletteIndex = paletteIndex(known);
distinct_colors = [
    0.620, 0.125, 0.294;  % Alabama (Crimson)
    0.086, 0.317, 0.482;  % Alaska (Dark Blue)
    0.769, 0.102, 0.125;  % Arizona (Red)
    0.090, 0.184, 0.373;  % Arkansas (Navy Blue)
    0.839, 0.282, 0.098;  % California (Orange-Red)
    0.533, 0.172, 0.227;  % Colorado (Burgundy)
    0.137, 0.235, 0.423;  % Connecticut (Navy Blue)
    0.902, 0.160, 0.235;  % Delaware (Red)
    0.980, 0.349, 0.090;  % Florida (Orange)
    0.612, 0.086, 0.141;  % Georgia (Red)
    0.984, 0.502, 0.118;  % Hawaii (Orange)
    0.278, 0.486, 0.169;  % Idaho (Green)
    0.341, 0.360, 0.690;  % Illinois (Blue)
    0.075, 0.306, 0.267;  % Indiana (Green)
    0.502, 0.000, 0.149;  % Iowa (Dark Red)
    0.906, 0.298, 0.235;  % Kansas (Red)
    0.537, 0.404, 0.145;  % Kentucky (Olive)
    0.541, 0.149, 0.196;  % Louisiana (Maroon)
    0.282, 0.322, 0.619;  % Maine (Blue)
    0.000, 0.361, 0.533;  % Maryland (Navy Blue)
    0.482, 0.569, 0.094;  % Massachusetts (Green)
    0.384, 0.431, 0.435;  % Michigan (Dark Gray)
    0.514, 0.675, 0.757;  % Minnesota (Light Blue)
    0.216, 0.247, 0.271;  % Mississippi (Dark Gray)
    0.506, 0.149, 0.341;  % Missouri (Maroon)
    0.965, 0.855, 0.157;  % Montana (Yellow)
    0.078, 0.388, 0.333;  % Nebraska (Green)
    0.086, 0.176, 0.431;  % Nevada (Dark Blue)
    0.251, 0.541, 0.796;  % New Hampshire (Blue)
    0.937, 0.227, 0.243;  % New Jersey (Red)
    0.275, 0.506, 0.725;  % New Mexico (Blue)
    0.078, 0.361, 0.529;  % New York (Navy Blue)
    0.251, 0.404, 0.698;  % North Carolina (Blue)
    0.000, 0.306, 0.561;  % North Dakota (Dark Blue)
    0.812, 0.196, 0.208;  % Ohio (Red)
    0.094, 0.373, 0.102;  % Oklahoma (Green)
    0.749, 0.196, 0.384;  % Oregon (Red)
    0.145, 0.251, 0.396;  % Pennsylvania (Dark Blue)
    0.000, 0.271, 0.529;  % Rhode Island (Navy Blue)
    0.141, 0.317, 0.470;  % South Carolina (Dark Blue)
    0.086, 0.129, 0.431;  % South Dakota (Dark Blue)
    0.620, 0.125, 0.294;  % Tennessee (Crimson)
    0.000, 0.267, 0.486;  % Texas (Dark Blue)
    0.000, 0.337, 0.620;  % Utah (Navy Blue)
    0.086, 0.227, 0.435;  % Vermont (Dark Blue)
    0.639, 0.086, 0.216;  % Virginia (Maroon)
    0.043, 0.275, 0.557;  % Washington (Blue)
    0.533, 0.102, 0.243;  % West Virginia (Maroon)
    0.000, 0.286, 0.482;  % Wisconsin (Dark Blue)
    0.239, 0.275, 0.435;  % Wyoming (Dark Blue)
    0.737, 0.737, 0.737;  % Washington, D.C. (Light Gray)
];
rings = cell(numel(states),1);
mainland = [];
for i = 1:numel(states)
    parts = states(i).Parts;
    rings{i} = cell(numel(parts),1);
    for j = 1:numel(parts)
        if strcmp(states(i).Name,'Alaska')
            xy = lambertUSA(parts(j).Lon,parts(j).Lat,-154,63);
        elseif strcmp(states(i).Name,'Hawaii')
            xy = lambertUSA(parts(j).Lon,parts(j).Lat,-157,20);
        else
            xy = lambertUSA(parts(j).Lon,parts(j).Lat);
            mainland = [mainland;xy];
        end
        rings{i}{j} = xy;
    end
end
if isempty(mainland), error('usa:MissingMainland','No mainland states found.'); end
lo = min(mainland); span = max(mainland)-lo;
% Insets keep all islands visible without squeezing the contiguous states.
for i = 1:numel(states)
    if strcmp(states(i).Name,'Alaska') || strcmp(states(i).Name,'Hawaii')
        allPoints = vertcat(rings{i}{:});
        low = min(allPoints); extent = max(allPoints)-low;
        if strcmp(states(i).Name,'Alaska')
            box = [lo(1),lo(2)-span(2)*.42,span(1)*.26,span(2)*.34];
        else
            box = [lo(1)+span(1)*.30,lo(2)-span(2)*.32,span(1)*.13,span(2)*.18];
        end
        factor = min(box(3:4)./extent);
        for j = 1:numel(rings{i})
            rings{i}{j} = (rings{i}{j}-low)*factor+box(1:2);
        end
    end
end
if exist('OCTAVE_VERSION','builtin')
    if any(strcmp(available_graphics_toolkits(),'qt')), graphics_toolkit('qt'); end
end
useRaster = exist('OCTAVE_VERSION','builtin') && strcmp(graphics_toolkit(),'gnuplot');
meshes = struct('Vertices',{},'Faces',{},'Color',{},'Outline',{},'Height',{});
visibility = 'on';
if ~isempty(outputFile), visibility = 'off'; end
background = [.055 .075 .10];
figHandle = figure('Name','USA Bank Failures','Color',background, ...
    'Position',[0 0 1800 1100],'Visible',visibility);
ax = axes('Parent',figHandle,'Position',[.035 .19 .72 .68]);
hold(ax,'on');
set(ax,'Color',background,'XTick',[],'YTick',[],'ZColor',[.8 .85 .9],'FontSize',11);
heightValues = zeros(numel(states),1);
for i = 1:numel(states)
    height = 0;
    if isKey(counts,states(i).Name), height = counts(states(i).Name); end
    heightValues(i) = height;
    color = distinct_colors(paletteIndex(i),:);
    if height == 0, color = [.20 .25 .30]; end
    for j = 1:numel(rings{i})
        [xy, faces] = triangulateRing(rings{i}{j});
        if isempty(faces), continue; end
        count = size(xy,1);
        % Triangular faces allow filled 3D polygons even with gnuplot.
        vertices = [xy,repmat(height,count,1)];
        meshes(end+1) = struct('Vertices',vertices,'Faces',faces,'Color',color,'Outline',true,'Height',height);
        if ~useRaster
            patch('Parent',ax,'Vertices',vertices,'Faces',faces, ...
                'FaceColor',color,'EdgeColor','none');
        end
        if height > 0
            next = [2:count,1]'; k = (1:count)';
            sides = [k,next,k+count;next,next+count,k+count];
            meshes(end+1) = struct('Vertices',[xy,zeros(count,1);vertices], ...
                'Faces',sides,'Color',color*.65,'Outline',false,'Height',height);
            if ~useRaster
                patch('Parent',ax,'Vertices',[xy,zeros(count,1);vertices], ...
                    'Faces',sides,'FaceColor',color*.65,'EdgeColor','none');
            end
        end
        outline = xy([1:end,1],:);
        % Retain the original stacked contours, one layer per failure.
        for layer = 0:height
            if useRaster, break; end
            plot3(ax,outline(:,1),outline(:,2),repmat(layer,size(outline,1),1), ...
                'Color',color*.55+[.35 .35 .35],'LineWidth',.35);
        end
    end
end
if useRaster
    rgb = rasterizeMap(meshes,background);
    image(ax,double(rgb)/255); axis(ax,'image'); axis(ax,'off'); set(ax,'YDir','reverse');
else
    view(ax,-12,55); pbaspect(ax,[1.8 1 .55]);
    zlim(ax,[0 max(10,max(heightValues)*1.1)]);
    zlabel(ax,'Bank failures','Color',[.85 .9 .95]);
    rotate3d(figHandle,'on');
end
title(ax,'USA BANK FAILURES | 2000–2023','Color',[.95 .97 1],'FontSize',23);
legendAx = axes('Parent',figHandle,'Position',[.79 .12 .20 .79]);
hold(legendAx,'on'); axis(legendAx,[0 1 0 numel(states)+2]); axis(legendAx,'off');
text(legendAx,0,numel(states)+1.4,'STATE / FAILURES','FontSize',12, ...
    'FontWeight','bold','Color',[.95 .97 1]);
for i = 1:numel(states)
    y = numel(states)-i+.5;
    rectangle('Parent',legendAx,'Position',[0,y-.16,.035,.30], ...
        'FaceColor',distinct_colors(paletteIndex(i),:),'EdgeColor','none');
    text(legendAx,.06,y,sprintf('%s  (%d)',states(i).Name,heightValues(i)), ...
        'FontSize',11,'Color',[.86 .90 .94],'Interpreter','none');
end
footer = {sprintf('%d failures across the 50 states | bundled data through July 2023',sum(heightValues)), ...
    'Alaska (lower left) and Hawaii (next to Alaska) are repositioned and rescaled.', ...
    'Height = failure count. Free boundary data: see data/README.md.'};
for k = 1:numel(footer)
    annotation(figHandle,'textbox',[.055 .12-k*.03 .70 .025], ...
        'String',footer{k},'Color',[.72 .79 .85],'EdgeColor','none','FontSize',11);
end
if ~isempty(outputFile)
    folder = fileparts(outputFile);
    if ~isempty(folder) && exist(folder,'dir') ~= 7, mkdir(folder); end
    set(figHandle,'PaperPositionMode','auto','InvertHardcopy','off');
    if useRaster
        % pngcairo keeps the dark background; EPS/Ghostscript may whiten it.
        print(figHandle,outputFile,'-dpngcairo','-r150');
    else
        print(figHandle,outputFile,'-dpng','-r150');
    end
    fprintf('Saved %s\n',outputFile);
end
end
