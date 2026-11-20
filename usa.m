function fig = usa(data, varargin)
% USA  2.5D extruded map of the 50 states: one prism per state, height = value.
%
%   usa                                        bank-failure demo (banklist.csv)
%   usa(data)                                  any input usaData accepts
%   usa(data, 'Title', 'Population', 'Output', 'out.png')
%   usa('sales.csv', 'ValueColumn', 'Revenue')  CSV options are passed to usaData
%
% DATA can be a 50-vector (alphabetical), containers.Map, struct, table,
% {keys, values} cell, cellstr of keys to count, or a CSV path. Keys may be
% postal codes or state names. See usaData.
%
% Options (name/value, case-insensitive):
%   Title       ''          figure title
%   ValueLabel  'Value'     legend heading
%   Output      ''          write a PNG and close the figure (unless it is returned)
%   Colors      'value'     'value' (sequential ramp) | 'states' (distinct palette)
%                           | N x 3 colormap | colormap function name, e.g. 'parula'
%   Height      0.35        tallest prism as a fraction of the map width
%   Contours    0           rings stacked on each prism: 0 none, N evenly spaced
%                           levels, or 'unit' for one ring per 1.0 of value
%   View        [-12 55]    [azimuth elevation] in degrees
%   Legend      true        true (states with data) | false | N (top N states)
%   Format      '%g'        number format used in the legend
%   Footer      {}          cellstr of footnote lines
%   Boundaries  ''          alternate boundary .json or shapefile
%   Renderer    'auto'      'auto' | 'opengl' (rotatable) | 'raster' (fixed image)
%   StateColumn, ValueColumn, Aggregate    forwarded to usaData
%
% Performance: geometry is triangulated once and cached (see usaGeometry), and
% the whole map is a single patch plus one outline object per state, so
% rendering and rotation stay cheap regardless of the values.

if nargin < 1, data = []; end
% Legacy form: usa(boundaryFile, outputFile).
if numel(varargin) == 1 && (isempty(data) || isLegacyBoundary(data))
    varargin = {'Boundaries', data, 'Output', varargin{1}};
    data = [];
end
defaults = struct('Title', '', 'ValueLabel', 'Value', 'Output', '', 'Colors', 'value', ...
    'Height', .35, 'Contours', 0, 'View', [-12 55], 'Legend', true, 'Format', '%g', ...
    'Footer', {{}}, 'Boundaries', '', 'Renderer', 'auto', ...
    'StateColumn', '', 'ValueColumn', '', 'Aggregate', '');
isDemo = isempty(data);
if isDemo
    % Demo: FDIC failed-bank list, styled like the original project.
    data = fullfile(fileparts(mfilename('fullpath')), 'banklist.csv');
    defaults.Title = 'USA BANK FAILURES | 2000–2023';
    defaults.ValueLabel = 'Failures';
    defaults.Colors = 'states';
    defaults.Contours = 'unit';
    defaults.Footer = {'Bundled FDIC data through July 2023; Puerto Rico records excluded.', ...
        'Alaska and Hawaii are repositioned and rescaled. Height = failure count.'};
end
opts = parseOptions(varargin, defaults);
if isDemo, quiet = warning('off', 'usaData:UnknownKeys'); end  % PR is noted in the footer

names = usaStates();
values = usaData(data, 'StateColumn', opts.StateColumn, ...
    'ValueColumn', opts.ValueColumn, 'Aggregate', opts.Aggregate);
if isDemo, warning(quiet); end
geo = usaGeometry(opts.Boundaries);
colors = stateColors(values, opts.Colors);
scene = buildScene(geo, values, colors, opts);

% ---- figure -------------------------------------------------------------
if exist('OCTAVE_VERSION', 'builtin') && any(strcmp(available_graphics_toolkits(), 'qt'))
    graphics_toolkit('qt');
end
useRaster = strcmpi(opts.Renderer, 'raster') || (strcmpi(opts.Renderer, 'auto') && ...
    exist('OCTAVE_VERSION', 'builtin') && strcmp(graphics_toolkit(), 'gnuplot'));
background = [.055 .075 .10];
ink = [.86 .90 .94];
showLegend = ~isequal(opts.Legend, false) && ~isequal(opts.Legend, 0);
visible = 'on';
if ~isempty(opts.Output), visible = 'off'; end
fig = figure('Name', char(opts.Title), 'Color', background, ...
    'Position', [0 0 1800 1100], 'Visible', visible, 'InvertHardcopy', 'off');
mapWidth = .93 - .22 * showLegend;
ax = axes('Parent', fig, 'Position', [.03 .10 mapWidth .80], 'Color', background);
hold(ax, 'on');

if useRaster
    image(ax, double(rasterizeMap(scene, background, opts.View)) / 255);
    axis(ax, 'image'); set(ax, 'YDir', 'reverse');
else
    patch('Parent', ax, 'Vertices', scene.Vertices, 'Faces', scene.Faces, ...
        'FaceVertexCData', scene.FaceColors, 'FaceColor', 'flat', 'EdgeColor', 'none');
    for k = 1:numel(scene.Lines)
        L = scene.Lines(k);
        line(L.XYZ(:, 1), L.XYZ(:, 2), L.XYZ(:, 3), 'Parent', ax, ...
            'Color', L.Color, 'LineWidth', .4);
    end
    axis(ax, 'equal', 'tight'); view(ax, opts.View);
    set(ax, 'Projection', 'orthographic', 'Clipping', 'off');
    camzoom(ax, 1.3);    % 3D axes reserve room for any rotation; fill the panel instead
    rotate3d(fig, 'on');
end
axis(ax, 'off');
annotation(fig, 'textbox', [.03 .91 mapWidth .07], 'String', opts.Title, 'Color', [.95 .97 1], ...
    'FontSize', 22, 'FontWeight', 'bold', 'EdgeColor', 'none', 'HorizontalAlignment', 'center');

if showLegend, drawLegend(fig, names, values, colors, opts, ink); end
footer = opts.Footer;
if ischar(footer), footer = {footer}; end
finite = values(isfinite(values));
summary = sprintf(['%s total across %d states with data  |  max ' opts.Format], ...
    num2str(sum(finite)), numel(finite), max([finite; 0]));
annotation(fig, 'textbox', [.04 .01 .70 .08], 'String', [{summary}, footer(:)'], ...
    'Color', [.72 .79 .85], 'EdgeColor', 'none', 'FontSize', 11, ...
    'VerticalAlignment', 'bottom');

if ~isempty(opts.Output)
    folder = fileparts(opts.Output);
    if ~isempty(folder) && exist(folder, 'dir') ~= 7, mkdir(folder); end
    set(fig, 'PaperPositionMode', 'auto');
    device = '-dpng';
    if exist('OCTAVE_VERSION', 'builtin') && strcmp(graphics_toolkit(), 'gnuplot')
        device = '-dpngcairo';   % keeps the dark background
    end
    print(fig, opts.Output, device, '-r150');
    fprintf('Saved %s\n', opts.Output);
    if nargout == 0, close(fig); clear fig; end
end
end

% ========================================================================
function scene = buildScene(geo, values, colors, opts)
% One triangle mesh (tops + walls) and one polyline set per state.
h = values; h(~isfinite(h) | h < 0) = 0;
span = max(geo.Points) - min(geo.Points);
zScale = opts.Height * span(1) / max([h; eps]);
top = h * zScale;
P = size(geo.Points, 1);
scene.Vertices = [geo.Points, top(geo.PointState); geo.Points, zeros(P, 1)];

% Walls: only for raised states. Rings are CCW, so [dy, -dx] points outward.
raised = top(geo.EdgeState) > 0;
a = geo.Edges(raised, 1); b = geo.Edges(raised, 2);
d = geo.Points(b, :) - geo.Points(a, :);
normal = [d(:, 2), -d(:, 1)] ./ max(hypot(d(:, 1), d(:, 2)), eps);
% Fake lighting: a light rotated 40 degrees off the camera, no lighting engine.
az = (opts.View(1) + 40) * pi / 180;
shade = .45 + .45 * max(0, normal * [sin(az); -cos(az)]);
wallColor = colors(geo.EdgeState(raised), :) .* shade;

scene.Faces = [geo.Faces; a, b, b + P; a, b + P, a + P];
scene.FaceColors = [colors(geo.FaceState, :); wallColor; wallColor];

% Outlines: every state's top edge, plus optional stacked contour rings.
if ischar(opts.Contours) && strcmpi(opts.Contours, 'unit')
    levels = 1:floor(max(h));
elseif isnumeric(opts.Contours) && opts.Contours > 0
    levels = linspace(0, max(h), round(opts.Contours) + 1);
    levels = levels(1:end - 1);
else
    levels = [];
end
lines = struct('XYZ', {}, 'Color', {});
for s = 1:50
    rings = find(geo.RingState == s & geo.RingLength > 0)';
    if isempty(rings), continue; end
    % Closed rings separated by NaN rows: a single line object per state.
    xy = cell(numel(rings), 1);
    for k = 1:numel(rings)
        ids = geo.RingStart(rings(k)) + [0:geo.RingLength(rings(k)) - 1, 0];
        xy{k} = [geo.Points(ids, :); NaN NaN];
    end
    xy = vertcat(xy{:});
    z = [levels(levels < h(s)) * zScale, top(s)];
    n = size(xy, 1);
    lines(end + 1) = struct('XYZ', [repmat(xy, numel(z), 1), kron(z(:), ones(n, 1))], ...
        'Color', min(1, colors(s, :) * .55 + .35)); %#ok<AGROW>
end
scene.Lines = lines;
end

function colors = stateColors(values, scheme)
noData = [.20 .25 .30];
if ischar(scheme) && strcmpi(scheme, 'states')
    colors = statePalette();
    colors(~(values > 0), :) = repmat(noData, nnz(~(values > 0)), 1);
    return;
end
if ischar(scheme) && strcmpi(scheme, 'value')
    % Viridis anchors (lightly trimmed at the dark end for a dark background).
    anchors = [.28 .14 .46; .23 .32 .55; .13 .57 .55; .37 .79 .38; .99 .91 .14];
    map = interp1(linspace(0, 1, 5), anchors, linspace(0, 1, 256));
elseif ischar(scheme)
    map = feval(scheme, 256);
else
    map = scheme;
end
finite = isfinite(values);
lo = min(values(finite)); hi = max(values(finite));
t = .5 * ones(50, 1);
if hi > lo, t = (values - lo) / (hi - lo); end
t(~finite) = 0;
colors = map(round(1 + t * (size(map, 1) - 1)), :);
colors(~finite, :) = repmat(noData, nnz(~finite), 1);
end

function drawLegend(fig, names, values, colors, opts, ink)
sortable = values; sortable(~isfinite(sortable)) = -inf;
[~, order] = sort(sortable, 'descend');
count = max(1, nnz(isfinite(values)));   % states without data are not listed
if isnumeric(opts.Legend) && ~islogical(opts.Legend), count = min(count, opts.Legend); end
order = order(1:count);
ax = axes('Parent', fig, 'Position', [.78 .10 .20 .80]);
rows = max(count, 30);   % fixed row pitch, so short legends stay compact
hold(ax, 'on'); axis(ax, [0 1 0 rows + 2]); axis(ax, 'off');
text(ax, 0, rows + 1.4, upper(sprintf('State / %s', opts.ValueLabel)), ...
    'FontSize', 12, 'FontWeight', 'bold', 'Color', [.95 .97 1]);
y = rows - (1:count)' + .5;
% All swatches are one patch.
x = [0 .035 .035 0];
patch('Parent', ax, 'XData', repmat(x', 1, count), ...
    'YData', [y - .16, y - .16, y + .14, y + .14]', ...
    'FaceVertexCData', colors(order, :), 'FaceColor', 'flat', 'EdgeColor', 'none');
for i = 1:count
    v = values(order(i));
    label = '—';
    if isfinite(v), label = sprintf(opts.Format, v); end
    text(ax, .06, y(i), sprintf('%s  (%s)', names{order(i)}, label), ...
        'FontSize', 10.5, 'Color', ink, 'Interpreter', 'none');
end
end

function tf = isLegacyBoundary(x)
tf = ischar(x) && any(strcmpi(regexp(x, '\.\w+$', 'match', 'once'), {'.shp', '.json'}));
end

function opts = parseOptions(args, opts)
if mod(numel(args), 2), error('usa:BadOptions', 'Options must be name/value pairs.'); end
fields = fieldnames(opts);
for k = 1:2:numel(args)
    hit = strcmpi(fields, args{k});
    if ~any(hit), error('usa:BadOption', 'Unknown option ''%s''.', args{k}); end
    opts.(fields{hit}) = args{k + 1};
end
end

function colors = statePalette()
% The original project's distinct palette, alphabetical by state.
colors = [
    .620 .125 .294; .086 .317 .482; .769 .102 .125; .090 .184 .373; % AL AK AZ AR
    .839 .282 .098; .533 .172 .227; .137 .235 .423; .902 .160 .235; % CA CO CT DE
    .980 .349 .090; .612 .086 .141; .984 .502 .118; .278 .486 .169; % FL GA HI ID
    .341 .360 .690; .075 .306 .267; .502 .000 .149; .906 .298 .235; % IL IN IA KS
    .537 .404 .145; .541 .149 .196; .282 .322 .619; .000 .361 .533; % KY LA ME MD
    .482 .569 .094; .384 .431 .435; .514 .675 .757; .216 .247 .271; % MA MI MN MS
    .506 .149 .341; .965 .855 .157; .078 .388 .333; .086 .176 .431; % MO MT NE NV
    .251 .541 .796; .937 .227 .243; .275 .506 .725; .078 .361 .529; % NH NJ NM NY
    .251 .404 .698; .000 .306 .561; .812 .196 .208; .094 .373 .102; % NC ND OH OK
    .749 .196 .384; .145 .251 .396; .000 .271 .529; .141 .317 .470; % OR PA RI SC
    .086 .129 .431; .620 .125 .294; .000 .267 .486; .000 .337 .620; % SD TN TX UT
    .086 .227 .435; .639 .086 .216; .043 .275 .557; .533 .102 .243; % VT VA WA WV
    .000 .286 .482; .239 .275 .435];                                % WI WY
end
